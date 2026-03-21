; composite.asm — Porter-Duff src-over, alpha fill

%include "src/canvas/canvas.inc"

extern canvas_get_pixel
extern canvas_put_pixel
extern canvas_fill_rect

section .text
global canvas_composite
global canvas_fill_rect_alpha

; canvas_composite(dst, src, x, y) — rdi rsi rdx rcx
canvas_composite:
    push rbx
    push r12
    push r13
    push r14
    push r15

    test rdi, rdi
    jz .bad
    test rsi, rsi
    jz .bad

    mov rbx, rdi
    mov r12, rsi
    mov r13d, edx
    mov r14d, ecx

    xor r15d, r15d
.sy:
    cmp r15d, dword [r12 + CV_HEIGHT_OFF]
    jae .ok
    xor r8d, r8d
.sx:
    cmp r8d, dword [r12 + CV_WIDTH_OFF]
    jae .sny

    lea eax, [r13 + r8]
    cmp eax, 0
    jl .snx
    cmp eax, dword [rbx + CV_WIDTH_OFF]
    jge .snx
    lea eax, [r14 + r15]
    cmp eax, 0
    jl .snx
    cmp eax, dword [rbx + CV_HEIGHT_OFF]
    jge .snx

    mov eax, r15d
    imul eax, dword [r12 + CV_STRIDE_OFF]
    cdqe
    mov rdi, qword [r12 + CV_BUFFER_OFF]
    add rdi, rax
    mov r9d, r8d
    shl r9d, 2
    movsxd r9, r9d
    add rdi, r9
    mov r9d, dword [rdi]

    mov r11d, r8d
    mov rdi, rbx
    mov esi, r13d
    add esi, r11d
    mov edx, r14d
    add edx, r15d
    call canvas_get_pixel
    mov r8d, r11d
    mov r10d, eax

    mov eax, r9d
    shr eax, 24
    cmp eax, 255
    jge .sopq
    test eax, eax
    jz .snx

    mov r11d, eax
    mov ecx, 255
    sub ecx, r11d

    mov esi, r9d
    and esi, 0xFF
    imul esi, r11d
    mov edi, r10d
    and edi, 0xFF
    imul edi, ecx
    add esi, edi
    imul esi, 257
    add esi, 257
    shr esi, 16
    push rsi

    mov esi, r9d
    shr esi, 8
    and esi, 0xFF
    imul esi, r11d
    mov edi, r10d
    shr edi, 8
    and edi, 0xFF
    imul edi, ecx
    add esi, edi
    imul esi, 257
    add esi, 257
    shr esi, 16
    push rsi

    mov esi, r9d
    shr esi, 16
    and esi, 0xFF
    imul esi, r11d
    mov edi, r10d
    shr edi, 16
    and edi, 0xFF
    imul edi, ecx
    add esi, edi
    imul esi, 257
    add esi, 257
    shr esi, 16

    pop rdx
    pop rcx
    shl esi, 16
    shl edx, 8
    or esi, edx
    or esi, ecx
    or esi, 0xFF000000
    mov r9d, esi

    mov rdi, rbx
    mov esi, r13d
    add esi, r8d
    mov edx, r14d
    add edx, r15d
    mov ecx, r9d
    call canvas_put_pixel
    jmp .snx

.sopq:
    mov rdi, rbx
    mov esi, r13d
    add esi, r8d
    mov edx, r14d
    add edx, r15d
    mov ecx, r9d
    call canvas_put_pixel

.snx:
    inc r8d
    jmp .sx
.sny:
    inc r15d
    jmp .sy

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

; canvas_fill_rect_alpha(canvas,x,y,w,h,color)
canvas_fill_rect_alpha:
    push rbx
    push rbp
    push r12
    push r13
    push r14
    push r15

    test rdi, rdi
    jz .fbad
    test rcx, rcx
    jle .fok
    test r8, r8
    jle .fok

    mov rbx, rdi
    mov r12d, esi
    mov r13d, edx
    mov r14d, ecx
    mov r15d, r8d
    mov r11d, r9d

    mov eax, r11d
    shr eax, 24
    cmp eax, 255
    jge .opaque_fill
    test eax, eax
    jz .fok

    mov ebp, eax
    mov r10d, 255
    sub r10d, ebp

    mov r8d, r13d
.fy:
    mov eax, r13d
    add eax, r15d
    cmp r8d, eax
    jge .fok
    mov r9d, r12d
.fx:
    mov eax, r12d
    add eax, r14d
    cmp r9d, eax
    jge .fny

    mov rdi, rbx
    mov esi, r9d
    mov edx, r8d
    call canvas_get_pixel
    mov r10d, eax

    mov esi, r11d
    and esi, 0xFF
    imul esi, ebp
    mov edi, r10d
    and edi, 0xFF
    imul edi, r10d
    add esi, edi
    imul esi, 257
    add esi, 257
    shr esi, 16
    push rsi

    mov esi, r11d
    shr esi, 8
    and esi, 0xFF
    imul esi, ebp
    mov edi, r10d
    shr edi, 8
    and edi, 0xFF
    imul edi, r10d
    add esi, edi
    imul esi, 257
    add esi, 257
    shr esi, 16
    push rsi

    mov esi, r11d
    shr esi, 16
    and esi, 0xFF
    imul esi, ebp
    mov edi, r10d
    shr edi, 16
    and edi, 0xFF
    imul edi, r10d
    add esi, edi
    imul esi, 257
    add esi, 257
    shr esi, 16

    pop rdx
    pop rcx
    shl esi, 16
    shl edx, 8
    or esi, edx
    or esi, ecx
    or esi, 0xFF000000

    mov eax, esi
    mov rdi, rbx
    mov esi, r9d
    mov edx, r8d
    mov ecx, eax
    call canvas_put_pixel
    inc r9d
    jmp .fx
.fny:
    inc r8d
    jmp .fy

.opaque_fill:
    mov rdi, rbx
    mov esi, r12d
    mov edx, r13d
    mov ecx, r14d
    mov r8d, r15d
    mov r9d, r11d
    call canvas_fill_rect

.fok:
    xor eax, eax
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret
.fbad:
    mov rax, -1
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret
