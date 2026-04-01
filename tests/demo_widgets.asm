; demo_widgets.asm — interactive showcase (manual): 1024x768, tokyo-night theme,
; full-window REPL terminal, tab bar, scrollable list (inertia), demo button, status bar.
; Build: aura-widget-demo (see Makefile target demo).
%include "src/hal/platform_defs.inc"
%include "src/gui/widget.inc"
%include "src/gui/theme.inc"
%include "src/core/gesture.inc"

extern hal_write
extern hal_exit
extern hal_clock_gettime
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
extern theme_load_builtin
extern theme_destroy
extern font_measure_string
extern gesture_init
extern gesture_process_event
extern spring_init
extern spring_set_target
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
extern widget_measure
extern terminal_widget_init
extern jobs_update_status

%define KEY_PRESSED                     1
%define BLINK_INTERVAL_NS               500000000
%define DEMO_LIST_ITEMS                 24

; ListData offsets (match list.asm)
%define LD_ITEMS    0
%define LD_COUNT    8
%define LD_ITEM_H   12
%define LD_FONT     16
%define LD_FG       24
%define LD_SEL      28
%define LD_INERT    32
%define LD_TEXTLEN  72

; ButtonData (match button.asm)
%define BD_TEXT        0
%define BD_LEN         8
%define BD_ONCLICK     16
%define BD_FONT        24
%define BD_BG          32
%define BD_FG          36
%define BD_RIPPLE      52

; Status bar (match status_bar.asm)
%define ST_BG       0
%define ST_FONT     4
%define ST_FG       12
%define ST_LEFT     20
%define ST_LEFTLEN  28
%define ST_RIGHT    32
%define ST_RIGHTLEN 40

; Tab bar (match tab_bar.asm)
%define TB_LABELS   0
%define TB_N        8
%define TB_ACTIVE   12
%define TB_IND      16
%define TB_ACCENT   44
%define TB_TABW     48

section .rodata
    app_title           db "Aura Widget Demo", 0
    theme_name          db "tokyo-night", 0
    theme_name_len      equ 11
    measure_ch          db "M", 0
    init_fail_msg       db "aura-widget-demo: init failed", 10
    init_fail_len       equ $ - init_fail_msg
    demo_btn_txt        db "Demo", 0
    demo_btn_len        equ $ - demo_btn_txt - 1
    list_row_txt        db "Scroll row (drag for inertia)", 0
    st_left_txt         db "Aura Phase 2", 0
    st_left_len         equ $ - st_left_txt - 1
    st_right_txt        db "Tab / List / REPL", 0
    st_right_len        equ $ - st_right_txt - 1

section .bss
    demo_arena_ptr      resq 1
    demo_window_ptr     resq 1
    demo_repl_ptr       resq 1
    demo_theme_ptr      resq 1
    root_widget         resq 1
    term_widget         resq 1
    list_widget         resq 1
    btn_widget          resq 1
    stat_widget         resq 1
    tab_widget          resq 1
    list_data           resb 96
    list_item_ptrs      resq DEMO_LIST_ITEMS
    button_data         resb 96
    status_data         resb 64
    tab_data            resb 64
    event_tmp           resb 64
    ts_now              resq 2
    ts_last_blink       resq 2
    gesture_rec         resb GR_STRUCT_SIZE
    anim_sched          resb 1200

section .text
global _start

demo_sleep_1ms:
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

_start:
    mov rcx, [rsp]
    lea rax, [rsp + 8]
    lea rdx, [rax + rcx * 8 + 8]
    mov [rel global_envp], rdx

    mov rdi, 1048576
    call arena_init
    test rax, rax
    jz .fail
    mov [rel demo_arena_ptr], rax

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
    mov [rel demo_window_ptr], rax

    lea rdi, [rel theme_name]
    mov esi, theme_name_len
    call theme_load_builtin
    test rax, rax
    jz .fail_cleanup_ws
    mov [rel demo_theme_ptr], rax

    mov rdi, [rax + T_FONT_MAIN_OFF]
    lea rsi, [rel measure_ch]
    mov edx, 1
    mov ecx, [rax + T_FONT_MAIN_SIZE_OFF]
    call font_measure_string
    mov r8d, eax
    mov r9d, edx

    mov rdi, [rel demo_arena_ptr]
    call repl_set_arena

    mov rdi, [rel demo_window_ptr]
    mov esi, r8d
    mov edx, r9d
    call repl_init
    test rax, rax
    jz .fail_cleanup_ws
    mov [rel demo_repl_ptr], rax

    mov r10, [rel demo_theme_ptr]
    mov rdi, [rel demo_repl_ptr]
    mov rsi, [r10 + T_FONT_MAIN_OFF]
    mov edx, [r10 + T_FONT_MAIN_SIZE_OFF]
    call repl_set_font

    mov rdi, [rel demo_repl_ptr]
    mov esi, [r10 + T_BG_OFF]
    mov edx, [r10 + T_FG_OFF]
    mov ecx, [r10 + T_ACCENT_OFF]
    mov r8d, [r10 + T_ACCENT_OFF]
    call repl_set_colors

    ; --- Root ---
    mov rdi, WIDGET_CONTAINER
    xor esi, esi
    xor edx, edx
    mov ecx, 1024
    mov r8d, 768
    call widget_init
    test rax, rax
    jz .fail_cleanup_ws
    mov [rel root_widget], rax

    ; --- Terminal (full window, drawn first) ---
    mov rdi, [rel demo_repl_ptr]
    mov rsi, [rel demo_theme_ptr]
    mov edx, 1024
    mov ecx, 768
    call terminal_widget_init
    test rax, rax
    jz .fail_cleanup_ws
    mov [rel term_widget], rax

    mov rdi, [rel root_widget]
    mov rsi, [rel term_widget]
    call widget_add_child

    ; --- Demo button (below tab strip) ---
    mov edi, WIDGET_BUTTON
    mov esi, 8
    mov edx, 56
    mov ecx, 200
    mov r8d, 48
    call widget_init
    test rax, rax
    jz .fail_cleanup_ws
    mov [rel btn_widget], rax

    lea rbx, [rel button_data]
    lea rdi, [rel demo_btn_txt]
    mov [rbx + BD_TEXT], rdi
    mov dword [rbx + BD_LEN], demo_btn_len
    mov qword [rbx + BD_ONCLICK], 0
    mov rdi, [r10 + T_FONT_MAIN_OFF]
    mov [rbx + BD_FONT], rdi
    mov eax, [r10 + T_SURFACE_OFF]
    mov [rbx + BD_BG], eax
    mov eax, [r10 + T_FG_OFF]
    mov [rbx + BD_FG], eax
    lea rdi, [rbx + BD_RIPPLE]
    xor esi, esi
    mov edx, esi
    mov ecx, 0x00018000
    mov r8d, 0x0000C000
    call spring_init
    mov rax, [rel btn_widget]
    mov [rax + W_DATA_OFF], rbx

    mov rdi, [rel root_widget]
    mov rsi, [rel btn_widget]
    call widget_add_child

    ; --- List with inertia (left column) ---
    xor ecx, ecx
.lp_fill:
    cmp ecx, DEMO_LIST_ITEMS
    jae .lp_done
    lea rax, [rel list_row_txt]
    mov [rel list_item_ptrs + rcx * 8], rax
    inc ecx
    jmp .lp_fill
.lp_done:

    mov edi, WIDGET_LIST
    mov esi, 8
    mov edx, 112
    mov ecx, 320
    mov r8d, 560
    call widget_init
    test rax, rax
    jz .fail_cleanup_ws
    mov [rel list_widget], rax

    lea rbx, [rel list_data]
    lea rdi, [rel list_item_ptrs]
    mov [rbx + LD_ITEMS], rdi
    mov dword [rbx + LD_COUNT], DEMO_LIST_ITEMS
    mov dword [rbx + LD_ITEM_H], 48
    mov rdi, [r10 + T_FONT_MAIN_OFF]
    mov [rbx + LD_FONT], rdi
    mov eax, [r10 + T_FG_OFF]
    mov [rbx + LD_FG], eax
    mov dword [rbx + LD_SEL], 0
    mov dword [rbx + LD_TEXTLEN], 40
    mov rax, [rel list_widget]
    mov [rax + W_DATA_OFF], rbx
    mov rdi, rax
    mov esi, 1024
    mov edx, 768
    call widget_measure

    mov rdi, [rel root_widget]
    mov rsi, [rel list_widget]
    call widget_add_child

    ; --- Status bar ---
    mov edi, WIDGET_STATUS_BAR
    xor esi, esi
    mov edx, 728
    mov ecx, 1024
    mov r8d, 40
    call widget_init
    test rax, rax
    jz .fail_cleanup_ws
    mov [rel stat_widget], rax

    lea rbx, [rel status_data]
    mov eax, [r10 + T_BORDER_COLOR_OFF]
    mov [rbx + ST_BG], eax
    mov rdi, [r10 + T_FONT_MAIN_OFF]
    mov [rbx + ST_FONT], rdi
    mov eax, [r10 + T_FG_OFF]
    mov [rbx + ST_FG], eax
    lea rdi, [rel st_left_txt]
    mov [rbx + ST_LEFT], rdi
    mov dword [rbx + ST_LEFTLEN], st_left_len
    lea rdi, [rel st_right_txt]
    mov [rbx + ST_RIGHT], rdi
    mov dword [rbx + ST_RIGHTLEN], st_right_len
    mov rax, [rel stat_widget]
    mov [rax + W_DATA_OFF], rbx

    mov rdi, [rel root_widget]
    mov rsi, [rel stat_widget]
    call widget_add_child

    ; --- Tab bar (top chrome, hit-tested first) ---
    mov edi, WIDGET_TAB_BAR
    xor esi, esi
    xor edx, edx
    mov ecx, 1024
    mov r8d, 48
    call widget_init
    test rax, rax
    jz .fail_cleanup_ws
    mov [rel tab_widget], rax

    lea rbx, [rel tab_data]
    mov qword [rbx + TB_LABELS], 0
    mov dword [rbx + TB_N], 2
    mov dword [rbx + TB_ACTIVE], 0
    mov eax, [r10 + T_ACCENT_OFF]
    mov [rbx + TB_ACCENT], eax
    mov dword [rbx + TB_TABW], 512
    lea rdi, [rbx + TB_IND]
    xor esi, esi
    mov edx, esi
    mov ecx, 0x00010000
    mov r8d, 0x00008000
    call spring_init
    lea rdi, [rbx + TB_IND]
    xor esi, esi
    call spring_set_target
    mov rax, [rel tab_widget]
    mov [rax + W_DATA_OFF], rbx

    mov rdi, [rel root_widget]
    mov rsi, [rel tab_widget]
    call widget_add_child

    mov rdi, [rel term_widget]
    call widget_focus

    lea rdi, [rel gesture_rec]
    call gesture_init

    lea rdi, [rel anim_sched]
    call anim_scheduler_init

    mov rdi, CLOCK_MONOTONIC
    lea rsi, [rel ts_last_blink]
    call hal_clock_gettime

.loop:
    mov rdi, [rel demo_window_ptr]
    call window_process_events

.poll:
    lea rdi, [rel event_tmp]
    call input_poll_event
    cmp rax, 1
    jne .blink

    lea rdi, [rel gesture_rec]
    lea rsi, [rel event_tmp]
    call gesture_process_event

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
    mov rdx, [rel demo_repl_ptr]
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

    mov rdi, [rel demo_window_ptr]
    call window_get_canvas
    mov rsi, rax
    mov rdi, [rel root_widget]
    mov rdx, [rel demo_theme_ptr]
    xor ecx, ecx
    xor r8d, r8d
    call widget_render

    mov rdi, [rel demo_window_ptr]
    call window_present

    mov rdi, [rel demo_window_ptr]
    call window_should_close
    cmp rax, 1
    je .cleanup

    call demo_sleep_1ms
    jmp .loop

.cleanup:
    mov rdi, [rel demo_theme_ptr]
    call theme_destroy
    mov rdi, [rel demo_window_ptr]
    call window_destroy
    call widget_system_shutdown
    mov rdi, [rel demo_arena_ptr]
    call arena_destroy
    xor rdi, rdi
    call hal_exit

.fail_cleanup_ws:
    mov rdi, [rel demo_window_ptr]
    test rdi, rdi
    jz .fail_cleanup_arena
    call window_destroy
.fail_cleanup_arena:
    call widget_system_shutdown
    mov rdi, [rel demo_arena_ptr]
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
