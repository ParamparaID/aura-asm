; rasterizer.asm
; AuraCanvas software rasterizer primitives (ARGB32)
; Author: Aura Shell Team
; Date: 2026-03-20

%include "src/hal/linux_x86_64/defs.inc"
%include "src/canvas/canvas.inc"

extern hal_mmap
extern hal_munmap
extern canvas_has_sse2
extern canvas_fill_rect_simd
extern canvas_clear_simd

%define PAGE_SIZE                4096
%define MAX_CANVAS               8

section .data

section .bss
    canvas_pool      resb CV_STRUCT_SIZE * MAX_CANVAS
    canvas_used      resb MAX_CANVAS

section .text
global canvas_init
global canvas_destroy
global canvas_clear
global canvas_put_pixel
global canvas_get_pixel
global canvas_fill_rect
global canvas_fill_rect_scalar
global canvas_draw_rect
global canvas_hline
global canvas_vline
global canvas_draw_image
global canvas_draw_image_raw
global canvas_draw_image_scaled

; canvas_init(width, height)
; Params: rdi=width, rsi=height
; Return: rax=Canvas* or 0
; Complexity: O(MAX_CANVAS)
canvas_init:
    push rbx
    push r12
    push r13
    push r14

    test rdi, rdi
    jz .fail
    test rsi, rsi
    jz .fail

    mov r12, rdi
    mov r13, rsi

    mov rax, r12
    shl rax, 2
    jc .fail
    mov r14, rax                    ; stride

    mov rax, r14
    mul r13
    test rdx, rdx
    jnz .fail
    test rax, rax
    jz .fail

    add rax, PAGE_SIZE - 1
    and rax, -PAGE_SIZE
    mov r11, rax                    ; mmap size

    xor rdi, rdi
    mov rsi, r11
    mov rdx, PROT_READ | PROT_WRITE
    mov rcx, MAP_PRIVATE | MAP_ANONYMOUS
    mov r8, -1
    xor r9, r9
    call hal_mmap
    test rax, rax
    js .fail
    mov r10, rax                    ; buffer

    xor ecx, ecx
.find_slot:
    cmp ecx, MAX_CANVAS
    jae .unmap_fail
    movzx eax, byte [canvas_used + rcx]
    test eax, eax
    jz .slot_ok
    inc ecx
    jmp .find_slot

.slot_ok:
    mov byte [canvas_used + rcx], 1
    mov rax, rcx
    imul rax, CV_STRUCT_SIZE
    lea rdi, [canvas_pool + rax]
    mov [rdi + CV_BUFFER_OFF], r10
    mov dword [rdi + CV_WIDTH_OFF], r12d
    mov dword [rdi + CV_HEIGHT_OFF], r13d
    mov dword [rdi + CV_STRIDE_OFF], r14d
    mov dword [rdi + CV_PAD_OFF], 0
    mov [rdi + CV_SIZE_OFF], r11
    mov dword [rdi + CV_CLIP_DEPTH_OFF], 0
    mov dword [rdi + CV_CLIP_X_OFF], 0
    mov dword [rdi + CV_CLIP_Y_OFF], 0
    mov [rdi + CV_CLIP_W_OFF], r12d
    mov [rdi + CV_CLIP_H_OFF], r13d
    mov rax, rdi
    jmp .ret

.unmap_fail:
    mov rdi, r10
    mov rsi, r11
    call hal_munmap
.fail:
    xor eax, eax
.ret:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; canvas_destroy(canvas_ptr)
; Params: rdi=Canvas*
; Return: rax=0 success, -1 invalid
; Complexity: O(MAX_CANVAS)
canvas_destroy:
    push rbx
    test rdi, rdi
    jz .bad
    mov rbx, rdi

    mov rdi, [rbx + CV_BUFFER_OFF]
    mov rsi, [rbx + CV_SIZE_OFF]
    call hal_munmap

    lea rdx, [canvas_pool]
    mov rax, rbx
    sub rax, rdx
    xor edx, edx
    mov ecx, CV_STRUCT_SIZE
    div rcx
    cmp rax, MAX_CANVAS
    jae .ok
    mov byte [canvas_used + rax], 0
.ok:
    xor eax, eax
    pop rbx
    ret
.bad:
    mov rax, -1
    pop rbx
    ret

; canvas_clear(canvas_ptr, color)
; Params: rdi=Canvas*, rsi=color
; Return: rax=0/-1
; Complexity: O(width*height)
canvas_clear:
    test rdi, rdi
    jz .bad
    mov r10, rdi
    mov r11, rsi
    mov rdi, r10
    call canvas_has_sse2
    cmp rax, 1
    jne .scalar
    mov rdi, r10
    mov rsi, r11
    call canvas_clear_simd
    ret
.scalar:
    mov rdi, r10
    xor rsi, rsi
    xor rdx, rdx
    mov ecx, [r10 + CV_WIDTH_OFF]
    mov r8d, [r10 + CV_HEIGHT_OFF]
    mov r9, r11
    call canvas_fill_rect_scalar
    ret
.bad:
    mov rax, -1
    ret

; canvas_put_pixel(canvas_ptr, x, y, color)
; Params: rdi=Canvas*, rsi=x, rdx=y, rcx=color
; Return: rax=0 / -1
; Complexity: O(1)
canvas_put_pixel:
    test rdi, rdi
    jz .bad
    push rbx
    test rsi, rsi
    js .ok
    test rdx, rdx
    js .ok
    mov eax, [rdi + CV_WIDTH_OFF]
    cmp rsi, rax
    jae .ok
    mov eax, [rdi + CV_HEIGHT_OFF]
    cmp rdx, rax
    jae .ok
    mov eax, [rdi + CV_CLIP_W_OFF]
    test eax, eax
    jz .ok
    mov eax, [rdi + CV_CLIP_X_OFF]
    cmp esi, eax
    jl .ok
    mov eax, [rdi + CV_CLIP_Y_OFF]
    cmp edx, eax
    jl .ok
    mov eax, [rdi + CV_CLIP_X_OFF]
    add eax, [rdi + CV_CLIP_W_OFF]
    cmp esi, eax
    jge .ok
    mov eax, [rdi + CV_CLIP_Y_OFF]
    add eax, [rdi + CV_CLIP_H_OFF]
    cmp edx, eax
    jge .ok
    mov rbx, [rdi + CV_BUFFER_OFF]
    mov eax, [rdi + CV_STRIDE_OFF]
    imul rdx, rax
    lea rax, [rsi*4]
    add rdx, rax
    add rbx, rdx
    mov dword [rbx], ecx
.ok:
    pop rbx
    xor eax, eax
    ret
.bad:
    mov rax, -1
    ret

; canvas_get_pixel(canvas_ptr, x, y)
; Params: rdi=Canvas*, rsi=x, rdx=y
; Return: rax=color or 0 if OOB
; Complexity: O(1)
canvas_get_pixel:
    test rdi, rdi
    jz .zero
    test rsi, rsi
    js .zero
    test rdx, rdx
    js .zero
    mov eax, [rdi + CV_WIDTH_OFF]
    cmp rsi, rax
    jae .zero
    mov eax, [rdi + CV_HEIGHT_OFF]
    cmp rdx, rax
    jae .zero
    mov r8, [rdi + CV_BUFFER_OFF]
    mov eax, [rdi + CV_STRIDE_OFF]
    imul rdx, rax
    lea rax, [rsi*4]
    add rdx, rax
    add r8, rdx
    mov eax, dword [r8]
    ret
.zero:
    xor eax, eax
    ret

; canvas_fill_rect(canvas_ptr, x, y, w, h, color)
; Params: rdi,rsi,rdx,rcx,r8,r9
; Return: rax=0/-1
; Complexity: O(w*h)
canvas_fill_rect:
    call canvas_fill_rect_scalar
    ret

; canvas_fill_rect_scalar(canvas_ptr, x, y, w, h, color)
; Params: rdi,rsi,rdx,rcx,r8,r9
; Return: rax=0/-1
; Complexity: O(w*h)
canvas_fill_rect_scalar:
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

    mov rbx, rdi
    mov r12, rsi                    ; x
    mov r13, rdx                    ; y
    mov r14, rcx                    ; w
    mov r15, r8                     ; h
    mov r10d, r9d                   ; color

    ; x0/y0
    xor r8d, r8d
    cmp r12, 0
    cmovge r8, r12
    xor r9d, r9d
    cmp r13, 0
    cmovge r9, r13

    ; x1/y1
    mov r11, r12
    add r11, r14
    mov eax, [rbx + CV_WIDTH_OFF]
    mov rdx, rax
    cmp r11, rdx
    cmova r11, rdx

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
    mov ebp, [rbx + CV_CLIP_Y_OFF]
    mov edi, eax
    add edi, [rbx + CV_CLIP_W_OFF]
    mov esi, ebp
    add esi, [rbx + CV_CLIP_H_OFF]
    cmp r8, rax
    cmovl r8, rax
    cmp r9, rbp
    cmovl r9, rbp
    cmp r11, rdi
    cmova r11, rdi
    cmp r12, rsi
    cmova r12, rsi
    cmp r11, r8
    jle .ok
    cmp r12, r9
    jle .ok

    mov r13, r9
.row:
    cmp r13, r12
    jae .ok
    mov rax, [rbx + CV_BUFFER_OFF]
    mov edx, [rbx + CV_STRIDE_OFF]
    imul rdx, r13
    add rax, rdx
    lea rax, [rax + r8*4]
    mov r14, r8
.col:
    cmp r14, r11
    jae .next_row
    mov dword [rax], r10d
    add rax, 4
    inc r14
    jmp .col
.next_row:
    inc r13
    jmp .row

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

; canvas_draw_rect(canvas_ptr, x, y, w, h, color, thickness)
; Params: rdi,rsi,rdx,rcx,r8,r9,[rsp+8]
; Return: rax=0/-1
; Complexity: O(perimeter*thickness)
canvas_draw_rect:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r10, [rbp + 16]
    test r10, r10
    jle .ok

    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r14, rcx
    mov r15, r8
    mov r11, r9

    mov rdi, rbx
    mov rsi, r12
    mov rdx, r13
    mov rcx, r14
    mov r8, r10
    mov r9, r11
    call canvas_fill_rect

    mov rdi, rbx
    mov rsi, r12
    mov rdx, r13
    add rdx, r15
    sub rdx, r10
    mov rcx, r14
    mov r8, r10
    mov r9, r11
    call canvas_fill_rect

    mov rdi, rbx
    mov rsi, r12
    mov rdx, r13
    mov rcx, r10
    mov r8, r15
    mov r9, r11
    call canvas_fill_rect

    mov rdi, rbx
    mov rsi, r12
    add rsi, r14
    sub rsi, r10
    mov rdx, r13
    mov rcx, r10
    mov r8, r15
    mov r9, r11
    call canvas_fill_rect

.ok:
    xor eax, eax
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; canvas_hline(canvas_ptr, x1, x2, y, color)
; Params: rdi,rsi,rdx,rcx,r8
; Return: rax=0/-1
; Complexity: O(length)
canvas_hline:
    cmp rsi, rdx
    jle .ordered
    xchg rsi, rdx
.ordered:
    mov r9, r8
    mov r8, 1
    mov rax, rdx
    sub rax, rsi
    inc rax
    mov rdx, rcx
    mov rcx, rax
    call canvas_fill_rect
    ret

; Image: width dd, height dd, pixels dq, stride dd
%define IMG_WIDTH_OFF            0
%define IMG_HEIGHT_OFF           4
%define IMG_PIXELS_OFF           8
%define IMG_STRIDE_OFF           16

; canvas_draw_image(canvas, image, x, y)  rdi, rsi, edx, ecx
canvas_draw_image:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp

    test rdi, rdi
    jz .di_bad
    test rsi, rsi
    jz .di_bad

    mov rbx, rdi
    mov r12, rsi
    mov r13d, edx
    mov r14d, ecx

    mov r8d, dword [r12 + IMG_WIDTH_OFF]
    mov r9d, dword [r12 + IMG_HEIGHT_OFF]
    mov r15, qword [r12 + IMG_PIXELS_OFF]
    mov ebp, dword [r12 + IMG_STRIDE_OFF]

    xor edx, edx
.sy:
    cmp edx, r9d
    jae .di_ok
    xor ecx, ecx
.sx:
    cmp ecx, r8d
    jae .ny

    lea eax, [r13 + rcx]
    cmp eax, 0
    jl .nx
    cmp eax, dword [rbx + CV_WIDTH_OFF]
    jge .nx
    lea eax, [r14 + rdx]
    cmp eax, 0
    jl .nx
    cmp eax, dword [rbx + CV_HEIGHT_OFF]
    jge .nx

    mov eax, dword [rbx + CV_CLIP_W_OFF]
    test eax, eax
    jz .nx
    lea esi, [r13 + rcx]
    lea eax, [r14 + rdx]
    cmp esi, dword [rbx + CV_CLIP_X_OFF]
    jl .nx
    cmp eax, dword [rbx + CV_CLIP_Y_OFF]
    jl .nx
    mov edi, dword [rbx + CV_CLIP_X_OFF]
    add edi, dword [rbx + CV_CLIP_W_OFF]
    cmp esi, edi
    jge .nx
    mov edi, dword [rbx + CV_CLIP_Y_OFF]
    add edi, dword [rbx + CV_CLIP_H_OFF]
    cmp eax, edi
    jge .nx

    mov eax, edx
    imul eax, ebp
    cdqe
    mov esi, ecx
    shl esi, 2
    movsxd rsi, esi
    add rax, rsi
    add rax, r15
    mov r10d, dword [rax]

    mov r11, qword [rbx + CV_BUFFER_OFF]
    mov eax, r14d
    add eax, edx
    imul eax, dword [rbx + CV_STRIDE_OFF]
    cdqe
    lea r11, [r11 + rax]
    lea rax, [r13 + rcx]
    lea r11, [r11 + rax*4]

    mov eax, r10d
    shr eax, 24
    test eax, eax
    jz .nx
    cmp eax, 255
    je .opaque

    push rcx
    push rdx

    mov r8d, eax                  ; sa
    mov esi, 255
    sub esi, r8d                  ; inv

    mov edi, dword [r11]

    mov eax, r10d
    and eax, 0xFF
    imul eax, r8d
    mov ecx, edi
    and ecx, 0xFF
    imul ecx, esi
    add eax, ecx
    imul eax, 257
    add eax, 257
    shr eax, 16
    push rax

    mov eax, r10d
    shr eax, 8
    and eax, 0xFF
    imul eax, r8d
    mov ecx, edi
    shr ecx, 8
    and ecx, 0xFF
    imul ecx, esi
    add eax, ecx
    imul eax, 257
    add eax, 257
    shr eax, 16
    push rax

    mov eax, r10d
    shr eax, 16
    and eax, 0xFF
    imul eax, r8d
    mov ecx, edi
    shr ecx, 16
    and ecx, 0xFF
    imul ecx, esi
    add eax, ecx
    imul eax, 257
    add eax, 257
    shr eax, 16

    pop rdx
    pop rcx
    shl eax, 16
    shl edx, 8
    or eax, edx
    or eax, ecx
    or eax, 0xFF000000
    mov dword [r11], eax

    pop rdx
    pop rcx
    jmp .nx

.opaque:
    mov dword [r11], r10d

.nx:
    inc ecx
    jmp .sx
.ny:
    inc edx
    jmp .sy

.di_ok:
    xor eax, eax
    jmp .di_out
.di_bad:
    mov eax, -1
.di_out:
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; canvas_draw_image_raw(canvas, src_pixels, dst_x, dst_y, width, height, src_stride)
; rdi, rsi, edx, ecx, r8d, r9d, r10d = src_stride
canvas_draw_image_raw:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp

    test rdi, rdi
    jz .raw_bad
    test rsi, rsi
    jz .raw_bad
    test r8, r8
    jle .raw_bad
    test r9, r9
    jle .raw_bad

    mov rbx, rdi
    mov r15, rsi
    mov r13d, edx
    mov r14d, ecx
    mov r12d, r8d
    mov ebp, r9d
    mov r11d, r10d

    xor edx, edx
.raw_sy:
    cmp edx, ebp
    jae .raw_ok
    xor ecx, ecx
.raw_sx:
    cmp ecx, r12d
    jae .raw_ny

    lea eax, [r13 + rcx]
    cmp eax, 0
    jl .raw_nx
    cmp eax, dword [rbx + CV_WIDTH_OFF]
    jge .raw_nx
    lea eax, [r14 + rdx]
    cmp eax, 0
    jl .raw_nx
    cmp eax, dword [rbx + CV_HEIGHT_OFF]
    jge .raw_nx

    mov eax, dword [rbx + CV_CLIP_W_OFF]
    test eax, eax
    jz .raw_nx
    lea esi, [r13 + rcx]
    lea eax, [r14 + rdx]
    cmp esi, dword [rbx + CV_CLIP_X_OFF]
    jl .raw_nx
    cmp eax, dword [rbx + CV_CLIP_Y_OFF]
    jl .raw_nx
    mov edi, dword [rbx + CV_CLIP_X_OFF]
    add edi, dword [rbx + CV_CLIP_W_OFF]
    cmp esi, edi
    jge .raw_nx
    mov edi, dword [rbx + CV_CLIP_Y_OFF]
    add edi, dword [rbx + CV_CLIP_H_OFF]
    cmp eax, edi
    jge .raw_nx

    mov eax, edx
    imul eax, r11d
    cdqe
    mov esi, ecx
    shl esi, 2
    movsxd rsi, esi
    add rax, rsi
    add rax, r15
    mov r10d, dword [rax]

    mov r8, qword [rbx + CV_BUFFER_OFF]
    mov eax, r14d
    add eax, edx
    imul eax, dword [rbx + CV_STRIDE_OFF]
    cdqe
    lea r8, [r8 + rax]
    lea rax, [r13 + rcx]
    lea r8, [r8 + rax*4]

    mov eax, r10d
    shr eax, 24
    test eax, eax
    jz .raw_nx
    cmp eax, 255
    je .raw_opaque

    push rcx
    push rdx

    mov r9d, eax
    mov esi, 255
    sub esi, r9d

    mov edi, dword [r8]

    mov eax, r10d
    and eax, 0xFF
    imul eax, r9d
    mov ecx, edi
    and ecx, 0xFF
    imul ecx, esi
    add eax, ecx
    imul eax, 257
    add eax, 257
    shr eax, 16
    push rax

    mov eax, r10d
    shr eax, 8
    and eax, 0xFF
    imul eax, r9d
    mov ecx, edi
    shr ecx, 8
    and ecx, 0xFF
    imul ecx, esi
    add eax, ecx
    imul eax, 257
    add eax, 257
    shr eax, 16
    push rax

    mov eax, r10d
    shr eax, 16
    and eax, 0xFF
    imul eax, r9d
    mov ecx, edi
    shr ecx, 16
    and ecx, 0xFF
    imul ecx, esi
    add eax, ecx
    imul eax, 257
    add eax, 257
    shr eax, 16

    pop rdx
    pop rcx
    shl eax, 16
    shl edx, 8
    or eax, edx
    or eax, ecx
    or eax, 0xFF000000
    mov dword [r8], eax

    pop rdx
    pop rcx
    jmp .raw_nx

.raw_opaque:
    mov dword [r8], r10d

.raw_nx:
    inc ecx
    jmp .raw_sx
.raw_ny:
    inc edx
    jmp .raw_sy

.raw_ok:
    xor eax, eax
    jmp .raw_out
.raw_bad:
    mov eax, -1
.raw_out:
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; canvas_draw_image_scaled(canvas, image, x, y, dw, dh) rdi rsi rdx rcx r8 r9
; [rsp+0]=iw, +4=ih, +8=dw, +12=dh after sub rsp,16
canvas_draw_image_scaled:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp
    sub rsp, 16

    test rdi, rdi
    jz .ds_bad
    test rsi, rsi
    jz .ds_bad
    test r8, r8
    jle .ds_bad
    test r9, r9
    jle .ds_bad

    mov rbx, rdi
    mov r12, rsi
    mov r13d, edx
    mov r14d, ecx

    mov eax, r8d
    mov dword [rsp + 8], eax
    mov eax, r9d
    mov dword [rsp + 12], eax

    mov eax, dword [r12 + IMG_WIDTH_OFF]
    mov dword [rsp + 0], eax
    mov eax, dword [r12 + IMG_HEIGHT_OFF]
    mov dword [rsp + 4], eax
    test eax, eax
    jz .ds_bad
    cmp dword [rsp + 0], 0
    je .ds_bad

    xor r8d, r8d
.dsy:
    cmp r8d, dword [rsp + 12]
    jae .ds_ok
    xor ecx, ecx
.dsx:
    cmp ecx, dword [rsp + 8]
    jae .dny

    mov eax, r8d
    mul dword [rsp + 4]
    div dword [rsp + 12]
    mov r10d, eax                 ; sy

    mov eax, ecx
    mul dword [rsp + 0]
    div dword [rsp + 8]
    mov r9d, eax                  ; sx

    lea eax, [r13 + rcx]
    cmp eax, 0
    jl .dnx
    cmp eax, dword [rbx + CV_WIDTH_OFF]
    jge .dnx
    mov eax, r14d
    add eax, r8d
    cmp eax, 0
    jl .dnx
    cmp eax, dword [rbx + CV_HEIGHT_OFF]
    jge .dnx

    mov eax, dword [rbx + CV_CLIP_W_OFF]
    test eax, eax
    jz .dnx
    lea esi, [r13 + rcx]
    mov eax, r14d
    add eax, r8d
    cmp esi, dword [rbx + CV_CLIP_X_OFF]
    jl .dnx
    cmp eax, dword [rbx + CV_CLIP_Y_OFF]
    jl .dnx
    mov edi, dword [rbx + CV_CLIP_X_OFF]
    add edi, dword [rbx + CV_CLIP_W_OFF]
    cmp esi, edi
    jge .dnx
    mov edi, dword [rbx + CV_CLIP_Y_OFF]
    add edi, dword [rbx + CV_CLIP_H_OFF]
    cmp eax, edi
    jge .dnx

    mov esi, dword [r12 + IMG_STRIDE_OFF]
    mov eax, r10d
    imul eax, esi
    cdqe
    mov rdi, qword [r12 + IMG_PIXELS_OFF]
    add rax, rdi
    mov esi, r9d
    shl esi, 2
    movsxd rsi, esi
    add rax, rsi
    mov r10d, dword [rax]

    mov r11, qword [rbx + CV_BUFFER_OFF]
    mov eax, r14d
    add eax, r8d
    imul eax, dword [rbx + CV_STRIDE_OFF]
    cdqe
    lea r11, [r11 + rax]
    lea rax, [r13 + rcx]
    lea r11, [r11 + rax*4]

    mov eax, r10d
    shr eax, 24
    test eax, eax
    jz .dnx
    cmp eax, 255
    je .ds_opq

    push rcx
    push r8

    mov r8d, eax
    mov esi, 255
    sub esi, r8d

    mov edi, dword [r11]

    mov eax, r10d
    and eax, 0xFF
    imul eax, r8d
    mov ecx, edi
    and ecx, 0xFF
    imul ecx, esi
    add eax, ecx
    imul eax, 257
    add eax, 257
    shr eax, 16
    push rax

    mov eax, r10d
    shr eax, 8
    and eax, 0xFF
    imul eax, r8d
    mov ecx, edi
    shr ecx, 8
    and ecx, 0xFF
    imul ecx, esi
    add eax, ecx
    imul eax, 257
    add eax, 257
    shr eax, 16
    push rax

    mov eax, r10d
    shr eax, 16
    and eax, 0xFF
    imul eax, r8d
    mov ecx, edi
    shr ecx, 16
    and ecx, 0xFF
    imul ecx, esi
    add eax, ecx
    imul eax, 257
    add eax, 257
    shr eax, 16
    pop rdx
    pop rcx
    shl eax, 16
    shl rdx, 8
    or eax, edx
    or eax, ecx
    or eax, 0xFF000000
    mov dword [r11], eax

    pop r8
    pop rcx
    jmp .dnx

.ds_opq:
    mov dword [r11], r10d

.dnx:
    inc ecx
    jmp .dsx
.dny:
    inc r8d
    jmp .dsy

.ds_ok:
    xor eax, eax
    jmp .ds_out
.ds_bad:
    mov eax, -1
.ds_out:
    add rsp, 16
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; canvas_vline(canvas_ptr, x, y1, y2, color)
; Params: rdi,rsi,rdx,rcx,r8
; Return: rax=0/-1
; Complexity: O(length)
canvas_vline:
    cmp rdx, rcx
    jle .ordered
    xchg rdx, rcx
.ordered:
    mov r9, r8
    mov r8, rcx
    sub r8, rdx
    inc r8
    mov rcx, 1
    call canvas_fill_rect
    ret
