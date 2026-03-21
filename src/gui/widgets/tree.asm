; tree.asm — flat tree lines with indent + tap row toggles expand flag
%include "src/hal/linux_x86_64/defs.inc"
%include "src/gui/widget.inc"

%define MOUSE_LEFT 0x110

extern font_draw_string
extern canvas_fill_rect
extern widget_set_dirty

%define TR_LINES    0
%define TR_COUNT    8
%define TR_FONT     16
%define TR_FG       24
%define TR_EXP      32
%define TR_SEL      40
%define TR_ROWH     44

section .text
global w_tree_render
global w_tree_measure
global w_tree_handle_input
global w_tree_layout
global w_tree_destroy

w_tree_measure:
    mov dword [rdi + W_PREF_W_OFF], 260
    mov dword [rdi + W_PREF_H_OFF], 180
    mov dword [rdi + W_MIN_W_OFF], TOUCH_TARGET_MIN
    mov dword [rdi + W_MIN_H_OFF], TOUCH_TARGET_MIN
    ret

w_tree_render:
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

    xor r10d, r10d
.loop:
    cmp r10d, [rbx + TR_COUNT]
    jae .out
    cmp r10d, [rbx + TR_SEL]
    jne .ns
    mov r9d, 0xFF3355AA
    jmp .bg
.ns:
    mov r9d, 0xFF181818
.bg:
    mov edx, r15d
    mov eax, r10d
    imul eax, [rbx + TR_ROWH]
    add edx, eax
    mov rdi, r13
    mov esi, r14d
    mov ecx, [r12 + W_WIDTH_OFF]
    mov r8d, [rbx + TR_ROWH]
    call canvas_fill_rect

    mov rax, [rbx + TR_LINES]
    mov r8, [rax + r10*8]
    mov rdi, [rbx + TR_FONT]
    test rdi, rdi
    jz .nx
    mov rsi, r13
    mov edx, r14d
    add edx, 12
    mov eax, r10d
    imul eax, [rbx + TR_ROWH]
    add eax, r15d
    add eax, 10
    mov ecx, eax
    mov r9d, 20
    sub rsp, 24
    mov dword [rsp], 13
    mov eax, [rbx + TR_FG]
    mov [rsp + 8], eax
    mov dword [rsp + 16], 0
    call font_draw_string
    add rsp, 24
.nx:
    inc r10d
    jmp .loop

.out:
    pop r10
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

w_tree_handle_input:
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

    cmp dword [r13 + IE_TYPE_OFF], INPUT_TOUCH_DOWN
    je .go
    cmp dword [r13 + IE_TYPE_OFF], INPUT_MOUSE_BUTTON
    jne .no
    cmp dword [r13 + IE_KEY_CODE_OFF], MOUSE_LEFT
    jne .no
    cmp dword [r13 + IE_KEY_STATE_OFF], KEY_PRESSED
    jne .no
.go:
    mov eax, [r13 + IE_MOUSE_Y_OFF]
    sub eax, r15d
    xor edx, edx
    div dword [rbx + TR_ROWH]
    cmp eax, [rbx + TR_COUNT]
    jae .no
    mov r8d, eax
    mov [rbx + TR_SEL], r8d
    mov rcx, [rbx + TR_EXP]
    test rcx, rcx
    jz .dirty
    movzx eax, byte [rcx + r8]
    xor al, 1
    mov [rcx + r8], al
.dirty:
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

w_tree_layout:
    ret

w_tree_destroy:
    ret
