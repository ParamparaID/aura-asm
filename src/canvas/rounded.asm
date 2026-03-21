; rounded.asm — rounded rectangles

%include "src/canvas/canvas.inc"

extern canvas_fill_rect
extern canvas_put_pixel

section .text
global canvas_fill_rounded_rect
global canvas_fill_rounded_rect_4
global canvas_draw_rounded_rect

; canvas_fill_rounded_rect(canvas,x,y,w,h,r,color) — color at [rbp+16]
canvas_fill_rounded_rect:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15

    test rdi, rdi
    jz .bad
    test rcx, rcx
    jle .ok_empty
    test r8, r8
    jle .ok_empty

    mov rbx, rdi
    mov r12d, esi
    mov r13d, edx
    mov r14d, ecx
    mov r15d, r8d
    mov eax, r9d
    mov r9d, dword [rbp + 16]

    mov ecx, eax
    mov eax, r14d
    shr eax, 1
    cmp ecx, eax
    cmova ecx, eax
    mov eax, r15d
    shr eax, 1
    cmp ecx, eax
    cmova ecx, eax
    mov r10d, ecx
    mov r11d, r9d
    push r10
    push r11

    mov rdi, rbx
    mov esi, r12d
    add esi, r10d
    mov edx, r13d
    add edx, r10d
    mov ecx, r14d
    sub ecx, r10d
    sub ecx, r10d
    mov r8d, r15d
    sub r8d, r10d
    sub r8d, r10d
    mov r9d, r11d
    call canvas_fill_rect
    mov r10, [rsp + 8]
    mov r11, [rsp]

    mov rdi, rbx
    mov esi, r12d
    add esi, r10d
    mov edx, r13d
    mov ecx, r14d
    sub ecx, r10d
    sub ecx, r10d
    mov r8d, r10d
    mov r9d, r11d
    call canvas_fill_rect
    mov r10, [rsp + 8]
    mov r11, [rsp]

    mov rdi, rbx
    mov esi, r12d
    add esi, r10d
    mov edx, r13d
    add edx, r15d
    sub edx, r10d
    mov ecx, r14d
    sub ecx, r10d
    sub ecx, r10d
    mov r8d, r10d
    mov r9d, r11d
    call canvas_fill_rect
    mov r10, [rsp + 8]
    mov r11, [rsp]

    mov rdi, rbx
    mov esi, r12d
    mov edx, r13d
    add edx, r10d
    mov ecx, r10d
    mov r8d, r15d
    sub r8d, r10d
    sub r8d, r10d
    mov r9d, r11d
    call canvas_fill_rect
    mov r10, [rsp + 8]
    mov r11, [rsp]

    mov rdi, rbx
    mov esi, r12d
    add esi, r14d
    sub esi, r10d
    mov edx, r13d
    add edx, r10d
    mov ecx, r10d
    mov r8d, r15d
    sub r8d, r10d
    sub r8d, r10d
    mov r9d, r11d
    call canvas_fill_rect
    mov r10, [rsp + 8]
    mov r11, [rsp]

    mov eax, r10d
    imul eax, eax
    push rax

    mov r8d, r13d
.tl_y:
    mov eax, r13d
    add eax, r10d
    cmp r8d, eax
    jge .tl_done
    mov r9d, r12d
.tl_x:
    mov eax, r12d
    add eax, r10d
    cmp r9d, eax
    jge .tl_ny
    mov eax, r9d
    sub eax, r12d
    sub eax, r10d
    imul eax, eax
    mov ecx, eax
    mov eax, r8d
    sub eax, r13d
    sub eax, r10d
    imul eax, eax
    add eax, ecx
    cmp eax, dword [rsp]
    ja .tl_nx
    mov rdi, rbx
    mov esi, r9d
    mov edx, r8d
    mov ecx, r11d
    call canvas_put_pixel
.tl_nx:
    inc r9d
    jmp .tl_x
.tl_ny:
    inc r8d
    jmp .tl_y
.tl_done:

    mov r8d, r13d
.tr_y:
    mov eax, r13d
    add eax, r10d
    cmp r8d, eax
    jge .tr_done
    mov esi, r12d
    add esi, r14d
    sub esi, r10d
.tr_x:
    mov eax, r12d
    add eax, r14d
    cmp esi, eax
    jge .tr_ny
    mov eax, esi
    sub eax, r12d
    sub eax, r14d
    add eax, r10d
    imul eax, eax
    mov ecx, eax
    mov eax, r8d
    sub eax, r13d
    sub eax, r10d
    imul eax, eax
    add eax, ecx
    cmp eax, dword [rsp]
    ja .tr_nx
    mov rdi, rbx
    mov esi, esi
    mov edx, r8d
    mov ecx, r11d
    call canvas_put_pixel
.tr_nx:
    inc esi
    jmp .tr_x
.tr_ny:
    inc r8d
    jmp .tr_y
.tr_done:

    mov r8d, r13d
    add r8d, r15d
    sub r8d, r10d
.br_y:
    mov eax, r13d
    add eax, r15d
    cmp r8d, eax
    jge .br_done
    mov esi, r12d
    add esi, r14d
    sub esi, r10d
.br_x:
    mov eax, r12d
    add eax, r14d
    cmp esi, eax
    jge .br_ny
    mov eax, esi
    sub eax, r12d
    sub eax, r14d
    add eax, r10d
    imul eax, eax
    mov ecx, eax
    mov eax, r8d
    sub eax, r13d
    sub eax, r15d
    add eax, r10d
    imul eax, eax
    add eax, ecx
    cmp eax, dword [rsp]
    ja .br_nx
    mov rdi, rbx
    mov edx, r8d
    mov ecx, r11d
    call canvas_put_pixel
.br_nx:
    inc esi
    jmp .br_x
.br_ny:
    inc r8d
    jmp .br_y
.br_done:

    mov r8d, r13d
    add r8d, r15d
    sub r8d, r10d
.bl_y:
    mov eax, r13d
    add eax, r15d
    cmp r8d, eax
    jge .bl_done
    mov esi, r12d
.bl_x:
    mov eax, r12d
    add eax, r10d
    cmp esi, eax
    jge .bl_ny
    mov eax, esi
    sub eax, r12d
    sub eax, r10d
    imul eax, eax
    mov ecx, eax
    mov eax, r8d
    sub eax, r13d
    sub eax, r15d
    add eax, r10d
    imul eax, eax
    add eax, ecx
    cmp eax, dword [rsp]
    ja .bl_nx
    mov rdi, rbx
    mov esi, esi
    mov edx, r8d
    mov ecx, r11d
    call canvas_put_pixel
.bl_nx:
    inc esi
    jmp .bl_x
.bl_ny:
    inc r8d
    jmp .bl_y
.bl_done:

.ok_draw:
    add rsp, 8
    pop r11
    pop r10
    xor eax, eax
    jmp .out
.ok_empty:
    xor eax, eax
    jmp .out
.bad:
    mov rax, -1
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; canvas_fill_rounded_rect_4 — r9=r_tl, [rbp+16/24/32]=r_tr,r_br,r_bl, [rbp+40]=color
canvas_fill_rounded_rect_4:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15

    test rdi, rdi
    jz .f4_bad
    test rcx, rcx
    jle .f4_ok
    test r8, r8
    jle .f4_ok

    mov rbx, rdi
    mov r12d, esi
    mov r13d, edx
    mov r14d, ecx
    mov r15d, r8d

    mov eax, dword [rbp + 16]
    cmp r9d, eax
    jne .f4_gen
    cmp r9d, dword [rbp + 24]
    jne .f4_gen
    cmp r9d, dword [rbp + 32]
    jne .f4_gen
    mov eax, dword [rbp + 40]
    push rax
    mov rdi, rbx
    mov esi, r12d
    mov edx, r13d
    mov ecx, r14d
    mov r8d, r15d
    call canvas_fill_rounded_rect
    add rsp, 8
    jmp .f4_ok

.f4_gen:
    mov eax, r9d
    mov edi, dword [rbp + 16]
    cmp eax, edi
    cmova eax, edi
    mov edi, dword [rbp + 24]
    cmp eax, edi
    cmova eax, edi
    mov edi, dword [rbp + 32]
    cmp eax, edi
    cmova eax, edi
    mov r9d, eax
    mov eax, dword [rbp + 40]
    push rax
    mov rdi, rbx
    mov esi, r12d
    mov edx, r13d
    mov ecx, r14d
    mov r8d, r15d
    call canvas_fill_rounded_rect
    add rsp, 8

.f4_ok:
    xor eax, eax
    jmp .f4_out
.f4_bad:
    mov rax, -1
.f4_out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; canvas_draw_rounded_rect(canvas,x,y,w,h,r,color,thickness) — [rbp+16]=t [rbp+24]=color
canvas_draw_rounded_rect:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15

    test rdi, rdi
    jz .dr_bad
    test rcx, rcx
    jle .dr_ok_skip
    test r8, r8
    jle .dr_ok_skip

    mov rbx, rdi
    mov r12d, esi
    mov r13d, edx
    mov r14d, ecx
    mov r15d, r8d
    mov r10d, r9d
    mov r11d, dword [rbp + 24]
    mov r8d, dword [rbp + 16]
    test r8d, r8d
    jle .dr_bad

    mov eax, r10d
    mov edi, r14d
    shr edi, 1
    cmp eax, edi
    cmova eax, edi
    mov edi, r15d
    shr edi, 1
    cmp eax, edi
    cmova eax, edi
    mov r10d, eax

    mov eax, r10d
    sub eax, r8d
    mov r9d, eax
    cmp r9d, 1
    jl .dr_ok_skip
    imul r9d, r9d

    mov eax, r10d
    imul eax, eax
    push rax

    mov rdi, rbx
    mov esi, r12d
    add esi, r10d
    mov edx, r13d
    mov ecx, r14d
    sub ecx, r10d
    sub ecx, r10d
    mov r8d, dword [rbp + 16]
    mov r9d, r11d
    call canvas_fill_rect

    mov rdi, rbx
    mov esi, r12d
    add esi, r10d
    mov edx, r13d
    add edx, r15d
    sub edx, dword [rbp + 16]
    mov ecx, r14d
    sub ecx, r10d
    sub ecx, r10d
    mov r8d, dword [rbp + 16]
    mov r9d, r11d
    call canvas_fill_rect

    mov rdi, rbx
    mov esi, r12d
    mov edx, r13d
    add edx, r10d
    mov ecx, dword [rbp + 16]
    mov r8d, r15d
    sub r8d, r10d
    sub r8d, r10d
    mov r9d, r11d
    call canvas_fill_rect

    mov rdi, rbx
    mov esi, r12d
    add esi, r14d
    sub esi, dword [rbp + 16]
    mov edx, r13d
    add edx, r10d
    mov ecx, dword [rbp + 16]
    mov r8d, r15d
    sub r8d, r10d
    sub r8d, r10d
    mov r9d, r11d
    call canvas_fill_rect

    mov r8d, r13d
.dry:
    mov eax, r13d
    add eax, r10d
    cmp r8d, eax
    jge .dr_tl_done
    mov esi, r12d
.drx:
    mov eax, r12d
    add eax, r10d
    cmp esi, eax
    jge .dr_tl_ny
    mov eax, esi
    sub eax, r12d
    sub eax, r10d
    imul eax, eax
    mov ecx, eax
    mov eax, r8d
    sub eax, r13d
    sub eax, r10d
    imul eax, eax
    add eax, ecx
    cmp eax, dword [rsp]
    ja .dr_tl_nx
    cmp eax, r9d
    jbe .dr_tl_nx
    mov rdi, rbx
    mov edx, r8d
    mov ecx, r11d
    call canvas_put_pixel
.dr_tl_nx:
    inc esi
    jmp .drx
.dr_tl_ny:
    inc r8d
    jmp .dry
.dr_tl_done:

.dr_ok:
    add rsp, 8
.dr_ok_skip:
    xor eax, eax
    jmp .dr_out
.dr_bad:
    mov rax, -1
.dr_out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret