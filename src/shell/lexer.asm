; lexer.asm
; Tokenizer for Aura Shell Phase 1 (Linux x86_64, NASM)

extern arena_alloc

section .text
global lexer_init
global lexer_tokenize
global lexer_get_tokens
global lexer_get_count
global lexer_get_error

; Token types
%define TOK_WORD                    1
%define TOK_PIPE                    2
%define TOK_REDIRECT_IN             3
%define TOK_REDIRECT_OUT            4
%define TOK_REDIRECT_APPEND         5
%define TOK_AND                     6
%define TOK_OR                      7
%define TOK_SEMICOLON               8
%define TOK_AMPERSAND               9
%define TOK_LPAREN                  10
%define TOK_RPAREN                  11
%define TOK_LBRACE                  12
%define TOK_RBRACE                  13
%define TOK_VARIABLE                14
%define TOK_ASSIGNMENT              15
%define TOK_NEWLINE                 16
%define TOK_EOF                     17
%define TOK_ERROR                   18

; Token flags
%define FLAG_QUOTED                 0x01
%define FLAG_EXPANDED               0x02

; Token layout (24 bytes)
%define TOKEN_TYPE_OFF              0
%define TOKEN_START_OFF             8
%define TOKEN_LENGTH_OFF            16
%define TOKEN_FLAGS_OFF             20
%define TOKEN_SIZE                  24

; Lexer layout
%define LX_INPUT_OFF                0
%define LX_INPUT_LEN_OFF            8
%define LX_POS_OFF                  16
%define LX_TOKENS_OFF               24
%define LX_TOKEN_COUNT_OFF          32
%define LX_TOKEN_CAP_OFF            40
%define LX_ARENA_PTR_OFF            48
%define LX_EXPAND_BUF_OFF           56
%define LX_EXPAND_POS_OFF           64
%define LX_ERROR_MSG_OFF            72
%define LEXER_STRUCT_SIZE           80

%define DEFAULT_TOKEN_CAP           256
%define EXPAND_EXTRA_BYTES          64

section .rodata
    err_alloc_lexer         db "lexer: allocation failed (lexer)", 0
    err_alloc_tokens        db "lexer: allocation failed (tokens)", 0
    err_alloc_expand        db "lexer: allocation failed (expand buffer)", 0
    err_too_many_tokens     db "lexer: too many tokens", 0
    err_unclosed_single     db "lexer: unclosed single quote", 0
    err_unclosed_double     db "lexer: unclosed double quote", 0
    err_invalid_variable    db "lexer: invalid variable syntax", 0
    err_invalid_operator    db "lexer: invalid operator", 0

section .text

set_error:
    mov [rdi + LX_ERROR_MSG_OFF], rsi
    mov rax, -1
    ret

; emit_token(lexer, type, start, length, flags)
; rdi=lexer, esi=type, rdx=start, ecx=length, r8d=flags
; rax=0 ok, -1 fail
emit_token:
    push rbx
    mov rbx, rdi

    mov rax, [rbx + LX_TOKEN_COUNT_OFF]
    cmp rax, [rbx + LX_TOKEN_CAP_OFF]
    jb .have_cap
    lea rsi, [rel err_too_many_tokens]
    mov rdi, rbx
    call set_error
    pop rbx
    ret

.have_cap:
    mov r9, [rbx + LX_TOKENS_OFF]
    imul r10, rax, TOKEN_SIZE
    add r9, r10

    mov dword [r9 + TOKEN_TYPE_OFF], esi
    mov [r9 + TOKEN_START_OFF], rdx
    mov dword [r9 + TOKEN_LENGTH_OFF], ecx
    mov dword [r9 + TOKEN_FLAGS_OFF], r8d

    inc qword [rbx + LX_TOKEN_COUNT_OFF]
    xor eax, eax
    pop rbx
    ret

; skip_whitespace(lexer)
; skips spaces/tabs, but not '\n'
skip_whitespace:
    mov r8, [rdi + LX_POS_OFF]
    mov r9, [rdi + LX_INPUT_LEN_OFF]
    mov r10, [rdi + LX_INPUT_OFF]
.loop:
    cmp r8, r9
    jae .done
    mov al, [r10 + r8]
    cmp al, ' '
    je .inc
    cmp al, 9
    jne .done
.inc:
    inc r8
    jmp .loop
.done:
    mov [rdi + LX_POS_OFF], r8
    ret

; check_assignment(start_ptr, length)
; rdi=start_ptr, rsi=length
; rax=1 if NAME=VALUE, else 0
check_assignment:
    xor eax, eax
    cmp rsi, 3
    jb .ret

    xor rcx, rcx                     ; index
    mov r8, -1                       ; '=' index
.find_eq:
    cmp rcx, rsi
    jae .no_eq
    mov dl, [rdi + rcx]
    cmp dl, '='
    jne .next_find
    mov r8, rcx
    jmp .have_eq
.next_find:
    inc rcx
    jmp .find_eq

.no_eq:
    xor eax, eax
    ret

.have_eq:
    cmp r8, 0
    je .ret

    mov dl, [rdi]
    cmp dl, '_'
    je .check_rest
    cmp dl, 'A'
    jb .ret
    cmp dl, 'Z'
    jbe .check_rest
    cmp dl, 'a'
    jb .ret
    cmp dl, 'z'
    ja .ret

.check_rest:
    mov rcx, 1
.rest_loop:
    cmp rcx, r8
    jae .yes
    mov dl, [rdi + rcx]
    cmp dl, '_'
    je .rest_next
    cmp dl, '0'
    jb .rest_alpha
    cmp dl, '9'
    jbe .rest_next
.rest_alpha:
    cmp dl, 'A'
    jb .ret
    cmp dl, 'Z'
    jbe .rest_next
    cmp dl, 'a'
    jb .ret
    cmp dl, 'z'
    ja .ret
.rest_next:
    inc rcx
    jmp .rest_loop

.yes:
    mov eax, 1
.ret:
    ret

; read_operator(lexer)
; rax=token type or 0 on error, rdx=length (1 or 2)
read_operator:
    push rbx
    mov rbx, rdi

    mov r8, [rbx + LX_POS_OFF]
    mov r9, [rbx + LX_INPUT_LEN_OFF]
    mov r10, [rbx + LX_INPUT_OFF]
    cmp r8, r9
    jae .invalid

    mov al, [r10 + r8]
    mov edx, 1

    cmp al, '|'
    je .op_pipe
    cmp al, '&'
    je .op_amp
    cmp al, '>'
    je .op_gt
    cmp al, '<'
    je .op_lt
    cmp al, ';'
    je .op_semicolon
    cmp al, '('
    je .op_lparen
    cmp al, ')'
    je .op_rparen
    cmp al, '{'
    je .op_lbrace
    cmp al, '}'
    je .op_rbrace
    jmp .invalid

.op_pipe:
    mov eax, TOK_PIPE
    lea rcx, [r8 + 1]
    cmp rcx, r9
    jae .advance
    cmp byte [r10 + rcx], '|'
    jne .advance
    mov eax, TOK_OR
    mov edx, 2
    jmp .advance

.op_amp:
    mov eax, TOK_AMPERSAND
    lea rcx, [r8 + 1]
    cmp rcx, r9
    jae .advance
    cmp byte [r10 + rcx], '&'
    jne .advance
    mov eax, TOK_AND
    mov edx, 2
    jmp .advance

.op_gt:
    mov eax, TOK_REDIRECT_OUT
    lea rcx, [r8 + 1]
    cmp rcx, r9
    jae .advance
    cmp byte [r10 + rcx], '>'
    jne .advance
    mov eax, TOK_REDIRECT_APPEND
    mov edx, 2
    jmp .advance

.op_lt:
    mov eax, TOK_REDIRECT_IN
    jmp .advance

.op_semicolon:
    mov eax, TOK_SEMICOLON
    jmp .advance

.op_lparen:
    mov eax, TOK_LPAREN
    jmp .advance

.op_rparen:
    mov eax, TOK_RPAREN
    jmp .advance

.op_lbrace:
    mov eax, TOK_LBRACE
    jmp .advance

.op_rbrace:
    mov eax, TOK_RBRACE

.advance:
    add r8, rdx
    mov [rbx + LX_POS_OFF], r8
    pop rbx
    ret

.invalid:
    lea rsi, [rel err_invalid_operator]
    mov rdi, rbx
    call set_error
    xor eax, eax
    xor edx, edx
    pop rbx
    ret

; read_variable(lexer)
; rax=start_ptr, rdx=len, r8d=flags(0), rax=0 on error
read_variable:
    push rbx
    mov rbx, rdi

    mov r8, [rbx + LX_POS_OFF]
    mov r9, [rbx + LX_INPUT_LEN_OFF]
    mov r10, [rbx + LX_INPUT_OFF]
    inc r8                              ; after '$'
    cmp r8, r9
    jae .invalid

    cmp byte [r10 + r8], '{'
    je .brace_form

    mov r11, r8                         ; name_start
.plain_loop:
    cmp r8, r9
    jae .plain_done
    mov al, [r10 + r8]
    cmp al, '_'
    je .plain_next
    cmp al, '0'
    jb .plain_alpha
    cmp al, '9'
    jbe .plain_next
.plain_alpha:
    cmp al, 'A'
    jb .plain_done
    cmp al, 'Z'
    jbe .plain_next
    cmp al, 'a'
    jb .plain_done
    cmp al, 'z'
    ja .plain_done
.plain_next:
    inc r8
    jmp .plain_loop

.plain_done:
    cmp r8, r11
    je .invalid
    mov [rbx + LX_POS_OFF], r8
    mov rdx, r8
    sub rdx, r11
    mov rax, r10
    add rax, r11
    xor r8d, r8d
    pop rbx
    ret

.brace_form:
    inc r8                              ; skip '{'
    mov r11, r8                         ; name_start
.brace_loop:
    cmp r8, r9
    jae .invalid
    cmp byte [r10 + r8], '}'
    je .brace_done
    inc r8
    jmp .brace_loop

.brace_done:
    cmp r8, r11
    je .invalid
    mov [rbx + LX_POS_OFF], r8
    inc qword [rbx + LX_POS_OFF]        ; skip '}'
    mov rdx, r8
    sub rdx, r11
    mov rax, r10
    add rax, r11
    xor r8d, r8d
    pop rbx
    ret

.invalid:
    lea rsi, [rel err_invalid_variable]
    mov rdi, rbx
    call set_error
    xor eax, eax
    xor edx, edx
    xor r8d, r8d
    pop rbx
    ret

; read_single_quoted(lexer)
; rax=start_ptr, rdx=len, r8d=FLAG_QUOTED, rax=0 on error
read_single_quoted:
    push rbx
    mov rbx, rdi

    mov r8, [rbx + LX_POS_OFF]
    mov r9, [rbx + LX_INPUT_LEN_OFF]
    mov r10, [rbx + LX_INPUT_OFF]
    inc r8                              ; first char in quote
    mov r11, r8                         ; content start

.loop:
    cmp r8, r9
    jae .unclosed
    cmp byte [r10 + r8], 39
    je .done
    inc r8
    jmp .loop

.done:
    mov [rbx + LX_POS_OFF], r8
    inc qword [rbx + LX_POS_OFF]        ; skip closing quote

    mov rdx, r8
    sub rdx, r11
    mov rax, r10
    add rax, r11
    mov r8d, FLAG_QUOTED
    pop rbx
    ret

.unclosed:
    lea rsi, [rel err_unclosed_single]
    mov rdi, rbx
    call set_error
    xor eax, eax
    xor edx, edx
    xor r8d, r8d
    pop rbx
    ret

; read_double_quoted(lexer)
; rax=start_ptr(in expand_buf), rdx=len, r8d=FLAG_QUOTED|FLAG_EXPANDED, rax=0 on error
read_double_quoted:
    push rbx
    push r12
    mov rbx, rdi

    mov r8, [rbx + LX_POS_OFF]
    mov r9, [rbx + LX_INPUT_LEN_OFF]
    mov r10, [rbx + LX_INPUT_OFF]
    mov r11, [rbx + LX_EXPAND_POS_OFF]  ; old expand pos
    mov r12, [rbx + LX_EXPAND_BUF_OFF]
    add r12, r11                        ; dst ptr
    inc r8                              ; first char in quote

.loop:
    cmp r8, r9
    jae .unclosed
    mov al, [r10 + r8]
    cmp al, '"'
    je .done

    cmp al, '\'
    jne .store_char
    lea rcx, [r8 + 1]
    cmp rcx, r9
    jae .store_char
    mov r8, rcx
    mov al, [r10 + r8]
    cmp al, 'n'
    jne .store_char
    mov al, 10

.store_char:
    mov [r12], al
    inc r12
    inc qword [rbx + LX_EXPAND_POS_OFF]
    inc r8
    jmp .loop

.done:
    mov [rbx + LX_POS_OFF], r8
    inc qword [rbx + LX_POS_OFF]        ; skip closing quote

    mov rdx, [rbx + LX_EXPAND_POS_OFF]
    sub rdx, r11
    mov rax, [rbx + LX_EXPAND_BUF_OFF]
    add rax, r11
    mov r8d, FLAG_QUOTED | FLAG_EXPANDED
    pop r12
    pop rbx
    ret

.unclosed:
    lea rsi, [rel err_unclosed_double]
    mov rdi, rbx
    call set_error
    xor eax, eax
    xor edx, edx
    xor r8d, r8d
    pop r12
    pop rbx
    ret

; read_word(lexer)
; rax=start_ptr, rdx=len, r8d=flags (0 or FLAG_EXPANDED), rax=0 on error
read_word:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi

    mov r12, [rbx + LX_POS_OFF]         ; start pos
    mov r13, r12                        ; scan pos
    xor r14d, r14d                      ; has_escape

    mov r9, [rbx + LX_INPUT_LEN_OFF]
    mov r10, [rbx + LX_INPUT_OFF]

.scan_loop:
    cmp r13, r9
    jae .scan_done
    mov al, [r10 + r13]
    cmp al, ' '
    je .scan_done
    cmp al, 9
    je .scan_done
    cmp al, 10
    je .scan_done
    cmp al, '|'
    je .scan_done
    cmp al, '&'
    je .scan_done
    cmp al, '>'
    je .scan_done
    cmp al, '<'
    je .scan_done
    cmp al, ';'
    je .scan_done
    cmp al, '('
    je .scan_done
    cmp al, ')'
    je .scan_done
    cmp al, '{'
    je .scan_done
    cmp al, '}'
    je .scan_done
    cmp al, 39
    je .scan_done
    cmp al, '"'
    je .scan_done
    cmp al, '$'
    je .scan_done

    cmp al, '\'
    jne .next_char
    lea rcx, [r13 + 1]
    cmp rcx, r9
    jae .next_char
    mov r14d, 1
    add r13, 2
    jmp .scan_loop

.next_char:
    inc r13
    jmp .scan_loop

.scan_done:
    mov [rbx + LX_POS_OFF], r13
    mov rdx, r13
    sub rdx, r12
    test rdx, rdx
    jz .empty

    test r14d, r14d
    jnz .copy

    mov rax, [rbx + LX_INPUT_OFF]
    add rax, r12
    xor r8d, r8d
    jmp .ok

.copy:
    mov r15, [rbx + LX_EXPAND_POS_OFF]  ; old expand pos
    mov r11, [rbx + LX_EXPAND_BUF_OFF]
    add r11, r15
    mov rcx, r12

.copy_loop:
    cmp rcx, r13
    jae .copy_done
    mov r10, [rbx + LX_INPUT_OFF]
    mov al, [r10 + rcx]
    cmp al, '\'
    jne .copy_store
    lea r10, [rcx + 1]
    cmp r10, r13
    jae .copy_store
    mov rcx, r10
    mov r10, [rbx + LX_INPUT_OFF]
    mov al, [r10 + rcx]
    cmp al, 'n'
    jne .copy_store
    mov al, 10

.copy_store:
    mov [r11], al
    inc r11
    inc qword [rbx + LX_EXPAND_POS_OFF]
    inc rcx
    jmp .copy_loop

.copy_done:
    mov rdx, [rbx + LX_EXPAND_POS_OFF]
    sub rdx, r15
    mov rax, [rbx + LX_EXPAND_BUF_OFF]
    add rax, r15
    mov r8d, FLAG_EXPANDED
    jmp .ok

.empty:
    xor eax, eax
    xor edx, edx
    xor r8d, r8d

.ok:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; lexer_init(arena_ptr, input_str, input_len)
; rax=lexer_ptr or 0
lexer_init:
    push rbx
    push r12
    push r13
    push r14

    test rdi, rdi
    jz .fail
    test rsi, rsi
    jz .fail

    mov r12, rdi                        ; arena
    mov r13, rsi                        ; input ptr
    mov r14, rdx                        ; input len

    mov rdi, r12
    mov rsi, LEXER_STRUCT_SIZE
    call arena_alloc
    test rax, rax
    jz .fail
    mov rbx, rax                        ; lexer ptr

    mov rdi, r12
    mov rsi, DEFAULT_TOKEN_CAP * TOKEN_SIZE
    call arena_alloc
    test rax, rax
    jz .alloc_tokens_fail
    mov [rbx + LX_TOKENS_OFF], rax

    mov rsi, r14
    add rsi, EXPAND_EXTRA_BYTES
    jc .alloc_expand_fail
    mov rdi, r12
    call arena_alloc
    test rax, rax
    jz .alloc_expand_fail
    mov [rbx + LX_EXPAND_BUF_OFF], rax

    mov [rbx + LX_INPUT_OFF], r13
    mov [rbx + LX_INPUT_LEN_OFF], r14
    mov qword [rbx + LX_POS_OFF], 0
    mov qword [rbx + LX_TOKEN_COUNT_OFF], 0
    mov qword [rbx + LX_TOKEN_CAP_OFF], DEFAULT_TOKEN_CAP
    mov [rbx + LX_ARENA_PTR_OFF], r12
    mov qword [rbx + LX_EXPAND_POS_OFF], 0
    mov qword [rbx + LX_ERROR_MSG_OFF], 0

    mov rax, rbx
    jmp .ret

.alloc_tokens_fail:
    lea rdx, [rel err_alloc_tokens]
    mov [rbx + LX_ERROR_MSG_OFF], rdx
    xor eax, eax
    jmp .ret

.alloc_expand_fail:
    lea rdx, [rel err_alloc_expand]
    mov [rbx + LX_ERROR_MSG_OFF], rdx
    xor eax, eax
    jmp .ret

.fail:
    xor eax, eax
.ret:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; lexer_tokenize(lexer_ptr)
; rax=0 ok, -1 error
lexer_tokenize:
    push rbx
    push r12
    push r13
    push r14

    test rdi, rdi
    jz .fail
    mov rbx, rdi

    mov qword [rbx + LX_POS_OFF], 0
    mov qword [rbx + LX_TOKEN_COUNT_OFF], 0
    mov qword [rbx + LX_EXPAND_POS_OFF], 0
    mov qword [rbx + LX_ERROR_MSG_OFF], 0

.main_loop:
    mov rdi, rbx
    call skip_whitespace

    mov r8, [rbx + LX_POS_OFF]
    cmp r8, [rbx + LX_INPUT_LEN_OFF]
    jae .emit_eof

    mov r9, [rbx + LX_INPUT_OFF]
    mov al, [r9 + r8]

    cmp al, '#'
    je .skip_comment
    cmp al, 10
    je .emit_newline
    cmp al, 39
    je .handle_single
    cmp al, '"'
    je .handle_double
    cmp al, '$'
    je .handle_variable
    cmp al, '|'
    je .handle_operator
    cmp al, '&'
    je .handle_operator
    cmp al, '>'
    je .handle_operator
    cmp al, '<'
    je .handle_operator
    cmp al, ';'
    je .handle_operator
    cmp al, '('
    je .handle_operator
    cmp al, ')'
    je .handle_operator
    cmp al, '{'
    je .handle_operator
    cmp al, '}'
    je .handle_operator
    jmp .handle_word

.skip_comment:
    inc r8
.comment_loop:
    cmp r8, [rbx + LX_INPUT_LEN_OFF]
    jae .comment_done
    cmp byte [r9 + r8], 10
    je .comment_done
    inc r8
    jmp .comment_loop
.comment_done:
    mov [rbx + LX_POS_OFF], r8
    jmp .main_loop

.emit_newline:
    mov rdx, [rbx + LX_INPUT_OFF]
    add rdx, r8
    mov rdi, rbx
    mov esi, TOK_NEWLINE
    mov ecx, 1
    xor r8d, r8d
    call emit_token
    cmp rax, 0
    jne .fail
    inc qword [rbx + LX_POS_OFF]
    jmp .main_loop

.handle_single:
    mov rdi, rbx
    call read_single_quoted
    test rax, rax
    jz .fail
    mov r12, rax
    mov r13, rdx
    mov r14d, r8d
    mov rdi, rbx
    mov esi, TOK_WORD
    mov rdx, r12
    mov rcx, r13
    mov r8d, r14d
    call emit_token
    cmp rax, 0
    jne .fail
    jmp .main_loop

.handle_double:
    mov rdi, rbx
    call read_double_quoted
    test rax, rax
    jz .fail
    mov r12, rax
    mov r13, rdx
    mov r14d, r8d
    mov rdi, rbx
    mov esi, TOK_WORD
    mov rdx, r12
    mov rcx, r13
    mov r8d, r14d
    call emit_token
    cmp rax, 0
    jne .fail
    jmp .main_loop

.handle_variable:
    mov rdi, rbx
    call read_variable
    test rax, rax
    jz .fail
    mov r12, rax
    mov r13, rdx
    mov rdi, rbx
    mov esi, TOK_VARIABLE
    mov rdx, r12
    mov rcx, r13
    xor r8d, r8d
    call emit_token
    cmp rax, 0
    jne .fail
    jmp .main_loop

.handle_operator:
    mov rdi, rbx
    call read_operator
    test eax, eax
    jz .fail
    mov r12d, eax
    mov r13, rdx
    mov rdx, [rbx + LX_INPUT_OFF]
    mov r8, [rbx + LX_POS_OFF]
    sub r8, r13
    add rdx, r8
    mov rdi, rbx
    mov esi, r12d
    mov rcx, r13
    xor r8d, r8d
    call emit_token
    cmp rax, 0
    jne .fail
    jmp .main_loop

.handle_word:
    mov rdi, rbx
    call read_word
    test rax, rax
    jz .fail
    mov r12, rax
    mov r13, rdx
    mov r14d, r8d

    mov rdi, r12
    mov rsi, r13
    call check_assignment
    cmp eax, 1
    jne .emit_word

    mov rdi, rbx
    mov esi, TOK_ASSIGNMENT
    mov rdx, r12
    mov rcx, r13
    mov r8d, r14d
    call emit_token
    cmp rax, 0
    jne .fail
    jmp .main_loop

.emit_word:
    mov rdi, rbx
    mov esi, TOK_WORD
    mov rdx, r12
    mov rcx, r13
    mov r8d, r14d
    call emit_token
    cmp rax, 0
    jne .fail
    jmp .main_loop

.emit_eof:
    mov rdx, [rbx + LX_INPUT_OFF]
    add rdx, [rbx + LX_INPUT_LEN_OFF]
    mov rdi, rbx
    mov esi, TOK_EOF
    xor ecx, ecx
    xor r8d, r8d
    call emit_token
    cmp rax, 0
    jne .fail
    xor eax, eax
    jmp .ret

.fail:
    mov rax, -1
.ret:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; lexer_get_tokens(lexer_ptr)
; rax=tokens ptr or 0
lexer_get_tokens:
    test rdi, rdi
    jz .null
    mov rax, [rdi + LX_TOKENS_OFF]
    ret
.null:
    xor eax, eax
    ret

; lexer_get_count(lexer_ptr)
; rax=count or 0
lexer_get_count:
    test rdi, rdi
    jz .null
    mov rax, [rdi + LX_TOKEN_COUNT_OFF]
    ret
.null:
    xor eax, eax
    ret

; lexer_get_error(lexer_ptr)
; rax=error msg ptr or 0
lexer_get_error:
    test rdi, rdi
    jz .null
    mov rax, [rdi + LX_ERROR_MSG_OFF]
    ret
.null:
    xor eax, eax
    ret
