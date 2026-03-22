; main.asm — Aura Shell: widgets + TrueType theme + REPL terminal
%include "src/hal/linux_x86_64/defs.inc"
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

%define KEY_PRESSED                     1
%define BLINK_INTERVAL_NS               500000000

section .rodata
    app_title           db "Aura Shell", 0
    theme_name          db "tokyo-night", 0
    theme_name_len      equ 11
    measure_ch          db "M", 0
    init_fail_msg       db "aura-shell: init failed", 10
    init_fail_len       equ $ - init_fail_msg

section .bss
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
    anim_sched          resb 1200

section .text
global _start

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

_start:
    mov rcx, [rsp]
    lea rax, [rsp + 8]
    lea rdx, [rax + rcx * 8 + 8]
    mov [rel global_envp], rdx

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

    lea rdi, [rel theme_name]
    mov esi, theme_name_len
    call theme_load_builtin
    test rax, rax
    jz .fail_cleanup_ws
    mov [rel main_theme_ptr], rax

    mov rdi, [rax + T_FONT_MAIN_OFF]
    lea rsi, [rel measure_ch]
    mov edx, 1
    mov ecx, [rax + T_FONT_MAIN_SIZE_OFF]
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

    mov rdi, [rel main_window_ptr]
    call window_get_canvas
    mov rsi, rax
    mov rdi, [rel root_widget]
    mov rdx, [rel main_theme_ptr]
    xor ecx, ecx
    xor r8d, r8d
    call widget_render

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
