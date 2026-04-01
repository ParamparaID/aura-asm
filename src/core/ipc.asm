; ipc.asm
; Lock-free SPSC ring buffer IPC for Aura Shell
; Author: Aura Shell Team
; Date: 2026-03-19

%include "src/hal/platform_defs.inc"

extern hal_mmap
extern hal_munmap

%define PAGE_SIZE                   4096
%define IPC_MSG_SIZE                32
%define IPC_RING_META_SIZE          192

; RingBuffer layout
%define RB_BUFFER_OFF               0
%define RB_CAPACITY_OFF             8
%define RB_MASK_OFF                 16
%define RB_HEAD_OFF                 24
%define RB_TAIL_OFF                 88
%define RB_BUF_BYTES_OFF            152
%define RB_TOTAL_MAP_OFF            160

section .data

section .bss

section .text
global ring_init
global ring_push
global ring_pop
global ring_is_empty
global ring_is_full
global ring_destroy

; ring_init(capacity)
; Params:
;   rdi = ring capacity (must be power of two)
; Return:
;   rax = RingBuffer* on success, 0 on failure
; Complexity: O(1)
ring_init:
    push rbx
    push r12

    test rdi, rdi
    jz .fail
    mov rbx, rdi
    mov rax, rbx
    dec rax
    test rbx, rax
    jnz .fail                        ; not power of two

    mov rax, rbx
    imul rax, IPC_MSG_SIZE
    test rax, rax
    jz .fail
    add rax, PAGE_SIZE - 1
    and rax, -PAGE_SIZE
    mov r12, rax                     ; buffer bytes

    mov rax, IPC_RING_META_SIZE
    add rax, r12
    add rax, PAGE_SIZE - 1
    and rax, -PAGE_SIZE
    mov r11, rax                     ; total bytes

    xor rdi, rdi
    mov rsi, r11
    mov rdx, PROT_READ | PROT_WRITE
    mov rcx, MAP_PRIVATE | MAP_ANONYMOUS
    mov r8, -1
    xor r9, r9
    call hal_mmap
    test rax, rax
    js .fail

    mov [rax + RB_BUFFER_OFF], rax
    add qword [rax + RB_BUFFER_OFF], IPC_RING_META_SIZE
    mov [rax + RB_CAPACITY_OFF], rbx
    mov rcx, rbx
    dec rcx
    mov [rax + RB_MASK_OFF], rcx
    mov qword [rax + RB_HEAD_OFF], 0
    mov qword [rax + RB_TAIL_OFF], 0
    mov [rax + RB_BUF_BYTES_OFF], r12
    mov [rax + RB_TOTAL_MAP_OFF], r11

    pop r12
    pop rbx
    ret
.fail:
    xor eax, eax
    pop r12
    pop rbx
    ret

; ring_push(ring_ptr, msg_ptr)
; Params:
;   rdi = RingBuffer*
;   rsi = IPCMessage* (32 bytes)
; Return:
;   rax = 0 on success, -1 if full/invalid
; Complexity: O(1)
ring_push:
    test rdi, rdi
    jz .fail
    test rsi, rsi
    jz .fail

    mov r8, [rdi + RB_HEAD_OFF]
    mov r9, [rdi + RB_TAIL_OFF]
    mov r10, r8
    inc r10
    mov rcx, [rdi + RB_MASK_OFF]
    and r10, rcx
    cmp r10, r9
    je .fail                         ; full

    mov r11, [rdi + RB_BUFFER_OFF]
    mov rax, r8
    shl rax, 5                       ; * 32
    add r11, rax

    mov rax, [rsi]
    mov [r11], rax
    mov rax, [rsi + 8]
    mov [r11 + 8], rax
    mov rax, [rsi + 16]
    mov [r11 + 16], rax
    mov rax, [rsi + 24]
    mov [r11 + 24], rax

    mfence
    mov [rdi + RB_HEAD_OFF], r10
    xor eax, eax
    ret
.fail:
    mov rax, -1
    ret

; ring_pop(ring_ptr, msg_ptr)
; Params:
;   rdi = RingBuffer*
;   rsi = IPCMessage* out (32 bytes)
; Return:
;   rax = 0 on success, -1 if empty/invalid
; Complexity: O(1)
ring_pop:
    test rdi, rdi
    jz .fail
    test rsi, rsi
    jz .fail

    mov r8, [rdi + RB_HEAD_OFF]
    mov r9, [rdi + RB_TAIL_OFF]
    cmp r8, r9
    je .fail                         ; empty

    mov r11, [rdi + RB_BUFFER_OFF]
    mov rax, r9
    shl rax, 5
    add r11, rax

    mov rax, [r11]
    mov [rsi], rax
    mov rax, [r11 + 8]
    mov [rsi + 8], rax
    mov rax, [r11 + 16]
    mov [rsi + 16], rax
    mov rax, [r11 + 24]
    mov [rsi + 24], rax

    mov r10, r9
    inc r10
    mov rcx, [rdi + RB_MASK_OFF]
    and r10, rcx
    mfence
    mov [rdi + RB_TAIL_OFF], r10

    xor eax, eax
    ret
.fail:
    mov rax, -1
    ret

; ring_is_empty(ring_ptr)
; Return:
;   rax = 1 if empty, 0 otherwise (also 1 for null)
; Complexity: O(1)
ring_is_empty:
    test rdi, rdi
    jz .yes
    mov rax, [rdi + RB_HEAD_OFF]
    cmp rax, [rdi + RB_TAIL_OFF]
    jne .no
.yes:
    mov eax, 1
    ret
.no:
    xor eax, eax
    ret

; ring_is_full(ring_ptr)
; Return:
;   rax = 1 if full, 0 otherwise (also 1 for null)
; Complexity: O(1)
ring_is_full:
    test rdi, rdi
    jz .yes
    mov r8, [rdi + RB_HEAD_OFF]
    mov r9, [rdi + RB_TAIL_OFF]
    mov r10, r8
    inc r10
    and r10, [rdi + RB_MASK_OFF]
    cmp r10, r9
    jne .no
.yes:
    mov eax, 1
    ret
.no:
    xor eax, eax
    ret

; ring_destroy(ring_ptr)
; Params:
;   rdi = RingBuffer*
; Return:
;   rax = 0 on success, -1 on invalid pointer
; Complexity: O(1)
ring_destroy:
    test rdi, rdi
    jz .bad
    mov rsi, [rdi + RB_TOTAL_MAP_OFF]
    call hal_munmap
    ret
.bad:
    mov rax, -1
    ret
