; keymap.asm - minimal Win32 key -> ASCII mapper for REPL
%include "src/hal/win_x86_64/defs.inc"

section .text
global wayland_keycode_to_ascii

; wayland_keycode_to_ascii(keycode, modifiers) -> al
; This keeps the legacy symbol name used by repl.asm while mapping Win32 keys.
wayland_keycode_to_ascii:
    ; rdi = keycode, rsi = modifiers
    mov eax, edi
    cmp eax, VK_RETURN
    jne .check_bs
    mov eax, 10
    ret
.check_bs:
    cmp eax, 8
    jne .check_space
    mov eax, 8
    ret
.check_space:
    cmp eax, 0x20
    jne .check_digit
    mov eax, ' '
    ret
.check_digit:
    cmp eax, 0x30
    jb .check_letter
    cmp eax, 0x39
    ja .check_letter
    ret
.check_letter:
    cmp eax, 0x41
    jb .none
    cmp eax, 0x5A
    ja .none
    ; uppercase VK_A..VK_Z -> lowercase ascii
    or eax, 0x20
    ret
.none:
    xor eax, eax
    ret
