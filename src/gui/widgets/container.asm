; container.asm — generic grouping widget (no chrome)
%include "src/hal/linux_x86_64/defs.inc"
%include "src/gui/widget.inc"

section .text
global w_container_render
global w_container_measure
global w_container_handle_input
global w_container_layout
global w_container_destroy

w_container_render:
    ret

w_container_measure:
    mov eax, [rdi + W_WIDTH_OFF]
    mov [rdi + W_PREF_W_OFF], eax
    mov eax, [rdi + W_HEIGHT_OFF]
    mov [rdi + W_PREF_H_OFF], eax
    mov eax, [rdi + W_MIN_W_OFF]
    cmp eax, TOUCH_TARGET_MIN
    jge .mw
    mov dword [rdi + W_MIN_W_OFF], TOUCH_TARGET_MIN
.mw:
    mov eax, [rdi + W_MIN_H_OFF]
    cmp eax, TOUCH_TARGET_MIN
    jge .mh
    mov dword [rdi + W_MIN_H_OFF], TOUCH_TARGET_MIN
.mh:
    ret

w_container_handle_input:
    xor eax, eax
    ret

w_container_layout:
    ret

w_container_destroy:
    ret
