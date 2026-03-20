; parser.asm
; Recursive-descent parser for Aura Shell Phase 1 (Linux x86_64, NASM)

extern arena_alloc
extern lexer_get_tokens
extern lexer_get_count

section .text
global parser_init
global parser_parse
global parser_get_error

; Token types (from lexer)
%define TOK_WORD                    1
%define TOK_PIPE                    2
%define TOK_REDIRECT_IN             3
%define TOK_REDIRECT_OUT            4
%define TOK_REDIRECT_APPEND         5
%define TOK_AND                     6
%define TOK_OR                      7
%define TOK_SEMICOLON               8
%define TOK_AMPERSAND               9
%define TOK_VARIABLE                14
%define TOK_ASSIGNMENT              15
%define TOK_NEWLINE                 16
%define TOK_EOF                     17

; Token layout
%define TOKEN_TYPE_OFF              0
%define TOKEN_START_OFF             8
%define TOKEN_LENGTH_OFF            16
%define TOKEN_SIZE                  24

; AST node types
%define NODE_COMMAND                1
%define NODE_PIPELINE               2
%define NODE_LIST                   3

; List operators
%define OP_AND                      1
%define OP_OR                       2
%define OP_SEQ                      3

%define MAX_ARGS                    16
%define MAX_COMMANDS                16
%define MAX_LIST_ITEMS              16
%define MAX_ASSIGNMENTS             16

; Parser layout
%define PS_ARENA_PTR_OFF            0
%define PS_LEXER_PTR_OFF            8
%define PS_TOKENS_OFF               16
%define PS_TOKEN_COUNT_OFF          24
%define PS_POS_OFF                  32
%define PS_ERROR_MSG_OFF            40
%define PARSER_STRUCT_SIZE          48

; CommandNode layout (256 bytes)
%define CMD_TYPE_OFF                0
%define CMD_ARGC_OFF                4
%define CMD_ARGV_OFF                8
%define CMD_ARGV_LEN_OFF            136
%define CMD_REDIRECT_IN_OFF         200
%define CMD_REDIRECT_IN_LEN_OFF     208
%define CMD_REDIRECT_OUT_OFF        216
%define CMD_REDIRECT_OUT_LEN_OFF    224
%define CMD_REDIRECT_APPEND_OFF     228
%define CMD_ASSIGN_PTRS_OFF         232
%define CMD_ASSIGN_LENS_OFF         240
%define CMD_ASSIGN_COUNT_OFF        248
%define CMD_BACKGROUND_OFF          252
%define CMD_NODE_SIZE               256

; PipelineNode layout (144 bytes)
%define PL_TYPE_OFF                 0
%define PL_CMD_COUNT_OFF            4
%define PL_COMMANDS_OFF             8
%define PL_NEGATED_OFF              136
%define PIPELINE_NODE_SIZE          144

; ListNode layout (200 bytes)
%define LS_TYPE_OFF                 0
%define LS_COUNT_OFF                4
%define LS_PIPELINES_OFF            8
%define LS_OPERATORS_OFF            136
%define LIST_NODE_SIZE              200

section .rodata
    err_alloc_parser          db "parser: allocation failed (parser)", 0
    err_alloc_node            db "parser: allocation failed (node)", 0
    err_unexpected_token      db "parser: unexpected token", 0
    err_unexpected_eof        db "parser: unexpected end of input", 0
    err_expected_command      db "parser: expected command", 0
    err_expected_word         db "parser: expected word", 0
    err_too_many_args         db "parser: too many arguments", 0
    err_too_many_cmds         db "parser: too many commands in pipeline", 0
    err_too_many_list_items   db "parser: too many list items", 0
    err_too_many_assign       db "parser: too many assignments", 0

section .text

set_error:
    mov [rdi + PS_ERROR_MSG_OFF], rsi
    xor eax, eax
    ret

memzero:
    test rsi, rsi
    jz .ret
    xor eax, eax
.loop:
    mov byte [rdi], al
    inc rdi
    dec rsi
    jnz .loop
.ret:
    ret

; alloc_node(parser, size)
; rax=node ptr or 0
alloc_node:
    push rbx
    mov rbx, rdi
    mov rdi, [rbx + PS_ARENA_PTR_OFF]
    call arena_alloc
    test rax, rax
    jnz .ok
    lea rsi, [rel err_alloc_node]
    mov rdi, rbx
    call set_error
    xor eax, eax
    pop rbx
    ret
.ok:
    pop rbx
    ret

; peek_token(parser) -> rax=token ptr or 0
peek_token:
    mov rax, [rdi + PS_POS_OFF]
    cmp rax, [rdi + PS_TOKEN_COUNT_OFF]
    jae .none
    mov rdx, [rdi + PS_TOKENS_OFF]
    imul rax, TOKEN_SIZE
    add rax, rdx
    ret
.none:
    xor eax, eax
    ret

; advance(parser) -> rax=old token ptr or 0
advance:
    push rbx
    mov rbx, rdi
    call peek_token
    test rax, rax
    jz .ret
    inc qword [rbx + PS_POS_OFF]
.ret:
    pop rbx
    ret

; expect_token(parser, token_type)
; rax=token ptr or 0 on error
expect_token:
    push rbx
    mov rbx, rdi
    mov r8d, esi
    call peek_token
    test rax, rax
    jz .eof
    mov ecx, dword [rax + TOKEN_TYPE_OFF]
    cmp ecx, r8d
    jne .bad
    mov rdi, rbx
    call advance
    pop rbx
    ret
.eof:
    lea rsi, [rel err_unexpected_eof]
    mov rdi, rbx
    call set_error
    xor eax, eax
    pop rbx
    ret
.bad:
    lea rsi, [rel err_unexpected_token]
    mov rdi, rbx
    call set_error
    xor eax, eax
    pop rbx
    ret

skip_newlines:
    push rbx
    mov rbx, rdi
.loop:
    mov rdi, rbx
    call peek_token
    test rax, rax
    jz .ret
    cmp dword [rax + TOKEN_TYPE_OFF], TOK_NEWLINE
    jne .ret
    mov rdi, rbx
    call advance
    jmp .loop
.ret:
    pop rbx
    ret

; parse_redirect(parser, cmd_ptr)
; rax=1 success, 0 fail
parse_redirect:
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdi
    mov r12, rsi

    mov rdi, rbx
    call peek_token
    test rax, rax
    jz .eof
    mov r8d, dword [rax + TOKEN_TYPE_OFF] ; redirect token type
    mov rdi, rbx
    call advance

    mov rdi, rbx
    call peek_token
    test rax, rax
    jz .eof
    mov ecx, dword [rax + TOKEN_TYPE_OFF]
    cmp ecx, TOK_WORD
    je .have_word
    cmp ecx, TOK_VARIABLE
    je .have_word
    lea rsi, [rel err_expected_word]
    mov rdi, rbx
    call set_error
    xor eax, eax
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

.have_word:
    mov r13, [rax + TOKEN_START_OFF]
    mov r14d, dword [rax + TOKEN_LENGTH_OFF]
    mov rdi, rbx
    call advance

    cmp r8d, TOK_REDIRECT_IN
    jne .check_out
    mov [r12 + CMD_REDIRECT_IN_OFF], r13
    mov dword [r12 + CMD_REDIRECT_IN_LEN_OFF], r14d
    mov eax, 1
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

.check_out:
    mov [r12 + CMD_REDIRECT_OUT_OFF], r13
    mov dword [r12 + CMD_REDIRECT_OUT_LEN_OFF], r14d
    cmp r8d, TOK_REDIRECT_APPEND
    jne .normal_out
    mov dword [r12 + CMD_REDIRECT_APPEND_OFF], 1
    jmp .ok
.normal_out:
    mov dword [r12 + CMD_REDIRECT_APPEND_OFF], 0
.ok:
    mov eax, 1
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

.eof:
    lea rsi, [rel err_unexpected_eof]
    mov rdi, rbx
    call set_error
    xor eax, eax
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; parse_command(parser) -> rax=CommandNode* or 0
parse_command:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi

    mov rdi, rbx
    mov rsi, CMD_NODE_SIZE
    call alloc_node
    test rax, rax
    jz .fail
    mov r12, rax

    mov rdi, r12
    mov rsi, CMD_NODE_SIZE
    call memzero
    mov dword [r12 + CMD_TYPE_OFF], NODE_COMMAND

    mov rdi, rbx
    mov rsi, MAX_ASSIGNMENTS * 8
    call alloc_node
    test rax, rax
    jz .fail
    mov [r12 + CMD_ASSIGN_PTRS_OFF], rax

    mov rdi, rbx
    mov rsi, MAX_ASSIGNMENTS * 4
    call alloc_node
    test rax, rax
    jz .fail
    mov [r12 + CMD_ASSIGN_LENS_OFF], rax

    ; leading assignments
.assign_loop:
    mov rdi, rbx
    call peek_token
    test rax, rax
    jz .after_assign
    cmp dword [rax + TOKEN_TYPE_OFF], TOK_ASSIGNMENT
    jne .after_assign

    mov ecx, dword [r12 + CMD_ASSIGN_COUNT_OFF]
    cmp ecx, MAX_ASSIGNMENTS
    jb .assign_store
    lea rsi, [rel err_too_many_assign]
    mov rdi, rbx
    call set_error
    jmp .fail

.assign_store:
    mov rdx, [r12 + CMD_ASSIGN_PTRS_OFF]
    mov r8, [rax + TOKEN_START_OFF]
    mov [rdx + rcx*8], r8
    mov rdx, [r12 + CMD_ASSIGN_LENS_OFF]
    mov r8d, dword [rax + TOKEN_LENGTH_OFF]
    mov dword [rdx + rcx*4], r8d
    inc dword [r12 + CMD_ASSIGN_COUNT_OFF]
    mov rdi, rbx
    call advance
    jmp .assign_loop

.after_assign:
    ; command name (word/variable) optional only if no assignments
    mov rdi, rbx
    call peek_token
    test rax, rax
    jz .no_cmd_name
    mov ecx, dword [rax + TOKEN_TYPE_OFF]
    cmp ecx, TOK_WORD
    je .add_first_arg
    cmp ecx, TOK_VARIABLE
    je .add_first_arg
    jmp .no_cmd_name

.add_first_arg:
    mov r13d, dword [r12 + CMD_ARGC_OFF]
    cmp r13d, MAX_ARGS
    jb .store_first
    lea rsi, [rel err_too_many_args]
    mov rdi, rbx
    call set_error
    jmp .fail
.store_first:
    mov rdx, [rax + TOKEN_START_OFF]
    mov [r12 + CMD_ARGV_OFF + r13*8], rdx
    mov edx, dword [rax + TOKEN_LENGTH_OFF]
    mov dword [r12 + CMD_ARGV_LEN_OFF + r13*4], edx
    inc dword [r12 + CMD_ARGC_OFF]
    mov rdi, rbx
    call advance

.no_cmd_name:
    ; if no argv and no assignments, this is not a command start
    cmp dword [r12 + CMD_ARGC_OFF], 0
    jne .tail_loop
    cmp dword [r12 + CMD_ASSIGN_COUNT_OFF], 0
    jne .tail_loop
    lea rsi, [rel err_expected_command]
    mov rdi, rbx
    call set_error
    jmp .fail

.tail_loop:
    mov rdi, rbx
    call peek_token
    test rax, rax
    jz .ok
    mov r14d, dword [rax + TOKEN_TYPE_OFF]

    cmp r14d, TOK_WORD
    je .add_arg
    cmp r14d, TOK_VARIABLE
    je .add_arg
    cmp r14d, TOK_REDIRECT_IN
    je .redir
    cmp r14d, TOK_REDIRECT_OUT
    je .redir
    cmp r14d, TOK_REDIRECT_APPEND
    je .redir
    cmp r14d, TOK_AMPERSAND
    je .background
    jmp .ok

.add_arg:
    mov r13d, dword [r12 + CMD_ARGC_OFF]
    cmp r13d, MAX_ARGS
    jb .store_arg
    lea rsi, [rel err_too_many_args]
    mov rdi, rbx
    call set_error
    jmp .fail
.store_arg:
    mov rdx, [rax + TOKEN_START_OFF]
    mov [r12 + CMD_ARGV_OFF + r13*8], rdx
    mov edx, dword [rax + TOKEN_LENGTH_OFF]
    mov dword [r12 + CMD_ARGV_LEN_OFF + r13*4], edx
    inc dword [r12 + CMD_ARGC_OFF]
    mov rdi, rbx
    call advance
    jmp .tail_loop

.redir:
    mov rdi, rbx
    mov rsi, r12
    call parse_redirect
    cmp rax, 1
    jne .fail
    jmp .tail_loop

.background:
    mov dword [r12 + CMD_BACKGROUND_OFF], 1
    mov rdi, rbx
    call advance
    jmp .ok

.ok:
    mov rax, r12
    jmp .ret

.fail:
    xor eax, eax
.ret:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; parse_pipeline(parser) -> rax=PipelineNode* or 0
parse_pipeline:
    push rbx
    push r12
    push r13
    mov rbx, rdi

    mov rdi, rbx
    mov rsi, PIPELINE_NODE_SIZE
    call alloc_node
    test rax, rax
    jz .fail
    mov r12, rax

    mov rdi, r12
    mov rsi, PIPELINE_NODE_SIZE
    call memzero
    mov dword [r12 + PL_TYPE_OFF], NODE_PIPELINE

    mov rdi, rbx
    call parse_command
    test rax, rax
    jz .fail
    mov [r12 + PL_COMMANDS_OFF], rax
    mov dword [r12 + PL_CMD_COUNT_OFF], 1

.pipe_loop:
    mov rdi, rbx
    call peek_token
    test rax, rax
    jz .ok
    cmp dword [rax + TOKEN_TYPE_OFF], TOK_PIPE
    jne .ok

    mov rdi, rbx
    call advance

    mov r13d, dword [r12 + PL_CMD_COUNT_OFF]
    cmp r13d, MAX_COMMANDS
    jb .parse_next
    lea rsi, [rel err_too_many_cmds]
    mov rdi, rbx
    call set_error
    jmp .fail

.parse_next:
    mov rdi, rbx
    call parse_command
    test rax, rax
    jz .fail
    mov [r12 + PL_COMMANDS_OFF + r13*8], rax
    inc dword [r12 + PL_CMD_COUNT_OFF]
    jmp .pipe_loop

.ok:
    mov rax, r12
    jmp .ret

.fail:
    xor eax, eax
.ret:
    pop r13
    pop r12
    pop rbx
    ret

; parse_list(parser) -> rax=ListNode* or 0
parse_list:
    push rbx
    push r12
    push r13
    mov rbx, rdi

    mov rdi, rbx
    mov rsi, LIST_NODE_SIZE
    call alloc_node
    test rax, rax
    jz .fail
    mov r12, rax
    mov rdi, r12
    mov rsi, LIST_NODE_SIZE
    call memzero
    mov dword [r12 + LS_TYPE_OFF], NODE_LIST

    mov rdi, rbx
    call skip_newlines

    mov rdi, rbx
    call peek_token
    test rax, rax
    jz .ok
    cmp dword [rax + TOKEN_TYPE_OFF], TOK_EOF
    je .ok

    mov rdi, rbx
    call parse_pipeline
    test rax, rax
    jz .fail
    mov [r12 + LS_PIPELINES_OFF], rax
    mov dword [r12 + LS_COUNT_OFF], 1

.list_loop:
    mov rdi, rbx
    call peek_token
    test rax, rax
    jz .ok
    mov r13d, dword [rax + TOKEN_TYPE_OFF]
    mov r8d, 0

    cmp r13d, TOK_AND
    jne .check_or
    mov r8d, OP_AND
    jmp .have_op
.check_or:
    cmp r13d, TOK_OR
    jne .check_seq
    mov r8d, OP_OR
    jmp .have_op
.check_seq:
    cmp r13d, TOK_SEMICOLON
    je .seq_op
    cmp r13d, TOK_NEWLINE
    je .seq_op
    jmp .ok
.seq_op:
    mov r8d, OP_SEQ

.have_op:
    mov rdi, rbx
    call advance

    ; collapse extra newlines after any separator
    mov rdi, rbx
    call skip_newlines

    mov rdi, rbx
    call peek_token
    test rax, rax
    jz .eof_after_op
    mov ecx, dword [rax + TOKEN_TYPE_OFF]
    cmp ecx, TOK_EOF
    jne .store_and_parse

    ; trailing ';' or '\n' is accepted, but && / || requires rhs
    cmp r8d, OP_SEQ
    je .ok
    jmp .eof_after_op

.store_and_parse:
    mov ecx, dword [r12 + LS_COUNT_OFF]
    cmp ecx, MAX_LIST_ITEMS
    jb .fit_list
    lea rsi, [rel err_too_many_list_items]
    mov rdi, rbx
    call set_error
    jmp .fail

.fit_list:
    mov dword [r12 + LS_OPERATORS_OFF + rcx*4], r8d
    mov rdi, rbx
    call parse_pipeline
    test rax, rax
    jz .fail
    mov [r12 + LS_PIPELINES_OFF + rcx*8], rax
    inc dword [r12 + LS_COUNT_OFF]
    jmp .list_loop

.eof_after_op:
    lea rsi, [rel err_unexpected_eof]
    mov rdi, rbx
    call set_error
    jmp .fail

.ok:
    mov rax, r12
    jmp .ret
.fail:
    xor eax, eax
.ret:
    pop r13
    pop r12
    pop rbx
    ret

; parser_init(arena_ptr, lexer_ptr) -> rax=parser_ptr or 0
parser_init:
    push rbx
    push r12
    push r13

    test rdi, rdi
    jz .fail
    test rsi, rsi
    jz .fail
    mov r12, rdi
    mov r13, rsi

    mov rdi, r12
    mov rsi, PARSER_STRUCT_SIZE
    call arena_alloc
    test rax, rax
    jz .fail
    mov rbx, rax

    mov [rbx + PS_ARENA_PTR_OFF], r12
    mov [rbx + PS_LEXER_PTR_OFF], r13
    mov qword [rbx + PS_POS_OFF], 0
    mov qword [rbx + PS_ERROR_MSG_OFF], 0

    mov rdi, r13
    call lexer_get_tokens
    test rax, rax
    jz .fail_msg
    mov [rbx + PS_TOKENS_OFF], rax

    mov rdi, r13
    call lexer_get_count
    mov [rbx + PS_TOKEN_COUNT_OFF], rax

    mov rax, rbx
    jmp .ret

.fail_msg:
    lea rdx, [rel err_unexpected_eof]
    mov [rbx + PS_ERROR_MSG_OFF], rdx
    xor eax, eax
    jmp .ret
.fail:
    xor eax, eax
.ret:
    pop r13
    pop r12
    pop rbx
    ret

; parser_parse(parser_ptr) -> rax=root(ListNode*) or 0
parser_parse:
    push rbx
    mov rbx, rdi
    test rbx, rbx
    jz .fail

    mov qword [rbx + PS_POS_OFF], 0
    mov qword [rbx + PS_ERROR_MSG_OFF], 0

    mov rdi, rbx
    call parse_list
    test rax, rax
    jz .fail
    mov r8, rax

    mov rdi, rbx
    call peek_token
    test rax, rax
    jz .ok
    cmp dword [rax + TOKEN_TYPE_OFF], TOK_EOF
    je .ok
    lea rsi, [rel err_unexpected_token]
    mov rdi, rbx
    call set_error
    xor eax, eax
    pop rbx
    ret

.ok:
    mov rax, r8
    pop rbx
    ret
.fail:
    xor eax, eax
    pop rbx
    ret

; parser_get_error(parser_ptr) -> rax=msg ptr or 0
parser_get_error:
    test rdi, rdi
    jz .null
    mov rax, [rdi + PS_ERROR_MSG_OFF]
    ret
.null:
    xor eax, eax
    ret
