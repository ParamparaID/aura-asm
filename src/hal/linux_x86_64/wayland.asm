; wayland.asm
; Wayland wire protocol helpers for Aura Shell.

%include "src/hal/platform_defs.inc"

extern hal_close

%define AF_UNIX                1
%define SOCK_STREAM            1
%define SOL_SOCKET             1
%define SCM_RIGHTS             1
%define MSG_DONTWAIT           0x40

%define WL_IFACE_COMPOSITOR    1
%define WL_IFACE_SHM           2
%define WL_IFACE_XDG_WM_BASE   3
%define WL_IFACE_SEAT          4

%define WL_SHM_FORMAT_ARGB8888 0

%define XDG_WM_BASE_PONG       3
%define XDG_SURFACE_ACK_CFG    4

section .data
    wayland_path_1      db "/mnt/wslg/runtime-dir/wayland-0",0
    wayland_path_2      db "/run/user/1000/wayland-0",0
    wayland_path_3      db "/tmp/wayland-0",0

    iface_compositor    db "wl_compositor",0
    iface_shm           db "wl_shm",0
    iface_xdg_wm_base   db "xdg_wm_base",0
    iface_seat          db "wl_seat",0

section .bss
    wl_tmp_buf          resb 512
    wl_ctrl_buf         resb 64

section .text
global wl_connect
global wl_disconnect
global wl_send
global wl_send_fd
global wl_recv
global wl_recv_nowait
global wl_parse_event
global wl_display_get_registry
global wl_display_sync
global wl_registry_bind
global wl_compositor_create_surface
global wl_seat_get_pointer
global wl_seat_get_keyboard
global wl_shm_create_pool
global wl_shm_pool_create_buffer
global wl_surface_attach
global wl_surface_damage
global wl_surface_frame
global wl_surface_commit
global xdg_wm_base_get_xdg_surface
global xdg_surface_get_toplevel
global xdg_toplevel_set_title
global xdg_wm_base_pong
global xdg_surface_ack_configure

; rdi=sender_id, rsi=opcode, rdx=size
; eax=(size<<16)|opcode
wl_pack_opcode_size:
    shl edx, 16
    and esi, 0xFFFF
    mov eax, edx
    or eax, esi
    ret

; rdi=path, rsi=sockfd
; rax=0 success, -1 fail
wl_try_connect_path:
    push rbx
    push r8
    sub rsp, 112
    mov r8, rdi
    lea rbx, [rsp]
    xor eax, eax
    mov ecx, 14
    mov rdi, rbx
    rep stosq
    mov rdi, r8
    lea rbx, [rsp]
    mov word [rbx + 0], AF_UNIX
    lea rcx, [rbx + 2]
    xor rdx, rdx
.copy_path:
    mov al, [rdi + rdx]
    mov [rcx + rdx], al
    cmp al, 0
    je .do_connect
    inc rdx
    cmp rdx, 107
    jb .copy_path
.do_connect:
    mov rax, SYS_CONNECT
    mov rdi, rsi
    mov rsi, rbx
    add rdx, 3
    syscall
    test rax, rax
    js .fail
    xor eax, eax
    add rsp, 112
    pop r8
    pop rbx
    ret
.fail:
    mov rax, -1
    add rsp, 112
    pop r8
    pop rbx
    ret

; wl_connect() -> rax=fd/-1
wl_connect:
    mov rax, SYS_SOCKET
    mov rdi, AF_UNIX
    mov rsi, SOCK_STREAM
    xor rdx, rdx
    syscall
    test rax, rax
    js .fail
    mov r8, rax

    lea rdi, [rel wayland_path_1]
    mov rsi, r8
    call wl_try_connect_path
    test rax, rax
    jz .ok
    lea rdi, [rel wayland_path_2]
    mov rsi, r8
    call wl_try_connect_path
    test rax, rax
    jz .ok
    lea rdi, [rel wayland_path_3]
    mov rsi, r8
    call wl_try_connect_path
    test rax, rax
    jz .ok

    mov rdi, r8
    call hal_close
.fail:
    mov rax, -1
    ret
.ok:
    mov rax, r8
    ret

wl_disconnect:
    jmp hal_close

; wl_send(fd, buf, len)
wl_send:
    push rbx
    sub rsp, 96
    lea rbx, [rsp]

    ; iovec
    mov [rbx + 0], rsi
    mov [rbx + 8], rdx

    ; msghdr
    mov qword [rbx + 16], 0
    mov qword [rbx + 24], 0
    lea rax, [rbx + 0]
    mov [rbx + 32], rax
    mov qword [rbx + 40], 1
    mov qword [rbx + 48], 0
    mov qword [rbx + 56], 0
    mov qword [rbx + 64], 0
    mov qword [rbx + 72], 0

    mov rax, SYS_SENDMSG
    lea rsi, [rbx + 16]
    xor rdx, rdx
    syscall

    add rsp, 96
    pop rbx
    ret

; wl_send_fd(fd, buf, len, pass_fd)
wl_send_fd:
    push rbx
    sub rsp, 96
    lea rbx, [rsp]

    ; iovec
    mov [rbx + 0], rsi
    mov [rbx + 8], rdx

    ; cmsghdr + fd
    lea rax, [rel wl_ctrl_buf]
    mov qword [rax + 0], 20
    mov dword [rax + 8], SOL_SOCKET
    mov dword [rax + 12], SCM_RIGHTS
    mov dword [rax + 16], ecx
    mov dword [rax + 20], 0

    ; msghdr
    mov qword [rbx + 16], 0
    mov qword [rbx + 24], 0
    lea rax, [rbx + 0]
    mov [rbx + 32], rax
    mov qword [rbx + 40], 1
    lea rax, [rel wl_ctrl_buf]
    mov [rbx + 48], rax
    mov qword [rbx + 56], 24
    mov qword [rbx + 64], 0
    mov qword [rbx + 72], 0

    mov rax, SYS_SENDMSG
    lea rsi, [rbx + 16]
    xor rdx, rdx
    syscall

    add rsp, 96
    pop rbx
    ret

; wl_recv(fd, buf, max_len)
; blocking recvmsg
wl_recv:
    push rbx
    sub rsp, 96
    lea rbx, [rsp]

    mov [rbx + 0], rsi
    mov [rbx + 8], rdx

    mov qword [rbx + 16], 0
    mov qword [rbx + 24], 0
    lea rax, [rbx + 0]
    mov [rbx + 32], rax
    mov qword [rbx + 40], 1
    mov qword [rbx + 48], 0
    mov qword [rbx + 56], 0
    mov qword [rbx + 64], 0
    mov qword [rbx + 72], 0

    mov rax, SYS_RECVMSG
    lea rsi, [rbx + 16]
    xor rdx, rdx
    syscall

    add rsp, 96
    pop rbx
    ret

; wl_recv_nowait(fd, buf, max_len)
wl_recv_nowait:
    push rbx
    sub rsp, 96
    lea rbx, [rsp]

    mov [rbx + 0], rsi
    mov [rbx + 8], rdx

    mov qword [rbx + 16], 0
    mov qword [rbx + 24], 0
    lea rax, [rbx + 0]
    mov [rbx + 32], rax
    mov qword [rbx + 40], 1
    mov qword [rbx + 48], 0
    mov qword [rbx + 56], 0
    mov qword [rbx + 64], 0
    mov qword [rbx + 72], 0

    mov rax, SYS_RECVMSG
    lea rsi, [rbx + 16]
    mov rdx, MSG_DONTWAIT
    syscall

    add rsp, 96
    pop rbx
    ret

; wl_parse_event(buf, event_out)
; event_out: +0 sender(dd), +4 opcode(dd), +8 size(dd), +16 payload(dq)
wl_parse_event:
    mov eax, dword [rdi + 0]
    mov [rsi + 0], eax
    mov eax, dword [rdi + 4]
    mov edx, eax
    and edx, 0xFFFF
    mov [rsi + 4], edx
    shr eax, 16
    mov [rsi + 8], eax
    lea rax, [rdi + 8]
    mov [rsi + 16], rax
    ret

; wl_display_get_registry(sock_fd, registry_id)
wl_display_get_registry:
    mov r10, rdi
    mov r11d, esi
    mov edi, 1
    mov esi, 1
    mov edx, 12
    call wl_pack_opcode_size
    lea r8, [rel wl_tmp_buf]
    mov dword [r8 + 0], 1
    mov dword [r8 + 4], eax
    mov dword [r8 + 8], r11d
    mov rdi, r10
    mov rsi, r8
    mov rdx, 12
    jmp wl_send

; wl_display_sync(sock_fd, callback_id)
wl_display_sync:
    mov r10, rdi
    mov r11d, esi
    mov edi, 1
    mov esi, 0
    mov edx, 12
    call wl_pack_opcode_size
    lea r8, [rel wl_tmp_buf]
    mov dword [r8 + 0], 1
    mov dword [r8 + 4], eax
    mov dword [r8 + 8], r11d
    mov rdi, r10
    mov rsi, r8
    mov rdx, 12
    jmp wl_send

; wl_registry_bind(sock_fd, registry_id, name, iface_code, version, new_id)
wl_registry_bind:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov rbx, rdi
    mov r12d, esi                   ; registry_id
    mov r13d, edx                   ; name
    mov r14d, ecx                   ; iface code
    mov r15d, r8d                   ; version
    mov r11d, r9d                   ; new_id

    lea r10, [rel iface_compositor]
    mov ecx, 13
    cmp r14d, WL_IFACE_COMPOSITOR
    je .iface_selected
    lea r10, [rel iface_shm]
    mov ecx, 6
    cmp r14d, WL_IFACE_SHM
    je .iface_selected
    lea r10, [rel iface_xdg_wm_base]
    mov ecx, 11
    cmp r14d, WL_IFACE_XDG_WM_BASE
    je .iface_selected
    lea r10, [rel iface_seat]
    mov ecx, 7
.iface_selected:
    mov eax, ecx
    mov r14d, ecx                   ; raw string length
    inc eax
    add eax, 3
    and eax, -4
    mov edx, eax                    ; aligned string bytes
    add eax, 24
    mov r9d, eax                    ; total size

    mov edi, r12d
    mov esi, 0
    mov edx, r9d
    call wl_pack_opcode_size
    lea r8, [rel wl_tmp_buf]
    mov dword [r8 + 0], r12d
    mov dword [r8 + 4], eax
    mov dword [r8 + 8], r13d
    mov eax, ecx
    inc eax
    mov dword [r8 + 12], eax        ; strlen incl NUL

    ; Zero iface string field (wl_pack_opcode_size clobbers edx via shl edx,16)
    lea rdi, [r8 + 16]
    xor eax, eax
    mov ecx, r14d
    inc ecx
    add ecx, 3
    and ecx, -4
    rep stosb

    lea rdi, [r8 + 16]
    xor eax, eax
.copy_iface:
    cmp eax, r14d
    jae .iface_done
    mov dl, [r10 + rax]
    mov [rdi + rax], dl
    inc eax
    jmp .copy_iface
.iface_done:
    lea rdi, [r8 + 16]
    mov edx, r14d
    inc edx
    add edx, 3
    and edx, -4
    add rdi, rdx
    mov dword [rdi + 0], r15d
    mov dword [rdi + 4], r11d

    mov rdi, rbx
    mov rsi, r8
    mov edx, r9d
    call wl_send

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; wl_compositor_create_surface(sock_fd, compositor_id, surface_id)
; Uses ecx for surface_id — r12–r15 are callee-saved (SysV).
wl_compositor_create_surface:
    mov r10, rdi
    mov r11d, esi
    mov ecx, edx
    mov edi, r11d
    mov esi, 0
    mov edx, 12
    call wl_pack_opcode_size
    lea r8, [rel wl_tmp_buf]
    mov dword [r8 + 0], r11d
    mov dword [r8 + 4], eax
    mov dword [r8 + 8], ecx
    mov rdi, r10
    mov rsi, r8
    mov rdx, 12
    jmp wl_send

; wl_seat_get_pointer(sock_fd, seat_id, pointer_new_id)
wl_seat_get_pointer:
    mov r10, rdi
    mov r11d, esi
    mov ecx, edx
    mov edi, r11d
    xor esi, esi
    mov edx, 12
    call wl_pack_opcode_size
    lea r8, [rel wl_tmp_buf]
    mov dword [r8 + 0], r11d
    mov dword [r8 + 4], eax
    mov dword [r8 + 8], ecx
    mov rdi, r10
    mov rsi, r8
    mov rdx, 12
    jmp wl_send

; wl_seat_get_keyboard(sock_fd, seat_id, keyboard_new_id)
wl_seat_get_keyboard:
    mov r10, rdi
    mov r11d, esi
    mov ecx, edx
    mov edi, r11d
    mov esi, 1
    mov edx, 12
    call wl_pack_opcode_size
    lea r8, [rel wl_tmp_buf]
    mov dword [r8 + 0], r11d
    mov dword [r8 + 4], eax
    mov dword [r8 + 8], ecx
    mov rdi, r10
    mov rsi, r8
    mov rdx, 12
    jmp wl_send

; wl_shm_create_pool(sock_fd, shm_id, pool_id, shm_fd, size)
wl_shm_create_pool:
    push r12
    push r13
    push r14
    mov r10, rdi
    mov r11d, esi
    mov r12d, edx
    mov r13d, ecx
    mov r14d, r8d
    mov edi, r11d
    mov esi, 0
    mov edx, 16
    call wl_pack_opcode_size
    lea r8, [rel wl_tmp_buf]
    mov dword [r8 + 0], r11d
    mov dword [r8 + 4], eax
    mov dword [r8 + 8], r12d
    mov dword [r8 + 12], r14d
    mov rdi, r10
    mov rsi, r8
    mov rdx, 16
    mov ecx, r13d
    call wl_send_fd
    pop r14
    pop r13
    pop r12
    ret

; wl_shm_pool_create_buffer(sock_fd, pool_id, buffer_id, offset, w, h, stride, format)
wl_shm_pool_create_buffer:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    push r15

    mov r10, rdi
    mov r11d, esi
    mov r12d, edx
    mov r13d, ecx
    mov r14d, r8d
    mov r15d, r9d
    mov eax, dword [rbp + 16]       ; stride
    mov edx, dword [rbp + 24]       ; format

    mov edi, r11d
    mov esi, 0
    mov edx, 32
    call wl_pack_opcode_size

    lea r8, [rel wl_tmp_buf]
    mov dword [r8 + 0], r11d
    mov dword [r8 + 4], eax
    mov dword [r8 + 8], r12d
    mov dword [r8 + 12], r13d
    mov dword [r8 + 16], r14d
    mov dword [r8 + 20], r15d
    mov eax, dword [rbp + 16]
    mov dword [r8 + 24], eax
    mov eax, dword [rbp + 24]
    mov dword [r8 + 28], eax

    mov rdi, r10
    mov rsi, r8
    mov rdx, 32
    call wl_send

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

; wl_surface_attach(sock_fd, surface_id, buffer_id, x, y)
wl_surface_attach:
    push r12
    push r13
    push r14
    mov r10, rdi
    mov r11d, esi
    mov r12d, edx
    mov r13d, ecx
    mov r14d, r8d
    mov edi, r11d
    mov esi, 1
    mov edx, 20
    call wl_pack_opcode_size
    lea r8, [rel wl_tmp_buf]
    mov dword [r8 + 0], r11d
    mov dword [r8 + 4], eax
    mov dword [r8 + 8], r12d
    mov dword [r8 + 12], r13d
    mov dword [r8 + 16], r14d
    mov rdi, r10
    mov rsi, r8
    mov rdx, 20
    call wl_send
    pop r14
    pop r13
    pop r12
    ret

; wl_surface_damage(sock_fd, surface_id, x, y, w, h)
wl_surface_damage:
    push r12
    push r13
    push r14
    push r15
    mov r10, rdi
    mov r11d, esi
    mov r12d, edx
    mov r13d, ecx
    mov r14d, r8d
    mov r15d, r9d
    mov edi, r11d
    mov esi, 2
    mov edx, 24
    call wl_pack_opcode_size
    lea r8, [rel wl_tmp_buf]
    mov dword [r8 + 0], r11d
    mov dword [r8 + 4], eax
    mov dword [r8 + 8], r12d
    mov dword [r8 + 12], r13d
    mov dword [r8 + 16], r14d
    mov dword [r8 + 20], r15d
    mov rdi, r10
    mov rsi, r8
    mov rdx, 24
    call wl_send
    pop r15
    pop r14
    pop r13
    pop r12
    ret

; wl_surface_frame(sock_fd, surface_id, callback_id)
wl_surface_frame:
    mov r10, rdi
    mov r11d, esi
    mov ecx, edx
    mov edi, r11d
    mov esi, 3
    mov edx, 12
    call wl_pack_opcode_size
    lea r8, [rel wl_tmp_buf]
    mov dword [r8 + 0], r11d
    mov dword [r8 + 4], eax
    mov dword [r8 + 8], ecx
    mov rdi, r10
    mov rsi, r8
    mov rdx, 12
    jmp wl_send

; wl_surface_commit(sock_fd, surface_id)
wl_surface_commit:
    mov r10, rdi
    mov r11d, esi
    mov edi, r11d
    mov esi, 6
    mov edx, 8
    call wl_pack_opcode_size
    lea r8, [rel wl_tmp_buf]
    mov dword [r8 + 0], r11d
    mov dword [r8 + 4], eax
    mov rdi, r10
    mov rsi, r8
    mov rdx, 8
    jmp wl_send

; xdg_wm_base_get_xdg_surface(sock_fd, wm_base_id, xdg_surface_id, surface_id)
xdg_wm_base_get_xdg_surface:
    push r12
    push r13
    mov r10, rdi
    mov r11d, esi
    mov r12d, edx
    mov r13d, ecx
    mov edi, r11d
    mov esi, 2
    mov edx, 16
    call wl_pack_opcode_size
    lea r8, [rel wl_tmp_buf]
    mov dword [r8 + 0], r11d
    mov dword [r8 + 4], eax
    mov dword [r8 + 8], r12d
    mov dword [r8 + 12], r13d
    mov rdi, r10
    mov rsi, r8
    mov rdx, 16
    call wl_send
    pop r13
    pop r12
    ret

; xdg_surface_get_toplevel(sock_fd, xdg_surface_id, toplevel_id)
xdg_surface_get_toplevel:
    mov r10, rdi
    mov r11d, esi
    mov ecx, edx
    mov edi, r11d
    mov esi, 1
    mov edx, 12
    call wl_pack_opcode_size
    lea r8, [rel wl_tmp_buf]
    mov dword [r8 + 0], r11d
    mov dword [r8 + 4], eax
    mov dword [r8 + 8], ecx
    mov rdi, r10
    mov rsi, r8
    mov rdx, 12
    jmp wl_send

; xdg_toplevel_set_title(sock_fd, toplevel_id, title_ptr, title_len)
xdg_toplevel_set_title:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r10, rdi
    mov r11d, esi
    mov rbx, rdx
    mov r12d, ecx

    mov eax, r12d
    inc eax                         ; include NUL
    mov r13d, eax
    add eax, 3
    and eax, -4
    mov r14d, eax
    add eax, 12
    mov r15d, eax                   ; total size

    mov edi, r11d
    mov esi, 2
    mov edx, r15d
    call wl_pack_opcode_size
    lea r8, [rel wl_tmp_buf]
    mov dword [r8 + 0], r11d
    mov dword [r8 + 4], eax
    mov dword [r8 + 8], r13d

    lea rdi, [r8 + 12]
    xor eax, eax
    mov ecx, r14d
    rep stosb

    xor eax, eax
.copy_title:
    cmp eax, r12d
    jae .title_done
    mov dl, [rbx + rax]
    mov [r8 + 12 + rax], dl
    inc eax
    jmp .copy_title
.title_done:
    mov byte [r8 + 12 + r12], 0

    mov rdi, r10
    mov rsi, r8
    mov edx, r15d
    call wl_send
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; xdg_wm_base_pong(sock_fd, wm_base_id, serial)
xdg_wm_base_pong:
    mov r10, rdi
    mov r11d, esi
    mov ecx, edx
    mov edi, r11d
    mov esi, XDG_WM_BASE_PONG
    mov edx, 12
    call wl_pack_opcode_size
    lea r8, [rel wl_tmp_buf]
    mov dword [r8 + 0], r11d
    mov dword [r8 + 4], eax
    mov dword [r8 + 8], ecx
    mov rdi, r10
    mov rsi, r8
    mov rdx, 12
    jmp wl_send

; xdg_surface_ack_configure(sock_fd, xdg_surface_id, serial)
xdg_surface_ack_configure:
    mov r10, rdi
    mov r11d, esi
    mov ecx, edx
    mov edi, r11d
    mov esi, XDG_SURFACE_ACK_CFG
    mov edx, 12
    call wl_pack_opcode_size
    lea r8, [rel wl_tmp_buf]
    mov dword [r8 + 0], r11d
    mov dword [r8 + 4], eax
    mov dword [r8 + 8], ecx
    mov rdi, r10
    mov rsi, r8
    mov rdx, 12
    jmp wl_send
