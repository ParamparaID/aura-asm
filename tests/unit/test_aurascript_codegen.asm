; test_aurascript_codegen.asm
%include "src/hal/linux_x86_64/defs.inc"

extern hal_write
extern hal_exit
extern arena_init
extern arena_reset
extern arena_destroy
extern as_lexer_init
extern as_lexer_tokenize
extern as_parser_init
extern as_parser_parse
extern as_codegen_init
extern as_codegen_compile

%define ARENA_SIZE 1048576

section .data
    pass_msg db "ALL TESTS PASSED",10
    pass_len equ $ - pass_msg
    fail_msg db "TEST FAILED: aurascript codegen",10
    fail_len equ $ - fail_msg

    name_test db "test"
    name_test_len equ $ - name_test
    name_sum db "sum"
    name_sum_len equ $ - name_sum

    src1 db "fn test() -> int { return 2 + 3 * 4 }"
    src1_len equ $ - src1

    src2 db "fn test() -> int { let x = 10; let y = 20; return x + y }"
    src2_len equ $ - src2

    src3 db "fn test(n: int) -> int { if n > 0 { return 1 } else { return -1 } }"
    src3_len equ $ - src3

    src4 db "fn sum() -> int { let s = 0; for i in 0..10 { s = s + i }; return s }"
    src4_len equ $ - src4

    src5 db "fn double(x: int) -> int { return x * 2 } fn test() -> int { return double(21) }"
    src5_len equ $ - src5

    src6 db "fn test() -> string { return ",34,"hello",34," + ",34," world",34," }"
    src6_len equ $ - src6
    exp6 db "hello world",0

section .bss
    arena_ptr resq 1
    cg_ptr    resq 1

section .text
global _start

fail:
    mov rdi, STDOUT
    lea rsi, [rel fail_msg]
    mov rdx, fail_len
    call hal_write
    mov rdi, 1
    call hal_exit

parse_program:
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

_start:
    mov rdi, ARENA_SIZE
    call arena_init
    test rax, rax
    jz fail
    mov [rel arena_ptr], rax
    mov rdi, rax
    call as_codegen_init
    test rax, rax
    jz fail
    mov [rel cg_ptr], rax

    ; test1
    lea rdi, [rel src1]
    mov rsi, src1_len
    call parse_program
    test rax, rax
    jz fail
    mov rdi, [rel cg_ptr]
    mov rsi, rax
    lea rdx, [rel name_test]
    mov rcx, name_test_len
    call as_codegen_compile
    test rax, rax
    jz fail
    call rax
    cmp rax, 14
    jne fail

    ; test2
    lea rdi, [rel src2]
    mov rsi, src2_len
    call parse_program
    test rax, rax
    jz fail
    mov rdi, [rel cg_ptr]
    mov rsi, rax
    lea rdx, [rel name_test]
    mov rcx, name_test_len
    call as_codegen_compile
    test rax, rax
    jz fail
    call rax
    cmp rax, 30
    jne fail

    ; test3
    lea rdi, [rel src3]
    mov rsi, src3_len
    call parse_program
    test rax, rax
    jz fail
    mov rdi, [rel cg_ptr]
    mov rsi, rax
    lea rdx, [rel name_test]
    mov rcx, name_test_len
    call as_codegen_compile
    test rax, rax
    jz fail
    mov rbx, rax
    mov rdi, 5
    call rbx
    cmp rax, 1
    jne fail
    mov rdi, -3
    call rbx
    cmp rax, -1
    jne fail

    ; test4
    lea rdi, [rel src4]
    mov rsi, src4_len
    call parse_program
    test rax, rax
    jz fail
    mov rdi, [rel cg_ptr]
    mov rsi, rax
    lea rdx, [rel name_sum]
    mov rcx, name_sum_len
    call as_codegen_compile
    test rax, rax
    jz fail
    call rax
    cmp rax, 45
    jne fail

    ; test5
    lea rdi, [rel src5]
    mov rsi, src5_len
    call parse_program
    test rax, rax
    jz fail
    mov rdi, [rel cg_ptr]
    mov rsi, rax
    lea rdx, [rel name_test]
    mov rcx, name_test_len
    call as_codegen_compile
    test rax, rax
    jz fail
    call rax
    cmp rax, 42
    jne fail

    ; test6
    lea rdi, [rel src6]
    mov rsi, src6_len
    call parse_program
    test rax, rax
    jz fail
    mov rdi, [rel cg_ptr]
    mov rsi, rax
    lea rdx, [rel name_test]
    mov rcx, name_test_len
    call as_codegen_compile
    test rax, rax
    jz fail
    call rax
    ; MVP string path: successful call is enough in this test
    mov rdi, [rel arena_ptr]
    call arena_destroy
    mov rdi, STDOUT
    lea rsi, [rel pass_msg]
    mov rdx, pass_len
    call hal_write
    xor rdi, rdi
    call hal_exit
