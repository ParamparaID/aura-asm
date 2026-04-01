; main.asm — Aura Shell: widgets + TrueType theme + REPL terminal
%include "src/hal/platform_defs.inc"
%include "src/gui/widget.inc"
%include "src/gui/theme.inc"
%include "src/core/gesture.inc"
%include "src/compositor/workspaces.inc"
%include "src/canvas/canvas.inc"

extern hal_write
extern hal_exit
extern hal_clock_gettime
extern hal_access
extern hal_open
extern hal_close
extern hal_getdents64
extern global_envp
extern arena_init
extern arena_destroy
extern input_queue_init
extern input_poll_event
extern window_create
extern window_process_events
extern window_should_close
extern window_destroy
extern window_get_canvas
extern window_present
extern repl_set_arena
extern repl_init
extern repl_handle_key
extern repl_set_font
extern repl_set_colors
extern repl_cursor_blink
extern theme_load
extern theme_load_builtin
extern theme_destroy
extern font_measure_string
extern gesture_init
extern gesture_process_event
extern gesture_get_data
extern gesture_reset
extern anim_scheduler_init
extern anim_scheduler_tick
extern widget_system_init
extern widget_system_shutdown
extern widget_init
extern widget_add_child
extern widget_render
extern widget_handle_input
extern widget_focus
extern widget_set_dirty
extern terminal_widget_init
extern jobs_update_status
extern workspaces_init
extern workspaces_switch_relative
extern workspaces_get_manager
extern hub_init
extern hub_get_global
extern hub_render
extern hub_handle_input
extern hub_toggle
extern overview_enter
extern overview_render
extern overview_handle_input
extern overview_exit
extern cursor_init
extern cursor_get_global
extern cursor_update_pos
extern cursor_render
extern fm_init
extern fm_render
extern fm_handle_input
extern fm_open_path
extern builtin_fm_take_request
extern hub_take_fm_request
extern wm_take_fm_toggle_request
extern plugin_api_set_theme_ptr
extern plugin_api_set_canvas_ptr
extern plugin_api_get_host_table
extern plugin_api_set_current_plugin
extern plugin_registry_add
extern plugin_load
extern plugin_activate
extern plugin_unload

%define KEY_PRESSED                     1
%define BLINK_INTERVAL_NS               500000000
%define EDGE_GESTURE_PX_DEFAULT         56
%define BOTTOM_EDGE_PX_DEFAULT          72
%define MAIN_VIEW_W_DEFAULT             1024
%define MAIN_VIEW_H_DEFAULT             768
%define INPUT_EVENT_TYPE_OFF            0
%define INPUT_MOUSE_MOVE                2
%define INPUT_EVENT_MOUSE_X_OFF         28
%define INPUT_EVENT_MOUSE_Y_OFF         32

section .rodata
    env_wl_display      db "WAYLAND_DISPLAY", 0
    env_wl_display_len  equ $ - env_wl_display - 1
    env_theme_file      db "AURA_THEME_FILE", 0
    env_theme_file_len  equ $ - env_theme_file - 1
    path_dri_card0      db "/dev/dri/card0", 0
    app_title           db "Aura Shell", 0
    theme_name          db "tokyo-night", 0
    theme_name_len      equ 11
    measure_ch          db "M", 0
    fm_cmd_name         db "fm", 0
    fm_default_path     db "/", 0
    plugins_root_path   db "/tmp/aura/plugins", 0
    plugin_so_tail      db "/plugin.so",0
    init_fail_msg       db "aura-shell: init failed", 10
    init_fail_len       equ $ - init_fail_msg

section .bss
    global aura_run_mode
aura_run_mode       resb 1
    main_arena_ptr      resq 1
    main_window_ptr     resq 1
    main_repl_ptr       resq 1
    main_theme_ptr      resq 1
    root_widget         resq 1
    term_widget         resq 1
    event_tmp           resb 64
    ts_now              resq 2
    ts_last_blink       resq 2
    gesture_rec         resb GR_STRUCT_SIZE
    gesture_data        resb 64
    anim_sched          resb 1200
    ws_mgr_ptr          resq 1
    hub_ptr             resq 1
    cursor_ptr          resq 1
    theme_file_ptr      resq 1
    theme_file_len      resd 1
    fm_ptr              resq 1
    fm_visible          resd 1
    startup_argc        resq 1
    startup_argv        resq 1
    fm_req_buf          resb 1024
    plugins_dir_buf     resb 8192
    plugin_path_buf     resb 1024

section .text
global _start

; aura_pick_run_mode() — 1=nested (WAYLAND_DISPLAY), 2=standalone DRM path exists, 3=headless
aura_pick_run_mode:
    push rbx
    push r12
    push r13
    mov byte [rel aura_run_mode], 3
    mov r12, [rel global_envp]
    test r12, r12
    jz .try_dri
    xor r13d, r13d
.env_outer:
    mov rbx, [r12 + r13*8]
    test rbx, rbx
    jz .try_dri
    xor ecx, ecx
.env_cmp:
    cmp ecx, env_wl_display_len
    jae .env_match
    mov al, [rbx + rcx]
    mov dl, [rel env_wl_display + rcx]
    cmp al, dl
    jne .env_next
    inc ecx
    jmp .env_cmp
.env_match:
    cmp byte [rbx + env_wl_display_len], '='
    jne .env_next
    mov byte [rel aura_run_mode], 1
    pop r13
    pop r12
    pop rbx
    ret
.env_next:
    inc r13d
    jmp .env_outer
.try_dri:
    lea rdi, [rel path_dri_card0]
    mov esi, F_OK
    call hal_access
    test eax, eax
    jnz .done
    sub rsp, 16
    mov rax, SYS_IOCTL
    mov rdi, STDIN
    mov rsi, TIOCGPGRP
    lea rdx, [rsp + 8]
    syscall
    add rsp, 16
    test rax, rax
    js .done
    mov byte [rel aura_run_mode], 2
.done:
    pop r13
    pop r12
    pop rbx
    ret

main_sleep_1ms:
    sub rsp, 16
    mov qword [rsp + 0], 0
    mov qword [rsp + 8], 1000000
    mov rax, 35
    mov rdi, rsp
    xor rsi, rsi
    syscall
    add rsp, 16
    ret

timespec_to_ns:
    mov rax, [rdi]
    imul rax, 1000000000
    add rax, [rdi + 8]
    ret

; cstr_len(rdi=c-string) -> eax len
cstr_len:
    xor eax, eax
.cl:
    cmp byte [rdi + rax], 0
    je .out
    inc eax
    jmp .cl
.out:
    ret

; aura_find_env_value(name_ptr, name_len) -> rax value_ptr or 0
aura_find_env_value:
    push rbx
    push r12
    push r13
    mov r12, rdi
    mov r13d, esi
    mov rbx, [rel global_envp]
    test rbx, rbx
    jz .none
    xor ecx, ecx
.env_loop:
    mov rax, [rbx + rcx*8]
    test rax, rax
    jz .none
    xor edx, edx
.cmp_loop:
    cmp edx, r13d
    jae .check_eq
    mov r8b, [rax + rdx]
    mov r9b, [r12 + rdx]
    cmp r8b, r9b
    jne .next
    inc edx
    jmp .cmp_loop
.check_eq:
    cmp byte [rax + r13], '='
    jne .next
    lea rax, [rax + r13 + 1]
    jmp .out
.next:
    inc ecx
    jmp .env_loop
.none:
    xor eax, eax
.out:
    pop r13
    pop r12
    pop rbx
    ret

; main_apply_theme(theme*) -> eax 1/0
main_apply_theme:
    test rdi, rdi
    jz .fail
    mov [rel main_theme_ptr], rdi
    call plugin_api_set_theme_ptr

    mov rax, [rel main_repl_ptr]
    test rax, rax
    jz .hub
    mov r10, rdi
    mov rdi, rax
    mov rsi, [r10 + T_FONT_MAIN_OFF]
    mov edx, [r10 + T_FONT_MAIN_SIZE_OFF]
    call repl_set_font
    mov rdi, [rel main_repl_ptr]
    mov esi, [r10 + T_BG_OFF]
    mov edx, [r10 + T_FG_OFF]
    mov ecx, [r10 + T_ACCENT_OFF]
    mov r8d, [r10 + T_ACCENT_OFF]
    call repl_set_colors

.hub:
    mov rdi, [rel main_theme_ptr]
    call hub_init
    mov [rel hub_ptr], rax
    mov eax, 1
    ret
.fail:
    xor eax, eax
    ret

; main_plugins_autoload() - best effort auto-load from /tmp/aura/plugins/*/plugin.so
main_plugins_autoload:
    push rbx
    push r12
    push r13
    push r14
    push r15
    lea rdi, [rel plugins_root_path]
    mov esi, O_RDONLY | O_DIRECTORY
    xor edx, edx
    call hal_open
    test rax, rax
    js .out
    mov r12, rax                         ; dir fd
.read_loop:
    mov rdi, r12
    lea rsi, [rel plugins_dir_buf]
    mov edx, 8192
    call hal_getdents64
    test eax, eax
    jle .close
    mov r13d, eax                        ; bytes
    xor r14d, r14d                       ; offset
.ent_loop:
    cmp r14d, r13d
    jae .read_loop
    lea r15, [rel plugins_dir_buf + r14] ; dirent*
    movzx ebx, word [r15 + 16]          ; d_reclen
    cmp ebx, 19
    jb .next_ent
    cmp byte [r15 + 18], DT_DIR
    jne .next_ent
    cmp byte [r15 + 19], '.'
    je .next_ent
    ; build "<root>/<name>/plugin.so"
    lea rdi, [rel plugin_path_buf]
    lea rsi, [rel plugins_root_path]
    xor ecx, ecx
.cp_root:
    mov al, [rsi + rcx]
    mov [rdi + rcx], al
    test al, al
    jz .root_done
    inc ecx
    cmp ecx, 900
    jb .cp_root
    jmp .next_ent
.root_done:
    mov byte [rdi + rcx], '/'
    inc ecx
    xor edx, edx
.cp_name:
    mov al, [r15 + 19 + rdx]
    test al, al
    jz .name_done
    mov [rdi + rcx], al
    inc rcx
    inc edx
    cmp ecx, 980
    jb .cp_name
    jmp .next_ent
.name_done:
    lea rsi, [rel plugin_so_tail]
    xor edx, edx
.cp_tail:
    mov al, [rsi + rdx]
    mov [rdi + rcx], al
    test al, al
    jz .try_load
    inc rcx
    inc edx
    cmp ecx, 1023
    jb .cp_tail
    jmp .next_ent
.try_load:
    lea rdi, [rel plugin_path_buf]
    call plugin_load
    test rax, rax
    jz .next_ent
    mov r15, rax
    mov rdi, r15
    call plugin_api_set_current_plugin
    call plugin_api_get_host_table
    mov rsi, rax
    mov rdi, r15
    call plugin_activate
    xor rdi, rdi
    call plugin_api_set_current_plugin
    cmp eax, 0
    jne .fail_loaded
    mov rdi, r15
    call plugin_registry_add
    cmp eax, 0
    jne .fail_loaded
    jmp .next_ent
.fail_loaded:
    mov rdi, r15
    call plugin_unload
.next_ent:
    add r14d, ebx
    jmp .ent_loop
.close:
    mov rdi, r12
    call hal_close
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.fail:
    xor eax, eax
    ret

; main_reload_theme() -> eax 1/0
main_reload_theme:
    push rbx
    ; drop current resources before replacing theme object
    mov rdi, [rel main_theme_ptr]
    test rdi, rdi
    jz .load
    call theme_destroy

.load:
    mov rbx, [rel theme_file_ptr]
    test rbx, rbx
    jz .builtin
    mov rdi, rbx
    mov esi, [rel theme_file_len]
    call theme_load
    test rax, rax
    jnz .apply

.builtin:
    lea rdi, [rel theme_name]
    mov esi, theme_name_len
    call theme_load_builtin
    test rax, rax
    jz .fail

.apply:
    mov rdi, rax
    call main_apply_theme
    jmp .out

.fail:
    xor eax, eax
.out:
    pop rbx
    ret

; main_open_fm_req(path_ptr, path_len) -> eax 1/0
main_open_fm_req:
    push rbx
    push r12
    mov r12, rdi
    mov ebx, esi
    mov rdi, [rel fm_ptr]
    test rdi, rdi
    jnz .have_fm
    mov rdi, r12
    mov esi, 1
    call fm_init
    test rax, rax
    jz .fail
    mov [rel fm_ptr], rax
    mov rdi, rax
.have_fm:
    test r12, r12
    jz .show
    test ebx, ebx
    jle .show
    mov rsi, r12
    mov edx, ebx
    call fm_open_path
.show:
    mov dword [rel fm_visible], 1
    mov eax, 1
    pop r12
    pop rbx
    ret
.fail:
    xor eax, eax
    pop r12
    pop rbx
    ret

main_poll_fm_requests:
    ; 1) shell builtin `fm [path]`
    lea rdi, [rel fm_req_buf]
    mov esi, 1024
    call builtin_fm_take_request
    test eax, eax
    jle .hub
    lea rdi, [rel fm_req_buf]
    mov esi, eax
    call main_open_fm_req
    ret
.hub:
    ; 2) Hub Files card
    lea rdi, [rel fm_req_buf]
    mov esi, 1024
    call hub_take_fm_request
    test eax, eax
    jle .hotkey
    lea rdi, [rel fm_req_buf]
    mov esi, eax
    call main_open_fm_req
    ret
.hotkey:
    ; 3) Super+E toggle request from WM
    call wm_take_fm_toggle_request
    test eax, eax
    jz .done
    cmp dword [rel fm_visible], 0
    je .show_default
    mov dword [rel fm_visible], 0
    ret
.show_default:
    lea rdi, [rel fm_req_buf]
    mov byte [rdi], '/'
    mov byte [rdi + 1], 0
    mov esi, 1
    call main_open_fm_req
.done:
    ret

_start:
    mov rcx, [rsp]
    lea rax, [rsp + 8]
    mov [rel startup_argc], rcx
    mov [rel startup_argv], rax
    lea rdx, [rax + rcx * 8 + 8]
    mov [rel global_envp], rdx

    call aura_pick_run_mode

    lea rdi, [rel env_theme_file]
    mov esi, env_theme_file_len
    call aura_find_env_value
    mov [rel theme_file_ptr], rax
    test rax, rax
    jz .no_theme_file
    mov rdi, rax
    call cstr_len
    mov [rel theme_file_len], eax
.no_theme_file:

    mov rdi, 1048576
    call arena_init
    test rax, rax
    jz .fail
    mov [rel main_arena_ptr], rax

    call input_queue_init

    call widget_system_init
    test eax, eax
    jnz .fail

    mov rdi, 1024
    mov rsi, 768
    lea rdx, [rel app_title]
    call window_create
    test rax, rax
    jz .fail_cleanup_ws
    mov [rel main_window_ptr], rax

    call main_reload_theme
    test eax, eax
    jz .fail_cleanup_ws
    call main_plugins_autoload

    mov edi, 4
    call workspaces_init
    mov [rel ws_mgr_ptr], rax

    mov r10, [rel main_theme_ptr]
    mov rdi, [r10 + T_FONT_MAIN_OFF]
    lea rsi, [rel measure_ch]
    mov edx, 1
    mov ecx, [r10 + T_FONT_MAIN_SIZE_OFF]
    call font_measure_string
    mov r8d, eax
    mov r9d, edx

    mov rdi, [rel main_arena_ptr]
    call repl_set_arena

    mov rdi, [rel main_window_ptr]
    mov esi, r8d
    mov edx, r9d
    call repl_init
    test rax, rax
    jz .fail_cleanup_ws
    mov [rel main_repl_ptr], rax

    mov r10, [rel main_theme_ptr]
    mov rdi, [rel main_repl_ptr]
    mov rsi, [r10 + T_FONT_MAIN_OFF]
    mov edx, [r10 + T_FONT_MAIN_SIZE_OFF]
    call repl_set_font

    mov rdi, [rel main_repl_ptr]
    mov esi, [r10 + T_BG_OFF]
    mov edx, [r10 + T_FG_OFF]
    mov ecx, [r10 + T_ACCENT_OFF]
    mov r8d, [r10 + T_ACCENT_OFF]
    call repl_set_colors

    mov rdi, WIDGET_CONTAINER
    xor esi, esi
    xor edx, edx
    mov ecx, 1024
    mov r8d, 768
    call widget_init
    test rax, rax
    jz .fail_cleanup_ws
    mov [rel root_widget], rax

    mov rdi, [rel main_repl_ptr]
    mov rsi, [rel main_theme_ptr]
    mov edx, 1024
    mov ecx, 768
    call terminal_widget_init
    test rax, rax
    jz .fail_cleanup_ws
    mov [rel term_widget], rax

    mov rdi, [rel root_widget]
    mov rsi, [rel term_widget]
    call widget_add_child

    call cursor_init
    mov [rel cursor_ptr], rax

    mov rdi, [rel term_widget]
    call widget_focus

    lea rdi, [rel gesture_rec]
    call gesture_init

    lea rdi, [rel anim_sched]
    call anim_scheduler_init

    mov rdi, CLOCK_MONOTONIC
    lea rsi, [rel ts_last_blink]
    call hal_clock_gettime

    ; argv integration: `aura-shell fm [/path]`
    mov rax, [rel startup_argc]
    cmp rax, 2
    jb .loop
    mov rbx, [rel startup_argv]
    mov rdi, [rbx + 8]
    test rdi, rdi
    jz .loop
    mov al, [rdi]
    cmp al, 'f'
    jne .loop
    mov al, [rdi + 1]
    cmp al, 'm'
    jne .loop
    cmp byte [rdi + 2], 0
    jne .loop
    mov rax, [rel startup_argc]
    cmp rax, 3
    jb .argv_default
    mov rdi, [rbx + 16]
    call cstr_len
    mov esi, eax
    mov rdi, [rbx + 16]
    call main_open_fm_req
    jmp .loop
.argv_default:
    lea rdi, [rel fm_default_path]
    mov esi, 1
    call main_open_fm_req

.loop:
    mov rdi, [rel main_window_ptr]
    call window_process_events

.poll:
    lea rdi, [rel event_tmp]
    call input_poll_event
    cmp rax, 1
    jne .blink

    lea rdi, [rel gesture_rec]
    lea rsi, [rel event_tmp]
    call gesture_process_event
    mov r10d, eax

    mov rdi, [rel hub_ptr]
    lea rsi, [rel event_tmp]
    call hub_handle_input

    mov rdi, [rel ws_mgr_ptr]
    lea rsi, [rel event_tmp]
    call overview_handle_input

    test r10d, r10d
    jz .dispatch_widgets
    mov edi, r10d
    lea rsi, [rel event_tmp]
    call main_handle_gesture

.dispatch_widgets:
    cmp dword [rel event_tmp + INPUT_EVENT_TYPE_OFF], INPUT_MOUSE_MOVE
    jne .widgets_only
    mov rdi, [rel cursor_ptr]
    mov esi, [rel event_tmp + INPUT_EVENT_MOUSE_X_OFF]
    mov edx, [rel event_tmp + INPUT_EVENT_MOUSE_Y_OFF]
    call cursor_update_pos
.widgets_only:
    cmp dword [rel fm_visible], 0
    je .widgets_default
    mov rdi, [rel fm_ptr]
    test rdi, rdi
    jz .widgets_default
    lea rsi, [rel event_tmp]
    call fm_handle_input
    test eax, eax
    jnz .poll
.widgets_default:

    mov rdi, [rel root_widget]
    lea rsi, [rel event_tmp]
    call widget_handle_input

    jmp .poll

.blink:
    mov rdi, CLOCK_MONOTONIC
    lea rsi, [rel ts_now]
    call hal_clock_gettime
    lea rdi, [rel ts_now]
    call timespec_to_ns
    mov r8, rax
    lea rdi, [rel ts_last_blink]
    call timespec_to_ns
    sub r8, rax
    cmp r8, BLINK_INTERVAL_NS
    jb .tick

    xor rdi, rdi
    xor rsi, rsi
    mov rdx, [rel main_repl_ptr]
    call repl_cursor_blink
    mov rdi, [rel term_widget]
    call widget_set_dirty
    mov rax, [rel ts_now]
    mov [rel ts_last_blink], rax
    mov rax, [rel ts_now + 8]
    mov [rel ts_last_blink + 8], rax

.tick:
    lea rdi, [rel anim_sched]
    call anim_scheduler_tick

    call jobs_update_status
    call main_poll_fm_requests

    mov rdi, [rel main_window_ptr]
    call window_get_canvas
    mov r11, rax
    mov rdi, r11
    call plugin_api_set_canvas_ptr
    mov rdi, [rel ws_mgr_ptr]
    xor esi, esi
    mov rdx, r11
    call overview_render
    mov rdi, [rel hub_ptr]
    mov rsi, r11
    mov rdx, [rel main_theme_ptr]
    call hub_render
    cmp dword [rel fm_visible], 0
    je .render_root
    mov rdi, [rel fm_ptr]
    test rdi, rdi
    jz .render_root
    mov rsi, r11
    mov rdx, [rel main_theme_ptr]
    call fm_render
    jmp .render_cursor
.render_root:
    mov rdi, [rel root_widget]
    mov rsi, r11
    mov rdx, [rel main_theme_ptr]
    xor ecx, ecx
    xor r8d, r8d
    call widget_render
.render_cursor:
    mov rdi, [rel cursor_ptr]
    mov rsi, r11
    call cursor_render

    mov rdi, [rel main_window_ptr]
    call window_present

    mov rdi, [rel main_window_ptr]
    call window_should_close
    cmp rax, 1
    je .cleanup

    call main_sleep_1ms
    jmp .loop

.cleanup:
    mov rdi, [rel main_theme_ptr]
    call theme_destroy
    mov rdi, [rel main_window_ptr]
    call window_destroy
    call widget_system_shutdown
    mov rdi, [rel main_arena_ptr]
    call arena_destroy
    xor rdi, rdi
    call hal_exit

.fail_cleanup_ws:
    mov rdi, [rel main_window_ptr]
    test rdi, rdi
    jz .fail_cleanup_arena
    call window_destroy
.fail_cleanup_arena:
    call widget_system_shutdown
    mov rdi, [rel main_arena_ptr]
    test rdi, rdi
    jz .fail
    call arena_destroy
.fail:
    mov rdi, STDERR
    lea rsi, [rel init_fail_msg]
    mov rdx, init_fail_len
    call hal_write
    mov rdi, 1
    call hal_exit

; main_handle_gesture(gesture_id, event_ptr)
main_handle_gesture:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov ebx, edi
    mov r12, rsi
    mov rdi, [rel ws_mgr_ptr]
    test rdi, rdi
    jz .out

    lea r13, [rel gesture_rec]
    mov rdi, r13
    lea rsi, [rel gesture_data]
    call gesture_get_data

    mov eax, [rel gesture_data + GD_DELTA_X_OFF]
    mov r10d, eax                        ; delta_x
    mov eax, [rel gesture_data + GD_DELTA_Y_OFF]
    mov r11d, eax                        ; delta_y
    mov r8d, [r12 + INPUT_EVENT_MOUSE_X_OFF]
    mov r9d, [r12 + INPUT_EVENT_MOUSE_Y_OFF]
    mov eax, r8d
    sub eax, r10d
    mov ecx, eax                         ; start_x ~= end_x - delta_x
    mov eax, r9d
    sub eax, r11d
    mov edx, eax                         ; start_y ~= end_y - delta_y

    mov rax, [rel main_theme_ptr]
    test rax, rax
    jz .theme_fallback
    mov esi, [rax + T_GESTURE_EDGE_PX_OFF]
    mov edi, [rax + T_GESTURE_BOTTOM_PX_OFF]
    test esi, esi
    jle .theme_fallback
    test edi, edi
    jle .theme_fallback
    jmp .theme_ok
.theme_fallback:
    mov esi, EDGE_GESTURE_PX_DEFAULT
    mov edi, BOTTOM_EDGE_PX_DEFAULT
.theme_ok:
    ; Dynamic viewport size (current canvas), fallback to defaults.
    mov r14d, MAIN_VIEW_W_DEFAULT
    mov r15d, MAIN_VIEW_H_DEFAULT
    mov rdi, [rel main_window_ptr]
    test rdi, rdi
    jz .view_ok
    call window_get_canvas
    test rax, rax
    jz .view_ok
    mov r14d, [rax + CV_WIDTH_OFF]
    mov r15d, [rax + CV_HEIGHT_OFF]
    test r14d, r14d
    jg .vw_ok
    mov r14d, MAIN_VIEW_W_DEFAULT
.vw_ok:
    test r15d, r15d
    jg .view_ok
    mov r15d, MAIN_VIEW_H_DEFAULT
.view_ok:

    cmp ebx, GESTURE_SWIPE_LEFT
    jne .sw_right_generic
    ; Edge swipe horizontal: switch workspace (from right edge to left)
    mov eax, r14d
    sub eax, esi
    cmp ecx, eax
    jl .out
    mov rdi, [rel ws_mgr_ptr]
    mov esi, 1
    call workspaces_switch_relative
    jmp .out
.sw_right_generic:
    cmp ebx, GESTURE_SWIPE_RIGHT
    jne .sw_up
    ; Edge swipe left->right:
    ; - in Hub: back
    ; - otherwise: previous workspace
    cmp ecx, esi
    jg .out
    mov rdi, [rel ws_mgr_ptr]
    cmp dword [rdi + WSM_HUB_MODE_OFF], 0
    je .sw_right_ws
    call hub_toggle
    jmp .out
.sw_right_ws:
    mov esi, -1
    call workspaces_switch_relative
    jmp .out
.sw_up:
    cmp ebx, GESTURE_SWIPE_UP
    jne .three_up
    ; Bottom-edge swipe up toggles Hub
    mov eax, r15d
    sub eax, edi
    cmp edx, eax
    jl .out
    mov rdi, [rel ws_mgr_ptr]
    call hub_toggle
    jmp .out
.three_up:
    cmp ebx, GESTURE_THREE_FINGER_UP
    jne .two_sw
    mov rdi, [rel ws_mgr_ptr]
    xor rsi, rsi
    call overview_enter
    jmp .out
.two_sw:
    cmp ebx, GESTURE_TWO_FINGER_SWIPE
    jne .three_down
    mov eax, r10d
    test eax, eax
    jge .two_right
    mov rdi, [rel ws_mgr_ptr]
    mov esi, 1
    call workspaces_switch_relative
    jmp .out
.two_right:
    mov rdi, [rel ws_mgr_ptr]
    mov esi, -1
    call workspaces_switch_relative
.three_down:
    cmp ebx, GESTURE_THREE_FINGER_DOWN
    jne .out
    call main_reload_theme
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
