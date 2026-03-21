; status_bar.asm — bottom strip + left/right text
%include "src/hal/linux_x86_64/defs.inc"
%include "src/gui/widget.inc"

extern font_draw_string
extern canvas_fill_rounded_rect

%define ST_BG       0
%define ST_FONT     4
%define ST_FG       12
%define ST_LEFT     20
%define ST_LEFTLEN  28
%define ST_RIGHT    32
%define ST_RIGHTLEN 40

section .text
global w_status_render
global w_status_measure
global w_status_handle_input
global w_status_layout
global w_status_destroy

w_status_measure:
    mov dword [rdi + W_PREF_W_OFF], 400
    mov dword [rdi + W_PREF_H_OFF], TOUCH_TARGET_MIN
    mov dword [rdi + W_MIN_W_OFF], TOUCH_TARGET_MIN
    mov dword [rdi + W_MIN_H_OFF], TOUCH_TARGET_MIN
    ret

w_status_render:
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

    mov eax, [rbx + ST_BG]
    push rax
    mov rdi, r13
    mov esi, r14d
    mov edx, r15d
    mov ecx, [r12 + W_WIDTH_OFF]
    mov r8d, [r12 + W_HEIGHT_OFF]
    mov r9d, 6
    call canvas_fill_rounded_rect
    add rsp, 8

    mov rdi, [rbx + ST_FONT]
    test rdi, rdi
    jz .out
    mov rsi, r13
    mov edx, r14d
    add edx, 8
    mov ecx, r15d
    add ecx, 8
    mov r8, [rbx + ST_LEFT]
    mov r9d, [rbx + ST_LEFTLEN]
    sub rsp, 24
    mov dword [rsp], 13
    mov eax, [rbx + ST_FG]
    mov [rsp + 8], eax
    mov dword [rsp + 16], 0
    call font_draw_string
    add rsp, 24

    mov rdi, [rbx + ST_FONT]
    mov rsi, r13
    mov edx, [r12 + W_WIDTH_OFF]
    add edx, r14d
    sub edx, 130
    mov ecx, r15d
    add ecx, 8
    mov r8, [rbx + ST_RIGHT]
    mov r9d, [rbx + ST_RIGHTLEN]
    sub rsp, 24
    mov dword [rsp], 13
    mov eax, [rbx + ST_FG]
    mov [rsp + 8], eax
    mov dword [rsp + 16], 0
    call font_draw_string
    add rsp, 24
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

w_status_handle_input:
    xor eax, eax
    ret

w_status_layout:
    ret

w_status_destroy:
    ret
