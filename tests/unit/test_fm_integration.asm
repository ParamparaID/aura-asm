; test_fm_integration.asm — STEP 44 integration smoke
%include "src/hal/platform_defs.inc"
%include "src/gui/widget.inc"
%include "src/fm/panel.inc"

extern hal_write
extern hal_exit
extern hal_mkdir
extern canvas_init
extern canvas_destroy
extern canvas_clear
extern canvas_get_pixel
extern widget_system_init
extern widget_system_shutdown
extern fm_init
extern fm_render
extern fm_handle_input
extern fm_open_path
extern op_delete

section .data
    root_path        db "/tmp/aura_test_fm_int", 0
    pass_msg         db "ALL TESTS PASSED", 10
    pass_len         equ $ - pass_msg
    fail_msg         db "FAIL: fm integration", 10
    fail_len         equ $ - fail_msg

section .bss
    fm_ptr           resq 1
    canvas_ptr       resq 1
    theme_mem        resb THEME_STRUCT_SIZE
    event_mem        resb 64

section .text
global _start

fail:
    mov rdi, STDOUT
    lea rsi, [rel fail_msg]
    mov rdx, fail_len
    call hal_write
    mov rdi, 1
    call hal_exit

cleanup:
    lea rdi, [rel root_path]
    mov esi, 1
    call op_delete
    ret

_start:
    call cleanup
    lea rdi, [rel root_path]
    mov esi, 0o755
    call hal_mkdir

    call widget_system_init
    test eax, eax
    jnz fail

    mov rdi, 800
    mov rsi, 600
    call canvas_init
    test rax, rax
    jz fail
    mov [rel canvas_ptr], rax
    mov rdi, rax
    mov esi, 0xFF000000
    call canvas_clear

    lea rdi, [rel root_path]
    mov esi, 1
    call fm_init
    test rax, rax
    jz fail
    mov [rel fm_ptr], rax

    ; direct integration API
    mov rdi, rax
    lea rsi, [rel root_path]
    mov edx, 21
    call fm_open_path
    test eax, eax
    js fail

    ; render smoke
    mov rdi, [rel fm_ptr]
    mov rsi, [rel canvas_ptr]
    lea rdx, [rel theme_mem]
    call fm_render
    mov rdi, [rel canvas_ptr]
    mov esi, 10
    mov edx, 10
    call canvas_get_pixel
    cmp eax, 0xFF000000
    je fail

    mov rdi, [rel canvas_ptr]
    call canvas_destroy
    call widget_system_shutdown
    call cleanup
    mov rdi, STDOUT
    lea rsi, [rel pass_msg]
    mov rdx, pass_len
    call hal_write
    xor edi, edi
    call hal_exit
