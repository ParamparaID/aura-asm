; text_input.asm — single-line buffer + cursor
%include "src/hal/platform_defs.inc"
%include "src/gui/widget.inc"

extern font_draw_string
extern canvas_fill_rounded_rect
extern widget_set_dirty

%define TI_BUF_SZ    128
%define TI_BUF       0
%define TI_CURSOR    TI_BUF_SZ
%define TI_FONT      (TI_CURSOR + 4)
%define TI_FG        (TI_FONT + 8)
%define TI_BG        (TI_FG + 4)
%define TI_PLH       (TI_BG + 4)
%define TI_PLHLEN    (TI_PLH + 8)

section .text
global w_text_input_render
global w_text_input_measure
global w_text_input_handle_input
global w_text_input_layout
global w_text_input_destroy

w_text_input_measure:
    mov dword [rdi + W_PREF_W_OFF], 200
    mov dword [rdi + W_PREF_H_OFF], TOUCH_TARGET_MIN
    mov dword [rdi + W_MIN_W_OFF], 120
    mov dword [rdi + W_MIN_H_OFF], TOUCH_TARGET_MIN
    ret

w_text_input_render:
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
    mov eax, [rbx + TI_BG]
    push rax
    mov rdi, r13
    mov esi, r14d
    mov edx, r15d
    mov ecx, [r12 + W_WIDTH_OFF]
    mov r8d, [r12 + W_HEIGHT_OFF]
    mov r9d, 4
    call canvas_fill_rounded_rect
    add rsp, 8
    mov rdi, [rbx + TI_FONT]
    test rdi, rdi
    jz .out
    mov ecx, [rbx + TI_CURSOR]
    cmp ecx, TI_BUF_SZ - 1
    jl .cok
    mov ecx, TI_BUF_SZ - 1
    mov [rbx + TI_CURSOR], ecx
.cok:
    mov byte [rbx + rcx + TI_BUF], 0
    lea r8, [rbx + TI_BUF]
    mov esi, ecx
    xor ecx, ecx
.len:
    cmp ecx, esi
    jae .ldone
    cmp byte [r8 + rcx], 0
    je .ldone
    inc ecx
    jmp .len
.ldone:
    mov r9d, ecx
    cmp r9d, 0
    jne .draw
    mov r8, [rbx + TI_PLH]
    test r8, r8
    jz .out
    mov r9d, [rbx + TI_PLHLEN]
.draw:
    mov rsi, r13
    mov edx, r14d
    add edx, 8
    mov ecx, r15d
    add ecx, 12
    sub rsp, 24
    mov dword [rsp], 14
    mov eax, [rbx + TI_FG]
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

w_text_input_handle_input:
    push rbx
    push r12
    push r13
    mov r12, rdi
    mov r13, rsi
    mov rbx, [r12 + W_DATA_OFF]
    test rbx, rbx
    jz .no
    cmp dword [r13 + IE_TYPE_OFF], INPUT_KEY
    jne .touch
    cmp dword [r13 + IE_KEY_STATE_OFF], KEY_PRESSED
    jne .no
    mov eax, [r13 + IE_KEY_CODE_OFF]
    cmp eax, 8
    je .bs
    cmp eax, KEY_LEFT
    je .left
    cmp eax, KEY_RIGHT
    je .right
    cmp eax, KEY_HOME
    je .home
    cmp eax, KEY_END
    je .end
    cmp eax, 32
    jl .no
    cmp eax, 126
    ja .no
    mov ecx, [rbx + TI_CURSOR]
    cmp ecx, TI_BUF_SZ - 2
    jge .no
    mov [rbx + rcx + TI_BUF], al
    inc dword [rbx + TI_CURSOR]
    jmp .dirty
.bs:
    cmp dword [rbx + TI_CURSOR], 0
    je .no
    dec dword [rbx + TI_CURSOR]
    mov ecx, [rbx + TI_CURSOR]
    mov byte [rbx + rcx + TI_BUF], 0
    jmp .dirty
.left:
    cmp dword [rbx + TI_CURSOR], 0
    je .no
    dec dword [rbx + TI_CURSOR]
    jmp .dirty
.right:
    mov ecx, [rbx + TI_CURSOR]
    cmp ecx, TI_BUF_SZ - 2
    jge .no
    inc dword [rbx + TI_CURSOR]
    jmp .dirty
.home:
    mov dword [rbx + TI_CURSOR], 0
    jmp .dirty
.end:
    xor ecx, ecx
.le:
    cmp ecx, TI_BUF_SZ - 1
    jge .dirty
    cmp byte [rbx + rcx + TI_BUF], 0
    je .dirty
    inc ecx
    jmp .le
.touch:
    cmp dword [r13 + IE_TYPE_OFF], INPUT_TOUCH_DOWN
    jne .no
    mov dword [rbx + TI_CURSOR], 0
.dirty:
    mov rdi, r12
    call widget_set_dirty
    mov eax, 1
    jmp .ret
.no:
    xor eax, eax
.ret:
    pop r13
    pop r12
    pop rbx
    ret

w_text_input_layout:
    ret

w_text_input_destroy:
    ret
