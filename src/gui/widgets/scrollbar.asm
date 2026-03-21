; scrollbar.asm — track + thumb, opacity spring (fade)
%include "src/hal/linux_x86_64/defs.inc"
%include "src/gui/widget.inc"

%define FP_DT_60 1092

extern canvas_fill_rect
extern canvas_fill_rect_alpha
extern spring_init
extern spring_set_target
extern spring_update
extern spring_value
extern widget_set_dirty

%define SB_VERT     0
%define SB_OPAC     4           ; Spring 28 bytes
%define SB_THUMB    32
%define SB_TRACK    36

section .text
global w_scrollbar_render
global w_scrollbar_measure
global w_scrollbar_handle_input
global w_scrollbar_layout
global w_scrollbar_destroy

w_scrollbar_measure:
    mov dword [rdi + W_PREF_W_OFF], 12
    mov dword [rdi + W_PREF_H_OFF], 120
    mov dword [rdi + W_MIN_W_OFF], 8
    mov dword [rdi + W_MIN_H_OFF], TOUCH_TARGET_MIN
    ret

w_scrollbar_render:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13, rsi
    mov r14d, ecx
    mov r15d, r8d
    mov rbx, [r12 + W_DATA_OFF]
    test rbx, rbx
    jz .out

    lea rdi, [rbx + SB_OPAC]
    mov esi, FP_DT_60
    call spring_update
    lea rdi, [rbx + SB_OPAC]
    call spring_value
    mov edi, eax
    add edi, 0x8000
    sar edi, 16
    cmp edi, 2
    jl .out
    imul edi, edi
    cmp edi, 255
    jle .aok
    mov edi, 255
.aok:
    shl edi, 24
    or edi, 0x00AAAAAA
    mov r9d, edi

    mov rdi, r13
    mov esi, r14d
    mov edx, r15d
    mov ecx, [r12 + W_WIDTH_OFF]
    mov r8d, [r12 + W_HEIGHT_OFF]
    call canvas_fill_rect_alpha

    mov r9d, 0xFF666666
    mov ecx, 4
    mov r8d, [r12 + W_HEIGHT_OFF]
    sub r8d, 8
    mov rdi, r13
    mov esi, r14d
    mov edx, r15d
    add edx, 4
    call canvas_fill_rect

    mov eax, [rbx + SB_THUMB]
    imul eax, [r12 + W_HEIGHT_OFF]
    mov ecx, [rbx + SB_TRACK]
    test ecx, ecx
    jz .out
    xor edx, edx
    div ecx
    add eax, r15d
    add eax, 4
    mov edx, eax
    mov r9d, 0xFFCCCCCC
    mov ecx, [r12 + W_WIDTH_OFF]
    sub ecx, 4
    mov r8d, 24
    mov rdi, r13
    mov esi, r14d
    add esi, 2
    call canvas_fill_rect

    lea rdi, [rbx + SB_OPAC]
    call spring_value
    cmp eax, 0x00010000
    jge .out
    mov rdi, r12
    call widget_set_dirty
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

w_scrollbar_handle_input:
    push rbx
    mov rbx, [rdi + W_DATA_OFF]
    test rbx, rbx
    jz .no
    lea rdi, [rbx + SB_OPAC]
    mov esi, 0x00010000
    call spring_set_target
    mov eax, 1
    pop rbx
    ret
.no:
    xor eax, eax
    pop rbx
    ret

w_scrollbar_layout:
    ret

w_scrollbar_destroy:
    ret
