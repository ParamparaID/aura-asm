; test_gesture.asm — tap, swipe, long press
%include "src/hal/linux_x86_64/defs.inc"
%include "src/core/gesture.inc"

extern hal_write
extern hal_exit
extern gesture_init
extern gesture_process_event
extern gesture_reset

section .bss
    gr          resb GR_STRUCT_SIZE
    event_buf   resb 64

section .rodata
    pass_msg db "ALL TESTS PASSED", 10
    pass_len equ $ - pass_msg
    f1       db "FAIL:1", 10
    f1l      equ $ - f1
    f2       db "FAIL:2", 10
    f2l      equ $ - f2
    f3       db "FAIL:3", 10
    f3l      equ $ - f3
    f4       db "FAIL:4", 10
    f4l      equ $ - f4

section .text
global _start

%macro fail_exit 2
    mov rdi, 1
    lea rsi, [rel %1]
    mov rdx, %2
    call hal_write
    mov rdi, 1
    call hal_exit
%endmacro

%macro write_stdout 2
    mov rdi, 1
    lea rsi, [rel %1]
    mov rdx, %2
    call hal_write
%endmacro

_start:
    lea rdi, [rel gr]
    call gesture_init

    ; --- Tap ---
    lea rdi, [rel event_buf]
    xor eax, eax
    mov ecx, 16
    rep stosb
    lea rdi, [rel event_buf]
    mov dword [rdi + INPUT_EVENT_TYPE_OFF], INPUT_TOUCH_DOWN
    mov qword [rdi + INPUT_EVENT_TIMESTAMP_OFF], 0
    mov dword [rdi + INPUT_EVENT_MOUSE_X_OFF], 100
    mov dword [rdi + INPUT_EVENT_MOUSE_Y_OFF], 100
    mov dword [rdi + INPUT_EVENT_TOUCH_ID_OFF], 0
    lea rdi, [rel gr]
    lea rsi, [rel event_buf]
    call gesture_process_event

    lea rdi, [rel event_buf]
    mov dword [rdi + INPUT_EVENT_TYPE_OFF], INPUT_TOUCH_UP
    mov qword [rdi + INPUT_EVENT_TIMESTAMP_OFF], 50
    mov dword [rdi + INPUT_EVENT_MOUSE_X_OFF], 102
    mov dword [rdi + INPUT_EVENT_MOUSE_Y_OFF], 101
    mov dword [rdi + INPUT_EVENT_TOUCH_ID_OFF], 0
    lea rdi, [rel gr]
    lea rsi, [rel event_buf]
    call gesture_process_event
    cmp eax, GESTURE_TAP
    jne .e1

    ; --- Swipe right ---
    lea rdi, [rel gr]
    call gesture_reset
    lea rdi, [rel event_buf]
    mov dword [rdi + INPUT_EVENT_TYPE_OFF], INPUT_TOUCH_DOWN
    mov qword [rdi + INPUT_EVENT_TIMESTAMP_OFF], 1000
    mov dword [rdi + INPUT_EVENT_MOUSE_X_OFF], 100
    mov dword [rdi + INPUT_EVENT_MOUSE_Y_OFF], 100
    mov dword [rdi + INPUT_EVENT_TOUCH_ID_OFF], 0
    lea rdi, [rel gr]
    lea rsi, [rel event_buf]
    call gesture_process_event

    lea rdi, [rel event_buf]
    mov dword [rdi + INPUT_EVENT_TYPE_OFF], INPUT_TOUCH_MOVE
    mov qword [rdi + INPUT_EVENT_TIMESTAMP_OFF], 1100
    mov dword [rdi + INPUT_EVENT_MOUSE_X_OFF], 200
    mov dword [rdi + INPUT_EVENT_MOUSE_Y_OFF], 105
    lea rdi, [rel gr]
    lea rsi, [rel event_buf]
    call gesture_process_event

    lea rdi, [rel event_buf]
    mov dword [rdi + INPUT_EVENT_TYPE_OFF], INPUT_TOUCH_UP
    mov qword [rdi + INPUT_EVENT_TIMESTAMP_OFF], 1200
    mov dword [rdi + INPUT_EVENT_MOUSE_X_OFF], 200
    mov dword [rdi + INPUT_EVENT_MOUSE_Y_OFF], 105
    mov dword [rdi + INPUT_EVENT_TOUCH_ID_OFF], 0
    lea rdi, [rel gr]
    lea rsi, [rel event_buf]
    call gesture_process_event
    cmp eax, GESTURE_SWIPE_RIGHT
    jne .e2

    ; --- Long press ---
    lea rdi, [rel gr]
    call gesture_reset
    lea rdi, [rel event_buf]
    mov dword [rdi + INPUT_EVENT_TYPE_OFF], INPUT_TOUCH_DOWN
    mov qword [rdi + INPUT_EVENT_TIMESTAMP_OFF], 2000
    mov dword [rdi + INPUT_EVENT_MOUSE_X_OFF], 100
    mov dword [rdi + INPUT_EVENT_MOUSE_Y_OFF], 100
    mov dword [rdi + INPUT_EVENT_TOUCH_ID_OFF], 0
    lea rdi, [rel gr]
    lea rsi, [rel event_buf]
    call gesture_process_event

    lea rdi, [rel event_buf]
    mov dword [rdi + INPUT_EVENT_TYPE_OFF], INPUT_TOUCH_MOVE
    mov qword [rdi + INPUT_EVENT_TIMESTAMP_OFF], 2700
    mov dword [rdi + INPUT_EVENT_MOUSE_X_OFF], 100
    mov dword [rdi + INPUT_EVENT_MOUSE_Y_OFF], 100
    lea rdi, [rel gr]
    lea rsi, [rel event_buf]
    call gesture_process_event
    cmp eax, GESTURE_LONG_PRESS
    jne .e3

    ; --- Not a tap (large move on up) ---
    lea rdi, [rel gr]
    call gesture_reset
    lea rdi, [rel event_buf]
    mov dword [rdi + INPUT_EVENT_TYPE_OFF], INPUT_TOUCH_DOWN
    mov qword [rdi + INPUT_EVENT_TIMESTAMP_OFF], 3000
    mov dword [rdi + INPUT_EVENT_MOUSE_X_OFF], 100
    mov dword [rdi + INPUT_EVENT_MOUSE_Y_OFF], 100
    mov dword [rdi + INPUT_EVENT_TOUCH_ID_OFF], 0
    lea rdi, [rel gr]
    lea rsi, [rel event_buf]
    call gesture_process_event

    lea rdi, [rel event_buf]
    mov dword [rdi + INPUT_EVENT_TYPE_OFF], INPUT_TOUCH_UP
    mov qword [rdi + INPUT_EVENT_TIMESTAMP_OFF], 3050
    mov dword [rdi + INPUT_EVENT_MOUSE_X_OFF], 200
    mov dword [rdi + INPUT_EVENT_MOUSE_Y_OFF], 200
    mov dword [rdi + INPUT_EVENT_TOUCH_ID_OFF], 0
    lea rdi, [rel gr]
    lea rsi, [rel event_buf]
    call gesture_process_event
    cmp eax, GESTURE_TAP
    je .e4

    write_stdout pass_msg, pass_len
    xor rdi, rdi
    call hal_exit

.e1:
    fail_exit f1, f1l
.e2:
    fail_exit f2, f2l
.e3:
    fail_exit f3, f3l
.e4:
    fail_exit f4, f4l
