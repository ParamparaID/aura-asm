; test_win64_window.asm — STEP 61A: Win32 window + DIB + red canvas, ~2s then close
%include "src/hal/win_x86_64/defs.inc"
%include "src/canvas/canvas.inc"

extern bootstrap_init
extern input_queue_init
extern hal_write
extern hal_exit
extern hal_sleep_ms
extern window_create_win32
extern window_get_canvas
extern window_present_win32
extern window_process_events
extern window_should_close
extern window_destroy
extern canvas_clear

%define RED_ARGB                   0xFFFF0000

section .data
    win_title      db "STEP 61A Aura Window", 0
    msg_pass       db "ALL TESTS PASSED", 13, 10
    msg_pass_len   equ $ - msg_pass
    msg_fail       db "TEST FAILED", 13, 10
    msg_fail_len   equ $ - msg_fail

section .bss
    wnd_ptr        resq 1

section .text
global _start
_start:
    sub rsp, 8
    call bootstrap_init
    cmp eax, 1
    jne .fail

    call input_queue_init

    mov rdi, 640
    mov rsi, 480
    lea rdx, [rel win_title]
    call window_create_win32
    test rax, rax
    jz .fail
    mov [rel wnd_ptr], rax

    mov rdi, rax
    call window_get_canvas
    test rax, rax
    jz .fail_close
    mov rdi, rax
    mov esi, RED_ARGB
    call canvas_clear

    mov rdi, [rel wnd_ptr]
    call window_present_win32
    cmp eax, 0
    jne .fail_close

    ; Visible for ~2s while servicing the message queue
    mov r12d, 40
.pump:
    mov rdi, [rel wnd_ptr]
    call window_process_events
    mov edi, 50
    call hal_sleep_ms
    mov rdi, [rel wnd_ptr]
    call window_should_close
    test eax, eax
    jnz .done_ok
    dec r12d
    jnz .pump

.done_ok:
    mov rdi, [rel wnd_ptr]
    call window_destroy
    cmp eax, 0
    jne .fail

    mov rdi, STDOUT
    lea rsi, [rel msg_pass]
    mov rdx, msg_pass_len
    call hal_write
    xor edi, edi
    call hal_exit

.fail_close:
    mov rdi, [rel wnd_ptr]
    test rdi, rdi
    jz .fail
    call window_destroy
.fail:
    mov rdi, STDOUT
    lea rsi, [rel msg_fail]
    mov rdx, msg_fail_len
    call hal_write
    mov edi, 1
    call hal_exit
