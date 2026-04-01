; progress_bar.asm — spring-smoothed fill (target in PB_TARGET fp)
%include "src/hal/platform_defs.inc"
%include "src/gui/widget.inc"

%define FP_DT_60 1092

extern canvas_fill_rounded_rect
extern spring_set_target
extern spring_update
extern spring_value

%define PB_TARGET   0           ; dd desired value 16.16
%define PB_SPRING   4           ; 28 bytes
%define PB_COL      32

section .text
global w_progress_render
global w_progress_measure
global w_progress_handle_input
global w_progress_layout
global w_progress_destroy

w_progress_measure:
    mov dword [rdi + W_PREF_W_OFF], 240
    mov dword [rdi + W_PREF_H_OFF], 24
    mov dword [rdi + W_MIN_W_OFF], 120
    mov dword [rdi + W_MIN_H_OFF], TOUCH_TARGET_MIN
    ret

w_progress_render:
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

    lea rdi, [rbx + PB_SPRING]
    mov esi, [rbx + PB_TARGET]
    call spring_set_target
    lea rdi, [rbx + PB_SPRING]
    mov esi, FP_DT_60
    call spring_update
    lea rdi, [rbx + PB_SPRING]
    call spring_value
    mov ecx, eax
    mov eax, [r12 + W_WIDTH_OFF]
    imul eax, ecx
    sar eax, 16
    mov r10d, eax

    mov rax, 0xFF333333
    push rax
    mov rdi, r13
    mov esi, r14d
    mov edx, r15d
    mov ecx, [r12 + W_WIDTH_OFF]
    mov r8d, [r12 + W_HEIGHT_OFF]
    mov r9d, 4
    call canvas_fill_rounded_rect
    add rsp, 8

    cmp r10d, 2
    jl .anim
    mov eax, [rbx + PB_COL]
    push rax
    mov rdi, r13
    mov esi, r14d
    mov edx, r15d
    mov ecx, r10d
    mov r8d, [r12 + W_HEIGHT_OFF]
    mov r9d, 4
    call canvas_fill_rounded_rect
    add rsp, 8
.anim:
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

w_progress_handle_input:
    xor eax, eax
    ret

w_progress_layout:
    ret

w_progress_destroy:
    ret
