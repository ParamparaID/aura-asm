; protocol.asm — Wayland wire I/O (compositor server side)
%include "src/hal/linux_x86_64/defs.inc"
%include "src/compositor/compositor.inc"

extern hal_recvmsg
extern registry_dispatch_display
extern registry_dispatch_registry
extern client_resource_find
extern compositor_disconnect_client
extern surface_dispatch_compositor
extern surface_dispatch_surface
extern shm_dispatch_shm
extern shm_dispatch_shm_pool
extern xdg_dispatch_wm_base
extern xdg_dispatch_xdg_surface
extern xdg_dispatch_xdg_toplevel

section .text
global proto_recv
global proto_dispatch
global proto_flush
global proto_send_event
global proto_send_fd
global proto_send_error
global proto_send_delete_id
global proto_send_global
global proto_pack_header

; proto_pack_header(object_id ignored for word2 — only size+opcode)
; rdi=object_id esi=opcode edx=total_size -> eax = (size<<16)|opcode
proto_pack_header:
    shl edx, 16
    and esi, 0xFFFF
    mov eax, edx
    or eax, esi
    ret

; proto_send_event(client, object_id, opcode, args_buf, args_len)
; r8 = args_len
proto_send_event:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi
    mov r12d, esi                ; object_id
    mov r13d, edx                ; opcode
    mov r14, rcx                 ; args_buf
    mov r15, r8                  ; args_len

    mov eax, r15d
    add eax, 8
    jc .fail
    mov edi, r12d
    mov esi, r13d
    mov edx, eax
    call proto_pack_header
    mov r13d, eax                ; header word2

    mov eax, dword [rbx + CC_SEND_LEN_OFF]
    mov ecx, eax
    add ecx, r15d
    add ecx, 8
    jc .fail
    cmp ecx, dword [rbx + CC_SEND_CAP_OFF]
    ja .need_flush
.have_room:
    mov rsi, [rbx + CC_SEND_BUF_OFF]
    add rsi, rax
    mov dword [rsi + 0], r12d
    mov dword [rsi + 4], r13d
    lea rdi, [rsi + 8]
    mov rsi, r14
    mov rcx, r15
    test rcx, rcx
    jz .no_copy
    rep movsb
.no_copy:
    mov eax, dword [rbx + CC_SEND_LEN_OFF]
    add eax, r15d
    add eax, 8
    mov dword [rbx + CC_SEND_LEN_OFF], eax
    xor eax, eax
    jmp .ret
.need_flush:
    mov rdi, rbx
    call proto_flush
    test rax, rax
    js .fail
    jmp .have_room
.fail:
    mov rax, -1
.ret:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; proto_flush(client)
proto_flush:
    push rbx
    push r12
    sub rsp, 96
    mov rbx, rdi
    mov r12d, dword [rbx + CC_SEND_LEN_OFF]
    test r12d, r12d
    jz .ok

    lea r11, [rsp]
    mov rsi, [rbx + CC_SEND_BUF_OFF]
    mov [r11 + 0], rsi
    mov qword [r11 + 8], r12

    mov qword [r11 + 16], 0
    mov qword [r11 + 24], 0
    lea rax, [r11 + 0]
    mov [r11 + 32], rax
    mov qword [r11 + 40], 1
    mov qword [r11 + 48], 0
    mov qword [r11 + 56], 0
    mov qword [r11 + 64], 0
    mov qword [r11 + 72], 0

    movsx rdi, dword [rbx + CC_FD_OFF]
    lea rsi, [r11 + 16]
    xor edx, edx
    mov rax, SYS_SENDMSG
    syscall
    test rax, rax
    js .fail
    mov dword [rbx + CC_SEND_LEN_OFF], 0
.ok:
    xor eax, eax
    add rsp, 96
    pop r12
    pop rbx
    ret
.fail:
    mov rax, -1
    add rsp, 96
    pop r12
    pop rbx
    ret

; proto_send_fd(client, object_id, opcode, args_buf, args_len, pass_fd)
; Windows ABI not used — SysV: rdi,rsi,rdx,rcx,r8,r9 then stack
; rdi client, esi obj, edx opc, rcx args, r8 args_len, r9d pass_fd
proto_send_fd:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 128

    mov rbx, rdi
    mov r12d, esi
    mov r13d, edx
    mov r14, rcx
    mov r15, r8
    mov eax, r9d
    mov dword [rsp + 32], eax      ; fd in scratch for cmsg

    mov eax, r15d
    add eax, 8
    jc .fail
    mov edi, r12d
    mov esi, r13d
    mov edx, eax
    call proto_pack_header
    mov r13d, eax

    mov eax, dword [rbx + CC_SEND_LEN_OFF]
    add eax, r15d
    add eax, 8
    cmp eax, dword [rbx + CC_SEND_CAP_OFF]
    ja .fail

    mov rsi, [rbx + CC_SEND_BUF_OFF]
    mov eax, dword [rbx + CC_SEND_LEN_OFF]
    add rsi, rax
    mov dword [rsi + 0], r12d
    mov dword [rsi + 4], r13d
    lea rdi, [rsi + 8]
    mov rsi, r14
    mov rcx, r15
    rep movsb

    mov eax, dword [rbx + CC_SEND_LEN_OFF]
    add eax, r15d
    add eax, 8
    mov dword [rbx + CC_SEND_LEN_OFF], eax

    lea r10, [rsp + 40]
    mov dword [r10 + 0], 20
    mov dword [r10 + 8], 1
    mov dword [r10 + 12], 1
    mov eax, dword [rsp + 32]
    mov dword [r10 + 16], eax

    lea r11, [rsp + 64]
    mov rsi, [rbx + CC_SEND_BUF_OFF]
    mov eax, dword [rbx + CC_SEND_LEN_OFF]
    mov [r11 + 0], rsi
    mov qword [r11 + 8], rax

    mov qword [r11 + 16], 0
    mov qword [r11 + 24], 0
    lea rax, [r11 + 0]
    mov [r11 + 32], rax
    mov qword [r11 + 40], 1
    mov [r11 + 48], r10
    mov qword [r11 + 56], 24
    mov qword [r11 + 64], 0
    mov qword [r11 + 72], 0

    movsx rdi, dword [rbx + CC_FD_OFF]
    lea rsi, [r11 + 16]
    xor edx, edx
    mov rax, SYS_SENDMSG
    syscall
    test rax, rax
    js .fail
    mov dword [rbx + CC_SEND_LEN_OFF], 0
    xor eax, eax
    jmp .done
.fail:
    mov rax, -1
.done:
    add rsp, 128
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; proto_send_error(client, bad_object_id, code, msg_ptr, msg_len)
; esi = object_id that caused error (wire field), edx=code, rcx=msg, r8=len without NUL
proto_send_error:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 416

    mov rbx, rdi
    mov r12d, esi
    mov r13d, edx
    mov r14, rcx
    mov r15, r8

    mov dword [rsp + 12], r13d    ; save error code

    mov eax, r15d
    inc eax
    add eax, 3
    and eax, -4
    mov r13d, eax                ; str_align (clobber r13 after code saved)

    mov dword [rsp + 20], r12d
    mov eax, dword [rsp + 12]
    mov dword [rsp + 24], eax
    mov eax, r15d
    inc eax
    mov dword [rsp + 28], eax
    lea rdi, [rsp + 32]
    mov rsi, r14
    mov rcx, r15
    rep movsb
    mov byte [rdi], 0

    movsxd r8, r13d
    add r8, 12
    mov rdi, rbx
    mov esi, 1
    xor edx, edx
    lea rcx, [rsp + 20]
    call proto_send_event

    add rsp, 416
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; proto_send_delete_id(client, id)
proto_send_delete_id:
    push rbx
    sub rsp, 16
    mov rbx, rdi
    mov dword [rsp + 8], esi
    mov rdi, rbx
    mov esi, 1
    mov edx, 1
    lea rcx, [rsp + 8]
    mov r8, 4
    call proto_send_event
    add rsp, 16
    pop rbx
    ret

; proto_send_global(client, registry_id, name, iface_ptr, iface_len, version)
; iface_len = strlen without terminating NUL
proto_send_global:
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
    sub rsp, 320
    lea rdi, [rsp]
    mov ecx, 80
    xor eax, eax
    rep stosd
    mov eax, r9d
    mov dword [rsp + 304], eax   ; version

    mov eax, r15d
    inc eax
    add eax, 3
    and eax, -4
    mov r9d, eax                 ; str_align

    mov dword [rsp + 32], r13d
    mov eax, r15d
    inc eax
    mov dword [rsp + 36], eax
    lea rdi, [rsp + 40]
    mov rsi, r14
    mov ecx, r15d
    rep movsb
    mov byte [rdi], 0
    lea rdi, [rsp + 40]
    add rdi, r9
    mov eax, dword [rsp + 304]
    mov dword [rdi], eax

    lea r8, [r9 + 12]
    mov rdi, rbx
    mov esi, r12d
    xor edx, edx
    lea rcx, [rsp + 32]
    call proto_send_event

    add rsp, 320
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; proto_dispatch(client, object_id, opcode, payload, payload_len)
proto_dispatch:
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
    call client_resource_find
    test rax, rax
    jz .out
    mov r10d, dword [rax + RES_TYPE_OFF]
    cmp r10d, RESOURCE_DISPLAY
    je .as_display
    cmp r10d, RESOURCE_REGISTRY
    je .as_registry
    cmp r10d, RESOURCE_COMPOSITOR
    je .as_compositor
    cmp r10d, RESOURCE_SURFACE
    je .as_surface
    cmp r10d, RESOURCE_SHM
    je .as_shm
    cmp r10d, RESOURCE_SHM_POOL
    je .as_pool
    cmp r10d, RESOURCE_XDG_WM_BASE
    je .as_xdg_wm
    cmp r10d, RESOURCE_XDG_SURFACE
    je .as_xdg_surf
    cmp r10d, RESOURCE_XDG_TOPLEVEL
    je .as_xdg_top
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.as_display:
    mov rdi, rbx
    mov esi, r13d
    mov rdx, r14
    mov ecx, r15d
    call registry_dispatch_display
    jmp .out
.as_registry:
    mov rdi, rbx
    mov esi, r13d
    mov rdx, r14
    mov ecx, r15d
    call registry_dispatch_registry
    jmp .out
.as_compositor:
    mov rdi, rbx
    mov esi, r12d
    mov edx, r13d
    mov rcx, r14
    mov r8d, r15d
    call surface_dispatch_compositor
    jmp .out
.as_surface:
    mov rdi, rbx
    mov esi, r12d
    mov edx, r13d
    mov rcx, r14
    mov r8d, r15d
    call surface_dispatch_surface
    jmp .out
.as_shm:
    mov rdi, rbx
    mov esi, r12d
    mov edx, r13d
    mov rcx, r14
    mov r8d, r15d
    call shm_dispatch_shm
    jmp .out
.as_pool:
    mov rdi, rbx
    mov esi, r12d
    mov edx, r13d
    mov rcx, r14
    mov r8d, r15d
    call shm_dispatch_shm_pool
    jmp .out
.as_xdg_wm:
    mov rdi, rbx
    mov esi, r12d
    mov edx, r13d
    mov rcx, r14
    mov r8d, r15d
    call xdg_dispatch_wm_base
    jmp .out
.as_xdg_surf:
    mov rdi, rbx
    mov esi, r12d
    mov edx, r13d
    mov rcx, r14
    mov r8d, r15d
    call xdg_dispatch_xdg_surface
    jmp .out
.as_xdg_top:
    mov rdi, rbx
    mov esi, r12d
    mov edx, r13d
    mov rcx, r14
    mov r8d, r15d
    call xdg_dispatch_xdg_toplevel
    jmp .out

; proto_recv(client) -> rax: 0 ok, -1 disconnect/error
%define EAGAIN_NEG           -11

proto_recv:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov rbx, rdi

    mov r13d, dword [rbx + CC_RECV_LEN_OFF]
    mov eax, CLIENT_IO_BUF_CAP
    sub eax, r13d
    jbe .parse
    mov r14d, eax                ; max read
    sub rsp, 384
    lea rdi, [rsp]
    mov ecx, 48
    xor eax, eax
    rep stosq                    ; zero cmsg + iov + msghdr tail

    mov rsi, [rbx + CC_RECV_BUF_OFF]
    movsxd rax, dword [rbx + CC_RECV_LEN_OFF]
    add rsi, rax
    mov [rsp + 256], rsi         ; iov_base
    mov rax, r14
    mov [rsp + 264], rax         ; iov_len

    lea rax, [rsp + 256]
    mov qword [rsp + 288], rax   ; msg_iov
    mov dword [rsp + 296], 1     ; msg_iovlen
    mov qword [rsp + 304], rsp   ; msg_control
    mov dword [rsp + 312], 256   ; msg_controllen

    movsx rdi, dword [rbx + CC_FD_OFF]
    lea rsi, [rsp + 272]
    xor edx, edx
    call hal_recvmsg
    test rax, rax
    jz .disc_pop
    js .read_neg_pop
    add dword [rbx + CC_RECV_LEN_OFF], eax

    mov ecx, dword [rsp + 312]
    cmp ecx, 20
    jb .done_recv_pop
    cmp dword [rsp + 8], SOL_SOCKET
    jne .done_recv_pop
    cmp dword [rsp + 12], SCM_RIGHTS
    jne .done_recv_pop
    mov eax, dword [rsp + 16]
    mov dword [rbx + CC_PENDING_FD_OFF], eax

.done_recv_pop:
    add rsp, 384
    jmp .parse
.read_neg_pop:
    cmp rax, EAGAIN_NEG
    je .eagain_pop
.disc_pop:
    add rsp, 384
    jmp .disc
.eagain_pop:
    add rsp, 384
    jmp .parse
.parse:
    xor r12d, r12d
.msg:
    mov eax, dword [rbx + CC_RECV_LEN_OFF]
    sub eax, r12d
    cmp eax, 8
    jb .compact
    mov rsi, [rbx + CC_RECV_BUF_OFF]
    movsxd r15, r12d
    add rsi, r15
    mov r10d, dword [rsi + 0]
    mov r9d, dword [rsi + 4]
    mov eax, r9d
    shr eax, 16
    mov r14d, eax
    cmp r14d, 8
    jb .disc
    mov ecx, dword [rbx + CC_RECV_LEN_OFF]
    sub ecx, r12d
    cmp ecx, r14d
    jb .compact
    mov eax, r9d
    and eax, 0xFFFF
    mov r8d, r14d
    sub r8d, 8
    lea rcx, [rsi + 8]
    mov rdi, rbx
    mov esi, r10d
    mov edx, eax
    call proto_dispatch
    add r12d, r14d
    jmp .msg
.compact:
    mov eax, dword [rbx + CC_RECV_LEN_OFF]
    sub eax, r12d
    je .drained
    mov rdi, [rbx + CC_RECV_BUF_OFF]
    movsxd r13, r12d
    lea rsi, [rdi + r13]
    mov ecx, eax
    rep movsb
    mov dword [rbx + CC_RECV_LEN_OFF], eax
    jmp .flush
.drained:
    mov dword [rbx + CC_RECV_LEN_OFF], 0
.flush:
    mov rdi, rbx
    call proto_flush
    xor eax, eax
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.disc:
    mov rdi, [rbx + CC_SERVER_OFF]
    mov rsi, rbx
    call compositor_disconnect_client
    mov rax, -1
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
