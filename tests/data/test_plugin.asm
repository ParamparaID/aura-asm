global aura_plugin_init
global aura_plugin_shutdown
global test_add

section .text
aura_plugin_init:
    ; rdi = host_api_table (unused in MVP)
    xor eax, eax
    ret

aura_plugin_shutdown:
    ret

test_add:
    ; rdi = a, rsi = b
    lea eax, [rdi + rsi]
    ret
