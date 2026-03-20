; wayland_input.asm
; Wayland input abstraction layer for Aura Shell

extern wl_send
extern wl_registry_bind
extern input_queue_init
extern input_push_event

section .text
global wayland_input_init
global wayland_input_handle_registry_global
global wayland_input_handle_message
global wayland_keycode_to_ascii

%define IFACE_SEAT                       4

%define WL_SEAT_CAP_POINTER              0x1
%define WL_SEAT_CAP_KEYBOARD             0x2
%define WL_SEAT_CAP_TOUCH                0x4

%define W_SOCK_FD_OFF                    0
%define W_NEXT_ID_OFF                    88
%define W_REGISTRY_ID_OFF                92
%define W_SEAT_ID_OFF                    120
%define W_KEYBOARD_ID_OFF                124
%define W_POINTER_ID_OFF                 128
%define W_TOUCH_ID_OFF                   132
%define W_CURRENT_MODIFIERS_OFF          136

%define INPUT_EVENT_TYPE_OFF             0
%define INPUT_EVENT_TIMESTAMP_OFF        8
%define INPUT_EVENT_KEY_CODE_OFF         16
%define INPUT_EVENT_KEY_STATE_OFF        20
%define INPUT_EVENT_MODIFIERS_OFF        24
%define INPUT_EVENT_MOUSE_X_OFF          28
%define INPUT_EVENT_MOUSE_Y_OFF          32
%define INPUT_EVENT_SCROLL_DX_OFF        36
%define INPUT_EVENT_SCROLL_DY_OFF        40
%define INPUT_EVENT_TOUCH_ID_OFF         44

%define INPUT_KEY                        1
%define INPUT_MOUSE_MOVE                 2
%define INPUT_MOUSE_BUTTON               3
%define INPUT_TOUCH_DOWN                 4
%define INPUT_TOUCH_UP                   5
%define INPUT_TOUCH_MOVE                 6
%define INPUT_SCROLL                     7

%define MOD_SHIFT                        0x01
%define MOD_CTRL                         0x02
%define MOD_ALT                          0x04
%define MOD_SUPER                        0x08

section .data
    iface_name_seat                      db "wl_seat",0

section .bss
    wl_input_tmp_buf                     resb 64
    wl_input_event_tmp                   resb 64

section .text

; rdi=sender_id, rsi=opcode, rdx=size
; eax=(size<<16)|opcode
wayland_pack_opcode_size:
    shl edx, 16
    and esi, 0xFFFF
    mov eax, edx
    or eax, esi
    ret

; wl_seat.get_pointer(fd, seat_id, pointer_id)
; rdi=fd, esi=seat_id, edx=pointer_id
wayland_seat_get_pointer:
    mov r10, rdi
    mov r11d, esi
    mov r12d, edx
    mov edi, r11d
    xor esi, esi
    mov edx, 12
    call wayland_pack_opcode_size
    lea r8, [rel wl_input_tmp_buf]
    mov dword [r8 + 0], r11d
    mov dword [r8 + 4], eax
    mov dword [r8 + 8], r12d
    mov rdi, r10
    mov rsi, r8
    mov rdx, 12
    jmp wl_send

; wl_seat.get_keyboard(fd, seat_id, keyboard_id)
; rdi=fd, esi=seat_id, edx=keyboard_id
wayland_seat_get_keyboard:
    mov r10, rdi
    mov r11d, esi
    mov r12d, edx
    mov edi, r11d
    mov esi, 1
    mov edx, 12
    call wayland_pack_opcode_size
    lea r8, [rel wl_input_tmp_buf]
    mov dword [r8 + 0], r11d
    mov dword [r8 + 4], eax
    mov dword [r8 + 8], r12d
    mov rdi, r10
    mov rsi, r8
    mov rdx, 12
    jmp wl_send

; wl_seat.get_touch(fd, seat_id, touch_id)
; rdi=fd, esi=seat_id, edx=touch_id
wayland_seat_get_touch:
    mov r10, rdi
    mov r11d, esi
    mov r12d, edx
    mov edi, r11d
    mov esi, 2
    mov edx, 12
    call wayland_pack_opcode_size
    lea r8, [rel wl_input_tmp_buf]
    mov dword [r8 + 0], r11d
    mov dword [r8 + 4], eax
    mov dword [r8 + 8], r12d
    mov rdi, r10
    mov rsi, r8
    mov rdx, 12
    jmp wl_send

; zero temporary InputEvent in wl_input_event_tmp
wayland_input_clear_event:
    lea rax, [rel wl_input_event_tmp]
    mov qword [rax + 0], 0
    mov qword [rax + 8], 0
    mov qword [rax + 16], 0
    mov qword [rax + 24], 0
    mov qword [rax + 32], 0
    mov qword [rax + 40], 0
    mov qword [rax + 48], 0
    mov qword [rax + 56], 0
    ret

; rdi=Window*
; Return: rax=0
wayland_input_init:
    test rdi, rdi
    jz .ret
    mov dword [rdi + W_CURRENT_MODIFIERS_OFF], 0
    call input_queue_init
.ret:
    xor eax, eax
    ret

; wayland_input_handle_registry_global(window_ptr, name_u32, iface_ptr, iface_len, version)
; Params: rdi=Window*, esi=name, rdx=iface_ptr, ecx=iface_len, r8d=version
; Return: rax=1 handled, 0 not handled
wayland_input_handle_registry_global:
    push rbx
    push r12
    push r13
    push r14

    test rdi, rdi
    jz .no
    mov rbx, rdi
    mov r12d, esi
    mov r13, rdx
    mov r14d, ecx

    cmp r14d, 7
    jne .no
    mov al, [r13 + 0]
    cmp al, 'w'
    jne .no
    mov al, [r13 + 1]
    cmp al, 'l'
    jne .no
    mov al, [r13 + 2]
    cmp al, '_'
    jne .no
    mov al, [r13 + 3]
    cmp al, 's'
    jne .no
    mov al, [r13 + 4]
    cmp al, 'e'
    jne .no
    mov al, [r13 + 5]
    cmp al, 'a'
    jne .no
    mov al, [r13 + 6]
    cmp al, 't'
    jne .no

    cmp dword [rbx + W_SEAT_ID_OFF], 0
    jne .yes

    mov eax, [rbx + W_NEXT_ID_OFF]
    mov dword [rbx + W_SEAT_ID_OFF], eax
    inc dword [rbx + W_NEXT_ID_OFF]

    mov rdi, [rbx + W_SOCK_FD_OFF]
    mov esi, [rbx + W_REGISTRY_ID_OFF]
    mov edx, r12d
    mov ecx, IFACE_SEAT
    mov r9d, [rbx + W_SEAT_ID_OFF]
    cmp r8d, 7
    jbe .bind_ver_ok
    mov r8d, 7
.bind_ver_ok:
    call wl_registry_bind
    jmp .yes

.no:
    xor eax, eax
    jmp .ret
.yes:
    mov eax, 1
.ret:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; wayland_keycode_to_ascii(keycode, modifiers)
; Params: rdi=keycode, rsi=modifiers
; Return: al=ascii or 0 (non-printable)
wayland_keycode_to_ascii:
    mov eax, edi
    mov r8d, esi

    ; letters A..Z (evdev 30..55 with gaps)
    cmp eax, 30
    je .letter_a
    cmp eax, 48
    je .letter_b
    cmp eax, 46
    je .letter_c
    cmp eax, 32
    je .letter_d
    cmp eax, 18
    je .letter_e
    cmp eax, 33
    je .letter_f
    cmp eax, 34
    je .letter_g
    cmp eax, 35
    je .letter_h
    cmp eax, 23
    je .letter_i
    cmp eax, 36
    je .letter_j
    cmp eax, 37
    je .letter_k
    cmp eax, 38
    je .letter_l
    cmp eax, 50
    je .letter_m
    cmp eax, 49
    je .letter_n
    cmp eax, 24
    je .letter_o
    cmp eax, 25
    je .letter_p
    cmp eax, 16
    je .letter_q
    cmp eax, 19
    je .letter_r
    cmp eax, 31
    je .letter_s
    cmp eax, 20
    je .letter_t
    cmp eax, 22
    je .letter_u
    cmp eax, 47
    je .letter_v
    cmp eax, 17
    je .letter_w
    cmp eax, 45
    je .letter_x
    cmp eax, 21
    je .letter_y
    cmp eax, 44
    je .letter_z

    ; digits 1..0
    cmp eax, 2
    je .digit_1
    cmp eax, 3
    je .digit_2
    cmp eax, 4
    je .digit_3
    cmp eax, 5
    je .digit_4
    cmp eax, 6
    je .digit_5
    cmp eax, 7
    je .digit_6
    cmp eax, 8
    je .digit_7
    cmp eax, 9
    je .digit_8
    cmp eax, 10
    je .digit_9
    cmp eax, 11
    je .digit_0

    cmp eax, 57
    je .space
    cmp eax, 28
    je .enter
    cmp eax, 14
    je .backspace
    cmp eax, 15
    je .tab
    cmp eax, 1
    je .esc
    xor eax, eax
    ret

.letter_a: mov al, 'a'  ; fallthrough shared shift path
    jmp .letter_shift
.letter_b: mov al, 'b'
    jmp .letter_shift
.letter_c: mov al, 'c'
    jmp .letter_shift
.letter_d: mov al, 'd'
    jmp .letter_shift
.letter_e: mov al, 'e'
    jmp .letter_shift
.letter_f: mov al, 'f'
    jmp .letter_shift
.letter_g: mov al, 'g'
    jmp .letter_shift
.letter_h: mov al, 'h'
    jmp .letter_shift
.letter_i: mov al, 'i'
    jmp .letter_shift
.letter_j: mov al, 'j'
    jmp .letter_shift
.letter_k: mov al, 'k'
    jmp .letter_shift
.letter_l: mov al, 'l'
    jmp .letter_shift
.letter_m: mov al, 'm'
    jmp .letter_shift
.letter_n: mov al, 'n'
    jmp .letter_shift
.letter_o: mov al, 'o'
    jmp .letter_shift
.letter_p: mov al, 'p'
    jmp .letter_shift
.letter_q: mov al, 'q'
    jmp .letter_shift
.letter_r: mov al, 'r'
    jmp .letter_shift
.letter_s: mov al, 's'
    jmp .letter_shift
.letter_t: mov al, 't'
    jmp .letter_shift
.letter_u: mov al, 'u'
    jmp .letter_shift
.letter_v: mov al, 'v'
    jmp .letter_shift
.letter_w: mov al, 'w'
    jmp .letter_shift
.letter_x: mov al, 'x'
    jmp .letter_shift
.letter_y: mov al, 'y'
    jmp .letter_shift
.letter_z: mov al, 'z'
.letter_shift:
    test r8d, MOD_SHIFT
    jz .ret_ascii
    and al, 0xDF
    ret

.digit_1:
    test r8d, MOD_SHIFT
    jz .digit_1_plain
    mov al, '!'
    ret
.digit_1_plain:
    mov al, '1'
    ret
.digit_2:
    test r8d, MOD_SHIFT
    jz .digit_2_plain
    mov al, '@'
    ret
.digit_2_plain:
    mov al, '2'
    ret
.digit_3:
    test r8d, MOD_SHIFT
    jz .digit_3_plain
    mov al, '#'
    ret
.digit_3_plain:
    mov al, '3'
    ret
.digit_4:
    test r8d, MOD_SHIFT
    jz .digit_4_plain
    mov al, '$'
    ret
.digit_4_plain:
    mov al, '4'
    ret
.digit_5:
    test r8d, MOD_SHIFT
    jz .digit_5_plain
    mov al, '%'
    ret
.digit_5_plain:
    mov al, '5'
    ret
.digit_6:
    test r8d, MOD_SHIFT
    jz .digit_6_plain
    mov al, '^'
    ret
.digit_6_plain:
    mov al, '6'
    ret
.digit_7:
    test r8d, MOD_SHIFT
    jz .digit_7_plain
    mov al, '&'
    ret
.digit_7_plain:
    mov al, '7'
    ret
.digit_8:
    test r8d, MOD_SHIFT
    jz .digit_8_plain
    mov al, '*'
    ret
.digit_8_plain:
    mov al, '8'
    ret
.digit_9:
    test r8d, MOD_SHIFT
    jz .digit_9_plain
    mov al, '('
    ret
.digit_9_plain:
    mov al, '9'
    ret
.digit_0:
    test r8d, MOD_SHIFT
    jz .digit_0_plain
    mov al, ')'
    ret
.digit_0_plain:
    mov al, '0'
    ret

.space:
    mov al, ' '
    ret
.enter:
    mov al, 10
    ret
.backspace:
    mov al, 8
    ret
.tab:
    mov al, 9
    ret
.esc:
    mov al, 0x1B
    ret
.ret_ascii:
    ret

; rdi=Window*, esi=keycode, edx=state
wayland_update_modifiers_from_key:
    push rbx
    mov rbx, rdi
    mov eax, [rbx + W_CURRENT_MODIFIERS_OFF]

    cmp esi, 42
    je .shift
    cmp esi, 54
    je .shift
    cmp esi, 29
    je .ctrl
    cmp esi, 97
    je .ctrl
    cmp esi, 56
    je .alt
    cmp esi, 100
    je .alt
    cmp esi, 125
    je .super
    cmp esi, 126
    je .super
    jmp .done

.shift:
    cmp edx, 0
    je .shift_up
    or eax, MOD_SHIFT
    jmp .store
.shift_up:
    and eax, ~MOD_SHIFT
    jmp .store
.ctrl:
    cmp edx, 0
    je .ctrl_up
    or eax, MOD_CTRL
    jmp .store
.ctrl_up:
    and eax, ~MOD_CTRL
    jmp .store
.alt:
    cmp edx, 0
    je .alt_up
    or eax, MOD_ALT
    jmp .store
.alt_up:
    and eax, ~MOD_ALT
    jmp .store
.super:
    cmp edx, 0
    je .super_up
    or eax, MOD_SUPER
    jmp .store
.super_up:
    and eax, ~MOD_SUPER
.store:
    mov [rbx + W_CURRENT_MODIFIERS_OFF], eax
.done:
    pop rbx
    ret

; wayland_input_handle_message(window_ptr, sender_id, opcode, payload_ptr, msg_size)
; Params: rdi=Window*, esi=sender, edx=opcode, rcx=payload, r8d=msg_size
; Return: rax=1 handled, 0 not handled
wayland_input_handle_message:
    push rbx
    push r12
    push r13
    push r14
    push r15

    test rdi, rdi
    jz .no
    mov rbx, rdi
    mov r12d, esi                     ; sender
    mov r13d, edx                     ; opcode
    mov r14, rcx                      ; payload

    ; wl_seat events
    cmp r12d, [rbx + W_SEAT_ID_OFF]
    jne .check_keyboard
    cmp r13d, 0
    jne .yes
    mov eax, [r14 + 0]                ; capabilities

    test eax, WL_SEAT_CAP_POINTER
    jz .seat_no_pointer
    cmp dword [rbx + W_POINTER_ID_OFF], 0
    jne .seat_no_pointer
    mov edx, [rbx + W_NEXT_ID_OFF]
    mov [rbx + W_POINTER_ID_OFF], edx
    inc dword [rbx + W_NEXT_ID_OFF]
    mov rdi, [rbx + W_SOCK_FD_OFF]
    mov esi, [rbx + W_SEAT_ID_OFF]
    call wayland_seat_get_pointer
.seat_no_pointer:
    mov eax, [r14 + 0]
    test eax, WL_SEAT_CAP_KEYBOARD
    jz .seat_no_keyboard
    cmp dword [rbx + W_KEYBOARD_ID_OFF], 0
    jne .seat_no_keyboard
    mov edx, [rbx + W_NEXT_ID_OFF]
    mov [rbx + W_KEYBOARD_ID_OFF], edx
    inc dword [rbx + W_NEXT_ID_OFF]
    mov rdi, [rbx + W_SOCK_FD_OFF]
    mov esi, [rbx + W_SEAT_ID_OFF]
    call wayland_seat_get_keyboard
.seat_no_keyboard:
    mov eax, [r14 + 0]
    test eax, WL_SEAT_CAP_TOUCH
    jz .yes
    cmp dword [rbx + W_TOUCH_ID_OFF], 0
    jne .yes
    mov edx, [rbx + W_NEXT_ID_OFF]
    mov [rbx + W_TOUCH_ID_OFF], edx
    inc dword [rbx + W_NEXT_ID_OFF]
    mov rdi, [rbx + W_SOCK_FD_OFF]
    mov esi, [rbx + W_SEAT_ID_OFF]
    call wayland_seat_get_touch
    jmp .yes

.check_keyboard:
    cmp r12d, [rbx + W_KEYBOARD_ID_OFF]
    jne .check_pointer

    cmp r13d, 3
    je .keyboard_key
    cmp r13d, 4
    je .keyboard_modifiers
    jmp .yes

.keyboard_key:
    ; serial@0, time@4, key@8, state@12
    mov esi, [r14 + 8]
    mov edx, [r14 + 12]
    mov rdi, rbx
    call wayland_update_modifiers_from_key

    call wayland_input_clear_event
    lea r15, [rel wl_input_event_tmp]
    mov dword [r15 + INPUT_EVENT_TYPE_OFF], INPUT_KEY
    mov eax, [r14 + 4]
    imul rax, rax, 1000000
    mov [r15 + INPUT_EVENT_TIMESTAMP_OFF], rax
    mov eax, [r14 + 8]
    mov [r15 + INPUT_EVENT_KEY_CODE_OFF], eax
    mov eax, [r14 + 12]
    mov [r15 + INPUT_EVENT_KEY_STATE_OFF], eax
    mov eax, [rbx + W_CURRENT_MODIFIERS_OFF]
    mov [r15 + INPUT_EVENT_MODIFIERS_OFF], eax
    mov rdi, r15
    call input_push_event
    jmp .yes

.keyboard_modifiers:
    ; mods_depressed@0, mods_latched@4, mods_locked@8, group@12
    mov eax, [r14 + 0]
    xor r15d, r15d
    test eax, 0x1
    jz .no_shift
    or r15d, MOD_SHIFT
.no_shift:
    test eax, 0x4
    jz .no_ctrl
    or r15d, MOD_CTRL
.no_ctrl:
    test eax, 0x8
    jz .no_alt
    or r15d, MOD_ALT
.no_alt:
    test eax, 0x40
    jz .no_super
    or r15d, MOD_SUPER
.no_super:
    mov [rbx + W_CURRENT_MODIFIERS_OFF], r15d
    jmp .yes

.check_pointer:
    cmp r12d, [rbx + W_POINTER_ID_OFF]
    jne .check_touch

    cmp r13d, 1
    je .pointer_motion
    cmp r13d, 2
    je .pointer_button
    cmp r13d, 3
    je .pointer_axis
    jmp .yes

.pointer_motion:
    ; time@0, x_fixed@4, y_fixed@8
    call wayland_input_clear_event
    lea r15, [rel wl_input_event_tmp]
    mov dword [r15 + INPUT_EVENT_TYPE_OFF], INPUT_MOUSE_MOVE
    mov eax, [r14 + 0]
    imul rax, rax, 1000000
    mov [r15 + INPUT_EVENT_TIMESTAMP_OFF], rax
    mov eax, [rbx + W_CURRENT_MODIFIERS_OFF]
    mov [r15 + INPUT_EVENT_MODIFIERS_OFF], eax
    mov eax, [r14 + 4]
    sar eax, 8
    mov [r15 + INPUT_EVENT_MOUSE_X_OFF], eax
    mov eax, [r14 + 8]
    sar eax, 8
    mov [r15 + INPUT_EVENT_MOUSE_Y_OFF], eax
    mov rdi, r15
    call input_push_event
    jmp .yes

.pointer_button:
    ; serial@0, time@4, button@8, state@12
    call wayland_input_clear_event
    lea r15, [rel wl_input_event_tmp]
    mov dword [r15 + INPUT_EVENT_TYPE_OFF], INPUT_MOUSE_BUTTON
    mov eax, [r14 + 4]
    imul rax, rax, 1000000
    mov [r15 + INPUT_EVENT_TIMESTAMP_OFF], rax
    mov eax, [r14 + 8]
    mov [r15 + INPUT_EVENT_KEY_CODE_OFF], eax
    mov eax, [r14 + 12]
    mov [r15 + INPUT_EVENT_KEY_STATE_OFF], eax
    mov eax, [rbx + W_CURRENT_MODIFIERS_OFF]
    mov [r15 + INPUT_EVENT_MODIFIERS_OFF], eax
    mov rdi, r15
    call input_push_event
    jmp .yes

.pointer_axis:
    ; time@0, axis@4, value_fixed@8
    call wayland_input_clear_event
    lea r15, [rel wl_input_event_tmp]
    mov dword [r15 + INPUT_EVENT_TYPE_OFF], INPUT_SCROLL
    mov eax, [r14 + 0]
    imul rax, rax, 1000000
    mov [r15 + INPUT_EVENT_TIMESTAMP_OFF], rax
    mov eax, [rbx + W_CURRENT_MODIFIERS_OFF]
    mov [r15 + INPUT_EVENT_MODIFIERS_OFF], eax
    mov eax, [r14 + 8]
    sar eax, 8
    cmp dword [r14 + 4], 0
    jne .axis_horizontal
    mov [r15 + INPUT_EVENT_SCROLL_DY_OFF], eax
    jmp .axis_done
.axis_horizontal:
    mov [r15 + INPUT_EVENT_SCROLL_DX_OFF], eax
.axis_done:
    mov rdi, r15
    call input_push_event
    jmp .yes

.check_touch:
    cmp r12d, [rbx + W_TOUCH_ID_OFF]
    jne .no

    cmp r13d, 0
    je .touch_down
    cmp r13d, 1
    je .touch_up
    cmp r13d, 2
    je .touch_motion
    jmp .yes

.touch_down:
    ; serial@0, time@4, surface@8, id@12, x@16, y@20
    call wayland_input_clear_event
    lea r15, [rel wl_input_event_tmp]
    mov dword [r15 + INPUT_EVENT_TYPE_OFF], INPUT_TOUCH_DOWN
    mov eax, [r14 + 4]
    imul rax, rax, 1000000
    mov [r15 + INPUT_EVENT_TIMESTAMP_OFF], rax
    mov eax, [rbx + W_CURRENT_MODIFIERS_OFF]
    mov [r15 + INPUT_EVENT_MODIFIERS_OFF], eax
    mov eax, [r14 + 12]
    mov [r15 + INPUT_EVENT_TOUCH_ID_OFF], eax
    mov eax, [r14 + 16]
    sar eax, 8
    mov [r15 + INPUT_EVENT_MOUSE_X_OFF], eax
    mov eax, [r14 + 20]
    sar eax, 8
    mov [r15 + INPUT_EVENT_MOUSE_Y_OFF], eax
    mov rdi, r15
    call input_push_event
    jmp .yes

.touch_up:
    ; serial@0, time@4, id@8
    call wayland_input_clear_event
    lea r15, [rel wl_input_event_tmp]
    mov dword [r15 + INPUT_EVENT_TYPE_OFF], INPUT_TOUCH_UP
    mov eax, [r14 + 4]
    imul rax, rax, 1000000
    mov [r15 + INPUT_EVENT_TIMESTAMP_OFF], rax
    mov eax, [rbx + W_CURRENT_MODIFIERS_OFF]
    mov [r15 + INPUT_EVENT_MODIFIERS_OFF], eax
    mov eax, [r14 + 8]
    mov [r15 + INPUT_EVENT_TOUCH_ID_OFF], eax
    mov rdi, r15
    call input_push_event
    jmp .yes

.touch_motion:
    ; time@0, id@4, x@8, y@12
    call wayland_input_clear_event
    lea r15, [rel wl_input_event_tmp]
    mov dword [r15 + INPUT_EVENT_TYPE_OFF], INPUT_TOUCH_MOVE
    mov eax, [r14 + 0]
    imul rax, rax, 1000000
    mov [r15 + INPUT_EVENT_TIMESTAMP_OFF], rax
    mov eax, [rbx + W_CURRENT_MODIFIERS_OFF]
    mov [r15 + INPUT_EVENT_MODIFIERS_OFF], eax
    mov eax, [r14 + 4]
    mov [r15 + INPUT_EVENT_TOUCH_ID_OFF], eax
    mov eax, [r14 + 8]
    sar eax, 8
    mov [r15 + INPUT_EVENT_MOUSE_X_OFF], eax
    mov eax, [r14 + 12]
    sar eax, 8
    mov [r15 + INPUT_EVENT_MOUSE_Y_OFF], eax
    mov rdi, r15
    call input_push_event
    jmp .yes

.no:
    xor eax, eax
    jmp .ret
.yes:
    mov eax, 1
.ret:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
