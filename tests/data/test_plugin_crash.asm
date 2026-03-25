global aura_plugin_init
global aura_plugin_shutdown
global aura_plugin_get_info

section .text
aura_plugin_init:
    ; deliberate crash for isolation test
    mov qword [0], 1
    xor eax, eax
    ret

aura_plugin_shutdown:
    ret

aura_plugin_get_info:
    ret
