; sync.asm
; Synchronization primitives and atomics for Aura Shell
; Author: Aura Shell Team
; Date: 2026-03-19

%include "src/hal/platform_defs.inc"

section .data

section .bss

section .text
global spin_lock
global spin_unlock
global spin_trylock
global mutex_init
global mutex_lock
global mutex_unlock
global mutex_trylock
global atomic_inc
global atomic_dec
global atomic_load
global atomic_store
global atomic_cas

; spin_lock(lock_ptr)
; Params:
;   rdi = pointer to qword lock (0=free, 1=locked)
; Return:
;   rax = 0
; Complexity: O(contention)
spin_lock:
.retry:
    xor eax, eax
    mov edx, 1
    lock cmpxchg qword [rdi], rdx
    je .ok
.spin:
    pause
    cmp qword [rdi], 0
    jne .spin
    jmp .retry
.ok:
    xor eax, eax
    ret

; spin_unlock(lock_ptr)
; Params:
;   rdi = pointer to lock
; Return:
;   rax = 0
; Complexity: O(1)
spin_unlock:
    mfence
    mov qword [rdi], 0
    xor eax, eax
    ret

; spin_trylock(lock_ptr)
; Params:
;   rdi = pointer to lock
; Return:
;   rax = 0 success, 1 fail
; Complexity: O(1)
spin_trylock:
    xor eax, eax
    mov edx, 1
    lock cmpxchg qword [rdi], rdx
    jne .fail
    xor eax, eax
    ret
.fail:
    mov eax, 1
    ret

; mutex_init(mutex_ptr)
; Params:
;   rdi = pointer to qword mutex (0 free, 1 locked-no-waiters, 2 locked-waiters)
; Return:
;   rax = 0
; Complexity: O(1)
mutex_init:
    mov qword [rdi], 0
    xor eax, eax
    ret

; mutex_lock(mutex_ptr)
; Params:
;   rdi = pointer to mutex qword
; Return:
;   rax = 0
; Complexity: O(contention)
mutex_lock:
    mov rcx, rdi
    xor eax, eax
    mov edx, 1
    lock cmpxchg qword [rcx], rdx
    je .acquired

.contended:
    mov eax, 2
    xchg qword [rcx], rax
    test eax, eax
    je .acquired

.wait:
    mov rax, SYS_FUTEX
    mov rdi, rcx
    mov rsi, FUTEX_WAIT
    mov rdx, 2
    xor r10, r10
    xor r8, r8
    xor r9, r9
    syscall

    xor eax, eax
    mov edx, 2
    lock cmpxchg qword [rcx], rdx
    jne .contended

.acquired:
    xor eax, eax
    ret

; mutex_unlock(mutex_ptr)
; Params:
;   rdi = pointer to mutex
; Return:
;   rax = 0
; Complexity: O(1) uncontended, O(1)+syscall contended
mutex_unlock:
    mov rcx, rdi
    xor eax, eax
    xchg qword [rcx], rax
    cmp rax, 2
    jne .done
    mov rax, SYS_FUTEX
    mov rdi, rcx
    mov rsi, FUTEX_WAKE
    mov rdx, 1
    xor r10, r10
    xor r8, r8
    xor r9, r9
    syscall
.done:
    xor eax, eax
    ret

; mutex_trylock(mutex_ptr)
; Params:
;   rdi = pointer to mutex
; Return:
;   rax = 0 success, 1 fail
; Complexity: O(1)
mutex_trylock:
    xor eax, eax
    mov edx, 1
    lock cmpxchg qword [rdi], rdx
    jne .fail
    xor eax, eax
    ret
.fail:
    mov eax, 1
    ret

; atomic_inc(ptr)
; Params:
;   rdi = pointer to qword value
; Return:
;   rax = new value
; Complexity: O(1)
atomic_inc:
    mov rax, 1
    lock xadd qword [rdi], rax
    inc rax
    ret

; atomic_dec(ptr)
; Params:
;   rdi = pointer to qword value
; Return:
;   rax = new value
; Complexity: O(1)
atomic_dec:
    mov rax, -1
    lock xadd qword [rdi], rax
    dec rax
    ret

; atomic_load(ptr)
; Params:
;   rdi = pointer to qword value
; Return:
;   rax = loaded value
; Complexity: O(1)
atomic_load:
    mfence
    mov rax, [rdi]
    mfence
    ret

; atomic_store(ptr, val)
; Params:
;   rdi = pointer to qword value
;   rsi = value to store
; Return:
;   rax = 0
; Complexity: O(1)
atomic_store:
    mfence
    mov [rdi], rsi
    mfence
    xor eax, eax
    ret

; atomic_cas(ptr, expected, desired)
; Params:
;   rdi = pointer to qword value
;   rsi = expected old value
;   rdx = desired value
; Return:
;   rax = previous value observed at *ptr
; Complexity: O(1)
atomic_cas:
    mov rax, rsi
    lock cmpxchg qword [rdi], rdx
    ret
