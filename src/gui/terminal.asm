; terminal.asm — REPL surface inside widget tree (rounded bg, optional blur)
%include "src/hal/platform_defs.inc"
%include "src/gui/widget.inc"
%include "src/gui/theme.inc"

extern canvas_fill_rounded_rect
extern canvas_blur_region
extern canvas_fill_rect_alpha
extern repl_draw
extern repl_handle_key
extern widget_init
extern widget_set_dirty

%define TD_REPL_OFF     0
%define TD_THEME_OFF    8
%define TD_PAD          6

section .bss
    term_singleton_data resq 2

section .text
global w_terminal_render
global w_terminal_measure
global w_terminal_handle_input
global w_terminal_layout
global w_terminal_destroy
global terminal_widget_init

w_terminal_measure:
    mov dword [rdi + W_PREF_W_OFF], 400
    mov dword [rdi + W_PREF_H_OFF], 240
    mov dword [rdi + W_MIN_W_OFF], 120
    mov dword [rdi + W_MIN_H_OFF], 80
    ret

w_terminal_layout:
    ret

w_terminal_destroy:
    ret

; repl*, theme*, width, height -> widget*
terminal_widget_init:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13, rsi
    mov r14d, edx
    mov r15d, ecx
    mov edi, WIDGET_TERMINAL
    xor esi, esi
    xor edx, edx
    mov ecx, r14d
    mov r8d, r15d
    call widget_init
    test rax, rax
    jz .out
    mov rbx, rax
    mov [rel term_singleton_data + TD_REPL_OFF], r12
    mov [rel term_singleton_data + TD_THEME_OFF], r13
    lea rax, [rel term_singleton_data]
    mov [rbx + W_DATA_OFF], rax
    mov rax, rbx
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

w_terminal_render:
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
    mov rcx, [rbx + TD_THEME_OFF]
    test rcx, rcx
    jz .out
    mov eax, [rcx + T_BG_OFF]
    push rax
    mov rdi, r13
    mov esi, r14d
    mov edx, r15d
    mov ecx, [r12 + W_WIDTH_OFF]
    mov r8d, [r12 + W_HEIGHT_OFF]
    mov r9d, [rcx + T_CORNER_RADIUS_OFF]
    call canvas_fill_rounded_rect
    add rsp, 8

    mov rcx, [rbx + TD_THEME_OFF]
    mov r10d, [rcx + T_BLUR_RADIUS_OFF]
    cmp r10d, 0
    jle .no_blur
    push r10
    mov rdi, r13
    mov esi, r14d
    mov edx, r15d
    mov ecx, [r12 + W_WIDTH_OFF]
    mov r8d, [r12 + W_HEIGHT_OFF]
    call canvas_blur_region
    add rsp, 8
    mov rcx, [rbx + TD_THEME_OFF]
    mov eax, [rcx + T_SURFACE_OFF]
    push rax
    mov rdi, r13
    mov esi, r14d
    mov edx, r15d
    mov ecx, [r12 + W_WIDTH_OFF]
    mov r8d, [r12 + W_HEIGHT_OFF]
    call canvas_fill_rect_alpha
    add rsp, 8
.no_blur:
    mov rdi, [rbx + TD_REPL_OFF]
    test rdi, rdi
    jz .out
    mov rsi, r13
    mov ecx, r14d
    add ecx, TD_PAD
    mov r8d, r15d
    add r8d, TD_PAD
    call repl_draw
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

w_terminal_handle_input:
    push rbx
    mov rbx, rdi
    mov eax, [rsi + IE_TYPE_OFF]
    cmp eax, INPUT_KEY
    jne .no
    cmp dword [rsi + IE_KEY_STATE_OFF], KEY_PRESSED
    jne .no
    mov rdi, [rbx + W_DATA_OFF]
    test rdi, rdi
    jz .no
    mov rdi, [rdi + TD_REPL_OFF]
    test rdi, rdi
    jz .no
    call repl_handle_key
    mov rdi, rbx
    call widget_set_dirty
    mov eax, 1
    jmp .out
.no:
    xor eax, eax
.out:
    pop rbx
    ret
