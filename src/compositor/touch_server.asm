; touch_server.asm — wl_touch routing (down/motion/up/frame), up to 16 slots
%include "src/hal/linux_x86_64/defs.inc"
%include "src/compositor/compositor.inc"

extern surface_hit_test
extern surface_find_by_id
extern proto_send_event
extern compositor_bump_serial

%define MAX_TOUCH_SLOTS 16
%define TS_STRIDE       32

; slot: active dd, touch_id dd, client dq, surface_wl_id dd, pad dd

section .bss
    ts_slots      resb (MAX_TOUCH_SLOTS * TS_STRIDE)
    ts_frame_sent resq MAX_TOUCH_SLOTS
    ts_sent_num   resd 1

section .text
global touch_handle_down
global touch_handle_motion
global touch_handle_up
global touch_handle_frame

find_touch_slot_by_id:
    xor ecx, ecx
    lea r8, [rel ts_slots]
.loop:
    cmp ecx, MAX_TOUCH_SLOTS
    jae .none
    cmp dword [r8], 0
    je .next
    cmp dword [r8 + 4], edi
    je .found
.next:
    add r8, TS_STRIDE
    inc ecx
    jmp .loop
.found:
    mov rax, r8
    ret
.none:
    or rax, -1
    ret

find_free_touch_slot:
    xor ecx, ecx
    lea r8, [rel ts_slots]
.loop:
    cmp ecx, MAX_TOUCH_SLOTS
    jae .none
    cmp dword [r8], 0
    je .found
    add r8, TS_STRIDE
    inc ecx
    jmp .loop
.found:
    mov rax, r8
    ret
.none:
    xor eax, eax
    ret

; touch_handle_down(server, touch_id, x, y)
touch_handle_down:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi
    mov r12d, esi
    mov r13d, edx
    mov r14d, ecx

    mov rdi, rbx
    mov esi, r13d
    mov edx, r14d
    call surface_hit_test
    test rax, rax
    jz .out
    mov r15, rax

    call find_free_touch_slot
    test rax, rax
    jz .out
    mov rdi, rax

    mov rcx, [r15 + SF_CLIENT_OFF]
    test rcx, rcx
    jz .out
    cmp dword [rcx + CC_TOUCH_ID_OFF], 0
    je .out

    mov dword [rdi], 1
    mov dword [rdi + 4], r12d
    mov [rdi + 8], rcx
    mov eax, dword [r15 + SF_ID_OFF]
    mov dword [rdi + 16], eax

    mov eax, r13d
    sub eax, dword [r15 + SF_SCREEN_X_OFF]
    shl eax, 8
    mov r8d, eax
    mov eax, r14d
    sub eax, dword [r15 + SF_SCREEN_Y_OFF]
    shl eax, 8
    mov r9d, eax

    sub rsp, 40
    mov rdi, rcx
    call compositor_bump_serial
    mov dword [rsp + 8], eax
    xor eax, eax
    mov dword [rsp + 12], eax
    mov eax, dword [r15 + SF_ID_OFF]
    mov dword [rsp + 16], eax
    mov dword [rsp + 20], r12d
    mov dword [rsp + 24], r8d
    mov dword [rsp + 28], r9d
    mov rdi, [r15 + SF_CLIENT_OFF]
    mov esi, dword [rdi + CC_TOUCH_ID_OFF]
    xor edx, edx
    lea rcx, [rsp + 8]
    mov r8, 24
    call proto_send_event
    add rsp, 40
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; touch_handle_motion(server, touch_id, x, y)
touch_handle_motion:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi
    mov r12d, esi
    mov r13d, edx
    mov r14d, ecx

    mov edi, r12d
    call find_touch_slot_by_id
    cmp rax, -1
    je .out
    mov r15, rax

    cmp dword [r15], 0
    je .out
    mov rdi, [r15 + 8]
    test rdi, rdi
    jz .out
    mov esi, dword [r15 + 16]
    call surface_find_by_id
    test rax, rax
    jz .out
    mov rsi, rax

    mov eax, r13d
    sub eax, dword [rsi + SF_SCREEN_X_OFF]
    shl eax, 8
    mov r8d, eax
    mov eax, r14d
    sub eax, dword [rsi + SF_SCREEN_Y_OFF]
    shl eax, 8
    mov r9d, eax

    sub rsp, 24
    xor eax, eax
    mov dword [rsp + 8], eax
    mov dword [rsp + 12], r12d
    mov dword [rsp + 16], r8d
    mov dword [rsp + 20], r9d
    mov rdi, [r15 + 8]
    mov esi, dword [rdi + CC_TOUCH_ID_OFF]
    mov edx, 2
    lea rcx, [rsp + 8]
    mov r8, 16
    call proto_send_event
    add rsp, 24
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; touch_handle_up(server, touch_id)
touch_handle_up:
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdi
    mov r12d, esi

    mov edi, r12d
    call find_touch_slot_by_id
    cmp rax, -1
    je .out
    mov r13, rax

    cmp dword [r13], 0
    je .out
    mov r14, [r13 + 8]
    test r14, r14
    jz .clear
    cmp dword [r14 + CC_TOUCH_ID_OFF], 0
    je .clear

    sub rsp, 24
    mov rdi, r14
    call compositor_bump_serial
    mov dword [rsp + 8], eax
    xor eax, eax
    mov dword [rsp + 12], eax
    mov dword [rsp + 16], r12d
    mov rdi, r14
    mov esi, dword [r14 + CC_TOUCH_ID_OFF]
    mov edx, 1
    lea rcx, [rsp + 8]
    mov r8, 12
    call proto_send_event
    add rsp, 24
.clear:
    mov dword [r13], 0
.out:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; touch_handle_frame(server)
touch_handle_frame:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi

    mov dword [rel ts_sent_num], 0

    xor r12d, r12d
    lea r13, [rel ts_slots]
.slot:
    cmp r12d, MAX_TOUCH_SLOTS
    jae .clear_sent
    cmp dword [r13], 0
    je .next
    mov r14, [r13 + 8]
    test r14, r14
    jz .next
    cmp dword [r14 + CC_TOUCH_ID_OFF], 0
    jz .next

    xor r15d, r15d
.dedup:
    cmp r15d, dword [rel ts_sent_num]
    jae .emit
    lea rax, [rel ts_frame_sent]
    cmp [rax + r15*8], r14
    je .next
    inc r15d
    jmp .dedup
.emit:
    mov eax, dword [rel ts_sent_num]
    lea rdx, [rel ts_frame_sent]
    mov [rdx + rax*8], r14
    inc dword [rel ts_sent_num]
    mov rdi, r14
    mov esi, dword [r14 + CC_TOUCH_ID_OFF]
    mov edx, 3
    xor ecx, ecx
    xor r8d, r8d
    call proto_send_event
.next:
    add r13, TS_STRIDE
    inc r12d
    jmp .slot
.clear_sent:
    lea rdi, [rel ts_frame_sent]
    mov ecx, MAX_TOUCH_SLOTS
    xor eax, eax
    rep stosq
    mov dword [rel ts_sent_num], 0

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
