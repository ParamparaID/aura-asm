; test_surfaces.asm — SHM pools, surfaces, XDG, compositor_render (Phase 3)
%include "src/hal/platform_defs.inc"
%include "src/compositor/compositor.inc"
%include "src/canvas/canvas.inc"

extern hal_write
extern hal_exit
extern hal_close
extern hal_memfd_create
extern hal_ftruncate
extern hal_mmap
extern hal_munmap
extern compositor_server_init
extern compositor_server_destroy
extern compositor_service_round
extern wl_display_get_registry
extern wl_registry_bind
extern wl_compositor_create_surface
extern wl_shm_create_pool
extern wl_shm_pool_create_buffer
extern wl_surface_attach
extern wl_surface_commit
extern wl_surface_frame
extern xdg_wm_base_get_xdg_surface
extern xdg_surface_get_toplevel
extern xdg_surface_ack_configure
extern wl_recv
extern wl_parse_event
extern client_resource_find
extern surface_find_by_id
extern surface_set_screen_pos
extern canvas_init
extern canvas_destroy
extern canvas_get_pixel
extern compositor_render

%define WL_IFACE_COMPOSITOR    1
%define WL_IFACE_SHM           2
%define WL_IFACE_XDG_WM_BASE   3

%define RED_PIX                0xFFFF0000

section .data
    env_xdg            db "XDG_RUNTIME_DIR=/tmp", 0
    envp_arr           dq env_xdg, 0
    memfd_name         db "surf", 0

    pass_msg           db "ALL TESTS PASSED", 10
    pass_len           equ $ - pass_msg
    fail_init          db "FAIL: server_init", 10
    fail_init_len      equ $ - fail_init
    fail_conn          db "FAIL: connect", 10
    fail_conn_len      equ $ - fail_conn

section .bss
    server_ptr         resq 1
    client_fd          resd 1
    mem_fd             resd 1
    read_buf           resb 16384
    event_tmp          resb 32
    out_canvas         resq 1
    cfg_serial         resd 1

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

    fail_s1 db "FAIL: t1 surface", 10
    len_s1  equ $ - fail_s1
    fail_s2 db "FAIL: t2 buffer", 10
    len_s2  equ $ - fail_s2
    fail_s3 db "FAIL: t3 mapped", 10
    len_s3  equ $ - fail_s3
    fail_s4 db "FAIL: t4 pixel", 10
    len_s4  equ $ - fail_s4
    fail_s5 db "FAIL: t5 frame", 10
    len_s5  equ $ - fail_s5

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
.ucp:
    mov al, [rdi + rdx]
    mov [rcx + rdx], al
    test al, al
    je .ud
    inc rdx
    cmp rdx, 107
    jb .ucp
.ud:
    add rdx, 3
    mov rax, SYS_CONNECT
    movsx rdi, ebx
    lea rsi, [rsp + 8]
    syscall
    test rax, rax
    js .ucl
    mov eax, ebx
    jmp .uok
.ucl:
    movsx rdi, ebx
    call hal_close
    or rax, -1
    jmp .ux
.ubad:
    or rax, -1
    jmp .ux
.uok:
    add rsp, 120
    pop r12
    pop rbx
    ret
.ux:
    add rsp, 120
    pop r12
    pop rbx
    ret

; parse_xdg_surface_configure(buf, len, want_id) -> eax serial or 0
parse_xdg_cfg:
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
    jb .pz
    lea rdi, [rbx + r15]
    lea rsi, [rel event_tmp]
    call wl_parse_event
    mov eax, dword [rel event_tmp + 0]
    cmp eax, r13d
    jne .sk
    mov eax, dword [rel event_tmp + 4]
    test eax, eax
    jnz .sk
    mov eax, dword [rel event_tmp + 8]
    cmp eax, 12
    jb .sk
    mov rax, qword [rel event_tmp + 16]
    mov eax, dword [rax]
    jmp .pdone
.sk:
    mov eax, dword [rel event_tmp + 8]
    add r15, rax
    jmp .walk
.pz:
    xor eax, eax
.pdone:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; parse_cb_done(buf, len, cb_id) -> eax data or 0
parse_cb_done:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi
    mov r12, rsi
    mov r13d, edx
    xor r15d, r15d
.w2:
    mov rax, r12
    sub rax, r15
    cmp rax, 8
    jb .z2
    lea rdi, [rbx + r15]
    lea rsi, [rel event_tmp]
    call wl_parse_event
    mov eax, dword [rel event_tmp + 0]
    cmp eax, r13d
    jne .s2
    mov eax, dword [rel event_tmp + 4]
    test eax, eax
    jnz .s2
    mov eax, dword [rel event_tmp + 8]
    cmp eax, 12
    jb .s2
    mov rax, qword [rel event_tmp + 16]
    mov eax, dword [rax]
    jmp .d2
.s2:
    mov eax, dword [rel event_tmp + 8]
    add r15, rax
    jmp .w2
.z2:
    xor eax, eax
.d2:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

_start:
    lea rdi, [rel envp_arr]
    call compositor_server_init
    test rax, rax
    jz .bad_init
    mov [rel server_ptr], rax

    mov rax, [rel server_ptr]
    lea rdi, [rax + CS_SOCKET_PATH_OFF]
    call unix_connect
    cmp eax, 0
    jl .bad_conn
    mov dword [rel client_fd], eax

    mov rdi, [rel server_ptr]
    mov rsi, 4
    call pump_events

    movsx rdi, dword [rel client_fd]
    mov esi, 2
    call wl_display_get_registry
    mov rdi, [rel server_ptr]
    mov rsi, 16
    call pump_events

    movsx rdi, dword [rel client_fd]
    mov esi, 2
    mov edx, 1
    mov ecx, WL_IFACE_COMPOSITOR
    mov r8d, 5
    mov r9d, 6
    call wl_registry_bind
    mov rdi, [rel server_ptr]
    mov rsi, 4
    call pump_events

    movsx rdi, dword [rel client_fd]
    mov esi, 2
    mov edx, 2
    mov ecx, WL_IFACE_SHM
    mov r8d, 1
    mov r9d, 7
    call wl_registry_bind
    mov rdi, [rel server_ptr]
    mov rsi, 4
    call pump_events

    movsx rdi, dword [rel client_fd]
    mov esi, 2
    mov edx, 4
    mov ecx, WL_IFACE_XDG_WM_BASE
    mov r8d, 2
    mov r9d, 8
    call wl_registry_bind
    mov rdi, [rel server_ptr]
    mov rsi, 4
    call pump_events

    ; --- Test 1: create_surface id 10 ---
    movsx rdi, dword [rel client_fd]
    mov esi, 6
    mov edx, 10
    call wl_compositor_create_surface
    mov rdi, [rel server_ptr]
    mov rsi, 4
    call pump_events

    mov rax, [rel server_ptr]
    mov rax, [rax + CS_CLIENTS_OFF]
    mov rdi, [rax]
    mov esi, 10
    call client_resource_find
    test rax, rax
    jz .f1
    cmp dword [rax + RES_TYPE_OFF], RESOURCE_SURFACE
    jne .f1

    ; --- memfd + red fill ---
    lea rdi, [rel memfd_name]
    mov rsi, MFD_CLOEXEC
    call hal_memfd_create
    cmp rax, 0
    jl .f1
    mov dword [rel mem_fd], eax
    movsx rdi, eax
    mov rsi, 40000
    call hal_ftruncate

    xor rdi, rdi
    mov rsi, 40000
    mov rdx, PROT_READ | PROT_WRITE
    mov rcx, MAP_SHARED
    movsx r8, dword [rel mem_fd]
    xor r9, r9
    call hal_mmap
    test rax, rax
    js .f1
    mov r12, rax
    mov rdi, r12
    mov ecx, 10000
    mov eax, RED_PIX
    rep stosd
    mov rdi, r12
    mov rsi, 40000
    call hal_munmap
.filled:

    ; --- Test 2: pool + buffer ---
    movsx rdi, dword [rel client_fd]
    mov esi, 7
    mov edx, 20
    mov ecx, dword [rel mem_fd]
    mov r8d, 40000
    call wl_shm_create_pool
    mov rdi, [rel server_ptr]
    mov rsi, 8
    call pump_events

    movsx rdi, dword [rel client_fd]
    mov esi, 20
    mov edx, 21
    xor ecx, ecx
    mov r8d, 100
    mov r9d, 100
    push qword 0
    push qword 400
    call wl_shm_pool_create_buffer
    add rsp, 16
    mov rdi, [rel server_ptr]
    mov rsi, 4
    call pump_events

    mov rax, [rel server_ptr]
    mov rax, [rax + CS_CLIENTS_OFF]
    mov rdi, [rax]
    mov esi, 21
    call client_resource_find
    test rax, rax
    jz .f2
    cmp dword [rax + RES_TYPE_OFF], RESOURCE_BUFFER
    jne .f2
    mov rax, [rax + RES_DATA_OFF]
    test rax, rax
    jz .f2
    mov rax, [rax + BUF_PIXELS_OFF]
    test rax, rax
    jz .f2
    cmp dword [rax], RED_PIX
    jne .f2

    ; --- Test 3: XDG + attach + commit + mapped ---
    movsx rdi, dword [rel client_fd]
    mov esi, 8
    mov edx, 11
    mov ecx, 10
    call xdg_wm_base_get_xdg_surface
    mov rdi, [rel server_ptr]
    mov rsi, 4
    call pump_events

    movsx rdi, dword [rel client_fd]
    mov esi, 11
    mov edx, 12
    call xdg_surface_get_toplevel
    mov rdi, [rel server_ptr]
    mov rsi, 8
    call pump_events

    movsx rdi, dword [rel client_fd]
    lea rsi, [rel read_buf]
    mov rdx, 16384
    call wl_recv
    cmp rax, 8
    jl .f3
    lea rdi, [rel read_buf]
    mov rsi, rax
    mov edx, 11
    call parse_xdg_cfg
    test eax, eax
    jz .f3
    mov dword [rel cfg_serial], eax

    movsx rdi, dword [rel client_fd]
    mov esi, 11
    mov edx, dword [rel cfg_serial]
    call xdg_surface_ack_configure
    mov rdi, [rel server_ptr]
    mov rsi, 4
    call pump_events

    movsx rdi, dword [rel client_fd]
    mov esi, 10
    mov edx, 21
    xor ecx, ecx
    xor r8d, r8d
    call wl_surface_attach
    movsx rdi, dword [rel client_fd]
    mov esi, 10
    call wl_surface_commit
    mov rdi, [rel server_ptr]
    mov rsi, 8
    call pump_events

    mov rax, [rel server_ptr]
    mov rax, [rax + CS_CLIENTS_OFF]
    mov rdi, [rax]
    mov esi, 10
    call surface_find_by_id
    test rax, rax
    jz .f3
    cmp dword [rax + SF_MAPPED_OFF], 1
    jne .f3

    ; --- Test 4: composite pixel ---
    mov rdi, rax
    mov esi, 100
    mov edx, 100
    call surface_set_screen_pos

    mov rdi, 800
    mov rsi, 600
    call canvas_init
    test rax, rax
    jz .f4
    mov [rel out_canvas], rax

    mov rdi, [rel server_ptr]
    mov rsi, [rel out_canvas]
    mov edx, 0xFF333333
    call compositor_render

    mov rdi, [rel out_canvas]
    mov rsi, 150
    mov rdx, 150
    call canvas_get_pixel
    and eax, 0x00FFFFFF
    cmp eax, 0x00FF0000
    jne .f4

    ; --- Test 5: frame callback ---
    movsx rdi, dword [rel client_fd]
    mov esi, 10
    mov edx, 30
    call wl_surface_frame
    movsx rdi, dword [rel client_fd]
    mov esi, 10
    call wl_surface_commit
    mov rdi, [rel server_ptr]
    mov rsi, 8
    call pump_events

    mov rdi, [rel server_ptr]
    mov rsi, [rel out_canvas]
    mov edx, 0xFF333333
    call compositor_render

    movsx rdi, dword [rel client_fd]
    lea rsi, [rel read_buf]
    mov rdx, 16384
    call wl_recv
    cmp rax, 8
    jl .f5
    lea rdi, [rel read_buf]
    mov rsi, rax
    mov edx, 30
    call parse_cb_done
    test eax, eax
    jz .f5

    mov rdi, [rel out_canvas]
    call canvas_destroy
    movsx rdi, dword [rel mem_fd]
    call hal_close
    movsx rdi, dword [rel client_fd]
    call hal_close
    mov rdi, [rel server_ptr]
    call compositor_server_destroy

    write_stdout pass_msg, pass_len
    xor rdi, rdi
    call hal_exit

.bad_init:
    fail fail_init, fail_init_len
.bad_conn:
    fail fail_conn, fail_conn_len
.f1:
    fail fail_s1, len_s1
.f2:
    fail fail_s2, len_s2
.f3:
    fail fail_s3, len_s3
.f4:
    fail fail_s4, len_s4
.f5:
    fail fail_s5, len_s5
