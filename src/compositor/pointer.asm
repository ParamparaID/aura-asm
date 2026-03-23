; pointer.asm — wl_pointer enter/leave/motion/button/axis + hit-test (Z-order)
%include "src/hal/linux_x86_64/defs.inc"
%include "src/compositor/compositor.inc"

extern proto_send_event
extern compositor_bump_serial
extern keyboard_set_focus

section .bss
    ph_scratch resq 32

%define WL_POINTER_BUTTON_STATE_RELEASED 0
%define WL_POINTER_BUTTON_STATE_PRESSED  1

section .text
global surface_hit_test
global pointer_handle_motion
global pointer_handle_button
global pointer_handle_axis

; surface_hit_test(server, screen_x, screen_y) -> rax Surface* or 0
surface_hit_test:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi
    mov r12d, esi
    mov r13d, edx

    lea r11, [rel ph_scratch]
    xor r14d, r14d
    mov r15, [rbx + CS_CLIENTS_OFF]
    xor ecx, ecx
.cli:
    cmp ecx, dword [rbx + CS_CLIENT_COUNT_OFF]
    jae .sort
    mov rax, [r15 + rcx*8]
    inc ecx
    test rax, rax
    jz .cli
    mov r8, rax
    xor edx, edx
.res:
    cmp edx, dword [r8 + CC_RES_COUNT_OFF]
    jae .next_cli
    mov rsi, [r8 + CC_RESOURCES_OFF + rdx*8]
    inc edx
    test rsi, rsi
    jz .res
    cmp dword [rsi + RES_TYPE_OFF], RESOURCE_SURFACE
    jne .res
    mov rsi, [rsi + RES_DATA_OFF]
    test rsi, rsi
    jz .res
    cmp dword [rsi + SF_MAPPED_OFF], 0
    je .res
    cmp r14d, 32
    jae .res
    mov [r11 + r14*8], rsi
    inc r14d
    jmp .res
.next_cli:
    jmp .cli

.sort:
    cmp r14d, 2
    jb .pick
    xor ecx, ecx
.bub_i:
    mov eax, r14d
    dec eax
    cmp ecx, eax
    jae .pick
    xor edx, edx
.bub_j:
    mov eax, r14d
    dec eax
    sub eax, ecx
    cmp edx, eax
    jae .bub_inci
    mov r8, [r11 + rdx*8]
    mov r9, [r11 + rdx*8 + 8]
    mov eax, dword [r8 + SF_Z_ORDER_OFF]
    cmp eax, dword [r9 + SF_Z_ORDER_OFF]
    jle .bub_next
    mov [r11 + rdx*8], r9
    mov [r11 + rdx*8 + 8], r8
.bub_next:
    inc edx
    jmp .bub_j
.bub_inci:
    inc ecx
    jmp .bub_i

.pick:
    mov ecx, r14d
    dec ecx
.hit_loop:
    cmp ecx, -1
    jle .none
    mov rsi, [r11 + rcx*8]
    dec ecx
    mov eax, dword [rsi + SF_SCREEN_X_OFF]
    cmp r12d, eax
    jb .hit_loop
    mov edx, dword [rsi + SF_WIDTH_OFF]
    add eax, edx
    cmp r12d, eax
    jae .hit_loop
    mov eax, dword [rsi + SF_SCREEN_Y_OFF]
    cmp r13d, eax
    jb .hit_loop
    mov edx, dword [rsi + SF_HEIGHT_OFF]
    add eax, edx
    cmp r13d, eax
    jae .hit_loop
    mov rax, rsi
    jmp .done
.none:
    xor eax, eax
.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; pointer_handle_motion(server, x, y)
pointer_handle_motion:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi
    mov r12d, esi
    mov r13d, edx

    mov rdi, rbx
    mov esi, r12d
    mov edx, r13d
    call surface_hit_test
    mov r14, rax

    mov r15, [rbx + CS_POINTER_FOCUS_OFF]
    cmp r15, r14
    je .same_surf

    test r15, r15
    jz .no_leave
    mov rdi, [r15 + SF_CLIENT_OFF]
    test rdi, rdi
    jz .no_leave
    cmp dword [rdi + CC_POINTER_ID_OFF], 0
    je .no_leave
    sub rsp, 24
    call compositor_bump_serial
    mov dword [rsp + 8], eax
    mov eax, dword [r15 + SF_ID_OFF]
    mov dword [rsp + 12], eax
    mov rdi, [r15 + SF_CLIENT_OFF]
    mov esi, dword [rdi + CC_POINTER_ID_OFF]
    mov edx, 1
    lea rcx, [rsp + 8]
    mov r8, 8
    call proto_send_event
    add rsp, 24
.no_leave:

    mov [rbx + CS_POINTER_FOCUS_OFF], r14
    test r14, r14
    jz .no_enter

    mov rdi, [r14 + SF_CLIENT_OFF]
    test rdi, rdi
    jz .same_surf
    cmp dword [rdi + CC_POINTER_ID_OFF], 0
    je .same_surf

    mov eax, r12d
    sub eax, dword [r14 + SF_SCREEN_X_OFF]
    shl eax, 8
    mov dword [rbx + CS_POINTER_FIX_X_OFF], eax
    mov eax, r13d
    sub eax, dword [r14 + SF_SCREEN_Y_OFF]
    shl eax, 8
    mov dword [rbx + CS_POINTER_FIX_Y_OFF], eax

    sub rsp, 32
    mov rdi, [r14 + SF_CLIENT_OFF]
    call compositor_bump_serial
    mov dword [rsp + 8], eax
    mov eax, dword [r14 + SF_ID_OFF]
    mov dword [rsp + 12], eax
    mov eax, dword [rbx + CS_POINTER_FIX_X_OFF]
    mov dword [rsp + 16], eax
    mov eax, dword [rbx + CS_POINTER_FIX_Y_OFF]
    mov dword [rsp + 20], eax
    mov rdi, [r14 + SF_CLIENT_OFF]
    mov esi, dword [rdi + CC_POINTER_ID_OFF]
    xor edx, edx
    lea rcx, [rsp + 8]
    mov r8, 16
    call proto_send_event
    add rsp, 32
    jmp .motion

.same_surf:
    test r14, r14
    jz .out
    mov eax, r12d
    sub eax, dword [r14 + SF_SCREEN_X_OFF]
    shl eax, 8
    mov dword [rbx + CS_POINTER_FIX_X_OFF], eax
    mov eax, r13d
    sub eax, dword [r14 + SF_SCREEN_Y_OFF]
    shl eax, 8
    mov dword [rbx + CS_POINTER_FIX_Y_OFF], eax

.motion:
    mov rdi, [r14 + SF_CLIENT_OFF]
    test rdi, rdi
    jz .out
    cmp dword [rdi + CC_POINTER_ID_OFF], 0
    je .out
    sub rsp, 24
    xor eax, eax
    mov dword [rsp + 8], eax
    mov eax, dword [rbx + CS_POINTER_FIX_X_OFF]
    mov dword [rsp + 12], eax
    mov eax, dword [rbx + CS_POINTER_FIX_Y_OFF]
    mov dword [rsp + 16], eax
    mov esi, dword [rdi + CC_POINTER_ID_OFF]
    mov edx, 2
    lea rcx, [rsp + 8]
    mov r8, 12
    call proto_send_event
    add rsp, 24
.no_enter:
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; pointer_handle_button(server, button, state)
pointer_handle_button:
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdi
    mov r12d, esi
    mov r13d, edx

    mov r14, [rbx + CS_POINTER_FOCUS_OFF]
    test r14, r14
    jz .out

    mov rdi, [r14 + SF_CLIENT_OFF]
    test rdi, rdi
    jz .out
    cmp dword [rdi + CC_POINTER_ID_OFF], 0
    je .out

    sub rsp, 32
    call compositor_bump_serial
    mov dword [rsp + 8], eax
    xor eax, eax
    mov dword [rsp + 12], eax
    mov dword [rsp + 16], r12d
    mov dword [rsp + 20], r13d
    mov rdi, [r14 + SF_CLIENT_OFF]
    mov esi, dword [rdi + CC_POINTER_ID_OFF]
    mov edx, 3
    lea rcx, [rsp + 8]
    mov r8, 16
    call proto_send_event
    add rsp, 32

    cmp r13d, WL_POINTER_BUTTON_STATE_PRESSED
    jne .out
    cmp r12d, BTN_LEFT
    jne .out
    mov rax, [rbx + CS_KEYBOARD_FOCUS_OFF]
    cmp rax, r14
    je .out
    mov rdi, rbx
    mov rsi, r14
    call keyboard_set_focus
.out:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; pointer_handle_axis(server, axis, value_fixed)
pointer_handle_axis:
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdi
    mov r12d, esi
    mov r13d, edx

    mov r14, [rbx + CS_POINTER_FOCUS_OFF]
    test r14, r14
    jz .out
    mov rdi, [r14 + SF_CLIENT_OFF]
    test rdi, rdi
    jz .out
    cmp dword [rdi + CC_POINTER_ID_OFF], 0
    je .out

    sub rsp, 24
    xor eax, eax
    mov dword [rsp + 8], eax
    mov dword [rsp + 12], r12d
    mov dword [rsp + 16], r13d
    mov esi, dword [rdi + CC_POINTER_ID_OFF]
    mov edx, 4
    lea rcx, [rsp + 8]
    mov r8, 12
    call proto_send_event
    add rsp, 24
.out:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
