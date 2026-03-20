; test_parser.asm
; Unit tests for shell parser/AST (Aura Shell)

%include "src/hal/linux_x86_64/defs.inc"

extern hal_write
extern hal_exit
extern arena_init
extern arena_reset
extern arena_destroy
extern lexer_init
extern lexer_tokenize
extern parser_init
extern parser_parse
extern parser_get_error

%define ARENA_REQ_SIZE               262144

; AST node types
%define NODE_COMMAND                 1
%define NODE_PIPELINE                2
%define NODE_LIST                    3

; List operators
%define OP_AND                       1
%define OP_OR                        2
%define OP_SEQ                       3

; CommandNode layout (must match parser.asm)
%define CMD_TYPE_OFF                 0
%define CMD_ARGC_OFF                 4
%define CMD_ARGV_OFF                 8
%define CMD_ARGV_LEN_OFF             136
%define CMD_REDIRECT_IN_OFF          200
%define CMD_REDIRECT_IN_LEN_OFF      208
%define CMD_REDIRECT_OUT_OFF         216
%define CMD_REDIRECT_OUT_LEN_OFF     224
%define CMD_REDIRECT_APPEND_OFF      228
%define CMD_ASSIGN_PTRS_OFF          232
%define CMD_ASSIGN_LENS_OFF          240
%define CMD_ASSIGN_COUNT_OFF         248
%define CMD_BACKGROUND_OFF           252

; PipelineNode layout
%define PL_TYPE_OFF                  0
%define PL_CMD_COUNT_OFF             4
%define PL_COMMANDS_OFF              8

; ListNode layout
%define LS_TYPE_OFF                  0
%define LS_COUNT_OFF                 4
%define LS_PIPELINES_OFF             8
%define LS_OPERATORS_OFF             136

section .data
    pass_msg                 db "ALL TESTS PASSED", 10
    pass_len                 equ $ - pass_msg

    fail_setup_msg           db "TEST FAILED: setup_or_lex", 10
    fail_setup_len           equ $ - fail_setup_msg
    fail_t1_msg              db "TEST FAILED: test_simple_command_ast", 10
    fail_t1_len              equ $ - fail_t1_msg
    fail_t2_msg              db "TEST FAILED: test_pipeline_ast", 10
    fail_t2_len              equ $ - fail_t2_msg
    fail_t3_msg              db "TEST FAILED: test_redirect_ast", 10
    fail_t3_len              equ $ - fail_t3_msg
    fail_t4_msg              db "TEST FAILED: test_redirect_pipe_redirect", 10
    fail_t4_len              equ $ - fail_t4_msg
    fail_t5_msg              db "TEST FAILED: test_and_or_ast", 10
    fail_t5_len              equ $ - fail_t5_msg
    fail_t6_msg              db "TEST FAILED: test_background_ast", 10
    fail_t6_len              equ $ - fail_t6_msg
    fail_t7_msg              db "TEST FAILED: test_assignment_ast", 10
    fail_t7_len              equ $ - fail_t7_msg
    fail_t8_msg              db "TEST FAILED: test_complex_ast", 10
    fail_t8_len              equ $ - fail_t8_msg
    fail_t9_msg              db "TEST FAILED: test_empty_input_ast", 10
    fail_t9_len              equ $ - fail_t9_msg
    fail_t10_msg             db "TEST FAILED: test_parse_error_ast", 10
    fail_t10_len             equ $ - fail_t10_msg

    in1                      db "ls -la /tmp"
    in1_len                  equ $ - in1
    in2                      db "cat file | grep error | wc -l"
    in2_len                  equ $ - in2
    in3                      db "echo hello > out.txt"
    in3_len                  equ $ - in3
    in4                      db "cat < in.txt | sort > out.txt"
    in4_len                  equ $ - in4
    in5                      db "make && echo ok || echo fail"
    in5_len                  equ $ - in5
    in6                      db "sleep 10 &"
    in6_len                  equ $ - in6
    in7                      db "CC=gcc make -j4"
    in7_len                  equ $ - in7
    in8                      db "cat < input | grep -v error >> log.txt && echo done || echo fail"
    in8_len                  equ $ - in8
    in9                      db ""
    in9_len                  equ $ - in9
    in10                     db "| invalid"
    in10_len                 equ $ - in10

    s_ls                     db "ls"
    s_ls_len                 equ $ - s_ls
    s_dashla                 db "-la"
    s_dashla_len             equ $ - s_dashla
    s_tmp                    db "/tmp"
    s_tmp_len                equ $ - s_tmp
    s_cat                    db "cat"
    s_cat_len                equ $ - s_cat
    s_file                   db "file"
    s_file_len               equ $ - s_file
    s_grep                   db "grep"
    s_grep_len               equ $ - s_grep
    s_error                  db "error"
    s_error_len              equ $ - s_error
    s_wc                     db "wc"
    s_wc_len                 equ $ - s_wc
    s_dashl                  db "-l"
    s_dashl_len              equ $ - s_dashl
    s_echo                   db "echo"
    s_echo_len               equ $ - s_echo
    s_hello                  db "hello"
    s_hello_len              equ $ - s_hello
    s_out                    db "out.txt"
    s_out_len                equ $ - s_out
    s_in                     db "in.txt"
    s_in_len                 equ $ - s_in
    s_sort                   db "sort"
    s_sort_len               equ $ - s_sort
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
    s_assign                 db "CC=gcc"
    s_assign_len             equ $ - s_assign
    s_dashj4                 db "-j4"
    s_dashj4_len             equ $ - s_dashj4
    s_input                  db "input"
    s_input_len              equ $ - s_input
    s_dashv                  db "-v"
    s_dashv_len              equ $ - s_dashv
    s_log                    db "log.txt"
    s_log_len                equ $ - s_log
    s_done                   db "done"
    s_done_len               equ $ - s_done

section .bss
    arena_ptr                resq 1
    lexer_ptr                resq 1
    parser_ptr               resq 1
    root_ptr                 resq 1

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

; check_str(ptr, len, expected_ptr, expected_len) -> rax=1 if equal
check_str:
    cmp rsi, rcx
    jne .no
    mov rdx, rsi
    mov rsi, rdx
    ; fix args for memeq
    ; rdi already ptr
    mov rsi, r8
    call memeq
    ret
.no:
    xor eax, eax
    ret

; run_parse(input_ptr, input_len)
; stores lexer_ptr/parser_ptr/root_ptr
; rax = root_ptr (or 0 on parse error)
run_parse:
    push rbx
    mov rbx, rdi

    mov rdi, [rel arena_ptr]
    call arena_reset

    mov rdi, [rel arena_ptr]
    mov rsi, rbx
    ; rdx = input_len
    call lexer_init
    test rax, rax
    jz .lex_fail
    mov [rel lexer_ptr], rax

    mov rdi, rax
    call lexer_tokenize
    cmp rax, 0
    jne .lex_fail

    mov rdi, [rel arena_ptr]
    mov rsi, [rel lexer_ptr]
    call parser_init
    test rax, rax
    jz .lex_fail
    mov [rel parser_ptr], rax

    mov rdi, rax
    call parser_parse
    mov [rel root_ptr], rax
    pop rbx
    ret

.lex_fail:
    xor eax, eax
    mov [rel root_ptr], rax
    pop rbx
    ret

; get pipeline i from root
; rdi=root, rsi=index -> rax=pipeline ptr
list_get_pipeline:
    mov rax, [rdi + LS_PIPELINES_OFF + rsi*8]
    ret

; get command i from pipeline
; rdi=pipeline, rsi=index -> rax=command ptr
pipeline_get_cmd:
    mov rax, [rdi + PL_COMMANDS_OFF + rsi*8]
    ret

_start:
    mov rdi, ARENA_REQ_SIZE
    call arena_init
    test rax, rax
    jz .fail_setup
    mov [rel arena_ptr], rax

    ; Test 1: simple command
    lea rdi, [rel in1]
    mov rdx, in1_len
    call run_parse
    test rax, rax
    jz .fail_t1
    mov rbx, rax
    cmp dword [rbx + LS_TYPE_OFF], NODE_LIST
    jne .fail_t1
    cmp dword [rbx + LS_COUNT_OFF], 1
    jne .fail_t1
    mov rdi, rbx
    xor esi, esi
    call list_get_pipeline
    test rax, rax
    jz .fail_t1
    mov r12, rax
    cmp dword [r12 + PL_TYPE_OFF], NODE_PIPELINE
    jne .fail_t1
    cmp dword [r12 + PL_CMD_COUNT_OFF], 1
    jne .fail_t1
    mov rdi, r12
    xor esi, esi
    call pipeline_get_cmd
    test rax, rax
    jz .fail_t1
    mov r13, rax
    cmp dword [r13 + CMD_ARGC_OFF], 3
    jne .fail_t1
    mov rdi, [r13 + CMD_ARGV_OFF + 0*8]
    mov esi, [r13 + CMD_ARGV_LEN_OFF + 0*4]
    lea r8, [rel s_ls]
    mov ecx, s_ls_len
    call check_str
    cmp rax, 1
    jne .fail_t1
    mov rdi, [r13 + CMD_ARGV_OFF + 1*8]
    mov esi, [r13 + CMD_ARGV_LEN_OFF + 1*4]
    lea r8, [rel s_dashla]
    mov ecx, s_dashla_len
    call check_str
    cmp rax, 1
    jne .fail_t1
    mov rdi, [r13 + CMD_ARGV_OFF + 2*8]
    mov esi, [r13 + CMD_ARGV_LEN_OFF + 2*4]
    lea r8, [rel s_tmp]
    mov ecx, s_tmp_len
    call check_str
    cmp rax, 1
    jne .fail_t1

    ; Test 2: pipeline
    lea rdi, [rel in2]
    mov rdx, in2_len
    call run_parse
    test rax, rax
    jz .fail_t2
    mov rbx, rax
    cmp dword [rbx + LS_COUNT_OFF], 1
    jne .fail_t2
    mov rdi, rbx
    xor esi, esi
    call list_get_pipeline
    mov r12, rax
    cmp dword [r12 + PL_CMD_COUNT_OFF], 3
    jne .fail_t2
    mov rdi, r12
    xor esi, esi
    call pipeline_get_cmd
    mov r13, rax
    mov rdi, [r13 + CMD_ARGV_OFF + 0*8]
    mov esi, [r13 + CMD_ARGV_LEN_OFF + 0*4]
    lea r8, [rel s_cat]
    mov ecx, s_cat_len
    call check_str
    cmp rax, 1
    jne .fail_t2
    mov rdi, r12
    mov esi, 1
    call pipeline_get_cmd
    mov r13, rax
    mov rdi, [r13 + CMD_ARGV_OFF + 0*8]
    mov esi, [r13 + CMD_ARGV_LEN_OFF + 0*4]
    lea r8, [rel s_grep]
    mov ecx, s_grep_len
    call check_str
    cmp rax, 1
    jne .fail_t2
    mov rdi, r12
    mov esi, 2
    call pipeline_get_cmd
    mov r13, rax
    mov rdi, [r13 + CMD_ARGV_OFF + 0*8]
    mov esi, [r13 + CMD_ARGV_LEN_OFF + 0*4]
    lea r8, [rel s_wc]
    mov ecx, s_wc_len
    call check_str
    cmp rax, 1
    jne .fail_t2

    ; Test 3: redirect out
    lea rdi, [rel in3]
    mov rdx, in3_len
    call run_parse
    test rax, rax
    jz .fail_t3
    mov rbx, rax
    mov rdi, rbx
    xor esi, esi
    call list_get_pipeline
    mov rdi, rax
    xor esi, esi
    call pipeline_get_cmd
    mov r13, rax
    cmp dword [r13 + CMD_REDIRECT_APPEND_OFF], 0
    jne .fail_t3
    mov rdi, [r13 + CMD_REDIRECT_OUT_OFF]
    mov esi, [r13 + CMD_REDIRECT_OUT_LEN_OFF]
    lea r8, [rel s_out]
    mov ecx, s_out_len
    call check_str
    cmp rax, 1
    jne .fail_t3

    ; Test 4: in redirect + pipe + out redirect
    lea rdi, [rel in4]
    mov rdx, in4_len
    call run_parse
    test rax, rax
    jz .fail_t4
    mov rbx, rax
    mov rdi, rbx
    xor esi, esi
    call list_get_pipeline
    mov r12, rax
    cmp dword [r12 + PL_CMD_COUNT_OFF], 2
    jne .fail_t4
    mov rdi, r12
    xor esi, esi
    call pipeline_get_cmd
    mov r13, rax
    mov rdi, [r13 + CMD_REDIRECT_IN_OFF]
    mov esi, [r13 + CMD_REDIRECT_IN_LEN_OFF]
    lea r8, [rel s_in]
    mov ecx, s_in_len
    call check_str
    cmp rax, 1
    jne .fail_t4
    mov rdi, r12
    mov esi, 1
    call pipeline_get_cmd
    mov r13, rax
    mov rdi, [r13 + CMD_REDIRECT_OUT_OFF]
    mov esi, [r13 + CMD_REDIRECT_OUT_LEN_OFF]
    lea r8, [rel s_out]
    mov ecx, s_out_len
    call check_str
    cmp rax, 1
    jne .fail_t4

    ; Test 5: AND/OR list
    lea rdi, [rel in5]
    mov rdx, in5_len
    call run_parse
    test rax, rax
    jz .fail_t5
    mov rbx, rax
    cmp dword [rbx + LS_COUNT_OFF], 3
    jne .fail_t5
    cmp dword [rbx + LS_OPERATORS_OFF + 1*4], OP_AND
    jne .fail_t5
    cmp dword [rbx + LS_OPERATORS_OFF + 2*4], OP_OR
    jne .fail_t5

    ; Test 6: background
    lea rdi, [rel in6]
    mov rdx, in6_len
    call run_parse
    test rax, rax
    jz .fail_t6
    mov rbx, rax
    mov rdi, rbx
    xor esi, esi
    call list_get_pipeline
    mov rdi, rax
    xor esi, esi
    call pipeline_get_cmd
    mov r13, rax
    cmp dword [r13 + CMD_BACKGROUND_OFF], 1
    jne .fail_t6

    ; Test 7: assignment + command
    lea rdi, [rel in7]
    mov rdx, in7_len
    call run_parse
    test rax, rax
    jz .fail_t7
    mov rbx, rax
    mov rdi, rbx
    xor esi, esi
    call list_get_pipeline
    mov rdi, rax
    xor esi, esi
    call pipeline_get_cmd
    mov r13, rax
    cmp dword [r13 + CMD_ASSIGN_COUNT_OFF], 1
    jne .fail_t7
    mov r14, [r13 + CMD_ASSIGN_PTRS_OFF]
    mov r15, [r13 + CMD_ASSIGN_LENS_OFF]
    mov rdi, [r14 + 0*8]
    mov esi, [r15 + 0*4]
    lea r8, [rel s_assign]
    mov ecx, s_assign_len
    call check_str
    cmp rax, 1
    jne .fail_t7
    cmp dword [r13 + CMD_ARGC_OFF], 2
    jne .fail_t7
    mov rdi, [r13 + CMD_ARGV_OFF + 0*8]
    mov esi, [r13 + CMD_ARGV_LEN_OFF + 0*4]
    lea r8, [rel s_make]
    mov ecx, s_make_len
    call check_str
    cmp rax, 1
    jne .fail_t7
    mov rdi, [r13 + CMD_ARGV_OFF + 1*8]
    mov esi, [r13 + CMD_ARGV_LEN_OFF + 1*4]
    lea r8, [rel s_dashj4]
    mov ecx, s_dashj4_len
    call check_str
    cmp rax, 1
    jne .fail_t7

    ; Test 8: complex AST
    lea rdi, [rel in8]
    mov rdx, in8_len
    call run_parse
    test rax, rax
    jz .fail_t8
    mov rbx, rax
    cmp dword [rbx + LS_COUNT_OFF], 3
    jne .fail_t8
    cmp dword [rbx + LS_OPERATORS_OFF + 1*4], OP_AND
    jne .fail_t8
    cmp dword [rbx + LS_OPERATORS_OFF + 2*4], OP_OR
    jne .fail_t8
    mov rdi, rbx
    xor esi, esi
    call list_get_pipeline
    mov r12, rax
    cmp dword [r12 + PL_CMD_COUNT_OFF], 2
    jne .fail_t8
    mov rdi, r12
    xor esi, esi
    call pipeline_get_cmd
    mov r13, rax
    mov rdi, [r13 + CMD_REDIRECT_IN_OFF]
    mov esi, [r13 + CMD_REDIRECT_IN_LEN_OFF]
    lea r8, [rel s_input]
    mov ecx, s_input_len
    call check_str
    cmp rax, 1
    jne .fail_t8
    mov rdi, r12
    mov esi, 1
    call pipeline_get_cmd
    mov r13, rax
    cmp dword [r13 + CMD_REDIRECT_APPEND_OFF], 1
    jne .fail_t8
    mov rdi, [r13 + CMD_REDIRECT_OUT_OFF]
    mov esi, [r13 + CMD_REDIRECT_OUT_LEN_OFF]
    lea r8, [rel s_log]
    mov ecx, s_log_len
    call check_str
    cmp rax, 1
    jne .fail_t8

    ; Test 9: empty input
    lea rdi, [rel in9]
    mov rdx, in9_len
    call run_parse
    test rax, rax
    jz .fail_t9
    mov rbx, rax
    cmp dword [rbx + LS_TYPE_OFF], NODE_LIST
    jne .fail_t9
    cmp dword [rbx + LS_COUNT_OFF], 0
    jne .fail_t9

    ; Test 10: parse error
    lea rdi, [rel in10]
    mov rdx, in10_len
    call run_parse
    test rax, rax
    jnz .fail_t10
    mov rdi, [rel parser_ptr]
    call parser_get_error
    test rax, rax
    jz .fail_t10

    mov rdi, [rel arena_ptr]
    call arena_destroy
    cmp rax, 0
    jne .fail_setup

    write_stdout pass_msg, pass_len
    xor rdi, rdi
    call hal_exit

.fail_setup:
    fail_exit fail_setup_msg, fail_setup_len
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
