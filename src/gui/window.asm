; window.asm
; Wayland-backed window management for Aura Shell.

%include "src/hal/platform_defs.inc"

extern hal_mmap
extern hal_munmap
extern hal_close
extern wl_connect
extern wl_disconnect
extern wl_recv
extern wl_recv_nowait
extern wl_display_get_registry
extern wl_display_sync
extern wl_registry_bind
extern wl_compositor_create_surface
extern wl_shm_create_pool
extern wl_shm_pool_create_buffer
extern wl_surface_attach
extern wl_surface_damage
extern wl_surface_commit
extern xdg_wm_base_get_xdg_surface
extern xdg_surface_get_toplevel
extern xdg_toplevel_set_title
extern xdg_wm_base_pong
extern xdg_surface_ack_configure
extern wayland_input_init
extern wayland_input_handle_registry_global
extern wayland_input_handle_message
extern canvas_init
extern canvas_destroy

%define PAGE_SIZE                    4096
%define IFACE_COMPOSITOR             1
%define IFACE_SHM                    2
%define IFACE_XDG_WM_BASE            3
%define WL_SHM_FORMAT_ARGB8888       0

%define CANVAS_BUF_OFF               0
%define CANVAS_SIZE_OFF              24

; Window layout
%define W_SOCK_FD_OFF                0   ; dq
%define W_WIDTH_OFF                  8   ; dd
%define W_HEIGHT_OFF                 12  ; dd
%define W_CANVAS_PTR_OFF             16  ; dq
%define W_SURFACE_ID_OFF             24  ; dd
%define W_BUFFER_ID_OFF              28  ; dd
%define W_TOPLEVEL_ID_OFF            32  ; dd
%define W_XDG_SURFACE_ID_OFF         36  ; dd
%define W_COMPOSITOR_ID_OFF          40  ; dd
%define W_SHM_ID_OFF                 44  ; dd
%define W_WM_BASE_ID_OFF             48  ; dd
%define W_SHM_POOL_ID_OFF            52  ; dd
%define W_SHM_FD_OFF                 56  ; dd
%define W_PAD0_OFF                   60  ; dd
%define W_SHM_PTR_OFF                64  ; dq
%define W_SHM_SIZE_OFF               72  ; dq
%define W_SHOULD_CLOSE_OFF           80  ; dq
%define W_NEXT_ID_OFF                88  ; dd
%define W_REGISTRY_ID_OFF            92  ; dd
%define W_CONFIGURED_OFF             96  ; dq
%define W_TITLE_PTR_OFF              104 ; dq
%define W_TITLE_LEN_OFF              112 ; dq
%define W_SEAT_ID_OFF                120 ; dd
%define W_KEYBOARD_ID_OFF            124 ; dd
%define W_POINTER_ID_OFF             128 ; dd
%define W_TOUCH_ID_OFF               132 ; dd
%define W_CURRENT_MODIFIERS_OFF      136 ; dd
%define W_STRUCT_SIZE                160

section .data
    memfd_name              db "aura-shm",0
    iface_name_compositor   db "wl_compositor",0
    iface_name_shm          db "wl_shm",0
    iface_name_xdg_wm_base  db "xdg_wm_base",0

section .bss
    wnd_event_buf           resb 8192

section .text
global window_create
global window_present
global window_get_canvas
global window_process_events
global window_should_close
global window_destroy

; rdi=Window*
; eax=next id
window_next_id:
    mov eax, [rdi + W_NEXT_ID_OFF]
    inc dword [rdi + W_NEXT_ID_OFF]
    ret

window_sleep_1ms:
    sub rsp, 16
    mov qword [rsp + 0], 0
    mov qword [rsp + 8], 1000000
    mov rax, 35                      ; nanosleep
    mov rdi, rsp
    xor rsi, rsi
    syscall
    add rsp, 16
    ret

; rdi=str_ptr, esi=str_len, rdx=lit_ptr, ecx=lit_len
; eax=1 if equal else 0
window_str_eq:
    cmp esi, ecx
    jne .no
    test esi, esi
    jle .yes
    xor eax, eax
.loop:
    cmp eax, esi
    jae .yes
    mov r8b, [rdi + rax]
    mov r9b, [rdx + rax]
    cmp r8b, r9b
    jne .no
    inc eax
    jmp .loop
.yes:
    mov eax, 1
    ret
.no:
    xor eax, eax
    ret

; Process one recv buffer: globals + runtime events.
; rdi=Window*, rsi=buf, rdx=bytes
window_handle_messages:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    xor r14d, r14d

.msg_loop:
    cmp r14, r13
    jae .done
    mov eax, dword [r12 + r14 + 4]
    mov r15d, eax
    shr r15d, 16                     ; size
    and eax, 0xFFFF                  ; opcode
    cmp r15d, 8
    jb .done
    cmp r15d, 8192
    ja .done
    mov rax, r14
    add rax, r15
    cmp rax, r13
    ja .done                         ; incomplete frame in current recv chunk
    mov ecx, dword [r12 + r14 + 0]   ; sender
    lea rdx, [r12 + r14 + 8]         ; payload

    ; wl_display.error
    cmp ecx, 1
    jne .check_registry
    cmp eax, 0
    jne .check_registry
    mov qword [rbx + W_SHOULD_CLOSE_OFF], 1
    jmp .done

.check_registry:

    ; wl_registry.global
    cmp ecx, [rbx + W_REGISTRY_ID_OFF]
    jne .check_ping
    cmp eax, 0
    jne .advance
    ; payload: name(u32), interface(string), version(u32)
    mov esi, dword [rdx + 4]         ; strlen incl NUL
    test esi, esi
    jle .advance
    dec esi                          ; compare without NUL

    ; wl_compositor
    lea rdi, [r12 + r14 + 16]
    lea rdx, [rel iface_name_compositor]
    mov ecx, 13
    call window_str_eq
    cmp eax, 1
    jne .check_shm
    cmp dword [rbx + W_COMPOSITOR_ID_OFF], 0
    jne .advance
    mov rdi, rbx
    call window_next_id
    mov [rbx + W_COMPOSITOR_ID_OFF], eax
    mov rdi, [rbx + W_SOCK_FD_OFF]
    mov esi, [rbx + W_REGISTRY_ID_OFF]
    mov edx, dword [r12 + r14 + 8]
    mov ecx, IFACE_COMPOSITOR
    mov r8d, 4
    mov r9d, [rbx + W_COMPOSITOR_ID_OFF]
    call wl_registry_bind
    jmp .advance

.check_shm:
    mov esi, dword [r12 + r14 + 12]
    dec esi
    lea rdi, [r12 + r14 + 16]
    lea rdx, [rel iface_name_shm]
    mov ecx, 6
    call window_str_eq
    cmp eax, 1
    jne .check_wm_base
    cmp dword [rbx + W_SHM_ID_OFF], 0
    jne .advance
    mov rdi, rbx
    call window_next_id
    mov [rbx + W_SHM_ID_OFF], eax
    mov rdi, [rbx + W_SOCK_FD_OFF]
    mov esi, [rbx + W_REGISTRY_ID_OFF]
    mov edx, dword [r12 + r14 + 8]
    mov ecx, IFACE_SHM
    mov r8d, 1
    mov r9d, [rbx + W_SHM_ID_OFF]
    call wl_registry_bind
    jmp .advance

.check_wm_base:
    mov esi, dword [r12 + r14 + 12]
    dec esi
    lea rdi, [r12 + r14 + 16]
    lea rdx, [rel iface_name_xdg_wm_base]
    mov ecx, 11
    call window_str_eq
    cmp eax, 1
    jne .check_input_globals
    cmp dword [rbx + W_WM_BASE_ID_OFF], 0
    jne .advance
    mov rdi, rbx
    call window_next_id
    mov [rbx + W_WM_BASE_ID_OFF], eax
    mov rdi, [rbx + W_SOCK_FD_OFF]
    mov esi, [rbx + W_REGISTRY_ID_OFF]
    mov edx, dword [r12 + r14 + 8]
    mov ecx, IFACE_XDG_WM_BASE
    mov r8d, 1
    mov r9d, [rbx + W_WM_BASE_ID_OFF]
    call wl_registry_bind
    jmp .advance

.check_input_globals:
    mov esi, dword [r12 + r14 + 8]       ; name
    lea rdx, [r12 + r14 + 16]            ; interface string
    mov ecx, dword [r12 + r14 + 12]      ; strlen incl NUL
    test ecx, ecx
    jle .advance
    mov r9d, ecx
    add r9d, 3
    and r9d, -4
    lea rax, [r12 + r14 + 16]
    add rax, r9
    mov r8d, dword [rax]                ; version
    dec ecx                              ; without NUL
    mov rdi, rbx
    call wayland_input_handle_registry_global
    jmp .advance

.check_ping:
    cmp ecx, [rbx + W_WM_BASE_ID_OFF]
    jne .check_xdg_surface
    cmp eax, 0
    jne .advance
    mov edx, dword [rdx + 0]         ; serial
    mov rdi, [rbx + W_SOCK_FD_OFF]
    mov esi, [rbx + W_WM_BASE_ID_OFF]
    call xdg_wm_base_pong
    jmp .advance

.check_xdg_surface:
    cmp ecx, [rbx + W_XDG_SURFACE_ID_OFF]
    jne .check_toplevel
    cmp eax, 0
    jne .advance
    mov edx, dword [rdx + 0]         ; serial
    mov rdi, [rbx + W_SOCK_FD_OFF]
    mov esi, [rbx + W_XDG_SURFACE_ID_OFF]
    call xdg_surface_ack_configure
    mov qword [rbx + W_CONFIGURED_OFF], 1
    ; commit after ack is mandatory
    mov rdi, [rbx + W_SOCK_FD_OFF]
    mov esi, [rbx + W_SURFACE_ID_OFF]
    call wl_surface_commit
    jmp .advance

.check_toplevel:
    cmp ecx, [rbx + W_TOPLEVEL_ID_OFF]
    jne .advance
    cmp eax, 1                        ; close
    jne .advance
    mov qword [rbx + W_SHOULD_CLOSE_OFF], 1

.advance:
    mov esi, dword [r12 + r14 + 0]       ; sender id
    mov edx, dword [r12 + r14 + 4]
    and edx, 0xFFFF                      ; opcode
    lea rcx, [r12 + r14 + 8]             ; payload
    mov r8d, r15d                        ; message size
    mov rdi, rbx
    call wayland_input_handle_message
    add r14, r15
    jmp .msg_loop

.done:
    mov rax, r14
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; window_create(width, height, title_ptr)
window_create:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi                     ; width
    mov r13, rsi                     ; height
    mov r14, rdx                     ; title ptr

    test r12, r12
    jz .fail
    test r13, r13
    jz .fail
    test r14, r14
    jz .fail

    ; title length
    xor r15d, r15d
.title_len:
    cmp byte [r14 + r15], 0
    je .title_len_done
    inc r15d
    jmp .title_len
.title_len_done:

    ; allocate window struct
    xor rdi, rdi
    mov rsi, PAGE_SIZE
    mov rdx, PROT_READ | PROT_WRITE
    mov rcx, MAP_PRIVATE | MAP_ANONYMOUS
    mov r8, -1
    xor r9, r9
    call hal_mmap
    test rax, rax
    js .fail
    mov rbx, rax

    mov [rbx + W_WIDTH_OFF], r12d
    mov [rbx + W_HEIGHT_OFF], r13d
    mov [rbx + W_TITLE_PTR_OFF], r14
    mov [rbx + W_TITLE_LEN_OFF], r15
    mov qword [rbx + W_SOCK_FD_OFF], -1
    mov qword [rbx + W_SHOULD_CLOSE_OFF], 0
    mov qword [rbx + W_CONFIGURED_OFF], 0
    mov dword [rbx + W_NEXT_ID_OFF], 2
    mov dword [rbx + W_SHM_FD_OFF], -1
    mov dword [rbx + W_PAD0_OFF], 0      ; recv pending bytes
    mov dword [rbx + W_SEAT_ID_OFF], 0
    mov dword [rbx + W_KEYBOARD_ID_OFF], 0
    mov dword [rbx + W_POINTER_ID_OFF], 0
    mov dword [rbx + W_TOUCH_ID_OFF], 0
    mov dword [rbx + W_CURRENT_MODIFIERS_OFF], 0

    mov rdi, rbx
    call wayland_input_init

    ; connect
    call wl_connect
    test rax, rax
    js .dbg_f1
    mov [rbx + W_SOCK_FD_OFF], rax

    ; get registry
    mov rdi, rbx
    call window_next_id
    mov [rbx + W_REGISTRY_ID_OFF], eax
    mov rdi, [rbx + W_SOCK_FD_OFF]
    mov esi, [rbx + W_REGISTRY_ID_OFF]
    call wl_display_get_registry
    cmp rax, 12
    jne .dbg_f7

    ; roundtrip kick: wl_display.sync
    mov rdi, rbx
    call window_next_id
    mov rdi, [rbx + W_SOCK_FD_OFF]
    mov esi, eax
    call wl_display_sync

    ; collect globals
    mov r12d, 5000
.globals_loop:
    cmp dword [rbx + W_COMPOSITOR_ID_OFF], 0
    je .need_more_globals
    cmp dword [rbx + W_SHM_ID_OFF], 0
    je .need_more_globals
    cmp dword [rbx + W_WM_BASE_ID_OFF], 0
    je .need_more_globals
    jmp .globals_done
.need_more_globals:
    dec r12d
    jz .dbg_f2
    mov ecx, [rbx + W_PAD0_OFF]
    cmp ecx, 8192
    jae .dbg_f2
    mov rdi, [rbx + W_SOCK_FD_OFF]
    lea rsi, [rel wnd_event_buf]
    add rsi, rcx
    mov edx, 8192
    sub edx, ecx
    call wl_recv_nowait
    cmp rax, 0
    je .dbg_f9
    cmp rax, -11
    je .globals_yield
    js .dbg_f8
    add [rbx + W_PAD0_OFF], eax
    mov edx, [rbx + W_PAD0_OFF]
    test edx, edx
    jle .globals_yield
    mov rdi, rbx
    lea rsi, [rel wnd_event_buf]
    mov rdx, rdx
    call window_handle_messages
    mov ecx, [rbx + W_PAD0_OFF]
    sub ecx, eax
    jle .globals_no_rem
    lea rsi, [rel wnd_event_buf]
    lea rdi, [rel wnd_event_buf]
    add rsi, rax
    mov edx, ecx
    rep movsb
.globals_no_rem:
    mov [rbx + W_PAD0_OFF], ecx
    jmp .globals_loop
.globals_yield:
    call window_sleep_1ms
    jmp .globals_loop
.globals_done:

    ; create wl_surface
    mov rdi, rbx
    call window_next_id
    mov [rbx + W_SURFACE_ID_OFF], eax
    mov rdi, [rbx + W_SOCK_FD_OFF]
    mov esi, [rbx + W_COMPOSITOR_ID_OFF]
    mov edx, [rbx + W_SURFACE_ID_OFF]
    call wl_compositor_create_surface

    ; xdg_surface / xdg_toplevel
    mov rdi, rbx
    call window_next_id
    mov [rbx + W_XDG_SURFACE_ID_OFF], eax
    mov rdi, rbx
    call window_next_id
    mov [rbx + W_TOPLEVEL_ID_OFF], eax

    mov rdi, [rbx + W_SOCK_FD_OFF]
    mov esi, [rbx + W_WM_BASE_ID_OFF]
    mov edx, [rbx + W_XDG_SURFACE_ID_OFF]
    mov ecx, [rbx + W_SURFACE_ID_OFF]
    call xdg_wm_base_get_xdg_surface

    mov rdi, [rbx + W_SOCK_FD_OFF]
    mov esi, [rbx + W_XDG_SURFACE_ID_OFF]
    mov edx, [rbx + W_TOPLEVEL_ID_OFF]
    call xdg_surface_get_toplevel

    mov rdi, [rbx + W_SOCK_FD_OFF]
    mov esi, [rbx + W_TOPLEVEL_ID_OFF]
    mov rdx, [rbx + W_TITLE_PTR_OFF]
    mov ecx, [rbx + W_TITLE_LEN_OFF]
    call xdg_toplevel_set_title

    ; initial commit to receive configure
    mov rdi, [rbx + W_SOCK_FD_OFF]
    mov esi, [rbx + W_SURFACE_ID_OFF]
    call wl_surface_commit

    ; wait for configure
    mov r12d, 5000
.cfg_loop:
    cmp qword [rbx + W_CONFIGURED_OFF], 1
    je .cfg_done
    dec r12d
    jz .dbg_f3
    mov ecx, [rbx + W_PAD0_OFF]
    cmp ecx, 8192
    jae .dbg_f3
    mov rdi, [rbx + W_SOCK_FD_OFF]
    lea rsi, [rel wnd_event_buf]
    add rsi, rcx
    mov edx, 8192
    sub edx, ecx
    call wl_recv_nowait
    cmp rax, 0
    jle .cfg_yield
    add [rbx + W_PAD0_OFF], eax
    mov edx, [rbx + W_PAD0_OFF]
    test edx, edx
    jle .cfg_yield
    mov rdi, rbx
    lea rsi, [rel wnd_event_buf]
    mov rdx, rdx
    call window_handle_messages
    mov ecx, [rbx + W_PAD0_OFF]
    sub ecx, eax
    jle .cfg_no_rem
    lea rsi, [rel wnd_event_buf]
    lea rdi, [rel wnd_event_buf]
    add rsi, rax
    mov edx, ecx
    rep movsb
.cfg_no_rem:
    mov [rbx + W_PAD0_OFF], ecx
    jmp .cfg_loop
.cfg_yield:
    call window_sleep_1ms
    jmp .cfg_loop
.cfg_done:

    ; shm size = align(width*height*4, PAGE_SIZE)
    mov eax, [rbx + W_WIDTH_OFF]
    imul eax, [rbx + W_HEIGHT_OFF]
    shl eax, 2
    mov edx, eax
    add rdx, PAGE_SIZE - 1
    and rdx, -PAGE_SIZE
    mov [rbx + W_SHM_SIZE_OFF], rdx

    ; memfd_create
    mov rax, SYS_MEMFD_CREATE
    lea rdi, [rel memfd_name]
    xor rsi, rsi
    syscall
    test rax, rax
    js .dbg_f4
    mov dword [rbx + W_SHM_FD_OFF], eax

    ; ftruncate(fd, shm_size)
    mov rax, SYS_FTRUNCATE
    mov edi, [rbx + W_SHM_FD_OFF]
    mov rsi, [rbx + W_SHM_SIZE_OFF]
    syscall
    test rax, rax
    js .dbg_f5

    ; mmap shared memory
    mov rax, SYS_MMAP
    xor rdi, rdi
    mov rsi, [rbx + W_SHM_SIZE_OFF]
    mov rdx, PROT_READ | PROT_WRITE
    mov r10, MAP_SHARED
    mov r8d, [rbx + W_SHM_FD_OFF]
    xor r9, r9
    syscall
    test rax, rax
    js .dbg_f6
    mov [rbx + W_SHM_PTR_OFF], rax

    ; wl_shm pool + buffer
    mov rdi, rbx
    call window_next_id
    mov [rbx + W_SHM_POOL_ID_OFF], eax
    mov rdi, rbx
    call window_next_id
    mov [rbx + W_BUFFER_ID_OFF], eax

    mov rdi, [rbx + W_SOCK_FD_OFF]
    mov esi, [rbx + W_SHM_ID_OFF]
    mov edx, [rbx + W_SHM_POOL_ID_OFF]
    mov ecx, [rbx + W_SHM_FD_OFF]
    mov r8d, [rbx + W_SHM_SIZE_OFF]
    call wl_shm_create_pool

    mov rdi, [rbx + W_SOCK_FD_OFF]
    mov esi, [rbx + W_SHM_POOL_ID_OFF]
    mov edx, [rbx + W_BUFFER_ID_OFF]
    xor ecx, ecx
    mov r8d, [rbx + W_WIDTH_OFF]
    mov r9d, [rbx + W_HEIGHT_OFF]
    sub rsp, 16
    mov eax, [rbx + W_WIDTH_OFF]
    shl eax, 2
    mov dword [rsp + 0], eax
    mov dword [rsp + 8], WL_SHM_FORMAT_ARGB8888
    call wl_shm_pool_create_buffer
    add rsp, 16

    ; local canvas backing
    mov edi, [rbx + W_WIDTH_OFF]
    mov esi, [rbx + W_HEIGHT_OFF]
    call canvas_init
    test rax, rax
    jz .destroy_all
    mov [rbx + W_CANVAS_PTR_OFF], rax

    ; first present
    mov rdi, rbx
    call window_present

    mov rax, rbx
    jmp .ret

.fallback_canvas:
    mov rdi, [rbx + W_CANVAS_PTR_OFF]
    test rdi, rdi
    jnz .ret_ok
    mov edi, [rbx + W_WIDTH_OFF]
    mov esi, [rbx + W_HEIGHT_OFF]
    call canvas_init
    test rax, rax
    jz .destroy_all
    mov [rbx + W_CANVAS_PTR_OFF], rax
.ret_ok:
    mov rax, rbx
    jmp .ret

.dbg_f1:
%ifdef STRICT_WAYLAND
    jmp .destroy_struct
%else
    jmp .fallback_canvas
%endif
.dbg_f2:
%ifdef STRICT_WAYLAND
    jmp .destroy_all
%else
    jmp .fallback_canvas
%endif
.dbg_f3:
%ifdef STRICT_WAYLAND
    jmp .destroy_all
%else
    jmp .fallback_canvas
%endif
.dbg_f4:
%ifdef STRICT_WAYLAND
    jmp .destroy_all
%else
    jmp .fallback_canvas
%endif
.dbg_f5:
%ifdef STRICT_WAYLAND
    jmp .destroy_all
%else
    jmp .fallback_canvas
%endif
.dbg_f6:
%ifdef STRICT_WAYLAND
    jmp .destroy_all
%else
    jmp .fallback_canvas
%endif
.dbg_f7:
%ifdef STRICT_WAYLAND
    jmp .destroy_all
%else
    jmp .fallback_canvas
%endif
.dbg_f8:
%ifdef STRICT_WAYLAND
    jmp .destroy_all
%else
    jmp .fallback_canvas
%endif
.dbg_f9:
%ifdef STRICT_WAYLAND
    jmp .destroy_all
%else
    jmp .fallback_canvas
%endif

.destroy_all:
    mov rdi, rbx
    call window_destroy
.destroy_struct:
    mov rdi, rbx
    mov rsi, PAGE_SIZE
    call hal_munmap
.fail:
    xor eax, eax
.ret:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; window_present(window_ptr)
window_present:
    push rbx
    push r12
    push r13
    push r14
    push r15

    test rdi, rdi
    jz .soft_ok
    mov rbx, rdi
    mov r12, [rbx + W_CANVAS_PTR_OFF]
    mov r13, [rbx + W_SHM_PTR_OFF]
    test r12, r12
    jz .soft_ok
    test r13, r13
    jz .soft_ok

    ; copy canvas buffer -> shm
    mov rsi, [r12 + CANVAS_BUF_OFF]
    mov rdx, [r12 + CANVAS_SIZE_OFF]
    mov rcx, rdx
    shr rcx, 3
.copy_qword:
    test rcx, rcx
    jz .copy_tail
    mov rax, [rsi]
    mov [r13], rax
    add rsi, 8
    add r13, 8
    dec rcx
    jmp .copy_qword
.copy_tail:
    and rdx, 7
    jz .send_commit
.copy_byte:
    mov al, [rsi]
    mov [r13], al
    inc rsi
    inc r13
    dec rdx
    jnz .copy_byte

.send_commit:
    mov rdi, [rbx + W_SOCK_FD_OFF]
    mov esi, [rbx + W_SURFACE_ID_OFF]
    mov edx, [rbx + W_BUFFER_ID_OFF]
    xor ecx, ecx
    xor r8d, r8d
    call wl_surface_attach

    mov rdi, [rbx + W_SOCK_FD_OFF]
    mov esi, [rbx + W_SURFACE_ID_OFF]
    xor edx, edx
    xor ecx, ecx
    mov r8d, [rbx + W_WIDTH_OFF]
    mov r9d, [rbx + W_HEIGHT_OFF]
    call wl_surface_damage

    mov rdi, [rbx + W_SOCK_FD_OFF]
    mov esi, [rbx + W_SURFACE_ID_OFF]
    call wl_surface_commit

    xor eax, eax
    jmp .done
.soft_ok:
    xor eax, eax
.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

window_get_canvas:
    test rdi, rdi
    jz .none
    mov rax, [rdi + W_CANVAS_PTR_OFF]
    ret
.none:
    xor eax, eax
    ret

window_process_events:
    push rbx
    test rdi, rdi
    jz .done
    mov rbx, rdi
    mov ecx, [rbx + W_PAD0_OFF]
    cmp ecx, 8192
    jae .done
    mov rdi, [rbx + W_SOCK_FD_OFF]
    lea rsi, [rel wnd_event_buf]
    add rsi, rcx
    mov rdx, 8192
    sub rdx, rcx
    call wl_recv_nowait
    cmp rax, 0
    jle .process_pending
    add [rbx + W_PAD0_OFF], eax
.process_pending:
    mov rdi, rbx
    lea rsi, [rel wnd_event_buf]
    mov edx, [rbx + W_PAD0_OFF]
    test edx, edx
    jle .done
    call window_handle_messages
    mov ecx, [rbx + W_PAD0_OFF]
    sub ecx, eax
    jle .no_remain
    lea rsi, [rel wnd_event_buf]
    lea rdi, [rel wnd_event_buf]
    add rsi, rax
    mov edx, ecx
    rep movsb
.no_remain:
    mov [rbx + W_PAD0_OFF], ecx
.done:
    xor eax, eax
    pop rbx
    ret

window_should_close:
    test rdi, rdi
    jz .zero
    mov rax, [rdi + W_SHOULD_CLOSE_OFF]
    ret
.zero:
    xor eax, eax
    ret

window_destroy:
    push rbx
    test rdi, rdi
    jz .done
    mov rbx, rdi

    mov rdi, [rbx + W_CANVAS_PTR_OFF]
    test rdi, rdi
    jz .skip_canvas
    call canvas_destroy
.skip_canvas:
    mov rdi, [rbx + W_SHM_PTR_OFF]
    test rdi, rdi
    jz .skip_shm
    mov rsi, [rbx + W_SHM_SIZE_OFF]
    call hal_munmap
.skip_shm:
    mov edi, [rbx + W_SHM_FD_OFF]
    cmp edi, 0
    jl .skip_fd
    call hal_close
.skip_fd:
    mov rdi, [rbx + W_SOCK_FD_OFF]
    test rdi, rdi
    js .done
    call wl_disconnect
.done:
    xor eax, eax
    pop rbx
    ret
