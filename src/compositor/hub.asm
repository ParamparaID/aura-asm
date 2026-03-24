; hub.asm — home screen (Hub) for Aura Shell compositor
%include "src/hal/linux_x86_64/defs.inc"
%include "src/compositor/workspaces.inc"
%include "src/gui/theme.inc"

extern hal_clock_gettime
extern canvas_fill_rect
extern canvas_draw_rect
extern canvas_draw_string
extern canvas_push_clip
extern canvas_pop_clip
extern spring_init
extern spring_update
extern spring_value
extern workspaces_switch
extern workspaces_get_manager

%define INPUT_EVENT_TYPE_OFF         0
%define INPUT_EVENT_MOUSE_X_OFF      28
%define INPUT_EVENT_MOUSE_Y_OFF      32
%define INPUT_EVENT_TOUCH_ID_OFF     44
%define INPUT_TOUCH_DOWN             4
%define INPUT_TOUCH_UP               5
%define INPUT_TOUCH_MOVE             6

%define FP_ONE                       0x00010000
%define FP_DT_60                     1092
%define HUB_SPRING_STIFF             0x00022000
%define HUB_SPRING_DAMP              0x00010000

section .rodata
    hub_clock_prefix                db "Hub ", 0
    hub_clock_prefix_len            equ $ - hub_clock_prefix - 1
    hub_fm_title                    db "Files", 0
    hub_fm_hint                     db "Tap: Home  Tap right: /tmp", 0
    hub_fm_path_home                db "/", 0
    hub_fm_path_tmp                 db "/tmp", 0

section .bss
    hub_global                      resb HUB_STRUCT_SIZE
    hub_theme_ptr                   resq 1
    hub_transition_spring           resb 28
    hub_drag_touch_id               resd 1
    hub_drag_last_y                 resd 1
    hub_drag_last_dy                resd 1
    hub_drag_active                 resd 1
    hub_clock_buf                   resb 32
    hub_clock_len                   resd 1
    hub_fm_req_pending              resd 1
    hub_fm_req_path                 resb 256

section .text
global hub_get_global
global hub_init
global hub_render
global hub_handle_input
global hub_toggle
global hub_take_fm_request

hub_get_global:
    lea rax, [rel hub_global]
    ret

; hub_take_fm_request(path_out, out_cap) -> eax len, 0 if none
hub_take_fm_request:
    cmp dword [rel hub_fm_req_pending], 0
    jne .have
    xor eax, eax
    ret
.have:
    push rbx
    mov rbx, rdi
    xor ecx, ecx
.copy:
    cmp ecx, esi
    jae .term
    mov al, [rel hub_fm_req_path + rcx]
    mov [rbx + rcx], al
    test al, al
    jz .done
    inc ecx
    jmp .copy
.term:
    mov byte [rbx + rcx], 0
.done:
    mov dword [rel hub_fm_req_pending], 0
    mov eax, ecx
    pop rbx
    ret

hub_write_2digits:
    ; rdi=dst, esi=value [0..99]
    mov eax, esi
    xor edx, edx
    mov ecx, 10
    div ecx
    add al, '0'
    mov [rdi], al
    add dl, '0'
    mov [rdi + 1], dl
    ret

hub_update_clock:
    push rbx
    push r12
    sub rsp, 16
    mov rdi, CLOCK_REALTIME
    mov rsi, rsp
    call hal_clock_gettime
    test rax, rax
    js .fallback
    mov rax, [rsp]
    xor edx, edx
    mov ecx, 86400
    div rcx
    mov eax, edx
    xor edx, edx
    mov ecx, 3600
    div ecx
    mov ebx, eax                      ; hour
    mov eax, edx
    xor edx, edx
    mov ecx, 60
    div ecx
    mov r12d, eax                     ; minute
    mov ecx, edx                      ; second
    lea rdi, [rel hub_clock_buf]
    lea rsi, [rel hub_clock_prefix]
    mov eax, [rsi]
    mov [rdi], eax
    mov byte [rdi + 4], ' '
    lea rdi, [rel hub_clock_buf + 5]
    mov esi, ebx
    call hub_write_2digits
    mov byte [rel hub_clock_buf + 7], ':'
    lea rdi, [rel hub_clock_buf + 8]
    mov esi, r12d
    call hub_write_2digits
    mov byte [rel hub_clock_buf + 10], ':'
    lea rdi, [rel hub_clock_buf + 11]
    mov esi, ecx
    call hub_write_2digits
    mov byte [rel hub_clock_buf + 13], 0
    mov dword [rel hub_clock_len], 13
    jmp .out
.fallback:
    mov dword [rel hub_clock_len], 4
    mov dword [rel hub_clock_buf], 'Hub '
.out:
    add rsp, 16
    pop r12
    pop rbx
    ret

; hub_init(theme) -> rax Hub*
hub_init:
    push rdi
    lea rdi, [rel hub_global]
    mov ecx, HUB_STRUCT_SIZE / 8
    xor eax, eax
    rep stosq
    pop rdi
    mov [rel hub_theme_ptr], rdi
    mov dword [rel hub_global + HUB_WIDGET_COUNT_OFF], 2
    mov dword [rel hub_global + HUB_SCROLL_Y_OFF], 0
    mov dword [rel hub_global + HUB_CANVAS_HEIGHT_OFF], 1600
    mov dword [rel hub_global + HUB_ACTIVE_OFF], 0
    mov dword [rel hub_drag_touch_id], -1
    mov dword [rel hub_drag_active], 0
    lea rdi, [rel hub_transition_spring]
    xor esi, esi
    xor edx, edx
    mov ecx, HUB_SPRING_STIFF
    mov r8d, HUB_SPRING_DAMP
    call spring_init
    call hub_update_clock
    lea rax, [rel hub_global]
    ret

; hub_render(hub, canvas, theme)
hub_render:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    test rbx, rbx
    jz .out
    test r12, r12
    jz .out
    cmp dword [rbx + HUB_ACTIVE_OFF], 0
    je .out
    test r13, r13
    jnz .have_theme
    mov r13, [rel hub_theme_ptr]
    test r13, r13
    jz .out
.have_theme:
    lea rdi, [rel hub_transition_spring]
    mov esi, FP_DT_60
    call spring_update
    call hub_update_clock

    mov eax, dword [rbx + HUB_SCROLL_Y_OFF]
    mov r14d, eax
    mov rdi, r12
    xor esi, esi
    xor edx, edx
    mov ecx, 0x7FFFFFFF
    mov r8d, 0x7FFFFFFF
    call canvas_push_clip

    ; hub background
    mov rdi, r12
    xor esi, esi
    xor edx, edx
    mov ecx, 0x7FFF
    mov r8d, 0x7FFF
    mov r9d, [r13 + T_BG_OFF]
    call canvas_fill_rect

    ; clock widget card
    mov rdi, r12
    mov esi, 40
    mov edx, 40
    sub edx, r14d
    mov ecx, 560
    mov r8d, 120
    mov r9d, [r13 + T_SURFACE_OFF]
    call canvas_fill_rect
    mov rdi, r12
    mov esi, 40
    mov edx, 40
    sub edx, r14d
    mov ecx, 560
    mov r8d, 120
    mov r9d, [r13 + T_ACCENT_OFF]
    call canvas_draw_rect
    mov rdi, r12
    mov esi, 56
    mov edx, 90
    sub edx, r14d
    lea rcx, [rel hub_clock_buf]
    mov r8d, [rel hub_clock_len]
    mov r9d, [r13 + T_FG_OFF]
    push qword 0
    call canvas_draw_string
    add rsp, 8

    ; workspace previews strip
    call workspaces_get_manager
    test rax, rax
    jz .pop_clip
    mov r15, rax
    xor r10d, r10d
.preview_loop:
    cmp r10d, dword [r15 + WSM_COUNT_OFF]
    jae .pop_clip
    mov eax, r10d
    imul eax, 140
    add eax, 40
    mov esi, eax
    mov edx, 220
    sub edx, r14d
    mov rdi, r12
    mov ecx, 120
    mov r8d, 90
    mov r9d, [r13 + T_SURFACE_OFF]
    call canvas_fill_rect
    mov eax, [r15 + WSM_ACTIVE_IDX_OFF]
    cmp eax, r10d
    jne .preview_border
    mov r9d, [r13 + T_ACCENT_OFF]
    jmp .draw_preview_border
.preview_border:
    mov r9d, [r13 + T_BORDER_COLOR_OFF]
.draw_preview_border:
    mov rdi, r12
    mov eax, r10d
    imul eax, 140
    add eax, 40
    mov esi, eax
    mov edx, 220
    sub edx, r14d
    mov ecx, 120
    mov r8d, 90
    call canvas_draw_rect
    inc r10d
    jmp .preview_loop

.pop_clip:
    ; Files quick card
    mov rdi, r12
    mov esi, 40
    mov edx, 380
    sub edx, r14d
    mov ecx, 560
    mov r8d, 96
    mov r9d, [r13 + T_SURFACE_OFF]
    call canvas_fill_rect
    mov rdi, r12
    mov esi, 40
    mov edx, 380
    sub edx, r14d
    mov ecx, 560
    mov r8d, 96
    mov r9d, [r13 + T_ACCENT_OFF]
    call canvas_draw_rect
    mov rdi, r12
    mov esi, 56
    mov edx, 412
    sub edx, r14d
    lea rcx, [rel hub_fm_title]
    mov r8d, 5
    mov r9d, [r13 + T_FG_OFF]
    push qword 0
    call canvas_draw_string
    add rsp, 8
    mov rdi, r12
    mov esi, 56
    mov edx, 444
    sub edx, r14d
    lea rcx, [rel hub_fm_hint]
    mov r8d, 25
    mov r9d, [r13 + T_FG_OFF]
    push qword 0
    call canvas_draw_string
    add rsp, 8

    mov rdi, r12
    call canvas_pop_clip
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; hub_handle_input(hub, event) -> eax handled
hub_handle_input:
    push rbx
    push r12
    mov rbx, rdi
    mov r12, rsi
    test rbx, rbx
    jz .no
    test r12, r12
    jz .no
    cmp dword [rbx + HUB_ACTIVE_OFF], 0
    je .no

    mov eax, [r12 + INPUT_EVENT_TYPE_OFF]
    cmp eax, INPUT_TOUCH_DOWN
    je .down
    cmp eax, INPUT_TOUCH_MOVE
    je .move
    cmp eax, INPUT_TOUCH_UP
    je .up
    jmp .no

.down:
    mov eax, [r12 + INPUT_EVENT_TOUCH_ID_OFF]
    mov [rel hub_drag_touch_id], eax
    mov eax, [r12 + INPUT_EVENT_MOUSE_Y_OFF]
    mov [rel hub_drag_last_y], eax
    mov dword [rel hub_drag_last_dy], 0
    mov dword [rel hub_drag_active], 1
    mov eax, 1
    jmp .out

.move:
    cmp dword [rel hub_drag_active], 0
    je .no
    mov eax, [r12 + INPUT_EVENT_TOUCH_ID_OFF]
    cmp eax, [rel hub_drag_touch_id]
    jne .no
    mov ecx, [r12 + INPUT_EVENT_MOUSE_Y_OFF]
    mov edx, [rel hub_drag_last_y]
    sub ecx, edx
    mov [rel hub_drag_last_dy], ecx
    mov eax, [r12 + INPUT_EVENT_MOUSE_Y_OFF]
    mov [rel hub_drag_last_y], eax
    sub dword [rbx + HUB_SCROLL_Y_OFF], ecx
    cmp dword [rbx + HUB_SCROLL_Y_OFF], 0
    jge .bound_hi
    mov dword [rbx + HUB_SCROLL_Y_OFF], 0
    jmp .moved
.bound_hi:
    mov eax, [rbx + HUB_CANVAS_HEIGHT_OFF]
    sub eax, 768
    cmp eax, 0
    jg .bound_hi2
    xor eax, eax
.bound_hi2:
    cmp dword [rbx + HUB_SCROLL_Y_OFF], eax
    jle .moved
    mov [rbx + HUB_SCROLL_Y_OFF], eax
.moved:
    mov eax, 1
    jmp .out

.up:
    cmp dword [rel hub_drag_active], 0
    je .tap_try
    mov dword [rel hub_drag_active], 0
    mov dword [rel hub_drag_touch_id], -1
    mov eax, [rel hub_drag_last_dy]
    sar eax, 1
    sub dword [rbx + HUB_SCROLL_Y_OFF], eax
    mov eax, 1
    jmp .out

.tap_try:
    ; tap on Files card -> request FM open
    mov eax, [r12 + INPUT_EVENT_MOUSE_Y_OFF]
    cmp eax, 380
    jl .tap_ws
    cmp eax, 476
    jg .tap_ws
    mov eax, [r12 + INPUT_EVENT_MOUSE_X_OFF]
    cmp eax, 40
    jl .tap_ws
    cmp eax, 600
    jg .tap_ws
    cmp eax, 320
    jl .fm_home
    lea rsi, [rel hub_fm_path_tmp]
    jmp .fm_copy
.fm_home:
    lea rsi, [rel hub_fm_path_home]
.fm_copy:
    lea rdi, [rel hub_fm_req_path]
    xor ecx, ecx
.fm_loop:
    mov al, [rsi + rcx]
    mov [rdi + rcx], al
    test al, al
    jz .fm_done
    inc ecx
    jmp .fm_loop
.fm_done:
    mov dword [rel hub_fm_req_pending], 1
    mov eax, 1
    jmp .out

.tap_ws:
    ; tap on preview strip (first row only) -> switch workspace
    mov eax, [r12 + INPUT_EVENT_MOUSE_Y_OFF]
    cmp eax, 220
    jl .no
    cmp eax, 320
    jg .no
    mov eax, [r12 + INPUT_EVENT_MOUSE_X_OFF]
    sub eax, 40
    cmp eax, 0
    jl .no
    xor edx, edx
    mov ecx, 140
    div ecx
    mov r10d, eax
    call workspaces_get_manager
    test rax, rax
    jz .no
    cmp r10d, [rax + WSM_COUNT_OFF]
    jge .no
    mov rdi, rax
    mov esi, r10d
    call workspaces_switch
    mov eax, 1
    jmp .out

.no:
    xor eax, eax
.out:
    pop r12
    pop rbx
    ret

; hub_toggle(mgr) -> eax hub active (0/1)
hub_toggle:
    push rbx
    mov rbx, rdi
    lea rax, [rel hub_global]
    test rbx, rbx
    jz .ret_state
    cmp dword [rbx + WSM_HUB_MODE_OFF], 0
    jne .disable
    mov dword [rbx + WSM_HUB_MODE_OFF], 1
    mov dword [rbx + WSM_OVERVIEW_MODE_OFF], 0
    mov dword [rax + HUB_ACTIVE_OFF], 1
    lea rdi, [rel hub_transition_spring]
    xor esi, esi
    mov edx, FP_ONE
    mov ecx, HUB_SPRING_STIFF
    mov r8d, HUB_SPRING_DAMP
    call spring_init
    mov eax, 1
    jmp .out
.disable:
    mov dword [rbx + WSM_HUB_MODE_OFF], 0
    mov dword [rax + HUB_ACTIVE_OFF], 0
    lea rdi, [rel hub_transition_spring]
    mov esi, FP_ONE
    xor edx, edx
    mov ecx, HUB_SPRING_STIFF
    mov r8d, HUB_SPRING_DAMP
    call spring_init
    xor eax, eax
    jmp .out
.ret_state:
    mov eax, dword [rax + HUB_ACTIVE_OFF]
.out:
    pop rbx
    ret
