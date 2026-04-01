; xdg.asm — xdg_wm_base / xdg_surface / xdg_toplevel (Phase 3)
%include "src/hal/platform_defs.inc"
%include "src/compositor/compositor.inc"

extern client_resource_add
extern client_resource_find
extern compositor_bump_serial
extern proto_send_event
extern surface_find_by_id

section .text
global xdg_dispatch_wm_base
global xdg_dispatch_xdg_surface
global xdg_dispatch_xdg_toplevel

; xdg_find_typed(client, object_id, type) -> rax Resource* or 0
xdg_find_typed:
    push rbx
    push r12
    mov rbx, rdi
    mov r12d, edx
    mov rdi, rbx
    call client_resource_find
    test rax, rax
    jz .none
    cmp dword [rax + RES_TYPE_OFF], r12d
    jne .none
    pop r12
    pop rbx
    ret
.none:
    xor eax, eax
    pop r12
    pop rbx
    ret

; xdg_dispatch_wm_base(client, object_id, opcode, payload, payload_len)
xdg_dispatch_wm_base:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi
    mov r12d, edx                ; opcode
    mov r13, rcx
    mov r14d, r8d

    cmp r12d, 2
    je .get_xdg
    cmp r12d, 3
    je .out                      ; pong — ignore
    jmp .out

.get_xdg:
    cmp r14d, 8
    jb .out
    mov r15d, dword [r13 + 0]    ; new xdg_surface id
    mov r12d, dword [r13 + 4]    ; surface id

    mov rdi, rbx
    mov esi, r12d
    call surface_find_by_id
    test rax, rax
    jz .out
    mov r12, rax                 ; Surface*

    mov dword [r12 + SF_XDG_SURF_ID_OFF], r15d

    mov rdi, rbx
    mov esi, r15d
    mov edx, RESOURCE_XDG_SURFACE
    mov rcx, r12
    call client_resource_add
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; xdg_dispatch_xdg_surface(client, object_id, opcode, payload, payload_len)
xdg_dispatch_xdg_surface:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi
    mov r12d, esi                ; xdg_surface object id
    mov r13d, edx                ; opcode
    mov r14, rcx
    mov r15d, r8d

    mov rdi, rbx
    mov esi, r12d
    mov edx, RESOURCE_XDG_SURFACE
    call xdg_find_typed
    test rax, rax
    jz .out
    mov r12, [rax + RES_DATA_OFF]    ; Surface*

    cmp r13d, 1
    je .get_top
    cmp r13d, 4
    je .ack
    jmp .out

.get_top:
    cmp r15d, 4
    jb .out
    mov r13d, dword [r14 + 0]    ; new toplevel id
    mov dword [r12 + SF_XDG_TOP_ID_OFF], r13d
    mov dword [r12 + SF_XDG_CONFIGURED_OFF], 0

    mov rdi, rbx
    mov esi, r13d
    mov edx, RESOURCE_XDG_TOPLEVEL
    mov rcx, r12
    call client_resource_add

    mov rdi, rbx
    mov esi, r13d
    call xdg_emit_toplevel_configure

    mov rdi, rbx
    mov rsi, r12
    call xdg_emit_surface_configure
    jmp .out

.ack:
    cmp r15d, 4
    jb .out
    mov eax, dword [r14 + 0]
    cmp eax, dword [r12 + SF_LAST_CFG_SERIAL_OFF]
    jne .out
    mov dword [r12 + SF_XDG_CONFIGURED_OFF], 1
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; xdg_emit_toplevel_configure(client, toplevel_id)
xdg_emit_toplevel_configure:
    push rbx
    push r12
    sub rsp, 32
    mov rbx, rdi
    mov r12d, esi

    mov dword [rsp + 8], 0       ; width
    mov dword [rsp + 12], 0      ; height
    mov dword [rsp + 16], 0      ; states array length

    mov rdi, rbx
    mov esi, r12d
    xor edx, edx                 ; configure opcode 0
    lea rcx, [rsp + 8]
    mov r8, 12
    call proto_send_event

    add rsp, 32
    pop r12
    pop rbx
    ret

; xdg_emit_surface_configure(client, surface*)
xdg_emit_surface_configure:
    push rbx
    push r12
    sub rsp, 16
    mov rbx, rdi
    mov r12, rsi

    mov rdi, rbx
    call compositor_bump_serial
    mov dword [r12 + SF_LAST_CFG_SERIAL_OFF], eax
    mov dword [rsp + 8], eax

    mov esi, dword [r12 + SF_XDG_SURF_ID_OFF]
    mov rdi, rbx
    xor edx, edx
    lea rcx, [rsp + 8]
    mov r8, 4
    call proto_send_event

    add rsp, 16
    pop r12
    pop rbx
    ret

; xdg_dispatch_xdg_toplevel(client, object_id, opcode, payload, payload_len)
xdg_dispatch_xdg_toplevel:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi
    mov r12d, esi
    mov r13d, edx
    mov r14, rcx
    mov r15d, r8d

    mov rdi, rbx
    mov esi, r12d
    mov edx, RESOURCE_XDG_TOPLEVEL
    call xdg_find_typed
    test rax, rax
    jz .out
    mov r12, [rax + RES_DATA_OFF]

    cmp r13d, 0
    je .destroy
    cmp r13d, 2
    je .title
    cmp r13d, 3
    je .appid
    jmp .out

.destroy:
    mov dword [r12 + SF_XDG_TOP_ID_OFF], 0
    mov dword [r12 + SF_MAPPED_OFF], 0
    jmp .out

.title:
    cmp r15d, 8
    jb .out
    mov eax, dword [r14 + 0]
    cmp eax, 1
    jb .out
    mov ecx, eax
    add ecx, 3
    and ecx, -4
    lea edx, [rcx + 4]
    cmp r15d, edx
    jb .out
    dec eax
    cmp eax, 127
    ja .out
    mov dword [r12 + SF_TITLE_LEN_OFF], eax
    lea rdi, [r12 + SF_TITLE_OFF]
    lea rsi, [r14 + 4]
    mov ecx, eax
    rep movsb
    mov byte [rdi], 0
    jmp .out

.appid:
    cmp r15d, 8
    jb .out
    mov eax, dword [r14 + 0]
    cmp eax, 1
    jb .out
    mov ecx, eax
    add ecx, 3
    and ecx, -4
    lea edx, [rcx + 4]
    cmp r15d, edx
    jb .out
    dec eax
    cmp eax, 63
    ja .out
    mov dword [r12 + SF_APP_ID_LEN_OFF], eax
    lea rdi, [r12 + SF_APP_ID_OFF]
    lea rsi, [r14 + 4]
    mov ecx, eax
    rep movsb
    mov byte [rdi], 0
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
