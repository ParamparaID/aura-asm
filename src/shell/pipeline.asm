; pipeline.asm
; Pipeline execution for Aura Shell Phase 1

%include "src/hal/platform_defs.inc"

extern arena_alloc
extern hal_open
extern hal_close
extern hal_fork
extern hal_execve
extern hal_waitpid
extern hal_dup2
extern hal_pipe
extern hal_write
extern hal_exit
extern resolve_path
extern build_argv
extern exec_simple_command

section .text
global exec_pipeline
global apply_redirects

; Layouts shared with parser/executor
%define EX_LAST_EXIT_OFF            0
%define EX_ARENA_PTR_OFF            8
%define EX_ENVP_OFF                 16

%define CMD_ARGC_OFF                4
%define CMD_ARGV_OFF                8
%define CMD_ARGV_LEN_OFF            136
%define CMD_REDIRECT_IN_OFF         200
%define CMD_REDIRECT_IN_LEN_OFF     208
%define CMD_REDIRECT_OUT_OFF        216
%define CMD_REDIRECT_OUT_LEN_OFF    224
%define CMD_REDIRECT_APPEND_OFF     228

%define PL_CMD_COUNT_OFF            4
%define PL_COMMANDS_OFF             8

section .rodata
    msg_exec_failed        db "aura: exec failed", 10
    msg_exec_failed_len    equ $ - msg_exec_failed

section .text

copy_bytes:
    ; rdi=dst, rsi=src, rdx=len
    test rdx, rdx
    jz .ret
.loop:
    mov al, [rsi]
    mov [rdi], al
    inc rdi
    inc rsi
    dec rdx
    jnz .loop
.ret:
    ret

copy_token_to_cstr:
    ; rdi=state, rsi=src_ptr, rdx=src_len
    ; rax=cstr_ptr or 0
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov rdi, [rbx + EX_ARENA_PTR_OFF]
    mov rsi, r13
    inc rsi
    call arena_alloc
    test rax, rax
    jz .fail
    mov r8, rax
    mov rdi, r8
    mov rsi, r12
    mov rdx, r13
    call copy_bytes
    mov byte [r8 + r13], 0
    mov rax, r8
    jmp .ret
.fail:
    xor eax, eax
.ret:
    pop r13
    pop r12
    pop rbx
    ret

; apply_redirects(state, cmd_node)
; rax=0 success, -1 failure
apply_redirects:
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12, rsi

    ; stdin redirect
    mov rdi, rbx
    mov rsi, [r12 + CMD_REDIRECT_IN_OFF]
    test rsi, rsi
    jz .check_out
    mov edx, dword [r12 + CMD_REDIRECT_IN_LEN_OFF]
    call copy_token_to_cstr
    test rax, rax
    jz .fail
    mov rdi, rax
    mov rsi, O_RDONLY
    xor rdx, rdx
    call hal_open
    test rax, rax
    js .fail
    mov r13, rax
    mov rdi, r13
    mov rsi, STDIN
    call hal_dup2
    test rax, rax
    js .fail_close
    mov rdi, r13
    call hal_close
    jmp .check_out

.fail_close:
    mov rdi, r13
    call hal_close
    jmp .fail

.check_out:
    mov rdi, rbx
    mov rsi, [r12 + CMD_REDIRECT_OUT_OFF]
    test rsi, rsi
    jz .ok
    mov edx, dword [r12 + CMD_REDIRECT_OUT_LEN_OFF]
    call copy_token_to_cstr
    test rax, rax
    jz .fail

    mov rdi, rax
    mov rsi, O_WRONLY | O_CREAT
    cmp dword [r12 + CMD_REDIRECT_APPEND_OFF], 1
    jne .open_trunc
    or rsi, O_APPEND
    jmp .open_out
.open_trunc:
    or rsi, O_TRUNC
.open_out:
    mov rdx, 420                        ; 0644
    call hal_open
    test rax, rax
    js .fail
    mov r13, rax
    mov rdi, r13
    mov rsi, STDOUT
    call hal_dup2
    test rax, rax
    js .fail_close2
    mov rdi, r13
    call hal_close
    jmp .ok

.fail_close2:
    mov rdi, r13
    call hal_close
    jmp .fail

.ok:
    xor eax, eax
    jmp .ret
.fail:
    mov rax, -1
.ret:
    pop r13
    pop r12
    pop rbx
    ret

; exec_pipeline(state, pipeline_node)
; rax=exit code
exec_pipeline:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp
    sub rsp, 4120                       ; status + path buf
    mov rbx, rdi                        ; state
    mov r12, rsi                        ; pipeline

    test rbx, rbx
    jz .fail
    test r12, r12
    jz .fail

    mov r13d, dword [r12 + PL_CMD_COUNT_OFF]
    cmp r13d, 1
    ja .multi
    mov rsi, [r12 + PL_COMMANDS_OFF]
    test rsi, rsi
    jz .fail
    mov rdi, rbx
    call exec_simple_command
    jmp .ret

.multi:
    ; allocate pipes: (cmd_count-1) entries, each 8 bytes (int[2])
    mov eax, r13d
    dec eax
    mov r14d, eax                       ; pipe_count
    mov rdi, [rbx + EX_ARENA_PTR_OFF]
    mov rsi, r14
    imul rsi, 8
    call arena_alloc
    test rax, rax
    jz .fail
    mov r15, rax                        ; pipes ptr

    ; allocate pid array: cmd_count * 8
    mov rdi, [rbx + EX_ARENA_PTR_OFF]
    mov esi, r13d
    imul rsi, 8
    call arena_alloc
    test rax, rax
    jz .fail
    mov qword [rsp + 0], rax            ; pids ptr

    ; create N-1 pipes
    xor ebp, ebp
.pipe_create_loop:
    cmp ebp, r14d
    jae .fork_loop_start
    lea rdi, [r15 + rbp*8]
    call hal_pipe
    test rax, rax
    js .fail
    inc ebp
    jmp .pipe_create_loop

.fork_loop_start:
    xor ebp, ebp                        ; i
.fork_loop:
    cmp ebp, r13d
    jae .parent_close_pipes

    mov rdx, [r12 + PL_COMMANDS_OFF + rbp*8] ; cmd ptr
    test rdx, rdx
    jz .fail
    mov [rsp + 4112], rdx

    call hal_fork
    test rax, rax
    js .fail
    jz .child

    ; parent store pid
    mov r8, [rsp + 0]
    mov [r8 + rbp*8], rax
    inc ebp
    jmp .fork_loop

.child:
    mov rdx, [rsp + 4112]               ; cmd ptr
    ; connect stdin from previous pipe
    cmp ebp, 0
    je .child_stdout
    lea r8d, [ebp - 1]
    mov edi, dword [r15 + r8*8 + 0]     ; prev read end
    mov esi, STDIN
    call hal_dup2

.child_stdout:
    mov eax, r13d
    dec eax
    cmp ebp, eax
    jae .child_close_all
    mov edi, dword [r15 + rbp*8 + 4]    ; current write end
    mov esi, STDOUT
    call hal_dup2

.child_close_all:
    xor ebp, ebp
.child_close_loop:
    cmp ebp, r14d
    jae .child_redirect
    mov edi, dword [r15 + rbp*8 + 0]
    call hal_close
    mov edi, dword [r15 + rbp*8 + 4]
    call hal_close
    inc ebp
    jmp .child_close_loop

.child_redirect:
    mov rdi, rbx
    mov rsi, [rsp + 4112]
    call apply_redirects
    cmp rax, 0
    jne .child_fail

    ; resolve command path
    mov r10, [rsp + 4112]
    mov rdi, rbx
    mov rsi, [r10 + CMD_ARGV_OFF]
    mov edx, dword [r10 + CMD_ARGV_LEN_OFF]
    lea rcx, [rsp + 16]
    mov r8, 4096
    call resolve_path
    cmp rax, 1
    jne .child_fail

    ; build argv and exec
    mov rdi, rbx
    mov rsi, [rsp + 4112]
    call build_argv
    test rax, rax
    jz .child_fail
    mov rsi, rax
    lea rdi, [rsp + 16]
    mov rdx, [rbx + EX_ENVP_OFF]
    call hal_execve

.child_fail:
    mov rdi, STDERR
    lea rsi, [rel msg_exec_failed]
    mov rdx, msg_exec_failed_len
    call hal_write
    mov rdi, 127
    call hal_exit
    ud2

.parent_close_pipes:
    xor ebp, ebp
.parent_close_loop:
    cmp ebp, r14d
    jae .wait_children
    mov edi, dword [r15 + rbp*8 + 0]
    call hal_close
    mov edi, dword [r15 + rbp*8 + 4]
    call hal_close
    inc ebp
    jmp .parent_close_loop

.wait_children:
    xor ebp, ebp
    xor r9d, r9d
.wait_loop:
    cmp ebp, r13d
    jae .wait_done
    mov r8, [rsp + 0]                   ; pids ptr
    mov rdi, [r8 + rbp*8]
    lea rsi, [rsp + 8]                  ; status int
    xor rdx, rdx
    call hal_waitpid
    test rax, rax
    js .fail

    mov eax, r13d
    dec eax
    cmp ebp, eax
    jne .wait_next
    mov eax, dword [rsp + 8]
    shr eax, 8
    and eax, 0xFF
    mov r9d, eax
.wait_next:
    inc ebp
    jmp .wait_loop

.wait_done:
    mov eax, r9d
    jmp .ret

.fail:
    mov eax, 1
.ret:
    add rsp, 4120
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
