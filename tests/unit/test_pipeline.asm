; test_pipeline.asm
; Unit tests for pipeline/redirection/list operators

%include "src/hal/platform_defs.inc"

extern hal_write
extern hal_read
extern hal_close
extern hal_open
extern hal_dup2
extern hal_pipe
extern hal_exit
extern arena_init
extern arena_reset
extern arena_destroy
extern lexer_init
extern lexer_tokenize
extern parser_init
extern parser_parse
extern executor_init
extern executor_run

%define ARENA_REQ_SIZE               524288
%define BACKUP_STDOUT_FD             100

section .data
    pass_msg               db "ALL TESTS PASSED", 10
    pass_len               equ $ - pass_msg

    fail_setup_msg         db "TEST FAILED: setup", 10
    fail_setup_len         equ $ - fail_setup_msg
    fail_t1_msg            db "TEST FAILED: simple_pipe", 10
    fail_t1_len            equ $ - fail_t1_msg
    fail_t2_msg            db "TEST FAILED: triple_pipe", 10
    fail_t2_len            equ $ - fail_t2_msg
    fail_t3_msg            db "TEST FAILED: redirect_out", 10
    fail_t3_len            equ $ - fail_t3_msg
    fail_t4_msg            db "TEST FAILED: redirect_append", 10
    fail_t4_len            equ $ - fail_t4_msg
    fail_t5_msg            db "TEST FAILED: redirect_in", 10
    fail_t5_len            equ $ - fail_t5_msg
    fail_t6_msg            db "TEST FAILED: pipe_with_redirects", 10
    fail_t6_len            equ $ - fail_t6_msg
    fail_t7_msg            db "TEST FAILED: and_operator", 10
    fail_t7_len            equ $ - fail_t7_msg
    fail_t8_msg            db "TEST FAILED: or_operator", 10
    fail_t8_len            equ $ - fail_t8_msg
    fail_t9_msg            db "TEST FAILED: semicolon_operator", 10
    fail_t9_len            equ $ - fail_t9_msg

    cmd1                   db "echo hello | cat"
    cmd1_len               equ $ - cmd1
    cmd2                   db "printf 'aaa\nbbb\nccc\n' | sort | head -1"
    cmd2_len               equ $ - cmd2
    cmd3                   db "echo testdata > /tmp/aura_test_out.txt"
    cmd3_len               equ $ - cmd3
    cmd4a                  db "echo line1 > /tmp/aura_test_app.txt"
    cmd4a_len              equ $ - cmd4a
    cmd4b                  db "echo line2 >> /tmp/aura_test_app.txt"
    cmd4b_len              equ $ - cmd4b
    cmd5                   db "cat < /tmp/aura_test_in.txt"
    cmd5_len               equ $ - cmd5
    cmd6                   db "cat < /tmp/aura_test_in.txt | tr a-z A-Z > /tmp/aura_test_out2.txt"
    cmd6_len               equ $ - cmd6
    cmd7a                  db "/bin/true && echo yes"
    cmd7a_len              equ $ - cmd7a
    cmd7b                  db "/bin/false && echo yes"
    cmd7b_len              equ $ - cmd7b
    cmd8a                  db "/bin/false || echo fallback"
    cmd8a_len              equ $ - cmd8a
    cmd8b                  db "/bin/true || echo fallback"
    cmd8b_len              equ $ - cmd8b
    cmd9                   db "echo first ; echo second"
    cmd9_len               equ $ - cmd9

    file_in_path           db "/tmp/aura_test_in.txt", 0
    file_out_path          db "/tmp/aura_test_out.txt", 0
    file_app_path          db "/tmp/aura_test_app.txt", 0
    file_out2_path         db "/tmp/aura_test_out2.txt", 0

    expected_hello         db "hello", 10
    expected_hello_len     equ $ - expected_hello
    expected_aaa           db "aaa", 10
    expected_aaa_len       equ $ - expected_aaa
    expected_testdata      db "testdata", 10
    expected_testdata_len  equ $ - expected_testdata
    expected_appended      db "line1", 10, "line2", 10
    expected_appended_len  equ $ - expected_appended
    expected_input         db "input_data", 10
    expected_input_len     equ $ - expected_input
    expected_upper         db "INPUT_DATA", 10
    expected_upper_len     equ $ - expected_upper
    expected_yes           db "yes", 10
    expected_yes_len       equ $ - expected_yes
    expected_fb            db "fallback", 10
    expected_fb_len        equ $ - expected_fb
    expected_first         db "first", 10
    expected_second        db "second", 10
    input_data_content     db "input_data", 10
    input_data_len         equ $ - input_data_content

section .bss
    arena_ptr              resq 1
    envp_ptr               resq 1
    pipe_fds               resd 2
    read_buf               resb 4096
    file_buf               resb 4096
    cap_len                resq 1
    cap_exit               resq 1

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

contains_substr:
    ; rdi=buf, rsi=buf_len, rdx=sub_ptr, rcx=sub_len -> rax=1/0
    xor eax, eax
    test rcx, rcx
    jz .yes
    cmp rsi, rcx
    jb .no
    xor r8, r8
.outer:
    mov r9, rsi
    sub r9, rcx
    cmp r8, r9
    ja .no
    lea r10, [rdi + r8]
    push rdi
    push rsi
    push rdx
    push rcx
    mov rdi, r10
    mov rsi, rdx
    mov rdx, rcx
    call memeq
    pop rcx
    pop rdx
    pop rsi
    pop rdi
    cmp rax, 1
    je .yes
    inc r8
    jmp .outer
.yes:
    mov eax, 1
    ret
.no:
    xor eax, eax
    ret

run_command:
    ; rdi=input_ptr, rdx=input_len -> rax=exit code or -1
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

capture_command:
    ; rdi=input_ptr, rsi=input_len
    ; output: [cap_exit], [cap_len], read_buf
    push rbx
    push r12
    mov rbx, rdi
    mov r12, rsi

    lea rdi, [rel pipe_fds]
    call hal_pipe
    cmp rax, 0
    jne .fail

    mov rdi, STDOUT
    mov rsi, BACKUP_STDOUT_FD
    call hal_dup2
    test rax, rax
    js .fail

    mov edi, [rel pipe_fds + 4]
    mov esi, STDOUT
    call hal_dup2
    test rax, rax
    js .fail

    mov edi, [rel pipe_fds + 4]
    call hal_close

    mov rdi, rbx
    mov rdx, r12
    call run_command
    mov [rel cap_exit], rax

    mov rdi, BACKUP_STDOUT_FD
    mov rsi, STDOUT
    call hal_dup2
    mov rdi, BACKUP_STDOUT_FD
    call hal_close

    mov edi, [rel pipe_fds + 0]
    lea rsi, [rel read_buf]
    mov rdx, 4096
    call hal_read
    mov [rel cap_len], rax
    mov edi, [rel pipe_fds + 0]
    call hal_close

    pop r12
    pop rbx
    ret
.fail:
    mov qword [rel cap_exit], -1
    mov qword [rel cap_len], 0
    pop r12
    pop rbx
    ret

read_file_to_buf:
    ; rdi=path cstr -> rax=len or -1
    push rbx
    push r12
    mov rsi, O_RDONLY
    xor rdx, rdx
    call hal_open
    test rax, rax
    js .fail
    mov rbx, rax
    mov rdi, rbx
    lea rsi, [rel file_buf]
    mov rdx, 4096
    call hal_read
    mov r12, rax
    mov rdi, rbx
    call hal_close
    mov rax, r12
    pop r12
    pop rbx
    ret
.fail:
    mov rax, -1
    pop r12
    pop rbx
    ret

write_file_content:
    ; rdi=path cstr, rsi=data ptr, rdx=len
    push rbx
    push r12
    push r13
    mov rbx, rsi
    mov r12, rdx
    mov rsi, O_WRONLY | O_CREAT | O_TRUNC
    mov rdx, 420
    call hal_open
    test rax, rax
    js .fail
    mov r13, rax
    mov rdi, r13
    mov rsi, rbx
    mov rdx, r12
    call hal_write
    mov rdi, r13
    call hal_close
    xor eax, eax
    pop r13
    pop r12
    pop rbx
    ret
.fail:
    mov eax, -1
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

    ; prepare input file
    lea rdi, [rel file_in_path]
    lea rsi, [rel input_data_content]
    mov rdx, input_data_len
    call write_file_content
    cmp rax, 0
    jne .fail_setup

    ; Test 1: echo hello | cat
    lea rdi, [rel cmd1]
    mov rsi, cmd1_len
    call capture_command
    cmp qword [rel cap_exit], 0
    jne .fail_t1
    cmp qword [rel cap_len], expected_hello_len
    jl .fail_t1
    lea rdi, [rel read_buf]
    lea rsi, [rel expected_hello]
    mov rdx, expected_hello_len
    call memeq
    cmp rax, 1
    jne .fail_t1

    ; Test 2: triple pipe
    lea rdi, [rel cmd2]
    mov rsi, cmd2_len
    call capture_command
    cmp qword [rel cap_exit], 0
    jne .fail_t2
    cmp qword [rel cap_len], expected_aaa_len
    jl .fail_t2
    lea rdi, [rel read_buf]
    lea rsi, [rel expected_aaa]
    mov rdx, expected_aaa_len
    call memeq
    cmp rax, 1
    jne .fail_t2

    ; Test 3: redirect out
    lea rdi, [rel cmd3]
    mov rdx, cmd3_len
    call run_command
    cmp rax, 0
    jne .fail_t3
    lea rdi, [rel file_out_path]
    call read_file_to_buf
    cmp rax, expected_testdata_len
    jl .fail_t3
    lea rdi, [rel file_buf]
    lea rsi, [rel expected_testdata]
    mov rdx, expected_testdata_len
    call memeq
    cmp rax, 1
    jne .fail_t3

    ; Test 4: append redirect
    lea rdi, [rel cmd4a]
    mov rdx, cmd4a_len
    call run_command
    cmp rax, 0
    jne .fail_t4
    lea rdi, [rel cmd4b]
    mov rdx, cmd4b_len
    call run_command
    cmp rax, 0
    jne .fail_t4
    lea rdi, [rel file_app_path]
    call read_file_to_buf
    cmp rax, expected_appended_len
    jl .fail_t4
    lea rdi, [rel file_buf]
    lea rsi, [rel expected_appended]
    mov rdx, expected_appended_len
    call memeq
    cmp rax, 1
    jne .fail_t4

    ; Test 5: input redirect
    lea rdi, [rel cmd5]
    mov rsi, cmd5_len
    call capture_command
    cmp qword [rel cap_exit], 0
    jne .fail_t5
    cmp qword [rel cap_len], expected_input_len
    jl .fail_t5
    lea rdi, [rel read_buf]
    lea rsi, [rel expected_input]
    mov rdx, expected_input_len
    call memeq
    cmp rax, 1
    jne .fail_t5

    ; Test 6: pipe + redirects
    lea rdi, [rel cmd6]
    mov rdx, cmd6_len
    call run_command
    cmp rax, 0
    jne .fail_t6
    lea rdi, [rel file_out2_path]
    call read_file_to_buf
    cmp rax, expected_upper_len
    jl .fail_t6
    lea rdi, [rel file_buf]
    lea rsi, [rel expected_upper]
    mov rdx, expected_upper_len
    call memeq
    cmp rax, 1
    jne .fail_t6

    ; Test 7: &&
    lea rdi, [rel cmd7a]
    mov rsi, cmd7a_len
    call capture_command
    cmp qword [rel cap_exit], 0
    jne .fail_t7
    lea rdi, [rel read_buf]
    lea rsi, [rel expected_yes]
    mov rdx, expected_yes_len
    call memeq
    cmp rax, 1
    jne .fail_t7
    lea rdi, [rel cmd7b]
    mov rsi, cmd7b_len
    call capture_command
    cmp qword [rel cap_exit], 0
    je .fail_t7
    cmp qword [rel cap_len], 0
    jne .fail_t7

    ; Test 8: ||
    lea rdi, [rel cmd8a]
    mov rsi, cmd8a_len
    call capture_command
    cmp qword [rel cap_exit], 0
    jne .fail_t8
    lea rdi, [rel read_buf]
    lea rsi, [rel expected_fb]
    mov rdx, expected_fb_len
    call memeq
    cmp rax, 1
    jne .fail_t8
    lea rdi, [rel cmd8b]
    mov rsi, cmd8b_len
    call capture_command
    cmp qword [rel cap_exit], 0
    jne .fail_t8
    cmp qword [rel cap_len], 0
    jne .fail_t8

    ; Test 9: ;
    lea rdi, [rel cmd9]
    mov rsi, cmd9_len
    call capture_command
    cmp qword [rel cap_exit], 0
    jne .fail_t9
    lea rdi, [rel read_buf]
    mov rsi, [rel cap_len]
    lea rdx, [rel expected_first]
    mov rcx, 6
    call contains_substr
    cmp rax, 1
    jne .fail_t9
    lea rdi, [rel read_buf]
    mov rsi, [rel cap_len]
    lea rdx, [rel expected_second]
    mov rcx, 7
    call contains_substr
    cmp rax, 1
    jne .fail_t9

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
