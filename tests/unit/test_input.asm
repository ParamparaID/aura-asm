; test_input.asm
; Interactive input test for Aura Shell (keyboard, mouse, touch)

extern hal_write
extern hal_exit
extern window_create
extern window_get_canvas
extern window_process_events
extern window_should_close
extern window_present
extern window_destroy
extern canvas_clear
extern canvas_fill_rect
extern canvas_draw_char
extern input_poll_event
extern wayland_keycode_to_ascii

%define INPUT_EVENT_TYPE_OFF            0
%define INPUT_EVENT_KEY_CODE_OFF        16
%define INPUT_EVENT_KEY_STATE_OFF       20
%define INPUT_EVENT_MODIFIERS_OFF       24
%define INPUT_EVENT_MOUSE_X_OFF         28
%define INPUT_EVENT_MOUSE_Y_OFF         32

%define INPUT_KEY                       1
%define INPUT_MOUSE_MOVE                2
%define INPUT_TOUCH_DOWN                4
%define INPUT_TOUCH_MOVE                6

%define KEY_PRESSED                     1
%define KEY_ESC                         1

section .data
    title               db "Aura Shell Input Test",0
    info_msg            db "test_input: type keys, move mouse, touch screen, press ESC to exit",10
    info_len            equ $ - info_msg
    fail_msg            db "test_input: window create failed",10
    fail_len            equ $ - fail_msg

section .bss
    wnd_ptr             resq 1
    cv_ptr              resq 1
    event_buf           resb 64
    cursor_x            resd 1
    cursor_y            resd 1
    should_quit         resd 1
    need_present        resd 1

section .text
global _start

_start:
    mov rdi, 1
    lea rsi, [rel info_msg]
    mov rdx, info_len
    call hal_write

    mov dword [rel cursor_x], 16
    mov dword [rel cursor_y], 24
    mov dword [rel should_quit], 0
    mov dword [rel need_present], 0

    mov rdi, 960
    mov rsi, 640
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

    mov rdi, rax
    mov rsi, 0xFF101014
    call canvas_clear
    mov rdi, [rel wnd_ptr]
    call window_present

.main_loop:
    mov rdi, [rel wnd_ptr]
    call window_process_events

    mov rdi, [rel wnd_ptr]
    call window_should_close
    cmp rax, 1
    je .cleanup

.poll_loop:
    lea rdi, [rel event_buf]
    call input_poll_event
    cmp rax, 1
    jne .after_poll

    mov eax, [rel event_buf + INPUT_EVENT_TYPE_OFF]
    cmp eax, INPUT_KEY
    je .handle_key
    cmp eax, INPUT_MOUSE_MOVE
    je .handle_mouse_move
    cmp eax, INPUT_TOUCH_DOWN
    je .handle_touch_down
    cmp eax, INPUT_TOUCH_MOVE
    je .handle_touch_move
    jmp .poll_loop

.handle_key:
    cmp dword [rel event_buf + INPUT_EVENT_KEY_STATE_OFF], KEY_PRESSED
    jne .poll_loop
    mov eax, [rel event_buf + INPUT_EVENT_KEY_CODE_OFF]
    cmp eax, KEY_ESC
    jne .draw_char
    mov dword [rel should_quit], 1
    jmp .after_poll

.draw_char:
    mov edi, [rel event_buf + INPUT_EVENT_KEY_CODE_OFF]
    mov esi, [rel event_buf + INPUT_EVENT_MODIFIERS_OFF]
    call wayland_keycode_to_ascii
    test al, al
    jz .poll_loop

    cmp al, 10
    jne .not_newline
    mov dword [rel cursor_x], 16
    add dword [rel cursor_y], 16
    jmp .present_mark
.not_newline:
    cmp al, 8
    jne .render_char
    cmp dword [rel cursor_x], 16
    jle .poll_loop
    sub dword [rel cursor_x], 8
    mov rdi, [rel cv_ptr]
    movsx rsi, dword [rel cursor_x]
    movsx rdx, dword [rel cursor_y]
    mov rcx, 8
    mov r8, 16
    mov r9, 0xFF101014
    call canvas_fill_rect
    jmp .present_mark

.render_char:
    mov rdi, [rel cv_ptr]
    movsx rsi, dword [rel cursor_x]
    movsx rdx, dword [rel cursor_y]
    movzx ecx, al
    mov r8, 0xFFFFFFFF
    mov r9, 0
    call canvas_draw_char
    add dword [rel cursor_x], 8
    cmp dword [rel cursor_x], 936
    jle .present_mark
    mov dword [rel cursor_x], 16
    add dword [rel cursor_y], 16

.present_mark:
    mov dword [rel need_present], 1
    jmp .poll_loop

.handle_mouse_move:
    mov rdi, [rel cv_ptr]
    movsx rsi, dword [rel event_buf + INPUT_EVENT_MOUSE_X_OFF]
    movsx rdx, dword [rel event_buf + INPUT_EVENT_MOUSE_Y_OFF]
    mov rcx, 4
    mov r8, 4
    mov r9, 0xFF35C759
    call canvas_fill_rect
    mov dword [rel need_present], 1
    jmp .poll_loop

.handle_touch_down:
    mov rdi, [rel cv_ptr]
    movsx rsi, dword [rel event_buf + INPUT_EVENT_MOUSE_X_OFF]
    movsx rdx, dword [rel event_buf + INPUT_EVENT_MOUSE_Y_OFF]
    mov rcx, 8
    mov r8, 8
    mov r9, 0xFFFF453A
    call canvas_fill_rect
    mov dword [rel need_present], 1
    jmp .poll_loop

.handle_touch_move:
    mov rdi, [rel cv_ptr]
    movsx rsi, dword [rel event_buf + INPUT_EVENT_MOUSE_X_OFF]
    movsx rdx, dword [rel event_buf + INPUT_EVENT_MOUSE_Y_OFF]
    mov rcx, 6
    mov r8, 6
    mov r9, 0xFFFF9F0A
    call canvas_fill_rect
    mov dword [rel need_present], 1
    jmp .poll_loop

.after_poll:
    cmp dword [rel need_present], 0
    je .check_quit
    mov dword [rel need_present], 0
    mov rdi, [rel wnd_ptr]
    call window_present

.check_quit:
    cmp dword [rel should_quit], 1
    je .cleanup
    jmp .main_loop

.cleanup:
    mov rdi, [rel wnd_ptr]
    call window_destroy
    xor rdi, rdi
    call hal_exit

.fail:
    mov rdi, 1
    lea rsi, [rel fail_msg]
    mov rdx, fail_len
    call hal_write
    mov rdi, 1
    call hal_exit
