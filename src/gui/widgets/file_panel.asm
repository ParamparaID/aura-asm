; file_panel.asm — custom file manager panel widget
%include "src/hal/platform_defs.inc"
%include "src/gui/widget.inc"
%include "src/fm/panel.inc"

extern widget_init
extern widget_set_dirty
extern widget_arena_alloc
extern canvas_fill_rect
extern panel_navigate
extern panel_go_parent
extern panel_toggle_mark
extern panel_mark_all
extern panel_unmark_all

%ifdef AURA_WIN64
; Win32 path: window.asm passes virtual-key codes in key events.
%define KEY_UP                      0x26
%define KEY_DOWN                    0x28
%define KEY_HOME                    0x24
%define KEY_END                     0x23
%define KEY_ENTER                   0x0D
%define KEY_BACKSPACE               0x08
%define KEY_SPACE                   0x20
%define KEY_TAB                     0x09
%define KEY_A                       0x41
%else
%define KEY_UP                      103
%define KEY_DOWN                    108
%define KEY_HOME                    102
%define KEY_END                     107
%define KEY_ENTER                   28
%define KEY_BACKSPACE               14
%define KEY_SPACE                   57
%define KEY_TAB                     15
%define KEY_A                       30
%endif
%define INPUT_EVENT_MODIFIERS_OFF   24
%define MOD_CTRL                    0x02

%define FILE_PANEL_DATA_SIZE        32
%define FPD_PANEL_OFF               0
%define FPD_ROW_H_OFF               8
%define FPD_HEAD_H_OFF              12

section .text
global file_panel_create
global w_file_panel_render
global w_file_panel_measure
global w_file_panel_handle_input
global w_file_panel_layout
global w_file_panel_destroy

file_panel_create:
    ; (panel* rdi, x esi, y edx, w ecx, h r8d) -> rax Widget*
    push rbx
    push r12
    mov rbx, rdi
    mov edi, WIDGET_CONTAINER
    call widget_init
    test rax, rax
    jz .out
    mov r12, rax
    mov rdi, FILE_PANEL_DATA_SIZE
    call widget_arena_alloc
    test rax, rax
    jz .out
    mov [rax + FPD_PANEL_OFF], rbx
    mov dword [rax + FPD_ROW_H_OFF], 22
    mov dword [rax + FPD_HEAD_H_OFF], 26
    mov [r12 + W_DATA_OFF], rax
    lea rax, [rel w_file_panel_render]
    mov [r12 + W_FN_RENDER_OFF], rax
    lea rax, [rel w_file_panel_handle_input]
    mov [r12 + W_FN_HANDLE_OFF], rax
    lea rax, [rel w_file_panel_measure]
    mov [r12 + W_FN_MEASURE_OFF], rax
    lea rax, [rel w_file_panel_layout]
    mov [r12 + W_FN_LAYOUT_OFF], rax
    lea rax, [rel w_file_panel_destroy]
    mov [r12 + W_FN_DESTROY_OFF], rax
    mov rax, r12
.out:
    pop r12
    pop rbx
    ret

w_file_panel_measure:
    mov dword [rdi + W_PREF_W_OFF], 420
    mov dword [rdi + W_PREF_H_OFF], 300
    mov dword [rdi + W_MIN_W_OFF], 220
    mov dword [rdi + W_MIN_H_OFF], 140
    ret

w_file_panel_render:
    ; (widget rdi, canvas rsi, theme rdx, abs_x ecx, abs_y r8d)
    push rdi
    push rsi
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16
    mov dword [rsp + 0], ecx            ; abs_x
    mov dword [rsp + 4], r8d            ; abs_y
    mov r12, rdi
    mov r13, rsi
    mov r14, [r12 + W_DATA_OFF]
    test r14, r14
    jz .out
    mov r15, [r14 + FPD_PANEL_OFF]
    test r15, r15
    jz .out

    ; base background
    mov r9d, 0xFF171A20
    test rdx, rdx
    jz .bg
    mov r9d, [rdx + TH_SURFACE_OFF]
.bg:
    mov rdi, r13
    mov esi, [rsp + 0]
    mov edx, [rsp + 4]
    mov ecx, [r12 + W_WIDTH_OFF]
    mov r8d, [r12 + W_HEIGHT_OFF]
    call canvas_fill_rect

    ; breadcrumb/header strip
    mov r9d, 0xFF222834
    mov rdi, r13
    mov esi, [rsp + 0]
    mov edx, [rsp + 4]
    mov ecx, [r12 + W_WIDTH_OFF]
    mov r8d, [r14 + FPD_HEAD_H_OFF]
    call canvas_fill_rect

    ; draw rows
    mov ebx, [r15 + P_SCROLL_OFF]
    mov eax, [r15 + P_ENTRY_COUNT_OFF]
    mov dword [rsp + 8], eax             ; entry_count
    test eax, eax
    jnz .rows_init
    ; empty panel placeholder (high contrast) so FM is visibly alive
    mov rdi, r13
    mov esi, [rsp + 0]
    mov edx, [rsp + 4]
    add edx, [r14 + FPD_HEAD_H_OFF]
    add edx, 12
    mov ecx, [r12 + W_WIDTH_OFF]
    sub ecx, 24
    jle .status
    mov r8d, 28
    mov r9d, 0xFF3A5EA8
    call canvas_fill_rect
    jmp .status
.rows_init:
    mov dword [rsp + 12], 0              ; row_index
.rows:
    cmp ebx, [rsp + 8]
    jae .status
    ; y = abs_y + head + row*row_h
    mov eax, [rsp + 12]
    imul eax, [r14 + FPD_ROW_H_OFF]
    add eax, [r14 + FPD_HEAD_H_OFF]
    add eax, [rsp + 4]
    mov edx, eax
    mov eax, [rsp + 4]
    add eax, [r12 + W_HEIGHT_OFF]
    sub eax, 20
    cmp edx, eax
    jge .status

    ; selected row highlight
    mov eax, [r15 + P_SELECTED_IDX_OFF]
    cmp eax, ebx
    jne .norm
    mov r9d, 0xFF3A5EA8
    jmp .draw
.norm:
    mov eax, [rsp + 12]
    and eax, 1
    test eax, eax
    jz .z1
    mov r9d, 0xFF1E2530
    jmp .draw
.z1:
    mov r9d, 0xFF1A202A
.draw:
    mov rdi, r13
    mov esi, [rsp + 0]
    mov ecx, [r12 + W_WIDTH_OFF]
    mov r8d, [r14 + FPD_ROW_H_OFF]
    call canvas_fill_rect

    inc ebx
    mov eax, [rsp + 12]
    inc eax
    mov [rsp + 12], eax
    jmp .rows

.status:
    ; status line
    mov eax, [rsp + 4]
    add eax, [r12 + W_HEIGHT_OFF]
    sub eax, 20
    mov edx, eax
    mov r9d, 0xFF202734
    mov rdi, r13
    mov esi, [rsp + 0]
    mov ecx, [r12 + W_WIDTH_OFF]
    mov r8d, 20
    call canvas_fill_rect

.out:
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rsi
    pop rdi
    ret

w_file_panel_handle_input:
    ; (widget rdi, event rsi, abs_x edx, abs_y ecx) -> eax 1/0
    push rbx
    push r12
    mov rbx, [rdi + W_DATA_OFF]
    test rbx, rbx
    jz .no
    mov r12, [rbx + FPD_PANEL_OFF]
    test r12, r12
    jz .no

    mov eax, [rsi + IE_TYPE_OFF]
    cmp eax, INPUT_KEY
    je .key
    cmp eax, INPUT_TOUCH_DOWN
    je .point
    cmp eax, INPUT_MOUSE_BUTTON
    jne .no
    cmp dword [rsi + IE_KEY_STATE_OFF], KEY_PRESSED
    jne .no
    cmp dword [rsi + IE_KEY_CODE_OFF], 0x110
    jne .no
.point:
    mov eax, [rsi + IE_MOUSE_Y_OFF]
    sub eax, ecx
    sub eax, [rbx + FPD_HEAD_H_OFF]
    js .no
    cdq
    idiv dword [rbx + FPD_ROW_H_OFF]
    add eax, [r12 + P_SCROLL_OFF]
    cmp eax, [r12 + P_ENTRY_COUNT_OFF]
    jae .no
    mov [r12 + P_SELECTED_IDX_OFF], eax
    mov rdi, r12
    call panel_unmark_all
    mov eax, 1
    jmp .out

.key:
    cmp dword [rsi + IE_KEY_STATE_OFF], KEY_PRESSED
    jne .no
    mov eax, [rsi + IE_KEY_CODE_OFF]
    cmp eax, KEY_UP
    je .kup
    cmp eax, KEY_DOWN
    je .kdown
    cmp eax, KEY_HOME
    je .khome
    cmp eax, KEY_END
    je .kend
    cmp eax, KEY_BACKSPACE
    je .kback
    cmp eax, KEY_ENTER
    je .kenter
    cmp eax, KEY_SPACE
    je .kspace
    cmp eax, KEY_A
    jne .no
    test dword [rsi + INPUT_EVENT_MODIFIERS_OFF], MOD_CTRL
    jz .no
    mov rdi, r12
    call panel_mark_all
    mov eax, 1
    jmp .out
.kup:
    cmp dword [r12 + P_SELECTED_IDX_OFF], 0
    jle .cons
    dec dword [r12 + P_SELECTED_IDX_OFF]
    jmp .cons
.kdown:
    mov eax, [r12 + P_SELECTED_IDX_OFF]
    inc eax
    cmp eax, [r12 + P_ENTRY_COUNT_OFF]
    jge .cons
    mov [r12 + P_SELECTED_IDX_OFF], eax
    jmp .cons
.khome:
    mov dword [r12 + P_SELECTED_IDX_OFF], 0
    jmp .cons
.kend:
    mov eax, [r12 + P_ENTRY_COUNT_OFF]
    test eax, eax
    jz .cons
    dec eax
    mov [r12 + P_SELECTED_IDX_OFF], eax
    jmp .cons
.kback:
    mov rdi, r12
    call panel_go_parent
    jmp .cons
.kenter:
    mov esi, [r12 + P_SELECTED_IDX_OFF]
    mov rdi, r12
    call panel_navigate
    jmp .cons
.kspace:
    mov esi, [r12 + P_SELECTED_IDX_OFF]
    mov rdi, r12
    call panel_toggle_mark
.cons:
    mov eax, 1
    jmp .out

.no:
    xor eax, eax
.out:
    pop r12
    pop rbx
    ret

w_file_panel_layout:
    ret

w_file_panel_destroy:
    ret
