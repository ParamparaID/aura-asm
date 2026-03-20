; test_window.asm
; Wayland window smoke test for Aura Shell
; Author: Aura Shell Team
; Date: 2026-03-20

extern hal_write
extern hal_exit
extern hal_clock_gettime
extern window_create
extern window_present
extern window_get_canvas
extern window_process_events
extern window_should_close
extern window_destroy
extern canvas_clear
extern canvas_fill_rect
extern canvas_draw_string

%define CLOCK_MONOTONIC 1

section .data
    title            db "Aura Shell",0
    text             db "Aura Shell"
    text_len         equ $ - text
    info_msg         db "test_window: trying to open window...",10
    info_len         equ $ - info_msg
    fail_msg         db "test_window: unable to open window",10
    fail_len         equ $ - fail_msg
    done_msg         db "test_window: done",10
    done_len         equ $ - done_msg

section .bss
    wnd_ptr          resq 1
    cv_ptr           resq 1
    ts_start         resq 2
    ts_now           resq 2

section .text
global _start

_start:
    mov rdi, 1
    lea rsi, [rel info_msg]
    mov rdx, info_len
    call hal_write

    mov rdi, 800
    mov rsi, 600
    lea rdx, [rel title]
    call window_create
    test rax, rax
    jz .fail
    mov [rel wnd_ptr], rax

    mov rdi, rax
    call window_get_canvas
    test rax, rax
    jz .cleanup
    mov [rel cv_ptr], rax

    ; dark blue background
    mov rdi, rax
    mov rsi, 0xFF0D1B2A
    call canvas_clear

    ; center white rectangle
    mov rdi, [rel cv_ptr]
    mov rsi, 200
    mov rdx, 220
    mov rcx, 400
    mov r8, 160
    mov r9, 0xFFFFFFFF
    call canvas_fill_rect

    ; draw text
    mov rdi, [rel cv_ptr]
    mov rsi, 300
    mov rdx, 285
    lea rcx, [rel text]
    mov r8, text_len
    mov r9, 0xFF000000
    sub rsp, 8
    xor rax, rax
    mov eax, 0xFFFFFFFF
    mov [rsp], rax
    call canvas_draw_string
    add rsp, 8

    mov rdi, [rel wnd_ptr]
    call window_present

    mov rdi, CLOCK_MONOTONIC
    lea rsi, [rel ts_start]
    call hal_clock_gettime

.loop:
    mov rdi, [rel wnd_ptr]
    call window_process_events
    mov rdi, [rel wnd_ptr]
    call window_should_close
    cmp rax, 1
    je .cleanup

    mov rdi, CLOCK_MONOTONIC
    lea rsi, [rel ts_now]
    call hal_clock_gettime
    mov rax, [rel ts_now]
    sub rax, [rel ts_start]
    cmp rax, 3
    jb .loop

.cleanup:
    mov rdi, [rel wnd_ptr]
    call window_destroy
    mov rdi, 1
    lea rsi, [rel done_msg]
    mov rdx, done_len
    call hal_write
    xor rdi, rdi
    call hal_exit

.fail:
    mov rdi, 1
    lea rsi, [rel fail_msg]
    mov rdx, fail_len
    call hal_write
    mov rdi, 1
    call hal_exit
