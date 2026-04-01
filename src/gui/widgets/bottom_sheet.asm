; bottom_sheet.asm — panel position spring (peek / full)
%include "src/hal/platform_defs.inc"
%include "src/gui/widget.inc"

%define FP_DT_60 1092

extern canvas_fill_rounded_rect
extern spring_init
extern spring_set_target
extern spring_update
extern spring_value
%define BS_SPRING   0
%define BS_COLOR    28

section .text
global w_bottom_sheet_render
global w_bottom_sheet_measure
global w_bottom_sheet_handle_input
global w_bottom_sheet_layout
global w_bottom_sheet_destroy

w_bottom_sheet_measure:
    mov dword [rdi + W_PREF_W_OFF], 320
    mov dword [rdi + W_PREF_H_OFF], 240
    mov dword [rdi + W_MIN_W_OFF], TOUCH_TARGET_MIN
    mov dword [rdi + W_MIN_H_OFF], 80
    ret

w_bottom_sheet_render:
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

    lea rdi, [rbx + BS_SPRING]
    mov esi, FP_DT_60
    call spring_update
    lea rdi, [rbx + BS_SPRING]
    call spring_value
    add eax, 0x8000
    sar eax, 16
    mov edx, r15d
    sub edx, eax
    mov eax, [rbx + BS_COLOR]
    push rax
    mov rdi, r13
    mov esi, r14d
    mov ecx, [r12 + W_WIDTH_OFF]
    mov r8d, [r12 + W_HEIGHT_OFF]
    mov r9d, 12
    call canvas_fill_rounded_rect
    add rsp, 8
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

w_bottom_sheet_handle_input:
    push rbx
    mov rbx, [rdi + W_DATA_OFF]
    test rbx, rbx
    jz .no
    cmp dword [rsi + IE_TYPE_OFF], INPUT_TOUCH_MOVE
    jne .no
    lea rdi, [rbx + BS_SPRING]
    mov esi, 0x00030000
    call spring_set_target
    mov eax, 1
    pop rbx
    ret
.no:
    xor eax, eax
    pop rbx
    ret

w_bottom_sheet_layout:
    ret

w_bottom_sheet_destroy:
    ret
