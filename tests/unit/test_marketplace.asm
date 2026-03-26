; test_marketplace.asm
%include "src/hal/linux_x86_64/defs.inc"

extern hal_write
extern hal_exit
extern apkg_init
extern apkg_list_count
extern apkg_install_local
extern apkg_remove
extern apkg_is_installed

section .data
    pass_msg db "ALL TESTS PASSED",10
    pass_len equ $ - pass_msg
    fail_msg db "TEST FAILED: marketplace",10
    fail_len equ $ - fail_msg
    pkg_name db "test-pkg",0
    fake_pkg db "/tmp/fake_pkg.tar.gz",0

section .text
global _start

fail:
    mov rdi, STDOUT
    lea rsi, [rel fail_msg]
    mov rdx, fail_len
    call hal_write
    mov rdi, 1
    call hal_exit

_start:
    ; test1 empty list
    call apkg_init
    call apkg_list_count
    cmp eax, 0
    jne fail

    ; test2 install local
    lea rdi, [rel fake_pkg]
    lea rsi, [rel pkg_name]
    call apkg_install_local
    cmp eax, 0
    jne fail
    lea rdi, [rel pkg_name]
    call apkg_is_installed
    cmp eax, 1
    jne fail

    ; test3 remove
    lea rdi, [rel pkg_name]
    call apkg_remove
    cmp eax, 0
    jne fail
    lea rdi, [rel pkg_name]
    call apkg_is_installed
    cmp eax, 0
    jne fail

    ; pass
    mov rdi, STDOUT
    lea rsi, [rel pass_msg]
    mov rdx, pass_len
    call hal_write
    xor rdi, rdi
    call hal_exit
