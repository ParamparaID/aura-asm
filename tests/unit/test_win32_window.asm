; test_win32_window.asm - Win32 window + input + process smoke
%include "src/hal/win_x86_64/defs.inc"
%include "src/canvas/canvas.inc"
%define INPUT_KEY 1

extern bootstrap_init
extern hal_write
extern hal_exit
extern hal_sleep_ms
extern window_create_win32
extern window_get_canvas
extern window_present_win32
extern window_process_events
extern window_should_close
extern window_destroy
extern window_send_test_keydown
extern input_poll_event
extern win_capture_cmd_output

section .data
    msg_pass       db "ALL TESTS PASSED",13,10
    msg_pass_len   equ $ - msg_pass
    msg_fail       db "TEST FAILED: win32 window",13,10
    msg_fail_len   equ $ - msg_fail
    title          db "Aura Win32",0
    cmd_echo       db "cmd.exe /c echo test",0

section .bss
    wnd_ptr        resq 1
    cv_ptr         resq 1
    ev_buf         resb 64
    out_buf        resb 256

section .text
global _start

fail:
    mov rdi, 1
    lea rsi, [rel msg_fail]
    mov rdx, msg_fail_len
    call hal_write
    mov edi, 1
    call hal_exit

_start:
    ; Win64 ABI: stabilize entry stack alignment for nested WinAPI calls.
    push rbx
    call bootstrap_init
    cmp eax, 1
    jne fail

    ; Test 1: create/present red frame
    mov rdi, 640
    mov rsi, 360
    lea rdx, [rel title]
    call window_create_win32
    test rax, rax
    jz fail
    cmp qword [rax + 0], 0
    je fail
    mov [rel wnd_ptr], rax
    mov rdi, [rel wnd_ptr]
    call window_present_win32
    cmp eax, 0
    jne fail

    ; pump messages shortly
    mov r14d, 6
.pump:
    mov rdi, [rel wnd_ptr]
    call window_process_events
    cmp eax, 0
    jne fail
    mov edi, 50
    call hal_sleep_ms
    dec r14d
    jnz .pump

    ; Test 2: key input via SendMessageA helper
    mov rdi, [rel wnd_ptr]
    mov esi, VK_RETURN
    call window_send_test_keydown
    mov r14d, 3
.pump2:
    mov rdi, [rel wnd_ptr]
    call window_process_events
    mov edi, 20
    call hal_sleep_ms
    dec r14d
    jnz .pump2
    lea rdi, [rel ev_buf]
    call input_poll_event
    cmp eax, 1
    jne fail
    cmp dword [rel ev_buf + 0], INPUT_KEY
    jne fail

    ; Test 3: CreateProcess capture stdout
    lea rdi, [rel cmd_echo]
    lea rsi, [rel out_buf]
    mov edx, 255
    call win_capture_cmd_output
    cmp eax, 0
    jle fail

    mov rdi, [rel wnd_ptr]
    call window_destroy
    cmp eax, 0
    jne fail

    mov rdi, 1
    lea rsi, [rel msg_pass]
    mov rdx, msg_pass_len
    call hal_write
    xor edi, edi
    call hal_exit
