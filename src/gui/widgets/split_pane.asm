; split_pane.asm — vertical split + draggable divider (children 0=left 1=right)
%include "src/hal/linux_x86_64/defs.inc"
%include "src/gui/widget.inc"

%define MOUSE_LEFT 0x110

extern canvas_fill_rect
extern widget_set_dirty

%define SP_POS      0           ; 16.16 split from left
%define SP_DRAG     4
%define SP_LASTX    8

section .text
global w_split_render
global w_split_measure
global w_split_handle_input
global w_split_layout
global w_split_destroy

w_split_measure:
    mov eax, [rdi + W_WIDTH_OFF]
    mov [rdi + W_PREF_W_OFF], eax
    mov eax, [rdi + W_HEIGHT_OFF]
    mov [rdi + W_PREF_H_OFF], eax
    mov dword [rdi + W_MIN_W_OFF], TOUCH_TARGET_MIN
    mov dword [rdi + W_MIN_H_OFF], TOUCH_TARGET_MIN
    ret

w_split_render:
    push rdi
    push rsi
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    mov r12, rdi
    mov r13, rsi
    mov r14d, ecx
    mov r15d, r8d
    mov rbx, [r12 + W_DATA_OFF]
    test rbx, rbx
    jz .out

    mov eax, [rbx + SP_POS]
    add eax, 0x8000
    sar eax, 16
    add eax, r14d
    mov esi, eax
    mov edx, r15d
    mov r9d, 0xFF555555
    mov ecx, 4
    mov r8d, [r12 + W_HEIGHT_OFF]
    mov rdi, r13
    call canvas_fill_rect
.out:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rsi
    pop rdi
    ret

w_split_handle_input:
    push rdi
    push rsi
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    mov r12, rdi
    mov r13, rsi
    mov r14d, edx
    mov rbx, [r12 + W_DATA_OFF]
    test rbx, rbx
    jz .no

    cmp dword [r13 + IE_TYPE_OFF], INPUT_MOUSE_BUTTON
    je .md
    cmp dword [r13 + IE_TYPE_OFF], INPUT_TOUCH_MOVE
    je .mv
    cmp dword [r13 + IE_TYPE_OFF], INPUT_TOUCH_UP
    je .up
    jmp .no
.md:
    cmp dword [r13 + IE_KEY_CODE_OFF], MOUSE_LEFT
    jne .no
    cmp dword [r13 + IE_KEY_STATE_OFF], KEY_PRESSED
    jne .no
    mov dword [rbx + SP_DRAG], 1
    mov eax, [r13 + IE_MOUSE_X_OFF]
    mov [rbx + SP_LASTX], eax
    mov eax, 1
    jmp .ret
.mv:
    cmp dword [rbx + SP_DRAG], 0
    je .no
    mov eax, [r13 + IE_MOUSE_X_OFF]
    mov ecx, eax
    sub eax, [rbx + SP_LASTX]
    mov [rbx + SP_LASTX], ecx
    shl eax, 16
    add [rbx + SP_POS], eax
    mov rdi, r12
    call w_split_layout
    mov rdi, r12
    call widget_set_dirty
    mov eax, 1
    jmp .ret
.up:
    mov dword [rbx + SP_DRAG], 0
    mov eax, 1
    jmp .ret
.no:
    xor eax, eax
.ret:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rsi
    pop rdi
    ret

w_split_layout:
    push rdi
    push rsi
    push rbx
    push r12
    push r13
    push r14
    mov r12, rdi
    mov rbx, [r12 + W_DATA_OFF]
    test rbx, rbx
    jz .out
    mov rax, [r12 + W_CHILDREN_OFF]
    test rax, rax
    jz .out
    cmp dword [r12 + W_CHILD_COUNT_OFF], 2
    jb .out

    mov eax, [rbx + SP_POS]
    add eax, 0x8000
    sar eax, 16
    mov r13d, eax
    cmp r13d, 40
    jge .lok
    mov r13d, 40
.lok:
    mov ecx, [r12 + W_WIDTH_OFF]
    sub ecx, 40
    cmp r13d, ecx
    jle .rok
    mov r13d, ecx
.rok:
    mov rax, [r12 + W_CHILDREN_OFF]
    mov rdi, [rax]
    mov dword [rdi + W_X_OFF], 0
    mov dword [rdi + W_Y_OFF], 0
    mov dword [rdi + W_WIDTH_OFF], r13d
    mov ecx, [r12 + W_HEIGHT_OFF]
    mov [rdi + W_HEIGHT_OFF], ecx

    mov rdi, [rax + 8]
    mov dword [rdi + W_X_OFF], r13d
    add dword [rdi + W_X_OFF], 4
    mov dword [rdi + W_Y_OFF], 0
    mov ecx, [r12 + W_WIDTH_OFF]
    sub ecx, [rdi + W_X_OFF]
    mov dword [rdi + W_WIDTH_OFF], ecx
    mov ecx, [r12 + W_HEIGHT_OFF]
    mov [rdi + W_HEIGHT_OFF], ecx
.out:
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rsi
    pop rdi
    ret

w_split_destroy:
    ret
