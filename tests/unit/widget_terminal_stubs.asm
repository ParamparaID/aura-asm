; Stubs for terminal widget vtable — linked into unit tests that pull in
; gui_widget.o but not the full REPL / terminal implementation.
%include "src/gui/widget.inc"

section .text
global w_terminal_render
global w_terminal_measure
global w_terminal_layout
global w_terminal_destroy
global w_terminal_handle_input

w_terminal_render:
    ret

w_terminal_measure:
    mov dword [rdi + W_PREF_W_OFF], 400
    mov dword [rdi + W_PREF_H_OFF], 240
    mov dword [rdi + W_MIN_W_OFF], 120
    mov dword [rdi + W_MIN_H_OFF], 80
    ret

w_terminal_layout:
    ret

w_terminal_destroy:
    ret

w_terminal_handle_input:
    xor eax, eax
    ret
