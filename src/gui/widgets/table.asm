; table.asm — header strip + zebra rows + tap header cycles sort column
%include "src/hal/linux_x86_64/defs.inc"
%include "src/gui/widget.inc"

%define MOUSE_LEFT 0x110

extern font_draw_string
extern canvas_fill_rect
extern canvas_push_clip
extern canvas_pop_clip
extern widget_set_dirty

; TableData
%define TD_FONT     0
%define TD_FG       8
%define TD_HBG      12
%define TD_Z1       16
%define TD_Z2       20
%define TD_HDRH     24
%define TD_ROWH     28
%define TD_NROW     32
%define TD_SCROLL   36
%define TD_SORTCOL  40
%define TD_TITLE    44
%define TD_TLEN     52

section .text
global w_table_render
global w_table_measure
global w_table_handle_input
global w_table_layout
global w_table_destroy

w_table_measure:
    mov dword [rdi + W_PREF_W_OFF], 300
    mov dword [rdi + W_PREF_H_OFF], 200
    mov dword [rdi + W_MIN_W_OFF], TOUCH_TARGET_MIN
    mov dword [rdi + W_MIN_H_OFF], TOUCH_TARGET_MIN
    ret

w_table_render:
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

    mov rdi, r13
    mov esi, r14d
    mov edx, r15d
    mov ecx, [r12 + W_WIDTH_OFF]
    mov r8d, [r12 + W_HEIGHT_OFF]
    call canvas_push_clip

    mov r9d, [rbx + TD_HBG]
    mov ecx, [r12 + W_WIDTH_OFF]
    mov r8d, [rbx + TD_HDRH]
    mov rdi, r13
    mov esi, r14d
    mov edx, r15d
    call canvas_fill_rect

    mov rdi, [rbx + TD_FONT]
    test rdi, rdi
    jz .rows
    mov rsi, r13
    mov edx, r14d
    add edx, 6
    mov ecx, r15d
    add ecx, 6
    mov r8, [rbx + TD_TITLE]
    mov r9d, [rbx + TD_TLEN]
    sub rsp, 24
    mov dword [rsp], 13
    mov eax, [rbx + TD_FG]
    mov [rsp + 8], eax
    mov dword [rsp + 16], 0
    call font_draw_string
    add rsp, 24

.rows:
    xor r10d, r10d
.rloop:
    cmp r10d, [rbx + TD_NROW]
    jae .pop
    mov eax, r10d
    and eax, 1
    test eax, eax
    jz .z1
    mov r9d, [rbx + TD_Z2]
    jmp .dr
.z1:
    mov r9d, [rbx + TD_Z1]
.dr:
    mov edx, r15d
    add edx, [rbx + TD_HDRH]
    mov eax, r10d
    imul eax, [rbx + TD_ROWH]
    add edx, eax
    sub edx, [rbx + TD_SCROLL]
    mov eax, edx
    add eax, [rbx + TD_ROWH]
    cmp eax, r15d
    jle .next
    mov eax, r15d
    add eax, [r12 + W_HEIGHT_OFF]
    cmp edx, eax
    jge .next

    mov rdi, r13
    mov esi, r14d
    mov ecx, [r12 + W_WIDTH_OFF]
    mov r8d, [rbx + TD_ROWH]
    call canvas_fill_rect
.next:
    inc r10d
    jmp .rloop

.pop:
    mov rdi, r13
    call canvas_pop_clip
.out:
    pop r10
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

w_table_handle_input:
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
    cmp eax, [rbx + TD_HDRH]
    jge .no
    inc dword [rbx + TD_SORTCOL]
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

w_table_layout:
    ret

w_table_destroy:
    ret
