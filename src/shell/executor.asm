; executor.asm
; AST executor for Aura Shell Phase 1 (Linux x86_64, NASM)

%include "src/hal/linux_x86_64/defs.inc"

extern arena_alloc
extern hal_write
extern hal_exit
extern hal_open
extern hal_close
extern hal_fork
extern hal_execve
extern hal_waitpid
extern hal_dup2
extern hal_access
extern hal_chdir
extern exec_pipeline

section .text
global executor_init
global executor_run
global exec_simple_command
global resolve_path
global build_argv

; AST node types
%define NODE_COMMAND                1
%define NODE_PIPELINE               2
%define NODE_LIST                   3

; List operators
%define OP_AND                      1
%define OP_OR                       2
%define OP_SEQ                      3

%define MAX_PATH_BUF                4096

; ExecutorState
%define EX_LAST_EXIT_OFF            0
%define EX_ARENA_PTR_OFF            8
%define EX_ENVP_OFF                 16
%define EXECUTOR_STATE_SIZE         24

; CommandNode layout (from parser)
%define CMD_TYPE_OFF                0
%define CMD_ARGC_OFF                4
%define CMD_ARGV_OFF                8
%define CMD_ARGV_LEN_OFF            136
%define CMD_REDIRECT_IN_OFF         200
%define CMD_REDIRECT_IN_LEN_OFF     208
%define CMD_REDIRECT_OUT_OFF        216
%define CMD_REDIRECT_OUT_LEN_OFF    224
%define CMD_REDIRECT_APPEND_OFF     228
%define CMD_BACKGROUND_OFF          252

; PipelineNode layout
%define PL_TYPE_OFF                 0
%define PL_CMD_COUNT_OFF            4
%define PL_COMMANDS_OFF             8

; ListNode layout
%define LS_TYPE_OFF                 0
%define LS_COUNT_OFF                4
%define LS_PIPELINES_OFF            8
%define LS_OPERATORS_OFF            136

section .rodata
    env_name_path          db "PATH"
    env_name_path_len      equ $ - env_name_path
    default_path           db "/bin:/usr/bin", 0
    msg_exec_failed        db "aura: exec failed", 10
    msg_exec_failed_len    equ $ - msg_exec_failed
    builtin_echo_name      db "echo"
    builtin_cd_name        db "cd"
    builtin_exit_name      db "exit"

section .data
    out_space              db " "
    out_nl                 db 10

section .text

memcpy_simple:
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

streq_len:
    ; rdi=str1, rsi=str2, rdx=len, rax=1 if equal
    xor eax, eax
    test rdx, rdx
    jz .yes
.loop:
    mov cl, [rdi]
    cmp cl, [rsi]
    jne .no
    inc rdi
    inc rsi
    dec rdx
    jnz .loop
.yes:
    mov eax, 1
    ret
.no:
    xor eax, eax
    ret

contains_slash:
    ; rdi=ptr, rsi=len ; rax=1 if has '/'
    xor eax, eax
    xor rcx, rcx
.loop:
    cmp rcx, rsi
    jae .ret
    cmp byte [rdi + rcx], '/'
    je .yes
    inc rcx
    jmp .loop
.yes:
    mov eax, 1
.ret:
    ret

copy_to_cstr:
    ; rdi=dst, rsi=src, rdx=len -> rax=dst
    push rbx
    push rcx
    mov rbx, rdi
    mov rcx, rdx
    call memcpy_simple
    mov byte [rbx + rcx], 0
    mov rax, rbx
    pop rcx
    pop rbx
    ret

find_env_value:
    ; rdi=envp, rsi=name_ptr, rdx=name_len
    ; rax=value_ptr or 0
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx

    test rbx, rbx
    jz .none
    xor rcx, rcx
.env_loop:
    mov r8, [rbx + rcx*8]
    test r8, r8
    jz .none

    ; compare prefix name
    xor r9, r9
.cmp_loop:
    cmp r9, r13
    jae .check_eq
    mov al, [r8 + r9]
    cmp al, [r12 + r9]
    jne .next_env
    inc r9
    jmp .cmp_loop

.check_eq:
    cmp byte [r8 + r13], '='
    jne .next_env
    lea rax, [r8 + r13 + 1]
    jmp .ret

.next_env:
    inc rcx
    jmp .env_loop

.none:
    xor eax, eax
.ret:
    pop r13
    pop r12
    pop rbx
    ret

resolve_path:
    ; rdi=state, rsi=cmd_ptr, rdx=cmd_len, rcx=result_buf, r8=buf_size
    ; rax=1 success, 0 fail
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r14, rcx
    mov r15, r8

    test r12, r12
    jz .fail
    test r13, r13
    jz .fail

    mov rdi, r12
    mov rsi, r13
    call contains_slash
    cmp rax, 1
    jne .search_path

    mov rax, r13
    inc rax
    cmp rax, r15
    ja .fail
    mov rdi, r14
    mov rsi, r12
    mov rdx, r13
    call copy_to_cstr
    mov rdi, r14
    mov rsi, X_OK
    call hal_access
    cmp rax, 0
    jne .fail
    mov eax, 1
    jmp .ret

.search_path:
    mov rdi, [rbx + EX_ENVP_OFF]
    lea rsi, [rel env_name_path]
    mov rdx, env_name_path_len
    call find_env_value
    test rax, rax
    jnz .have_path
    lea rax, [rel default_path]
.have_path:
    mov r9, rax                         ; path cursor

.next_segment:
    mov r10, r9                        ; seg start
    xor r11, r11                       ; seg len
.seg_len_loop:
    mov al, [r10 + r11]
    test al, al
    jz .seg_end
    cmp al, ':'
    je .seg_end
    inc r11
    jmp .seg_len_loop

.seg_end:
    ; build "seg/cmd\0"
    ; required = seg_len + 1 + cmd_len + 1
    mov rax, r11
    add rax, 1
    add rax, r13
    add rax, 1
    cmp rax, r15
    ja .advance_seg

    ; copy seg
    mov rdi, r14
    test r11, r11
    jz .copy_cmd_only
    mov rsi, r10
    mov rdx, r11
    call memcpy_simple
.copy_cmd_only:
    lea rdi, [r14 + r11]
    mov byte [rdi], '/'
    inc rdi
    mov rsi, r12
    mov rdx, r13
    call memcpy_simple
    lea rax, [r14 + r11 + 1]
    mov byte [rax + r13], 0

    mov rdi, r14
    mov rsi, X_OK
    push r10
    push r11
    call hal_access
    pop r11
    pop r10
    cmp rax, 0
    je .ok

.advance_seg:
    mov al, [r10 + r11]
    test al, al
    jz .fail
    lea r9, [r10 + r11 + 1]
    jmp .next_segment

.ok:
    mov eax, 1
    jmp .ret
.fail:
    xor eax, eax
.ret:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

build_argv:
    ; rdi=state, rsi=cmd_ptr
    ; rax=argv_ptr or 0
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16
    mov rbx, rdi
    mov r12, rsi

    mov r13d, dword [r12 + CMD_ARGC_OFF]
    lea rsi, [r13*8 + 8]               ; (argc+1)*8
    mov rdi, [rbx + EX_ARENA_PTR_OFF]
    call arena_alloc
    test rax, rax
    jz .fail
    mov r14, rax                        ; argv array

    xor r15, r15
.arg_loop:
    cmp r15, r13
    jae .done
    mov r8, [r12 + CMD_ARGV_OFF + r15*8]
    mov r9d, dword [r12 + CMD_ARGV_LEN_OFF + r15*4]
    mov [rsp + 0], r8
    mov [rsp + 8], r9
    mov rsi, r9
    inc rsi
    mov rdi, [rbx + EX_ARENA_PTR_OFF]
    call arena_alloc
    test rax, rax
    jz .fail
    mov [r14 + r15*8], rax
    mov r10, rax
    mov r8, [rsp + 0]
    mov r9, [rsp + 8]
    mov rdi, r10
    mov rsi, r8
    mov rdx, r9
    call memcpy_simple
    mov byte [r10 + r9], 0
    inc r15
    jmp .arg_loop

.done:
    mov qword [r14 + r13*8], 0
    mov rax, r14
    jmp .ret
.fail:
    xor eax, eax
.ret:
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

builtin_echo:
    ; rdi=cmd_ptr
    ; rax=exit code
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12d, dword [rbx + CMD_ARGC_OFF]
    cmp r12d, 1
    jbe .newline
    mov r13d, 1
.arg_loop:
    cmp r13d, r12d
    jae .newline
    mov rdi, STDOUT
    mov rsi, [rbx + CMD_ARGV_OFF + r13*8]
    mov edx, dword [rbx + CMD_ARGV_LEN_OFF + r13*4]
    call hal_write
    mov eax, r12d
    dec eax
    cmp r13d, eax
    jae .next
    lea rsi, [rel out_space]
    mov rdi, STDOUT
    mov rdx, 1
    call hal_write
.next:
    inc r13d
    jmp .arg_loop
.newline:
    lea rsi, [rel out_nl]
    mov rdi, STDOUT
    mov rdx, 1
    call hal_write
    xor eax, eax
    pop r13
    pop r12
    pop rbx
    ret

parse_int:
    ; rdi=ptr, rsi=len -> eax=value (simple decimal)
    xor eax, eax
    xor rcx, rcx
.loop:
    cmp rcx, rsi
    jae .ret
    mov dl, [rdi + rcx]
    cmp dl, '0'
    jb .ret
    cmp dl, '9'
    ja .ret
    imul eax, eax, 10
    sub dl, '0'
    add eax, edx
    inc rcx
    jmp .loop
.ret:
    ret

is_builtin:
    ; rdi=cmd_ptr
    ; eax: 0 no, 1 echo, 2 cd, 3 exit
    push rbx
    mov rbx, rdi
    cmp dword [rbx + CMD_ARGC_OFF], 0
    jne .check_echo
    xor eax, eax
    pop rbx
    ret
.check_echo:
    cmp dword [rbx + CMD_ARGV_LEN_OFF], 4
    jne .check_cd
    mov rdi, [rbx + CMD_ARGV_OFF]
    lea rsi, [rel builtin_echo_name]
    mov rdx, 4
    call streq_len
    cmp rax, 1
    jne .check_cd
    mov eax, 1
    pop rbx
    ret
.check_cd:
    cmp dword [rbx + CMD_ARGV_LEN_OFF], 2
    jne .check_exit
    mov rdi, [rbx + CMD_ARGV_OFF]
    lea rsi, [rel builtin_cd_name]
    mov rdx, 2
    call streq_len
    cmp rax, 1
    jne .check_exit
    mov eax, 2
    pop rbx
    ret
.check_exit:
    cmp dword [rbx + CMD_ARGV_LEN_OFF], 4
    jne .no
    mov rdi, [rbx + CMD_ARGV_OFF]
    lea rsi, [rel builtin_exit_name]
    mov rdx, 4
    call streq_len
    cmp rax, 1
    jne .no
    mov eax, 3
    pop rbx
    ret
.no:
    xor eax, eax
    pop rbx
    ret

exec_simple_command:
    ; rdi=state, rsi=cmd_ptr
    ; rax=exit_code
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, MAX_PATH_BUF + 32
    mov rbx, rdi
    mov r12, rsi

    mov rdi, r12
    call is_builtin
    cmp eax, 1
    jne .check_cd
    cmp qword [r12 + CMD_REDIRECT_IN_OFF], 0
    jne .external
    cmp qword [r12 + CMD_REDIRECT_OUT_OFF], 0
    jne .external
    mov rdi, r12
    call builtin_echo
    jmp .ret

.check_cd:
    cmp eax, 2
    jne .check_exit
    cmp dword [r12 + CMD_ARGC_OFF], 2
    jb .cd_fail
    mov r13, [r12 + CMD_ARGV_OFF + 8]
    mov r14d, dword [r12 + CMD_ARGV_LEN_OFF + 4]
    mov rdi, [rbx + EX_ARENA_PTR_OFF]
    mov rsi, r14
    inc rsi
    call arena_alloc
    test rax, rax
    jz .cd_fail
    mov rdi, rax
    mov rsi, r13
    mov rdx, r14
    call copy_to_cstr
    mov rdi, rax
    call hal_chdir
    cmp rax, 0
    jne .cd_fail
    xor eax, eax
    jmp .ret
.cd_fail:
    mov eax, 1
    jmp .ret

.check_exit:
    cmp eax, 3
    jne .external
    mov eax, 0
    cmp dword [r12 + CMD_ARGC_OFF], 2
    jb .do_exit
    mov rdi, [r12 + CMD_ARGV_OFF + 8]
    mov esi, dword [r12 + CMD_ARGV_LEN_OFF + 4]
    call parse_int
.do_exit:
    mov edi, eax
    call hal_exit
    mov eax, 0
    jmp .ret

.external:
    ; resolve path
    lea rcx, [rsp + 16]
    mov rdi, rbx
    mov rsi, [r12 + CMD_ARGV_OFF]
    mov edx, dword [r12 + CMD_ARGV_LEN_OFF]
    mov r8, MAX_PATH_BUF
    call resolve_path
    cmp rax, 1
    jne .exec_fail_ret

    mov rdi, rbx
    mov rsi, r12
    call build_argv
    test rax, rax
    jz .exec_fail_ret
    mov r13, rax                        ; argv

    call hal_fork
    test rax, rax
    js .exec_fail_ret
    jz .child

    ; parent
    cmp dword [r12 + CMD_BACKGROUND_OFF], 1
    je .bg_ok
    mov r14, rax                        ; pid
    lea rsi, [rsp + 8]
    mov rdi, r14
    xor rdx, rdx
    call hal_waitpid
    test rax, rax
    js .exec_fail_ret
    mov eax, dword [rsp + 8]
    shr eax, 8
    and eax, 0xFF
    jmp .ret
.bg_ok:
    xor eax, eax
    jmp .ret

.child:
    ; redirect stdin if needed
    mov r14, [r12 + CMD_REDIRECT_IN_OFF]
    test r14, r14
    jz .check_out_redirect
    mov r15d, dword [r12 + CMD_REDIRECT_IN_LEN_OFF]
    mov rdi, [rbx + EX_ARENA_PTR_OFF]
    mov rsi, r15
    inc rsi
    call arena_alloc
    test rax, rax
    jz .child_fail
    mov rdi, rax
    mov rsi, r14
    mov rdx, r15
    call copy_to_cstr
    mov rdi, rax
    mov rsi, O_RDONLY
    xor rdx, rdx
    call hal_open
    test rax, rax
    js .child_fail
    mov r14, rax
    mov rdi, r14
    mov rsi, STDIN
    call hal_dup2
    mov rdi, r14
    call hal_close

.check_out_redirect:
    mov r14, [r12 + CMD_REDIRECT_OUT_OFF]
    test r14, r14
    jz .do_exec
    mov r15d, dword [r12 + CMD_REDIRECT_OUT_LEN_OFF]
    mov rdi, [rbx + EX_ARENA_PTR_OFF]
    mov rsi, r15
    inc rsi
    call arena_alloc
    test rax, rax
    jz .child_fail
    mov rdi, rax
    mov rsi, r14
    mov rdx, r15
    call copy_to_cstr
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
    js .child_fail
    mov r14, rax
    mov rdi, r14
    mov rsi, STDOUT
    call hal_dup2
    mov rdi, r14
    call hal_close

.do_exec:
    lea rdi, [rsp + 16]                 ; resolved path
    mov rsi, r13                        ; argv
    mov rdx, [rbx + EX_ENVP_OFF]
    call hal_execve

.child_fail:
    mov rdi, STDERR
    lea rsi, [rel msg_exec_failed]
    mov rdx, msg_exec_failed_len
    call hal_write
    mov rdi, 127
    call hal_exit
    xor eax, eax
    jmp .ret

.exec_fail_ret:
    mov eax, 127

.ret:
    add rsp, MAX_PATH_BUF + 32
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

exec_list:
    ; rdi=state, rsi=list_node
    ; rax=last exit code
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdi
    mov r12, rsi
    mov r13d, dword [r12 + LS_COUNT_OFF]
    test r13d, r13d
    jz .zero

    xor r14d, r14d
    xor eax, eax
.loop:
    cmp r14d, r13d
    jae .done

    cmp r14d, 0
    je .run_item
    mov ecx, dword [r12 + LS_OPERATORS_OFF + r14*4]
    cmp ecx, OP_AND
    jne .check_or
    cmp eax, 0
    jne .skip
    jmp .run_item
.check_or:
    cmp ecx, OP_OR
    jne .run_item
    cmp eax, 0
    je .skip
    jmp .run_item

.skip:
    inc r14d
    jmp .loop

.run_item:
    mov rdi, rbx
    mov rsi, [r12 + LS_PIPELINES_OFF + r14*8]
    call exec_pipeline
    mov dword [rbx + EX_LAST_EXIT_OFF], eax
    inc r14d
    jmp .loop

.done:
    mov eax, dword [rbx + EX_LAST_EXIT_OFF]
    jmp .ret
.zero:
    xor eax, eax
    mov dword [rbx + EX_LAST_EXIT_OFF], eax
.ret:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; executor_init(arena_ptr, envp) -> rax=state ptr or 0
executor_init:
    test rdi, rdi
    jz .fail
    push rbx
    mov rbx, rsi
    mov rsi, EXECUTOR_STATE_SIZE
    call arena_alloc
    test rax, rax
    jz .fail_pop
    mov dword [rax + EX_LAST_EXIT_OFF], 0
    mov [rax + EX_ARENA_PTR_OFF], rdi
    mov [rax + EX_ENVP_OFF], rbx
    pop rbx
    ret
.fail_pop:
    pop rbx
.fail:
    xor eax, eax
    ret

; executor_run(state, ast_root) -> rax=exit code
executor_run:
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdi
    mov r12, rsi
    test rbx, rbx
    jz .fail
    test r12, r12
    jz .fail

    cmp dword [r12 + LS_TYPE_OFF], NODE_LIST
    jne .fail
    mov rdi, rbx
    mov rsi, r12
    call exec_list
    jmp .ret
.fail:
    mov eax, 1
.ret:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
