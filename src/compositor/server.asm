; server.asm — Wayland compositor: Unix socket, clients, epoll
%include "src/hal/platform_defs.inc"
%include "src/compositor/compositor.inc"

extern hal_socket
extern hal_bind
extern hal_listen
extern hal_accept4
extern hal_close
extern hal_munmap
extern hal_unlink
extern eventloop_init
extern eventloop_add_fd
extern eventloop_remove_fd
extern eventloop_destroy
extern arena_init
extern arena_alloc
extern arena_destroy
extern proto_recv

%define EADDRINUSE_NEG       -98
%define EAGAIN_NEG           -11

section .rodata
    env_xdg            db "XDG_RUNTIME_DIR", 0
    env_xdg_len        equ $ - env_xdg - 1
    default_rt         db "/tmp", 0
    wl_prefix          db "wayland-", 0
    slash              db "/", 0

section .bss
    compositor_next_client_id resd 1

section .text
global compositor_server_init
global compositor_server_destroy
global compositor_listen_handler
global compositor_client_io_handler
global compositor_disconnect_client
global client_resource_add
global client_resource_find
global compositor_service_round
global client_resource_by_type_data

; find_env_value(envp, name, name_len) -> rax c-string or 0
find_env_value:
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    test rbx, rbx
    jz .none
    xor rcx, rcx
.env_loop:
    mov r8, [rbx + rcx*8]
    test r8, r8
    jz .none
    xor r9, r9
.cmp_loop:
    cmp r9, r13
    jae .check_eq
    mov al, [r8 + r9]
    cmp al, [r12 + r9]
    jne .next_env
    inc r9
    jmp .cmp_loop
.check_eq:
    cmp byte [r8 + r13], '='
    jne .next_env
    lea rax, [r8 + r13 + 1]
    jmp .ret
.next_env:
    inc rcx
    jmp .env_loop
.none:
    xor eax, eax
.ret:
    pop r13
    pop r12
    pop rbx
    ret

; build_socket_path(dest256, runtime_cstr, index_digit)
; rdi dest, rsi runtime, edx index 0..99
build_socket_path:
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdi
    mov r12, rsi
    mov r13d, edx
    xor r14d, r14d
.copy_rt:
    mov al, [r12 + r14]
    mov [rbx + r14], al
    test al, al
    je .rt_done
    inc r14d
    cmp r14d, 200
    jb .copy_rt
.rt_done:
    cmp r14d, 0
    je .fail
    dec r14d
    cmp byte [rbx + r14], '/'
    je .has_slash
    inc r14d
    mov byte [rbx + r14], '/'
    inc r14d
    jmp .wl
.has_slash:
    inc r14d
.wl:
    lea rsi, [rel wl_prefix]
.wl_c:
    lodsb
    test al, al
    je .digit
    mov [rbx + r14], al
    inc r14d
    cmp r14d, 250
    jb .wl_c
.digit:
    mov eax, r13d
    cmp eax, 10
    jb .one_d
    mov ecx, 10
    xor edx, edx
    div ecx
    add dl, '0'
    mov [rbx + r14], dl
    inc r14d
    add al, '0'
    mov [rbx + r14], al
    inc r14d
    jmp .zterm
.one_d:
    add al, '0'
    mov [rbx + r14], al
    inc r14d
.zterm:
    mov byte [rbx + r14], 0
    mov rax, rbx
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.fail:
    xor eax, eax
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; copy_display_name(dest16, index)
copy_display_name:
    push rbx
    mov rbx, rdi
    mov dword [rbx + 0], 0
    mov dword [rbx + 4], 0
    mov dword [rbx + 8], 0
    mov dword [rbx + 12], 0
    mov byte [rbx + 0], 'w'
    mov byte [rbx + 1], 'a'
    mov byte [rbx + 2], 'y'
    mov byte [rbx + 3], 'l'
    mov byte [rbx + 4], 'a'
    mov byte [rbx + 5], 'n'
    mov byte [rbx + 6], 'd'
    mov byte [rbx + 7], '-'
    mov eax, esi
    cmp eax, 10
    jb .one
    mov ecx, 10
    xor edx, edx
    div ecx
    add dl, '0'
    mov [rbx + 8], dl
    add al, '0'
    mov [rbx + 9], al
    jmp .done
.one:
    add al, '0'
    mov [rbx + 8], al
.done:
    pop rbx
    ret

; try_bind_listen(server, runtime, index) -> eax fd or negative errno
try_bind_listen:
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 144
    mov rbx, rdi
    mov r12, rsi
    mov r13d, edx

    lea rdi, [rbx + CS_SOCKET_PATH_OFF]
    mov rsi, r12
    mov edx, r13d
    call build_socket_path
    test rax, rax
    jz .fail

    lea rdi, [rbx + CS_SOCKET_PATH_OFF]
    call hal_unlink

    mov rdi, AF_UNIX
    mov rsi, SOCK_STREAM | SOCK_CLOEXEC | SOCK_NONBLOCK
    xor rdx, rdx
    call hal_socket
    test rax, rax
    js .fail_rax
    mov r14d, eax

    lea rdi, [rsp + 16]
    xor eax, eax
    mov ecx, 15
    rep stosq
    lea rdi, [rsp + 16]
    mov word [rdi], AF_UNIX
    lea rsi, [rbx + CS_SOCKET_PATH_OFF]
    lea rdi, [rsp + 18]
    xor rdx, rdx
.cp:
    mov al, [rsi + rdx]
    mov [rdi + rdx], al
    test al, al
    je .cp_done
    inc rdx
    cmp rdx, 107
    jb .cp
.cp_done:
    add rdx, 3
    movsx rdi, r14d
    lea rsi, [rsp + 16]
    call hal_bind
    test rax, rax
    js .bind_bad
    movsx rdi, r14d
    mov rsi, 16
    call hal_listen
    test rax, rax
    js .bind_bad
    mov eax, r14d
    jmp .ok
.bind_bad:
    mov r11, rax
    movsx rdi, r14d
    call hal_close
    mov rax, r11
    jmp .fail_rax
.fail:
    mov rax, -1
.ok:
    add rsp, 144
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.fail_rax:
    add rsp, 144
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; compositor_server_init(envp) -> rax server* or 0
compositor_server_init:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r15, rdi

    mov rdi, r15
    lea rsi, [rel env_xdg]
    mov rdx, env_xdg_len
    call find_env_value
    test rax, rax
    jnz .have_rt
    lea r12, [rel default_rt]
    jmp .after_rt
.have_rt:
    mov r12, rax
.after_rt:
    call eventloop_init
    test rax, rax
    jz .fail
    mov r13, rax

    mov rdi, 1048576
    call arena_init
    test rax, rax
    jz .fail_loop
    mov r14, rax

    mov rdi, r14
    mov rsi, CS_STRUCT_SIZE
    call arena_alloc
    test rax, rax
    jz .fail_partial_arena
    mov rbx, rax
    mov dword [rbx + CS_LISTEN_FD_OFF], -1

    mov rdi, r14
    mov rsi, SERVER_MAX_CLIENTS * 8
    call arena_alloc
    test rax, rax
    jz .fail_arena
    mov [rbx + CS_CLIENTS_OFF], rax

    xor r8d, r8d
.try_idx:
    cmp r8d, 16
    jae .fail_arena
    mov rdi, rbx
    mov rsi, r12
    mov edx, r8d
    call try_bind_listen
    test rax, rax
    jns .have_fd
    cmp rax, EADDRINUSE_NEG
    je .next_idx
    jmp .fail_arena
.next_idx:
    inc r8d
    jmp .try_idx
.have_fd:
    mov dword [rbx + CS_LISTEN_FD_OFF], eax

    lea rdi, [rbx + CS_DISPLAY_NAME_OFF]
    mov esi, r8d
    call copy_display_name

    mov qword [rbx + CS_EVENT_LOOP_OFF], r13
    mov qword [rbx + CS_ARENA_OFF], r14
    mov dword [rbx + CS_CLIENT_COUNT_OFF], 0
    mov dword [rbx + CS_CLIENT_CAP_OFF], SERVER_MAX_CLIENTS
    mov dword [rbx + CS_NEXT_GLOBAL_OFF], 6
    mov dword [rbx + CS_NEXT_SERIAL_OFF], 0
    mov qword [rbx + CS_KEYBOARD_FOCUS_OFF], 0
    mov qword [rbx + CS_POINTER_FOCUS_OFF], 0
    mov dword [rbx + CS_POINTER_FIX_X_OFF], 0
    mov dword [rbx + CS_POINTER_FIX_Y_OFF], 0
    lea rdi, [rbx + CS_KEY_STATE_OFF]
    mov ecx, 32
    xor eax, eax
    rep stosb

    mov rdi, r13
    movsx rsi, dword [rbx + CS_LISTEN_FD_OFF]
    mov rdx, EPOLLIN
    lea rcx, [rel compositor_listen_handler]
    mov r8, rbx
    call eventloop_add_fd
    test rax, rax
    jnz .fail_arena

    mov rax, rbx
    jmp .done

.fail_partial_arena:
    mov rdi, r14
    call arena_destroy
    jmp .fail_loop

.fail_arena:
    movsx rdi, dword [rbx + CS_LISTEN_FD_OFF]
    cmp rdi, 0
    jl .no_close
    call hal_close
.no_close:
    cmp byte [rbx + CS_SOCKET_PATH_OFF], 0
    je .no_unlink
    lea rdi, [rbx + CS_SOCKET_PATH_OFF]
    call hal_unlink
.no_unlink:
    mov rdi, r14
    call arena_destroy
.fail_loop:
    mov rdi, r13
    call eventloop_destroy
.fail:
    xor eax, eax
.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; compositor_server_destroy(server)
compositor_server_destroy:
    push rbx
    push r12
    push r13
    mov rbx, rdi
    test rbx, rbx
    jz .out

.rm_loop:
    cmp dword [rbx + CS_CLIENT_COUNT_OFF], 0
    je .no_clients
    mov rax, [rbx + CS_CLIENTS_OFF]
    mov rsi, [rax]
    test rsi, rsi
    je .no_clients
    mov rdi, rbx
    call compositor_disconnect_client
    jmp .rm_loop
.no_clients:
    mov rdi, [rbx + CS_EVENT_LOOP_OFF]
    movsx rsi, dword [rbx + CS_LISTEN_FD_OFF]
    call eventloop_remove_fd
    movsx rdi, dword [rbx + CS_LISTEN_FD_OFF]
    call hal_close
    lea rdi, [rbx + CS_SOCKET_PATH_OFF]
    call hal_unlink
    mov rdi, [rbx + CS_EVENT_LOOP_OFF]
    call eventloop_destroy
    mov rdi, [rbx + CS_ARENA_OFF]
    call arena_destroy
.out:
    pop r13
    pop r12
    pop rbx
    ret

; compositor_service_round(server) — one listen accept + one proto_recv per client
compositor_service_round:
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdi

    movsxd rdi, dword [rbx + CS_LISTEN_FD_OFF]
    mov esi, EPOLLIN
    mov rdx, rbx
    call compositor_listen_handler

    mov r12d, dword [rbx + CS_CLIENT_COUNT_OFF]
    test r12d, r12d
    jz .csr_out
    mov r13, [rbx + CS_CLIENTS_OFF]
    xor r14d, r14d
.csr_cli:
    cmp r14d, r12d
    jae .csr_out
    mov rsi, [r13 + r14*8]
    test rsi, rsi
    jz .csr_next
    mov r8, rsi
    movsxd rdi, dword [r8 + CC_FD_OFF]
    mov esi, EPOLLIN
    mov rdx, r8
    call compositor_client_io_handler
.csr_next:
    inc r14d
    jmp .csr_cli
.csr_out:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; compositor_listen_handler(fd, events, user_data)
compositor_listen_handler:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdx
    test esi, EPOLLERR
    jnz .out

    xor rsi, rsi
    xor rdx, rdx
    mov r10d, SOCK_CLOEXEC | SOCK_NONBLOCK
    call hal_accept4
    test rax, rax
    js .again
    mov r12d, eax

    mov eax, dword [rbx + CS_CLIENT_COUNT_OFF]
    cmp eax, dword [rbx + CS_CLIENT_CAP_OFF]
    jae .reject

    mov rdi, [rbx + CS_ARENA_OFF]
    mov rsi, CC_STRUCT_SIZE
    call arena_alloc
    test rax, rax
    jz .reject
    mov r13, rax

    mov rdi, [rbx + CS_ARENA_OFF]
    mov rsi, CLIENT_IO_BUF_CAP
    call arena_alloc
    test rax, rax
    jz .reject
    mov r14, rax

    mov rdi, [rbx + CS_ARENA_OFF]
    mov rsi, CLIENT_IO_BUF_CAP
    call arena_alloc
    test rax, rax
    jz .reject
    mov r15, rax

    mov dword [r13 + CC_FD_OFF], r12d
    mov qword [r13 + CC_SERVER_OFF], rbx
    mov qword [r13 + CC_RECV_BUF_OFF], r14
    mov dword [r13 + CC_RECV_CAP_OFF], CLIENT_IO_BUF_CAP
    mov dword [r13 + CC_RECV_LEN_OFF], 0
    mov qword [r13 + CC_SEND_BUF_OFF], r15
    mov dword [r13 + CC_SEND_CAP_OFF], CLIENT_IO_BUF_CAP
    mov dword [r13 + CC_SEND_LEN_OFF], 0
    mov dword [r13 + CC_RES_COUNT_OFF], 0
    mov dword [r13 + CC_RES_CAP_OFF], CLIENT_MAX_RESOURCES
    mov dword [r13 + CC_ALIVE_OFF], 1
    mov dword [r13 + CC_COMPOSITOR_ID_OFF], 0
    mov dword [r13 + CC_SHM_ID_OFF], 0
    mov dword [r13 + CC_SEAT_ID_OFF], 0
    mov dword [r13 + CC_WM_BASE_ID_OFF], 0
    mov dword [r13 + CC_PENDING_FD_OFF], -1
    mov dword [r13 + CC_KEYBOARD_ID_OFF], 0
    mov dword [r13 + CC_POINTER_ID_OFF], 0
    mov dword [r13 + CC_TOUCH_ID_OFF], 0

    mov eax, dword [compositor_next_client_id]
    inc dword [compositor_next_client_id]
    mov dword [r13 + CC_ID_OFF], eax

    xor ecx, ecx
.clear_res:
    cmp ecx, CLIENT_MAX_RESOURCES
    jae .res_done
    mov qword [r13 + CC_RESOURCES_OFF + rcx*8], 0
    inc ecx
    jmp .clear_res
.res_done:
    mov dword [r13 + CC_NEXT_SRV_ID_OFF], 2

    mov rdi, r13
    mov esi, 1
    mov edx, RESOURCE_DISPLAY
    xor ecx, ecx
    call client_resource_add
    test rax, rax
    jz .reject

    mov rax, [rbx + CS_CLIENTS_OFF]
    mov ecx, dword [rbx + CS_CLIENT_COUNT_OFF]
    mov [rax + rcx*8], r13
    inc dword [rbx + CS_CLIENT_COUNT_OFF]

    mov rdi, [rbx + CS_EVENT_LOOP_OFF]
    mov esi, r12d
    mov rdx, EPOLLIN
    lea rcx, [rel compositor_client_io_handler]
    mov r8, r13
    call eventloop_add_fd
    jmp .out
.reject:
    movsx rdi, r12d
    call hal_close
    jmp .out
.again:
    cmp rax, EAGAIN_NEG
    je .out
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; compositor_client_io_handler(fd, events, user_data)
compositor_client_io_handler:
    push rbx
    mov rbx, rdx
    test esi, EPOLLERR
    jnz .disc
    mov rdi, rbx
    call proto_recv
    cmp rax, -1
    je .disc
    jmp .out
.disc:
    mov rdi, [rbx + CC_SERVER_OFF]
    mov rsi, rbx
    call compositor_disconnect_client
.out:
    pop rbx
    ret

; compositor_disconnect_client(server, client)
compositor_disconnect_client:
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdi
    mov r12, rsi
    test r12, r12
    jz .out

    mov rdi, [rbx + CS_EVENT_LOOP_OFF]
    movsx rsi, dword [r12 + CC_FD_OFF]
    call eventloop_remove_fd

    movsx rdi, dword [r12 + CC_FD_OFF]
    call hal_close
    mov dword [r12 + CC_FD_OFF], -1
    mov dword [r12 + CC_ALIVE_OFF], 0

    mov rdi, r12
    call compositor_client_cleanup_pools

    mov r13, [rbx + CS_CLIENTS_OFF]
    mov r14d, dword [rbx + CS_CLIENT_COUNT_OFF]
    xor ecx, ecx
.find:
    cmp ecx, r14d
    jae .out
    cmp qword [r13 + rcx*8], r12
    je .found
    inc ecx
    jmp .find
.found:
    dec r14d
    mov rax, [r13 + r14*8]
    mov [r13 + rcx*8], rax
    mov dword [rbx + CS_CLIENT_COUNT_OFF], r14d
.out:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; compositor_client_cleanup_pools(client) — munmap/close SHM pools, pending SCM fd
compositor_client_cleanup_pools:
    push rbx
    push r12
    push r13
    push r14
    mov r12, rdi

    movsx rdi, dword [r12 + CC_PENDING_FD_OFF]
    cmp rdi, 0
    jl .no_pend
    call hal_close
.no_pend:
    mov dword [r12 + CC_PENDING_FD_OFF], -1

    xor r13d, r13d
.pool_loop:
    cmp r13d, dword [r12 + CC_RES_COUNT_OFF]
    jae .done
    mov rbx, [r12 + CC_RESOURCES_OFF + r13*8]
    inc r13d
    test rbx, rbx
    jz .pool_loop
    cmp dword [rbx + RES_TYPE_OFF], RESOURCE_SHM_POOL
    jne .pool_loop
    mov r14, [rbx + RES_DATA_OFF]
    test r14, r14
    jz .pool_loop
    mov rdi, [r14 + POOL_DATA_OFF]
    test rdi, rdi
    jz .no_unmap
    mov rsi, [r14 + POOL_SIZE_OFF]
    call hal_munmap
    mov qword [r14 + POOL_DATA_OFF], 0
.no_unmap:
    movsx rdi, dword [r14 + POOL_FD_OFF]
    cmp rdi, 0
    jl .pool_loop
    call hal_close
    mov dword [r14 + POOL_FD_OFF], -1
    jmp .pool_loop
.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; client_resource_by_type_data(client, type) -> rax first Resource* or 0
client_resource_by_type_data:
    xor ecx, ecx
.loop:
    cmp ecx, dword [rdi + CC_RES_COUNT_OFF]
    jae .none
    mov rax, [rdi + CC_RESOURCES_OFF + rcx*8]
    inc ecx
    test rax, rax
    jz .loop
    cmp dword [rax + RES_TYPE_OFF], esi
    jne .loop
    ret
.none:
    xor eax, eax
    ret

; client_resource_add(client, id, type, data)
client_resource_add:
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdi
    mov r12d, esi
    mov r13d, edx
    mov r14, rcx

    mov eax, dword [rbx + CC_RES_COUNT_OFF]
    cmp eax, CLIENT_MAX_RESOURCES
    jae .fail

    mov rdi, [rbx + CC_SERVER_OFF]
    mov rdi, [rdi + CS_ARENA_OFF]
    mov rsi, RES_STRUCT_SIZE
    call arena_alloc
    test rax, rax
    jz .fail

    mov dword [rax + RES_ID_OFF], r12d
    mov dword [rax + RES_TYPE_OFF], r13d
    mov qword [rax + RES_DATA_OFF], r14
    mov qword [rax + RES_CLIENT_OFF], rbx

    mov ecx, dword [rbx + CC_RES_COUNT_OFF]
    mov [rbx + CC_RESOURCES_OFF + rcx*8], rax
    inc dword [rbx + CC_RES_COUNT_OFF]
    jmp .ok
.fail:
    xor eax, eax
.ok:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; client_resource_find(client, id) -> rax Resource* or 0
client_resource_find:
    mov r8, rdi
    mov r9d, esi
    xor ecx, ecx
.loop:
    cmp ecx, dword [r8 + CC_RES_COUNT_OFF]
    jae .none
    mov rax, [r8 + CC_RESOURCES_OFF + rcx*8]
    test rax, rax
    jz .next
    cmp dword [rax + RES_ID_OFF], r9d
    je .done
.next:
    inc ecx
    jmp .loop
.none:
    xor eax, eax
.done:
    ret
