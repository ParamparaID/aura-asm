; test_ipc.asm
; Unit tests for lock-free SPSC IPC ring buffer
; Author: Aura Shell Team
; Date: 2026-03-19

%include "src/hal/platform_defs.inc"

extern hal_write
extern hal_exit
extern thread_create
extern ring_init
extern ring_push
extern ring_pop
extern ring_destroy
extern ring_is_full

section .data
    pass_msg             db "ALL TESTS PASSED", 10
    pass_len             equ $ - pass_msg

    fail_basic_msg       db "TEST FAILED: ipc_basic", 10
    fail_basic_len       equ $ - fail_basic_msg
    fail_overflow_msg    db "TEST FAILED: ipc_overflow", 10
    fail_overflow_len    equ $ - fail_overflow_msg
    fail_spsc_msg        db "TEST FAILED: ipc_spsc", 10
    fail_spsc_len        equ $ - fail_spsc_msg

section .bss
    ring_ptr             resq 1
    msg_tmp              resq 4
    exp_counter          resq 1
    recv_counter         resq 1
    spsc_ring            resq 1

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

producer_fn:
    xor r12d, r12d
.prod_loop:
    cmp r12d, 10000
    jae .done
    mov [rel msg_tmp], r12
    mov qword [rel msg_tmp + 8], 1
    mov qword [rel msg_tmp + 16], 2
    mov qword [rel msg_tmp + 24], 3
    mov rdi, [rel spsc_ring]
    lea rsi, [rel msg_tmp]
    call ring_push
    cmp rax, 0
    je .next
    pause
    jmp .prod_loop
.next:
    inc r12d
    jmp .prod_loop
.done:
    ret

consumer_fn:
    xor r12d, r12d
.cons_loop:
    cmp r12d, 10000
    jae .done
    mov rdi, [rel spsc_ring]
    lea rsi, [rel msg_tmp]
    call ring_pop
    cmp rax, 0
    jne .spin
    mov rax, [rel msg_tmp]
    cmp rax, r12
    jne .bad
    inc r12d
    jmp .cons_loop
.spin:
    pause
    jmp .cons_loop
.bad:
    mov qword [rel recv_counter], -1
    ret
.done:
    mov qword [rel recv_counter], 10000
    ret

_start:
    ; Test 1: basic push/pop
    mov rdi, 16
    call ring_init
    test rax, rax
    jz .fail_basic
    mov [rel ring_ptr], rax

    xor r12d, r12d
.push10:
    cmp r12d, 10
    jae .pop10
    mov [rel msg_tmp], r12
    mov qword [rel msg_tmp + 8], 10
    mov qword [rel msg_tmp + 16], 20
    mov qword [rel msg_tmp + 24], 30
    mov rdi, [rel ring_ptr]
    lea rsi, [rel msg_tmp]
    call ring_push
    cmp rax, 0
    jne .fail_basic_destroy
    inc r12d
    jmp .push10

.pop10:
    xor r12d, r12d
.pop_loop:
    cmp r12d, 10
    jae .overflow_test
    mov rdi, [rel ring_ptr]
    lea rsi, [rel msg_tmp]
    call ring_pop
    cmp rax, 0
    jne .fail_basic_destroy
    cmp qword [rel msg_tmp], r12
    jne .fail_basic_destroy
    inc r12d
    jmp .pop_loop

    ; Test 2: overflow
.overflow_test:
    mov rdi, [rel ring_ptr]
    call ring_destroy

    mov rdi, 8
    call ring_init
    test rax, rax
    jz .fail_overflow
    mov [rel ring_ptr], rax

    xor r12d, r12d
.fill_ring:
    cmp r12d, 7                      ; usable size is capacity-1
    jae .one_more
    mov [rel msg_tmp], r12
    mov qword [rel msg_tmp + 8], 0
    mov qword [rel msg_tmp + 16], 0
    mov qword [rel msg_tmp + 24], 0
    mov rdi, [rel ring_ptr]
    lea rsi, [rel msg_tmp]
    call ring_push
    cmp rax, 0
    jne .fail_overflow_destroy
    inc r12d
    jmp .fill_ring

.one_more:
    mov qword [rel msg_tmp], 999
    mov rdi, [rel ring_ptr]
    lea rsi, [rel msg_tmp]
    call ring_push
    cmp rax, -1
    jne .fail_overflow_destroy

    ; Test 3: concurrent SPSC
    mov rdi, [rel ring_ptr]
    call ring_destroy

    mov rdi, 16384
    call ring_init
    test rax, rax
    jz .fail_spsc
    mov [rel spsc_ring], rax
    mov qword [rel recv_counter], 0

    lea rdi, [rel producer_fn]
    xor rsi, rsi
    xor rdx, rdx
    call thread_create
    test rax, rax
    jle .fail_spsc_destroy

    lea rdi, [rel consumer_fn]
    xor rsi, rsi
    xor rdx, rdx
    call thread_create
    test rax, rax
    jle .fail_spsc_destroy

    cmp qword [rel recv_counter], 10000
    jne .fail_spsc_destroy

    mov rdi, [rel spsc_ring]
    call ring_destroy

    write_stdout pass_msg, pass_len
    xor rdi, rdi
    call hal_exit

.fail_basic_destroy:
    mov rdi, [rel ring_ptr]
    call ring_destroy
.fail_basic:
    fail_exit fail_basic_msg, fail_basic_len

.fail_overflow_destroy:
    mov rdi, [rel ring_ptr]
    call ring_destroy
.fail_overflow:
    fail_exit fail_overflow_msg, fail_overflow_len

.fail_spsc_destroy:
    mov rdi, [rel spsc_ring]
    call ring_destroy
.fail_spsc:
    fail_exit fail_spsc_msg, fail_spsc_len
