; test_aurascript_parser.asm
%include "src/hal/platform_defs.inc"

extern hal_write
extern hal_exit
extern arena_init
extern arena_reset
extern arena_destroy
extern as_lexer_init
extern as_lexer_tokenize
extern as_parser_init
extern as_parser_parse
extern as_parser_get_error

%define ARENA_SIZE           524288

%define AST_PROGRAM          1
%define AST_FN_DECL          2
%define AST_LET_STMT         3
%define AST_IF_STMT          4
%define AST_FOR_STMT         5
%define AST_RETURN_STMT      7
%define AST_BLOCK            8
%define AST_BINARY_EXPR      9
%define AST_ARRAY_LIT        20
%define AST_MAP_LIT          21
%define AST_SHELL_CAPTURE    22

%define ND_TYPE_OFF          0
%define ND_D0_OFF            8
%define ND_D1_OFF            16
%define ND_D3_OFF            32
%define ND_D4_OFF            40

section .data
    pass_msg db "ALL TESTS PASSED",10
    pass_len equ $ - pass_msg
    fail_msg db "TEST FAILED: aurascript parser",10
    fail_len equ $ - fail_msg

    src_fn db "fn add(a: int, b: int) -> int { return a + b }"
    src_fn_len equ $ - src_fn

    src_let_if db "let x = 42; if x > 10 { } else { }"
    src_let_if_len equ $ - src_let_if

    src_for db "for i in 0..10 { i }"
    src_for_len equ $ - src_for

    src_arr_map db "let a = [1, 2, 3]",10,"let m = {",34,"key",34,": ",34,"val",34,"}"
    src_arr_map_len equ $ - src_arr_map

    src_shell db "let out = $(ls)"
    src_shell_len equ $ - src_shell

    src_bad db "fn ( { broken"
    src_bad_len equ $ - src_bad

section .bss
    arena_ptr  resq 1
    parser_ptr resq 1

section .text
global _start

fail:
    mov rdi, STDOUT
    lea rsi, [rel fail_msg]
    mov rdx, fail_len
    call hal_write
    mov rdi, 1
    call hal_exit

parse_source:
    ; (src rdi, len rsi) -> ast rax / 0
    push rbx
    push r12
    mov rbx, rdi
    mov r12, rsi

    mov rdi, [rel arena_ptr]
    call arena_reset

    mov rdi, [rel arena_ptr]
    mov rsi, rbx
    mov rdx, r12
    call as_lexer_init
    test rax, rax
    jz .f
    mov rbx, rax

    mov rdi, rbx
    call as_lexer_tokenize
    cmp eax, 0
    jne .f

    mov rdi, [rel arena_ptr]
    mov rsi, rbx
    call as_parser_init
    test rax, rax
    jz .f
    mov [rel parser_ptr], rax

    mov rdi, rax
    call as_parser_parse
    pop r12
    pop rbx
    ret

.f:
    xor eax, eax
    pop r12
    pop rbx
    ret

; rax = AST_PROGRAM*
check_program_min1:
    cmp dword [rax + ND_TYPE_OFF], AST_PROGRAM
    jne fail
    cmp qword [rax + ND_D1_OFF], 1
    jb fail
    ret

_start:
    mov rdi, ARENA_SIZE
    call arena_init
    test rax, rax
    jz fail
    mov [rel arena_ptr], rax

    ; case1: simple function
    lea rdi, [rel src_fn]
    mov rsi, src_fn_len
    call parse_source
    test rax, rax
    jz fail
    call check_program_min1
    mov rbx, [rax + ND_D0_OFF]
    mov rbx, [rbx]
    cmp dword [rbx + ND_TYPE_OFF], AST_FN_DECL
    jne fail

    ; case2: let + if/else
    lea rdi, [rel src_let_if]
    mov rsi, src_let_if_len
    call parse_source
    test rax, rax
    jz fail
    cmp dword [rax + ND_TYPE_OFF], AST_PROGRAM
    jne fail
    cmp qword [rax + ND_D1_OFF], 1
    jb fail

    ; case3: for loop
    lea rdi, [rel src_for]
    mov rsi, src_for_len
    call parse_source
    test rax, rax
    jz fail
    cmp dword [rax + ND_TYPE_OFF], AST_PROGRAM
    jne fail

    ; case4: array + map
    lea rdi, [rel src_arr_map]
    mov rsi, src_arr_map_len
    call parse_source
    test rax, rax
    jz fail
    cmp dword [rax + ND_TYPE_OFF], AST_PROGRAM
    jne fail

    ; case5: shell capture
    lea rdi, [rel src_shell]
    mov rsi, src_shell_len
    call parse_source
    test rax, rax
    jz fail
    call check_program_min1
    mov rbx, [rax + ND_D0_OFF]
    mov rcx, [rbx]
    cmp dword [rcx + ND_TYPE_OFF], AST_LET_STMT
    jne fail
    mov rcx, [rcx + ND_D3_OFF]
    cmp dword [rcx + ND_TYPE_OFF], AST_SHELL_CAPTURE
    jne fail

    ; case6: error
    lea rdi, [rel src_bad]
    mov rsi, src_bad_len
    call parse_source
    mov rdi, [rel parser_ptr]
    call as_parser_get_error
    test rax, rax
    jz fail

    mov rdi, [rel arena_ptr]
    call arena_destroy
    mov rdi, STDOUT
    lea rsi, [rel pass_msg]
    mov rdx, pass_len
    call hal_write
    xor rdi, rdi
    call hal_exit
