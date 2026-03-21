; tab_bar.asm — tabs + indicator spring
%include "src/hal/linux_x86_64/defs.inc"
%include "src/gui/widget.inc"

%define FP_DT_60 1092

extern canvas_fill_rect
extern spring_init
extern spring_set_target
extern spring_update
extern spring_value
%define TB_LABELS   0
%define TB_N        8
%define TB_ACTIVE   12
%define TB_IND      16          ; Spring
%define TB_ACCENT   44
%define TB_TABW     48

section .text
global w_tab_bar_render
global w_tab_bar_measure
global w_tab_bar_handle_input
global w_tab_bar_layout
global w_tab_bar_destroy

w_tab_bar_measure:
    mov dword [rdi + W_PREF_W_OFF], 400
    mov dword [rdi + W_PREF_H_OFF], TOUCH_TARGET_MIN
    mov dword [rdi + W_MIN_W_OFF], TOUCH_TARGET_MIN
    mov dword [rdi + W_MIN_H_OFF], TOUCH_TARGET_MIN
    ret

w_tab_bar_render:
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

    lea rdi, [rbx + TB_IND]
    mov esi, FP_DT_60
    call spring_update

    mov r9d, 0xFF1E1E1E
    mov rdi, r13
    mov esi, r14d
    mov edx, r15d
    mov ecx, [r12 + W_WIDTH_OFF]
    mov r8d, [r12 + W_HEIGHT_OFF]
    call canvas_fill_rect

    lea rdi, [rbx + TB_IND]
    call spring_value
    add eax, 0x8000
    sar eax, 16
    mov edx, r15d
    add edx, [r12 + W_HEIGHT_OFF]
    sub edx, 4
    mov esi, r14d
    add esi, eax
    mov r9d, [rbx + TB_ACCENT]
    mov ecx, [rbx + TB_TABW]
    mov r8d, 3
    mov rdi, r13
    call canvas_fill_rect
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

w_tab_bar_handle_input:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13, rsi
    mov r14d, edx
    mov rbx, [r12 + W_DATA_OFF]
    test rbx, rbx
    jz .no

    cmp dword [r13 + IE_TYPE_OFF], INPUT_TOUCH_DOWN
    je .go
    cmp dword [r13 + IE_TYPE_OFF], INPUT_MOUSE_BUTTON
    jne .no
    cmp dword [r13 + IE_KEY_CODE_OFF], 0x110
    jne .no
    cmp dword [r13 + IE_KEY_STATE_OFF], KEY_PRESSED
    jne .no
.go:
    mov eax, [r13 + IE_MOUSE_X_OFF]
    sub eax, r14d
    xor edx, edx
    div dword [rbx + TB_TABW]
    cmp eax, [rbx + TB_N]
    jae .no
    mov [rbx + TB_ACTIVE], eax
    lea rdi, [rbx + TB_IND]
    mov esi, eax
    imul esi, dword [rbx + TB_TABW]
    shl esi, 16
    call spring_set_target
    mov eax, 1
    jmp .ret
.no:
    xor eax, eax
.ret:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

w_tab_bar_layout:
    ret

w_tab_bar_destroy:
    ret
