; host_win_stub.asm — PE build: no ELF .so loading (stubs satisfy linker / builtins)
section .text
global plugin_load
global plugin_get_symbol
global plugin_activate
global plugin_unload

; plugin_load(path rdi) -> rax 0 (failure)
plugin_load:
    xor eax, eax
    ret

; plugin_get_symbol(handle, name, name_len) -> rax 0
plugin_get_symbol:
    xor eax, eax
    ret

; plugin_activate(handle, host_api) -> eax 0
plugin_activate:
    xor eax, eax
    ret

; plugin_unload(handle) -> eax 0
plugin_unload:
    xor eax, eax
    ret
