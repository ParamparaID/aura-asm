; seat.asm — wl_seat: bind announcements + get_pointer/get_keyboard/get_touch
%include "src/hal/platform_defs.inc"
%include "src/compositor/compositor.inc"

extern proto_send_event
extern client_resource_add
extern keyboard_send_keymap

section .rodata
    seat_name_default db "default", 0
    seat_name_len     equ $ - seat_name_default - 1

section .text
global seat_on_bind
global seat_dispatch_seat

; seat_on_bind(client, seat_object_id)
; Sends wl_seat.capabilities(7) and wl_seat.name("default").
seat_on_bind:
    push rbx
    push r12
    sub rsp, 16
    mov rbx, rdi
    mov r12d, esi

    mov dword [rsp + 8], 7
    mov rdi, rbx
    mov esi, r12d
    xor edx, edx
    lea rcx, [rsp + 8]
    mov r8, 4
    call proto_send_event

    mov eax, seat_name_len
    inc eax
    add eax, 3
    and eax, -4
    mov r8d, eax
    add r8d, 4
    lea rdi, [rsp + 8]
    xor eax, eax
    mov ecx, 6
    rep stosd
    mov dword [rsp + 8], seat_name_len
    inc dword [rsp + 8]
    lea rdi, [rsp + 12]
    lea rsi, [rel seat_name_default]
    mov ecx, seat_name_len
    inc ecx
    rep movsb

    mov rdi, rbx
    mov esi, r12d
    mov edx, 1
    lea rcx, [rsp + 8]
    mov r8, r8
    call proto_send_event

    add rsp, 16
    pop r12
    pop rbx
    ret

; seat_dispatch_seat(client, object_id, opcode, payload, payload_len)
seat_dispatch_seat:
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdi
    mov r12d, edx
    mov r13, rcx
    mov r14d, r8d

    cmp r12d, 0
    je .get_pointer
    cmp r12d, 1
    je .get_keyboard
    cmp r12d, 2
    je .get_touch
    jmp .out

.get_pointer:
    cmp r14d, 4
    jb .out
    mov esi, dword [r13 + 0]
    mov edx, RESOURCE_POINTER
    xor ecx, ecx
    mov rdi, rbx
    call client_resource_add
    test rax, rax
    jz .out
    mov eax, dword [r13 + 0]
    mov dword [rbx + CC_POINTER_ID_OFF], eax
    jmp .out

.get_keyboard:
    cmp r14d, 4
    jb .out
    mov esi, dword [r13 + 0]
    mov edx, RESOURCE_KEYBOARD
    xor ecx, ecx
    mov rdi, rbx
    call client_resource_add
    test rax, rax
    jz .out
    mov eax, dword [r13 + 0]
    mov dword [rbx + CC_KEYBOARD_ID_OFF], eax
    mov rdi, rbx
    mov esi, eax
    call keyboard_send_keymap
    jmp .out

.get_touch:
    cmp r14d, 4
    jb .out
    mov esi, dword [r13 + 0]
    mov edx, RESOURCE_TOUCH
    xor ecx, ecx
    mov rdi, rbx
    call client_resource_add
    test rax, rax
    jz .out
    mov eax, dword [r13 + 0]
    mov dword [rbx + CC_TOUCH_ID_OFF], eax
.out:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
