; registry.asm — wl_display / wl_registry (compositor server)
%include "src/hal/linux_x86_64/defs.inc"
%include "src/compositor/compositor.inc"

extern proto_send_event
extern proto_send_delete_id
extern proto_send_global
extern client_resource_add

section .rodata
    iface_wl_compositor db "wl_compositor", 0
    iface_wl_compositor_len equ 13
    iface_wl_shm       db "wl_shm", 0
    iface_wl_shm_len   equ 6
    iface_wl_seat      db "wl_seat", 0
    iface_wl_seat_len  equ 7
    iface_xdg_wm       db "xdg_wm_base", 0
    iface_xdg_wm_len   equ 11
    iface_wl_output    db "wl_output", 0
    iface_wl_output_len equ 9

section .text
global registry_dispatch_display
global registry_dispatch_registry
global compositor_bump_serial

compositor_bump_serial:
    mov rax, [rdi + CC_SERVER_OFF]
    mov ecx, dword [rax + CS_NEXT_SERIAL_OFF]
    inc ecx
    mov dword [rax + CS_NEXT_SERIAL_OFF], ecx
    mov eax, ecx
    ret

; registry_send_globals(client, registry_id)
registry_send_globals:
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12d, esi

    mov rdi, rbx
    mov esi, r12d
    mov edx, 1
    lea rcx, [rel iface_wl_compositor]
    mov r8d, iface_wl_compositor_len
    mov r9d, 5
    call proto_send_global

    mov rdi, rbx
    mov esi, r12d
    mov edx, 2
    lea rcx, [rel iface_wl_shm]
    mov r8d, iface_wl_shm_len
    mov r9d, 1
    call proto_send_global

    mov rdi, rbx
    mov esi, r12d
    mov edx, 3
    lea rcx, [rel iface_wl_seat]
    mov r8d, iface_wl_seat_len
    mov r9d, 7
    call proto_send_global

    mov rdi, rbx
    mov esi, r12d
    mov edx, 4
    lea rcx, [rel iface_xdg_wm]
    mov r8d, iface_xdg_wm_len
    mov r9d, 2
    call proto_send_global

    mov rdi, rbx
    mov esi, r12d
    mov edx, 5
    lea rcx, [rel iface_wl_output]
    mov r8d, iface_wl_output_len
    mov r9d, 4
    call proto_send_global

    pop r13
    pop r12
    pop rbx
    ret

; registry_shm_send_formats(client, shm_id)
registry_shm_send_formats:
    push rbx
    push r12
    sub rsp, 16
    mov rbx, rdi
    mov r12d, esi

    mov dword [rsp + 8], 0
    mov rdi, rbx
    mov esi, r12d
    xor edx, edx
    lea rcx, [rsp + 8]
    mov r8, 4
    call proto_send_event

    mov dword [rsp + 8], 1
    mov rdi, rbx
    mov esi, r12d
    xor edx, edx
    lea rcx, [rsp + 8]
    mov r8, 4
    call proto_send_event

    add rsp, 16
    pop r12
    pop rbx
    ret

; registry_dispatch_display(client, opcode, payload, payload_len)
registry_dispatch_display:
    push rbx
    push r12
    push r13
    push r15
    mov rbx, rdi
    mov r12d, esi
    mov r13, rdx

    cmp r12d, 0
    je .sync
    cmp r12d, 1
    je .get_reg
    jmp .done
.sync:
    cmp ecx, 4
    jb .done
    mov r15d, dword [r13 + 0]
    sub rsp, 16
    mov rdi, rbx
    call compositor_bump_serial
    mov dword [rsp + 8], eax
    mov rdi, rbx
    mov esi, r15d
    xor edx, edx
    lea rcx, [rsp + 8]
    mov r8, 4
    call proto_send_event
    mov rdi, rbx
    mov esi, r15d
    call proto_send_delete_id
    add rsp, 16
    jmp .done
.get_reg:
    cmp ecx, 4
    jb .done
    mov esi, dword [r13 + 0]
    mov edx, RESOURCE_REGISTRY
    xor ecx, ecx
    mov rdi, rbx
    call client_resource_add
    test rax, rax
    jz .done
    mov esi, dword [r13 + 0]
    mov rdi, rbx
    call registry_send_globals
.done:
    pop r15
    pop r13
    pop r12
    pop rbx
    ret

; registry_dispatch_registry(client, opcode, payload, payload_len)
registry_dispatch_registry:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi
    mov r12d, esi
    mov r13, rdx
    mov r14d, ecx

    cmp r12d, 0
    jne .out
    cmp r14d, 8
    jb .out
    mov r15d, dword [r13 + 0]
    mov eax, dword [r13 + 4]
    cmp eax, 1
    jb .out
    mov ecx, eax
    add ecx, 3
    and ecx, -4
    mov r12d, ecx
    lea eax, [r12 + 16]
    cmp r14d, eax
    jb .out
    mov r8d, dword [r13 + 12 + r12]

    cmp r15d, 1
    je .bind_comp
    cmp r15d, 2
    je .bind_shm
    cmp r15d, 3
    je .bind_seat
    cmp r15d, 4
    je .bind_xdg
    cmp r15d, 5
    je .bind_out
    jmp .out
.bind_comp:
    mov r12d, r8d                   ; new_id — r8 not preserved across calls
    mov esi, r12d
    mov edx, RESOURCE_COMPOSITOR
    xor ecx, ecx
    mov rdi, rbx
    call client_resource_add
    test rax, rax
    jz .out
    mov dword [rbx + CC_COMPOSITOR_ID_OFF], r12d
    jmp .out
.bind_shm:
    mov r12d, r8d
    mov esi, r12d
    mov edx, RESOURCE_SHM
    xor ecx, ecx
    mov rdi, rbx
    call client_resource_add
    test rax, rax
    jz .out
    mov dword [rbx + CC_SHM_ID_OFF], r12d
    mov esi, r12d
    mov rdi, rbx
    call registry_shm_send_formats
    jmp .out
.bind_seat:
    mov r12d, r8d
    mov esi, r12d
    mov edx, RESOURCE_SEAT
    xor ecx, ecx
    mov rdi, rbx
    call client_resource_add
    test rax, rax
    jz .out
    mov dword [rbx + CC_SEAT_ID_OFF], r12d
    jmp .out
.bind_xdg:
    mov r12d, r8d
    mov esi, r12d
    mov edx, RESOURCE_XDG_WM_BASE
    xor ecx, ecx
    mov rdi, rbx
    call client_resource_add
    test rax, rax
    jz .out
    mov dword [rbx + CC_WM_BASE_ID_OFF], r12d
    jmp .out
.bind_out:
    mov r12d, r8d
    mov esi, r12d
    mov edx, RESOURCE_OUTPUT
    xor ecx, ecx
    mov rdi, rbx
    call client_resource_add
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
