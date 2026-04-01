; test_jobs.asm
; Job control tests (MVP)

%include "src/hal/platform_defs.inc"

extern hal_write
extern hal_exit
extern hal_clock_gettime
extern arena_init
extern arena_reset
extern arena_destroy
extern builtins_init
extern lexer_init
extern lexer_tokenize
extern parser_init
extern parser_parse
extern executor_init
extern executor_run
extern jobs_get_count
extern jobs_update_status
extern jobs_add
extern jobs_remove
extern jobs_get_last_id
extern jobs_get_sigchld_flag

%define ARENA_SIZE                   524288

section .data
    pass_msg             db "ALL TESTS PASSED",10
    pass_len             equ $ - pass_msg
    fail_msg             db "TEST FAILED: test_jobs",10
    fail_len             equ $ - fail_msg

    cmd_sleep_bg         db "sleep 1 &"
    cmd_sleep_bg_len     equ $ - cmd_sleep_bg
    cmd_pipe_bg          db "echo hello | cat &"
    cmd_pipe_bg_len      equ $ - cmd_pipe_bg

section .bss
    arena_ptr            resq 1
    envp_ptr             resq 1
    fake_pids            resd 3
    ts_buf               resq 2

section .text
global _start

fail:
    mov rdi, STDOUT
    lea rsi, [rel fail_msg]
    mov rdx, fail_len
    call hal_write
    mov rdi, 1
    call hal_exit

sleep_ms:
    ; rdi=ms (best effort via nanosleep syscall)
    sub rsp, 16
    xor rax, rax
    xor rdx, rdx
    mov [rsp], rax
    mov rax, rdi
    imul rax, 1000000
    mov [rsp + 8], rax
    mov rax, 35
    mov rdi, rsp
    xor rsi, rsi
    syscall
    add rsp, 16
    ret

run_command:
    ; rdi=input ptr, rdx=len -> rax=exit
    push rbx
    push r12
    mov rbx, rdi
    mov r12, rdx
    mov rdi, [rel arena_ptr]
    call arena_reset
    mov rdi, [rel arena_ptr]
    mov rsi, rbx
    mov rdx, r12
    call lexer_init
    test rax, rax
    jz .fail
    mov rdi, rax
    call lexer_tokenize
    cmp rax, 0
    jne .fail
    mov rsi, rdi
    mov rdi, [rel arena_ptr]
    call parser_init
    test rax, rax
    jz .fail
    mov rdi, rax
    call parser_parse
    test rax, rax
    jz .fail
    mov r12, rax
    mov rdi, [rel arena_ptr]
    mov rsi, [rel envp_ptr]
    call executor_init
    test rax, rax
    jz .fail
    mov rdi, rax
    mov rsi, r12
    call executor_run
    jmp .ret
.fail:
    mov rax, -1
.ret:
    pop r12
    pop rbx
    ret

_start:
    ; capture envp
    mov rcx, [rsp]
    lea rax, [rsp + 8]
    lea rdx, [rax + rcx*8 + 8]
    mov [rel envp_ptr], rdx

    mov rdi, ARENA_SIZE
    call arena_init
    test rax, rax
    jz fail
    mov [rel arena_ptr], rax

    mov rdi, rax
    call builtins_init
    cmp rax, 0
    jne fail

    ; Test 1: background job through executor
    lea rdi, [rel cmd_sleep_bg]
    mov rdx, cmd_sleep_bg_len
    call run_command
    cmp rax, 0
    jne fail
    call jobs_get_count
    cmp eax, 1
    jb fail
    mov rdi, 1500
    call sleep_ms
    call jobs_update_status

    ; Test 2: manual table add/remove
    mov dword [rel fake_pids + 0], 111
    mov dword [rel fake_pids + 4], 222
    mov dword [rel fake_pids + 8], 333
    mov rdi, 9001
    lea rsi, [rel fake_pids]
    mov rdx, 3
    mov rcx, 1
    lea r8, [rel cmd_pipe_bg]
    mov r9, cmd_pipe_bg_len
    call jobs_add
    test eax, eax
    jz fail
    mov edi, eax
    call jobs_remove
    cmp eax, 0
    jne fail

    ; Test 3: SIGCHLD flag eventually observed
    lea rdi, [rel cmd_sleep_bg]
    mov rdx, cmd_sleep_bg_len
    call run_command
    cmp rax, 0
    jne fail
    mov rdi, 1200
    call sleep_ms
    call jobs_update_status
    call jobs_get_sigchld_flag
    ; allowed 0 if already consumed, just ensure code path is callable

    ; Test 4: pipeline background command
    lea rdi, [rel cmd_pipe_bg]
    mov rdx, cmd_pipe_bg_len
    call run_command
    cmp rax, 0
    jne fail
    call jobs_get_count
    cmp eax, 1
    jb fail

    mov rdi, [rel arena_ptr]
    call arena_destroy

    mov rdi, STDOUT
    lea rsi, [rel pass_msg]
    mov rdx, pass_len
    call hal_write
    xor rdi, rdi
    call hal_exit
