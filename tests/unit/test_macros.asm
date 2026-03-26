; test_macros.asm
%include "src/hal/linux_x86_64/defs.inc"

extern hal_write
extern hal_exit
extern arena_init
extern arena_destroy
extern macro_init
extern macro_start_recording
extern macro_record_event
extern macro_stop_recording
extern macro_play
extern macro_play_tick
extern macro_dequeue_injected
extern macro_save
extern macro_load
extern macro_list_count
extern macro_delete

%define ARENA_SIZE 2097152

section .data
    pass_msg db "ALL TESTS PASSED",10
    pass_len equ $ - pass_msg
    fail_msg db "TEST FAILED: macros",10
    fail_len equ $ - fail_msg
    m1 db "test_macro",0
    m2 db "m2",0
    m3 db "m3",0
    m4 db "m4",0
    save_path db "/tmp/test_macros.bin",0

section .bss
    arena_ptr resq 1
    mgr_ptr   resq 1
    ev_tmp    resq 1
    out_ev    resq 1

section .text
global _start

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
    call macro_init
    test rax, rax
    jz fail
    mov [rel mgr_ptr], rax

    ; test1 record + play
    mov rdi, [rel mgr_ptr]
    lea rsi, [rel m1]
    call macro_start_recording
    cmp eax, 0
    jne fail
    mov qword [rel ev_tmp], 1
    mov rdi, [rel mgr_ptr]
    lea rsi, [rel ev_tmp]
    call macro_record_event
    cmp eax, 0
    jne fail
    mov qword [rel ev_tmp], 2
    mov rdi, [rel mgr_ptr]
    lea rsi, [rel ev_tmp]
    call macro_record_event
    cmp eax, 0
    jne fail
    mov qword [rel ev_tmp], 3
    mov rdi, [rel mgr_ptr]
    lea rsi, [rel ev_tmp]
    call macro_record_event
    cmp eax, 0
    jne fail
    mov qword [rel ev_tmp], 4
    mov rdi, [rel mgr_ptr]
    lea rsi, [rel ev_tmp]
    call macro_record_event
    cmp eax, 0
    jne fail
    mov qword [rel ev_tmp], 5
    mov rdi, [rel mgr_ptr]
    lea rsi, [rel ev_tmp]
    call macro_record_event
    cmp eax, 0
    jne fail
    mov rdi, [rel mgr_ptr]
    call macro_stop_recording
    cmp eax, 0
    jne fail
    mov rdi, [rel mgr_ptr]
    lea rsi, [rel m1]
    call macro_play
    cmp eax, 0
    jne fail
    mov r14d, 5
.ticks:
    mov rdi, [rel mgr_ptr]
    call macro_play_tick
    cmp eax, 1
    jne fail
    dec r14d
    jnz .ticks
    mov r14d, 5
.deq:
    mov rdi, [rel mgr_ptr]
    lea rsi, [rel out_ev]
    call macro_dequeue_injected
    cmp eax, 1
    jne fail
    dec r14d
    jnz .deq

    ; test2 save/load
    mov rdi, [rel mgr_ptr]
    lea rsi, [rel save_path]
    call macro_save
    cmp eax, 0
    jne fail
    mov rdi, [rel mgr_ptr]
    lea rsi, [rel m1]
    call macro_delete
    cmp eax, 0
    jne fail
    mov rdi, [rel mgr_ptr]
    call macro_list_count
    cmp eax, 0
    jne fail
    mov rdi, [rel mgr_ptr]
    lea rsi, [rel save_path]
    call macro_load
    cmp eax, 0
    jne fail
    mov rdi, [rel mgr_ptr]
    call macro_list_count
    cmp eax, 1
    jne fail

    ; test3 list (3 entries)
    mov rdi, [rel mgr_ptr]
    lea rsi, [rel m2]
    call macro_start_recording
    cmp eax, 0
    jne fail
    mov rdi, [rel mgr_ptr]
    call macro_stop_recording
    mov rdi, [rel mgr_ptr]
    lea rsi, [rel m3]
    call macro_start_recording
    cmp eax, 0
    jne fail
    mov rdi, [rel mgr_ptr]
    call macro_stop_recording
    mov rdi, [rel mgr_ptr]
    lea rsi, [rel m4]
    call macro_start_recording
    cmp eax, 0
    jne fail
    mov rdi, [rel mgr_ptr]
    call macro_stop_recording
    mov rdi, [rel mgr_ptr]
    call macro_list_count
    cmp eax, 4
    jne fail

    mov rdi, [rel arena_ptr]
    call arena_destroy
    mov rdi, STDOUT
    lea rsi, [rel pass_msg]
    mov rdx, pass_len
    call hal_write
    xor rdi, rdi
    call hal_exit
