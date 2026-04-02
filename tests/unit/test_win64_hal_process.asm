; test_win64_hal_process.asm — STEP 60D: CreateProcess, pipe capture, pipeline
%include "src/hal/win_x86_64/defs.inc"

extern bootstrap_init
extern hal_pipe
extern hal_spawn
extern hal_close
extern hal_read
extern hal_spawn_wait
extern hal_spawn_pipeline
extern hal_pipeline_stdout_read
extern win32_ExitProcess
extern win64_call_1
extern hal_write
section .rodata
msg_pass     db "ALL TESTS PASSED", 13, 10
msg_pass_len equ $ - msg_pass
msg_fail     db "TEST FAILED", 13, 10
msg_fail_len equ $ - msg_fail
msg_f_pipe1  db "FAIL: pipe", 13, 10
msg_f_pipe1_len equ $ - msg_f_pipe1
msg_f_sp1    db "FAIL: spawn1", 13, 10
msg_f_sp1_len equ $ - msg_f_sp1
msg_f_rd1    db "FAIL: read1", 13, 10
msg_f_rd1_len equ $ - msg_f_rd1
msg_f_ln1    db "FAIL: len1", 13, 10
msg_f_ln1_len equ $ - msg_f_ln1
msg_f_cm1    db "FAIL: cmp1", 13, 10
msg_f_cm1_len equ $ - msg_f_cm1
msg_f_wt1    db "FAIL: wait1", 13, 10
msg_f_wt1_len equ $ - msg_f_wt1
msg_f_pipe   db "FAIL: pipeline", 13, 10
msg_f_pipe_len equ $ - msg_f_pipe

src_echo     db "cmd.exe /c echo hello", 0
src_find     db "cmd.exe /c findstr hello", 0

expect       db 'h', 'e', 'l', 'l', 'o', 13, 10
expect_len   equ $ - expect

section .bss
align 8
    out_buf      resb 256
    cmd_echo     resb 128
    cmd_find     resb 128
    cmdv         resq 4

section .text

write_stdout:
    mov rdi, STDOUT
    mov rsi, rdx
    mov edx, r8d
    jmp hal_write

global _start
_start:
    sub rsp, 8
    call bootstrap_init
    cmp eax, 1
    jne .fail

    ; --- copy mutable cmd lines ---
    lea rdi, [rel cmd_echo]
    lea rsi, [rel src_echo]
.copy_e:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    test al, al
    jnz .copy_e

    lea rdi, [rel cmd_find]
    lea rsi, [rel src_find]
.copy_f:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    test al, al
    jnz .copy_f

    ; --- Test 1: single spawn, capture stdout (stack layout like win_capture_cmd_output) ---
    sub rsp, 24
    lea rdi, [rsp]
    call hal_pipe
    cmp eax, 0
    jne .fail_pipe1_stk

    lea rdi, [rel cmd_echo]
    xor esi, esi
    mov rdx, [rsp + 8]
    mov rcx, rdx
    call hal_spawn
    cmp rax, -1
    je .fail_spawn_cleanup1_stk
    mov [rsp + 16], rax

    mov rdi, [rsp + 8]
    call hal_close

    mov rdi, [rsp]
    lea rsi, [rel out_buf]
    mov byte [rsi], 0
    mov edx, 256
    call hal_read
    cmp eax, 0
    jl .fail_read_cleanup1_stk
    mov r14d, eax

    mov rdi, [rsp]
    call hal_close

    mov rdi, [rsp + 16]
    call hal_spawn_wait
    cmp eax, -1
    je .fail_wt1_stk

    cmp r14d, expect_len
    jne .fail_ln1_stk
    lea rsi, [rel expect]
    lea rdi, [rel out_buf]
    mov edx, expect_len
.cm1:
    test edx, edx
    jz .t2_pipeline
    movzx eax, byte [rdi]
    movzx ebx, byte [rsi]
    cmp eax, ebx
    jne .fail_cm1_stk
    inc rdi
    inc rsi
    dec edx
    jmp .cm1

    ; --- Test 2: pipeline ---
.t2_pipeline:
    lea rax, [rel cmd_echo]
    mov [rel cmdv], rax
    lea rax, [rel cmd_find]
    mov [rel cmdv + 8], rax

    lea rdi, [rel cmdv]
    mov esi, 2
    call hal_spawn_pipeline
    cmp rax, -1
    je .fail_pipe
    mov r12, rax

    mov rdi, [rel hal_pipeline_stdout_read]
    test rdi, rdi
    jz .fail_pipe_wait

    lea rsi, [rel out_buf]
    mov byte [rsi], 0
    mov edx, 256
    call hal_read
    cmp eax, 0
    jl .fail_pipe
    mov r14d, eax

    mov rdi, [rel hal_pipeline_stdout_read]
    call hal_close

    mov rdi, r12
    call hal_spawn_wait
    cmp eax, -1
    je .fail_pipe

    cmp r14d, expect_len
    jne .fail_pipe
    lea rsi, [rel expect]
    lea rdi, [rel out_buf]
    mov edx, expect_len
.cm2:
    test edx, edx
    jz .all_ok
    movzx eax, byte [rdi]
    movzx ebx, byte [rsi]
    cmp eax, ebx
    jne .fail_pipe
    inc rdi
    inc rsi
    dec edx
    jmp .cm2

.all_ok:
    lea rdx, [rel msg_pass]
    mov r8d, msg_pass_len
    call write_stdout
    mov rdi, [rel win32_ExitProcess]
    xor esi, esi
    call win64_call_1

.fail_pipe1_stk:
    add rsp, 24
    lea rdx, [rel msg_f_pipe1]
    mov r8d, msg_f_pipe1_len
    jmp .fail_out
.fail_spawn_cleanup1_stk:
    mov rdi, [rsp]
    call hal_close
    mov rdi, [rsp + 8]
    call hal_close
    add rsp, 24
    lea rdx, [rel msg_f_sp1]
    mov r8d, msg_f_sp1_len
    jmp .fail_out
.fail_read_cleanup1_stk:
    mov rdi, [rsp]
    call hal_close
    mov rdi, [rsp + 16]
    call hal_spawn_wait
    add rsp, 24
    lea rdx, [rel msg_f_rd1]
    mov r8d, msg_f_rd1_len
    jmp .fail_out
.fail_ln1_stk:
    add rsp, 24
    lea rdx, [rel msg_f_ln1]
    mov r8d, msg_f_ln1_len
    jmp .fail_out
.fail_cm1_stk:
    add rsp, 24
    lea rdx, [rel msg_f_cm1]
    mov r8d, msg_f_cm1_len
    jmp .fail_out
.fail_wt1_stk:
    add rsp, 24
    lea rdx, [rel msg_f_wt1]
    mov r8d, msg_f_wt1_len
    jmp .fail_out
.fail_pipe_wait:
    mov rdi, r12
    call hal_spawn_wait
.fail_pipe:
    lea rdx, [rel msg_f_pipe]
    mov r8d, msg_f_pipe_len
    jmp .fail_out
.fail:
    lea rdx, [rel msg_fail]
    mov r8d, msg_fail_len
.fail_out:
    call write_stdout
    mov rdi, [rel win32_ExitProcess]
    mov esi, 1
    call win64_call_1
