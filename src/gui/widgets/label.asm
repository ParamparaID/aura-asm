; label.asm — TrueType text label
%include "src/hal/platform_defs.inc"
%include "src/gui/widget.inc"

extern font_measure_string
extern font_draw_string

section .text
global w_label_render
global w_label_measure
global w_label_handle_input
global w_label_layout
global w_label_destroy

; LabelData: text_ptr dq, text_len dd, font_size dd, color dd, align dd, font dq

%define LD_TEXT      0
%define LD_LEN       8
%define LD_FONT_SZ   12
%define LD_COLOR     16
%define LD_ALIGN     20
%define LD_FONT      24

w_label_measure:
    push rbx
    mov rbx, rdi
    mov rax, [rbx + W_DATA_OFF]
    test rax, rax
    jz .def
    mov rdi, [rax + LD_FONT]
    test rdi, rdi
    jz .def
    mov rsi, [rax + LD_TEXT]
    mov edx, [rax + LD_LEN]
    mov ecx, [rax + LD_FONT_SZ]
    call font_measure_string
    mov [rbx + W_PREF_W_OFF], eax
    mov [rbx + W_PREF_H_OFF], edx
    cmp eax, TOUCH_TARGET_MIN
    jge .mw
    mov dword [rbx + W_PREF_W_OFF], TOUCH_TARGET_MIN
.mw:
    cmp edx, TOUCH_TARGET_MIN
    jge .mh
    mov dword [rbx + W_PREF_H_OFF], TOUCH_TARGET_MIN
.mh:
    mov eax, [rbx + W_PREF_W_OFF]
    mov [rbx + W_MIN_W_OFF], eax
    mov eax, [rbx + W_PREF_H_OFF]
    mov [rbx + W_MIN_H_OFF], eax
    pop rbx
    ret
.def:
    mov dword [rbx + W_PREF_W_OFF], TOUCH_TARGET_MIN
    mov dword [rbx + W_PREF_H_OFF], TOUCH_TARGET_MIN
    mov dword [rbx + W_MIN_W_OFF], TOUCH_TARGET_MIN
    mov dword [rbx + W_MIN_H_OFF], TOUCH_TARGET_MIN
    pop rbx
    ret

w_label_render:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push r10
    mov r12, rdi
    mov r13, rsi
    mov r14d, ecx
    mov r15d, r8d

    mov rbx, [r12 + W_DATA_OFF]
    test rbx, rbx
    jz .out
    mov rdi, [rbx + LD_FONT]
    test rdi, rdi
    jz .out

    mov rsi, [rbx + LD_TEXT]
    mov edx, [rbx + LD_LEN]
    mov ecx, [rbx + LD_FONT_SZ]
    call font_measure_string
    mov r10d, eax                 ; tw
    mov ecx, edx                  ; th (temp)

    mov eax, [rbx + LD_ALIGN]
    cmp eax, 1
    je .cen
    cmp eax, 2
    je .rgt
    mov esi, r14d                 ; pen x left
    jmp .ypos
.cen:
    mov esi, [r12 + W_WIDTH_OFF]
    sub esi, r10d
    sar esi, 1
    add esi, r14d
    jmp .ypos
.rgt:
    mov esi, [r12 + W_WIDTH_OFF]
    sub esi, r10d
    add esi, r14d
.ypos:
    mov eax, [r12 + W_HEIGHT_OFF]
    sub eax, ecx
    sar eax, 1
    add eax, r15d
    mov r8d, eax                  ; pen y

    mov rdi, [rbx + LD_FONT]
    mov rsi, r13
    mov edx, esi
    mov ecx, r8d
    mov r8, [rbx + LD_TEXT]
    mov r9d, [rbx + LD_LEN]
    sub rsp, 24
    mov eax, [rbx + LD_FONT_SZ]
    mov [rsp], eax
    mov eax, [rbx + LD_COLOR]
    mov [rsp + 8], eax
    mov dword [rsp + 16], 0
    call font_draw_string
    add rsp, 24
.out:
    pop r10
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

w_label_handle_input:
    xor eax, eax
    ret

w_label_layout:
    ret

w_label_destroy:
    ret
