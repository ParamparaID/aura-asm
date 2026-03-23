; decorations.asm — server-side window decorations (MVP)
%include "src/compositor/compositor.inc"
%include "src/compositor/wm.inc"
%include "src/gui/theme.inc"

extern canvas_fill_rect
extern canvas_draw_rect
extern proto_send_event
extern floating_start_drag
extern floating_start_resize

%define DECO_MAX                      128
%define TITLE_TARGET_MIN              44

%define DECO_HIT_NONE                 0
%define DECO_HIT_CLOSE                1
%define DECO_HIT_MAXIMIZE             2
%define DECO_HIT_MINIMIZE             3
%define DECO_HIT_TITLEBAR             4
%define DECO_HIT_CLIENT               5
%define DECO_HIT_BORDER_LEFT          6
%define DECO_HIT_BORDER_RIGHT         7
%define DECO_HIT_BORDER_TOP           8
%define DECO_HIT_BORDER_BOTTOM        9
%define DECO_HIT_BORDER_TL            10
%define DECO_HIT_BORDER_TR            11
%define DECO_HIT_BORDER_BL            12
%define DECO_HIT_BORDER_BR            13

; WindowDecoration
%define DC_SURFACE_OFF                0
%define DC_TITLE_H_OFF                8
%define DC_BORDER_W_OFF               12
%define DC_CORNER_R_OFF               16
%define DC_CLOSE_X_OFF                20
%define DC_CLOSE_Y_OFF                24
%define DC_CLOSE_W_OFF                28
%define DC_CLOSE_H_OFF                32
%define DC_MAX_X_OFF                  36
%define DC_MAX_Y_OFF                  40
%define DC_MIN_X_OFF                  44
%define DC_MIN_Y_OFF                  48
%define DC_HOVERED_BTN_OFF            52
%define DC_PRESSED_BTN_OFF            56
%define DC_BG_COLOR_OFF               60
%define DC_FG_COLOR_OFF               64
%define DC_CLOSE_COLOR_OFF            68
%define DC_STRUCT_SIZE                72

%define INPUT_EVENT_TYPE_OFF          0
%define INPUT_EVENT_KEY_CODE_OFF      16
%define INPUT_EVENT_KEY_STATE_OFF     20
%define INPUT_EVENT_MOUSE_X_OFF       28
%define INPUT_EVENT_MOUSE_Y_OFF       32
%define INPUT_TOUCH_DOWN              4
%define INPUT_TOUCH_UP                5
%define INPUT_MOUSE_BUTTON            3
%define KEY_PRESSED                   1
%define BTN_LEFT                      272

section .bss
    deco_pool                         resb DECO_MAX * DC_STRUCT_SIZE
    deco_used                         resd DECO_MAX

section .text
global decoration_init
global decoration_render
global decoration_hit_test
global decoration_handle_input
global decoration_render_surface

deco_find_by_surface:
    xor ecx, ecx
.loop:
    cmp ecx, DECO_MAX
    jae .none
    cmp dword [rel deco_used + ecx*4], 0
    je .next
    mov eax, ecx
    imul eax, DC_STRUCT_SIZE
    lea rax, [rel deco_pool + rax]
    cmp [rax + DC_SURFACE_OFF], rdi
    je .out
.next:
    inc ecx
    jmp .loop
.none:
    xor eax, eax
.out:
    ret

deco_alloc:
    xor ecx, ecx
.loop:
    cmp ecx, DECO_MAX
    jae .none
    cmp dword [rel deco_used + ecx*4], 0
    je .found
    inc ecx
    jmp .loop
.found:
    mov dword [rel deco_used + ecx*4], 1
    mov eax, ecx
    imul eax, DC_STRUCT_SIZE
    lea rax, [rel deco_pool + rax]
    ret
.none:
    xor eax, eax
    ret

; decoration_init(surface, theme) -> rax WindowDecoration*
decoration_init:
    push rbx
    mov rbx, rsi
    test rdi, rdi
    jz .none
    call deco_find_by_surface
    test rax, rax
    jnz .ret
    call deco_alloc
    test rax, rax
    jz .none
    mov [rax + DC_SURFACE_OFF], rdi
    mov dword [rax + DC_TITLE_H_OFF], 32
    mov dword [rax + DC_BORDER_W_OFF], 2
    mov dword [rax + DC_CORNER_R_OFF], 12
    mov dword [rax + DC_HOVERED_BTN_OFF], 0
    mov dword [rax + DC_PRESSED_BTN_OFF], 0
    mov dword [rax + DC_BG_COLOR_OFF], 0xCC1F2433
    mov dword [rax + DC_FG_COLOR_OFF], 0xFFE6EAF2
    mov dword [rax + DC_CLOSE_COLOR_OFF], 0xFFE06C75
    test rbx, rbx
    jz .ret
    mov ecx, [rbx + T_SURFACE_OFF]
    mov [rax + DC_BG_COLOR_OFF], ecx
    mov ecx, [rbx + T_FG_OFF]
    mov [rax + DC_FG_COLOR_OFF], ecx
    mov ecx, [rbx + T_ERROR_OFF]
    mov [rax + DC_CLOSE_COLOR_OFF], ecx
    mov ecx, [rbx + T_CORNER_RADIUS_OFF]
    mov [rax + DC_CORNER_R_OFF], ecx
.ret:
    pop rbx
    ret
.none:
    xor eax, eax
    pop rbx
    ret

; decoration_render(decor, canvas, theme, focused)
decoration_render:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r14d, ecx
    test rbx, rbx
    jz .out
    test r12, r12
    jz .out
    mov r15, [rbx + DC_SURFACE_OFF]
    test r15, r15
    jz .out

    ; Update colors from theme if provided.
    test r13, r13
    jz .geo
    mov eax, [r13 + T_SURFACE_OFF]
    mov [rbx + DC_BG_COLOR_OFF], eax
    mov eax, [r13 + T_FG_OFF]
    mov [rbx + DC_FG_COLOR_OFF], eax
    mov eax, [r13 + T_ERROR_OFF]
    mov [rbx + DC_CLOSE_COLOR_OFF], eax
.geo:
    mov eax, [r15 + SF_SCREEN_X_OFF]
    sub eax, [rbx + DC_BORDER_W_OFF]
    mov r8d, eax                      ; deco_x
    mov eax, [r15 + SF_SCREEN_Y_OFF]
    sub eax, [rbx + DC_TITLE_H_OFF]
    sub eax, [rbx + DC_BORDER_W_OFF]
    mov r9d, eax                      ; deco_y
    mov eax, [r15 + SF_WIDTH_OFF]
    add eax, [rbx + DC_BORDER_W_OFF]
    add eax, [rbx + DC_BORDER_W_OFF]
    mov r10d, eax                     ; deco_w
    mov eax, [r15 + SF_HEIGHT_OFF]
    add eax, [rbx + DC_TITLE_H_OFF]
    add eax, [rbx + DC_BORDER_W_OFF]
    add eax, [rbx + DC_BORDER_W_OFF]
    mov r11d, eax                     ; deco_h

    ; Border shell.
    mov rdi, r12
    mov esi, r8d
    mov edx, r9d
    mov ecx, r10d
    mov r8d, r11d
    mov r9d, 0xFF2C344A
    call canvas_fill_rect

    ; Glass-like title bar approximation (semi-opaque fill).
    mov rdi, r12
    mov esi, r8d
    mov edx, r9d
    mov ecx, r10d
    mov r8d, [rbx + DC_TITLE_H_OFF]
    add r8d, [rbx + DC_BORDER_W_OFF]
    mov r9d, [rbx + DC_BG_COLOR_OFF]
    call canvas_fill_rect

    ; Client area frame.
    mov rdi, r12
    mov esi, r8d
    mov edx, r9d
    mov ecx, r10d
    mov r8d, r11d
    test r14d, r14d
    jz .border_unfocused
    mov r9d, 0xFF7AA2F7
    jmp .border_draw
.border_unfocused:
    mov r9d, 0xFF5A6072
.border_draw:
    call canvas_draw_rect

.buttons:
    ; 44x44 touch target; visual glyph inside.
    mov eax, r8d
    add eax, r10d
    sub eax, 44
    mov [rbx + DC_CLOSE_X_OFF], eax
    mov [rbx + DC_CLOSE_Y_OFF], r9d
    mov dword [rbx + DC_CLOSE_W_OFF], TITLE_TARGET_MIN
    mov dword [rbx + DC_CLOSE_H_OFF], TITLE_TARGET_MIN
    mov ecx, eax
    sub ecx, 44
    mov [rbx + DC_MAX_X_OFF], ecx
    mov [rbx + DC_MAX_Y_OFF], r9d
    sub ecx, 44
    mov [rbx + DC_MIN_X_OFF], ecx
    mov [rbx + DC_MIN_Y_OFF], r9d

    ; close button
    mov rdi, r12
    mov esi, [rbx + DC_CLOSE_X_OFF]
    add esi, 14
    mov edx, [rbx + DC_CLOSE_Y_OFF]
    add edx, 14
    mov ecx, 16
    mov r8d, 16
    mov r9d, [rbx + DC_CLOSE_COLOR_OFF]
    call canvas_fill_rect
    ; maximize button
    mov rdi, r12
    mov esi, [rbx + DC_MAX_X_OFF]
    add esi, 14
    mov edx, [rbx + DC_MAX_Y_OFF]
    add edx, 14
    mov ecx, 16
    mov r8d, 16
    mov r9d, 0xFF98C379
    call canvas_fill_rect
    ; minimize button
    mov rdi, r12
    mov esi, [rbx + DC_MIN_X_OFF]
    add esi, 14
    mov edx, [rbx + DC_MIN_Y_OFF]
    add edx, 20
    mov ecx, 16
    mov r8d, 4
    mov r9d, 0xFFE5C07B
    call canvas_fill_rect

.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; decoration_hit_test(decor, x, y) -> eax hit code
decoration_hit_test:
    push rbx
    push r12
    mov rbx, rdi
    mov r12d, esi
    mov r11d, edx
    test rbx, rbx
    jz .none
    mov rax, [rbx + DC_SURFACE_OFF]
    test rax, rax
    jz .none

    mov r8d, [rax + SF_SCREEN_X_OFF]
    sub r8d, [rbx + DC_BORDER_W_OFF]    ; deco_x
    mov r9d, [rax + SF_SCREEN_Y_OFF]
    sub r9d, [rbx + DC_TITLE_H_OFF]
    sub r9d, [rbx + DC_BORDER_W_OFF]    ; deco_y
    mov r10d, [rax + SF_WIDTH_OFF]
    add r10d, [rbx + DC_BORDER_W_OFF]
    add r10d, [rbx + DC_BORDER_W_OFF]   ; deco_w
    mov ecx, [rax + SF_HEIGHT_OFF]
    add ecx, [rbx + DC_TITLE_H_OFF]
    add ecx, [rbx + DC_BORDER_W_OFF]
    add ecx, [rbx + DC_BORDER_W_OFF]    ; deco_h

    ; outside full window
    cmp r12d, r8d
    jl .none
    mov edx, r8d
    add edx, r10d
    cmp r12d, edx
    jge .none
    cmp r11d, r9d
    jl .none
    mov edx, r9d
    add edx, ecx
    cmp r11d, edx
    jge .none

    ; buttons
    mov edx, [rbx + DC_CLOSE_X_OFF]
    cmp r12d, edx
    jl .max_btn
    mov eax, [rbx + DC_CLOSE_W_OFF]
    add eax, edx
    cmp r12d, eax
    jg .max_btn
    mov edx, [rbx + DC_CLOSE_Y_OFF]
    cmp r11d, edx
    jl .max_btn
    mov eax, [rbx + DC_CLOSE_H_OFF]
    add eax, edx
    cmp r11d, eax
    jg .max_btn
    mov eax, DECO_HIT_CLOSE
    jmp .out
.max_btn:
    mov edx, [rbx + DC_MAX_X_OFF]
    cmp r12d, edx
    jl .min_btn
    lea eax, [edx + TITLE_TARGET_MIN]
    cmp r12d, eax
    jg .min_btn
    mov edx, [rbx + DC_MAX_Y_OFF]
    cmp r11d, edx
    jl .min_btn
    lea eax, [edx + TITLE_TARGET_MIN]
    cmp r11d, eax
    jg .min_btn
    mov eax, DECO_HIT_MAXIMIZE
    jmp .out
.min_btn:
    mov edx, [rbx + DC_MIN_X_OFF]
    cmp r12d, edx
    jl .title_or_border
    lea eax, [edx + TITLE_TARGET_MIN]
    cmp r12d, eax
    jg .title_or_border
    mov edx, [rbx + DC_MIN_Y_OFF]
    cmp r11d, edx
    jl .title_or_border
    lea eax, [edx + TITLE_TARGET_MIN]
    cmp r11d, eax
    jg .title_or_border
    mov eax, DECO_HIT_MINIMIZE
    jmp .out

.title_or_border:
    ; edges
    mov edx, [rbx + DC_BORDER_W_OFF]
    mov eax, r8d
    add eax, edx
    cmp r12d, eax
    jl .left_edge
    mov eax, r8d
    add eax, r10d
    sub eax, edx
    cmp r12d, eax
    jge .right_edge
    mov eax, r9d
    add eax, edx
    cmp r11d, eax
    jl .top_edge
    mov eax, r9d
    add eax, ecx
    sub eax, edx
    cmp r11d, eax
    jge .bottom_edge
    jmp .title_or_client

.left_edge:
    mov eax, DECO_HIT_BORDER_LEFT
    jmp .out
.right_edge:
    mov eax, DECO_HIT_BORDER_RIGHT
    jmp .out
.top_edge:
    mov eax, DECO_HIT_BORDER_TOP
    jmp .out
.bottom_edge:
    mov eax, DECO_HIT_BORDER_BOTTOM
    jmp .out

.title_or_client:
    mov edx, r9d
    add edx, [rbx + DC_TITLE_H_OFF]
    add edx, [rbx + DC_BORDER_W_OFF]
    cmp r11d, edx
    jl .titlebar
    mov eax, DECO_HIT_CLIENT
    jmp .out
.titlebar:
    mov eax, DECO_HIT_TITLEBAR
    jmp .out

.none:
    xor eax, eax
.out:
    pop r12
    pop rbx
    ret

decoration_send_close:
    ; rdi = Surface*
    push rbx
    mov rbx, [rdi + SF_CLIENT_OFF]
    test rbx, rbx
    jz .out
    mov esi, [rdi + SF_XDG_TOP_ID_OFF]
    test esi, esi
    jz .out
    mov rdi, rbx
    mov edx, 1                         ; xdg_toplevel.close
    xor ecx, ecx
    xor r8d, r8d
    call proto_send_event
.out:
    pop rbx
    ret

; decoration_handle_input(decor, wm, event) -> eax handled
decoration_handle_input:
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    test rbx, rbx
    jz .no
    test r12, r12
    jz .no
    test r13, r13
    jz .no

    mov esi, [r13 + INPUT_EVENT_MOUSE_X_OFF]
    mov edx, [r13 + INPUT_EVENT_MOUSE_Y_OFF]
    mov rdi, rbx
    call decoration_hit_test
    mov ecx, eax
    mov [rbx + DC_HOVERED_BTN_OFF], ecx

    mov eax, [r13 + INPUT_EVENT_TYPE_OFF]
    cmp eax, INPUT_MOUSE_BUTTON
    je .mouse
    cmp eax, INPUT_TOUCH_DOWN
    je .touch_press
    cmp eax, INPUT_TOUCH_UP
    je .touch_release
    jmp .no

.mouse:
    cmp dword [r13 + INPUT_EVENT_KEY_CODE_OFF], BTN_LEFT
    jne .no
    cmp dword [r13 + INPUT_EVENT_KEY_STATE_OFF], KEY_PRESSED
    jne .release
    mov [rbx + DC_PRESSED_BTN_OFF], ecx
    jmp .act
.release:
    mov dword [rbx + DC_PRESSED_BTN_OFF], 0
    xor eax, eax
    jmp .out

.touch_press:
    mov [rbx + DC_PRESSED_BTN_OFF], ecx
    jmp .act
.touch_release:
    mov dword [rbx + DC_PRESSED_BTN_OFF], 0
    xor eax, eax
    jmp .out

.act:
    mov rax, [rbx + DC_SURFACE_OFF]
    test rax, rax
    jz .no
    cmp ecx, DECO_HIT_CLOSE
    jne .chk_max
    mov rdi, rax
    call decoration_send_close
    mov dword [rax + SF_MAPPED_OFF], 0
    mov eax, 1
    jmp .out
.chk_max:
    cmp ecx, DECO_HIT_MAXIMIZE
    jne .chk_min
    mov edx, [r12 + WM_OUTPUT_W_OFF]
    cmp [rax + SF_WIDTH_OFF], edx
    jne .to_full
    mov dword [rax + SF_WIDTH_OFF], 640
    mov dword [rax + SF_HEIGHT_OFF], 480
    mov eax, 1
    jmp .out
.to_full:
    mov edx, [r12 + WM_OUTPUT_X_OFF]
    mov [rax + SF_SCREEN_X_OFF], edx
    mov edx, [r12 + WM_OUTPUT_Y_OFF]
    mov [rax + SF_SCREEN_Y_OFF], edx
    mov edx, [r12 + WM_OUTPUT_W_OFF]
    mov [rax + SF_WIDTH_OFF], edx
    mov edx, [r12 + WM_OUTPUT_H_OFF]
    mov [rax + SF_HEIGHT_OFF], edx
    mov eax, 1
    jmp .out
.chk_min:
    cmp ecx, DECO_HIT_MINIMIZE
    jne .chk_title
    mov dword [rax + SF_MAPPED_OFF], 0
    mov eax, 1
    jmp .out
.chk_title:
    cmp ecx, DECO_HIT_TITLEBAR
    jne .chk_border
    mov rdi, r12
    mov rsi, rax
    mov edx, [r13 + INPUT_EVENT_MOUSE_X_OFF]
    mov ecx, [r13 + INPUT_EVENT_MOUSE_Y_OFF]
    call floating_start_drag
    mov eax, 1
    jmp .out
.chk_border:
    ; map edge hit to WM_EDGE_* then start resize
    mov edx, WM_EDGE_NONE
    cmp ecx, DECO_HIT_BORDER_LEFT
    jne .rb
    mov edx, WM_EDGE_LEFT
    jmp .start_resize
.rb:
    cmp ecx, DECO_HIT_BORDER_RIGHT
    jne .tb
    mov edx, WM_EDGE_RIGHT
    jmp .start_resize
.tb:
    cmp ecx, DECO_HIT_BORDER_TOP
    jne .bb
    mov edx, WM_EDGE_TOP
    jmp .start_resize
.bb:
    cmp ecx, DECO_HIT_BORDER_BOTTOM
    jne .no
    mov edx, WM_EDGE_BOTTOM
.start_resize:
    mov rdi, r12
    mov rsi, rax
    mov ecx, [r13 + INPUT_EVENT_MOUSE_X_OFF]
    mov r8d, [r13 + INPUT_EVENT_MOUSE_Y_OFF]
    call floating_start_resize
    mov eax, 1
    jmp .out

.no:
    xor eax, eax
.out:
    pop r13
    pop r12
    pop rbx
    ret

; decoration_render_surface(surface, canvas, theme, focused)
decoration_render_surface:
    push rbx
    push r12
    push r13
    mov rbx, rsi
    mov r12, rdx
    mov r13d, ecx
    mov rsi, rdx
    call decoration_init
    test rax, rax
    jz .out
    mov rdi, rax
    mov rsi, rbx
    mov rdx, r12
    mov ecx, r13d
    call decoration_render
.out:
    pop r13
    pop r12
    pop rbx
    ret
