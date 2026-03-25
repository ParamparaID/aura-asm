global aura_plugin_init

section .text
aura_plugin_init:
    ; deliberate crash for isolation test
    mov qword [0], 1
    xor eax, eax
    ret
