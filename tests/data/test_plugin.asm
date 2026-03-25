global aura_plugin_init
global aura_plugin_shutdown
global aura_plugin_get_info
global test_add

section .text
aura_plugin_init:
    ; rdi = host_api_table (unused in MVP)
    xor eax, eax
    ret

aura_plugin_shutdown:
    ret

aura_plugin_get_info:
    test rdi, rdi
    jz .out
    mov qword [rdi + 0], 0
    mov dword [rdi + 8], 1
    mov qword [rdi + 16], 0
    mov qword [rdi + 24], 0
.out:
    ret

test_add:
    ; rdi = a, rsi = b
    lea eax, [rdi + rsi]
    ret
