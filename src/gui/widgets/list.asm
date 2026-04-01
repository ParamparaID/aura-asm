; list.asm — clipped list, inertia scroll, item height >= 44
%include "src/hal/platform_defs.inc"
%include "src/gui/widget.inc"

%define MOUSE_LEFT 0x110
%define FP_DT_60   1092

extern font_draw_string
extern canvas_fill_rect
extern canvas_push_clip
extern canvas_pop_clip
extern inertia_init
extern inertia_fling
extern inertia_update
extern inertia_value
extern widget_set_dirty

; ListData
%define LD_ITEMS    0
%define LD_COUNT    8
%define LD_ITEM_H   12
%define LD_FONT     16
%define LD_FG       24
%define LD_SEL      28
%define LD_INERT    32          ; 28 bytes
%define LD_DRAG     60
%define LD_LASTY    64
%define LD_IINIT    68
%define LD_TEXTLEN  72

section .text
global w_list_render
global w_list_measure
global w_list_handle_input
global w_list_layout
global w_list_destroy

; max_scroll -> eax (rbx=listdata, r12=widget)
%macro list_max_scroll 0
    mov eax, [rbx + LD_COUNT]
    imul eax, [rbx + LD_ITEM_H]
    sub eax, [r12 + W_HEIGHT_OFF]
    jns %%ok
    xor eax, eax
%%ok:
%endmacro

w_list_measure:
    push rbx
    push r12
    mov r12, rdi
    mov rbx, [r12 + W_DATA_OFF]
    test rbx, rbx
    jz .def

    mov eax, [rbx + LD_COUNT]
    imul eax, [rbx + LD_ITEM_H]
    cmp eax, 200
    jge .h
    mov eax, 200
.h:
    mov [r12 + W_PREF_H_OFF], eax
    mov eax, [r12 + W_WIDTH_OFF]
    test eax, eax
    jnz .wok
    mov eax, 240
.wok:
    mov [r12 + W_PREF_W_OFF], eax
    mov dword [r12 + W_MIN_W_OFF], TOUCH_TARGET_MIN
    mov dword [r12 + W_MIN_H_OFF], TOUCH_TARGET_MIN

    cmp dword [rbx + LD_IINIT], 1
    je .done
    list_max_scroll
    mov ecx, eax
    xor edx, edx
    mov r8d, 0x0000E800
    xor esi, esi
    lea rdi, [rbx + LD_INERT]
    call inertia_init
    mov dword [rbx + LD_IINIT], 1
.done:
    pop r12
    pop rbx
    ret
.def:
    mov dword [r12 + W_PREF_W_OFF], 240
    mov dword [r12 + W_PREF_H_OFF], 200
    pop r12
    pop rbx
    ret

w_list_render:
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

    lea rdi, [rbx + LD_INERT]
    mov esi, FP_DT_60
    call inertia_update

    lea rdi, [rbx + LD_INERT]
    call inertia_value
    mov r11d, eax                 ; scroll px

    mov rdi, r13
    mov esi, r14d
    mov edx, r15d
    mov ecx, [r12 + W_WIDTH_OFF]
    mov r8d, [r12 + W_HEIGHT_OFF]
    call canvas_push_clip

    xor r10d, r10d
.row:
    cmp r10d, [rbx + LD_COUNT]
    jae .popc

    mov eax, r10d
    imul eax, [rbx + LD_ITEM_H]
    sub eax, r11d
    add eax, r15d
    mov ecx, eax                  ; row top abs y

    mov eax, ecx
    add eax, [rbx + LD_ITEM_H]
    cmp eax, r15d
    jle .next

    mov eax, r15d
    add eax, [r12 + W_HEIGHT_OFF]
    cmp ecx, eax
    jge .next

    cmp r10d, [rbx + LD_SEL]
    jne .bg
    mov r9d, 0xFF4488FF
    jmp .fill
.bg:
    mov r9d, 0xFF202020
.fill:
    mov rdi, r13
    mov esi, r14d
    mov edx, ecx
    mov eax, [r12 + W_WIDTH_OFF]
    mov ecx, eax
    mov eax, [rbx + LD_ITEM_H]
    mov r8d, eax
    call canvas_fill_rect

    mov rax, [rbx + LD_ITEMS]
    mov r8, [rax + r10*8]
    mov rdi, [rbx + LD_FONT]
    test rdi, rdi
    jz .next
    mov eax, r10d
    imul eax, [rbx + LD_ITEM_H]
    sub eax, r11d
    add eax, r15d
    add eax, 10
    mov ecx, eax
    mov edx, r14d
    add edx, 8
    mov rsi, r13
    mov rdi, [rbx + LD_FONT]
    mov r9d, [rbx + LD_TEXTLEN]
    sub rsp, 24
    mov dword [rsp], 14
    mov eax, [rbx + LD_FG]
    mov [rsp + 8], eax
    mov dword [rsp + 16], 0
    call font_draw_string
    add rsp, 24
.next:
    inc r10d
    jmp .row

.popc:
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

w_list_handle_input:
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
    je .md
    cmp eax, INPUT_TOUCH_MOVE
    je .move
    cmp eax, INPUT_TOUCH_UP
    je .up
    jmp .no

.md:
    cmp dword [r13 + IE_KEY_CODE_OFF], MOUSE_LEFT
    jne .no
    cmp dword [r13 + IE_KEY_STATE_OFF], KEY_PRESSED
    jne .no
.down:
    mov dword [rbx + LD_DRAG], 1
    mov eax, [r13 + IE_MOUSE_Y_OFF]
    mov [rbx + LD_LASTY], eax

    lea rdi, [rbx + LD_INERT]
    call inertia_value
    mov ecx, [r13 + IE_MOUSE_Y_OFF]
    sub ecx, r15d
    add ecx, eax
    mov eax, ecx
    xor edx, edx
    div dword [rbx + LD_ITEM_H]
    mov [rbx + LD_SEL], eax

    mov rdi, r12
    call widget_set_dirty
    mov eax, 1
    jmp .ret

.move:
    cmp dword [rbx + LD_DRAG], 0
    je .no
    lea rdi, [rbx + LD_INERT]
    call inertia_value
    mov ecx, eax
    mov eax, [r13 + IE_MOUSE_Y_OFF]
    mov edx, eax
    sub eax, [rbx + LD_LASTY]
    mov [rbx + LD_LASTY], edx
    sub ecx, eax
    list_max_scroll
    mov r8d, eax
    xor eax, eax
    cmp ecx, eax
    cmovl ecx, eax
    cmp ecx, r8d
    cmovg ecx, r8d
    mov esi, ecx
    list_max_scroll
    mov ecx, eax
    xor edx, edx
    mov r8d, 0x0000E800
    lea rdi, [rbx + LD_INERT]
    call inertia_init

    mov rdi, r12
    call widget_set_dirty
    mov eax, 1
    jmp .ret

.up:
    mov dword [rbx + LD_DRAG], 0
    mov eax, [r13 + IE_MOUSE_Y_OFF]
    sub eax, [rbx + LD_LASTY]
    neg eax
    shl eax, 3
    lea rdi, [rbx + LD_INERT]
    mov esi, eax
    call inertia_fling
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

w_list_layout:
    ret

w_list_destroy:
    ret
