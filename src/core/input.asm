; input.asm
; Unified input queue for Aura Shell (keyboard, pointer, touch)

section .text
global input_queue_init
global input_push_event
global input_poll_event
global input_peek_event

; InputEvent (64 bytes)
%define INPUT_EVENT_TYPE_OFF            0   ; dd
%define INPUT_EVENT_TIMESTAMP_OFF       8   ; dq
%define INPUT_EVENT_KEY_CODE_OFF        16  ; dd
%define INPUT_EVENT_KEY_STATE_OFF       20  ; dd
%define INPUT_EVENT_MODIFIERS_OFF       24  ; dd
%define INPUT_EVENT_MOUSE_X_OFF         28  ; dd
%define INPUT_EVENT_MOUSE_Y_OFF         32  ; dd
%define INPUT_EVENT_SCROLL_DX_OFF       36  ; dd
%define INPUT_EVENT_SCROLL_DY_OFF       40  ; dd
%define INPUT_EVENT_TOUCH_ID_OFF        44  ; dd
%define INPUT_EVENT_RESERVED_OFF        48  ; 16 bytes
%define INPUT_EVENT_SIZE                64

; Event types
%define INPUT_KEY                       1
%define INPUT_MOUSE_MOVE                2
%define INPUT_MOUSE_BUTTON              3
%define INPUT_TOUCH_DOWN                4
%define INPUT_TOUCH_UP                  5
%define INPUT_TOUCH_MOVE                6
%define INPUT_SCROLL                    7

; Modifiers
%define MOD_SHIFT                       0x01
%define MOD_CTRL                        0x02
%define MOD_ALT                         0x04
%define MOD_SUPER                       0x08

; Key state
%define KEY_RELEASED                    0
%define KEY_PRESSED                     1

; Mouse buttons (Linux input)
%define MOUSE_LEFT                      0x110
%define MOUSE_RIGHT                     0x111
%define MOUSE_MIDDLE                    0x112

%define INPUT_QUEUE_CAPACITY            256
%define INPUT_QUEUE_MASK                (INPUT_QUEUE_CAPACITY - 1)

section .bss
    input_queue_head                    resq 1
    input_queue_tail                    resq 1
    input_queue_buf                     resb INPUT_QUEUE_CAPACITY * INPUT_EVENT_SIZE

section .text

; input_queue_init()
; Return: rax=0
input_queue_init:
    mov qword [rel input_queue_head], 0
    mov qword [rel input_queue_tail], 0
    xor eax, eax
    ret

; input_push_event(event_ptr)
; Params: rdi=InputEvent*
; Return: rax=1 success, 0 full/invalid
input_push_event:
    push rbx
    push r12
    push r13

    test rdi, rdi
    jz .fail

    mov r12, [rel input_queue_head]
    mov r13, [rel input_queue_tail]
    mov r11, r12
    inc r11
    and r11, INPUT_QUEUE_MASK
    cmp r11, r13
    je .fail

    mov rbx, r12
    shl rbx, 6                         ; * 64
    lea rax, [rel input_queue_buf]
    add rbx, rax

    ; copy 64 bytes
    mov rax, [rdi + 0]
    mov [rbx + 0], rax
    mov rax, [rdi + 8]
    mov [rbx + 8], rax
    mov rax, [rdi + 16]
    mov [rbx + 16], rax
    mov rax, [rdi + 24]
    mov [rbx + 24], rax
    mov rax, [rdi + 32]
    mov [rbx + 32], rax
    mov rax, [rdi + 40]
    mov [rbx + 40], rax
    mov rax, [rdi + 48]
    mov [rbx + 48], rax
    mov rax, [rdi + 56]
    mov [rbx + 56], rax

    mov [rel input_queue_head], r11

    mov eax, 1
    jmp .ret
.fail:
    xor eax, eax
.ret:
    pop r13
    pop r12
    pop rbx
    ret

; input_poll_event(event_out_ptr)
; Params: rdi=InputEvent* out
; Return: rax=1 event copied, 0 queue empty/invalid
input_poll_event:
    test rdi, rdi
    jz .empty

    mov r8, [rel input_queue_head]
    mov r9, [rel input_queue_tail]
    cmp r8, r9
    je .empty

    mov r10, r9
    shl r10, 6
    lea rax, [rel input_queue_buf]
    add r10, rax

    mov rax, [r10 + 0]
    mov [rdi + 0], rax
    mov rax, [r10 + 8]
    mov [rdi + 8], rax
    mov rax, [r10 + 16]
    mov [rdi + 16], rax
    mov rax, [r10 + 24]
    mov [rdi + 24], rax
    mov rax, [r10 + 32]
    mov [rdi + 32], rax
    mov rax, [r10 + 40]
    mov [rdi + 40], rax
    mov rax, [r10 + 48]
    mov [rdi + 48], rax
    mov rax, [r10 + 56]
    mov [rdi + 56], rax

    inc r9
    and r9, INPUT_QUEUE_MASK
    mfence
    mov [rel input_queue_tail], r9
    mov eax, 1
    ret
.empty:
    xor eax, eax
    ret

; input_peek_event(event_out_ptr)
; Params: rdi=InputEvent* out
; Return: rax=1 event copied, 0 queue empty/invalid
input_peek_event:
    test rdi, rdi
    jz .empty

    mov r8, [rel input_queue_head]
    mov r9, [rel input_queue_tail]
    cmp r8, r9
    je .empty

    mov r10, r9
    shl r10, 6
    lea rax, [rel input_queue_buf]
    add r10, rax

    mov rax, [r10 + 0]
    mov [rdi + 0], rax
    mov rax, [r10 + 8]
    mov [rdi + 8], rax
    mov rax, [r10 + 16]
    mov [rdi + 16], rax
    mov rax, [r10 + 24]
    mov [rdi + 24], rax
    mov rax, [r10 + 32]
    mov [rdi + 32], rax
    mov rax, [r10 + 40]
    mov [rdi + 40], rax
    mov rax, [r10 + 48]
    mov [rdi + 48], rax
    mov rax, [r10 + 56]
    mov [rdi + 56], rax

    mov eax, 1
    ret
.empty:
    xor eax, eax
    ret
