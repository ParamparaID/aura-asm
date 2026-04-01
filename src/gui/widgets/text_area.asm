; text_area.asm — multiline buffer + scroll_y
%include "src/hal/platform_defs.inc"
%include "src/gui/widget.inc"

%define MOUSE_LEFT 0x110

extern font_draw_string
extern canvas_fill_rounded_rect
extern canvas_push_clip
extern canvas_pop_clip
extern widget_set_dirty

%define TA_BUF_SZ   512
%define TA_BUF      0
%define TA_SCROLL   TA_BUF_SZ
%define TA_FONT     (TA_SCROLL + 4)
%define TA_FG       (TA_FONT + 8)
%define TA_BG       (TA_FG + 4)
%define TA_DRAG     (TA_BG + 4)
%define TA_LASTY    (TA_DRAG + 4)

section .text
global w_text_area_render
global w_text_area_measure
global w_text_area_handle_input
global w_text_area_layout
global w_text_area_destroy

w_text_area_measure:
    mov dword [rdi + W_PREF_W_OFF], 280
    mov dword [rdi + W_PREF_H_OFF], 160
    mov dword [rdi + W_MIN_W_OFF], TOUCH_TARGET_MIN
    mov dword [rdi + W_MIN_H_OFF], TOUCH_TARGET_MIN
    ret

w_text_area_render:
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
    mov eax, [rbx + TA_BG]
    push rax
    mov rdi, r13
    mov esi, r14d
    mov edx, r15d
    mov ecx, [r12 + W_WIDTH_OFF]
    mov r8d, [r12 + W_HEIGHT_OFF]
    mov r9d, 4
    call canvas_fill_rounded_rect
    add rsp, 8

    mov rdi, r13
    mov esi, r14d
    mov edx, r15d
    mov ecx, [r12 + W_WIDTH_OFF]
    mov r8d, [r12 + W_HEIGHT_OFF]
    call canvas_push_clip

    mov rdi, [rbx + TA_FONT]
    test rdi, rdi
    jz .pop
    mov rsi, r13
    mov edx, r14d
    add edx, 6
    mov ecx, r15d
    add ecx, 8
    sub ecx, [rbx + TA_SCROLL]
    lea r8, [rbx + TA_BUF]
    mov r9d, TA_BUF_SZ - 1
    sub rsp, 24
    mov dword [rsp], 13
    mov eax, [rbx + TA_FG]
    mov [rsp + 8], eax
    mov dword [rsp + 16], 0
    call font_draw_string
    add rsp, 24
.pop:
    mov rdi, r13
    call canvas_pop_clip
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

w_text_area_handle_input:
    push rbx
    push r12
    push r13
    mov r12, rdi
    mov r13, rsi
    mov rbx, [r12 + W_DATA_OFF]
    test rbx, rbx
    jz .no

    cmp dword [r13 + IE_TYPE_OFF], INPUT_SCROLL
    je .wheel
    cmp dword [r13 + IE_TYPE_OFF], INPUT_TOUCH_MOVE
    je .move
    cmp dword [r13 + IE_TYPE_OFF], INPUT_TOUCH_DOWN
    je .down
    cmp dword [r13 + IE_TYPE_OFF], INPUT_MOUSE_BUTTON
    jne .no
    cmp dword [r13 + IE_KEY_CODE_OFF], MOUSE_LEFT
    jne .no
.down:
    mov dword [rbx + TA_DRAG], 1
    mov eax, [r13 + IE_MOUSE_Y_OFF]
    mov [rbx + TA_LASTY], eax
    mov eax, 1
    jmp .ret
.move:
    cmp dword [rbx + TA_DRAG], 0
    je .no
    mov eax, [r13 + IE_MOUSE_Y_OFF]
    mov ecx, eax
    sub eax, [rbx + TA_LASTY]
    mov [rbx + TA_LASTY], ecx
    sub [rbx + TA_SCROLL], eax
    mov rdi, r12
    call widget_set_dirty
    mov eax, 1
    jmp .ret
.wheel:
    mov eax, [r13 + IE_SCROLL_DY_OFF]
    imul eax, 4
    sub [rbx + TA_SCROLL], eax
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

w_text_area_layout:
    ret

w_text_area_destroy:
    ret
