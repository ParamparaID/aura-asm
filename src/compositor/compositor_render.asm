; compositor_render.asm — composite mapped surfaces + frame callbacks (Phase 3)
%include "src/hal/linux_x86_64/defs.inc"
%include "src/compositor/compositor.inc"

extern canvas_clear
extern canvas_draw_image_raw
extern proto_send_event
extern proto_send_delete_id
extern compositor_bump_serial
extern proto_flush
extern decoration_render_surface
extern cursor_render_global

section .bss
    cr_saved_server   resq 1
    cr_scratch_base   resq 1       ; compositor_render scratch[] (survives canvas_clear)

section .text
global compositor_render
global compositor_send_frame_callbacks

; compositor_render(server, output_canvas, bg_color) — bg = esi (ARGB)
compositor_render:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 256                 ; 32 * qword surface* scratch
    mov [rel cr_scratch_base], rsp
    mov rbx, rdi
    mov r12, rsi
    mov r13d, edx
    mov [rel cr_saved_server], rbx

    mov rdi, r12
    mov esi, r13d
    call canvas_clear

    mov rbx, [rel cr_saved_server]
    mov r11, [rel cr_scratch_base]
    xor r14d, r14d
    mov r15, [rbx + CS_CLIENTS_OFF]
    xor ecx, ecx
.cli:
    cmp ecx, dword [rbx + CS_CLIENT_COUNT_OFF]
    jae .sort
    mov rax, [r15 + rcx*8]
    inc ecx
    test rax, rax
    jz .cli
    push rcx
    push rax
    mov r8, rax                  ; client* for .res (stable)
    xor edx, edx
.res:
    cmp edx, dword [r8 + CC_RES_COUNT_OFF]
    jae .next_cli
    mov rsi, [r8 + CC_RESOURCES_OFF + rdx*8]
    inc edx
    test rsi, rsi
    jz .res
    cmp dword [rsi + RES_TYPE_OFF], RESOURCE_SURFACE
    jne .res
    mov rsi, [rsi + RES_DATA_OFF]
    test rsi, rsi
    jz .res
    cmp dword [rsi + SF_MAPPED_OFF], 0
    je .res
    mov rdi, [rsi + SF_CURRENT_BUF_OFF]
    test rdi, rdi
    jz .res
    cmp r14d, 32
    jae .res
    mov [r11 + r14*8], rsi
    inc r14d
    jmp .res
.next_cli:
    pop rax
    pop rcx
    jmp .cli

.sort:
    cmp r14d, 2
    jb .draw
    xor ecx, ecx
.bub_i:
    mov eax, r14d
    dec eax
    cmp ecx, eax
    jae .draw
    xor edx, edx
.bub_j:
    mov eax, r14d
    dec eax
    sub eax, ecx
    cmp edx, eax
    jae .bub_inci
    mov r8, [r11 + rdx*8]
    mov r9, [r11 + rdx*8 + 8]
    mov eax, dword [r8 + SF_Z_ORDER_OFF]
    cmp eax, dword [r9 + SF_Z_ORDER_OFF]
    jle .bub_next
    mov [r11 + rdx*8], r9
    mov [r11 + rdx*8 + 8], r8
.bub_next:
    inc edx
    jmp .bub_j
.bub_inci:
    inc ecx
    jmp .bub_i

.draw:
    xor ecx, ecx
.dr:
    cmp ecx, r14d
    jae .frames
    mov r15, [r11 + rcx*8]
    inc ecx
    mov rdi, [r15 + SF_CURRENT_BUF_OFF]
    test rdi, rdi
    jz .dr
    mov rsi, [rdi + BUF_PIXELS_OFF]
    test rsi, rsi
    jz .dr
    push rdi
    push rcx
    push r15
    mov rdi, r15
    mov rsi, r12
    xor edx, edx
    xor ecx, ecx
    mov rax, [rbx + CS_KEYBOARD_FOCUS_OFF]
    cmp rax, r15
    jne .no_focus
    mov ecx, 1
.no_focus:
    call decoration_render_surface
    pop r15
    pop rcx
    pop rdi
    mov rsi, [rdi + BUF_PIXELS_OFF]
    mov r8d, dword [rdi + BUF_WIDTH_OFF]
    mov r9d, dword [rdi + BUF_HEIGHT_OFF]
    mov r10d, dword [rdi + BUF_STRIDE_OFF]
    mov edx, dword [r15 + SF_SCREEN_X_OFF]
    mov ecx, dword [r15 + SF_SCREEN_Y_OFF]
    mov rdi, r12
    call canvas_draw_image_raw
    jmp .dr

.frames:
    mov rdi, r12
    call cursor_render_global

    mov rdi, rbx
    call compositor_send_frame_callbacks

    ; Push queued events (e.g. wl_callback.done) to the wire — clients may recv immediately after render
    mov r11, [rbx + CS_CLIENTS_OFF]
    xor ecx, ecx
.cfl:
    cmp ecx, dword [rbx + CS_CLIENT_COUNT_OFF]
    jae .cfl_done
    mov rdi, [r11 + rcx*8]
    inc ecx
    test rdi, rdi
    jz .cfl
    call proto_flush
    jmp .cfl
.cfl_done:

    add rsp, 256
    xor eax, eax
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; compositor_send_frame_callbacks(server)
compositor_send_frame_callbacks:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi

    mov r15, [rbx + CS_CLIENTS_OFF]
    xor ecx, ecx
.ccli:
    cmp ecx, dword [rbx + CS_CLIENT_COUNT_OFF]
    jae .done
    mov r12, [r15 + rcx*8]
    inc ecx
    test r12, r12
    jz .ccli
    xor r13d, r13d
.cres:
    cmp r13d, dword [r12 + CC_RES_COUNT_OFF]
    jae .ccli
    mov rax, [r12 + CC_RESOURCES_OFF + r13*8]
    inc r13d
    test rax, rax
    jz .cres
    cmp dword [rax + RES_TYPE_OFF], RESOURCE_SURFACE
    jne .cres
    mov r14, [rax + RES_DATA_OFF]
    test r14, r14
    jz .cres
    cmp dword [r14 + SF_FRAME_CB_OFF], 0
    je .cres

    sub rsp, 32
    mov rdi, r12
    call compositor_bump_serial
    mov dword [rsp + 8], eax

    mov rdi, r12
    mov esi, dword [r14 + SF_FRAME_CB_OFF]
    xor edx, edx
    lea rcx, [rsp + 8]
    mov r8, 4
    call proto_send_event

    mov rdi, r12
    mov esi, dword [r14 + SF_FRAME_CB_OFF]
    call proto_send_delete_id

    mov dword [r14 + SF_FRAME_CB_OFF], 0
    add rsp, 32
    jmp .cres

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
