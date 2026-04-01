; test_input_routing.asm — keyboard/pointer routing (Phase 3 STEP 32)
%include "src/hal/platform_defs.inc"
%include "src/compositor/compositor.inc"

extern hal_write
extern hal_exit
extern hal_close
extern compositor_server_init
extern compositor_server_destroy
extern compositor_service_round
extern wl_display_get_registry
extern wl_registry_bind
extern wl_compositor_create_surface
extern wl_seat_get_keyboard
extern wl_seat_get_pointer
extern client_resource_by_type_data
extern surface_set_screen_pos
extern proto_flush
extern keyboard_set_focus
extern keyboard_handle_key
extern pointer_handle_motion
extern pointer_handle_button

%define SYS_RECVFROM           45
%define MSG_DONTWAIT           0x40
%define EAGAIN_NEG             -11

%define WL_IFACE_COMPOSITOR    1
%define WL_IFACE_SEAT          4

%define WL_KBD_ENTER_OPC       1
%define WL_KBD_LEAVE_OPC       2
%define WL_KBD_KEY_OPC         3

%define WL_PTR_ENTER_OPC       0
%define WL_PTR_LEAVE_OPC       1
%define WL_PTR_MOTION_OPC      2

%define WL_KBD_PRESSED         1

section .data
    env_xdg            db "XDG_RUNTIME_DIR=/tmp", 0
    envp_arr           dq env_xdg, 0
    pass_msg           db "ALL TESTS PASSED", 10
    pass_len           equ $ - pass_msg
    fail_init          db "FAIL: server_init", 10
    fail_init_len      equ $ - fail_init
    fail_conn          db "FAIL: connect", 10
    fail_conn_len      equ $ - fail_conn
    fail_t1            db "FAIL: t1 keyboard enter", 10
    fail_t1_len        equ $ - fail_t1
    fail_kbd_id        db "FAIL: surf client kbd id", 10
    fail_kbd_id_len    equ $ - fail_kbd_id
    fail_t2            db "FAIL: t2 keyboard leave/enter", 10
    fail_t2_len        equ $ - fail_t2
    fail_t3            db "FAIL: t3 key forward", 10
    fail_t3_len        equ $ - fail_t3
    fail_t4            db "FAIL: t4 pointer", 10
    fail_t4_len        equ $ - fail_t4
    fail_t5            db "FAIL: t5 pointer switch", 10
    fail_t5_len        equ $ - fail_t5
    fail_t6            db "FAIL: t6 click focus", 10
    fail_t6_len        equ $ - fail_t6

section .bss
    server_ptr         resq 1
    client1_fd         resd 1
    client2_fd         resd 1
    read_buf           resb 65536
    last_read_len      resd 1
    client1_ptr        resq 1
    client2_ptr        resq 1
    surf1_ptr          resq 1
    surf2_ptr          resq 1

section .text
global _start

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

pump_events:
    push rbx
    push r12
    mov rbx, rdi
    mov r12, rsi
.pl:
    test r12, r12
    jz .pd
    mov rdi, rbx
    call compositor_service_round
    dec r12
    jmp .pl
.pd:
    pop r12
    pop rbx
    ret

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
    js .ubad
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
    js .ubad_close
    mov eax, ebx
    jmp .uok
.ubad_close:
    mov r12, rax
    movsx rdi, ebx
    call hal_close
    mov rax, r12
    jmp .ubad
.ubad:
    or rax, -1
.uok:
    add rsp, 120
    pop r12
    pop rbx
    ret

; drain_one_read(fd) — one read into read_buf, sets last_read_len
drain_one_read:
    movsx rdi, edi
    lea rsi, [rel read_buf]
    mov rdx, 65536
    mov rax, SYS_READ
    syscall
    cmp rax, 0
    jle .bad
    mov dword [rel last_read_len], eax
    ret
.bad:
    mov dword [rel last_read_len], 0
    ret

; drain_client_stale(fd) — one large read (enough for post-handshake events)
drain_client_stale:
    movsx rdi, edi
    lea rsi, [rel read_buf]
    mov rdx, 65536
    mov rax, SYS_READ
    syscall
    ret

; drain_dontwait_loop(fd) — recv(MSG_DONTWAIT) until EAGAIN (empty server→client queue)
drain_dontwait_loop:
    push rbx
    mov ebx, edi
.lp:
    movsx rdi, ebx
    lea rsi, [rel read_buf]
    mov rdx, 65536
    mov r10, MSG_DONTWAIT
    xor r8, r8
    xor r9, r9
    mov rax, SYS_RECVFROM
    syscall
    cmp rax, 0
    jg .lp
    cmp rax, EAGAIN_NEG
    je .done
.done:
    pop rbx
    ret

; flush_surf_client(surface*) — proto_flush(surface->client)
flush_surf_client:
    mov rax, [rdi + SF_CLIENT_OFF]
    mov rdi, rax
    jmp proto_flush

; count_events(buf, len, object_id, opcode) -> eax
count_events:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi
    mov r12, rsi
    mov r13d, edx
    mov r14d, ecx
    xor r15d, r15d
    xor ecx, ecx
.walk:
    mov eax, r12d
    sub eax, ecx
    cmp eax, 8
    jb .done
    lea rdi, [rbx + rcx]
    mov eax, dword [rdi + 0]
    cmp eax, r13d
    jne .skip
    mov eax, dword [rdi + 4]
    and eax, 0xFFFF
    cmp eax, r14d
    jne .skip
    inc r15d
.skip:
    mov eax, dword [rdi + 4]
    shr eax, 16
    cmp eax, 8
    jb .done
    add ecx, eax
    jmp .walk
.done:
    mov eax, r15d
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

setup_one_client:
    ; rdi = server, esi = client fd
    push rbx
    push r12
    mov rbx, rdi
    mov r12d, esi

    mov edi, r12d
    mov esi, 2
    call wl_display_get_registry
    mov rdi, rbx
    mov rsi, 24
    call pump_events
    mov edi, r12d
    call drain_dontwait_loop

    mov edi, r12d
    mov esi, 2
    mov edx, 1
    mov ecx, WL_IFACE_COMPOSITOR
    mov r8d, 5
    mov r9d, 4
    call wl_registry_bind
    mov rdi, rbx
    mov rsi, 64
    call pump_events
    mov edi, r12d
    call drain_dontwait_loop

    mov edi, r12d
    mov esi, 4
    mov edx, 5
    call wl_compositor_create_surface
    mov rdi, rbx
    mov rsi, 128
    call pump_events
    mov edi, r12d
    call drain_dontwait_loop

    mov edi, r12d
    mov esi, 2
    mov edx, 3
    mov ecx, WL_IFACE_SEAT
    mov r8d, 7
    mov r9d, 6
    call wl_registry_bind
    mov rdi, rbx
    mov rsi, 24
    call pump_events
    mov edi, r12d
    call drain_dontwait_loop

    mov edi, r12d
    mov esi, 6
    mov edx, 10
    call wl_seat_get_keyboard
    mov rdi, rbx
    mov rsi, 64
    call pump_events
    mov edi, r12d
    call drain_dontwait_loop

    mov edi, r12d
    mov esi, 6
    mov edx, 11
    call wl_seat_get_pointer
    mov rdi, rbx
    mov rsi, 64
    call pump_events
    mov edi, r12d
    call drain_dontwait_loop

    pop r12
    pop rbx
    ret

_start:
    lea rdi, [rel envp_arr]
    call compositor_server_init
    test rax, rax
    jz .fail_init
    mov [rel server_ptr], rax

    mov rbx, rax
    lea rdi, [rbx + CS_SOCKET_PATH_OFF]
    call unix_connect
    test rax, rax
    js .fail_conn
    mov dword [rel client1_fd], eax

    mov rdi, rbx
    mov rsi, 32
    call pump_events
    mov edi, dword [rel client1_fd]
    call drain_dontwait_loop

    mov rax, [rbx + CS_CLIENTS_OFF]
    mov rax, [rax]
    mov [rel client1_ptr], rax

    mov rdi, rbx
    mov esi, dword [rel client1_fd]
    call setup_one_client

    mov rdi, [rel client1_ptr]
    mov esi, RESOURCE_SURFACE
    call client_resource_by_type_data
    test rax, rax
    jz .fail_t1
    mov rax, [rax + RES_DATA_OFF]
    mov [rel surf1_ptr], rax
    mov rdi, rax
    xor esi, esi
    xor edx, edx
    call surface_set_screen_pos
    mov rax, [rel surf1_ptr]
    mov dword [rax + SF_WIDTH_OFF], 400
    mov dword [rax + SF_HEIGHT_OFF], 300
    mov dword [rax + SF_MAPPED_OFF], 1

    lea rdi, [rbx + CS_SOCKET_PATH_OFF]
    call unix_connect
    test rax, rax
    js .fail_conn
    mov dword [rel client2_fd], eax

    mov rdi, [rel server_ptr]
    mov rsi, 32
    call pump_events
    mov edi, dword [rel client2_fd]
    call drain_dontwait_loop

    mov rax, [rbx + CS_CLIENTS_OFF]
    mov rcx, [rax + 8]
    mov [rel client2_ptr], rcx

    mov rdi, [rel server_ptr]
    mov esi, dword [rel client2_fd]
    call setup_one_client

    mov rdi, [rel client2_ptr]
    mov esi, RESOURCE_SURFACE
    call client_resource_by_type_data
    test rax, rax
    jz .fail_t1
    mov rax, [rax + RES_DATA_OFF]
    mov [rel surf2_ptr], rax
    mov rdi, rax
    mov esi, 400
    xor edx, edx
    call surface_set_screen_pos
    mov rax, [rel surf2_ptr]
    mov dword [rax + SF_WIDTH_OFF], 400
    mov dword [rax + SF_HEIGHT_OFF], 300
    mov dword [rax + SF_MAPPED_OFF], 1
    mov dword [rax + SF_Z_ORDER_OFF], 0
    mov rax, [rel surf1_ptr]
    mov dword [rax + SF_Z_ORDER_OFF], 1

    mov rax, [rel surf1_ptr]
    mov rax, [rax + SF_CLIENT_OFF]
    cmp dword [rax + CC_KEYBOARD_ID_OFF], 10
    jne .fail_kbd_id

    mov rdi, [rel server_ptr]
    xor esi, esi
    call keyboard_set_focus

    mov rdi, [rel server_ptr]
    mov rsi, [rel surf1_ptr]
    call keyboard_set_focus
    mov rdi, [rel surf1_ptr]
    call flush_surf_client
    mov edi, dword [rel client1_fd]
    call drain_one_read

    lea rdi, [rel read_buf]
    mov esi, dword [rel last_read_len]
    mov edx, 10
    mov ecx, WL_KBD_ENTER_OPC
    call count_events
    cmp eax, 1
    jne .fail_t1

    mov rdi, [rel server_ptr]
    mov rsi, [rel surf2_ptr]
    call keyboard_set_focus
    mov rdi, [rel surf1_ptr]
    call flush_surf_client
    mov rdi, [rel surf2_ptr]
    call flush_surf_client
    mov edi, dword [rel client1_fd]
    call drain_one_read

    lea rdi, [rel read_buf]
    mov esi, dword [rel last_read_len]
    mov edx, 10
    mov ecx, WL_KBD_LEAVE_OPC
    call count_events
    cmp eax, 1
    jne .fail_t2

    mov edi, dword [rel client2_fd]
    call drain_one_read
    lea rdi, [rel read_buf]
    mov esi, dword [rel last_read_len]
    mov edx, 10
    mov ecx, WL_KBD_ENTER_OPC
    call count_events
    cmp eax, 1
    jne .fail_t2

    mov rdi, [rel server_ptr]
    mov esi, KEY_A
    mov edx, WL_KBD_PRESSED
    call keyboard_handle_key
    mov rdi, [rel surf2_ptr]
    call flush_surf_client
    mov edi, dword [rel client2_fd]
    call drain_one_read

    lea rdi, [rel read_buf]
    mov esi, dword [rel last_read_len]
    mov edx, 10
    mov ecx, WL_KBD_KEY_OPC
    call count_events
    cmp eax, 1
    jne .fail_t3
    mov eax, dword [rel read_buf + 16]
    cmp eax, KEY_A + 8
    jne .fail_t3

    mov rdi, [rel server_ptr]
    mov esi, 200
    mov edx, 150
    call pointer_handle_motion
    mov rdi, [rel surf1_ptr]
    call flush_surf_client
    mov edi, dword [rel client1_fd]
    call drain_one_read

    lea rdi, [rel read_buf]
    mov esi, dword [rel last_read_len]
    mov edx, 11
    mov ecx, WL_PTR_ENTER_OPC
    call count_events
    cmp eax, 1
    jne .fail_t4
    lea rdi, [rel read_buf]
    mov esi, dword [rel last_read_len]
    mov edx, 11
    mov ecx, WL_PTR_MOTION_OPC
    call count_events
    cmp eax, 1
    jne .fail_t4

    mov rdi, [rel server_ptr]
    mov esi, 500
    mov edx, 150
    call pointer_handle_motion
    mov rdi, [rel surf1_ptr]
    call flush_surf_client
    mov rdi, [rel surf2_ptr]
    call flush_surf_client
    mov edi, dword [rel client1_fd]
    call drain_one_read

    lea rdi, [rel read_buf]
    mov esi, dword [rel last_read_len]
    mov edx, 11
    mov ecx, WL_PTR_LEAVE_OPC
    call count_events
    cmp eax, 1
    jne .fail_t5

    mov edi, dword [rel client2_fd]
    call drain_one_read
    lea rdi, [rel read_buf]
    mov esi, dword [rel last_read_len]
    mov edx, 11
    mov ecx, WL_PTR_ENTER_OPC
    call count_events
    cmp eax, 1
    jne .fail_t5
    lea rdi, [rel read_buf]
    mov esi, dword [rel last_read_len]
    mov edx, 11
    mov ecx, WL_PTR_MOTION_OPC
    call count_events
    cmp eax, 1
    jne .fail_t5

    mov rdi, [rel server_ptr]
    mov rsi, [rel surf1_ptr]
    call keyboard_set_focus
    mov rdi, [rel surf1_ptr]
    call flush_surf_client
    mov rdi, [rel surf2_ptr]
    call flush_surf_client
    mov edi, dword [rel client1_fd]
    call drain_one_read
    mov edi, dword [rel client2_fd]
    call drain_one_read

    mov rdi, [rel server_ptr]
    mov esi, 500
    mov edx, 150
    call pointer_handle_motion
    mov rdi, [rel server_ptr]
    mov esi, BTN_LEFT
    mov edx, 1
    call pointer_handle_button
    mov rdi, [rel surf1_ptr]
    call flush_surf_client
    mov rdi, [rel surf2_ptr]
    call flush_surf_client

    mov rax, [rel server_ptr]
    mov rax, [rax + CS_KEYBOARD_FOCUS_OFF]
    cmp rax, [rel surf2_ptr]
    jne .fail_t6

    mov rdi, [rel server_ptr]
    call compositor_server_destroy
    movsx rdi, dword [rel client1_fd]
    call hal_close
    movsx rdi, dword [rel client2_fd]
    call hal_close

    write_stdout pass_msg, pass_len
    xor edi, edi
    call hal_exit

.fail_init:
    fail fail_init, fail_init_len
.fail_conn:
    fail fail_conn, fail_conn_len
.fail_kbd_id:
    fail fail_kbd_id, fail_kbd_id_len
.fail_t1:
    fail fail_t1, fail_t1_len
.fail_t2:
    fail fail_t2, fail_t2_len
.fail_t3:
    fail fail_t3, fail_t3_len
.fail_t4:
    fail fail_t4, fail_t4_len
.fail_t5:
    fail fail_t5, fail_t5_len
.fail_t6:
    fail fail_t6, fail_t6_len
