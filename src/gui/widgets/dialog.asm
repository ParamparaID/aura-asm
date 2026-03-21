; dialog.asm — semi-transparent backdrop + centered panel
%include "src/hal/linux_x86_64/defs.inc"
%include "src/gui/widget.inc"

%define FP_DT_60 1092

extern canvas_fill_rect_alpha
extern canvas_fill_rounded_rect
extern spring_set_target
extern spring_update
extern spring_value
%define DLG_BACK    0           ; Spring 28 — backdrop opacity as fp 0..1
%define DLG_PANEL   28          ; panel ARGB color

section .text
global w_dialog_render
global w_dialog_measure
global w_dialog_handle_input
global w_dialog_layout
global w_dialog_destroy

w_dialog_measure:
    mov dword [rdi + W_PREF_W_OFF], 320
    mov dword [rdi + W_PREF_H_OFF], 240
    mov dword [rdi + W_MIN_W_OFF], TOUCH_TARGET_MIN
    mov dword [rdi + W_MIN_H_OFF], TOUCH_TARGET_MIN
    ret

w_dialog_render:
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

    lea rdi, [rbx + DLG_BACK]
    mov esi, FP_DT_60
    call spring_update
    lea rdi, [rbx + DLG_BACK]
    call spring_value
    mov edi, eax
    add edi, 0x8000
    sar edi, 16
    cmp edi, 1
    jl .out
    imul edi, edi
    cmp edi, 180
    jle .aok
    mov edi, 180
.aok:
    shl edi, 24
    or edi, 0x00000000
    mov r9d, edi
    mov rdi, r13
    mov esi, r14d
    mov edx, r15d
    mov ecx, [r12 + W_WIDTH_OFF]
    mov r8d, [r12 + W_HEIGHT_OFF]
    call canvas_fill_rect_alpha

    mov eax, [rbx + DLG_PANEL]
    push rax
    mov ecx, 260
    mov r8d, 160
    mov esi, r14d
    add esi, [r12 + W_WIDTH_OFF]
    sub esi, ecx
    sar esi, 1
    mov edx, r15d
    add edx, [r12 + W_HEIGHT_OFF]
    sub edx, r8d
    sar edx, 1
    mov rdi, r13
    mov r9d, 10
    call canvas_fill_rounded_rect
    add rsp, 8
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

w_dialog_handle_input:
    push rbx
    mov rbx, [rdi + W_DATA_OFF]
    test rbx, rbx
    jz .no
    cmp dword [rsi + IE_TYPE_OFF], INPUT_TOUCH_DOWN
    jne .no
    lea rdi, [rbx + DLG_BACK]
    xor esi, esi
    call spring_set_target
    mov eax, 1
    pop rbx
    ret
.no:
    xor eax, eax
    pop rbx
    ret

w_dialog_layout:
    ret

w_dialog_destroy:
    ret
