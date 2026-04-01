; test_builtins.asm

%include "src/hal/platform_defs.inc"

extern hal_write
extern hal_exit
extern hal_getcwd
extern arena_init
extern arena_destroy
extern builtins_init
extern builtins_get_var_store
extern builtins_get_alias_store
extern builtins_get_history
extern builtin_dispatch
extern vars_set
extern vars_get
extern vars_unset
extern vars_expand
extern alias_set
extern alias_get
extern history_add
extern history_navigate_up
extern history_search

%define ARENA_SIZE                   262144

%define CMD_ARGC_OFF                 4
%define CMD_ARGV_OFF                 8
%define CMD_ARGV_LEN_OFF             136

section .data
    pass_msg            db "ALL TESTS PASSED",10
    pass_len            equ $ - pass_msg
    fail_msg            db "TEST FAILED: test_builtins",10
    fail_len            equ $ - fail_msg

    s_my_var            db "MY_VAR"
    s_my_var_len        equ $ - s_my_var
    s_hello             db "hello"
    s_hello_len         equ $ - s_hello
    s_name              db "NAME"
    s_name_len          equ $ - s_name
    s_world             db "world"
    s_world_len         equ $ - s_world
    s_expand1           db "hello $NAME!"
    s_expand1_len       equ $ - s_expand1
    s_expand2           db "${NAME}123"
    s_expand2_len       equ $ - s_expand2
    s_no_vars           db "no vars here"
    s_no_vars_len       equ $ - s_no_vars
    s_expect1           db "hello world!"
    s_expect1_len       equ $ - s_expect1
    s_expect2           db "world123"
    s_expect2_len       equ $ - s_expect2

    s_ll                db "ll"
    s_ll_len            equ $ - s_ll
    s_lsla              db "ls -la"
    s_lsla_len          equ $ - s_lsla

    h_line1             db "echo one"
    h_line1_len         equ $ - h_line1
    h_line2             db "grep test file"
    h_line2_len         equ $ - h_line2
    h_line3             db "ls -la"
    h_line3_len         equ $ - h_line3
    h_pat               db "grep"
    h_pat_len           equ $ - h_pat

    b_cd                db "cd"
    b_tmp               db "/tmp",0
    b_true              db "true"
    b_false             db "false"
    b_none              db "nonexistent"

section .bss
    arena_ptr           resq 1
    vars_ptr            resq 1
    alias_ptr           resq 1
    hist_ptr            resq 1
    out_buf             resb 256
    cwd_buf             resb 256
    cmd_node            resb 256
    argv_buf            resq 4
    argv_len_buf        resd 4

section .text
global _start

memeq_t:
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

fail:
    mov rdi, STDOUT
    lea rsi, [rel fail_msg]
    mov rdx, fail_len
    call hal_write
    mov rdi, 1
    call hal_exit

_start:
    mov rdi, ARENA_SIZE
    call arena_init
    test rax, rax
    jz fail
    mov [rel arena_ptr], rax

    mov rdi, rax
    call builtins_init
    cmp rax, 0
    jne fail

    call builtins_get_var_store
    test rax, rax
    jz fail
    mov [rel vars_ptr], rax
    call builtins_get_alias_store
    test rax, rax
    jz fail
    mov [rel alias_ptr], rax
    call builtins_get_history
    test rax, rax
    jz fail
    mov [rel hist_ptr], rax

    ; vars set/get/unset
    mov rdi, [rel vars_ptr]
    lea rsi, [rel s_my_var]
    mov rdx, s_my_var_len
    lea rcx, [rel s_hello]
    mov r8, s_hello_len
    call vars_set
    cmp rax, 0
    jne fail
    mov rdi, [rel vars_ptr]
    lea rsi, [rel s_my_var]
    mov rdx, s_my_var_len
    call vars_get
    test rax, rax
    jz fail
    mov rdi, rax
    lea rsi, [rel s_hello]
    mov rdx, s_hello_len
    call memeq_t
    cmp rax, 1
    jne fail
    mov rdi, [rel vars_ptr]
    lea rsi, [rel s_my_var]
    mov rdx, s_my_var_len
    call vars_unset
    cmp rax, 0
    jne fail

    ; vars expand
    mov rdi, [rel vars_ptr]
    lea rsi, [rel s_name]
    mov rdx, s_name_len
    lea rcx, [rel s_world]
    mov r8, s_world_len
    call vars_set
    cmp rax, 0
    jne fail
    mov rdi, [rel vars_ptr]
    lea rsi, [rel s_expand1]
    mov rdx, s_expand1_len
    lea rcx, [rel out_buf]
    mov r8, 256
    call vars_expand
    cmp rax, s_expect1_len
    jne fail
    lea rdi, [rel out_buf]
    lea rsi, [rel s_expect1]
    mov rdx, s_expect1_len
    call memeq_t
    cmp rax, 1
    jne fail

    mov rdi, [rel vars_ptr]
    lea rsi, [rel s_expand2]
    mov rdx, s_expand2_len
    lea rcx, [rel out_buf]
    mov r8, 256
    call vars_expand
    cmp rax, s_expect2_len
    jne fail
    lea rdi, [rel out_buf]
    lea rsi, [rel s_expect2]
    mov rdx, s_expect2_len
    call memeq_t
    cmp rax, 1
    jne fail

    mov rdi, [rel vars_ptr]
    lea rsi, [rel s_no_vars]
    mov rdx, s_no_vars_len
    lea rcx, [rel out_buf]
    mov r8, 256
    call vars_expand
    cmp rax, s_no_vars_len
    jne fail

    ; alias
    mov rdi, [rel alias_ptr]
    lea rsi, [rel s_ll]
    mov rdx, s_ll_len
    lea rcx, [rel s_lsla]
    mov r8, s_lsla_len
    call alias_set
    cmp rax, 0
    jne fail
    mov rdi, [rel alias_ptr]
    lea rsi, [rel s_ll]
    mov rdx, s_ll_len
    call alias_get
    test rax, rax
    jz fail
    mov rdi, rax
    lea rsi, [rel s_lsla]
    mov rdx, s_lsla_len
    call memeq_t
    cmp rax, 1
    jne fail

    ; history
    mov rdi, [rel hist_ptr]
    lea rsi, [rel h_line1]
    mov rdx, h_line1_len
    call history_add
    mov rdi, [rel hist_ptr]
    lea rsi, [rel h_line2]
    mov rdx, h_line2_len
    call history_add
    mov rdi, [rel hist_ptr]
    lea rsi, [rel h_line3]
    mov rdx, h_line3_len
    call history_add
    mov rdi, [rel hist_ptr]
    call history_navigate_up
    test rax, rax
    jz fail
    mov rdi, rax
    lea rsi, [rel h_line3]
    mov rdx, h_line3_len
    call memeq_t
    cmp rax, 1
    jne fail
    mov rdi, [rel hist_ptr]
    lea rsi, [rel h_pat]
    mov rdx, h_pat_len
    call history_search
    test rax, rax
    jz fail

    ; builtin dispatch: cd /tmp
    ; prepare cmd node
    mov dword [rel cmd_node + CMD_ARGC_OFF], 2
    lea rax, [rel b_cd]
    mov [rel cmd_node + CMD_ARGV_OFF], rax
    lea rax, [rel b_tmp]
    mov [rel cmd_node + CMD_ARGV_OFF + 8], rax
    mov dword [rel cmd_node + CMD_ARGV_LEN_OFF], 2
    mov dword [rel cmd_node + CMD_ARGV_LEN_OFF + 4], 4
    lea rdi, [rel b_cd]
    mov rsi, 2
    lea rdx, [rel cmd_node]
    xor rcx, rcx
    call builtin_dispatch
    cmp rax, 0
    jne fail
    lea rdi, [rel cwd_buf]
    mov rsi, 256
    call hal_getcwd
    test rax, rax
    js fail
    cmp byte [rel cwd_buf], '/'
    jne fail

    ; true / false / nonexistent
    mov dword [rel cmd_node + CMD_ARGC_OFF], 1
    lea rax, [rel b_true]
    mov [rel cmd_node + CMD_ARGV_OFF], rax
    mov dword [rel cmd_node + CMD_ARGV_LEN_OFF], 4
    lea rdi, [rel b_true]
    mov rsi, 4
    lea rdx, [rel cmd_node]
    xor rcx, rcx
    call builtin_dispatch
    cmp rax, 0
    jne fail

    lea rax, [rel b_false]
    mov [rel cmd_node + CMD_ARGV_OFF], rax
    mov dword [rel cmd_node + CMD_ARGV_LEN_OFF], 5
    lea rdi, [rel b_false]
    mov rsi, 5
    lea rdx, [rel cmd_node]
    xor rcx, rcx
    call builtin_dispatch
    cmp rax, 1
    jne fail

    lea rdi, [rel b_none]
    mov rsi, 11
    lea rdx, [rel cmd_node]
    xor rcx, rcx
    call builtin_dispatch
    cmp eax, -1
    jne fail

    mov rdi, [rel arena_ptr]
    call arena_destroy
    mov rdi, STDOUT
    lea rsi, [rel pass_msg]
    mov rdx, pass_len
    call hal_write
    xor rdi, rdi
    call hal_exit
