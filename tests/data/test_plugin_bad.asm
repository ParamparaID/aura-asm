global aura_plugin_shutdown
global aura_plugin_get_info
global test_add

section .text
aura_plugin_shutdown:
    ret

aura_plugin_get_info:
    ret

test_add:
    lea eax, [rdi + rsi]
    ret
