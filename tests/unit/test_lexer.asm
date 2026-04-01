; test_lexer.asm
; Unit tests for shell lexer/tokenizer (Aura Shell)

%include "src/hal/platform_defs.inc"

extern hal_write
extern hal_exit
extern arena_init
extern arena_reset
extern arena_destroy
extern lexer_init
extern lexer_tokenize
extern lexer_get_tokens
extern lexer_get_count

%define ARENA_REQ_SIZE               131072

; Token types
%define TOK_WORD                     1
%define TOK_PIPE                     2
%define TOK_REDIRECT_IN              3
%define TOK_REDIRECT_OUT             4
%define TOK_REDIRECT_APPEND          5
%define TOK_AND                      6
%define TOK_OR                       7
%define TOK_SEMICOLON                8
%define TOK_AMPERSAND                9
%define TOK_LPAREN                   10
%define TOK_RPAREN                   11
%define TOK_LBRACE                   12
%define TOK_RBRACE                   13
%define TOK_VARIABLE                 14
%define TOK_ASSIGNMENT               15
%define TOK_NEWLINE                  16
%define TOK_EOF                      17

%define FLAG_QUOTED                  0x01

%define TOKEN_TYPE_OFF               0
%define TOKEN_START_OFF              8
%define TOKEN_LENGTH_OFF             16
%define TOKEN_FLAGS_OFF              20
%define TOKEN_SIZE                   24

section .data
    pass_msg                 db "ALL TESTS PASSED", 10
    pass_len                 equ $ - pass_msg

    fail_init_msg            db "TEST FAILED: setup_arena_or_lexer", 10
    fail_init_len            equ $ - fail_init_msg

    fail_t1_msg              db "TEST FAILED: test_simple_command", 10
    fail_t1_len              equ $ - fail_t1_msg
    fail_t2_msg              db "TEST FAILED: test_pipe", 10
    fail_t2_len              equ $ - fail_t2_msg
    fail_t3_msg              db "TEST FAILED: test_redirect_out", 10
    fail_t3_len              equ $ - fail_t3_msg
    fail_t4_msg              db "TEST FAILED: test_redirect_append", 10
    fail_t4_len              equ $ - fail_t4_msg
    fail_t5_msg              db "TEST FAILED: test_and_or", 10
    fail_t5_len              equ $ - fail_t5_msg
    fail_t6_msg              db "TEST FAILED: test_background", 10
    fail_t6_len              equ $ - fail_t6_msg
    fail_t7_msg              db "TEST FAILED: test_single_quotes", 10
    fail_t7_len              equ $ - fail_t7_msg
    fail_t8_msg              db "TEST FAILED: test_double_quotes", 10
    fail_t8_len              equ $ - fail_t8_msg
    fail_t9_msg              db "TEST FAILED: test_variable", 10
    fail_t9_len              equ $ - fail_t9_msg
    fail_t10_msg             db "TEST FAILED: test_assignment", 10
    fail_t10_len             equ $ - fail_t10_msg
    fail_t11_msg             db "TEST FAILED: test_comment", 10
    fail_t11_len             equ $ - fail_t11_msg
    fail_t12_msg             db "TEST FAILED: test_empty", 10
    fail_t12_len             equ $ - fail_t12_msg
    fail_t13_msg             db "TEST FAILED: test_complex", 10
    fail_t13_len             equ $ - fail_t13_msg

    in1                      db "ls -la /tmp"
    in1_len                  equ $ - in1
    in2                      db "cat file.txt | grep error"
    in2_len                  equ $ - in2
    in3                      db "echo hello > out.txt"
    in3_len                  equ $ - in3
    in4                      db "echo line >> log.txt"
    in4_len                  equ $ - in4
    in5                      db "make && echo ok || echo fail"
    in5_len                  equ $ - in5
    in6                      db "sleep 10 &"
    in6_len                  equ $ - in6
    in7                      db "echo 'hello world'"
    in7_len                  equ $ - in7
    in8                      db 'echo "hello world"'
    in8_len                  equ $ - in8
    in9                      db "echo $HOME"
    in9_len                  equ $ - in9
    in10                     db "MY_VAR=hello"
    in10_len                 equ $ - in10
    in11                     db "echo hello # this is comment"
    in11_len                 equ $ - in11
    in12                     db ""
    in12_len                 equ $ - in12
    in13                     db "cat < in.txt | grep -v error >> log.txt && echo done"
    in13_len                 equ $ - in13

    s_ls                     db "ls"
    s_ls_len                 equ $ - s_ls
    s_dashla                 db "-la"
    s_dashla_len             equ $ - s_dashla
    s_tmp                    db "/tmp"
    s_tmp_len                equ $ - s_tmp
    s_cat                    db "cat"
    s_cat_len                equ $ - s_cat
    s_file                   db "file.txt"
    s_file_len               equ $ - s_file
    s_grep                   db "grep"
    s_grep_len               equ $ - s_grep
    s_error                  db "error"
    s_error_len              equ $ - s_error
    s_echo                   db "echo"
    s_echo_len               equ $ - s_echo
    s_hello                  db "hello"
    s_hello_len              equ $ - s_hello
    s_out                    db "out.txt"
    s_out_len                equ $ - s_out
    s_line                   db "line"
    s_line_len               equ $ - s_line
    s_log                    db "log.txt"
    s_log_len                equ $ - s_log
    s_make                   db "make"
    s_make_len               equ $ - s_make
    s_ok                     db "ok"
    s_ok_len                 equ $ - s_ok
    s_fail                   db "fail"
    s_fail_len               equ $ - s_fail
    s_sleep                  db "sleep"
    s_sleep_len              equ $ - s_sleep
    s_10                     db "10"
    s_10_len                 equ $ - s_10
    s_hw                     db "hello world"
    s_hw_len                 equ $ - s_hw
    s_home                   db "HOME"
    s_home_len               equ $ - s_home
    s_assign                 db "MY_VAR=hello"
    s_assign_len             equ $ - s_assign
    s_in                     db "in.txt"
    s_in_len                 equ $ - s_in
    s_dashv                  db "-v"
    s_dashv_len              equ $ - s_dashv
    s_done                   db "done"
    s_done_len               equ $ - s_done

section .bss
    arena_ptr                resq 1
    lexer_ptr                resq 1
    tokens_ptr               resq 1
    token_count              resq 1

section .text
global _start

%macro write_stdout 2
    mov rdi, STDOUT
    lea rsi, [rel %1]
    mov rdx, %2
    call hal_write
%endmacro

%macro fail_exit 2
    write_stdout %1, %2
    mov rdi, 1
    call hal_exit
%endmacro

%macro check_count 2
    mov rax, [rel token_count]
    cmp rax, %1
    jne %2
%endmacro

%macro check_type 3
    mov rbx, [rel tokens_ptr]
    lea rbx, [rbx + %1 * TOKEN_SIZE]
    mov eax, dword [rbx + TOKEN_TYPE_OFF]
    cmp eax, %2
    jne %3
%endmacro

%macro check_word 4
    mov rbx, [rel tokens_ptr]
    lea rbx, [rbx + %1 * TOKEN_SIZE]
    mov eax, dword [rbx + TOKEN_LENGTH_OFF]
    cmp eax, %3
    jne %4
    mov rdi, [rbx + TOKEN_START_OFF]
    lea rsi, [rel %2]
    mov rdx, %3
    call memeq
    cmp rax, 1
    jne %4
%endmacro

%macro check_flag_set 3
    mov rbx, [rel tokens_ptr]
    lea rbx, [rbx + %1 * TOKEN_SIZE]
    mov eax, dword [rbx + TOKEN_FLAGS_OFF]
    test eax, %2
    jz %3
%endmacro

; memeq(ptr1, ptr2, len) -> rax=1 if equal
memeq:
    xor eax, eax
    test rdx, rdx
    jz .yes
.loop:
    mov cl, [rdi]
    cmp cl, [rsi]
    jne .no
    inc rdi
    inc rsi
    dec rdx
    jnz .loop
.yes:
    mov eax, 1
    ret
.no:
    xor eax, eax
    ret

; tokenize_input(input_ptr, input_len)
; stores lexer_ptr/tokens_ptr/token_count globals
; rax=0 ok, -1 fail
tokenize_input:
    push rbx
    mov rbx, rdi

    mov rdi, [rel arena_ptr]
    call arena_reset

    mov rdi, [rel arena_ptr]
    mov rsi, rbx
    ; rdx already contains input_len
    call lexer_init
    test rax, rax
    jz .fail
    mov [rel lexer_ptr], rax

    mov rdi, rax
    call lexer_tokenize
    cmp rax, 0
    jne .fail

    mov rdi, [rel lexer_ptr]
    call lexer_get_tokens
    mov [rel tokens_ptr], rax

    mov rdi, [rel lexer_ptr]
    call lexer_get_count
    mov [rel token_count], rax

    xor eax, eax
    pop rbx
    ret

.fail:
    mov rax, -1
    pop rbx
    ret

_start:
    mov rdi, ARENA_REQ_SIZE
    call arena_init
    test rax, rax
    jz .fail_init
    mov [rel arena_ptr], rax

    ; Test 1
    lea rdi, [rel in1]
    mov rdx, in1_len
    call tokenize_input
    cmp rax, 0
    jne .fail_init
    check_count 4, .fail_t1
    check_type 0, TOK_WORD, .fail_t1
    check_word 0, s_ls, s_ls_len, .fail_t1
    check_type 1, TOK_WORD, .fail_t1
    check_word 1, s_dashla, s_dashla_len, .fail_t1
    check_type 2, TOK_WORD, .fail_t1
    check_word 2, s_tmp, s_tmp_len, .fail_t1
    check_type 3, TOK_EOF, .fail_t1

    ; Test 2
    lea rdi, [rel in2]
    mov rdx, in2_len
    call tokenize_input
    cmp rax, 0
    jne .fail_init
    check_count 6, .fail_t2
    check_type 0, TOK_WORD, .fail_t2
    check_word 0, s_cat, s_cat_len, .fail_t2
    check_type 1, TOK_WORD, .fail_t2
    check_word 1, s_file, s_file_len, .fail_t2
    check_type 2, TOK_PIPE, .fail_t2
    check_type 3, TOK_WORD, .fail_t2
    check_word 3, s_grep, s_grep_len, .fail_t2
    check_type 4, TOK_WORD, .fail_t2
    check_word 4, s_error, s_error_len, .fail_t2
    check_type 5, TOK_EOF, .fail_t2

    ; Test 3
    lea rdi, [rel in3]
    mov rdx, in3_len
    call tokenize_input
    cmp rax, 0
    jne .fail_init
    check_count 5, .fail_t3
    check_type 0, TOK_WORD, .fail_t3
    check_word 0, s_echo, s_echo_len, .fail_t3
    check_type 1, TOK_WORD, .fail_t3
    check_word 1, s_hello, s_hello_len, .fail_t3
    check_type 2, TOK_REDIRECT_OUT, .fail_t3
    check_type 3, TOK_WORD, .fail_t3
    check_word 3, s_out, s_out_len, .fail_t3
    check_type 4, TOK_EOF, .fail_t3

    ; Test 4
    lea rdi, [rel in4]
    mov rdx, in4_len
    call tokenize_input
    cmp rax, 0
    jne .fail_init
    check_count 5, .fail_t4
    check_type 0, TOK_WORD, .fail_t4
    check_word 0, s_echo, s_echo_len, .fail_t4
    check_type 1, TOK_WORD, .fail_t4
    check_word 1, s_line, s_line_len, .fail_t4
    check_type 2, TOK_REDIRECT_APPEND, .fail_t4
    check_type 3, TOK_WORD, .fail_t4
    check_word 3, s_log, s_log_len, .fail_t4
    check_type 4, TOK_EOF, .fail_t4

    ; Test 5
    lea rdi, [rel in5]
    mov rdx, in5_len
    call tokenize_input
    cmp rax, 0
    jne .fail_init
    check_count 8, .fail_t5
    check_type 0, TOK_WORD, .fail_t5
    check_word 0, s_make, s_make_len, .fail_t5
    check_type 1, TOK_AND, .fail_t5
    check_type 2, TOK_WORD, .fail_t5
    check_word 2, s_echo, s_echo_len, .fail_t5
    check_type 3, TOK_WORD, .fail_t5
    check_word 3, s_ok, s_ok_len, .fail_t5
    check_type 4, TOK_OR, .fail_t5
    check_type 5, TOK_WORD, .fail_t5
    check_word 5, s_echo, s_echo_len, .fail_t5
    check_type 6, TOK_WORD, .fail_t5
    check_word 6, s_fail, s_fail_len, .fail_t5
    check_type 7, TOK_EOF, .fail_t5

    ; Test 6
    lea rdi, [rel in6]
    mov rdx, in6_len
    call tokenize_input
    cmp rax, 0
    jne .fail_init
    check_count 4, .fail_t6
    check_type 0, TOK_WORD, .fail_t6
    check_word 0, s_sleep, s_sleep_len, .fail_t6
    check_type 1, TOK_WORD, .fail_t6
    check_word 1, s_10, s_10_len, .fail_t6
    check_type 2, TOK_AMPERSAND, .fail_t6
    check_type 3, TOK_EOF, .fail_t6

    ; Test 7
    lea rdi, [rel in7]
    mov rdx, in7_len
    call tokenize_input
    cmp rax, 0
    jne .fail_init
    check_count 3, .fail_t7
    check_type 0, TOK_WORD, .fail_t7
    check_word 0, s_echo, s_echo_len, .fail_t7
    check_type 1, TOK_WORD, .fail_t7
    check_word 1, s_hw, s_hw_len, .fail_t7
    check_flag_set 1, FLAG_QUOTED, .fail_t7
    check_type 2, TOK_EOF, .fail_t7

    ; Test 8
    lea rdi, [rel in8]
    mov rdx, in8_len
    call tokenize_input
    cmp rax, 0
    jne .fail_init
    check_count 3, .fail_t8
    check_type 0, TOK_WORD, .fail_t8
    check_word 0, s_echo, s_echo_len, .fail_t8
    check_type 1, TOK_WORD, .fail_t8
    check_word 1, s_hw, s_hw_len, .fail_t8
    check_flag_set 1, FLAG_QUOTED, .fail_t8
    check_type 2, TOK_EOF, .fail_t8

    ; Test 9
    lea rdi, [rel in9]
    mov rdx, in9_len
    call tokenize_input
    cmp rax, 0
    jne .fail_init
    check_count 3, .fail_t9
    check_type 0, TOK_WORD, .fail_t9
    check_word 0, s_echo, s_echo_len, .fail_t9
    check_type 1, TOK_VARIABLE, .fail_t9
    check_word 1, s_home, s_home_len, .fail_t9
    check_type 2, TOK_EOF, .fail_t9

    ; Test 10
    lea rdi, [rel in10]
    mov rdx, in10_len
    call tokenize_input
    cmp rax, 0
    jne .fail_init
    check_count 2, .fail_t10
    check_type 0, TOK_ASSIGNMENT, .fail_t10
    check_word 0, s_assign, s_assign_len, .fail_t10
    check_type 1, TOK_EOF, .fail_t10

    ; Test 11
    lea rdi, [rel in11]
    mov rdx, in11_len
    call tokenize_input
    cmp rax, 0
    jne .fail_init
    check_count 3, .fail_t11
    check_type 0, TOK_WORD, .fail_t11
    check_word 0, s_echo, s_echo_len, .fail_t11
    check_type 1, TOK_WORD, .fail_t11
    check_word 1, s_hello, s_hello_len, .fail_t11
    check_type 2, TOK_EOF, .fail_t11

    ; Test 12
    lea rdi, [rel in12]
    mov rdx, in12_len
    call tokenize_input
    cmp rax, 0
    jne .fail_init
    check_count 1, .fail_t12
    check_type 0, TOK_EOF, .fail_t12

    ; Test 13
    lea rdi, [rel in13]
    mov rdx, in13_len
    call tokenize_input
    cmp rax, 0
    jne .fail_init
    check_count 13, .fail_t13
    check_type 0, TOK_WORD, .fail_t13
    check_word 0, s_cat, s_cat_len, .fail_t13
    check_type 1, TOK_REDIRECT_IN, .fail_t13
    check_type 2, TOK_WORD, .fail_t13
    check_word 2, s_in, s_in_len, .fail_t13
    check_type 3, TOK_PIPE, .fail_t13
    check_type 4, TOK_WORD, .fail_t13
    check_word 4, s_grep, s_grep_len, .fail_t13
    check_type 5, TOK_WORD, .fail_t13
    check_word 5, s_dashv, s_dashv_len, .fail_t13
    check_type 6, TOK_WORD, .fail_t13
    check_word 6, s_error, s_error_len, .fail_t13
    check_type 7, TOK_REDIRECT_APPEND, .fail_t13
    check_type 8, TOK_WORD, .fail_t13
    check_word 8, s_log, s_log_len, .fail_t13
    check_type 9, TOK_AND, .fail_t13
    check_type 10, TOK_WORD, .fail_t13
    check_word 10, s_echo, s_echo_len, .fail_t13
    check_type 11, TOK_WORD, .fail_t13
    check_word 11, s_done, s_done_len, .fail_t13
    check_type 12, TOK_EOF, .fail_t13

    mov rdi, [rel arena_ptr]
    call arena_destroy
    cmp rax, 0
    jne .fail_init

    write_stdout pass_msg, pass_len
    xor rdi, rdi
    call hal_exit

.fail_init:
    fail_exit fail_init_msg, fail_init_len
.fail_t1:
    fail_exit fail_t1_msg, fail_t1_len
.fail_t2:
    fail_exit fail_t2_msg, fail_t2_len
.fail_t3:
    fail_exit fail_t3_msg, fail_t3_len
.fail_t4:
    fail_exit fail_t4_msg, fail_t4_len
.fail_t5:
    fail_exit fail_t5_msg, fail_t5_len
.fail_t6:
    fail_exit fail_t6_msg, fail_t6_len
.fail_t7:
    fail_exit fail_t7_msg, fail_t7_len
.fail_t8:
    fail_exit fail_t8_msg, fail_t8_len
.fail_t9:
    fail_exit fail_t9_msg, fail_t9_len
.fail_t10:
    fail_exit fail_t10_msg, fail_t10_len
.fail_t11:
    fail_exit fail_t11_msg, fail_t11_len
.fail_t12:
    fail_exit fail_t12_msg, fail_t12_len
.fail_t13:
    fail_exit fail_t13_msg, fail_t13_len
