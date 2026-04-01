; main_win.asm - Native Win32 Aura Shell + FM loop
%include "src/hal/win_x86_64/defs.inc"
%include "src/gui/theme.inc"

extern bootstrap_init
extern hal_write
extern hal_exit
extern hal_sleep_ms
extern arena_init
extern arena_destroy
extern input_queue_init
extern input_poll_event
extern widget_system_init
extern widget_system_shutdown
extern window_create_win32
extern window_process_events
extern window_should_close
extern window_destroy
extern window_get_canvas
extern window_present_win32
extern canvas_fill_rect
extern repl_set_arena
extern repl_init
extern repl_set_font
extern repl_set_colors
extern repl_handle_key
extern repl_draw
extern repl_cursor_blink
extern fm_init
extern fm_render
extern fm_handle_input
extern vfs_path_len
extern win32_GetCurrentDirectoryA
extern win32_GetModuleFileNameA

section .data
    app_title          db "Aura Shell (Win32 Native)",0
    theme_name         db "tokyo-night",0
    theme_name_len     equ 11
    measure_ch         db "M",0
    fm_path_root       db "/",0
    msg_fail           db "aura-shell-win: init failed",13,10
    msg_fail_len       equ $ - msg_fail
    mode_shell         dd 0
    mode_fm            dd 1
    vk_f6              dd 0x75
    vk_tab             dd 0x09
    vk_right           dd 0x27
    win_safe_mode      dd 0

section .bss
    arena_ptr          resq 1
    wnd_ptr            resq 1
    theme_ptr          resq 1
    theme_local        resb THEME_STRUCT_SIZE
    repl_ptr           resq 1
    fm_ptr             resq 1
    event_buf          resb 64
    mode_state         resd 1
    fm_start_path      resb 1024
    frame_poll_budget  resd 1
    frame_counter      resd 1

section .text
global _start

%define INPUT_EVENT_TYPE_OFF            0
%define INPUT_EVENT_KEY_CODE_OFF        16
%define INPUT_EVENT_KEY_STATE_OFF       20
%define INPUT_KEY                       1
%define KEY_PRESSED                     1

fail:
    mov rdi, 1
    lea rsi, [rel msg_fail]
    mov rdx, msg_fail_len
    call hal_write
    mov edi, 1
    call hal_exit

_start:
    and rsp, -16
    call bootstrap_init
    cmp eax, 1
    jne fail

    mov rdi, 16777216
    call arena_init
    test rax, rax
    jz fail
    mov [rel arena_ptr], rax
    mov rdi, rax
    call repl_set_arena

    call input_queue_init
    call widget_system_init
    test eax, eax
    jne .cleanup_fail

    mov rdi, 1280
    mov rsi, 800
    lea rdx, [rel app_title]
    call window_create_win32
    test rax, rax
    jz .cleanup_fail
    mov [rel wnd_ptr], rax

    ; build minimal in-memory theme for Win native path
    lea rdi, [rel theme_local]
    mov ecx, THEME_STRUCT_SIZE/4
    xor eax, eax
    rep stosd
    lea rax, [rel theme_local]
    mov [rel theme_ptr], rax
    mov dword [rax + T_BG_OFF], 0xFF1A1B26
    mov dword [rax + T_FG_OFF], 0xFFC0CAF5
    mov dword [rax + T_ACCENT_OFF], 0xFF7AA2F7
    mov dword [rax + T_SURFACE_OFF], 0xFF24283B
    mov dword [rax + T_BORDER_COLOR_OFF], 0xFF414868
    mov dword [rax + T_FONT_MAIN_SIZE_OFF], 16
    mov dword [rax + T_FONT_UI_SIZE_OFF], 16
    mov dword [rax + T_LOADED_OFF], 1

    ; restore REPL init path (kept in FM mode rendering for now)
    mov r8d, 8
    mov r9d, 16
    mov rdi, [rel wnd_ptr]
    mov esi, r8d
    mov edx, r9d
    call repl_init
    mov [rel repl_ptr], rax
    test rax, rax
    jz .repl_skip

    mov r10, [rel theme_ptr]
    mov rdi, [rel repl_ptr]
    mov rsi, [r10 + T_FONT_MAIN_OFF]
    mov edx, [r10 + T_FONT_MAIN_SIZE_OFF]
    call repl_set_font

    mov r10, [rel theme_ptr]
    mov rdi, [rel repl_ptr]
    mov esi, [r10 + T_BG_OFF]
    mov edx, [r10 + T_FG_OFF]
    mov ecx, [r10 + T_ACCENT_OFF]
    mov r8d, [r10 + T_ACCENT_OFF]
    call repl_set_colors
.repl_skip:
    mov r10, [rel theme_ptr]
    test r10, r10
    jz .cleanup_fail
    ; ensure REPL colors are always initialized from a fresh theme_ptr load
    ; (r10 is volatile across calls on Win64 ABI).
    mov rdi, [rel repl_ptr]
    test rdi, rdi
    jz .after_repl_colors
    mov esi, [r10 + T_BG_OFF]
    mov edx, [r10 + T_FG_OFF]
    mov ecx, [r10 + T_ACCENT_OFF]
    mov r8d, [r10 + T_ACCENT_OFF]
    call repl_set_colors
.after_repl_colors:
    cmp dword [rel win_safe_mode], 1
    je .fm_skip_init
    ; Start FM from current working directory for faster/stabler startup.
    mov rax, [rel win32_GetCurrentDirectoryA]
    test rax, rax
    jz .fm_root_default
    mov ecx, 1024
    lea rdx, [rel fm_start_path]
    sub rsp, 32
    call rax
    add rsp, 32
    test eax, eax
    jz .fm_root_default
    cmp eax, 1024
    jae .fm_root_default
    ; normalize backslashes to forward slashes in-place
    xor ecx, ecx
.fm_norm_loop:
    cmp ecx, eax
    jae .fm_norm_done
    cmp byte [rel fm_start_path + rcx], 92
    jne .fm_norm_next
    mov byte [rel fm_start_path + rcx], '/'
.fm_norm_next:
    inc ecx
    jmp .fm_norm_loop
.fm_norm_done:
    mov byte [rel fm_start_path + rax], 0
    lea rdi, [rel fm_start_path]
    jmp .fm_init_call
.fm_root_default:
    mov byte [rel fm_start_path + 0], 'C'
    mov byte [rel fm_start_path + 1], ':'
    mov byte [rel fm_start_path + 2], '/'
    mov byte [rel fm_start_path + 3], 0
    lea rdi, [rel fm_start_path]
.fm_init_call:
    mov esi, 1                           ; FM_DUAL_PANEL
    call fm_init
    test rax, rax
    jz .cleanup_fail
    mov [rel fm_ptr], rax
    jmp .fm_init_done
.fm_skip_init:
    xor rax, rax
    mov [rel fm_ptr], rax
.fm_init_done:

    mov dword [rel mode_state], 1

.ultra_loop:
    ; Ultra-safe runtime loop for isolating base Win32 hangs.
    ; No FM, no REPL, no input queue processing.
    cmp dword [rel win_safe_mode], 0
    je .loop
    mov rdi, [rel wnd_ptr]
    call window_process_events
    cmp eax, 0
    jl .cleanup_fail
    mov rdi, [rel wnd_ptr]
    call window_should_close
    cmp eax, 1
    je .cleanup_ok
    mov rdi, [rel wnd_ptr]
    call window_get_canvas
    test rax, rax
    jz .cleanup_fail
    mov rbx, rax
    cmp dword [rel win_safe_mode], 3
    jne .ultra_heartbeat
    ; Stage 3: FM render only, without input queue dispatch.
    mov rdi, [rel fm_ptr]
    test rdi, rdi
    jz .ultra_heartbeat
    mov rsi, rbx
    mov rdx, [rel theme_ptr]
    call fm_render
    jmp .ultra_present
.ultra_heartbeat:
    inc dword [rel frame_counter]
    mov eax, [rel frame_counter]
    and eax, 1
    test eax, eax
    jz .ultra_bg_a
    mov r9d, 0xFF24304A
    jmp .ultra_bg_draw
.ultra_bg_a:
    mov r9d, 0xFF1A1E30
.ultra_bg_draw:
    mov rdi, rbx
    xor esi, esi
    xor edx, edx
    mov ecx, 1280
    mov r8d, 800
    call canvas_fill_rect
.ultra_present:
    mov rdi, [rel wnd_ptr]
    call window_present_win32
    mov edi, 16
    call hal_sleep_ms
    jmp .ultra_loop

.loop:
    ; Anti-hang guard: do not let input polling starve rendering forever.
    mov dword [rel frame_poll_budget], 1024
    mov rdi, [rel wnd_ptr]
    call window_process_events
    cmp eax, 0
    jl .cleanup_fail

.poll:
    cmp dword [rel frame_poll_budget], 0
    jle .render
    lea rdi, [rel event_buf]
    call input_poll_event
    test eax, eax
    jz .render
    dec dword [rel frame_poll_budget]

    cmp dword [rel event_buf + INPUT_EVENT_TYPE_OFF], INPUT_KEY
    jne .dispatch
    cmp dword [rel event_buf + INPUT_EVENT_KEY_STATE_OFF], KEY_PRESSED
    jne .dispatch
    mov eax, [rel vk_f6]
    cmp dword [rel event_buf + INPUT_EVENT_KEY_CODE_OFF], eax
    jne .dispatch
    ; Win native stabilization: temporarily disable runtime mode switch
    ; until REPL path is fully crash-safe on this backend.
    mov dword [rel mode_state], 1
    jmp .poll

.dispatch:
    cmp dword [rel event_buf + INPUT_EVENT_TYPE_OFF], INPUT_KEY
    jne .dispatch_mode
    cmp dword [rel event_buf + INPUT_EVENT_KEY_STATE_OFF], KEY_PRESSED
    jne .poll

.dispatch_mode:
    cmp dword [rel mode_state], 0
    jne .dispatch_fm
    mov rdi, [rel repl_ptr]
    test rdi, rdi
    jz .poll
    lea rsi, [rel event_buf]
    call repl_handle_key
    jmp .poll

.dispatch_fm:
    cmp dword [rel win_safe_mode], 0
    jne .poll
    ; Hard fallback: if Tab reaches main loop but is not handled in FM
    ; path on this Win build, route it through the already working Right.
    cmp dword [rel event_buf + INPUT_EVENT_TYPE_OFF], INPUT_KEY
    jne .dispatch_fm_call
    cmp dword [rel event_buf + INPUT_EVENT_KEY_STATE_OFF], KEY_PRESSED
    jne .dispatch_fm_call
    mov eax, [rel vk_tab]
    cmp dword [rel event_buf + INPUT_EVENT_KEY_CODE_OFF], eax
    jne .dispatch_fm_call
    mov eax, [rel vk_right]
    mov dword [rel event_buf + INPUT_EVENT_KEY_CODE_OFF], eax
.dispatch_fm_call:
    mov rdi, [rel fm_ptr]
    lea rsi, [rel event_buf]
    call fm_handle_input
    jmp .poll

.render:
    mov rdi, [rel wnd_ptr]
    call window_get_canvas
    test rax, rax
    jz .cleanup_fail
    mov rbx, rax
    cmp dword [rel mode_state], 0
    jne .render_fm
    mov rdi, [rel repl_ptr]
    test rdi, rdi
    jz .render_fm
    mov rsi, rbx
    xor ecx, ecx
    xor r8d, r8d
    call repl_draw
    xor rdi, rdi
    xor rsi, rsi
    mov rdx, [rel repl_ptr]
    call repl_cursor_blink
    jmp .present

.render_fm:
    cmp dword [rel win_safe_mode], 0
    jne .render_safe
    mov rdi, [rel fm_ptr]
    mov rsi, rbx
    mov rdx, [rel theme_ptr]
    call fm_render
    jmp .present

.render_safe:
    ; Emergency safe frame: keep window responsive while isolating FM hangs.
    inc dword [rel frame_counter]
    mov eax, [rel frame_counter]
    and eax, 1
    test eax, eax
    jz .safe_bg_a
    mov r9d, 0xFF20243A
    jmp .safe_bg_draw
.safe_bg_a:
    mov r9d, 0xFF1A1E30
.safe_bg_draw:
    mov rdi, rbx
    xor esi, esi
    xor edx, edx
    mov ecx, 1280
    mov r8d, 800
    call canvas_fill_rect
    ; moving heartbeat block
    mov eax, [rel frame_counter]
    xor edx, edx
    mov ecx, 1200
    div ecx
    mov esi, edx
    add esi, 20
    mov rdi, rbx
    mov edx, 760
    mov ecx, 56
    mov r8d, 20
    mov r9d, 0xFF7AA2F7
    call canvas_fill_rect

.present:
    mov rdi, [rel wnd_ptr]
    call window_present_win32

    mov rdi, [rel wnd_ptr]
    call window_should_close
    cmp eax, 1
    je .cleanup_ok

    mov edi, 16
    call hal_sleep_ms
    jmp .loop

.cleanup_ok:
    mov rdi, [rel wnd_ptr]
    test rdi, rdi
    jz .skip_wnd
    call window_destroy
.skip_wnd:
    call widget_system_shutdown
    mov rdi, [rel arena_ptr]
    test rdi, rdi
    jz .exit0
    call arena_destroy
.exit0:
    xor edi, edi
    call hal_exit

.cleanup_fail:
    mov rdi, [rel wnd_ptr]
    test rdi, rdi
    jz .skip_wnd_f
    call window_destroy
.skip_wnd_f:
    call widget_system_shutdown
    mov rdi, [rel arena_ptr]
    test rdi, rdi
    jz fail
    call arena_destroy
    jmp fail
