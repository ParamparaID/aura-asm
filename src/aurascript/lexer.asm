; aurascript lexer (MVP)
extern arena_alloc

section .text
global as_lexer_init
global as_lexer_tokenize
global as_lexer_get_tokens
global as_lexer_get_count
global as_lexer_get_error

; token types
%define AS_TOK_FN                   1
%define AS_TOK_LET                  2
%define AS_TOK_MUT                  3
%define AS_TOK_IF                   4
%define AS_TOK_ELSE                 5
%define AS_TOK_FOR                  6
%define AS_TOK_WHILE                7
%define AS_TOK_MATCH                8
%define AS_TOK_RETURN               9
%define AS_TOK_IMPORT               10
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
%define AS_TOK_ERROR                62

; ASToken (24 bytes)
%define TOK_TYPE_OFF                0
%define TOK_START_OFF               8
%define TOK_LEN_OFF                 16
%define TOK_LINE_OFF                20
%define TOK_SIZE                    24

; lexer layout
%define LX_ARENA_OFF                0
%define LX_INPUT_OFF                8
%define LX_INPUT_LEN_OFF            16
%define LX_POS_OFF                  24
%define LX_TOKENS_OFF               32
%define LX_COUNT_OFF                40
%define LX_CAP_OFF                  48
%define LX_LINE_OFF                 56
%define LX_ERR_OFF                  64
%define LX_SIZE                     72

%define AS_LEXER_TOKEN_CAP          4096

section .rodata
    as_err_alloc_lexer      db "as_lexer: alloc lexer failed",0
    as_err_alloc_tokens     db "as_lexer: alloc tokens failed",0
    as_err_too_many_tokens  db "as_lexer: too many tokens",0
    as_err_unclosed_string  db "as_lexer: unclosed string",0
    as_err_bad_token        db "as_lexer: invalid token",0

section .text

as_set_error:
    mov [rdi + LX_ERR_OFF], rsi
    mov eax, -1
    ret

as_emit_token:
    ; (lexer rdi, type esi, start rdx, len ecx)
    push rbx
    mov rbx, rdi
    mov rax, [rbx + LX_COUNT_OFF]
    cmp rax, [rbx + LX_CAP_OFF]
    jb .ok
    lea rsi, [rel as_err_too_many_tokens]
    mov rdi, rbx
    call as_set_error
    pop rbx
    ret
.ok:
    mov r8, [rbx + LX_TOKENS_OFF]
    imul r9, rax, TOK_SIZE
    add r8, r9
    mov dword [r8 + TOK_TYPE_OFF], esi
    mov [r8 + TOK_START_OFF], rdx
    mov dword [r8 + TOK_LEN_OFF], ecx
    mov eax, [rbx + LX_LINE_OFF]
    mov [r8 + TOK_LINE_OFF], eax
    inc qword [rbx + LX_COUNT_OFF]
    xor eax, eax
    pop rbx
    ret

as_ident_char:
    ; al -> eax 1/0
    cmp al, '_'
    je .yes
    cmp al, '0'
    jb .alpha
    cmp al, '9'
    jbe .yes
.alpha:
    cmp al, 'A'
    jb .no
    cmp al, 'Z'
    jbe .yes
    cmp al, 'a'
    jb .no
    cmp al, 'z'
    ja .no
.yes:
    mov eax, 1
    ret
.no:
    xor eax, eax
    ret

as_first_ident_char:
    cmp al, '_'
    je .yes
    cmp al, 'A'
    jb .no
    cmp al, 'Z'
    jbe .yes
    cmp al, 'a'
    jb .no
    cmp al, 'z'
    ja .no
.yes:
    mov eax, 1
    ret
.no:
    xor eax, eax
    ret

as_kw_type:
    ; (ptr rdi, len esi) -> eax token type or AS_TOK_IDENT
    mov eax, AS_TOK_IDENT
    cmp esi, 2
    jne .l3
    cmp byte [rdi], 'f'
    jne .chk_in
    cmp byte [rdi+1], 'n'
    jne .chk_in
    mov eax, AS_TOK_FN
    ret
.chk_in:
    cmp byte [rdi], 'i'
    jne .chk_if2
    cmp byte [rdi+1], 'n'
    jne .chk_if2
    mov eax, AS_TOK_IN
    ret
.chk_if2:
    cmp byte [rdi], 'i'
    jne .l3
    cmp byte [rdi+1], 'f'
    jne .l3
    mov eax, AS_TOK_IF
    ret
.l3:
    cmp esi, 3
    jne .l4
    cmp byte [rdi], 'l'
    jne .chk_mut
    cmp byte [rdi+1], 'e'
    jne .chk_mut
    cmp byte [rdi+2], 't'
    jne .chk_mut
    mov eax, AS_TOK_LET
    ret
.chk_mut:
    cmp byte [rdi], 'm'
    jne .chk_if
    cmp byte [rdi+1], 'u'
    jne .chk_if
    cmp byte [rdi+2], 't'
    jne .chk_if
    mov eax, AS_TOK_MUT
    ret
.chk_if:
    cmp byte [rdi], 'f'
    jne .l4
    cmp byte [rdi+1], 'o'
    jne .l4
    cmp byte [rdi+2], 'r'
    jne .l4
    mov eax, AS_TOK_FOR
    ret
.l4:
    cmp esi, 4
    jne .l5
    cmp byte [rdi], 'e'
    jne .chk_for
    cmp byte [rdi+1], 'l'
    jne .chk_for
    cmp byte [rdi+2], 's'
    jne .chk_for
    cmp byte [rdi+3], 'e'
    jne .chk_for
    mov eax, AS_TOK_ELSE
    ret
.chk_for:
    jmp .chk_true
.chk_true:
    cmp byte [rdi], 't'
    jne .l5
    cmp byte [rdi+1], 'r'
    jne .l5
    cmp byte [rdi+2], 'u'
    jne .l5
    cmp byte [rdi+3], 'e'
    jne .l5
    mov eax, AS_TOK_TRUE
    ret
.l5:
    cmp esi, 5
    jne .l6
    cmp byte [rdi], 'w'
    jne .chk_match
    cmp byte [rdi+1], 'h'
    jne .chk_match
    cmp byte [rdi+2], 'i'
    jne .chk_match
    cmp byte [rdi+3], 'l'
    jne .chk_match
    cmp byte [rdi+4], 'e'
    jne .chk_match
    mov eax, AS_TOK_WHILE
    ret
.chk_match:
    cmp byte [rdi], 'm'
    jne .l6
    cmp byte [rdi+1], 'a'
    jne .l6
    cmp byte [rdi+2], 't'
    jne .l6
    cmp byte [rdi+3], 'c'
    jne .l6
    cmp byte [rdi+4], 'h'
    jne .l6
    mov eax, AS_TOK_MATCH
    ret
.l6:
    cmp esi, 6
    jne .l7
    cmp byte [rdi], 'i'
    jne .l7
    cmp byte [rdi+1], 'm'
    jne .l7
    cmp byte [rdi+2], 'p'
    jne .l7
    cmp byte [rdi+3], 'o'
    jne .l7
    cmp byte [rdi+4], 'r'
    jne .l7
    cmp byte [rdi+5], 't'
    jne .l7
    mov eax, AS_TOK_IMPORT
    ret
.l7:
    cmp esi, 7
    jne .ret
    cmp byte [rdi], 'r'
    jne .chk_false
    cmp byte [rdi+1], 'e'
    jne .chk_false
    cmp byte [rdi+2], 't'
    jne .chk_false
    cmp byte [rdi+3], 'u'
    jne .chk_false
    cmp byte [rdi+4], 'r'
    jne .chk_false
    cmp byte [rdi+5], 'n'
    jne .chk_false
    mov eax, AS_TOK_RETURN
    ret
.chk_false:
    cmp byte [rdi], 'f'
    jne .ret
    cmp byte [rdi+1], 'a'
    jne .ret
    cmp byte [rdi+2], 'l'
    jne .ret
    cmp byte [rdi+3], 's'
    jne .ret
    cmp byte [rdi+4], 'e'
    jne .ret
    mov eax, AS_TOK_FALSE
.ret:
    ret

as_lexer_init:
    ; (arena rdi, input rsi, len rdx) -> lexer*
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    test rdi, rdi
    jz .fail
    test rsi, rsi
    jz .fail
    mov rdi, rbx
    mov rsi, LX_SIZE
    call arena_alloc
    test rax, rax
    jz .fail
    mov r14, rax
    mov rdi, rbx
    mov rsi, AS_LEXER_TOKEN_CAP * TOK_SIZE
    call arena_alloc
    test rax, rax
    jz .fail
    mov [r14 + LX_ARENA_OFF], rbx
    mov [r14 + LX_INPUT_OFF], r12
    mov [r14 + LX_INPUT_LEN_OFF], r13
    mov qword [r14 + LX_POS_OFF], 0
    mov [r14 + LX_TOKENS_OFF], rax
    mov qword [r14 + LX_COUNT_OFF], 0
    mov qword [r14 + LX_CAP_OFF], AS_LEXER_TOKEN_CAP
    mov dword [r14 + LX_LINE_OFF], 1
    mov qword [r14 + LX_ERR_OFF], 0
    mov rax, r14
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.fail:
    xor eax, eax
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

as_lexer_tokenize:
    ; (lexer rdi) -> 0/-1
    push rbx
    mov rbx, rdi
    test rbx, rbx
    jz .fail
    mov qword [rbx + LX_POS_OFF], 0
    mov qword [rbx + LX_COUNT_OFF], 0
    mov dword [rbx + LX_LINE_OFF], 1
    mov qword [rbx + LX_ERR_OFF], 0
.loop:
    mov r8, [rbx + LX_POS_OFF]
    cmp r8, [rbx + LX_INPUT_LEN_OFF]
    jae .emit_eof
    mov r9, [rbx + LX_INPUT_OFF]
    mov al, [r9 + r8]
    cmp al, ' '
    je .sp
    cmp al, 9
    je .sp
    cmp al, 13
    je .sp
    cmp al, 10
    je .nl
    cmp al, '/'
    jne .non_comment
    lea rcx, [r8 + 1]
    cmp rcx, [rbx + LX_INPUT_LEN_OFF]
    jae .non_comment
    cmp byte [r9 + rcx], '/'
    jne .non_comment
    add r8, 2
.cmt:
    cmp r8, [rbx + LX_INPUT_LEN_OFF]
    jae .setpos
    cmp byte [r9 + r8], 10
    je .setpos
    inc r8
    jmp .cmt
.setpos:
    mov [rbx + LX_POS_OFF], r8
    jmp .loop
.sp:
    inc qword [rbx + LX_POS_OFF]
    jmp .loop
.nl:
    lea rdx, [r9 + r8]
    mov rdi, rbx
    mov esi, AS_TOK_NEWLINE
    mov ecx, 1
    call as_emit_token
    cmp eax, 0
    jne .ret
    inc qword [rbx + LX_POS_OFF]
    inc dword [rbx + LX_LINE_OFF]
    jmp .loop
.non_comment:
    ; identifiers/keywords
    mov al, [r9 + r8]
    call as_first_ident_char
    cmp eax, 1
    jne .number
    mov r10, r8
.id_scan:
    inc r8
    cmp r8, [rbx + LX_INPUT_LEN_OFF]
    jae .id_done
    mov al, [r9 + r8]
    call as_ident_char
    cmp eax, 1
    je .id_scan
.id_done:
    mov [rbx + LX_POS_OFF], r8
    lea rdi, [r9 + r10]
    mov esi, r8d
    sub esi, r10d
    call as_kw_type
    mov r11d, eax
    mov rdi, rbx
    mov esi, r11d
    lea rdx, [r9 + r10]
    mov ecx, r8d
    sub ecx, r10d
    call as_emit_token
    cmp eax, 0
    jne .ret
    jmp .loop
.number:
    mov al, [r9 + r8]
    cmp al, '0'
    jb .string
    cmp al, '9'
    ja .string
    mov r10, r8
    xor r11d, r11d
    ; hex/bin prefixes
    cmp byte [r9 + r8], '0'
    jne .num_scan
    lea rcx, [r8 + 1]
    cmp rcx, [rbx + LX_INPUT_LEN_OFF]
    jae .num_scan
    mov al, [r9 + rcx]
    cmp al, 'x'
    je .hex
    cmp al, 'X'
    je .hex
    cmp al, 'b'
    je .bin
    cmp al, 'B'
    je .bin
    jmp .num_scan
.hex:
    add r8, 2
.hex_loop:
    cmp r8, [rbx + LX_INPUT_LEN_OFF]
    jae .num_done_int
    mov al, [r9 + r8]
    cmp al, '0'
    jb .h1
    cmp al, '9'
    jbe .h_ok
.h1:
    cmp al, 'a'
    jb .h2
    cmp al, 'f'
    jbe .h_ok
.h2:
    cmp al, 'A'
    jb .num_done_int
    cmp al, 'F'
    ja .num_done_int
.h_ok:
    inc r8
    jmp .hex_loop
.bin:
    add r8, 2
.bin_loop:
    cmp r8, [rbx + LX_INPUT_LEN_OFF]
    jae .num_done_int
    mov al, [r9 + r8]
    cmp al, '0'
    je .b_ok
    cmp al, '1'
    jne .num_done_int
.b_ok:
    inc r8
    jmp .bin_loop
.num_scan:
    inc r8
.num_loop:
    cmp r8, [rbx + LX_INPUT_LEN_OFF]
    jae .num_done_int
    mov al, [r9 + r8]
    cmp al, '0'
    jb .maybe_dot
    cmp al, '9'
    jbe .num_advance
.maybe_dot:
    cmp al, '.'
    jne .num_done_int
    lea rcx, [r8 + 1]
    cmp rcx, [rbx + LX_INPUT_LEN_OFF]
    jae .num_done_int
    cmp byte [r9 + rcx], '.'
    je .num_done_int
    mov r11d, 1
    inc r8
    jmp .num_loop
.num_advance:
    inc r8
    jmp .num_loop
.num_done_int:
    mov [rbx + LX_POS_OFF], r8
    mov rdi, rbx
    mov esi, AS_TOK_INT
    cmp r11d, 0
    je .emit_num
    mov esi, AS_TOK_FLOAT
.emit_num:
    lea rdx, [r9 + r10]
    mov ecx, r8d
    sub ecx, r10d
    call as_emit_token
    cmp eax, 0
    jne .ret
    jmp .loop
.string:
    cmp byte [r9 + r8], '"'
    jne .operators
    mov r10, r8
    inc r8
.str_loop:
    cmp r8, [rbx + LX_INPUT_LEN_OFF]
    jae .str_err
    mov al, [r9 + r8]
    cmp al, '"'
    je .str_done
    cmp al, 10
    jne .str_ch
    inc dword [rbx + LX_LINE_OFF]
.str_ch:
    cmp al, '\'
    jne .str_n
    lea rcx, [r8 + 1]
    cmp rcx, [rbx + LX_INPUT_LEN_OFF]
    jae .str_err
    inc r8
.str_n:
    inc r8
    jmp .str_loop
.str_done:
    ; emit content without quotes
    mov [rbx + LX_POS_OFF], r8
    inc qword [rbx + LX_POS_OFF]
    mov rdi, rbx
    mov esi, AS_TOK_STRING
    lea rdx, [r9 + r10 + 1]
    mov ecx, r8d
    sub ecx, r10d
    dec ecx
    call as_emit_token
    cmp eax, 0
    jne .ret
    jmp .loop
.str_err:
    lea rsi, [rel as_err_unclosed_string]
    mov rdi, rbx
    call as_set_error
    jmp .ret
.operators:
    ; two-char first
    lea rcx, [r8 + 1]
    mov r10d, 0
    cmp rcx, [rbx + LX_INPUT_LEN_OFF]
    jae .one_char
    mov al, [r9 + r8]
    mov dl, [r9 + rcx]
    cmp al, '='
    jne .t_neq
    cmp dl, '='
    jne .t_assign
    mov r10d, AS_TOK_EQ
    mov r11d, 2
    jmp .emit_op
.t_assign:
    mov r10d, AS_TOK_ASSIGN
    mov r11d, 1
    jmp .emit_op
.t_neq:
    cmp al, '!'
    jne .t_lte
    cmp dl, '='
    jne .t_not
    mov r10d, AS_TOK_NEQ
    mov r11d, 2
    jmp .emit_op
.t_not:
    mov r10d, AS_TOK_NOT
    mov r11d, 1
    jmp .emit_op
.t_lte:
    cmp al, '<'
    jne .t_gte
    cmp dl, '='
    jne .t_lt
    mov r10d, AS_TOK_LTE
    mov r11d, 2
    jmp .emit_op
.t_lt:
    mov r10d, AS_TOK_LT
    mov r11d, 1
    jmp .emit_op
.t_gte:
    cmp al, '>'
    jne .t_and
    cmp dl, '='
    jne .t_gt
    mov r10d, AS_TOK_GTE
    mov r11d, 2
    jmp .emit_op
.t_gt:
    mov r10d, AS_TOK_GT
    mov r11d, 1
    jmp .emit_op
.t_and:
    cmp al, '&'
    jne .t_or
    cmp dl, '&'
    jne .bad
    mov r10d, AS_TOK_AND
    mov r11d, 2
    jmp .emit_op
.t_or:
    cmp al, '|'
    jne .t_arrow
    cmp dl, '|'
    jne .bad
    mov r10d, AS_TOK_OR
    mov r11d, 2
    jmp .emit_op
.t_arrow:
    cmp al, '-'
    jne .t_dotdot
    cmp dl, '>'
    jne .one_char
    mov r10d, AS_TOK_ARROW
    mov r11d, 2
    jmp .emit_op
.t_dotdot:
    cmp al, '.'
    jne .t_dollar
    cmp dl, '.'
    jne .one_char
    mov r10d, AS_TOK_DOTDOT
    mov r11d, 2
    jmp .emit_op
.t_dollar:
    cmp al, '$'
    jne .one_char
    cmp dl, '('
    jne .bad
    mov r10d, AS_TOK_DOLLAR_PAREN
    mov r11d, 2
    jmp .emit_op
.one_char:
    mov al, [r9 + r8]
    mov r11d, 1
    cmp al, '+'
    jne .c_minus
    mov r10d, AS_TOK_PLUS
    jmp .emit_op
.c_minus:
    cmp al, '-'
    jne .c_star
    mov r10d, AS_TOK_MINUS
    jmp .emit_op
.c_star:
    cmp al, '*'
    jne .c_slash
    mov r10d, AS_TOK_STAR
    jmp .emit_op
.c_slash:
    cmp al, '/'
    jne .c_pct
    mov r10d, AS_TOK_SLASH
    jmp .emit_op
.c_pct:
    cmp al, '%'
    jne .c_lpar
    mov r10d, AS_TOK_PERCENT
    jmp .emit_op
.c_lpar:
    cmp al, '('
    jne .c_rpar
    mov r10d, AS_TOK_LPAREN
    jmp .emit_op
.c_rpar:
    cmp al, ')'
    jne .c_lb
    mov r10d, AS_TOK_RPAREN
    jmp .emit_op
.c_lb:
    cmp al, '{'
    jne .c_rb
    mov r10d, AS_TOK_LBRACE
    jmp .emit_op
.c_rb:
    cmp al, '}'
    jne .c_lsq
    mov r10d, AS_TOK_RBRACE
    jmp .emit_op
.c_lsq:
    cmp al, '['
    jne .c_rsq
    mov r10d, AS_TOK_LBRACKET
    jmp .emit_op
.c_rsq:
    cmp al, ']'
    jne .c_comma
    mov r10d, AS_TOK_RBRACKET
    jmp .emit_op
.c_comma:
    cmp al, ','
    jne .c_colon
    mov r10d, AS_TOK_COMMA
    jmp .emit_op
.c_colon:
    cmp al, ':'
    jne .c_semi
    mov r10d, AS_TOK_COLON
    jmp .emit_op
.c_semi:
    cmp al, ';'
    jne .c_dot
    mov r10d, AS_TOK_SEMICOLON
    jmp .emit_op
.c_dot:
    cmp al, '.'
    jne .bad
    mov r10d, AS_TOK_DOT
.emit_op:
    mov [rbx + LX_POS_OFF], r8
    add [rbx + LX_POS_OFF], r11
    mov rdi, rbx
    mov esi, r10d
    lea rdx, [r9 + r8]
    mov ecx, r11d
    call as_emit_token
    cmp eax, 0
    jne .ret
    jmp .loop
.bad:
    lea rsi, [rel as_err_bad_token]
    mov rdi, rbx
    call as_set_error
    jmp .ret
.emit_eof:
    mov r9, [rbx + LX_INPUT_OFF]
    mov r8, [rbx + LX_INPUT_LEN_OFF]
    mov rdi, rbx
    mov esi, AS_TOK_EOF
    lea rdx, [r9 + r8]
    xor ecx, ecx
    call as_emit_token
    cmp eax, 0
    jne .ret
    xor eax, eax
    pop rbx
    ret
.fail:
    mov eax, -1
.ret:
    pop rbx
    ret

as_lexer_get_tokens:
    test rdi, rdi
    jz .n
    mov rax, [rdi + LX_TOKENS_OFF]
    ret
.n:
    xor eax, eax
    ret

as_lexer_get_count:
    test rdi, rdi
    jz .n
    mov rax, [rdi + LX_COUNT_OFF]
    ret
.n:
    xor eax, eax
    ret

as_lexer_get_error:
    test rdi, rdi
    jz .n
    mov rax, [rdi + LX_ERR_OFF]
    ret
.n:
    xor eax, eax
    ret
