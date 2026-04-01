; jobs.asm
; Job control table and operations

%include "src/hal/platform_defs.inc"

extern arena_alloc
extern hal_write
extern hal_waitpid
extern hal_kill
extern hal_getpid
extern hal_tcsetpgrp
extern hal_sigaction
extern hal_sigreturn_restorer

section .text
global jobs_init
global jobs_add
global jobs_remove
global jobs_find_by_id
global jobs_find_by_pgid
global jobs_update_status
global jobs_list
global jobs_fg
global jobs_bg
global jobs_get_count
global jobs_get_last_id
global jobs_get_sigchld_flag
global sigchld_handler

%define JOB_RUNNING                 1
%define JOB_STOPPED                 2
%define JOB_DONE                    3
%define MAX_JOBS                    64
%define MAX_JOB_PIDS                16

; Job struct
%define J_ID_OFF                    0
%define J_PGID_OFF                  4
%define J_PID_COUNT_OFF             8
%define J_PIDS_OFF                  12
%define J_STATUS_OFF                76
%define J_EXIT_CODE_OFF             80
%define J_BACKGROUND_OFF            84
%define J_COMMAND_OFF               88
%define J_CMD_LEN_OFF               96
%define JOB_SIZE                    104

section .data
    msg_lbrk               db "["
    msg_rbrk               db "] "
    msg_plus               db "+ "
    msg_minus              db "- "
    msg_running            db "Running "
    msg_running_len        equ $ - msg_running
    msg_stopped            db "Stopped "
    msg_stopped_len        equ $ - msg_stopped
    msg_done               db "Done "
    msg_done_len           equ $ - msg_done
    msg_amp                db " &"
    msg_nl                 db 10

section .bss
    jobs_table             resb JOB_SIZE * MAX_JOBS
    jobs_count             resd 1
    jobs_next_id           resd 1
    jobs_shell_pgid        resd 1
    jobs_terminal_fd       resd 1
    jobs_arena_ptr         resq 1
    sigchld_received       resd 1
    num_buf                resb 32

section .text

write_dec:
    ; rdi=value (unsigned int)
    push rbx
    push r12
    mov rbx, rdi
    lea r12, [rel num_buf + 31]
    mov byte [r12], 0
    cmp ebx, 0
    jne .loop
    dec r12
    mov byte [r12], '0'
    jmp .emit
.loop:
    xor edx, edx
    mov eax, ebx
    mov ecx, 10
    div ecx
    add dl, '0'
    dec r12
    mov [r12], dl
    mov ebx, eax
    test ebx, ebx
    jnz .loop
.emit:
    mov rdi, STDOUT
    mov rsi, r12
    lea rdx, [rel num_buf + 31]
    sub rdx, r12
    call hal_write
    pop r12
    pop rbx
    ret

jobs_find_free:
    ; rax=slot ptr or 0
    xor ecx, ecx
.loop:
    cmp ecx, MAX_JOBS
    jae .none
    mov eax, ecx
    imul rax, JOB_SIZE
    lea rdx, [rel jobs_table]
    add rax, rdx
    cmp dword [rax + J_ID_OFF], 0
    je .ret
    inc ecx
    jmp .loop
.none:
    xor eax, eax
.ret:
    ret

jobs_get_last_id:
    xor ecx, ecx
    xor eax, eax
.loop:
    cmp ecx, MAX_JOBS
    jae .ret
    mov eax, ecx
    imul rax, JOB_SIZE
    lea rdx, [rel jobs_table]
    add rdx, rax
    mov r8d, dword [rdx + J_ID_OFF]
    cmp r8d, eax
    jbe .next
    mov eax, r8d
.next:
    inc ecx
    jmp .loop
.ret:
    ret

jobs_get_count:
    mov eax, [rel jobs_count]
    ret

jobs_get_sigchld_flag:
    mov eax, [rel sigchld_received]
    ret

; minimal SIGCHLD handler
sigchld_handler:
    mov dword [rel sigchld_received], 1
    ret

jobs_init:
    ; rdi=arena_ptr (persistent)
    mov [rel jobs_arena_ptr], rdi
    mov dword [rel jobs_count], 0
    mov dword [rel jobs_next_id], 1
    mov dword [rel jobs_terminal_fd], STDIN
    mov dword [rel sigchld_received], 0
    call hal_getpid
    mov [rel jobs_shell_pgid], eax

    ; register SIGCHLD handler
    sub rsp, 32
    lea rax, [rel sigchld_handler]
    mov [rsp + 0], rax                  ; handler
    mov qword [rsp + 8], SA_RESTART | SA_RESTORER | SA_NOCLDSTOP
    lea rax, [rel hal_sigreturn_restorer]
    mov [rsp + 16], rax
    mov qword [rsp + 24], 0             ; mask
    mov rdi, SIGCHLD
    mov rsi, rsp
    xor rdx, rdx
    call hal_sigaction
    add rsp, 32
    xor eax, eax
    ret

jobs_find_by_id:
    ; rdi=job_id -> rax=job ptr or 0
    xor ecx, ecx
.loop:
    cmp ecx, MAX_JOBS
    jae .none
    mov eax, ecx
    imul rax, JOB_SIZE
    lea rdx, [rel jobs_table]
    add rax, rdx
    cmp dword [rax + J_ID_OFF], edi
    je .ret
    inc ecx
    jmp .loop
.none:
    xor eax, eax
.ret:
    ret

jobs_find_by_pgid:
    ; rdi=pgid -> rax=job ptr or 0
    xor ecx, ecx
.loop:
    cmp ecx, MAX_JOBS
    jae .none
    mov eax, ecx
    imul rax, JOB_SIZE
    lea rdx, [rel jobs_table]
    add rax, rdx
    cmp dword [rax + J_ID_OFF], 0
    je .next
    cmp dword [rax + J_PGID_OFF], edi
    je .ret
.next:
    inc ecx
    jmp .loop
.none:
    xor eax, eax
.ret:
    ret

jobs_add:
    ; rdi=pgid, rsi=pids_ptr, rdx=pid_count, rcx=background, r8=command, r9=cmd_len
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov ebx, edi                        ; pgid
    mov r12, rsi
    mov r13, rdx
    mov r14, rcx
    mov r15, r8
    mov r10, r9

    call jobs_find_free
    test rax, rax
    jz .fail
    mov r11, rax

    mov eax, [rel jobs_next_id]
    mov [r11 + J_ID_OFF], eax
    inc dword [rel jobs_next_id]
    mov [r11 + J_PGID_OFF], ebx
    mov [r11 + J_PID_COUNT_OFF], r13d
    mov dword [r11 + J_STATUS_OFF], JOB_RUNNING
    mov dword [r11 + J_EXIT_CODE_OFF], 0
    mov [r11 + J_BACKGROUND_OFF], r14d
    mov [r11 + J_CMD_LEN_OFF], r10d

    ; copy pids
    xor ecx, ecx
.pid_loop:
    cmp ecx, r13d
    jae .pid_done
    cmp ecx, MAX_JOB_PIDS
    jae .pid_done
    mov edx, dword [r12 + rcx*4]
    mov dword [r11 + J_PIDS_OFF + rcx*4], edx
    inc ecx
    jmp .pid_loop
.pid_done:

    ; copy command
    mov rdi, [rel jobs_arena_ptr]
    test rdi, rdi
    jz .no_cmd_copy
    mov rsi, r10
    inc rsi
    call arena_alloc
    test rax, rax
    jz .no_cmd_copy
    mov [r11 + J_COMMAND_OFF], rax
    mov rdi, rax
    mov rsi, r15
    mov rdx, r10
    test rdx, rdx
    jz .nul
.cpy:
    mov al, [rsi]
    mov [rdi], al
    inc rdi
    inc rsi
    dec rdx
    jnz .cpy
.nul:
    mov byte [rdi], 0
    jmp .added
.no_cmd_copy:
    mov [r11 + J_COMMAND_OFF], r15

.added:
    inc dword [rel jobs_count]
    mov eax, dword [r11 + J_ID_OFF]
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

jobs_remove:
    ; rdi=job_id -> eax=0/-1
    call jobs_find_by_id
    test rax, rax
    jz .fail
    mov dword [rax + J_ID_OFF], 0
    mov dword [rax + J_PGID_OFF], 0
    mov dword [rax + J_PID_COUNT_OFF], 0
    mov dword [rax + J_STATUS_OFF], 0
    mov dword [rax + J_EXIT_CODE_OFF], 0
    mov dword [rax + J_BACKGROUND_OFF], 0
    mov qword [rax + J_COMMAND_OFF], 0
    mov dword [rax + J_CMD_LEN_OFF], 0
    cmp dword [rel jobs_count], 0
    je .ok
    dec dword [rel jobs_count]
.ok:
    xor eax, eax
    ret
.fail:
    mov eax, -1
    ret

print_job_line:
    ; rdi=job ptr
    push rbx
    mov rbx, rdi
    mov rdi, STDOUT
    lea rsi, [rel msg_lbrk]
    mov rdx, 1
    call hal_write
    mov edi, dword [rbx + J_ID_OFF]
    call write_dec
    mov rdi, STDOUT
    lea rsi, [rel msg_rbrk]
    mov rdx, 2
    call hal_write

    cmp dword [rbx + J_STATUS_OFF], JOB_RUNNING
    jne .chk_stopped
    mov rdi, STDOUT
    lea rsi, [rel msg_running]
    mov rdx, msg_running_len
    call hal_write
    jmp .print_cmd
.chk_stopped:
    cmp dword [rbx + J_STATUS_OFF], JOB_STOPPED
    jne .done_state
    mov rdi, STDOUT
    lea rsi, [rel msg_stopped]
    mov rdx, msg_stopped_len
    call hal_write
    jmp .print_cmd
.done_state:
    mov rdi, STDOUT
    lea rsi, [rel msg_done]
    mov rdx, msg_done_len
    call hal_write

.print_cmd:
    mov rsi, [rbx + J_COMMAND_OFF]
    mov edx, dword [rbx + J_CMD_LEN_OFF]
    test rsi, rsi
    jz .trail
    test rdx, rdx
    jz .trail
    mov rdi, STDOUT
    call hal_write
.trail:
    cmp dword [rbx + J_BACKGROUND_OFF], 1
    jne .nl
    mov rdi, STDOUT
    lea rsi, [rel msg_amp]
    mov rdx, 2
    call hal_write
.nl:
    mov rdi, STDOUT
    lea rsi, [rel msg_nl]
    mov rdx, 1
    call hal_write
    pop rbx
    ret

jobs_list:
    push rbx
    xor ecx, ecx
.loop:
    cmp ecx, MAX_JOBS
    jae .ret
    mov eax, ecx
    imul rax, JOB_SIZE
    lea rbx, [rel jobs_table]
    add rbx, rax
    cmp dword [rbx + J_ID_OFF], 0
    je .next
    mov rdi, rbx
    call print_job_line
.next:
    inc ecx
    jmp .loop
.ret:
    pop rbx
    xor eax, eax
    ret

jobs_update_status:
    ; poll all jobs non-blocking
    push rbx
    push r12
    push r13
    mov dword [rel sigchld_received], 0
    xor ecx, ecx
.job_loop:
    cmp ecx, MAX_JOBS
    jae .ret
    mov eax, ecx
    imul rax, JOB_SIZE
    lea rbx, [rel jobs_table]
    add rbx, rax
    cmp dword [rbx + J_ID_OFF], 0
    je .next_job
    mov r12d, dword [rbx + J_PID_COUNT_OFF]
    xor r13d, r13d
.pid_loop:
    cmp r13d, r12d
    jae .next_job
    mov edi, dword [rbx + J_PIDS_OFF + r13*4]
    lea rsi, [rsp - 8]
    mov rdx, WNOHANG | WUNTRACED | WCONTINUED
    sub rsp, 16
    call hal_waitpid
    mov r8d, dword [rsp]
    add rsp, 16
    cmp rax, 0
    jle .next_pid
    ; exited or signaled -> mark done for MVP
    mov dword [rbx + J_STATUS_OFF], JOB_DONE
    mov eax, r8d
    shr eax, 8
    and eax, 0xFF
    mov dword [rbx + J_EXIT_CODE_OFF], eax
.next_pid:
    inc r13d
    jmp .pid_loop
.next_job:
    ; print completion for background and remove
    cmp dword [rbx + J_ID_OFF], 0
    je .advance
    cmp dword [rbx + J_STATUS_OFF], JOB_DONE
    jne .advance
    cmp dword [rbx + J_BACKGROUND_OFF], 1
    jne .rm
    mov rdi, rbx
    call print_job_line
.rm:
    mov edi, dword [rbx + J_ID_OFF]
    call jobs_remove
.advance:
    inc ecx
    jmp .job_loop
.ret:
    pop r13
    pop r12
    pop rbx
    xor eax, eax
    ret

jobs_fg:
    ; rdi=job_id (0 -> latest)
    push rbx
    push r12
    mov ebx, edi
    cmp ebx, 0
    jne .have_id
    call jobs_get_last_id
    mov ebx, eax
.have_id:
    mov edi, ebx
    call jobs_find_by_id
    test rax, rax
    jz .fail
    mov r12, rax

    ; move terminal to job group
    mov edi, dword [rel jobs_terminal_fd]
    mov esi, dword [r12 + J_PGID_OFF]
    call hal_tcsetpgrp

    ; continue group
    movsx rdi, dword [r12 + J_PGID_OFF]
    neg rdi
    mov rsi, SIGCONT
    call hal_kill

    ; wait for group
    sub rsp, 16
    movsx rdi, dword [r12 + J_PGID_OFF]
    neg rdi
    mov rsi, rsp
    mov rdx, WUNTRACED
    call hal_waitpid
    mov eax, dword [rsp]
    add rsp, 16
    and eax, 0xFF
    cmp eax, 0x7F
    jne .done
    mov dword [r12 + J_STATUS_OFF], JOB_STOPPED
    jmp .restore
.done:
    mov edi, dword [r12 + J_ID_OFF]
    call jobs_remove
.restore:
    mov edi, dword [rel jobs_terminal_fd]
    mov esi, dword [rel jobs_shell_pgid]
    call hal_tcsetpgrp
    xor eax, eax
    jmp .ret
.fail:
    mov eax, -1
.ret:
    pop r12
    pop rbx
    ret

jobs_bg:
    ; rdi=job_id (0 -> latest)
    push rbx
    mov ebx, edi
    cmp ebx, 0
    jne .have
    call jobs_get_last_id
    mov ebx, eax
.have:
    mov edi, ebx
    call jobs_find_by_id
    test rax, rax
    jz .fail
    mov dword [rax + J_STATUS_OFF], JOB_RUNNING
    mov dword [rax + J_BACKGROUND_OFF], 1
    movsx rdi, dword [rax + J_PGID_OFF]
    neg rdi
    mov rsi, SIGCONT
    call hal_kill
    xor eax, eax
    pop rbx
    ret
.fail:
    pop rbx
    mov eax, -1
    ret
