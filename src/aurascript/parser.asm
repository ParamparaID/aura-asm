; aurascript parser (MVP)
extern arena_alloc
extern as_lexer_get_tokens
extern as_lexer_get_count

section .text
global as_parser_init
global as_parser_parse
global as_parser_get_error

%define AS_TOK_FN                   1
%define AS_TOK_LET                  2
%define AS_TOK_MUT                  3
%define AS_TOK_IF                   4
%define AS_TOK_ELSE                 5
%define AS_TOK_FOR                  6
%define AS_TOK_WHILE                7
%define AS_TOK_RETURN               9
%define AS_TOK_IN                   11
%define AS_TOK_TRUE                 12
%define AS_TOK_FALSE                13
%define AS_TOK_INT                  20
%define AS_TOK_FLOAT                21
%define AS_TOK_STRING               22
%define AS_TOK_IDENT                23
%define AS_TOK_PLUS                 30
%define AS_TOK_MINUS                31
%define AS_TOK_STAR                 32
%define AS_TOK_SLASH                33
%define AS_TOK_PERCENT              34
%define AS_TOK_EQ                   35
%define AS_TOK_NEQ                  36
%define AS_TOK_LT                   37
%define AS_TOK_GT                   38
%define AS_TOK_LTE                  39
%define AS_TOK_GTE                  40
%define AS_TOK_AND                  41
%define AS_TOK_OR                   42
%define AS_TOK_NOT                  43
%define AS_TOK_ASSIGN               44
%define AS_TOK_ARROW                45
%define AS_TOK_DOTDOT               46
%define AS_TOK_DOLLAR_PAREN         47
%define AS_TOK_LPAREN               50
%define AS_TOK_RPAREN               51
%define AS_TOK_LBRACE               52
%define AS_TOK_RBRACE               53
%define AS_TOK_LBRACKET             54
%define AS_TOK_RBRACKET             55
%define AS_TOK_COMMA                56
%define AS_TOK_COLON                57
%define AS_TOK_SEMICOLON            58
%define AS_TOK_DOT                  59
%define AS_TOK_NEWLINE              60
%define AS_TOK_EOF                  61

%define AST_PROGRAM                 1
%define AST_FN_DECL                 2
%define AST_LET_STMT                3
%define AST_IF_STMT                 4
%define AST_FOR_STMT                5
%define AST_WHILE_STMT              6
%define AST_RETURN_STMT             7
%define AST_BLOCK                   8
%define AST_BINARY_EXPR             9
%define AST_UNARY_EXPR              10
%define AST_CALL_EXPR               11
%define AST_INDEX_EXPR              12
%define AST_FIELD_EXPR              13
%define AST_ASSIGN_EXPR             14
%define AST_IDENT                   15
%define AST_INT_LIT                 16
%define AST_FLOAT_LIT               17
%define AST_STRING_LIT              18
%define AST_BOOL_LIT                19
%define AST_ARRAY_LIT               20
%define AST_MAP_LIT                 21
%define AST_SHELL_CAPTURE           22

%define TOK_TYPE_OFF                0
%define TOK_START_OFF               8
%define TOK_LEN_OFF                 16
%define TOK_LINE_OFF                20
%define TOK_SIZE                    24

%define ND_TYPE_OFF                 0
%define ND_LINE_OFF                 4
%define ND_D0_OFF                   8
%define ND_D1_OFF                   16
%define ND_D2_OFF                   24
%define ND_D3_OFF                   32
%define ND_D4_OFF                   40
%define ND_SIZE                     48

%define PS_ARENA_OFF                0
%define PS_LEXER_OFF                8
%define PS_TOKENS_OFF               16
%define PS_COUNT_OFF                24
%define PS_POS_OFF                  32
%define PS_ERR_OFF                  40
%define PS_SIZE                     48

%define AS_MAX_ITEMS                512
%define AS_MAX_PARAMS               64

section .rodata
    as_perr_alloc      db "as_parser: allocation failed",0
    as_perr_eof        db "as_parser: unexpected eof",0
    as_perr_token      db "as_parser: unexpected token",0
    as_perr_ident      db "as_parser: expected identifier",0
    as_perr_primary    db "as_parser: expected primary",0

section .text

as_p_set_error:
    mov [rdi + PS_ERR_OFF], rsi
    xor eax, eax
    ret

as_p_alloc:
    push rbx
    mov rbx, rdi
    mov rdi, [rbx + PS_ARENA_OFF]
    call arena_alloc
    test rax, rax
    jnz .ok
    lea rsi, [rel as_perr_alloc]
    mov rdi, rbx
    call as_p_set_error
    xor eax, eax
.ok:
    pop rbx
    ret

as_p_peek:
    mov rax, [rdi + PS_POS_OFF]
    cmp rax, [rdi + PS_COUNT_OFF]
    jae .n
    imul rax, TOK_SIZE
    add rax, [rdi + PS_TOKENS_OFF]
    ret
.n:
    xor eax, eax
    ret

as_p_prev:
    mov rax, [rdi + PS_POS_OFF]
    test rax, rax
    jz .n
    dec rax
    imul rax, TOK_SIZE
    add rax, [rdi + PS_TOKENS_OFF]
    ret
.n:
    xor eax, eax
    ret

as_p_advance:
    push rbx
    mov rbx, rdi
    call as_p_peek
    test rax, rax
    jz .ret
    inc qword [rbx + PS_POS_OFF]
.ret:
    pop rbx
    ret

as_p_match:
    push rbx
    mov rbx, rdi
    call as_p_peek
    test rax, rax
    jz .no
    cmp dword [rax + TOK_TYPE_OFF], esi
    jne .no
    mov rdi, rbx
    call as_p_advance
    mov eax, 1
    pop rbx
    ret
.no:
    xor eax, eax
    pop rbx
    ret

as_p_expect:
    push rbx
    mov rbx, rdi
    call as_p_peek
    test rax, rax
    jz .eof
    cmp dword [rax + TOK_TYPE_OFF], esi
    jne .bad
    mov rdi, rbx
    call as_p_advance
    pop rbx
    ret
.eof:
    lea rsi, [rel as_perr_eof]
    mov rdi, rbx
    call as_p_set_error
    xor eax, eax
    pop rbx
    ret
.bad:
    lea rsi, [rel as_perr_token]
    mov rdi, rbx
    call as_p_set_error
    xor eax, eax
    pop rbx
    ret

as_p_skip_sep:
.loop:
    push rdi
    mov esi, AS_TOK_NEWLINE
    call as_p_match
    pop rdi
    cmp eax, 1
    je .loop
    push rdi
    mov esi, AS_TOK_SEMICOLON
    call as_p_match
    pop rdi
    cmp eax, 1
    je .loop
    ret

as_make_node:
    ; (parser rdi, type esi, line edx) -> node*
    push rbx
    push r12
    mov rbx, rdi
    mov r12d, esi
    mov r11d, edx
    mov rdi, rbx
    mov rsi, ND_SIZE
    call as_p_alloc
    test rax, rax
    jz .ret
    mov dword [rax + ND_TYPE_OFF], r12d
    mov dword [rax + ND_LINE_OFF], r11d
    mov qword [rax + ND_D0_OFF], 0
    mov qword [rax + ND_D1_OFF], 0
    mov qword [rax + ND_D2_OFF], 0
    mov qword [rax + ND_D3_OFF], 0
    mov qword [rax + ND_D4_OFF], 0
.ret:
    pop r12
    pop rbx
    ret

as_token_to_u64:
    xor rax, rax
    test esi, esi
    jz .ret
    cmp esi, 2
    jb .dec
    cmp byte [rdi], '0'
    jne .dec
    cmp byte [rdi+1], 'x'
    je .hex
    cmp byte [rdi+1], 'X'
    je .hex
    cmp byte [rdi+1], 'b'
    je .bin
    cmp byte [rdi+1], 'B'
    je .bin
.dec:
    xor ecx, ecx
.d:
    cmp ecx, esi
    jae .ret
    movzx rdx, byte [rdi + rcx]
    sub rdx, '0'
    cmp rdx, 9
    ja .ret
    imul rax, rax, 10
    add rax, rdx
    inc ecx
    jmp .d
.hex:
    mov ecx, 2
.h:
    cmp ecx, esi
    jae .ret
    movzx rdx, byte [rdi + rcx]
    shl rax, 4
    cmp rdx, '0'
    jb .ret
    cmp rdx, '9'
    jbe .hnum
    cmp rdx, 'a'
    jb .hup
    cmp rdx, 'f'
    jbe .hlow
.hup:
    cmp rdx, 'A'
    jb .ret
    cmp rdx, 'F'
    ja .ret
    sub rdx, 'A'
    add rdx, 10
    add rax, rdx
    inc ecx
    jmp .h
.hlow:
    sub rdx, 'a'
    add rdx, 10
    add rax, rdx
    inc ecx
    jmp .h
.hnum:
    sub rdx, '0'
    add rax, rdx
    inc ecx
    jmp .h
.bin:
    mov ecx, 2
.b:
    cmp ecx, esi
    jae .ret
    mov dl, [rdi + rcx]
    shl rax, 1
    cmp dl, '0'
    je .bn
    cmp dl, '1'
    jne .ret
    inc rax
.bn:
    inc ecx
    jmp .b
.ret:
    ret

; ---------- expression parser ----------
; forward: expr -> assignment

as_parse_primary:
    push rbx
    push r12
    push r14
    sub rsp, 8
    mov rbx, rdi
    mov rdi, rbx
    call as_p_peek
    test rax, rax
    jz .bad
    mov r12, rax
    mov ecx, [r12 + TOK_TYPE_OFF]
    mov edx, [r12 + TOK_LINE_OFF]
    cmp ecx, AS_TOK_INT
    jne .p_float
    mov rdi, rbx
    call as_p_advance
    mov rdi, [r12 + TOK_START_OFF]
    mov esi, [r12 + TOK_LEN_OFF]
    call as_token_to_u64
    mov r10, rax
    mov rdi, rbx
    mov esi, AST_INT_LIT
    call as_make_node
    test rax, rax
    jz .ret
    mov [rax + ND_D0_OFF], r10
    jmp .ret
.p_float:
    cmp ecx, AS_TOK_FLOAT
    jne .p_string
    mov rdi, rbx
    call as_p_advance
    mov rdi, rbx
    mov esi, AST_FLOAT_LIT
    call as_make_node
    test rax, rax
    jz .ret
    mov r10, [r12 + TOK_START_OFF]
    mov [rax + ND_D0_OFF], r10
    mov r10d, [r12 + TOK_LEN_OFF]
    mov [rax + ND_D1_OFF], r10
    jmp .ret
.p_string:
    cmp ecx, AS_TOK_STRING
    jne .p_true
    mov rdi, rbx
    call as_p_advance
    mov rdi, rbx
    mov esi, AST_STRING_LIT
    call as_make_node
    test rax, rax
    jz .ret
    mov r10, [r12 + TOK_START_OFF]
    mov [rax + ND_D0_OFF], r10
    mov r10d, [r12 + TOK_LEN_OFF]
    mov [rax + ND_D1_OFF], r10
    jmp .ret
.p_true:
    cmp ecx, AS_TOK_TRUE
    jne .p_false
    mov rdi, rbx
    call as_p_advance
    mov rdi, rbx
    mov esi, AST_BOOL_LIT
    call as_make_node
    test rax, rax
    jz .ret
    mov qword [rax + ND_D0_OFF], 1
    jmp .ret
.p_false:
    cmp ecx, AS_TOK_FALSE
    jne .p_ident
    mov rdi, rbx
    call as_p_advance
    mov rdi, rbx
    mov esi, AST_BOOL_LIT
    call as_make_node
    jmp .ret
.p_ident:
    cmp ecx, AS_TOK_IDENT
    jne .p_paren
    mov rdi, rbx
    call as_p_advance
    mov rdi, rbx
    mov esi, AST_IDENT
    call as_make_node
    test rax, rax
    jz .ret
    mov r10, [r12 + TOK_START_OFF]
    mov [rax + ND_D0_OFF], r10
    mov r10d, [r12 + TOK_LEN_OFF]
    mov [rax + ND_D1_OFF], r10
    jmp .ret
.p_paren:
    cmp ecx, AS_TOK_LPAREN
    jne .p_array
    mov rdi, rbx
    call as_p_advance
    mov rdi, rbx
    call as_parse_expr
    test rax, rax
    jz .ret
    mov r10, rax
    mov rdi, rbx
    mov esi, AS_TOK_RPAREN
    call as_p_expect
    test rax, rax
    jz .bad
    mov rax, r10
    jmp .ret
.p_array:
    cmp ecx, AS_TOK_LBRACKET
    jne .p_map
    mov rdi, rbx
    call as_p_advance
    mov rdi, rbx
    mov esi, AST_ARRAY_LIT
    call as_make_node
    test rax, rax
    jz .ret
    mov [rsp], rax
    mov rdi, rbx
    mov rsi, AS_MAX_ITEMS * 8
    call as_p_alloc
    test rax, rax
    jz .bad
    mov r10, [rsp]
    mov [r10 + ND_D0_OFF], rax
    xor r14d, r14d
    mov rdi, rbx
    mov esi, AS_TOK_RBRACKET
    call as_p_match
    cmp eax, 1
    je .arr_done
.arr_loop:
    mov rdi, rbx
    call as_parse_expr
    test rax, rax
    jz .bad
    mov r10, [rsp]
    mov rdx, [r10 + ND_D0_OFF]
    mov [rdx + r14*8], rax
    inc r14d
    mov rdi, rbx
    mov esi, AS_TOK_COMMA
    call as_p_match
    cmp eax, 1
    jne .arr_expect
    jmp .arr_loop
.arr_expect:
    mov rdi, rbx
    mov esi, AS_TOK_RBRACKET
    call as_p_expect
    test rax, rax
    jz .bad
.arr_done:
    mov r10, [rsp]
    mov [r10 + ND_D1_OFF], r14
    mov rax, r10
    jmp .ret
.p_map:
    cmp ecx, AS_TOK_LBRACE
    jne .p_shell
    mov rdi, rbx
    call as_p_advance
    mov rdi, rbx
    mov esi, AST_MAP_LIT
    call as_make_node
    test rax, rax
    jz .ret
    mov [rsp], rax
    mov rdi, rbx
    mov rsi, AS_MAX_ITEMS * 8
    call as_p_alloc
    test rax, rax
    jz .bad
    mov r10, [rsp]
    mov [r10 + ND_D0_OFF], rax
    mov rdi, rbx
    mov rsi, AS_MAX_ITEMS * 8
    call as_p_alloc
    test rax, rax
    jz .bad
    mov r10, [rsp]
    mov [r10 + ND_D1_OFF], rax
    xor r14d, r14d
    mov rdi, rbx
    mov esi, AS_TOK_RBRACE
    call as_p_match
    cmp eax, 1
    je .map_done
.map_loop:
    mov rdi, rbx
    call as_parse_expr
    test rax, rax
    jz .bad
    mov r10, [rsp]
    mov rdx, [r10 + ND_D0_OFF]
    mov [rdx + r14*8], rax
    mov rdi, rbx
    mov esi, AS_TOK_COLON
    call as_p_expect
    test rax, rax
    jz .bad
    mov rdi, rbx
    call as_parse_expr
    test rax, rax
    jz .bad
    mov r10, [rsp]
    mov rdx, [r10 + ND_D1_OFF]
    mov [rdx + r14*8], rax
    inc r14d
    mov rdi, rbx
    mov esi, AS_TOK_COMMA
    call as_p_match
    cmp eax, 1
    jne .map_expect
    jmp .map_loop
.map_expect:
    mov rdi, rbx
    mov esi, AS_TOK_RBRACE
    call as_p_expect
    test rax, rax
    jz .bad
.map_done:
    mov r10, [rsp]
    mov [r10 + ND_D2_OFF], r14
    mov rax, r10
    jmp .ret
.p_shell:
    cmp ecx, AS_TOK_DOLLAR_PAREN
    jne .bad
    mov rdi, rbx
    call as_p_advance
    mov r8, [r12 + TOK_START_OFF]
    add r8, 2
.sh_scan:
    mov rdi, rbx
    call as_p_peek
    test rax, rax
    jz .bad
    cmp dword [rax + TOK_TYPE_OFF], AS_TOK_RPAREN
    je .sh_done
    cmp dword [rax + TOK_TYPE_OFF], AS_TOK_EOF
    je .bad
    mov rdi, rbx
    call as_p_advance
    jmp .sh_scan
.sh_done:
    mov r9, [rax + TOK_START_OFF]
    mov rdi, rbx
    call as_p_advance
    mov rdi, rbx
    mov esi, AST_SHELL_CAPTURE
    call as_make_node
    test rax, rax
    jz .ret
    mov [rax + ND_D0_OFF], r8
    sub r9, r8
    mov [rax + ND_D1_OFF], r9
    jmp .ret
.bad:
    lea rsi, [rel as_perr_primary]
    mov rdi, rbx
    call as_p_set_error
    xor eax, eax
.ret:
    add rsp, 8
    pop r14
    pop r12
    pop rbx
    ret

as_parse_call:
    push rbx
    push r12
    push r14
    sub rsp, 16
    mov rbx, rdi
    mov rdi, rbx
    call as_parse_primary
    test rax, rax
    jz .fail
    mov [rsp], rax
.loop:
    mov rdi, rbx
    mov esi, AS_TOK_LPAREN
    call as_p_match
    cmp eax, 1
    jne .idx
    mov rdi, rbx
    mov rsi, AS_MAX_ITEMS * 8
    call as_p_alloc
    test rax, rax
    jz .fail
    mov [rsp + 8], rax
    xor r14d, r14d
    mov rdi, rbx
    mov esi, AS_TOK_RPAREN
    call as_p_match
    cmp eax, 1
    je .mk_call
.arg_loop:
    mov rdi, rbx
    call as_parse_expr
    test rax, rax
    jz .fail
    mov r11, [rsp + 8]
    mov [r11 + r14*8], rax
    inc r14d
    mov rdi, rbx
    mov esi, AS_TOK_COMMA
    call as_p_match
    cmp eax, 1
    jne .arg_end
    jmp .arg_loop
.arg_end:
    mov rdi, rbx
    mov esi, AS_TOK_RPAREN
    call as_p_expect
    test rax, rax
    jz .fail
.mk_call:
    mov edx, [rax + TOK_LINE_OFF]
    mov rdi, rbx
    mov esi, AST_CALL_EXPR
    call as_make_node
    test rax, rax
    jz .fail
    mov r10, [rsp]
    mov [rax + ND_D0_OFF], r10
    mov r11, [rsp + 8]
    mov [rax + ND_D1_OFF], r11
    mov [rax + ND_D2_OFF], r14
    mov [rsp], rax
    jmp .loop
.idx:
    mov rdi, rbx
    mov esi, AS_TOK_LBRACKET
    call as_p_match
    cmp eax, 1
    jne .field
    mov rdi, rbx
    call as_parse_expr
    test rax, rax
    jz .fail
    mov r11, rax
    mov rdi, rbx
    mov esi, AS_TOK_RBRACKET
    call as_p_expect
    test rax, rax
    jz .fail
    mov edx, [rax + TOK_LINE_OFF]
    mov rdi, rbx
    mov esi, AST_INDEX_EXPR
    call as_make_node
    test rax, rax
    jz .fail
    mov r10, [rsp]
    mov [rax + ND_D0_OFF], r10
    mov [rax + ND_D1_OFF], r11
    mov [rsp], rax
    jmp .loop
.field:
    mov rdi, rbx
    mov esi, AS_TOK_DOT
    call as_p_match
    cmp eax, 1
    jne .done
    mov rdi, rbx
    mov esi, AS_TOK_IDENT
    call as_p_expect
    test rax, rax
    jz .fail
    mov r11, [rax + TOK_START_OFF]
    mov r9d, [rax + TOK_LEN_OFF]
    mov edx, [rax + TOK_LINE_OFF]
    mov rdi, rbx
    mov esi, AST_FIELD_EXPR
    call as_make_node
    test rax, rax
    jz .fail
    mov r10, [rsp]
    mov [rax + ND_D0_OFF], r10
    mov [rax + ND_D1_OFF], r11
    mov [rax + ND_D2_OFF], r9
    mov [rsp], rax
    jmp .loop
.done:
    mov rax, [rsp]
    add rsp, 16
    pop r14
    pop r12
    pop rbx
    ret
.fail:
    xor eax, eax
    add rsp, 16
    pop r14
    pop r12
    pop rbx
    ret

as_parse_unary:
    push rbx
    mov rbx, rdi
    mov rdi, rbx
    call as_p_peek
    test rax, rax
    jz .fail
    mov ecx, [rax + TOK_TYPE_OFF]
    cmp ecx, AS_TOK_NOT
    je .mk
    cmp ecx, AS_TOK_MINUS
    je .mk
    mov rdi, rbx
    call as_parse_call
    pop rbx
    ret
.mk:
    mov r8d, ecx
    mov edx, [rax + TOK_LINE_OFF]
    mov rdi, rbx
    call as_p_advance
    mov rdi, rbx
    call as_parse_unary
    test rax, rax
    jz .fail
    mov r10, rax
    mov rdi, rbx
    mov esi, AST_UNARY_EXPR
    call as_make_node
    test rax, rax
    jz .fail
    mov [rax + ND_D0_OFF], r8
    mov [rax + ND_D1_OFF], r10
    pop rbx
    ret
.fail:
    xor eax, eax
    pop rbx
    ret

as_bin_loop:
    ; helper not used
    ret

; each level manually
as_parse_mult:
    push rbx
    mov rbx, rdi
    mov rdi, rbx
    call as_parse_unary
    test rax, rax
    jz .fail
    mov r10, rax
.loop:
    mov rdi, rbx
    call as_p_peek
    test rax, rax
    jz .done
    mov ecx, [rax + TOK_TYPE_OFF]
    cmp ecx, AS_TOK_STAR
    je .op
    cmp ecx, AS_TOK_SLASH
    je .op
    cmp ecx, AS_TOK_PERCENT
    jne .done
.op:
    mov r8d, ecx
    mov edx, [rax + TOK_LINE_OFF]
    mov rdi, rbx
    call as_p_advance
    mov rdi, rbx
    call as_parse_unary
    test rax, rax
    jz .fail
    mov r11, rax
    mov rdi, rbx
    mov esi, AST_BINARY_EXPR
    call as_make_node
    test rax, rax
    jz .fail
    mov [rax + ND_D0_OFF], r8
    mov [rax + ND_D1_OFF], r10
    mov [rax + ND_D2_OFF], r11
    mov r10, rax
    jmp .loop
.done:
    mov rax, r10
    pop rbx
    ret
.fail:
    xor eax, eax
    pop rbx
    ret

as_parse_addition:
    push rbx
    mov rbx, rdi
    mov rdi, rbx
    call as_parse_mult
    test rax, rax
    jz .fail
    mov r10, rax
.loop:
    mov rdi, rbx
    call as_p_peek
    test rax, rax
    jz .done
    mov ecx, [rax + TOK_TYPE_OFF]
    cmp ecx, AS_TOK_PLUS
    je .op
    cmp ecx, AS_TOK_MINUS
    jne .done
.op:
    mov r8d, ecx
    mov edx, [rax + TOK_LINE_OFF]
    mov rdi, rbx
    call as_p_advance
    mov rdi, rbx
    call as_parse_mult
    test rax, rax
    jz .fail
    mov r11, rax
    mov rdi, rbx
    mov esi, AST_BINARY_EXPR
    call as_make_node
    test rax, rax
    jz .fail
    mov [rax + ND_D0_OFF], r8
    mov [rax + ND_D1_OFF], r10
    mov [rax + ND_D2_OFF], r11
    mov r10, rax
    jmp .loop
.done:
    mov rax, r10
    pop rbx
    ret
.fail:
    xor eax, eax
    pop rbx
    ret

as_parse_comparison:
    push rbx
    mov rbx, rdi
    mov rdi, rbx
    call as_parse_addition
    test rax, rax
    jz .fail
    mov r10, rax
.loop:
    mov rdi, rbx
    call as_p_peek
    test rax, rax
    jz .done
    mov ecx, [rax + TOK_TYPE_OFF]
    cmp ecx, AS_TOK_LT
    je .op
    cmp ecx, AS_TOK_GT
    je .op
    cmp ecx, AS_TOK_LTE
    je .op
    cmp ecx, AS_TOK_GTE
    je .op
    cmp ecx, AS_TOK_DOTDOT
    jne .done
.op:
    mov r8d, ecx
    mov edx, [rax + TOK_LINE_OFF]
    mov rdi, rbx
    call as_p_advance
    mov rdi, rbx
    call as_parse_addition
    test rax, rax
    jz .fail
    mov r11, rax
    mov rdi, rbx
    mov esi, AST_BINARY_EXPR
    call as_make_node
    test rax, rax
    jz .fail
    mov [rax + ND_D0_OFF], r8
    mov [rax + ND_D1_OFF], r10
    mov [rax + ND_D2_OFF], r11
    mov r10, rax
    jmp .loop
.done:
    mov rax, r10
    pop rbx
    ret
.fail:
    xor eax, eax
    pop rbx
    ret

as_parse_equality:
    push rbx
    mov rbx, rdi
    mov rdi, rbx
    call as_parse_comparison
    test rax, rax
    jz .fail
    mov r10, rax
.loop:
    mov rdi, rbx
    call as_p_peek
    test rax, rax
    jz .done
    mov ecx, [rax + TOK_TYPE_OFF]
    cmp ecx, AS_TOK_EQ
    je .op
    cmp ecx, AS_TOK_NEQ
    jne .done
.op:
    mov r8d, ecx
    mov edx, [rax + TOK_LINE_OFF]
    mov rdi, rbx
    call as_p_advance
    mov rdi, rbx
    call as_parse_comparison
    test rax, rax
    jz .fail
    mov r11, rax
    mov rdi, rbx
    mov esi, AST_BINARY_EXPR
    call as_make_node
    test rax, rax
    jz .fail
    mov [rax + ND_D0_OFF], r8
    mov [rax + ND_D1_OFF], r10
    mov [rax + ND_D2_OFF], r11
    mov r10, rax
    jmp .loop
.done:
    mov rax, r10
    pop rbx
    ret
.fail:
    xor eax, eax
    pop rbx
    ret

as_parse_and:
    push rbx
    mov rbx, rdi
    mov rdi, rbx
    call as_parse_equality
    test rax, rax
    jz .fail
    mov r10, rax
.loop:
    mov rdi, rbx
    call as_p_peek
    test rax, rax
    jz .done
    cmp dword [rax + TOK_TYPE_OFF], AS_TOK_AND
    jne .done
    mov r8d, AS_TOK_AND
    mov edx, [rax + TOK_LINE_OFF]
    mov rdi, rbx
    call as_p_advance
    mov rdi, rbx
    call as_parse_equality
    test rax, rax
    jz .fail
    mov r11, rax
    mov rdi, rbx
    mov esi, AST_BINARY_EXPR
    call as_make_node
    test rax, rax
    jz .fail
    mov [rax + ND_D0_OFF], r8
    mov [rax + ND_D1_OFF], r10
    mov [rax + ND_D2_OFF], r11
    mov r10, rax
    jmp .loop
.done:
    mov rax, r10
    pop rbx
    ret
.fail:
    xor eax, eax
    pop rbx
    ret

as_parse_or:
    push rbx
    mov rbx, rdi
    mov rdi, rbx
    call as_parse_and
    test rax, rax
    jz .fail
    mov r10, rax
.loop:
    mov rdi, rbx
    call as_p_peek
    test rax, rax
    jz .done
    cmp dword [rax + TOK_TYPE_OFF], AS_TOK_OR
    jne .done
    mov r8d, AS_TOK_OR
    mov edx, [rax + TOK_LINE_OFF]
    mov rdi, rbx
    call as_p_advance
    mov rdi, rbx
    call as_parse_and
    test rax, rax
    jz .fail
    mov r11, rax
    mov rdi, rbx
    mov esi, AST_BINARY_EXPR
    call as_make_node
    test rax, rax
    jz .fail
    mov [rax + ND_D0_OFF], r8
    mov [rax + ND_D1_OFF], r10
    mov [rax + ND_D2_OFF], r11
    mov r10, rax
    jmp .loop
.done:
    mov rax, r10
    pop rbx
    ret
.fail:
    xor eax, eax
    pop rbx
    ret

as_parse_assignment:
    push rbx
    mov rbx, rdi
    mov rdi, rbx
    call as_parse_or
    test rax, rax
    jz .fail
    mov r10, rax
    mov rdi, rbx
    mov esi, AS_TOK_ASSIGN
    call as_p_match
    cmp eax, 1
    jne .ok
    cmp dword [r10 + ND_TYPE_OFF], AST_IDENT
    jne .fail
    mov rdi, rbx
    call as_p_prev
    mov edx, [rax + TOK_LINE_OFF]
    mov rdi, rbx
    call as_parse_assignment
    test rax, rax
    jz .fail
    mov r11, rax
    mov rdi, rbx
    mov esi, AST_ASSIGN_EXPR
    call as_make_node
    test rax, rax
    jz .fail
    mov [rax + ND_D0_OFF], r10
    mov [rax + ND_D1_OFF], r11
    pop rbx
    ret
.ok:
    mov rax, r10
    pop rbx
    ret
.fail:
    xor eax, eax
    pop rbx
    ret

as_parse_expr:
    jmp as_parse_assignment

; ---------- statements ----------
as_parse_type:
    ; consume simple type grammar
    push rbx
    mov rbx, rdi
    mov rdi, rbx
    call as_p_peek
    test rax, rax
    jz .no
    mov ecx, [rax + TOK_TYPE_OFF]
    cmp ecx, AS_TOK_IDENT
    je .id
    cmp ecx, AS_TOK_LBRACKET
    je .arr
    cmp ecx, AS_TOK_LBRACE
    je .map
    jmp .no
.id:
    mov rdi, rbx
    call as_p_advance
    mov eax, 1
    pop rbx
    ret
.arr:
    mov rdi, rbx
    mov esi, AS_TOK_LBRACKET
    call as_p_expect
    test rax, rax
    jz .no
    mov rdi, rbx
    call as_parse_type
    cmp eax, 1
    jne .no
    mov rdi, rbx
    mov esi, AS_TOK_RBRACKET
    call as_p_expect
    test rax, rax
    jz .no
    mov eax, 1
    pop rbx
    ret
.map:
    mov rdi, rbx
    mov esi, AS_TOK_LBRACE
    call as_p_expect
    test rax, rax
    jz .no
    mov rdi, rbx
    call as_parse_type
    cmp eax, 1
    jne .no
    mov rdi, rbx
    mov esi, AS_TOK_COLON
    call as_p_expect
    test rax, rax
    jz .no
    mov rdi, rbx
    call as_parse_type
    cmp eax, 1
    jne .no
    mov rdi, rbx
    mov esi, AS_TOK_RBRACE
    call as_p_expect
    test rax, rax
    jz .no
    mov eax, 1
    pop rbx
    ret
.no:
    xor eax, eax
    pop rbx
    ret

as_parse_block:
    push rbx
    push r14
    sub rsp, 8
    mov rbx, rdi
    mov rdi, rbx
    mov esi, AS_TOK_LBRACE
    call as_p_expect
    test rax, rax
    jz .fail
    mov edx, [rax + TOK_LINE_OFF]
    mov rdi, rbx
    mov esi, AST_BLOCK
    call as_make_node
    test rax, rax
    jz .fail
    mov [rsp], rax
    mov rdi, rbx
    mov rsi, AS_MAX_ITEMS * 8
    call as_p_alloc
    test rax, rax
    jz .fail
    mov r10, [rsp]
    mov [r10 + ND_D0_OFF], rax
    xor r14d, r14d
.loop:
    mov rdi, rbx
    call as_p_skip_sep
    mov rdi, rbx
    call as_p_peek
    test rax, rax
    jz .fail
    cmp dword [rax + TOK_TYPE_OFF], AS_TOK_RBRACE
    je .done
    cmp dword [rax + TOK_TYPE_OFF], AS_TOK_EOF
    je .fail
    mov rdi, rbx
    call as_parse_statement
    test rax, rax
    jz .fail
    mov r10, [rsp]
    mov rdx, [r10 + ND_D0_OFF]
    mov [rdx + r14*8], rax
    inc r14d
    cmp r14d, AS_MAX_ITEMS
    jb .loop
    jmp .fail
.done:
    mov r10, [rsp]
    mov [r10 + ND_D1_OFF], r14
    mov rdi, rbx
    mov esi, AS_TOK_RBRACE
    call as_p_expect
    test rax, rax
    jz .fail
    mov rax, [rsp]
    add rsp, 8
    pop r14
    pop rbx
    ret
.fail:
    xor eax, eax
    add rsp, 8
    pop r14
    pop rbx
    ret

as_parse_fn_decl:
    push rbx
    push r13
    push r14
    sub rsp, 32
    mov rbx, rdi
    mov rdi, rbx
    mov esi, AS_TOK_FN
    call as_p_expect
    test rax, rax
    jz .fail
    mov r13d, [rax + TOK_LINE_OFF]
    mov rdi, rbx
    mov esi, AS_TOK_IDENT
    call as_p_expect
    test rax, rax
    jz .ident_fail
    mov r10, [rax + TOK_START_OFF]
    mov r11d, [rax + TOK_LEN_OFF]
    mov [rsp + 8], r10
    mov [rsp + 16], r11
    mov rdi, rbx
    mov esi, AS_TOK_LPAREN
    call as_p_expect
    test rax, rax
    jz .fail
    mov rdi, rbx
    mov rsi, AS_MAX_PARAMS * 24
    call as_p_alloc
    test rax, rax
    jz .fail
    mov [rsp], rax
    xor r14d, r14d
    mov rdi, rbx
    mov esi, AS_TOK_RPAREN
    call as_p_match
    cmp eax, 1
    je .params_done
.param_loop:
    mov rdi, rbx
    mov esi, AS_TOK_IDENT
    call as_p_expect
    test rax, rax
    jz .fail
    mov rdx, r14
    imul rdx, 24
    mov r8, [rax + TOK_START_OFF]
    mov r10, [rsp]
    mov [r10 + rdx], r8
    mov r8d, [rax + TOK_LEN_OFF]
    mov dword [r10 + rdx + 8], r8d
    mov rdi, rbx
    mov esi, AS_TOK_COLON
    call as_p_expect
    test rax, rax
    jz .fail
    mov rdi, rbx
    call as_parse_type
    cmp eax, 1
    jne .fail
    inc r14d
    cmp r14d, AS_MAX_PARAMS
    jae .fail
    mov rdi, rbx
    mov esi, AS_TOK_COMMA
    call as_p_match
    cmp eax, 1
    je .param_loop
    mov rdi, rbx
    mov esi, AS_TOK_RPAREN
    call as_p_expect
    test rax, rax
    jz .fail
.params_done:
    mov rdi, rbx
    mov esi, AS_TOK_ARROW
    call as_p_match
    cmp eax, 1
    jne .body
    mov rdi, rbx
    call as_parse_type
    cmp eax, 1
    jne .fail
.body:
    mov rdi, rbx
    call as_parse_block
    test rax, rax
    jz .fail
    mov [rsp + 24], rax
    mov rdi, rbx
    mov esi, AST_FN_DECL
    mov edx, r13d
    call as_make_node
    test rax, rax
    jz .fail
    mov r10, [rsp + 8]
    mov [rax + ND_D0_OFF], r10
    mov r11, [rsp + 16]
    mov [rax + ND_D1_OFF], r11
    mov r10, [rsp]
    mov [rax + ND_D2_OFF], r10
    mov [rax + ND_D3_OFF], r14
    mov r8, [rsp + 24]
    mov [rax + ND_D4_OFF], r8
    add rsp, 32
    pop r14
    pop r13
    pop rbx
    ret
.ident_fail:
    lea rsi, [rel as_perr_ident]
    mov rdi, rbx
    call as_p_set_error
.fail:
    xor eax, eax
    add rsp, 32
    pop r14
    pop r13
    pop rbx
    ret

as_parse_let:
    push rbx
    sub rsp, 40
    mov rbx, rdi
    mov rdi, rbx
    mov esi, AS_TOK_LET
    call as_p_expect
    test rax, rax
    jz .fail
    mov r9d, [rax + TOK_LINE_OFF]
    mov dword [rsp + 32], r9d
    xor r8d, r8d
    mov rdi, rbx
    mov esi, AS_TOK_MUT
    call as_p_match
    cmp eax, 1
    jne .name
    mov r8d, 1
.name:
    mov rdi, rbx
    mov esi, AS_TOK_IDENT
    call as_p_expect
    test rax, rax
    jz .fail
    mov r10, [rax + TOK_START_OFF]
    mov [rsp], r10
    mov r11d, [rax + TOK_LEN_OFF]
    mov [rsp + 8], r11
    mov [rsp + 16], r8
    mov qword [rsp + 24], 0
    mov rdi, rbx
    mov esi, AS_TOK_ASSIGN
    call as_p_match
    cmp eax, 1
    jne .mk
    mov rdi, rbx
    call as_parse_expr
    test rax, rax
    jz .fail
    mov [rsp + 24], rax
.mk:
    mov rdi, rbx
    mov esi, AST_LET_STMT
    mov edx, [rsp + 32]
    call as_make_node
    test rax, rax
    jz .fail
    mov r10, [rsp]
    mov [rax + ND_D0_OFF], r10
    mov r11, [rsp + 8]
    mov [rax + ND_D1_OFF], r11
    mov r8, [rsp + 16]
    mov [rax + ND_D2_OFF], r8
    mov r12, [rsp + 24]
    mov [rax + ND_D3_OFF], r12
    add rsp, 40
    pop rbx
    ret
.fail:
    xor eax, eax
    add rsp, 40
    pop rbx
    ret

as_parse_if:
    push rbx
    sub rsp, 32
    mov rbx, rdi
    mov rdi, rbx
    mov esi, AS_TOK_IF
    call as_p_expect
    test rax, rax
    jz .fail
    mov r9d, [rax + TOK_LINE_OFF]
    mov dword [rsp + 24], r9d
    mov rdi, rbx
    call as_parse_expr
    test rax, rax
    jz .fail
    mov [rsp], rax
    mov rdi, rbx
    call as_parse_block
    test rax, rax
    jz .fail
    mov [rsp + 8], rax
    mov qword [rsp + 16], 0
    mov rdi, rbx
    mov esi, AS_TOK_ELSE
    call as_p_match
    cmp eax, 1
    jne .mk
    mov rdi, rbx
    call as_p_peek
    test rax, rax
    jz .fail
    cmp dword [rax + TOK_TYPE_OFF], AS_TOK_IF
    jne .else_blk
    mov rdi, rbx
    call as_parse_if
    test rax, rax
    jz .fail
    mov [rsp + 16], rax
    jmp .mk
.else_blk:
    mov rdi, rbx
    call as_parse_block
    test rax, rax
    jz .fail
    mov [rsp + 16], rax
.mk:
    mov rdi, rbx
    mov esi, AST_IF_STMT
    mov edx, [rsp + 24]
    call as_make_node
    test rax, rax
    jz .fail
    mov r10, [rsp]
    mov [rax + ND_D0_OFF], r10
    mov r11, [rsp + 8]
    mov [rax + ND_D1_OFF], r11
    mov r12, [rsp + 16]
    mov [rax + ND_D2_OFF], r12
    add rsp, 32
    pop rbx
    ret
.fail:
    xor eax, eax
    add rsp, 32
    pop rbx
    ret

as_parse_for:
    push rbx
    sub rsp, 40
    mov rbx, rdi
    mov rdi, rbx
    mov esi, AS_TOK_FOR
    call as_p_expect
    test rax, rax
    jz .fail
    mov r9d, [rax + TOK_LINE_OFF]
    mov dword [rsp + 32], r9d
    mov rdi, rbx
    mov esi, AS_TOK_IDENT
    call as_p_expect
    test rax, rax
    jz .fail
    mov r10, [rax + TOK_START_OFF]
    mov r11d, [rax + TOK_LEN_OFF]
    mov [rsp], r10
    mov [rsp + 8], r11
    mov rdi, rbx
    mov esi, AS_TOK_IN
    call as_p_expect
    test rax, rax
    jz .fail
    mov rdi, rbx
    call as_parse_expr
    test rax, rax
    jz .fail
    mov [rsp + 16], rax
    mov rdi, rbx
    call as_parse_block
    test rax, rax
    jz .fail
    mov [rsp + 24], rax
    mov rdi, rbx
    mov esi, AST_FOR_STMT
    mov edx, [rsp + 32]
    call as_make_node
    test rax, rax
    jz .fail
    mov r10, [rsp]
    mov [rax + ND_D0_OFF], r10
    mov r11, [rsp + 8]
    mov [rax + ND_D1_OFF], r11
    mov r12, [rsp + 16]
    mov [rax + ND_D2_OFF], r12
    mov r8, [rsp + 24]
    mov [rax + ND_D3_OFF], r8
    add rsp, 40
    pop rbx
    ret
.fail:
    xor eax, eax
    add rsp, 40
    pop rbx
    ret

as_parse_while:
    push rbx
    sub rsp, 24
    mov rbx, rdi
    mov rdi, rbx
    mov esi, AS_TOK_WHILE
    call as_p_expect
    test rax, rax
    jz .fail
    mov r9d, [rax + TOK_LINE_OFF]
    mov dword [rsp + 16], r9d
    mov rdi, rbx
    call as_parse_expr
    test rax, rax
    jz .fail
    mov [rsp], rax
    mov rdi, rbx
    call as_parse_block
    test rax, rax
    jz .fail
    mov [rsp + 8], rax
    mov rdi, rbx
    mov esi, AST_WHILE_STMT
    mov edx, [rsp + 16]
    call as_make_node
    test rax, rax
    jz .fail
    mov r10, [rsp]
    mov [rax + ND_D0_OFF], r10
    mov r11, [rsp + 8]
    mov [rax + ND_D1_OFF], r11
    add rsp, 24
    pop rbx
    ret
.fail:
    xor eax, eax
    add rsp, 24
    pop rbx
    ret

as_parse_return:
    push rbx
    sub rsp, 16
    mov rbx, rdi
    mov rdi, rbx
    mov esi, AS_TOK_RETURN
    call as_p_expect
    test rax, rax
    jz .fail
    mov r9d, [rax + TOK_LINE_OFF]
    mov dword [rsp + 8], r9d
    mov qword [rsp], 0
    mov rdi, rbx
    call as_p_peek
    test rax, rax
    jz .mk
    mov ecx, [rax + TOK_TYPE_OFF]
    cmp ecx, AS_TOK_NEWLINE
    je .mk
    cmp ecx, AS_TOK_SEMICOLON
    je .mk
    cmp ecx, AS_TOK_RBRACE
    je .mk
    cmp ecx, AS_TOK_EOF
    je .mk
    mov rdi, rbx
    call as_parse_expr
    test rax, rax
    jz .fail
    mov [rsp], rax
.mk:
    mov rdi, rbx
    mov esi, AST_RETURN_STMT
    mov edx, [rsp + 8]
    call as_make_node
    test rax, rax
    jz .fail
    mov r10, [rsp]
    mov [rax + ND_D0_OFF], r10
    add rsp, 16
    pop rbx
    ret
.fail:
    xor eax, eax
    add rsp, 16
    pop rbx
    ret

as_parse_statement:
    push rbx
    mov rbx, rdi
    mov rdi, rbx
    call as_p_skip_sep
    mov rdi, rbx
    call as_p_peek
    test rax, rax
    jz .fail
    mov ecx, [rax + TOK_TYPE_OFF]
    cmp ecx, AS_TOK_LET
    jne .s_if
    mov rdi, rbx
    call as_parse_let
    pop rbx
    ret
.s_if:
    cmp ecx, AS_TOK_IF
    jne .s_for
    mov rdi, rbx
    call as_parse_if
    pop rbx
    ret
.s_for:
    cmp ecx, AS_TOK_FOR
    jne .s_while
    mov rdi, rbx
    call as_parse_for
    pop rbx
    ret
.s_while:
    cmp ecx, AS_TOK_WHILE
    jne .s_ret
    mov rdi, rbx
    call as_parse_while
    pop rbx
    ret
.s_ret:
    cmp ecx, AS_TOK_RETURN
    jne .s_block
    mov rdi, rbx
    call as_parse_return
    pop rbx
    ret
.s_block:
    cmp ecx, AS_TOK_LBRACE
    jne .s_expr
    mov rdi, rbx
    call as_parse_block
    pop rbx
    ret
.s_expr:
    mov rdi, rbx
    call as_parse_expr
    pop rbx
    ret
.fail:
    xor eax, eax
    pop rbx
    ret

as_parse_program:
    push rbx
    push r14
    sub rsp, 8
    mov rbx, rdi
    mov rdi, rbx
    mov esi, AST_PROGRAM
    mov edx, 1
    call as_make_node
    test rax, rax
    jz .fail
    mov [rsp], rax
    mov rdi, rbx
    mov rsi, AS_MAX_ITEMS * 8
    call as_p_alloc
    test rax, rax
    jz .fail
    mov r10, [rsp]
    mov [r10 + ND_D0_OFF], rax
    xor r14d, r14d
.loop:
    mov rdi, rbx
    call as_p_skip_sep
    mov rdi, rbx
    call as_p_peek
    test rax, rax
    jz .done
    cmp dword [rax + TOK_TYPE_OFF], AS_TOK_EOF
    je .done
    cmp dword [rax + TOK_TYPE_OFF], AS_TOK_FN
    jne .stmt
    mov rdi, rbx
    call as_parse_fn_decl
    test rax, rax
    jz .fail
    jmp .store
.stmt:
    mov rdi, rbx
    call as_parse_statement
    test rax, rax
    jz .fail
.store:
    mov r10, [rsp]
    mov rdx, [r10 + ND_D0_OFF]
    mov [rdx + r14*8], rax
    inc r14d
    cmp r14d, AS_MAX_ITEMS
    jb .loop
    jmp .fail
.done:
    mov r10, [rsp]
    mov [r10 + ND_D1_OFF], r14
    mov rax, r10
    add rsp, 8
    pop r14
    pop rbx
    ret
.fail:
    xor eax, eax
    add rsp, 8
    pop r14
    pop rbx
    ret

as_parser_init:
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12, rsi
    test rbx, rbx
    jz .fail
    test r12, r12
    jz .fail
    mov rdi, rbx
    mov rsi, PS_SIZE
    call arena_alloc
    test rax, rax
    jz .fail
    mov r13, rax
    mov [r13 + PS_ARENA_OFF], rbx
    mov [r13 + PS_LEXER_OFF], r12
    mov qword [r13 + PS_POS_OFF], 0
    mov qword [r13 + PS_ERR_OFF], 0
    mov rdi, r12
    call as_lexer_get_tokens
    test rax, rax
    jz .fail
    mov [r13 + PS_TOKENS_OFF], rax
    mov rdi, r12
    call as_lexer_get_count
    mov [r13 + PS_COUNT_OFF], rax
    mov rax, r13
    pop r13
    pop r12
    pop rbx
    ret
.fail:
    xor eax, eax
    pop r13
    pop r12
    pop rbx
    ret

as_parser_parse:
    push rbx
    mov rbx, rdi
    test rbx, rbx
    jz .fail
    mov qword [rbx + PS_POS_OFF], 0
    mov qword [rbx + PS_ERR_OFF], 0
    mov rdi, rbx
    call as_parse_program
    pop rbx
    ret
.fail:
    xor eax, eax
    pop rbx
    ret

as_parser_get_error:
    test rdi, rdi
    jz .n
    mov rax, [rdi + PS_ERR_OFF]
    ret
.n:
    xor eax, eax
    ret
