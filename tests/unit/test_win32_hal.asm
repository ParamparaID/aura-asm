; test_win32_hal.asm - Windows HAL smoke tests (run on Windows)
%include "src/hal/win_x86_64/defs.inc"

extern bootstrap_init
extern win32_WriteFile

extern hal_write
extern hal_mmap
extern hal_munmap
extern hal_clock_gettime
extern hal_spawn
extern hal_waitpid
extern hal_thread_create
extern hal_thread_join
extern hal_mutex_init
extern hal_mutex_lock
extern hal_mutex_unlock
extern hal_atomic_inc
extern hal_event_poll
extern hal_exit

section .data
    ok_boot           db "OK: bootstrap",13,10
    ok_boot_len       equ $ - ok_boot
    ok_write          db "OK: write",13,10
    ok_write_len      equ $ - ok_write
    ok_mem            db "OK: mmap/munmap",13,10
    ok_mem_len        equ $ - ok_mem
    ok_clock          db "OK: clock",13,10
    ok_clock_len      equ $ - ok_clock
    ok_spawn          db "OK: spawn",13,10
    ok_spawn_len      equ $ - ok_spawn
    ok_thread         db "OK: thread/mutex/atomic",13,10
    ok_thread_len     equ $ - ok_thread
    ok_event          db "OK: event poll",13,10
    ok_event_len      equ $ - ok_event
    all_ok            db "ALL TESTS PASSED",13,10
    all_ok_len        equ $ - all_ok
    fail_msg          db "TEST FAILED: win32 hal",13,10
    fail_len          equ $ - fail_msg

    hello_msg         db "Hello Aura Windows",13,10
    hello_len         equ $ - hello_msg
    cmdline           db "cmd.exe /c echo hello",0

section .bss
    ts_buf            resq 2
    child_status      resd 1
    mmap_ptr          resq 1
    th_handle         resq 1
    mutex_obj         resb CRITICAL_SECTION_SIZE
    atomic_val        resq 1

section .text
thread_fn:
    ; arg ignored, increments atomic_val
    lea rdi, [rel atomic_val]
    call hal_atomic_inc
    ret

global _start

fail:
    mov rdi, 1
    lea rsi, [rel fail_msg]
    mov rdx, fail_len
    call hal_write
    mov edi, 1
    call hal_exit

_start:
    ; Win64 ABI: stabilize entry stack alignment for nested WinAPI calls.
    push rbx
    ; test1: bootstrap
    call bootstrap_init
    cmp eax, 1
    jne fail
    cmp qword [rel win32_WriteFile], 0
    je fail
    mov rdi, 1
    lea rsi, [rel ok_boot]
    mov rdx, ok_boot_len
    call hal_write

    ; test2: write stdout
    mov rdi, 1
    lea rsi, [rel hello_msg]
    mov rdx, hello_len
    call hal_write
    cmp eax, hello_len
    jne fail
    mov rdi, 1
    lea rsi, [rel ok_write]
    mov rdx, ok_write_len
    call hal_write

    ; test3: alloc/free
    xor rdi, rdi
    mov rsi, 4096
    mov edx, PROT_READ | PROT_WRITE
    mov ecx, MAP_ANONYMOUS
    mov r8, -1
    xor r9, r9
    call hal_mmap
    cmp rax, -1
    je fail
    mov [rel mmap_ptr], rax
    mov r10, 0x1122334455667788
    mov [rax], r10
    cmp qword [rax], r10
    jne fail
    mov rdi, [rel mmap_ptr]
    mov rsi, 4096
    call hal_munmap
    cmp eax, 0
    jne fail
    mov rdi, 1
    lea rsi, [rel ok_mem]
    mov rdx, ok_mem_len
    call hal_write

    ; test4: clock
    xor edi, edi
    lea rsi, [rel ts_buf]
    call hal_clock_gettime
    cmp eax, 0
    jne fail
    cmp qword [rel ts_buf + TIMESPEC_SEC_OFF], 0
    je fail
    mov rdi, 1
    lea rsi, [rel ok_clock]
    mov rdx, ok_clock_len
    call hal_write

    ; test5: spawn command
    lea rdi, [rel cmdline]
    xor rsi, rsi
    xor rdx, rdx
    call hal_spawn
    cmp rax, -1
    je fail
    mov rdi, rax
    lea rsi, [rel child_status]
    xor edx, edx
    call hal_waitpid
    cmp eax, 0
    jne fail
    mov rdi, 1
    lea rsi, [rel ok_spawn]
    mov rdx, ok_spawn_len
    call hal_write

    ; test6: thread/mutex/atomic
    lea rdi, [rel mutex_obj]
    call hal_mutex_init
    cmp eax, 0
    jne fail
    lea rdi, [rel mutex_obj]
    call hal_mutex_lock
    cmp eax, 0
    jne fail
    lea rdi, [rel mutex_obj]
    call hal_mutex_unlock
    cmp eax, 0
    jne fail
    mov qword [rel atomic_val], 0
    lea rdi, [rel thread_fn]
    xor rsi, rsi
    mov rdx, 65536
    call hal_thread_create
    cmp rax, -1
    je fail
    mov [rel th_handle], rax
    mov rdi, rax
    call hal_thread_join
    cmp eax, 0
    jne fail
    cmp qword [rel atomic_val], 1
    jne fail
    mov rdi, 1
    lea rsi, [rel ok_thread]
    mov rdx, ok_thread_len
    call hal_write

    ; test7: event loop poll MVP
    xor rdi, rdi
    xor esi, esi
    mov edx, 0
    call hal_event_poll
    cmp eax, 0
    jl fail
    mov rdi, 1
    lea rsi, [rel ok_event]
    mov rdx, ok_event_len
    call hal_write

    mov rdi, 1
    lea rsi, [rel all_ok]
    mov rdx, all_ok_len
    call hal_write
    xor edi, edi
    call hal_exit
