; cursor.asm — compositor cursor (MVP default arrow)
%include "src/hal/linux_x86_64/defs.inc"

extern canvas_draw_image_raw

%define CURSOR_DEFAULT                0
%define CURSOR_POINTER                1
%define CURSOR_RESIZE_H               2
%define CURSOR_RESIZE_V               3
%define CURSOR_RESIZE_DIAG            4
%define CURSOR_TEXT                   5
%define CURSOR_MOVE                   6

; CursorState
%define CR_X_OFF                      0
%define CR_Y_OFF                      4
%define CR_IMAGE_OFF                  8
%define CR_HOT_X_OFF                  16
%define CR_HOT_Y_OFF                  20
%define CR_VISIBLE_OFF                24
%define CR_SHAPE_OFF                  28
%define CR_STRUCT_SIZE                32

section .rodata
align 4
cursor_default_pixels:
    dd 0xFFFFFFFF,0xFF000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000
    dd 0xFFFFFFFF,0xFFFFFFFF,0xFF000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000
    dd 0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF,0xFF000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000
    dd 0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF,0xFF000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000
    dd 0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF,0xFF000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000
    dd 0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF,0xFF000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000
    dd 0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF,0xFF000000,0x00000000,0x00000000,0x00000000,0x00000000
    dd 0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF,0xFF000000,0x00000000,0x00000000,0x00000000
    dd 0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF,0xFF000000,0xFF000000,0x00000000,0x00000000,0x00000000
    dd 0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF,0xFF000000,0x00000000,0xFF000000,0x00000000,0x00000000,0x00000000
    dd 0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF,0xFF000000,0x00000000,0x00000000,0xFF000000,0x00000000,0x00000000,0x00000000
    dd 0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF,0xFF000000,0x00000000,0x00000000,0x00000000,0xFF000000,0x00000000,0x00000000,0x00000000
    dd 0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF,0xFF000000,0x00000000,0x00000000,0x00000000,0x00000000,0xFF000000,0x00000000,0x00000000,0x00000000
    dd 0xFFFFFFFF,0xFFFFFFFF,0xFF000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0xFF000000,0x00000000,0x00000000,0x00000000
    dd 0xFFFFFFFF,0xFF000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0xFF000000,0x00000000,0x00000000,0x00000000
    dd 0xFF000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0xFF000000,0x00000000,0x00000000,0x00000000

section .data
cursor_default_image:
    dd 12
    dd 16
    dq cursor_default_pixels
    dd 48

section .bss
    cursor_global                     resb CR_STRUCT_SIZE

section .text
global cursor_init
global cursor_set_shape
global cursor_render
global cursor_update_pos
global cursor_get_global
global cursor_render_global

cursor_get_global:
    lea rax, [rel cursor_global]
    ret

; cursor_init() -> rax CursorState*
cursor_init:
    lea rax, [rel cursor_global]
    mov dword [rax + CR_X_OFF], 0
    mov dword [rax + CR_Y_OFF], 0
    lea rcx, [rel cursor_default_image]
    mov [rax + CR_IMAGE_OFF], rcx
    mov dword [rax + CR_HOT_X_OFF], 0
    mov dword [rax + CR_HOT_Y_OFF], 0
    mov dword [rax + CR_VISIBLE_OFF], 1
    mov dword [rax + CR_SHAPE_OFF], CURSOR_DEFAULT
    ret

; cursor_set_shape(cursor, shape)
cursor_set_shape:
    test rdi, rdi
    jz .out
    mov [rdi + CR_SHAPE_OFF], esi
    ; MVP: always keep default bitmap.
.out:
    ret

; cursor_update_pos(cursor, x, y)
cursor_update_pos:
    test rdi, rdi
    jz .out
    mov [rdi + CR_X_OFF], esi
    mov [rdi + CR_Y_OFF], edx
.out:
    ret

; cursor_render(cursor, canvas)
cursor_render:
    push rbx
    push r12
    mov rbx, rdi
    mov r12, rsi
    test rbx, rbx
    jz .out
    test r12, r12
    jz .out
    cmp dword [rbx + CR_VISIBLE_OFF], 0
    je .out
    mov rsi, [rbx + CR_IMAGE_OFF]
    test rsi, rsi
    jz .out
    mov edx, [rbx + CR_X_OFF]
    sub edx, [rbx + CR_HOT_X_OFF]
    mov ecx, [rbx + CR_Y_OFF]
    sub ecx, [rbx + CR_HOT_Y_OFF]
    mov r8d, [rsi + 0]
    mov r9d, [rsi + 4]
    mov r10d, [rsi + 16]
    mov rsi, [rsi + 8]
    mov rdi, r12
    call canvas_draw_image_raw
.out:
    pop r12
    pop rbx
    ret

; cursor_render_global(canvas)
cursor_render_global:
    mov rsi, rdi
    lea rdi, [rel cursor_global]
    jmp cursor_render
