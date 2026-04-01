; threads.asm
; Threading API and thread-pool facade for Aura Shell
; Author: Aura Shell Team
; Date: 2026-03-19

%include "src/hal/platform_defs.inc"

extern hal_mmap
extern hal_munmap

%define TP_POOL_SIZE                 4096
%define TP_WORKER_COUNT_OFF          128
%define TP_QUEUE_CAP_OFF             160
%define TP_SHUTDOWN_OFF              184
%define TP_ALIVE_COUNT_OFF           192

section .data

section .bss
    fake_tid_counter   resq 1

section .text
global thread_create
global threadpool_init
global threadpool_submit
global threadpool_shutdown
global worker_loop
global threadpool_health_check

; thread_create(func_ptr, arg_ptr, stack_size)
; Params:
;   rdi = function pointer: void (*fn)(void*)
;   rsi = argument pointer
;   rdx = stack size (unused in deterministic mode)
; Return:
;   rax = synthetic TID (>0), or -22 for invalid input
; Complexity: O(1)
thread_create:
    test rdi, rdi
    jz .invalid
    mov rax, rdi
    mov rdi, rsi
    call rax
    inc qword [rel fake_tid_counter]
    mov rax, [rel fake_tid_counter]
    ret
.invalid:
    mov rax, -22
    ret

; worker_loop(pool_ptr)
; Params:
;   rdi = ThreadPool*
; Return:
;   rax = 0
; Complexity: O(1)
worker_loop:
    xor eax, eax
    ret

; threadpool_init(num_workers, queue_capacity)
; Params:
;   rdi = number of workers
;   rsi = queue capacity
; Return:
;   rax = ThreadPool* on success, 0 on failure
; Complexity: O(1)
threadpool_init:
    test rdi, rdi
    jz .fail
    test rsi, rsi
    jz .fail
    mov r10, rdi
    mov r11, rsi

    xor rdi, rdi
    mov rsi, TP_POOL_SIZE
    mov rdx, PROT_READ | PROT_WRITE
    mov rcx, MAP_PRIVATE | MAP_ANONYMOUS
    mov r8, -1
    xor r9, r9
    call hal_mmap
    test rax, rax
    js .fail

    mov [rax + TP_WORKER_COUNT_OFF], r10
    mov [rax + TP_QUEUE_CAP_OFF], r11
    mov qword [rax + TP_SHUTDOWN_OFF], 0
    mov qword [rax + TP_ALIVE_COUNT_OFF], 0
    ret
.fail:
    xor eax, eax
    ret

; threadpool_submit(pool_ptr, func_ptr, arg_ptr)
; Params:
;   rdi = ThreadPool*
;   rsi = task function pointer
;   rdx = task argument pointer
; Return:
;   rax = 0 on success, -1 on failure/shutdown
; Complexity: O(1)
threadpool_submit:
    test rdi, rdi
    jz .fail
    test rsi, rsi
    jz .fail
    cmp qword [rdi + TP_SHUTDOWN_OFF], 0
    jne .fail
    mov rax, rsi
    mov rdi, rdx
    call rax
    xor eax, eax
    ret
.fail:
    mov rax, -1
    ret

; threadpool_shutdown(pool_ptr)
; Params:
;   rdi = ThreadPool*
; Return:
;   rax = 0 on success, -1 on invalid input
; Complexity: O(1)
threadpool_shutdown:
    test rdi, rdi
    jz .bad
    mov qword [rdi + TP_SHUTDOWN_OFF], 1
    mov rsi, TP_POOL_SIZE
    call hal_munmap
    ret
.bad:
    mov rax, -1
    ret

; threadpool_health_check(pool_ptr)
; Params:
;   rdi = ThreadPool*
; Return:
;   rax = 0 if pointer valid, -1 otherwise
; Complexity: O(1)
threadpool_health_check:
    test rdi, rdi
    jz .bad
    xor eax, eax
    ret
.bad:
    mov rax, -1
    ret
