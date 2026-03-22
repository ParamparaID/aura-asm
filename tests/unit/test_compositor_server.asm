; test_compositor_server.asm — Wayland compositor socket + registry (Phase 3)
%include "src/hal/linux_x86_64/defs.inc"
%include "src/compositor/compositor.inc"

extern hal_write
extern hal_exit
extern hal_close
extern compositor_server_init
extern compositor_server_destroy
extern compositor_service_round
extern wl_display_get_registry
extern wl_display_sync
extern wl_registry_bind
extern wl_recv
extern wl_parse_event

section .data
    env_xdg            db "XDG_RUNTIME_DIR=/tmp", 0
    envp_arr           dq env_xdg, 0

    pass_msg           db "ALL TESTS PASSED", 10
    pass_len           equ $ - pass_msg

    fail_init          db "FAIL: server_init", 10
    fail_init_len      equ $ - fail_init
    fail_sock          db "FAIL: socket file", 10
    fail_sock_len      equ $ - fail_sock
    fail_conn          db "FAIL: connect", 10
    fail_conn_len      equ $ - fail_conn
    fail_count1        db "FAIL: client_count!=1", 10
    fail_count1_len    equ $ - fail_count1
    fail_global        db "FAIL: wl_compositor global", 10
    fail_global_len    equ $ - fail_global
    fail_sync          db "FAIL: sync done", 10
    fail_sync_len      equ $ - fail_sync
    fail_bind          db "FAIL: shm format", 10
    fail_bind_len      equ $ - fail_bind
    fail_count0        db "FAIL: client_count!=0", 10
    fail_count0_len    equ $ - fail_count0

    needle             db "wl_compositor", 0
    needle_len         equ 13

section .bss
    server_ptr         resq 1
    client_fd          resd 1
    read_buf           resb 8192
    event_tmp          resb 32

section .text
global _start

%define WL_IFACE_SHM       2

%macro write_stdout 2
    mov rdi, STDOUT
    lea rsi, [rel %1]
    mov rdx, %2
    call hal_write
%endmacro

%macro fail 2
    write_stdout %1, %2
    mov rdi, 1
    call hal_exit
%endmacro

; pump_events(server, times) — direct service rounds (avoids O(64*handlers) eventloop_run cost)
pump_events:
    push rbx
    push r12
    mov rbx, rdi
    mov r12, rsi
.loop:
    test r12, r12
    jz .done
    mov rdi, rbx
    call compositor_service_round
    dec r12
    jmp .loop
.done:
    pop r12
    pop rbx
    ret

; unix_connect(path) -> eax fd or negative
unix_connect:
    push rbx
    push r12
    sub rsp, 120
    mov r12, rdi

    mov rax, SYS_SOCKET
    mov rdi, AF_UNIX
    mov rsi, SOCK_STREAM
    xor rdx, rdx
    syscall
    test rax, rax
    js .bad
    mov ebx, eax

    lea rdi, [rsp + 8]
    xor eax, eax
    mov ecx, 14
    rep stosq
    lea rdi, [rsp + 8]
    mov word [rdi], AF_UNIX
    lea rcx, [rdi + 2]
    mov rdi, r12
    xor rdx, rdx
.cp:
    mov al, [rdi + rdx]
    mov [rcx + rdx], al
    test al, al
    je .cp_done
    inc rdx
    cmp rdx, 107
    jb .cp
.cp_done:
    add rdx, 3
    mov rax, SYS_CONNECT
    movsx rdi, ebx
    lea rsi, [rsp + 8]
    syscall
    test rax, rax
    js .bad_close
    mov eax, ebx
    jmp .ok
.bad_close:
    mov r12, rax
    movsx rdi, ebx
    call hal_close
    mov rax, r12
    jmp .bad
.bad:
    or rax, -1
.ok:
    add rsp, 120
    pop r12
    pop rbx
    ret

; parse_done_serial(buf, len, callback_id) -> eax serial or 0
parse_done_serial:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi
    mov r12, rsi
    mov r13d, edx
    xor r15d, r15d
.walk:
    mov rax, r12
    sub rax, r15
    cmp rax, 8
    jb .zero
    lea rdi, [rbx + r15]
    lea rsi, [rel event_tmp]
    call wl_parse_event
    mov eax, dword [rel event_tmp + 0]
    cmp eax, r13d
    jne .skip
    mov eax, dword [rel event_tmp + 4]
    test eax, eax
    jnz .skip
    mov eax, dword [rel event_tmp + 8]
    cmp eax, 12
    jb .skip
    mov rax, qword [rel event_tmp + 16]
    mov eax, dword [rax]
    jmp .done
.skip:
    mov eax, dword [rel event_tmp + 8]
    add r15, rax
    jmp .walk
.zero:
    xor eax, eax
.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; parse_shm_format(buf, len, shm_id) -> eax format or -1
parse_shm_format:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi
    mov r12, rsi
    mov r13d, edx
    xor r15d, r15d
.walk:
    mov rax, r12
    sub rax, r15
    cmp rax, 8
    jb .neg
    lea rdi, [rbx + r15]
    lea rsi, [rel event_tmp]
    call wl_parse_event
    mov eax, dword [rel event_tmp + 0]
    cmp eax, r13d
    jne .skip
    mov eax, dword [rel event_tmp + 4]
    test eax, eax
    jnz .skip
    mov eax, dword [rel event_tmp + 8]
    cmp eax, 12
    jb .skip
    mov rax, qword [rel event_tmp + 16]
    mov eax, dword [rax]
    jmp .done
.skip:
    mov eax, dword [rel event_tmp + 8]
    add r15, rax
    jmp .walk
.neg:
    mov eax, -1
.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

_start:
    ; --- Test 1: init + socket path ---
    lea rdi, [rel envp_arr]
    call compositor_server_init
    test rax, rax
    jz .f_init
    mov [rel server_ptr], rax

    mov rax, [rel server_ptr]
    cmp dword [rax + CS_LISTEN_FD_OFF], 0
    jle .f_init

    mov rax, SYS_ACCESS
    mov rdi, [rel server_ptr]
    lea rdi, [rdi + CS_SOCKET_PATH_OFF]
    mov rsi, F_OK
    syscall
    test rax, rax
    jnz .f_sock

    ; --- Test 2: client connect + count ---
    mov rdi, [rel server_ptr]
    lea rdi, [rdi + CS_SOCKET_PATH_OFF]
    call unix_connect
    test rax, rax
    js .f_conn
    mov dword [rel client_fd], eax

    mov rdi, [rel server_ptr]
    mov rsi, 4
    call pump_events

    mov rax, [rel server_ptr]
    cmp dword [rax + CS_CLIENT_COUNT_OFF], 1
    jne .f_count1

    ; --- Test 3: get_registry + globals ---
    movsx rdi, dword [rel client_fd]
    mov esi, 2
    call wl_display_get_registry

    mov rdi, [rel server_ptr]
    mov rsi, 16
    call pump_events

    movsx rdi, dword [rel client_fd]
    lea rsi, [rel read_buf]
    mov rdx, 8192
    call wl_recv
    cmp rax, 0
    jl .f_global
    cmp rax, 8
    jl .f_global

    lea r10, [rel read_buf]
    mov r11, rax
    xor r15, r15
.gsearch:
    mov rax, r15
    add rax, needle_len
    cmp rax, r11
    ja .f_global
    xor r8, r8
.gmatch:
    cmp r8, needle_len
    jae .gfound
    lea r9, [r10 + r15]
    movzx eax, byte [r9 + r8]
    lea rcx, [rel needle]
    movzx ecx, byte [rcx + r8]
    cmp al, cl
    jne .gnext
    inc r8
    jmp .gmatch
.gnext:
    inc r15
    jmp .gsearch
.gfound:

    ; --- Test 4: sync + done ---
    movsx rdi, dword [rel client_fd]
    mov esi, 3
    call wl_display_sync

    mov rdi, [rel server_ptr]
    mov rsi, 4
    call pump_events

    movsx rdi, dword [rel client_fd]
    lea rsi, [rel read_buf]
    mov rdx, 8192
    call wl_recv
    cmp rax, 0
    jl .f_sync
    cmp rax, 8
    jl .f_sync

    lea rdi, [rel read_buf]
    mov rsi, rax
    mov edx, 3
    call parse_done_serial
    test eax, eax
    jz .f_sync

    ; --- Test 5: bind wl_shm + format ---
    movsx rdi, dword [rel client_fd]
    mov esi, 2
    mov edx, 2
    mov ecx, WL_IFACE_SHM
    mov r8d, 1
    mov r9d, 4
    call wl_registry_bind

    mov rdi, [rel server_ptr]
    mov rsi, 4
    call pump_events

    movsx rdi, dword [rel client_fd]
    lea rsi, [rel read_buf]
    mov rdx, 8192
    call wl_recv
    cmp rax, 0
    jl .f_bind
    cmp rax, 8
    jl .f_bind

    lea rdi, [rel read_buf]
    mov rsi, rax
    mov edx, 4
    call parse_shm_format
    cmp eax, 0
    jne .f_bind

    ; --- Test 6: disconnect ---
    movsx rdi, dword [rel client_fd]
    call hal_close

    mov rdi, [rel server_ptr]
    mov rsi, 8
    call pump_events

    mov rax, [rel server_ptr]
    cmp dword [rax + CS_CLIENT_COUNT_OFF], 0
    jne .f_count0

    mov rdi, [rel server_ptr]
    call compositor_server_destroy

    write_stdout pass_msg, pass_len
    xor rdi, rdi
    call hal_exit

.f_init:
    fail fail_init, fail_init_len
.f_sock:
    fail fail_sock, fail_sock_len
.f_conn:
    fail fail_conn, fail_conn_len
.f_count1:
    fail fail_count1, fail_count1_len
.f_global:
    fail fail_global, fail_global_len
.f_sync:
    fail fail_sync, fail_sync_len
.f_bind:
    fail fail_bind, fail_bind_len
.f_count0:
    fail fail_count0, fail_count0_len
