; wm.asm — hybrid window manager (tiling + floating)
%include "src/compositor/compositor.inc"
%include "src/compositor/wm.inc"

extern tiling_init
extern tiling_add
extern tiling_layout
extern tiling_resize
extern tiling_swap
extern tiling_find_neighbor
extern tiling_set_split_mode
extern floating_add

%define KEY_1                       2
%define KEY_0                       11
%define KEY_Q                       16
%define KEY_ENTER                   28
%define KEY_F                       33
%define KEY_E                       18
%define KEY_H                       35
%define KEY_L                       38
%define KEY_V                       47
%define KEY_SPACE                   57
%define KEY_LEFTSHIFT               42
%define KEY_UP                      103
%define KEY_LEFT                    105
%define KEY_RIGHT                   106
%define KEY_DOWN                    108

section .bss
    wm_global_state      resb WM_STRUCT_SIZE
    wm_stack_list        resq WM_MAX_SURFACES
    wm_fm_toggle_request resd 1

section .text
global wm_init
global wm_add_surface
global wm_remove_surface
global wm_set_focus
global wm_get_focused
global wm_toggle_mode
global wm_set_surface_mode
global wm_relayout
global wm_get_global
global wm_handle_hotkey
global wm_take_fm_toggle_request

wm_take_fm_toggle_request:
    mov eax, [rel wm_fm_toggle_request]
    mov dword [rel wm_fm_toggle_request], 0
    ret

; wm_apply_simple_tiling(wm)
wm_apply_simple_tiling:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi
    xor r12d, r12d                    ; tiled count
    xor r13d, r13d                    ; scan index
    xor r14, r14                      ; master pointer

.scan:
    cmp r13d, dword [rbx + WM_SURFACE_COUNT_OFF]
    jae .have_list
    mov rax, [rbx + WM_SURFACES_OFF + r13*8]
    inc r13d
    test rax, rax
    jz .scan
    cmp dword [rax + SF_MAPPED_OFF], 0
    je .scan
    cmp dword [rax + SF_FLOATING_OFF], 0
    jne .scan
    cmp dword [rbx + WM_MODE_OFF], WM_MODE_FLOATING
    je .scan
    test r14, r14
    jnz .as_stack
    mov r14, rax
    inc r12d
    jmp .scan
.as_stack:
    mov [rel wm_stack_list + r12*8 - 8], rax
    inc r12d
    jmp .scan

.have_list:
    cmp r12d, 1
    jb .out
    ; one tiled surface: fullscreen-ish with gap
    cmp r12d, 1
    jne .multi
    mov eax, dword [rbx + WM_GAP_OFF]
    mov ecx, dword [rbx + WM_OUTPUT_X_OFF]
    add ecx, eax
    mov edx, dword [rbx + WM_OUTPUT_Y_OFF]
    add edx, eax
    mov dword [r14 + SF_SCREEN_X_OFF], ecx
    mov dword [r14 + SF_SCREEN_Y_OFF], edx
    mov ecx, dword [rbx + WM_OUTPUT_W_OFF]
    sub ecx, eax
    sub ecx, eax
    mov edx, dword [rbx + WM_OUTPUT_H_OFF]
    sub edx, eax
    sub edx, eax
    mov dword [r14 + SF_WIDTH_OFF], ecx
    mov dword [r14 + SF_HEIGHT_OFF], edx
    jmp .out

.multi:
    ; master/stack: master = 60%
    mov eax, dword [rbx + WM_OUTPUT_W_OFF]
    imul eax, 3
    xor edx, edx
    mov ecx, 5
    div ecx
    mov r15d, eax                     ; master_w raw
    mov eax, dword [rbx + WM_GAP_OFF]
    mov ecx, dword [rbx + WM_OUTPUT_X_OFF]
    add ecx, eax
    mov edx, dword [rbx + WM_OUTPUT_Y_OFF]
    add edx, eax
    mov dword [r14 + SF_SCREEN_X_OFF], ecx
    mov dword [r14 + SF_SCREEN_Y_OFF], edx
    mov ecx, r15d
    sub ecx, eax
    sub ecx, eax
    mov dword [r14 + SF_WIDTH_OFF], ecx
    mov ecx, dword [rbx + WM_OUTPUT_H_OFF]
    sub ecx, eax
    sub ecx, eax
    mov dword [r14 + SF_HEIGHT_OFF], ecx

    mov r13d, r12d
    dec r13d                          ; stack count
    mov eax, dword [rbx + WM_OUTPUT_H_OFF]
    mov ecx, dword [rbx + WM_GAP_OFF]
    mov r12d, r13d
    dec r12d
    imul ecx, r12d
    sub eax, ecx
    xor edx, edx
    mov ecx, r13d
    div ecx
    mov r12d, eax                     ; each_h raw

    xor r11d, r11d                    ; stack index
.stack_loop:
    cmp r11d, r13d
    jae .out
    mov rax, [rel wm_stack_list + r11*8]
    mov ecx, dword [rbx + WM_OUTPUT_X_OFF]
    add ecx, r15d
    add ecx, dword [rbx + WM_GAP_OFF]
    mov dword [rax + SF_SCREEN_X_OFF], ecx

    mov ecx, r12d
    add ecx, dword [rbx + WM_GAP_OFF]
    imul ecx, r11d
    add ecx, dword [rbx + WM_OUTPUT_Y_OFF]
    add ecx, dword [rbx + WM_GAP_OFF]
    mov dword [rax + SF_SCREEN_Y_OFF], ecx

    mov ecx, dword [rbx + WM_OUTPUT_W_OFF]
    sub ecx, r15d
    sub ecx, dword [rbx + WM_GAP_OFF]
    sub ecx, dword [rbx + WM_GAP_OFF]
    mov dword [rax + SF_WIDTH_OFF], ecx

    mov ecx, r12d
    sub ecx, dword [rbx + WM_GAP_OFF]
    sub ecx, dword [rbx + WM_GAP_OFF]
    mov dword [rax + SF_HEIGHT_OFF], ecx

    inc r11d
    jmp .stack_loop

.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

wm_get_global:
    lea rax, [rel wm_global_state]
    ret

; wm_remove_ptr_from_array(base_ptr, count_ptr, target_ptr)
; rdi = qword array base, rsi = dword count address, rdx = target pointer
wm_remove_ptr_from_array:
    push rbx
    push r12
    mov r12d, dword [rsi]
    xor ebx, ebx
.find:
    cmp ebx, r12d
    jae .out
    mov rax, [rdi + rbx*8]
    cmp rax, rdx
    je .shift
    inc ebx
    jmp .find
.shift:
    dec r12d
.sl:
    cmp ebx, r12d
    jae .save
    mov rax, [rdi + rbx*8 + 8]
    mov [rdi + rbx*8], rax
    inc ebx
    jmp .sl
.save:
    mov dword [rsi], r12d
.out:
    pop r12
    pop rbx
    ret

; wm_init(output_w, output_h, gap) -> rax wm*
wm_init:
    push rdi
    push rsi
    push rdx
    lea rdi, [rel wm_global_state]
    mov ecx, WM_STRUCT_SIZE / 4
    xor eax, eax
    rep stosd
    pop rdx
    pop rsi
    pop rdi

    lea rax, [rel wm_global_state]
    mov dword [rax + WM_MODE_OFF], WM_MODE_TILING
    mov dword [rax + WM_OUTPUT_X_OFF], 0
    mov dword [rax + WM_OUTPUT_Y_OFF], 0
    mov dword [rax + WM_OUTPUT_W_OFF], edi
    mov dword [rax + WM_OUTPUT_H_OFF], esi
    mov dword [rax + WM_GAP_OFF], edx

    mov edi, 0
    mov esi, 0
    mov edx, dword [rax + WM_OUTPUT_W_OFF]
    mov ecx, dword [rax + WM_OUTPUT_H_OFF]
    mov r8d, dword [rax + WM_GAP_OFF]
    call tiling_init
    mov [rel wm_global_state + WM_TILING_ROOT_OFF], rax
    lea rax, [rel wm_global_state]
    ret

; wm_add_surface(wm, surface)
wm_add_surface:
    push rbx
    push r12
    mov rbx, rdi
    mov r12, rsi
    mov eax, dword [rbx + WM_SURFACE_COUNT_OFF]
    cmp eax, WM_MAX_SURFACES
    jae .out
    mov [rbx + WM_SURFACES_OFF + rax*8], r12
    inc dword [rbx + WM_SURFACE_COUNT_OFF]
    mov dword [r12 + SF_MAPPED_OFF], 1
    cmp dword [r12 + SF_WIDTH_OFF], 0
    jg .h_ok
    mov dword [r12 + SF_WIDTH_OFF], 640
.h_ok:
    cmp dword [r12 + SF_HEIGHT_OFF], 0
    jg .focus
    mov dword [r12 + SF_HEIGHT_OFF], 480
.focus:
    mov rdi, rbx
    mov rsi, r12
    call wm_set_focus
    mov rdi, rbx
    call wm_relayout
.out:
    pop r12
    pop rbx
    ret

; wm_remove_surface(wm, surface)
wm_remove_surface:
    push rbx
    push r12
    mov rbx, rdi
    mov r12, rsi
    lea rdi, [rbx + WM_SURFACES_OFF]
    lea rsi, [rbx + WM_SURFACE_COUNT_OFF]
    mov rdx, r12
    call wm_remove_ptr_from_array

    lea rdi, [rbx + WM_FOCUS_STACK_OFF]
    lea rsi, [rbx + WM_FOCUS_COUNT_OFF]
    mov rdx, r12
    call wm_remove_ptr_from_array

    mov dword [r12 + SF_MAPPED_OFF], 0
    mov rdi, rbx
    call wm_relayout
    pop r12
    pop rbx
    ret

; wm_set_focus(wm, surface)
wm_set_focus:
    push rbx
    push r12
    mov rbx, rdi
    mov r12, rsi
    test r12, r12
    jz .out
    lea rdi, [rbx + WM_FOCUS_STACK_OFF]
    lea rsi, [rbx + WM_FOCUS_COUNT_OFF]
    mov rdx, r12
    call wm_remove_ptr_from_array

    mov eax, dword [rbx + WM_FOCUS_COUNT_OFF]
    cmp eax, WM_MAX_SURFACES
    jae .out
    mov [rbx + WM_FOCUS_STACK_OFF + rax*8], r12
    inc dword [rbx + WM_FOCUS_COUNT_OFF]
    mov dword [r12 + SF_Z_ORDER_OFF], 0x7FFFFFFF
.out:
    pop r12
    pop rbx
    ret

; wm_get_focused(wm) -> rax surface* or 0
wm_get_focused:
    mov eax, dword [rdi + WM_FOCUS_COUNT_OFF]
    test eax, eax
    jz .none
    dec eax
    mov rax, [rdi + WM_FOCUS_STACK_OFF + rax*8]
    ret
.none:
    xor eax, eax
    ret

wm_toggle_mode:
    mov eax, dword [rdi + WM_MODE_OFF]
    xor eax, 1
    mov dword [rdi + WM_MODE_OFF], eax
    jmp wm_relayout

; wm_set_surface_mode(wm, surface, mode)
wm_set_surface_mode:
    cmp edx, WM_MODE_FLOATING
    jne .to_tiling
    mov dword [rsi + SF_FLOATING_OFF], 1
    push rdi
    call floating_add
    pop rdi
    jmp wm_relayout
.to_tiling:
    mov dword [rsi + SF_FLOATING_OFF], 0
    jmp wm_relayout

; wm_relayout(wm)
wm_relayout:
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov edi, dword [rbx + WM_OUTPUT_X_OFF]
    mov esi, dword [rbx + WM_OUTPUT_Y_OFF]
    mov edx, dword [rbx + WM_OUTPUT_W_OFF]
    mov ecx, dword [rbx + WM_OUTPUT_H_OFF]
    mov r8d, dword [rbx + WM_GAP_OFF]
    call tiling_init
    mov [rbx + WM_TILING_ROOT_OFF], rax

    xor r12d, r12d
.loop:
    cmp r12d, dword [rbx + WM_SURFACE_COUNT_OFF]
    jae .finish
    mov r13, [rbx + WM_SURFACES_OFF + r12*8]
    test r13, r13
    jz .next
    cmp dword [r13 + SF_MAPPED_OFF], 0
    je .next

    cmp dword [r13 + SF_FLOATING_OFF], 0
    jne .float
    cmp dword [rbx + WM_MODE_OFF], WM_MODE_FLOATING
    je .float
    mov rdi, [rbx + WM_TILING_ROOT_OFF]
    mov rsi, r13
    call tiling_add
    jmp .next
.float:
    mov rdi, rbx
    mov rsi, r13
    call floating_add
.next:
    inc r12d
    jmp .loop
.finish:
    mov rdi, [rbx + WM_TILING_ROOT_OFF]
    call tiling_layout
    mov rdi, rbx
    call wm_apply_simple_tiling
    pop r13
    pop r12
    pop rbx
    ret

wm_is_key_down:
    ; wm_is_key_down(server, keycode) -> al
    mov eax, esi
    shr eax, 3
    and esi, 7
    mov dl, [rdi + CS_KEY_STATE_OFF + rax]
    mov al, 1
    mov cl, sil
    shl al, cl
    test dl, al
    setnz al
    ret

; wm_handle_hotkey(server, keycode) -> al handled
wm_handle_hotkey:
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdi
    mov r12d, esi
    lea r13, [rel wm_global_state]
    xor r14d, r14d

    cmp r12d, KEY_ENTER
    je .handled
    cmp r12d, KEY_1
    jb .not_num
    cmp r12d, KEY_0
    jbe .handled
.not_num:
    mov rdi, r13
    call wm_get_focused
    mov r14, rax

    cmp r12d, KEY_Q
    jne .k_space
    test r14, r14
    jz .handled
    mov rdi, r13
    mov rsi, r14
    call wm_remove_surface
    jmp .handled

.k_space:
    cmp r12d, KEY_SPACE
    jne .k_f
    test r14, r14
    jz .handled
    mov edx, dword [r14 + SF_FLOATING_OFF]
    xor edx, 1
    mov rdi, r13
    mov rsi, r14
    call wm_set_surface_mode
    jmp .handled

.k_f:
    cmp r12d, KEY_F
    jne .k_e
    test r14, r14
    jz .handled
    mov eax, dword [r14 + SF_WIDTH_OFF]
    cmp eax, dword [r13 + WM_OUTPUT_W_OFF]
    jne .to_full
    mov dword [r14 + SF_WIDTH_OFF], 640
    mov dword [r14 + SF_HEIGHT_OFF], 480
    mov dword [r14 + SF_FLOATING_OFF], 1
    mov rdi, r13
    mov rsi, r14
    call floating_add
    jmp .handled
.to_full:
    mov eax, dword [r13 + WM_OUTPUT_X_OFF]
    mov dword [r14 + SF_SCREEN_X_OFF], eax
    mov eax, dword [r13 + WM_OUTPUT_Y_OFF]
    mov dword [r14 + SF_SCREEN_Y_OFF], eax
    mov eax, dword [r13 + WM_OUTPUT_W_OFF]
    mov dword [r14 + SF_WIDTH_OFF], eax
    mov eax, dword [r13 + WM_OUTPUT_H_OFF]
    mov dword [r14 + SF_HEIGHT_OFF], eax
    mov dword [r14 + SF_FLOATING_OFF], 1
    jmp .handled

.k_e:
    cmp r12d, KEY_E
    jne .k_hv
    mov dword [rel wm_fm_toggle_request], 1
    jmp .handled

.k_hv:
    cmp r12d, KEY_H
    jne .k_v
    mov rdi, rbx
    mov esi, KEY_LEFTSHIFT
    call wm_is_key_down
    test al, al
    jnz .resize_left
    mov dword [r13 + WM_MODE_OFF], WM_MODE_TILING
    mov edi, TILING_SPLIT_H
    call tiling_set_split_mode
    jmp .handled
.resize_left:
    test r14, r14
    jz .handled
    mov rdi, [r13 + WM_TILING_ROOT_OFF]
    mov rsi, r14
    mov edx, -24
    xor ecx, ecx
    call tiling_resize
    jmp .handled

.k_v:
    cmp r12d, KEY_V
    jne .k_l
    mov dword [r13 + WM_MODE_OFF], WM_MODE_TILING
    mov edi, TILING_SPLIT_V
    call tiling_set_split_mode
    jmp .handled

.k_l:
    cmp r12d, KEY_L
    jne .arrows
    mov rdi, rbx
    mov esi, KEY_LEFTSHIFT
    call wm_is_key_down
    test al, al
    jz .not
    test r14, r14
    jz .handled
    mov rdi, [r13 + WM_TILING_ROOT_OFF]
    mov rsi, r14
    mov edx, 24
    xor ecx, ecx
    call tiling_resize
    jmp .handled

.arrows:
    cmp r12d, KEY_LEFT
    je .dir_left
    cmp r12d, KEY_RIGHT
    je .dir_right
    cmp r12d, KEY_UP
    je .dir_up
    cmp r12d, KEY_DOWN
    je .dir_down
    jmp .not
.dir_left:
    mov r8d, WM_DIR_LEFT
    jmp .nav
.dir_right:
    mov r8d, WM_DIR_RIGHT
    jmp .nav
.dir_up:
    mov r8d, WM_DIR_UP
    jmp .nav
.dir_down:
    mov r8d, WM_DIR_DOWN

.nav:
    test r14, r14
    jz .handled
    mov rdi, [r13 + WM_TILING_ROOT_OFF]
    mov rsi, r14
    mov edx, r8d
    call tiling_find_neighbor
    test rax, rax
    jz .handled
    mov r9, rax
    mov rdi, rbx
    mov esi, KEY_LEFTSHIFT
    call wm_is_key_down
    test al, al
    jnz .swap
    mov rdi, r13
    mov rsi, r9
    call wm_set_focus
    jmp .handled
.swap:
    mov rdi, [r13 + WM_TILING_ROOT_OFF]
    mov rsi, r14
    mov rdx, r9
    call tiling_swap
    mov rdi, r13
    call wm_relayout
    jmp .handled

.not:
    xor eax, eax
    jmp .out
.handled:
    mov eax, 1
.out:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
