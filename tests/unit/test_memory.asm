; test_memory.asm
; Unit tests for arena/slab allocators (Aura Shell)
; Author: Aura Shell Team
; Date: 2026-03-19

%include "src/hal/linux_x86_64/defs.inc"

extern hal_write
extern hal_exit
extern arena_init
extern arena_alloc
extern arena_reset
extern arena_destroy
extern slab_init
extern slab_alloc
extern slab_free
extern slab_destroy

%define ARENA_REQ_SIZE 65536
%define ARENA_ALLOC_SIZE 100
%define ARENA_ALLOC_ALIGNED 104
%define SLAB_OBJ_SIZE 64
%define SLAB_COUNT 100

section .data
    pass_msg            db "ALL TESTS PASSED", 10
    pass_len            equ $ - pass_msg

    fail_arena_init_msg         db "TEST FAILED: arena_init", 10
    fail_arena_init_len         equ $ - fail_arena_init_msg
    fail_arena_seq_msg          db "TEST FAILED: arena_alloc_seq", 10
    fail_arena_seq_len          equ $ - fail_arena_seq_msg
    fail_arena_overflow_msg     db "TEST FAILED: arena_overflow", 10
    fail_arena_overflow_len     equ $ - fail_arena_overflow_msg
    fail_arena_reset_msg        db "TEST FAILED: arena_reset", 10
    fail_arena_reset_len        equ $ - fail_arena_reset_msg
    fail_arena_destroy_msg      db "TEST FAILED: arena_destroy", 10
    fail_arena_destroy_len      equ $ - fail_arena_destroy_msg

    fail_slab_init_msg          db "TEST FAILED: slab_init", 10
    fail_slab_init_len          equ $ - fail_slab_init_msg
    fail_slab_alloc100_msg      db "TEST FAILED: slab_alloc_100", 10
    fail_slab_alloc100_len      equ $ - fail_slab_alloc100_msg
    fail_slab_unique_msg        db "TEST FAILED: slab_unique", 10
    fail_slab_unique_len        equ $ - fail_slab_unique_msg
    fail_slab_full_msg          db "TEST FAILED: slab_full", 10
    fail_slab_full_len          equ $ - fail_slab_full_msg
    fail_slab_refill_msg        db "TEST FAILED: slab_refill", 10
    fail_slab_refill_len        equ $ - fail_slab_refill_msg
    fail_slab_stress_msg        db "TEST FAILED: slab_stress", 10
    fail_slab_stress_len        equ $ - fail_slab_stress_msg
    fail_slab_destroy_msg       db "TEST FAILED: slab_destroy", 10
    fail_slab_destroy_len       equ $ - fail_slab_destroy_msg

section .bss
    arena_ptr        resq 1
    slab_ptr         resq 1
    first_arena_ptr  resq 1
    obj_ptrs         resq SLAB_COUNT

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

_start:
    ; --- Arena tests ---
    mov rdi, ARENA_REQ_SIZE
    call arena_init
    test rax, rax
    jz .fail_arena_init
    mov [rel arena_ptr], rax

    ; Allocate 10 blocks of 100 bytes and verify strict sequence with 8-byte alignment.
    xor r12d, r12d
.arena_seq_loop:
    cmp r12d, 10
    jae .arena_seq_done
    mov rdi, [rel arena_ptr]
    mov rsi, ARENA_ALLOC_SIZE
    call arena_alloc
    test rax, rax
    jz .fail_arena_seq
    test r12d, r12d
    jnz .arena_check_next
    mov [rel first_arena_ptr], rax
    jmp .arena_seq_advance
.arena_check_next:
    mov rcx, [rel first_arena_ptr]
    mov rdx, r12
    imul rdx, ARENA_ALLOC_ALIGNED
    add rcx, rdx
    cmp rax, rcx
    jne .fail_arena_seq
.arena_seq_advance:
    inc r12d
    jmp .arena_seq_loop
.arena_seq_done:

    ; Allocate until exhaustion: eventually must return 0.
    mov r12d, 2000
.arena_overflow_loop:
    mov rdi, [rel arena_ptr]
    mov rsi, ARENA_ALLOC_SIZE
    call arena_alloc
    test rax, rax
    jz .arena_overflow_ok
    dec r12d
    jnz .arena_overflow_loop
    jmp .fail_arena_overflow
.arena_overflow_ok:

    ; Reset and ensure allocation works again from the start.
    mov rdi, [rel arena_ptr]
    call arena_reset
    mov rdi, [rel arena_ptr]
    mov rsi, ARENA_ALLOC_SIZE
    call arena_alloc
    test rax, rax
    jz .fail_arena_reset
    cmp rax, [rel first_arena_ptr]
    jne .fail_arena_reset

    mov rdi, [rel arena_ptr]
    call arena_destroy
    cmp rax, 0
    jne .fail_arena_destroy

    ; --- Slab tests ---
    mov rdi, SLAB_OBJ_SIZE
    mov rsi, SLAB_COUNT
    call slab_init
    test rax, rax
    jz .fail_slab_init
    mov [rel slab_ptr], rax

    ; Allocate full slab: 100 objects.
    xor r12d, r12d
.slab_alloc_loop:
    cmp r12d, SLAB_COUNT
    jae .slab_alloc_done
    mov rdi, [rel slab_ptr]
    call slab_alloc
    test rax, rax
    jz .fail_slab_alloc100
    mov [obj_ptrs + r12*8], rax
    inc r12d
    jmp .slab_alloc_loop
.slab_alloc_done:

    ; Verify uniqueness (O(n^2), small n=100).
    xor r8d, r8d
.uniq_outer:
    cmp r8d, SLAB_COUNT
    jae .uniq_done
    mov r9, [obj_ptrs + r8*8]
    mov r10d, r8d
    inc r10d
.uniq_inner:
    cmp r10d, SLAB_COUNT
    jae .uniq_next
    mov r11, [obj_ptrs + r10*8]
    cmp r9, r11
    je .fail_slab_unique
    inc r10d
    jmp .uniq_inner
.uniq_next:
    inc r8d
    jmp .uniq_outer
.uniq_done:

    ; 101st alloc must fail (slab full).
    mov rdi, [rel slab_ptr]
    call slab_alloc
    test rax, rax
    jnz .fail_slab_full

    ; Free first 50 objects, then allocate 50 objects again.
    xor r12d, r12d
.free_50_loop:
    cmp r12d, 50
    jae .alloc_50_again
    mov rdi, [rel slab_ptr]
    mov rsi, [obj_ptrs + r12*8]
    call slab_free
    cmp rax, 0
    jne .fail_slab_refill
    inc r12d
    jmp .free_50_loop

.alloc_50_again:
    xor r12d, r12d
.alloc_50_loop:
    cmp r12d, 50
    jae .stress_test
    mov rdi, [rel slab_ptr]
    call slab_alloc
    test rax, rax
    jz .fail_slab_refill
    mov [obj_ptrs + r12*8], rax
    inc r12d
    jmp .alloc_50_loop

    ; Stress: free/alloc in cycle to detect free-list corruption.
.stress_test:
    xor r12d, r12d
.stress_loop:
    cmp r12d, 10000
    jae .slab_destroy_step
    mov eax, r12d
    xor edx, edx
    mov ecx, SLAB_COUNT
    div ecx
    mov r9d, edx
    mov r14d, r9d

    mov rdi, [rel slab_ptr]
    mov rsi, [obj_ptrs + r14*8]
    call slab_free
    cmp rax, 0
    jne .fail_slab_stress

    mov rdi, [rel slab_ptr]
    call slab_alloc
    test rax, rax
    jz .fail_slab_stress
    mov [obj_ptrs + r14*8], rax

    inc r12d
    jmp .stress_loop

.slab_destroy_step:
    mov rdi, [rel slab_ptr]
    call slab_destroy
    cmp rax, 0
    jne .fail_slab_destroy

    write_stdout pass_msg, pass_len
    xor rdi, rdi
    call hal_exit

.fail_arena_init:
    fail_exit fail_arena_init_msg, fail_arena_init_len
.fail_arena_seq:
    fail_exit fail_arena_seq_msg, fail_arena_seq_len
.fail_arena_overflow:
    fail_exit fail_arena_overflow_msg, fail_arena_overflow_len
.fail_arena_reset:
    fail_exit fail_arena_reset_msg, fail_arena_reset_len
.fail_arena_destroy:
    fail_exit fail_arena_destroy_msg, fail_arena_destroy_len

.fail_slab_init:
    fail_exit fail_slab_init_msg, fail_slab_init_len
.fail_slab_alloc100:
    fail_exit fail_slab_alloc100_msg, fail_slab_alloc100_len
.fail_slab_unique:
    fail_exit fail_slab_unique_msg, fail_slab_unique_len
.fail_slab_full:
    fail_exit fail_slab_full_msg, fail_slab_full_len
.fail_slab_refill:
    fail_exit fail_slab_refill_msg, fail_slab_refill_len
.fail_slab_stress:
    fail_exit fail_slab_stress_msg, fail_slab_stress_len
.fail_slab_destroy:
    fail_exit fail_slab_destroy_msg, fail_slab_destroy_len
