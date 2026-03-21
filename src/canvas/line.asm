; line.asm — DDA line with 16.16 y accumulator

%include "src/canvas/canvas.inc"

extern canvas_put_pixel

section .text
global canvas_draw_line_aa

canvas_draw_line_aa:
    push rbx
    push r12
    push r13
    push r14
    push r15

    test rdi, rdi
    jz .bad

    mov rbx, rdi
    mov r10d, esi
    mov r11d, edx
    mov r12d, ecx
    mov r13d, r8d
    mov r15d, r9d

    cmp r10d, r12d
    jle .ord
    xchg r10d, r12d
    xchg r11d, r13d
.ord:
    mov eax, r12d
    sub eax, r10d
    jz .vert
    mov ecx, eax
    mov eax, r13d
    sub eax, r11d
    shl rax, 16
    cqo
    idiv rcx
    mov r14, rax

    movsxd r9, r11d
    shl r9, 16
    mov r8d, r10d
.lp:
    cmp r8d, r12d
    ja .ok
    mov rdx, r9
    sar rdx, 16
    mov rdi, rbx
    mov esi, r8d
    mov ecx, r15d
    call canvas_put_pixel
    add r9, r14
    inc r8d
    jmp .lp

.vert:
    cmp r11d, r13d
    jle .vgo
    xchg r11d, r13d
.vgo:
    mov r8d, r11d
.vlp:
    cmp r8d, r13d
    ja .ok
    mov rdi, rbx
    mov esi, r10d
    mov edx, r8d
    mov ecx, r15d
    call canvas_put_pixel
    inc r8d
    jmp .vlp

.ok:
    xor eax, eax
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.bad:
    mov rax, -1
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
