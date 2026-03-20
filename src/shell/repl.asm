; repl.asm
; Minimal Aura Shell REPL for Phase 0

%include "src/hal/linux_x86_64/defs.inc"

extern arena_alloc
extern arena_init
extern arena_reset
extern window_get_canvas
extern canvas_clear
extern canvas_fill_rect
extern canvas_draw_string
extern window_present
extern wayland_keycode_to_ascii
extern font_char_width
extern font_char_height
extern hal_getenv_raw
extern hal_sigaction
extern hal_sigreturn_restorer
extern lexer_init
extern lexer_tokenize
extern lexer_get_error
extern parser_init
extern parser_parse
extern parser_get_error
extern executor_init
extern executor_run
extern builtins_init
extern jobs_update_status

section .text
global repl_set_arena
global repl_init
global repl_handle_key
global repl_execute
global repl_print
global repl_render
global repl_cursor_blink

%define HIST_MAX_LINES                  1000
%define INPUT_BUF_CAP                   1024
%define WINDOW_SHOULD_CLOSE_OFF         80
%define CANVAS_WIDTH_OFF                8
%define CANVAS_HEIGHT_OFF               12

%define INPUT_EVENT_KEY_CODE_OFF        16
%define INPUT_EVENT_MODIFIERS_OFF       24

%define MOD_CTRL                        0x02

%define KEY_LEFT                        105
%define KEY_RIGHT                       106
%define KEY_HOME                        102
%define KEY_END                         107
%define KEY_DELETE                      111
%define KEY_C                           46
%define KEY_L                           38

%define COLOR_BG                        0xFF1A1B26
%define COLOR_FG                        0xFFC0CAF5
%define COLOR_PROMPT                    0xFF7AA2F7
%define COLOR_CURSOR                    0xFFC0CAF5

; REPL struct
%define R_WINDOW_PTR_OFF                0
%define R_CANVAS_PTR_OFF                8
%define R_INPUT_BUF_OFF                 16
%define R_INPUT_LEN_OFF                 (R_INPUT_BUF_OFF + INPUT_BUF_CAP)
%define R_INPUT_CURSOR_OFF              (R_INPUT_LEN_OFF + 8)
%define R_CURSOR_VISIBLE_OFF            (R_INPUT_CURSOR_OFF + 8)
%define R_SCREEN_BUF_OFF                (R_CURSOR_VISIBLE_OFF + 8)
%define R_SCREEN_LINES_OFF              (R_SCREEN_BUF_OFF + 8)
%define R_SCREEN_COLS_OFF               (R_SCREEN_LINES_OFF + 8)
%define R_SCROLL_OFFSET_OFF             (R_SCREEN_COLS_OFF + 8)
%define R_LINE_COUNT_OFF                (R_SCROLL_OFFSET_OFF + 8)
%define R_PROMPT_OFF                    (R_LINE_COUNT_OFF + 8)
%define R_PROMPT_LEN_OFF                (R_PROMPT_OFF + 32)
; internal state
%define R_WRITE_COL_OFF                 (R_PROMPT_LEN_OFF + 8)
%define R_STRUCT_SIZE                   (R_WRITE_COL_OFF + 8)

section .data
    repl_prompt_default                 db "aura> "
    repl_prompt_default_len             equ $ - repl_prompt_default
    repl_welcome                        db "Aura Shell v0.1 - Phase 0",10,10
    repl_welcome_len                    equ $ - repl_welcome
    repl_newline                        db 10

    repl_help_text                      db "Commands: echo, clear, exit, help, version",10
    repl_help_text_len                  equ $ - repl_help_text
    repl_version_text                   db "Aura Shell v0.1 - Phase 0, NASM x86_64",10
    repl_version_text_len               equ $ - repl_version_text
    repl_unknown_prefix                 db "Unknown command: "
    repl_unknown_prefix_len             equ $ - repl_unknown_prefix

    cmd_echo                            db "echo"
    cmd_clear                           db "clear"
    cmd_exit                            db "exit"
    cmd_help                            db "help"
    cmd_version                         db "version"

section .bss
    repl_arena_ptr                      resq 1
    repl_exec_arena_ptr                 resq 1
    repl_envp_ptr                       resq 1
    repl_instance                       resb R_STRUCT_SIZE

section .text

; rdi=ptr, rsi=len
repl_memzero:
    test rsi, rsi
    jz .ret
    xor eax, eax
.zloop:
    mov byte [rdi], al
    inc rdi
    dec rsi
    jnz .zloop
.ret:
    ret

; rdi=dst, rsi=src, rdx=len
repl_memcpy:
    test rdx, rdx
    jz .ret
.cloop:
    mov al, [rsi]
    mov [rdi], al
    inc rdi
    inc rsi
    dec rdx
    jnz .cloop
.ret:
    ret

; rdi=ptr1, rsi=ptr2, rdx=len
; rax=1 equal, 0 otherwise
repl_memeq:
    xor eax, eax
    test rdx, rdx
    jz .yes
.loop:
    mov cl, [rdi]
    cmp cl, [rsi]
    jne .no
    inc rdi
    inc rsi
    dec rdx
    jnz .loop
.yes:
    mov eax, 1
    ret
.no:
    xor eax, eax
    ret

; rdi=c-string ptr
; rax=len
repl_cstrlen:
    xor eax, eax
    test rdi, rdi
    jz .ret
.loop:
    cmp byte [rdi + rax], 0
    je .ret
    inc rax
    jmp .loop
.ret:
    ret

; rdi=signum
repl_ignore_signal:
    sub rsp, 32
    mov qword [rsp + 0], SIG_IGN
    mov qword [rsp + 8], SA_RESTART | SA_RESTORER
    lea rax, [rel hal_sigreturn_restorer]
    mov [rsp + 16], rax
    mov qword [rsp + 24], 0
    mov rsi, rsp
    xor rdx, rdx
    call hal_sigaction
    add rsp, 32
    ret

; rdi=repl, rsi=abs_line
; rax=pointer to line start
repl_line_ptr:
    push rdx
    push rcx
    mov rax, rsi
    xor edx, edx
    mov ecx, HIST_MAX_LINES
    div rcx
    mov rax, [rdi + R_SCREEN_COLS_OFF]
    imul rax, rdx
    add rax, [rdi + R_SCREEN_BUF_OFF]
    pop rcx
    pop rdx
    ret

; rdi=repl
repl_ensure_first_line:
    push rbx
    mov rbx, rdi
    cmp qword [rdi + R_LINE_COUNT_OFF], 0
    jne .ret
    mov qword [rdi + R_LINE_COUNT_OFF], 1
    mov qword [rdi + R_WRITE_COL_OFF], 0
    mov rsi, 0
    call repl_line_ptr
    mov rdi, rax
    mov rsi, [rbx + R_SCREEN_COLS_OFF]
    call repl_memzero
.ret:
    pop rbx
    ret

; rdi=repl
repl_new_output_line:
    push rbx
    mov rbx, rdi
    inc qword [rbx + R_LINE_COUNT_OFF]
    mov qword [rbx + R_WRITE_COL_OFF], 0
    mov rdi, rbx
    mov rsi, [rbx + R_LINE_COUNT_OFF]
    dec rsi
    call repl_line_ptr
    mov rdi, rax
    mov rsi, [rbx + R_SCREEN_COLS_OFF]
    call repl_memzero
    pop rbx
    ret

; rdi=repl
repl_clear_history:
    push rbx
    mov rbx, rdi
    mov rax, [rbx + R_SCREEN_COLS_OFF]
    imul rax, HIST_MAX_LINES
    mov rdi, [rbx + R_SCREEN_BUF_OFF]
    mov rsi, rax
    call repl_memzero
    mov qword [rbx + R_LINE_COUNT_OFF], 1
    mov qword [rbx + R_WRITE_COL_OFF], 0
    pop rbx
    ret

; repl_set_arena(arena_ptr)
repl_set_arena:
    mov [rel repl_arena_ptr], rdi
    xor eax, eax
    ret

; repl_init(window_ptr)
; rax = repl_ptr or 0
repl_init:
    push rbx
    push r12
    push r13
    push r14

    test rdi, rdi
    jz .fail
    mov rbx, rdi
    lea r12, [rel repl_instance]

    ; zero full struct
    mov rdi, r12
    mov rsi, R_STRUCT_SIZE
    call repl_memzero

    mov [r12 + R_WINDOW_PTR_OFF], rbx
    mov rdi, rbx
    call window_get_canvas
    test rax, rax
    jz .fail
    mov [r12 + R_CANVAS_PTR_OFF], rax

    mov r13, [rax + CANVAS_WIDTH_OFF]
    mov r14, [rax + CANVAS_HEIGHT_OFF]

    mov rcx, [rel font_char_width]
    test rcx, rcx
    jz .fail
    xor rdx, rdx
    mov rax, r13
    div rcx
    cmp rax, 8
    jb .fail
    mov [r12 + R_SCREEN_COLS_OFF], rax

    mov rcx, [rel font_char_height]
    test rcx, rcx
    jz .fail
    xor rdx, rdx
    mov rax, r14
    div rcx
    cmp rax, 2
    jb .fail
    mov [r12 + R_SCREEN_LINES_OFF], rax

    mov rdi, [rel repl_arena_ptr]
    test rdi, rdi
    jz .fail
    mov rax, [r12 + R_SCREEN_COLS_OFF]
    imul rax, HIST_MAX_LINES
    mov rsi, rax
    call arena_alloc
    test rax, rax
    jz .fail
    mov [r12 + R_SCREEN_BUF_OFF], rax

    mov qword [r12 + R_INPUT_LEN_OFF], 0
    mov qword [r12 + R_INPUT_CURSOR_OFF], 0
    mov qword [r12 + R_CURSOR_VISIBLE_OFF], 1
    mov qword [r12 + R_SCROLL_OFFSET_OFF], 0
    mov qword [r12 + R_WRITE_COL_OFF], 0

    lea rdi, [r12 + R_PROMPT_OFF]
    lea rsi, [rel repl_prompt_default]
    mov rdx, repl_prompt_default_len
    call repl_memcpy
    mov qword [r12 + R_PROMPT_LEN_OFF], repl_prompt_default_len

    ; dedicated execution arena for lexer/parser/executor temporary data
    mov rdi, 1048576
    call arena_init
    test rax, rax
    jz .fail
    mov [rel repl_exec_arena_ptr], rax
    call hal_getenv_raw
    mov [rel repl_envp_ptr], rax

    ; initialize persistent shell stores (builtins/vars/alias/history/jobs)
    mov rdi, [rel repl_arena_ptr]
    call builtins_init

    ; shell should not be suspended by terminal job-control signals
    mov rdi, SIGTSTP
    call repl_ignore_signal
    mov rdi, SIGTTIN
    call repl_ignore_signal
    mov rdi, SIGTTOU
    call repl_ignore_signal

    mov rdi, r12
    call repl_clear_history

    mov rdi, r12
    lea rsi, [rel repl_welcome]
    mov rdx, repl_welcome_len
    call repl_print

    mov rax, r12
    jmp .ret
.fail:
    xor eax, eax
.ret:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; repl_print(repl_ptr, str_ptr, str_len)
repl_print:
    push rbx
    push r12
    push r13
    push r14

    test rdi, rdi
    jz .ret
    test rsi, rsi
    jz .ret
    test rdx, rdx
    jz .ret

    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    xor r14, r14

    mov rdi, rbx
    call repl_ensure_first_line

.char_loop:
    cmp r14, r13
    jae .ret
    mov al, [r12 + r14]
    cmp al, 13
    je .next_char
    cmp al, 10
    je .newline

    mov rcx, [rbx + R_WRITE_COL_OFF]
    cmp rcx, [rbx + R_SCREEN_COLS_OFF]
    jb .store
    mov rdi, rbx
    call repl_new_output_line
    xor ecx, ecx

.store:
    mov rdi, rbx
    mov rsi, [rbx + R_LINE_COUNT_OFF]
    dec rsi
    call repl_line_ptr
    add rax, rcx
    mov [rax], al
    inc qword [rbx + R_WRITE_COL_OFF]
    jmp .next_char

.newline:
    mov rdi, rbx
    call repl_new_output_line

.next_char:
    inc r14
    jmp .char_loop

.ret:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; rdi=repl, rsi=line_ptr
; rax=line strlen up to screen_cols
repl_line_len:
    xor eax, eax
.loop:
    cmp rax, [rdi + R_SCREEN_COLS_OFF]
    jae .ret
    cmp byte [rsi + rax], 0
    je .ret
    inc rax
    jmp .loop
.ret:
    ret

; repl_execute(repl_ptr)
repl_execute:
    push rbx
    push r12
    push r13

    test rdi, rdi
    jz .ret
    mov rbx, rdi

    ; process background job updates before running next command
    call jobs_update_status

    ; print entered command line: prompt + input + \n
    mov rdi, rbx
    lea rsi, [rbx + R_PROMPT_OFF]
    mov rdx, [rbx + R_PROMPT_LEN_OFF]
    call repl_print
    mov rdi, rbx
    lea rsi, [rbx + R_INPUT_BUF_OFF]
    mov rdx, [rbx + R_INPUT_LEN_OFF]
    call repl_print
    mov rdi, rbx
    lea rsi, [rel repl_newline]
    mov rdx, 1
    call repl_print

    mov r12, [rbx + R_INPUT_LEN_OFF]
    lea r13, [rbx + R_INPUT_BUF_OFF]
    cmp r12, 0
    je .clear_input

    ; keep "exit" as non-forked REPL action
    cmp r12, 4
    jne .pipeline_exec
    mov rdi, r13
    lea rsi, [rel cmd_exit]
    mov rdx, 4
    call repl_memeq
    cmp rax, 1
    jne .pipeline_exec
    mov rax, [rbx + R_WINDOW_PTR_OFF]
    mov qword [rax + WINDOW_SHOULD_CLOSE_OFF], 1
    jmp .clear_input

.pipeline_exec:
    mov rdi, [rel repl_exec_arena_ptr]
    call arena_reset

    mov rdi, [rel repl_exec_arena_ptr]
    lea rsi, [rbx + R_INPUT_BUF_OFF]
    mov rdx, [rbx + R_INPUT_LEN_OFF]
    call lexer_init
    test rax, rax
    jz .clear_input
    mov r12, rax                        ; lexer ptr

    mov rdi, r12
    call lexer_tokenize
    cmp rax, 0
    je .parse_stage
    mov rdi, r12
    call lexer_get_error
    test rax, rax
    jz .clear_input
    mov r13, rax
    mov rdi, r13
    call repl_cstrlen
    mov rdi, rbx
    mov rsi, r13
    mov rdx, rax
    call repl_print
    mov rdi, rbx
    lea rsi, [rel repl_newline]
    mov rdx, 1
    call repl_print
    jmp .clear_input

.parse_stage:
    mov rdi, [rel repl_exec_arena_ptr]
    mov rsi, r12
    call parser_init
    test rax, rax
    jz .clear_input
    mov r13, rax                        ; parser ptr

    mov rdi, r13
    call parser_parse
    test rax, rax
    jnz .exec_stage
    mov rdi, r13
    call parser_get_error
    test rax, rax
    jz .clear_input
    mov r12, rax
    mov rdi, r12
    call repl_cstrlen
    mov rdi, rbx
    mov rsi, r12
    mov rdx, rax
    call repl_print
    mov rdi, rbx
    lea rsi, [rel repl_newline]
    mov rdx, 1
    call repl_print
    jmp .clear_input

.exec_stage:
    mov r12, rax                        ; ast root
    mov rdi, [rel repl_exec_arena_ptr]
    mov rsi, [rel repl_envp_ptr]
    call executor_init
    test rax, rax
    jz .clear_input
    mov rdi, rax
    mov rsi, r12
    call executor_run

.clear_input:
    mov qword [rbx + R_INPUT_LEN_OFF], 0
    mov qword [rbx + R_INPUT_CURSOR_OFF], 0
    mov qword [rbx + R_CURSOR_VISIBLE_OFF], 1

.ret:
    pop r13
    pop r12
    pop rbx
    ret

; repl_handle_key(repl_ptr, input_event_ptr)
repl_handle_key:
    push rbx
    push r12
    push r13
    push r14

    test rdi, rdi
    jz .ret
    test rsi, rsi
    jz .ret
    mov rbx, rdi
    mov r12, rsi

    mov r13d, [r12 + INPUT_EVENT_KEY_CODE_OFF]
    mov r14d, [r12 + INPUT_EVENT_MODIFIERS_OFF]

    ; Ctrl+C / Ctrl+L
    test r14d, MOD_CTRL
    jz .no_ctrl
    cmp r13d, KEY_C
    jne .check_ctrl_l
    mov qword [rbx + R_INPUT_LEN_OFF], 0
    mov qword [rbx + R_INPUT_CURSOR_OFF], 0
    jmp .ret
.check_ctrl_l:
    cmp r13d, KEY_L
    jne .no_ctrl
    mov rdi, rbx
    call repl_clear_history
    jmp .ret

.no_ctrl:
    cmp r13d, KEY_LEFT
    jne .check_right
    cmp qword [rbx + R_INPUT_CURSOR_OFF], 0
    je .ret
    dec qword [rbx + R_INPUT_CURSOR_OFF]
    jmp .ret

.check_right:
    cmp r13d, KEY_RIGHT
    jne .check_home
    mov rax, [rbx + R_INPUT_CURSOR_OFF]
    cmp rax, [rbx + R_INPUT_LEN_OFF]
    jae .ret
    inc qword [rbx + R_INPUT_CURSOR_OFF]
    jmp .ret

.check_home:
    cmp r13d, KEY_HOME
    jne .check_end
    mov qword [rbx + R_INPUT_CURSOR_OFF], 0
    jmp .ret

.check_end:
    cmp r13d, KEY_END
    jne .check_delete
    mov rax, [rbx + R_INPUT_LEN_OFF]
    mov [rbx + R_INPUT_CURSOR_OFF], rax
    jmp .ret

.check_delete:
    cmp r13d, KEY_DELETE
    jne .map_ascii
    mov rax, [rbx + R_INPUT_CURSOR_OFF]
    cmp rax, [rbx + R_INPUT_LEN_OFF]
    jae .ret
.del_shift:
    mov rcx, rax
    inc rcx
    cmp rcx, [rbx + R_INPUT_LEN_OFF]
    jae .del_done
    mov dl, [rbx + R_INPUT_BUF_OFF + rcx]
    mov [rbx + R_INPUT_BUF_OFF + rax], dl
    inc rax
    jmp .del_shift
.del_done:
    dec qword [rbx + R_INPUT_LEN_OFF]
    mov rax, [rbx + R_INPUT_LEN_OFF]
    mov byte [rbx + R_INPUT_BUF_OFF + rax], 0
    jmp .ret

.map_ascii:
    mov edi, r13d
    mov esi, r14d
    call wayland_keycode_to_ascii
    test al, al
    jz .ret

    cmp al, 10                          ; Enter
    jne .check_backspace
    mov rdi, rbx
    call repl_execute
    jmp .ret

.check_backspace:
    cmp al, 8
    jne .check_printable
    cmp qword [rbx + R_INPUT_CURSOR_OFF], 0
    je .ret
    dec qword [rbx + R_INPUT_CURSOR_OFF]
    mov rax, [rbx + R_INPUT_CURSOR_OFF]
.bs_shift:
    mov rcx, rax
    inc rcx
    cmp rcx, [rbx + R_INPUT_LEN_OFF]
    jae .bs_done
    mov dl, [rbx + R_INPUT_BUF_OFF + rcx]
    mov [rbx + R_INPUT_BUF_OFF + rax], dl
    inc rax
    jmp .bs_shift
.bs_done:
    dec qword [rbx + R_INPUT_LEN_OFF]
    mov rax, [rbx + R_INPUT_LEN_OFF]
    mov byte [rbx + R_INPUT_BUF_OFF + rax], 0
    jmp .ret

.check_printable:
    cmp al, 32
    jb .ret
    cmp al, 126
    ja .ret
    mov rcx, [rbx + R_INPUT_LEN_OFF]
    cmp rcx, INPUT_BUF_CAP - 1
    jae .ret
    mov rdx, [rbx + R_INPUT_CURSOR_OFF]
    mov r10b, al
    cmp rdx, rcx
    jae .insert_tail
.shift_right:
    cmp rcx, rdx
    jbe .insert_done
    mov r9, rcx
    dec r9
    mov al, [rbx + R_INPUT_BUF_OFF + r9]
    mov [rbx + R_INPUT_BUF_OFF + rcx], al
    dec rcx
    cmp rcx, rdx
    jae .shift_right
.insert_done:
.insert_tail:
    mov [rbx + R_INPUT_BUF_OFF + rdx], r10b
    inc qword [rbx + R_INPUT_CURSOR_OFF]
    inc qword [rbx + R_INPUT_LEN_OFF]
    mov rax, [rbx + R_INPUT_LEN_OFF]
    mov byte [rbx + R_INPUT_BUF_OFF + rax], 0

.ret:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; repl_render(repl_ptr)
repl_render:
    push rbx
    push r12
    push r13
    push r14
    push r15

    test rdi, rdi
    jz .ret
    mov rbx, rdi
    mov r12, [rbx + R_CANVAS_PTR_OFF]
    test r12, r12
    jz .ret

    ; clear background
    mov rdi, r12
    mov rsi, COLOR_BG
    call canvas_clear

    ; history rows = screen_lines - 1
    mov r13, [rbx + R_SCREEN_LINES_OFF]
    cmp r13, 1
    jbe .draw_input
    dec r13

    ; start_abs = max(0, line_count - history_rows - scroll_offset)
    mov r14, [rbx + R_LINE_COUNT_OFF]
    mov rax, [rbx + R_SCROLL_OFFSET_OFF]
    cmp r14, r13
    jbe .start_zero
    sub r14, r13
    cmp r14, rax
    jbe .start_zero
    sub r14, rax
    jmp .start_ready
.start_zero:
    xor r14d, r14d
.start_ready:
    xor r15d, r15d                    ; row index

.hist_loop:
    cmp r15, r13
    jae .draw_input
    mov rdx, r14
    add rdx, r15
    cmp rdx, [rbx + R_LINE_COUNT_OFF]
    jae .draw_input

    mov rdi, rbx
    mov rsi, rdx
    call repl_line_ptr
    mov rcx, rax                      ; line_ptr
    mov rdi, rbx
    mov rsi, rcx
    call repl_line_len
    test rax, rax
    jz .next_hist

    ; draw_string(canvas, x=0, y=row*font_h, line_ptr, len, fg, bg=0)
    mov rsi, 0
    mov rdx, r15
    imul rdx, [rel font_char_height]
    mov r8, rax
    mov rcx, r14
    add rcx, r15
    mov rdi, rbx
    mov rsi, rcx
    call repl_line_ptr
    mov rcx, rax
    mov rdi, r12
    mov rsi, 0
    mov rdx, r15
    imul rdx, [rel font_char_height]
    mov r9, COLOR_FG
    sub rsp, 8
    mov qword [rsp], 0
    call canvas_draw_string
    add rsp, 8

.next_hist:
    inc r15
    jmp .hist_loop

.draw_input:
    ; y = (screen_lines - 1) * font_char_height
    mov r15, [rbx + R_SCREEN_LINES_OFF]
    dec r15
    imul r15, [rel font_char_height]

    ; draw prompt
    mov rdi, r12
    mov rsi, 0
    mov rdx, r15
    lea rcx, [rbx + R_PROMPT_OFF]
    mov r8, [rbx + R_PROMPT_LEN_OFF]
    mov r9, COLOR_PROMPT
    sub rsp, 8
    mov qword [rsp], 0
    call canvas_draw_string
    add rsp, 8

    ; draw current input
    mov rax, [rbx + R_PROMPT_LEN_OFF]
    imul rax, [rel font_char_width]
    mov rdi, r12
    mov rsi, rax
    mov rdx, r15
    lea rcx, [rbx + R_INPUT_BUF_OFF]
    mov r8, [rbx + R_INPUT_LEN_OFF]
    mov r9, COLOR_FG
    sub rsp, 8
    mov qword [rsp], 0
    call canvas_draw_string
    add rsp, 8

    ; cursor
    cmp qword [rbx + R_CURSOR_VISIBLE_OFF], 0
    je .present
    mov rax, [rbx + R_PROMPT_LEN_OFF]
    add rax, [rbx + R_INPUT_CURSOR_OFF]
    imul rax, [rel font_char_width]
    mov rdi, r12
    mov rsi, rax
    mov rdx, r15
    mov rcx, 2
    mov r8, [rel font_char_height]
    mov r9, COLOR_CURSOR
    call canvas_fill_rect

.present:
    mov rdi, [rbx + R_WINDOW_PTR_OFF]
    call window_present

.ret:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; repl_cursor_blink(fd, events, user_data)
; callback-compatible shape
repl_cursor_blink:
    test rdx, rdx
    jz .ret
    mov rax, [rdx + R_CURSOR_VISIBLE_OFF]
    xor rax, 1
    mov [rdx + R_CURSOR_VISIBLE_OFF], rax
    mov rdi, rdx
    call repl_render
.ret:
    ret
