; test_threads.asm
; Unit tests for threading, locks and thread pool (Aura Shell)
; Author: Aura Shell Team
; Date: 2026-03-19

%include "src/hal/platform_defs.inc"

extern hal_write
extern hal_exit
extern thread_create
extern threadpool_init
extern threadpool_submit
extern threadpool_shutdown
extern threadpool_health_check
extern spin_lock
extern spin_unlock
extern mutex_init
extern mutex_lock
extern mutex_unlock
extern atomic_inc

%define THREADS_4            4
%define ITERS_PER_THREAD     10000
%define EXPECTED_COUNT       40000
%define TASK_COUNT           100

section .data
    pass_msg             db "ALL TESTS PASSED", 10
    pass_len             equ $ - pass_msg

    fail_t1_msg          db "TEST FAILED: thread_basic", 10
    fail_t1_len          equ $ - fail_t1_msg
    fail_t2_msg          db "TEST FAILED: spinlock", 10
    fail_t2_len          equ $ - fail_t2_msg
    fail_t3_msg          db "TEST FAILED: mutex", 10
    fail_t3_len          equ $ - fail_t3_msg
    fail_t4_msg          db "TEST FAILED: threadpool", 10
    fail_t4_len          equ $ - fail_t4_msg

section .bss
    shared_value         resq 1

    spin_lock_var        resq 1
    spin_counter         resq 1
    spin_done            resq 1

    mutex_var            resq 1
    mutex_counter        resq 1
    mutex_done           resq 1

    pool_counter         resq 1
    pool_ptr             resq 1

    spin_args            resq 3    ; counter, lock, done
    mutex_args           resq 3    ; counter, lock, done

section .text
global _start

%macro write_stdout 2
    mov rdi, STDOUT
    lea rsi, [rel %1]
    mov rdx, %2
    call hal_write
%endmacro

%macro fail_exit 2
    write_stdout %1, %2
    mov rdi, 1
    call hal_exit
%endmacro

; Worker: sets *arg = 42
worker_set_42:
    mov qword [rdi], 42
    ret

; Worker: protected increment via spin lock, then done++
worker_spin_inc:
    push rbx
    push r12
    mov rbx, rdi
    mov r12d, ITERS_PER_THREAD
.spin_loop:
    test r12d, r12d
    jz .spin_done
    mov rdi, [rbx + 8]
    call spin_lock
    mov rax, [rbx]
    inc qword [rax]
    mov rdi, [rbx + 8]
    call spin_unlock
    dec r12d
    jmp .spin_loop
.spin_done:
    mov rdi, [rbx + 16]
    call atomic_inc
    pop r12
    pop rbx
    ret

; Worker: protected increment via mutex, then done++
worker_mutex_inc:
    push rbx
    push r12
    mov rbx, rdi
    mov r12d, ITERS_PER_THREAD
.mutex_loop:
    test r12d, r12d
    jz .mutex_done
    mov rdi, [rbx + 8]
    call mutex_lock
    mov rax, [rbx]
    inc qword [rax]
    mov rdi, [rbx + 8]
    call mutex_unlock
    dec r12d
    jmp .mutex_loop
.mutex_done:
    mov rdi, [rbx + 16]
    call atomic_inc
    pop r12
    pop rbx
    ret

; Task: atomic_inc(arg_ptr)
task_inc:
    call atomic_inc
    ret

_start:
    ; ---- Test 1: basic thread_create ----
    mov qword [rel shared_value], 0
    lea rdi, [rel worker_set_42]
    lea rsi, [rel shared_value]
    xor rdx, rdx
    call thread_create
    test rax, rax
    jle .fail_t1

    mov ecx, 5000000
.wait_42:
    cmp qword [rel shared_value], 42
    je .t1_ok
    pause
    dec ecx
    jnz .wait_42
    jmp .fail_t1
.t1_ok:

    ; ---- Test 2: spinlock with 4 threads ----
    mov qword [rel spin_lock_var], 0
    mov qword [rel spin_counter], 0
    mov qword [rel spin_done], 0
    lea rax, [rel spin_counter]
    mov [rel spin_args + 0], rax
    lea rax, [rel spin_lock_var]
    mov [rel spin_args + 8], rax
    lea rax, [rel spin_done]
    mov [rel spin_args + 16], rax

    mov r12d, THREADS_4
.spawn_spin:
    lea rdi, [rel worker_spin_inc]
    lea rsi, [rel spin_args]
    xor rdx, rdx
    call thread_create
    test rax, rax
    jle .fail_t2
    dec r12d
    jnz .spawn_spin

    mov ecx, 20000000
.wait_spin_done:
    cmp qword [rel spin_done], THREADS_4
    je .check_spin_count
    pause
    dec ecx
    jnz .wait_spin_done
    jmp .fail_t2
.check_spin_count:
    cmp qword [rel spin_counter], EXPECTED_COUNT
    jne .fail_t2

    ; ---- Test 3: mutex with 4 threads ----
    lea rdi, [rel mutex_var]
    call mutex_init
    mov qword [rel mutex_counter], 0
    mov qword [rel mutex_done], 0
    lea rax, [rel mutex_counter]
    mov [rel mutex_args + 0], rax
    lea rax, [rel mutex_var]
    mov [rel mutex_args + 8], rax
    lea rax, [rel mutex_done]
    mov [rel mutex_args + 16], rax

    mov r12d, THREADS_4
.spawn_mutex:
    lea rdi, [rel worker_mutex_inc]
    lea rsi, [rel mutex_args]
    xor rdx, rdx
    call thread_create
    test rax, rax
    jle .fail_t3
    dec r12d
    jnz .spawn_mutex

    mov ecx, 20000000
.wait_mutex_done:
    cmp qword [rel mutex_done], THREADS_4
    je .check_mutex_count
    pause
    dec ecx
    jnz .wait_mutex_done
    jmp .fail_t3
.check_mutex_count:
    cmp qword [rel mutex_counter], EXPECTED_COUNT
    jne .fail_t3

    ; ---- Test 4: thread pool ----
    mov qword [rel pool_counter], 0
    mov rdi, 4
    mov rsi, 128
    call threadpool_init
    test rax, rax
    jz .fail_t4
    mov [rel pool_ptr], rax

    xor r12d, r12d
.submit_loop:
    cmp r12d, TASK_COUNT
    jae .wait_pool
    mov rdi, [rel pool_ptr]
    lea rsi, [rel task_inc]
    lea rdx, [rel pool_counter]
    call threadpool_submit
    cmp rax, 0
    je .submitted
    ; On temporary queue pressure, let workers drain and retry.
    mov rdi, [rel pool_ptr]
    call threadpool_health_check
    pause
    jmp .submit_loop
.submitted:
    inc r12d
    jmp .submit_loop

.wait_pool:
    mov r12d, 20000000
.wait_pool_counter:
    cmp qword [rel pool_counter], TASK_COUNT
    je .shutdown_pool
    mov rdi, [rel pool_ptr]
    call threadpool_health_check
    pause
    dec r12d
    jnz .wait_pool_counter
    jmp .fail_t4

.shutdown_pool:
    mov rdi, [rel pool_ptr]
    call threadpool_shutdown
    cmp rax, 0
    jne .fail_t4

    write_stdout pass_msg, pass_len
    xor rdi, rdi
    call hal_exit

.fail_t1:
    fail_exit fail_t1_msg, fail_t1_len
.fail_t2:
    fail_exit fail_t2_msg, fail_t2_len
.fail_t3:
    fail_exit fail_t3_msg, fail_t3_len
.fail_t4:
    ; Try clean shutdown if pool exists, then fail.
    mov rax, [rel pool_ptr]
    test rax, rax
    jz .emit_t4
    mov rdi, rax
    call threadpool_shutdown
.emit_t4:
    fail_exit fail_t4_msg, fail_t4_len
