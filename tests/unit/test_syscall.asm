; test_syscall.asm
; Unit test binary for Linux x86_64 HAL syscall wrappers
; Author: Aura Shell Team
; Date: 2026-03-19

%include "src/hal/platform_defs.inc"

extern hal_write
extern hal_clock_gettime
extern hal_mmap
extern hal_munmap
extern hal_exit
extern hal_is_error

section .data
    hello_msg       db "Hello Aura", 10
    hello_len       equ $ - hello_msg

    pass_msg        db "ALL TESTS PASSED", 10
    pass_len        equ $ - pass_msg

    fail_write_msg      db "TEST FAILED: hal_write", 10
    fail_write_len      equ $ - fail_write_msg
    fail_clock_msg      db "TEST FAILED: hal_clock_gettime", 10
    fail_clock_len      equ $ - fail_clock_msg
    fail_mmap_msg       db "TEST FAILED: hal_mmap", 10
    fail_mmap_len       equ $ - fail_mmap_msg
    fail_mmap_rw_msg    db "TEST FAILED: hal_mmap_read_write", 10
    fail_mmap_rw_len    equ $ - fail_mmap_rw_msg
    fail_munmap_msg     db "TEST FAILED: hal_munmap", 10
    fail_munmap_len     equ $ - fail_munmap_msg

section .bss
    ts          resq 2    ; struct timespec { tv_sec, tv_nsec }
    mapped_ptr  resq 1

section .text
global _start

%macro write_stdout 2
    mov rdi, STDOUT
    lea rsi, [rel %1]
    mov rdx, %2
    call hal_write
%endmacro

_start:
    ; Test 1: hal_write(STDOUT, "Hello Aura\n", 11)
    mov rdi, STDOUT
    lea rsi, [rel hello_msg]
    mov rdx, hello_len
    call hal_write
    cmp rax, hello_len
    jne .fail_write

    ; Test 2: hal_clock_gettime(CLOCK_MONOTONIC, &ts)
    mov rdi, CLOCK_MONOTONIC
    lea rsi, [rel ts]
    call hal_clock_gettime
    cmp rax, 0
    jne .fail_clock
    mov rax, [rel ts]
    cmp rax, 0
    jle .fail_clock

    ; Test 3: hal_mmap(0, 4096, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0)
    xor rdi, rdi
    mov rsi, 4096
    mov rdx, PROT_READ | PROT_WRITE
    mov rcx, MAP_PRIVATE | MAP_ANONYMOUS
    mov r8, -1
    xor r9, r9
    call hal_mmap
    mov [rel mapped_ptr], rax

    mov rdi, rax
    call hal_is_error
    cmp rax, 1
    je .fail_mmap

    mov r10, [rel mapped_ptr]
    cmp r10, 0
    jle .fail_mmap

    mov rax, 0x1122334455667788
    mov [r10], rax
    mov r11, [r10]
    mov rax, 0x1122334455667788
    cmp r11, rax
    jne .fail_mmap_rw

    ; Test 4: hal_munmap(mapped_ptr, 4096)
    mov rdi, [rel mapped_ptr]
    mov rsi, 4096
    call hal_munmap
    cmp rax, 0
    jne .fail_munmap

    write_stdout pass_msg, pass_len
    xor rdi, rdi
    call hal_exit

.fail_write:
    write_stdout fail_write_msg, fail_write_len
    mov rdi, 1
    call hal_exit

.fail_clock:
    write_stdout fail_clock_msg, fail_clock_len
    mov rdi, 1
    call hal_exit

.fail_mmap:
    write_stdout fail_mmap_msg, fail_mmap_len
    mov rdi, 1
    call hal_exit

.fail_mmap_rw:
    write_stdout fail_mmap_rw_msg, fail_mmap_rw_len
    mov rdi, 1
    call hal_exit

.fail_munmap:
    write_stdout fail_munmap_msg, fail_munmap_len
    mov rdi, 1
    call hal_exit
