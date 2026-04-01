; test_event.asm
; Unit tests for epoll event loop and timer integration
; Author: Aura Shell Team
; Date: 2026-03-19

%include "src/hal/platform_defs.inc"

extern hal_write
extern hal_exit
extern hal_read
extern eventloop_init
extern eventloop_add_fd
extern eventloop_remove_fd
extern eventloop_run
extern eventloop_stop
extern eventloop_destroy
extern eventloop_add_timer
extern eventloop_remove_timer

section .data
    ping_msg             db "PING"
    ping_len             equ $ - ping_msg

    pass_msg             db "ALL TESTS PASSED", 10
    pass_len             equ $ - pass_msg

    fail_timer_msg       db "TEST FAILED: event_timer", 10
    fail_timer_len       equ $ - fail_timer_msg
    fail_pipe_msg        db "TEST FAILED: event_pipe", 10
    fail_pipe_len        equ $ - fail_pipe_msg

section .bss
    loop_ptr             resq 1
    timer_count          resq 1
    timer_fd_var         resq 1
    pipe_fds             resd 2
    pipe_buf             resb 8
    pipe_seen            resq 1

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

; timer_callback(fd, events, user_data)
timer_callback:
    inc qword [rel timer_count]
    cmp qword [rel timer_count], 5
    jb .ret
    mov rdi, [rel loop_ptr]
    call eventloop_stop
.ret:
    ret

; pipe_callback(fd, events, user_data)
pipe_callback:
    mov rdi, rdi
    lea rsi, [rel pipe_buf]
    mov rdx, 4
    call hal_read
    cmp rax, 4
    jne .ret
    mov eax, dword [rel pipe_buf]
    cmp eax, 0x474e4950            ; "PING" little-endian
    jne .ret
    mov qword [rel pipe_seen], 1
    mov rdi, [rel loop_ptr]
    call eventloop_stop
.ret:
    ret

_start:
    ; Test 1: timer on 50ms should fire at least 5 times.
    call eventloop_init
    test rax, rax
    jz .fail_timer
    mov [rel loop_ptr], rax
    mov qword [rel timer_count], 0

    mov rdi, rax
    mov rsi, 50
    lea rdx, [rel timer_callback]
    xor rcx, rcx
    call eventloop_add_timer
    test rax, rax
    js .fail_timer_destroy
    mov [rel timer_fd_var], rax

    mov rdi, [rel loop_ptr]
    call eventloop_run
    cmp qword [rel timer_count], 5
    jb .fail_timer_destroy

    mov rdi, [rel loop_ptr]
    mov rsi, [rel timer_fd_var]
    call eventloop_remove_timer

    ; Test 2: pipe + epoll callback reads "PING".
    mov rax, SYS_PIPE2
    lea rdi, [rel pipe_fds]
    xor rsi, rsi
    syscall
    test rax, rax
    js .fail_pipe_destroy

    mov qword [rel pipe_seen], 0
    mov rdi, [rel loop_ptr]
    movsx rsi, dword [rel pipe_fds]
    mov rdx, EPOLLIN
    lea rcx, [rel pipe_callback]
    xor r8, r8
    call eventloop_add_fd
    cmp rax, 0
    jne .fail_pipe_close

    mov rax, SYS_WRITE
    movsx rdi, dword [rel pipe_fds + 4]
    lea rsi, [rel ping_msg]
    mov rdx, ping_len
    syscall
    cmp rax, ping_len
    jne .fail_pipe_rm

    mov rdi, [rel loop_ptr]
    call eventloop_run
    cmp qword [rel pipe_seen], 1
    jne .fail_pipe_rm

    mov rdi, [rel loop_ptr]
    movsx rsi, dword [rel pipe_fds]
    call eventloop_remove_fd

    mov rdi, [rel loop_ptr]
    call eventloop_destroy

    write_stdout pass_msg, pass_len
    xor rdi, rdi
    call hal_exit

.fail_pipe_rm:
    mov rdi, [rel loop_ptr]
    movsx rsi, dword [rel pipe_fds]
    call eventloop_remove_fd
.fail_pipe_close:
    mov rax, SYS_CLOSE
    movsx rdi, dword [rel pipe_fds]
    syscall
    mov rax, SYS_CLOSE
    movsx rdi, dword [rel pipe_fds + 4]
    syscall
.fail_pipe_destroy:
    mov rdi, [rel loop_ptr]
    call eventloop_destroy
    fail_exit fail_pipe_msg, fail_pipe_len

.fail_timer_destroy:
    mov rdi, [rel loop_ptr]
    test rdi, rdi
    jz .fail_timer
    call eventloop_destroy
.fail_timer:
    fail_exit fail_timer_msg, fail_timer_len
