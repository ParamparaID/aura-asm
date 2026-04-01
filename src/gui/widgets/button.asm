; button.asm — rounded rect + label + ripple (spring)
%include "src/hal/platform_defs.inc"
%include "src/gui/widget.inc"

extern font_measure_string
extern font_draw_string
extern canvas_fill_rounded_rect
extern canvas_fill_rect_alpha
extern widget_set_dirty
extern spring_init
extern spring_set_target
extern spring_update
extern spring_value

%define FP_DT_60       1092
%define RIPPLE_ALPHA   0x33000000

; ButtonData
%define BD_TEXT        0
%define BD_LEN         8
%define BD_ONCLICK     16
%define BD_FONT        24
%define BD_BG          32
%define BD_FG          36
%define BD_STATE       40
%define BD_RIPX        44
%define BD_RIPY        48
%define BD_RIPPLE      52          ; Spring 28 bytes
%define BD_DOWN        80

%define MOUSE_LEFT      0x110

section .text
global w_button_render
global w_button_measure
global w_button_handle_input
global w_button_layout
global w_button_destroy

w_button_measure:
    push rbx
    mov rbx, rdi
    mov rax, [rbx + W_DATA_OFF]
    test rax, rax
    jz .def
    mov rdi, [rax + BD_FONT]
    test rdi, rdi
    jz .def
    mov rsi, [rax + BD_TEXT]
    mov edx, [rax + BD_LEN]
    mov ecx, 16
    cmp dword [rax + BD_LEN], 0
    je .def
    mov ecx, 16
    call font_measure_string
    add eax, 24
    add edx, 16
    cmp eax, TOUCH_TARGET_MIN
    jge .mw
    mov eax, TOUCH_TARGET_MIN
.mw:
    cmp edx, TOUCH_TARGET_MIN
    jge .mh
    mov edx, TOUCH_TARGET_MIN
.mh:
    mov [rbx + W_PREF_W_OFF], eax
    mov [rbx + W_PREF_H_OFF], edx
    mov [rbx + W_MIN_W_OFF], eax
    mov [rbx + W_MIN_H_OFF], edx
    pop rbx
    ret
.def:
    mov dword [rbx + W_PREF_W_OFF], TOUCH_TARGET_MIN
    mov dword [rbx + W_PREF_H_OFF], TOUCH_TARGET_MIN
    mov dword [rbx + W_MIN_W_OFF], TOUCH_TARGET_MIN
    mov dword [rbx + W_MIN_H_OFF], TOUCH_TARGET_MIN
    pop rbx
    ret

w_button_render:
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

    lea rdi, [rbx + BD_RIPPLE]
    mov esi, FP_DT_60
    call spring_update

    mov ecx, [r12 + W_WIDTH_OFF]
    mov r8d, [r12 + W_HEIGHT_OFF]
    cmp ecx, 8
    jl .out
    cmp r8d, 8
    jl .out
    mov eax, [rbx + BD_BG]
    push rax
    mov rdi, r13
    mov esi, r14d
    mov edx, r15d
    mov r9d, 6
    call canvas_fill_rounded_rect
    add rsp, 8

    lea rdi, [rbx + BD_RIPPLE]
    call spring_value
    mov edi, eax
    call fp_to_int_local
    mov ecx, eax                  ; radius px
    cmp ecx, 2
    jl .txt
    mov esi, [rbx + BD_RIPX]
    add esi, r14d
    sub esi, ecx
    mov edx, [rbx + BD_RIPY]
    add edx, r15d
    sub edx, ecx
    mov r10d, ecx
    shl r10d, 1
    mov ecx, r10d                 ; w
    mov r8d, r10d                 ; h
    mov rdi, r13
    mov r9d, 0x33FFFFFF
    call canvas_fill_rect_alpha
.txt:
    mov rdi, [rbx + BD_FONT]
    test rdi, rdi
    jz .after_text
    mov rsi, [rbx + BD_TEXT]
    mov edx, [rbx + BD_LEN]
    mov ecx, 16
    call font_measure_string
    mov r10d, eax
    mov r11d, edx
    mov esi, [r12 + W_WIDTH_OFF]
    sub esi, r10d
    sar esi, 1
    add esi, r14d
    mov eax, [r12 + W_HEIGHT_OFF]
    sub eax, r11d
    sar eax, 1
    add eax, r15d
    mov ecx, eax
    mov rdi, [rbx + BD_FONT]
    mov rsi, r13
    mov edx, esi
    mov r8, [rbx + BD_TEXT]
    mov r9d, [rbx + BD_LEN]
    sub rsp, 24
    mov dword [rsp], 16
    mov eax, [rbx + BD_FG]
    mov [rsp + 8], eax
    mov dword [rsp + 16], 0
    call font_draw_string
    add rsp, 24
.after_text:
    lea rdi, [rbx + BD_RIPPLE]
    call spring_value
    test eax, eax
    jz .out
    mov rdi, r12
    call widget_set_dirty
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

fp_to_int_local:
    add edi, 0x8000
    sar edi, 16
    mov eax, edi
    ret

; rdi=widget, rsi=event, rdx=abs_x, rcx=abs_y
w_button_handle_input:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13, rsi
    mov r14d, edx
    mov r15d, ecx

    mov rbx, [r12 + W_DATA_OFF]
    test rbx, rbx
    jz .no

    mov eax, [r13 + IE_TYPE_OFF]
    cmp eax, INPUT_TOUCH_DOWN
    je .down
    cmp eax, INPUT_MOUSE_BUTTON
    je .mouse
    cmp eax, INPUT_TOUCH_UP
    je .up
    jmp .no

.mouse:
    cmp dword [r13 + IE_KEY_CODE_OFF], MOUSE_LEFT
    jne .no
    cmp dword [r13 + IE_KEY_STATE_OFF], KEY_PRESSED
    jne .no
.down:
    mov eax, [r13 + IE_MOUSE_X_OFF]
    sub eax, r14d
    mov [rbx + BD_RIPX], eax
    mov eax, [r13 + IE_MOUSE_Y_OFF]
    sub eax, r15d
    mov [rbx + BD_RIPY], eax
    mov dword [rbx + BD_STATE], 2
    lea rdi, [rbx + BD_RIPPLE]
    xor esi, esi
    mov edx, esi
    mov ecx, 0x00018000
    mov r8d, 0x0000C000
    call spring_init
    lea rdi, [rbx + BD_RIPPLE]
    mov esi, 0x00500000
    call spring_set_target
    mov rdi, r12
    call widget_set_dirty
    mov eax, 1
    jmp .ret

.up:
    mov dword [rbx + BD_STATE], 0
    mov rax, [rbx + BD_ONCLICK]
    test rax, rax
    jz .after_cb
    call rax
.after_cb:
    lea rdi, [rbx + BD_RIPPLE]
    xor esi, esi
    call spring_set_target
    mov rdi, r12
    call widget_set_dirty
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

w_button_layout:
    ret

w_button_destroy:
    ret
