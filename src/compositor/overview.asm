; overview.asm — Expose-like overview for current workspace
%include "src/compositor/compositor.inc"
%include "src/compositor/workspaces.inc"
%include "src/compositor/wm.inc"
%include "src/canvas/canvas.inc"

extern canvas_blur_region
extern canvas_fill_rect
extern canvas_draw_rect
extern canvas_draw_string
extern canvas_draw_image_scaled
extern spring_init
extern spring_update
extern spring_value
extern workspaces_get_active
extern wm_set_focus
extern wm_remove_surface

%define INPUT_EVENT_TYPE_OFF         0
%define INPUT_EVENT_MOUSE_X_OFF      28
%define INPUT_EVENT_MOUSE_Y_OFF      32
%define INPUT_TOUCH_UP               5

%define FP_ONE                       0x00010000
%define FP_THUMB_SCALE               0x00004CCD ; ~0.3
%define FP_DT_60                     1092
%define OV_SPRING_STIFF              0x00022000
%define OV_SPRING_DAMP               0x00010000

; Image fields for canvas_draw_image_scaled
%define IMG_WIDTH_OFF                0
%define IMG_HEIGHT_OFF               4
%define IMG_PIXELS_OFF               8
%define IMG_STRIDE_OFF               16
%define IMG_STRUCT_SIZE              20

section .bss
    overview_thumb_count             resd 1
    overview_items                   resb OV_MAX_THUMBS * OV_THUMB_STRIDE
    overview_spring                  resb 28
    overview_wm_ptr                  resq 1

section .text
global overview_enter
global overview_render
global overview_handle_input
global overview_exit
global overview_debug_get_count
global overview_debug_get_item

overview_grid_cols:
    cmp edi, 1
    jle .c1
    cmp edi, 4
    jle .c2
    cmp edi, 9
    jle .c3
    mov eax, 4
    ret
.c3:
    mov eax, 3
    ret
.c2:
    mov eax, 2
    ret
.c1:
    mov eax, 1
    ret

; overview_enter(mgr, wm)
overview_enter:
    push rbx
    push r12
    mov rbx, rdi
    mov [rel overview_wm_ptr], rsi
    test rbx, rbx
    jz .out
    mov dword [rbx + WSM_OVERVIEW_MODE_OFF], 1
    mov dword [rbx + WSM_HUB_MODE_OFF], 0
    mov dword [rel overview_thumb_count], 0

    mov rdi, rbx
    call workspaces_get_active
    test rax, rax
    jz .anim
    mov r12, rax
    mov edi, dword [r12 + WS_SURFACE_COUNT_OFF]
    test edi, edi
    jz .anim
    cmp edi, OV_MAX_THUMBS
    jle .cnt_ok
    mov edi, OV_MAX_THUMBS
.cnt_ok:
    mov dword [rel overview_thumb_count], edi
    push rdi
    call overview_grid_cols
    mov r9d, eax                     ; cols
    pop rdi                          ; count
    mov eax, edi
    add eax, r9d
    dec eax
    xor edx, edx
    div r9d
    xor ecx, ecx
.fill:
    cmp ecx, edi
    jae .anim
    mov eax, ecx
    xor edx, edx
    div r9d
    mov r10d, eax                    ; row
    mov r11d, edx                    ; col
    mov r8d, r11d
    imul r8d, 250
    add r8d, 80
    mov eax, r10d
    imul eax, 180
    add eax, 70
    mov esi, ecx
    imul esi, OV_THUMB_STRIDE
    lea rax, [rel overview_items + rsi]
    mov [rax + OV_THUMB_X_OFF], r8d
    mov [rax + OV_THUMB_Y_OFF], eax
    mov dword [rax + OV_THUMB_W_OFF], 220
    mov dword [rax + OV_THUMB_H_OFF], 140
    mov dword [rax + OV_THUMB_SCALE_OFF], FP_THUMB_SCALE
    mov rdx, [r12 + WS_SURFACES_OFF + rcx*8]
    mov [rax + OV_THUMB_SURFACE_OFF], rdx
    inc ecx
    jmp .fill

.anim:
    lea rdi, [rel overview_spring]
    mov esi, FP_ONE
    mov edx, FP_THUMB_SCALE
    mov ecx, OV_SPRING_STIFF
    mov r8d, OV_SPRING_DAMP
    call spring_init
.out:
    pop r12
    pop rbx
    ret

; overview_render(mgr, compositor, canvas)
overview_render:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 32
    mov rbx, rdi
    mov r12, rdx
    test rbx, rbx
    jz .out
    test r12, r12
    jz .out
    cmp dword [rbx + WSM_OVERVIEW_MODE_OFF], 0
    je .out

    lea rdi, [rel overview_spring]
    mov esi, FP_DT_60
    call spring_update
    call spring_value
    mov r13d, eax                    ; scale fp

    ; blur full frame and darken
    mov rdi, r12
    xor esi, esi
    xor edx, edx
    mov ecx, [r12 + CV_WIDTH_OFF]
    mov r8d, [r12 + CV_HEIGHT_OFF]
    mov r9d, 5
    call canvas_blur_region
    mov rdi, r12
    xor esi, esi
    xor edx, edx
    mov ecx, [r12 + CV_WIDTH_OFF]
    mov r8d, [r12 + CV_HEIGHT_OFF]
    mov r9d, 0x88000000
    call canvas_fill_rect

    xor r14d, r14d
.loop:
    cmp r14d, dword [rel overview_thumb_count]
    jae .out
    mov eax, r14d
    imul eax, OV_THUMB_STRIDE
    lea r15, [rel overview_items + rax]
    mov rax, [r15 + OV_THUMB_SURFACE_OFF]
    test rax, rax
    jz .next
    mov rdx, [rax + SF_CURRENT_BUF_OFF]
    test rdx, rdx
    jz .next
    mov rcx, [rdx + BUF_PIXELS_OFF]
    test rcx, rcx
    jz .next

    ; image struct on stack
    mov eax, [rdx + BUF_WIDTH_OFF]
    mov [rsp + IMG_WIDTH_OFF], eax
    mov eax, [rdx + BUF_HEIGHT_OFF]
    mov [rsp + IMG_HEIGHT_OFF], eax
    mov [rsp + IMG_PIXELS_OFF], rcx
    mov eax, [rdx + BUF_STRIDE_OFF]
    mov [rsp + IMG_STRIDE_OFF], eax

    mov edi, [r15 + OV_THUMB_W_OFF]
    mov esi, r13d
    imul edi, esi
    sar edi, 16
    cmp edi, 48
    jge .w_ok
    mov edi, 48
.w_ok:
    mov ebx, [r15 + OV_THUMB_H_OFF]
    mov esi, r13d
    imul ebx, esi
    sar ebx, 16
    cmp ebx, 36
    jge .h_ok
    mov ebx, 36
.h_ok:
    mov rdi, r12
    lea rsi, [rsp]
    mov edx, [r15 + OV_THUMB_X_OFF]
    mov ecx, [r15 + OV_THUMB_Y_OFF]
    mov r8d, edi
    mov r9d, ebx
    call canvas_draw_image_scaled

    mov rdi, r12
    mov esi, [r15 + OV_THUMB_X_OFF]
    mov edx, [r15 + OV_THUMB_Y_OFF]
    mov ecx, edi
    mov r8d, ebx
    mov r9d, 0xFF6A90FF
    call canvas_draw_rect

    ; title (best effort with current bitmap font)
    mov rax, [r15 + OV_THUMB_SURFACE_OFF]
    mov ecx, [rax + SF_TITLE_LEN_OFF]
    test ecx, ecx
    jz .next
    cmp ecx, 24
    jle .title_len
    mov ecx, 24
.title_len:
    mov rdi, r12
    mov esi, [r15 + OV_THUMB_X_OFF]
    mov edx, [r15 + OV_THUMB_Y_OFF]
    add edx, ebx
    add edx, 10
    mov r8d, ecx
    lea rcx, [rax + SF_TITLE_OFF]
    mov r9d, 0xFFFFFFFF
    push qword 0
    call canvas_draw_string
    add rsp, 8
.next:
    inc r14d
    jmp .loop

.out:
    add rsp, 32
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; overview_handle_input(mgr, event) -> eax handled
overview_handle_input:
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12, rsi
    test rbx, rbx
    jz .no
    test r12, r12
    jz .no
    cmp dword [rbx + WSM_OVERVIEW_MODE_OFF], 0
    je .no
    cmp dword [r12 + INPUT_EVENT_TYPE_OFF], INPUT_TOUCH_UP
    jne .no

    mov r10d, [r12 + INPUT_EVENT_MOUSE_X_OFF]
    mov r11d, [r12 + INPUT_EVENT_MOUSE_Y_OFF]
    xor r13d, r13d
.hit:
    cmp r13d, dword [rel overview_thumb_count]
    jae .no
    mov eax, r13d
    imul eax, OV_THUMB_STRIDE
    lea rdx, [rel overview_items + rax]
    mov eax, [rdx + OV_THUMB_X_OFF]
    cmp r10d, eax
    jl .next
    mov ecx, eax
    add ecx, [rdx + OV_THUMB_W_OFF]
    cmp r10d, ecx
    jg .next
    mov eax, [rdx + OV_THUMB_Y_OFF]
    cmp r11d, eax
    jl .next
    mov ecx, eax
    add ecx, [rdx + OV_THUMB_H_OFF]
    cmp r11d, ecx
    jg .next

    mov rax, [rdx + OV_THUMB_SURFACE_OFF]
    test rax, rax
    jz .next
    mov rdi, [rel overview_wm_ptr]
    test rdi, rdi
    jz .exit_only
    ; top 20px inside thumbnail interpreted as "swipe-up close"
    mov ecx, [rdx + OV_THUMB_Y_OFF]
    add ecx, 20
    cmp r11d, ecx
    jle .close
    mov rsi, rax
    call wm_set_focus
    jmp .exit_only
.close:
    mov rsi, rax
    call wm_remove_surface
.exit_only:
    mov rdi, rbx
    call overview_exit
    mov eax, 1
    jmp .out
.next:
    inc r13d
    jmp .hit

.no:
    xor eax, eax
.out:
    pop r13
    pop r12
    pop rbx
    ret

; overview_exit(mgr)
overview_exit:
    test rdi, rdi
    jz .out
    mov dword [rdi + WSM_OVERVIEW_MODE_OFF], 0
    lea rdi, [rel overview_spring]
    mov esi, FP_THUMB_SCALE
    mov edx, FP_ONE
    mov ecx, OV_SPRING_STIFF
    mov r8d, OV_SPRING_DAMP
    call spring_init
.out:
    ret

overview_debug_get_count:
    mov eax, [rel overview_thumb_count]
    ret

; overview_debug_get_item(index) -> rax ptr or 0
overview_debug_get_item:
    cmp edi, 0
    jl .none
    cmp edi, [rel overview_thumb_count]
    jge .none
    imul eax, edi, OV_THUMB_STRIDE
    lea rax, [rel overview_items + rax]
    ret
.none:
    xor eax, eax
    ret
