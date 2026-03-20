; test_executor.asm
; Unit tests for shell executor (Aura Shell)

%include "src/hal/linux_x86_64/defs.inc"

extern hal_write
extern hal_read
extern hal_exit
extern hal_close
extern hal_dup2
extern hal_pipe
extern hal_getcwd
extern arena_init
extern arena_reset
extern arena_destroy
extern lexer_init
extern lexer_tokenize
extern parser_init
extern parser_parse
extern executor_init
extern executor_run

%define ARENA_REQ_SIZE               262144
%define BACKUP_STDOUT_FD             100

section .data
    pass_msg               db "ALL TESTS PASSED", 10
    pass_len               equ $ - pass_msg

    fail_setup_msg         db "TEST FAILED: setup", 10
    fail_setup_len         equ $ - fail_setup_msg
    fail_t1_msg            db "TEST FAILED: exec_echo_capture", 10
    fail_t1_len            equ $ - fail_t1_msg
    fail_t2_msg            db "TEST FAILED: exec_ls_tmp", 10
    fail_t2_len            equ $ - fail_t2_msg
    fail_t3_msg            db "TEST FAILED: exec_nonexistent", 10
    fail_t3_len            equ $ - fail_t3_msg
    fail_t4_msg            db "TEST FAILED: exec_path_resolution", 10
    fail_t4_len            equ $ - fail_t4_msg
    fail_t5_msg            db "TEST FAILED: exec_cd", 10
    fail_t5_len            equ $ - fail_t5_msg
    fail_t6_msg            db "TEST FAILED: exec_exit_code", 10
    fail_t6_len            equ $ - fail_t6_msg

    cmd_echo_hello         db "echo hello"
    cmd_echo_hello_len     equ $ - cmd_echo_hello
    cmd_ls_tmp             db "/bin/ls /tmp"
    cmd_ls_tmp_len         equ $ - cmd_ls_tmp
    cmd_nonexist           db "nonexistent_command_12345"
    cmd_nonexist_len       equ $ - cmd_nonexist
    cmd_cd_tmp             db "cd /tmp"
    cmd_cd_tmp_len         equ $ - cmd_cd_tmp
    cmd_cd_root            db "cd /"
    cmd_cd_root_len        equ $ - cmd_cd_root
    cmd_true               db "/bin/true"
    cmd_true_len           equ $ - cmd_true
    cmd_false              db "/bin/false"
    cmd_false_len          equ $ - cmd_false

    expected_hello         db "hello", 10
    expected_hello_len     equ $ - expected_hello
    expected_tmp_prefix    db "/tmp"
    expected_root_prefix   db "/"

section .bss
    arena_ptr              resq 1
    envp_ptr               resq 1
    pipe_fds               resd 2
    read_buf               resb 256
    cwd_buf                resb 512

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

; memeq(rdi, rsi, rdx) => rax=1 equal
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

; run_command(input_ptr, input_len) -> rax=exit code, -1 on setup/parse failure
run_command:
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12, rdx

    mov rdi, [rel arena_ptr]
    call arena_reset

    mov rdi, [rel arena_ptr]
    mov rsi, rbx
    mov rdx, r12
    call lexer_init
    test rax, rax
    jz .fail
    mov r13, rax

    mov rdi, r13
    call lexer_tokenize
    cmp rax, 0
    jne .fail

    mov rdi, [rel arena_ptr]
    mov rsi, r13
    call parser_init
    test rax, rax
    jz .fail
    mov r13, rax

    mov rdi, r13
    call parser_parse
    test rax, rax
    jz .fail
    mov r12, rax

    mov rdi, [rel arena_ptr]
    mov rsi, [rel envp_ptr]
    call executor_init
    test rax, rax
    jz .fail

    mov rdi, rax
    mov rsi, r12
    call executor_run
    jmp .ret

.fail:
    mov rax, -1
.ret:
    pop r13
    pop r12
    pop rbx
    ret

_start:
    ; capture envp from initial stack
    mov rcx, [rsp]
    lea rax, [rsp + 8]
    lea rdx, [rax + rcx*8 + 8]
    mov [rel envp_ptr], rdx

    mov rdi, ARENA_REQ_SIZE
    call arena_init
    test rax, rax
    jz .fail_setup
    mov [rel arena_ptr], rax

    ; Test 1: capture "echo hello"
    lea rdi, [rel pipe_fds]
    call hal_pipe
    cmp rax, 0
    jne .fail_t1

    mov rdi, STDOUT
    mov rsi, BACKUP_STDOUT_FD
    call hal_dup2
    test rax, rax
    js .fail_t1

    mov edi, [rel pipe_fds + 4]         ; write end
    mov esi, STDOUT
    call hal_dup2
    test rax, rax
    js .fail_t1

    mov edi, [rel pipe_fds + 4]
    call hal_close

    lea rdi, [rel cmd_echo_hello]
    mov rdx, cmd_echo_hello_len
    call run_command
    cmp rax, 0
    jne .fail_t1

    mov rdi, BACKUP_STDOUT_FD
    mov rsi, STDOUT
    call hal_dup2
    mov rdi, BACKUP_STDOUT_FD
    call hal_close

    mov edi, [rel pipe_fds + 0]
    lea rsi, [rel read_buf]
    mov rdx, 256
    call hal_read
    cmp rax, expected_hello_len
    jl .fail_t1
    mov edi, [rel pipe_fds + 0]
    call hal_close

    lea rdi, [rel read_buf]
    lea rsi, [rel expected_hello]
    mov rdx, expected_hello_len
    call memeq
    cmp rax, 1
    jne .fail_t1

    ; Test 2: /bin/ls /tmp
    lea rdi, [rel cmd_ls_tmp]
    mov rdx, cmd_ls_tmp_len
    call run_command
    cmp rax, 0
    jne .fail_t2

    ; Test 3: nonexistent command
    lea rdi, [rel cmd_nonexist]
    mov rdx, cmd_nonexist_len
    call run_command
    cmp rax, 0
    je .fail_t3

    ; Test 4: PATH resolution "echo hello"
    lea rdi, [rel cmd_echo_hello]
    mov rdx, cmd_echo_hello_len
    call run_command
    cmp rax, 0
    jne .fail_t4

    ; Test 5: cd /tmp then cd /
    lea rdi, [rel cmd_cd_tmp]
    mov rdx, cmd_cd_tmp_len
    call run_command
    cmp rax, 0
    jne .fail_t5
    lea rdi, [rel cwd_buf]
    mov rsi, 512
    call hal_getcwd
    test rax, rax
    js .fail_t5
    lea rdi, [rel cwd_buf]
    lea rsi, [rel expected_tmp_prefix]
    mov rdx, 4
    call memeq
    cmp rax, 1
    jne .fail_t5

    lea rdi, [rel cmd_cd_root]
    mov rdx, cmd_cd_root_len
    call run_command
    cmp rax, 0
    jne .fail_t5
    lea rdi, [rel cwd_buf]
    mov rsi, 512
    call hal_getcwd
    test rax, rax
    js .fail_t5
    cmp byte [cwd_buf], '/'
    jne .fail_t5

    ; Test 6: exit code true/false
    lea rdi, [rel cmd_true]
    mov rdx, cmd_true_len
    call run_command
    cmp rax, 0
    jne .fail_t6

    lea rdi, [rel cmd_false]
    mov rdx, cmd_false_len
    call run_command
    cmp rax, 1
    jne .fail_t6

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
