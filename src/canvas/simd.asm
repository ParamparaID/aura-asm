; simd.asm
; AuraCanvas SSE2 accelerated fill routines
; Author: Aura Shell Team
; Date: 2026-03-20

%include "src/canvas/canvas.inc"

extern canvas_fill_rect_scalar

section .data

section .bss
    sse2_state   resd 1            ; 0 unknown, 1 unavailable, 2 available

section .text
global canvas_has_sse2
global canvas_fill_rect_simd
global canvas_clear_simd

; canvas_has_sse2()
; Return: rax=1 if available, else 0
; Complexity: O(1)
canvas_has_sse2:
    mov eax, [rel sse2_state]
    cmp eax, 2
    je .yes
    cmp eax, 1
    je .no

    mov eax, 1
    cpuid
    bt edx, 26
    jc .set_yes
    mov dword [rel sse2_state], 1
    xor eax, eax
    ret
.set_yes:
    mov dword [rel sse2_state], 2
.yes:
    mov eax, 1
    ret
.no:
    xor eax, eax
    ret

; canvas_clear_simd(canvas_ptr, color)
; Params: rdi=Canvas*, rsi=color
; Return: rax=0/-1
; Complexity: O(width*height/4)
canvas_clear_simd:
    test rdi, rdi
    jz .bad
    mov r9, rsi
    xor rsi, rsi
    xor rdx, rdx
    mov ecx, [rdi + CV_WIDTH_OFF]
    mov r8d, [rdi + CV_HEIGHT_OFF]
    call canvas_fill_rect_simd
    ret
.bad:
    mov rax, -1
    ret

; canvas_fill_rect_simd(canvas_ptr, x, y, w, h, color)
; Params: rdi,rsi,rdx,rcx,r8,r9
; Return: rax=0/-1
; Complexity: O(w*h/4)
canvas_fill_rect_simd:
    push rbx
    push r12
    push r13
    push r14
    push r15

    test rdi, rdi
    jz .bad
    test rcx, rcx
    jle .ok
    test r8, r8
    jle .ok

    mov rbx, rdi                    ; canvas
    mov r12, rsi                    ; x
    mov r13, rdx                    ; y
    mov r14, rcx                    ; w
    mov r15, r8                     ; h
    mov r10d, r9d                   ; color

    call canvas_has_sse2
    cmp rax, 1
    jne .scalar

    ; x0 = max(0,x), y0 = max(0,y)
    xor r8d, r8d
    cmp r12, 0
    cmovge r8, r12
    xor r9d, r9d
    cmp r13, 0
    cmovge r9, r13

    ; x1 = min(width, x+w)
    mov r11, r12
    add r11, r14
    mov eax, [rbx + CV_WIDTH_OFF]
    mov rdx, rax
    cmp r11, rdx
    cmova r11, rdx

    ; y1 = min(height, y+h)
    mov r12, r13
    add r12, r15
    mov eax, [rbx + CV_HEIGHT_OFF]
    mov rdx, rax
    cmp r12, rdx
    cmova r12, rdx

    cmp r11, r8
    jle .ok
    cmp r12, r9
    jle .ok

    mov eax, [rbx + CV_CLIP_W_OFF]
    test eax, eax
    jz .ok
    mov eax, [rbx + CV_CLIP_X_OFF]
    mov ecx, [rbx + CV_CLIP_Y_OFF]
    mov rdx, rax
    add rdx, [rbx + CV_CLIP_W_OFF]
    mov r14, rcx
    add r14d, [rbx + CV_CLIP_H_OFF]
    cmp r8, rax
    cmovl r8, rax
    cmp r9, rcx
    cmovl r9, rcx
    cmp r11, rdx
    cmova r11, rdx
    cmp r12, r14
    cmova r12, r14
    cmp r11, r8
    jle .ok
    cmp r12, r9
    jle .ok

    movd xmm0, r10d
    pshufd xmm0, xmm0, 0

    mov r15, r11                    ; x1 — keep; prefix loop clobbers r11

    mov r13, r9                     ; ycur
.row_loop:
    cmp r13, r12
    jae .ok
    mov rax, [rbx + CV_BUFFER_OFF]
    mov edx, [rbx + CV_STRIDE_OFF]
    imul rdx, r13
    add rax, rdx
    lea rax, [rax + r8*4]           ; row ptr

    mov r14, r15
    sub r14, r8                     ; pixels in row
    mov rcx, r14

    ; prefix to 16-byte alignment
    mov rdx, rax
    and rdx, 15
    jz .aligned
    mov r11, 16
    sub r11, rdx
    shr r11, 2
    mov rdx, r11
    cmp rdx, rcx
    cmova rdx, rcx
.prefix:
    test rdx, rdx
    jz .aligned
    mov dword [rax], r10d
    add rax, 4
    dec rdx
    dec rcx
    jmp .prefix

.aligned:
    mov rdx, rcx
    shr rdx, 2                      ; groups of 4 pixels
.vec_loop:
    test rdx, rdx
    jz .tail
    movdqa [rax], xmm0
    add rax, 16
    dec rdx
    sub rcx, 4
    jmp .vec_loop

.tail:
    test rcx, rcx
    jz .next_row
    mov dword [rax], r10d
    add rax, 4
    dec rcx
    jmp .tail

.next_row:
    inc r13
    jmp .row_loop

.scalar:
    mov rdi, rbx
    mov rsi, r12
    mov rdx, r13
    mov rcx, r14
    mov r8, r15
    mov r9d, r10d
    call canvas_fill_rect_scalar
    jmp .ret

.ok:
    xor eax, eax
    jmp .ret
.bad:
    mov rax, -1
.ret:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
