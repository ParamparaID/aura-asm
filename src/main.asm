; main.asm
; Aura Shell Phase 0 entrypoint

%include "src/hal/linux_x86_64/defs.inc"

extern hal_write
extern hal_exit
extern hal_clock_gettime
extern arena_init
extern arena_destroy
extern input_queue_init
extern input_poll_event
extern window_create
extern window_process_events
extern window_should_close
extern window_destroy
extern repl_set_arena
extern repl_init
extern repl_handle_key
extern repl_render
extern repl_cursor_blink

section .text
global _start

%define INPUT_EVENT_TYPE_OFF            0
%define INPUT_EVENT_KEY_STATE_OFF       20
%define INPUT_KEY                       1
%define KEY_PRESSED                     1

%define BLINK_INTERVAL_NS               500000000

section .data
    app_title                           db "Aura Shell",0
    init_fail_msg                       db "aura-shell: init failed",10
    init_fail_len                       equ $ - init_fail_msg

section .bss
    main_arena_ptr                      resq 1
    main_window_ptr                     resq 1
    main_repl_ptr                       resq 1
    event_tmp                           resb 64
    ts_now                              resq 2
    ts_last_blink                       resq 2

section .text

main_sleep_1ms:
    sub rsp, 16
    mov qword [rsp + 0], 0
    mov qword [rsp + 8], 1000000
    mov rax, 35                         ; nanosleep
    mov rdi, rsp
    xor rsi, rsi
    syscall
    add rsp, 16
    ret

; rdi=timespec_ptr
; rax=nanoseconds
timespec_to_ns:
    mov rax, [rdi]
    imul rax, 1000000000
    add rax, [rdi + 8]
    ret

_start:
    ; 1) Memory arena
    mov rdi, 1048576
    call arena_init
    test rax, rax
    jz .fail
    mov [rel main_arena_ptr], rax

    ; 2) Input queue
    call input_queue_init

    ; 3) Window
    mov rdi, 1024
    mov rsi, 768
    lea rdx, [rel app_title]
    call window_create
    test rax, rax
    jz .fail_cleanup_arena
    mov [rel main_window_ptr], rax

    ; 4) REPL
    mov rdi, [rel main_arena_ptr]
    call repl_set_arena
    mov rdi, [rel main_window_ptr]
    call repl_init
    test rax, rax
    jz .fail_cleanup_window
    mov [rel main_repl_ptr], rax

    mov rdi, rax
    call repl_render

    ; blink baseline
    mov rdi, CLOCK_MONOTONIC
    lea rsi, [rel ts_last_blink]
    call hal_clock_gettime

.loop:
    mov rdi, [rel main_window_ptr]
    call window_process_events

.poll_input:
    lea rdi, [rel event_tmp]
    call input_poll_event
    cmp rax, 1
    jne .blink_check

    cmp dword [rel event_tmp + INPUT_EVENT_TYPE_OFF], INPUT_KEY
    jne .poll_input
    cmp dword [rel event_tmp + INPUT_EVENT_KEY_STATE_OFF], KEY_PRESSED
    jne .poll_input

    mov rdi, [rel main_repl_ptr]
    lea rsi, [rel event_tmp]
    call repl_handle_key
    mov rdi, [rel main_repl_ptr]
    call repl_render
    jmp .poll_input

.blink_check:
    mov rdi, CLOCK_MONOTONIC
    lea rsi, [rel ts_now]
    call hal_clock_gettime
    lea rdi, [rel ts_now]
    call timespec_to_ns
    mov r8, rax
    lea rdi, [rel ts_last_blink]
    call timespec_to_ns
    sub r8, rax
    cmp r8, BLINK_INTERVAL_NS
    jb .check_close

    mov rdi, 0
    mov rsi, 0
    mov rdx, [rel main_repl_ptr]
    call repl_cursor_blink
    mov rax, [rel ts_now]
    mov [rel ts_last_blink], rax
    mov rax, [rel ts_now + 8]
    mov [rel ts_last_blink + 8], rax

.check_close:
    mov rdi, [rel main_window_ptr]
    call window_should_close
    cmp rax, 1
    je .cleanup

    call main_sleep_1ms
    jmp .loop

.cleanup:
    mov rdi, [rel main_window_ptr]
    call window_destroy
    mov rdi, [rel main_arena_ptr]
    call arena_destroy
    xor rdi, rdi
    call hal_exit

.fail_cleanup_window:
    mov rdi, [rel main_window_ptr]
    test rdi, rdi
    jz .fail_cleanup_arena
    call window_destroy
.fail_cleanup_arena:
    mov rdi, [rel main_arena_ptr]
    test rdi, rdi
    jz .fail
    call arena_destroy
.fail:
    mov rdi, STDERR
    lea rsi, [rel init_fail_msg]
    mov rdx, init_fail_len
    call hal_write
    mov rdi, 1
    call hal_exit
