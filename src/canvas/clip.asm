; clip.asm — clip region stack (intersection), max depth 16

%include "src/canvas/canvas.inc"

section .text
global canvas_push_clip
global canvas_pop_clip

; canvas_recompute_clip — rbx = canvas (preserved)
canvas_recompute_clip:
    push r12
    push r13
    push r14
    push r15

    mov r12d, 0
    mov r13d, 0
    mov r14d, [rbx + CV_WIDTH_OFF]
    mov r15d, [rbx + CV_HEIGHT_OFF]

    xor ecx, ecx
.re_loop:
    cmp ecx, [rbx + CV_CLIP_DEPTH_OFF]
    jae .re_done

    imul rax, rcx, CV_CLIP_ENTRY_SIZE
    lea rdi, [rbx + CV_CLIP_STACK_OFF + rax]
    mov esi, [rdi + 0]
    mov ebp, [rdi + 4]
    mov r8d, [rdi + 8]
    mov r9d, [rdi + 12]
    add r8d, esi
    add r9d, ebp

    cmp r12, rsi
    cmovl r12, rsi
    cmp r13, rbp
    cmovl r13, rbp
    cmp r14, r8
    cmova r14, r8
    cmp r15, r9
    cmova r15, r9

    inc ecx
    jmp .re_loop

.re_done:
    cmp r14, r12
    jle .re_empty
    cmp r15, r13
    jle .re_empty

    mov [rbx + CV_CLIP_X_OFF], r12d
    mov [rbx + CV_CLIP_Y_OFF], r13d
    mov eax, r14d
    sub eax, r12d
    mov [rbx + CV_CLIP_W_OFF], eax
    mov eax, r15d
    sub eax, r13d
    mov [rbx + CV_CLIP_H_OFF], eax
    pop r15
    pop r14
    pop r13
    pop r12
    ret
.re_empty:
    mov dword [rbx + CV_CLIP_W_OFF], 0
    mov dword [rbx + CV_CLIP_H_OFF], 0
    pop r15
    pop r14
    pop r13
    pop r12
    ret

; canvas_push_clip(canvas, x, y, w, h) — rdi rsi rdx rcx r8
canvas_push_clip:
    push rbx
    push r12
    push r13
    push r14
    push r15

    test rdi, rdi
    jz .bad
    test r8, r8
    jle .bad
    test rcx, rcx
    jle .bad

    mov rbx, rdi
    mov r12d, esi
    mov r13d, edx
    mov r14d, ecx
    mov r15d, r8d

    xor esi, esi
    cmp r12, 0
    cmovge rsi, r12
    xor edx, edx
    cmp r13, 0
    cmovge rdx, r13

    mov r10, r12
    add r10, r14
    mov eax, [rbx + CV_WIDTH_OFF]
    cmp r10, rax
    cmova r10, rax

    mov r11, r13
    add r11, r15
    mov eax, [rbx + CV_HEIGHT_OFF]
    cmp r11, rax
    cmova r11, rax

    cmp r10, rsi
    jle .bad
    cmp r11, rdx
    jle .bad

    mov ecx, [rbx + CV_CLIP_DEPTH_OFF]
    cmp ecx, CV_CLIP_MAX_DEPTH
    jae .bad

    imul rcx, rcx, CV_CLIP_ENTRY_SIZE
    lea rdi, [rbx + CV_CLIP_STACK_OFF + rcx]
    mov [rdi + 0], esi
    mov [rdi + 4], edx
    mov eax, r10d
    sub eax, esi
    mov [rdi + 8], eax
    mov eax, r11d
    sub eax, edx
    mov [rdi + 12], eax

    inc dword [rbx + CV_CLIP_DEPTH_OFF]
    call canvas_recompute_clip
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

; canvas_pop_clip(canvas) — rdi
canvas_pop_clip:
    push rbx
    test rdi, rdi
    jz .bad
    mov rbx, rdi
    mov eax, [rbx + CV_CLIP_DEPTH_OFF]
    test eax, eax
    jz .bad
    dec dword [rbx + CV_CLIP_DEPTH_OFF]
    call canvas_recompute_clip
    xor eax, eax
    pop rbx
    ret
.bad:
    mov rax, -1
    pop rbx
    ret
