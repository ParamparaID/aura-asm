; test_plugin_host.asm — STEP 50 plugin host smoke tests
%include "src/hal/linux_x86_64/defs.inc"

extern hal_write
extern hal_exit
extern plugin_load
extern plugin_get_symbol
extern plugin_unload
extern plugin_activate
extern manifest_parse

%define PH_STATE_OFF                108
%define PLUGIN_UNLOADED             0
%define MF_NAME_OFF                 0
%define MF_VERSION_OFF              64
%define MF_AUTHOR_OFF               68
%define MF_DESC_OFF                 132
%define MF_HOOKS_OFF                260
%define MF_DEPS_OFF                 324
%define MANIFEST_STRUCT_SIZE        452

section .data
    plugin_path         db "build/test_plugin.so",0
    plugin_bad_path     db "build/test_plugin_bad.so",0
    plugin_crash_path   db "build/test_plugin_crash.so",0
    bad_plugin_path     db "nonexistent.so",0
    sym_test_add        db "test_add",0
    sym_init            db "aura_plugin_init",0
    ini_name_key        db "hello-world",0
    deps_value          db "core,net",0
    hook_value          db "hello_cmd",0

    manifest_ini:
        db "[plugin]",10
        db "name = hello-world",10
        db "version = 1",10
        db "author = Dev",10
        db "description = Example plugin",10
        db "[hooks]",10
        db "commands = hello_cmd",10
        db "dependencies = core,net",10
    manifest_ini_len    equ $ - manifest_ini

    manifest_toml:
        db "[plugin]",10
        db 'name = "', "hello-world", '"',10
        db "version = 2",10
        db 'author = "', "Dev", '"',10
        db 'description = "', "Toml plugin", '"',10
        db 'hooks.commands = "', "hello_cmd", '"',10
        db 'deps = "', "core,net", '"',10
    manifest_toml_len   equ $ - manifest_toml

    pass_msg            db "ALL TESTS PASSED",10
    pass_len            equ $ - pass_msg
    fail_load_msg       db "FAIL: plugin_load",10
    fail_load_len       equ $ - fail_load_msg
    fail_sym_msg        db "FAIL: plugin_get_symbol",10
    fail_sym_len        equ $ - fail_sym_msg
    fail_call_msg       db "FAIL: test_add call",10
    fail_call_len       equ $ - fail_call_msg
    fail_init_msg       db "FAIL: plugin init",10
    fail_init_len       equ $ - fail_init_msg
    fail_unload_msg     db "FAIL: plugin_unload state",10
    fail_unload_len     equ $ - fail_unload_msg
    fail_bad_msg        db "FAIL: bad plugin should fail",10
    fail_bad_len        equ $ - fail_bad_msg
    fail_manifest_ini_msg   db "FAIL: manifest parse ini",10
    fail_manifest_ini_len   equ $ - fail_manifest_ini_msg
    fail_manifest_name_msg  db "FAIL: manifest ini name",10
    fail_manifest_name_len  equ $ - fail_manifest_name_msg
    fail_manifest_hooks_msg db "FAIL: manifest ini hooks",10
    fail_manifest_hooks_len equ $ - fail_manifest_hooks_msg
    fail_manifest_deps_msg  db "FAIL: manifest ini deps",10
    fail_manifest_deps_len  equ $ - fail_manifest_deps_msg
    fail_manifest_toml_msg  db "FAIL: manifest parse toml",10
    fail_manifest_toml_len  equ $ - fail_manifest_toml_msg
    fail_sandbox_msg    db "FAIL: sandbox validate exports",10
    fail_sandbox_len    equ $ - fail_sandbox_msg
    fail_isolation_msg  db "FAIL: crash isolation",10
    fail_isolation_len  equ $ - fail_isolation_msg

section .bss
    handle_ptr          resq 1
    bad_handle_ptr      resq 1
    manifest_buf        resb MANIFEST_STRUCT_SIZE

section .text
global _start

%macro write_stdout 2
    mov rdi, STDOUT
    lea rsi, [rel %1]
    mov rdx, %2
    call hal_write
%endmacro

%macro fail 2
    write_stdout %1, %2
    mov rdi, 1
    call hal_exit
%endmacro

_start:
    ; manifest parse: ini
    lea rdi, [rel manifest_ini]
    mov esi, manifest_ini_len
    lea rdx, [rel manifest_buf]
    call manifest_parse
    test eax, eax
    jne .f_manifest_ini
    lea rsi, [rel ini_name_key]
    lea rdi, [rel manifest_buf + MF_NAME_OFF]
    mov ecx, 11
    cld
    repe cmpsb
    jne .f_manifest_name
    lea rsi, [rel hook_value]
    lea rdi, [rel manifest_buf + MF_HOOKS_OFF]
    mov ecx, 9
    cld
    repe cmpsb
    jne .f_manifest_hooks
    lea rsi, [rel deps_value]
    lea rdi, [rel manifest_buf + MF_DEPS_OFF]
    mov ecx, 8
    cld
    repe cmpsb
    jne .f_manifest_deps

    ; manifest parse: toml-like
    lea rdi, [rel manifest_toml]
    mov esi, manifest_toml_len
    lea rdx, [rel manifest_buf]
    call manifest_parse
    test eax, eax
    jne .f_manifest_toml
    cmp dword [rel manifest_buf + MF_VERSION_OFF], 2
    jne .f_manifest_toml

    ; test 1: load
    lea rdi, [rel plugin_path]
    call plugin_load
    test rax, rax
    jz .f_load
    mov [rel handle_ptr], rax

    ; test 2: resolve test_add
    mov rdi, [rel handle_ptr]
    lea rsi, [rel sym_test_add]
    mov edx, 8
    call plugin_get_symbol
    test rax, rax
    jz .f_sym
    mov rdi, 3
    mov rsi, 4
    call rax
    cmp eax, 7
    jne .f_call

    ; test 3: init symbol + activate
    mov rdi, [rel handle_ptr]
    lea rsi, [rel sym_init]
    mov edx, 16
    call plugin_get_symbol
    test rax, rax
    jz .f_init
    xor rdi, rdi
    call rax
    test eax, eax
    jne .f_init
    mov rdi, [rel handle_ptr]
    xor rsi, rsi
    call plugin_activate
    test eax, eax
    jne .f_init

    ; test 4: sandbox check on plugin without aura_plugin_init
    lea rdi, [rel plugin_bad_path]
    call plugin_load
    test rax, rax
    jz .f_sandbox
    mov [rel bad_handle_ptr], rax
    mov rdi, rax
    xor rsi, rsi
    call plugin_activate
    cmp eax, -1
    jne .f_sandbox
    mov rdi, [rel bad_handle_ptr]
    call plugin_unload

    ; test 5: crash isolation (init crashes in child)
    lea rdi, [rel plugin_crash_path]
    call plugin_load
    test rax, rax
    jz .f_isolation
    mov [rel bad_handle_ptr], rax
    mov rdi, rax
    xor rsi, rsi
    call plugin_activate
    cmp eax, -1
    jne .f_isolation
    mov rdi, [rel bad_handle_ptr]
    call plugin_unload

    ; test 6: unload and state
    mov rdi, [rel handle_ptr]
    call plugin_unload
    test eax, eax
    jne .f_unload
    mov rax, [rel handle_ptr]
    cmp dword [rax + PH_STATE_OFF], PLUGIN_UNLOADED
    jne .f_unload

    ; test 7: bad .so
    lea rdi, [rel bad_plugin_path]
    call plugin_load
    test rax, rax
    jnz .f_bad

    write_stdout pass_msg, pass_len
    xor rdi, rdi
    call hal_exit

.f_load:
    fail fail_load_msg, fail_load_len
.f_sym:
    fail fail_sym_msg, fail_sym_len
.f_call:
    fail fail_call_msg, fail_call_len
.f_init:
    fail fail_init_msg, fail_init_len
.f_unload:
    fail fail_unload_msg, fail_unload_len
.f_bad:
    fail fail_bad_msg, fail_bad_len
.f_manifest_ini:
    fail fail_manifest_ini_msg, fail_manifest_ini_len
.f_manifest_name:
    fail fail_manifest_name_msg, fail_manifest_name_len
.f_manifest_hooks:
    fail fail_manifest_hooks_msg, fail_manifest_hooks_len
.f_manifest_deps:
    fail fail_manifest_deps_msg, fail_manifest_deps_len
.f_manifest_toml:
    fail fail_manifest_toml_msg, fail_manifest_toml_len
.f_sandbox:
    fail fail_sandbox_msg, fail_sandbox_len
.f_isolation:
    fail fail_isolation_msg, fail_isolation_len
