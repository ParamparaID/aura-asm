; test_win64_hal_core.asm — STEP 60B gate (mmap/clock/thread/atomic via win64_call HAL)
%include "src/hal/win_x86_64/defs.inc"

extern bootstrap_init
extern stdout_handle
extern win32_WriteFile
extern win32_ExitProcess
extern win64_call_1
extern win64_call_5
extern hal_mmap
extern hal_munmap
extern hal_clock_gettime
extern hal_thread_create
extern hal_thread_join
extern hal_atomic_inc

section .rodata
msg_pass     db "ALL TESTS PASSED", 13, 10
msg_pass_len equ $ - msg_pass
msg_fail     db "TEST FAILED", 13, 10
msg_fail_len equ $ - msg_fail
msg_f_mmap   db "FAIL: mmap/munmap", 13, 10
msg_f_mmap_len equ $ - msg_f_mmap
msg_f_clock  db "FAIL: clock", 13, 10
msg_f_clock_len equ $ - msg_f_clock
msg_f_thread db "FAIL: thread/atomic", 13, 10
msg_f_thread_len equ $ - msg_f_thread
pat_qword    dq 0x1111111111111111

section .bss
    map_ptr      resq 1
    ts_buf       resq 2
    th_handle    resq 1
    shared_ctr   resq 1

section .text

thread_worker:
    lea rdi, [rel shared_ctr]
    call hal_atomic_inc
    ret

; rdx = msg, r8d = len
write_stdout:
    sub rsp, 24
    mov rdi, [rel win32_WriteFile]
    mov rsi, [rel stdout_handle]
    mov ecx, r8d
    lea r8, [rsp+16]
    xor r9d, r9d
    call win64_call_5
    add rsp, 24
    ret

global _start
_start:
    sub rsp, 8
    call bootstrap_init
    cmp eax, 1
    jne .fail

    ; --- 64 KiB map, pattern, verify, unmap (size must be 64 KiB per gate) ---
    xor rdi, rdi
    mov esi, 0x10000
    mov edx, PROT_READ | PROT_WRITE
    mov ecx, MAP_ANONYMOUS
    mov r8, -1
    xor r9, r9
    call hal_mmap
    cmp rax, -1
    je .fail_mmap
    mov [rel map_ptr], rax
    mov rbx, rax
    mov ecx, 8192
    mov rdx, [rel pat_qword]
.fill:
    mov [rbx], rdx
    add rbx, 8
    dec ecx
    jnz .fill
    mov rbx, [rel map_ptr]
    mov ecx, 8192
.check:
    cmp qword [rbx], rdx
    jne .fail_mmap
    add rbx, 8
    dec ecx
    jnz .check
    mov rdi, [rel map_ptr]
    mov esi, 0x10000
    call hal_munmap
    cmp eax, 0
    jne .fail_mmap

    ; --- monotonic clock ---
    xor edi, edi
    lea rsi, [rel ts_buf]
    call hal_clock_gettime
    cmp eax, 0
    jne .fail_clock
    mov rax, [rel ts_buf + TIMESPEC_SEC_OFF]
    or rax, [rel ts_buf + TIMESPEC_NSEC_OFF]
    jz .fail_clock

    ; --- thread + atomic ---
    mov qword [rel shared_ctr], 0
    lea rdi, [rel thread_worker]
    xor esi, esi
    mov rdx, 65536
    call hal_thread_create
    cmp rax, -1
    je .fail_thread
    mov [rel th_handle], rax
    mov rdi, rax
    call hal_thread_join
    cmp eax, 0
    jne .fail_thread
    cmp qword [rel shared_ctr], 1
    jne .fail_thread

    lea rdx, [rel msg_pass]
    mov r8d, msg_pass_len
    call write_stdout
    mov rdi, [rel win32_ExitProcess]
    xor esi, esi
    call win64_call_1

.fail_mmap:
    lea rdx, [rel msg_f_mmap]
    mov r8d, msg_f_mmap_len
    jmp .fail_out
.fail_clock:
    lea rdx, [rel msg_f_clock]
    mov r8d, msg_f_clock_len
    jmp .fail_out
.fail_thread:
    lea rdx, [rel msg_f_thread]
    mov r8d, msg_f_thread_len
    jmp .fail_out
.fail:
    lea rdx, [rel msg_fail]
    mov r8d, msg_fail_len
.fail_out:
    call write_stdout
    mov rdi, [rel win32_ExitProcess]
    mov esi, 1
    call win64_call_1
