; test_plugin_api.asm — STEP 51 plugin api tests
%include "src/hal/linux_x86_64/defs.inc"

extern hal_write
extern hal_exit
extern arena_init
extern arena_destroy
extern builtins_init
extern builtin_dispatch
extern plugin_registry_count

%define ARENA_SIZE             262144
%define CMD_ARGC_OFF           4
%define CMD_ARGV_OFF           8
%define CMD_ARGV_LEN_OFF       136

section .data
    cmd_plugin          db "plugin",0
    sub_load            db "load",0
    sub_unload          db "unload",0
    plugin_cmd_path     db "build/test_plugin_cmd.so",0
    plugin_plain_path   db "build/test_plugin.so",0
    plugin_cmd_name     db "test_plugin_cmd.so",0
    cmd_greet           db "greet",0

    pass_msg            db "ALL TESTS PASSED",10
    pass_len            equ $ - pass_msg
    fail_load_msg       db "FAIL: plugin load/register",10
    fail_load_len       equ $ - fail_load_msg
    fail_load_ret_msg   db "FAIL: plugin load ret",10
    fail_load_ret_len   equ $ - fail_load_ret_msg
    fail_load_count_msg db "FAIL: plugin load count",10
    fail_load_count_len equ $ - fail_load_count_msg
    fail_load2_ret_msg  db "FAIL: plugin second load ret",10
    fail_load2_ret_len  equ $ - fail_load2_ret_msg
    fail_load2_count_msg db "FAIL: plugin second load count",10
    fail_load2_count_len equ $ - fail_load2_count_msg
    fail_greet_msg      db "FAIL: plugin command dispatch",10
    fail_greet_len      equ $ - fail_greet_msg
    fail_list_msg       db "FAIL: plugin list count",10
    fail_list_len       equ $ - fail_list_msg
    fail_unload_msg     db "FAIL: plugin unload count",10
    fail_unload_len     equ $ - fail_unload_msg
    fail_init_msg       db "FAIL: builtins init",10
    fail_init_len       equ $ - fail_init_msg

section .bss
    arena_ptr           resq 1
    cmd_node            resb 256

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
    mov rdi, ARENA_SIZE
    call arena_init
    test rax, rax
    jz .f_init
    mov [rel arena_ptr], rax
    mov rdi, rax
    call builtins_init
    cmp eax, 0
    jne .f_init

    ; test 1: plugin load test_plugin_cmd.so
    mov dword [rel cmd_node + CMD_ARGC_OFF], 3
    lea rax, [rel cmd_plugin]
    mov [rel cmd_node + CMD_ARGV_OFF + 0], rax
    lea rax, [rel sub_load]
    mov [rel cmd_node + CMD_ARGV_OFF + 8], rax
    lea rax, [rel plugin_cmd_path]
    mov [rel cmd_node + CMD_ARGV_OFF + 16], rax
    mov dword [rel cmd_node + CMD_ARGV_LEN_OFF + 0], 6
    mov dword [rel cmd_node + CMD_ARGV_LEN_OFF + 4], 4
    mov dword [rel cmd_node + CMD_ARGV_LEN_OFF + 8], 24
    lea rdi, [rel cmd_plugin]
    mov esi, 6
    lea rdx, [rel cmd_node]
    xor rcx, rcx
    call builtin_dispatch
    cmp eax, 0
    jne .f_load_ret
    call plugin_registry_count
    cmp eax, 1
    jne .f_load_count

    ; load second plugin
    lea rax, [rel plugin_plain_path]
    mov [rel cmd_node + CMD_ARGV_OFF + 16], rax
    mov dword [rel cmd_node + CMD_ARGV_LEN_OFF + 8], 20
    lea rdi, [rel cmd_plugin]
    mov esi, 6
    lea rdx, [rel cmd_node]
    xor rcx, rcx
    call builtin_dispatch
    cmp eax, 0
    jne .f_load2_ret
    call plugin_registry_count
    cmp eax, 2
    jne .f_load2_count

    ; test 2: registered command execution
    mov dword [rel cmd_node + CMD_ARGC_OFF], 1
    lea rax, [rel cmd_greet]
    mov [rel cmd_node + CMD_ARGV_OFF + 0], rax
    mov dword [rel cmd_node + CMD_ARGV_LEN_OFF + 0], 5
    lea rdi, [rel cmd_greet]
    mov esi, 5
    lea rdx, [rel cmd_node]
    xor rcx, rcx
    call builtin_dispatch
    cmp eax, 0
    jne .f_greet

    ; test 3: unload one plugin by name
    mov dword [rel cmd_node + CMD_ARGC_OFF], 3
    lea rax, [rel cmd_plugin]
    mov [rel cmd_node + CMD_ARGV_OFF + 0], rax
    lea rax, [rel sub_unload]
    mov [rel cmd_node + CMD_ARGV_OFF + 8], rax
    lea rax, [rel plugin_cmd_name]
    mov [rel cmd_node + CMD_ARGV_OFF + 16], rax
    mov dword [rel cmd_node + CMD_ARGV_LEN_OFF + 0], 6
    mov dword [rel cmd_node + CMD_ARGV_LEN_OFF + 4], 6
    mov dword [rel cmd_node + CMD_ARGV_LEN_OFF + 8], 18
    lea rdi, [rel cmd_plugin]
    mov esi, 6
    lea rdx, [rel cmd_node]
    xor rcx, rcx
    call builtin_dispatch
    cmp eax, 0
    jne .f_unload
    call plugin_registry_count
    cmp eax, 1
    jne .f_unload

    mov rdi, [rel arena_ptr]
    call arena_destroy
    write_stdout pass_msg, pass_len
    xor rdi, rdi
    call hal_exit

.f_init:
    fail fail_init_msg, fail_init_len
.f_load:
    fail fail_load_msg, fail_load_len
.f_load_ret:
    fail fail_load_ret_msg, fail_load_ret_len
.f_load_count:
    fail fail_load_count_msg, fail_load_count_len
.f_load2_ret:
    fail fail_load2_ret_msg, fail_load2_ret_len
.f_load2_count:
    fail fail_load2_count_msg, fail_load2_count_len
.f_greet:
    fail fail_greet_msg, fail_greet_len
.f_list:
    fail fail_list_msg, fail_list_len
.f_unload:
    fail fail_unload_msg, fail_unload_len
