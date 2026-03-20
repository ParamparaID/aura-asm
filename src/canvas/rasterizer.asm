; rasterizer.asm
; AuraCanvas software rasterizer primitives (ARGB32)
; Author: Aura Shell Team
; Date: 2026-03-20

%include "src/hal/linux_x86_64/defs.inc"

extern hal_mmap
extern hal_munmap
extern canvas_has_sse2
extern canvas_fill_rect_simd
extern canvas_clear_simd

%define PAGE_SIZE                4096
%define MAX_CANVAS               8

%define CV_BUFFER_OFF            0
%define CV_WIDTH_OFF             8
%define CV_HEIGHT_OFF            12
%define CV_STRIDE_OFF            16
%define CV_PAD_OFF               20
%define CV_SIZE_OFF              24
%define CV_STRUCT_SIZE           32

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
    mov r8, [rdi + CV_BUFFER_OFF]
    mov eax, [rdi + CV_STRIDE_OFF]
    imul rdx, rax
    lea rax, [rsi*4]
    add rdx, rax
    add r8, rdx
    mov dword [r8], ecx
.ok:
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
