; floating.asm — floating window move/resize/snap
%include "src/compositor/compositor.inc"
%include "src/compositor/wm.inc"

%define FLOAT_DEFAULT_W             640
%define FLOAT_DEFAULT_H             480
%define FLOAT_MIN_W                 100
%define FLOAT_MIN_H                 100
%define FLOAT_SNAP_DISTANCE         20

section .bss
    float_drag_start_px      resd 1
    float_drag_start_py      resd 1
    float_drag_start_x       resd 1
    float_drag_start_y       resd 1
    float_resize_start_px    resd 1
    float_resize_start_py    resd 1
    float_resize_start_x     resd 1
    float_resize_start_y     resd 1
    float_resize_start_w     resd 1
    float_resize_start_h     resd 1

section .text
global floating_add
global floating_start_drag
global floating_update_drag
global floating_end_drag
global floating_start_resize
global floating_update_resize
global floating_end_resize
global floating_snap_check

; floating_add(wm, surface)
floating_add:
    mov dword [rsi + SF_FLOATING_OFF], 1
    mov eax, dword [rsi + SF_WIDTH_OFF]
    test eax, eax
    jg .have_w
    mov eax, FLOAT_DEFAULT_W
    mov dword [rsi + SF_WIDTH_OFF], eax
.have_w:
    mov edx, dword [rsi + SF_HEIGHT_OFF]
    test edx, edx
    jg .have_h
    mov edx, FLOAT_DEFAULT_H
    mov dword [rsi + SF_HEIGHT_OFF], edx
.have_h:
    mov ecx, dword [rdi + WM_OUTPUT_W_OFF]
    sub ecx, eax
    sar ecx, 1
    add ecx, dword [rdi + WM_OUTPUT_X_OFF]
    mov dword [rsi + SF_SCREEN_X_OFF], ecx
    mov ecx, dword [rdi + WM_OUTPUT_H_OFF]
    sub ecx, edx
    sar ecx, 1
    add ecx, dword [rdi + WM_OUTPUT_Y_OFF]
    mov dword [rsi + SF_SCREEN_Y_OFF], ecx
    ret

; floating_start_drag(wm, surface, pointer_x, pointer_y)
floating_start_drag:
    mov [rdi + WM_DRAG_SURFACE_OFF], rsi
    mov eax, edx
    sub eax, dword [rsi + SF_SCREEN_X_OFF]
    mov dword [rdi + WM_DRAG_OFFSET_X_OFF], eax
    mov eax, ecx
    sub eax, dword [rsi + SF_SCREEN_Y_OFF]
    mov dword [rdi + WM_DRAG_OFFSET_Y_OFF], eax
    mov dword [rel float_drag_start_px], edx
    mov dword [rel float_drag_start_py], ecx
    mov eax, dword [rsi + SF_SCREEN_X_OFF]
    mov dword [rel float_drag_start_x], eax
    mov eax, dword [rsi + SF_SCREEN_Y_OFF]
    mov dword [rel float_drag_start_y], eax
    ret

; floating_update_drag(wm, pointer_x, pointer_y)
floating_update_drag:
    mov rax, [rdi + WM_DRAG_SURFACE_OFF]
    test rax, rax
    jz .out
    mov ecx, esi
    sub ecx, dword [rdi + WM_DRAG_OFFSET_X_OFF]
    mov dword [rax + SF_SCREEN_X_OFF], ecx
    mov ecx, edx
    sub ecx, dword [rdi + WM_DRAG_OFFSET_Y_OFF]
    mov dword [rax + SF_SCREEN_Y_OFF], ecx
.out:
    ret

; floating_end_drag(wm)
floating_end_drag:
    mov rsi, [rdi + WM_DRAG_SURFACE_OFF]
    test rsi, rsi
    jz .clear
    call floating_snap_check
.clear:
    mov qword [rdi + WM_DRAG_SURFACE_OFF], 0
    mov dword [rdi + WM_DRAG_OFFSET_X_OFF], 0
    mov dword [rdi + WM_DRAG_OFFSET_Y_OFF], 0
    ret

; floating_start_resize(wm, surface, edge, pointer_x, pointer_y)
floating_start_resize:
    mov [rdi + WM_RESIZE_SURFACE_OFF], rsi
    mov dword [rdi + WM_RESIZE_EDGE_OFF], edx
    mov dword [rel float_resize_start_px], ecx
    mov dword [rel float_resize_start_py], r8d
    mov eax, dword [rsi + SF_SCREEN_X_OFF]
    mov dword [rel float_resize_start_x], eax
    mov eax, dword [rsi + SF_SCREEN_Y_OFF]
    mov dword [rel float_resize_start_y], eax
    mov eax, dword [rsi + SF_WIDTH_OFF]
    mov dword [rel float_resize_start_w], eax
    mov eax, dword [rsi + SF_HEIGHT_OFF]
    mov dword [rel float_resize_start_h], eax
    ret

; floating_update_resize(wm, pointer_x, pointer_y)
floating_update_resize:
    push rbx
    mov rax, [rdi + WM_RESIZE_SURFACE_OFF]
    test rax, rax
    jz .out
    mov ebx, dword [rdi + WM_RESIZE_EDGE_OFF]

    mov ecx, esi
    sub ecx, dword [rel float_resize_start_px]      ; dx
    mov edx, edx
    sub edx, dword [rel float_resize_start_py]      ; dy

    ; Start from baseline geometry
    mov r8d, dword [rel float_resize_start_x]
    mov r9d, dword [rel float_resize_start_y]
    mov r10d, dword [rel float_resize_start_w]
    mov r11d, dword [rel float_resize_start_h]

    cmp ebx, WM_EDGE_LEFT
    je .left
    cmp ebx, WM_EDGE_RIGHT
    je .right
    cmp ebx, WM_EDGE_TOP
    je .top
    cmp ebx, WM_EDGE_BOTTOM
    je .bottom
    cmp ebx, WM_EDGE_TOPLEFT
    je .topleft
    cmp ebx, WM_EDGE_TOPRIGHT
    je .topright
    cmp ebx, WM_EDGE_BOTTOMLEFT
    je .bottomleft
    cmp ebx, WM_EDGE_BOTTOMRIGHT
    je .bottomright
    jmp .apply

.left:
    add r8d, ecx
    sub r10d, ecx
    jmp .apply
.right:
    add r10d, ecx
    jmp .apply
.top:
    add r9d, edx
    sub r11d, edx
    jmp .apply
.bottom:
    add r11d, edx
    jmp .apply
.topleft:
    add r8d, ecx
    sub r10d, ecx
    add r9d, edx
    sub r11d, edx
    jmp .apply
.topright:
    add r10d, ecx
    add r9d, edx
    sub r11d, edx
    jmp .apply
.bottomleft:
    add r8d, ecx
    sub r10d, ecx
    add r11d, edx
    jmp .apply
.bottomright:
    add r10d, ecx
    add r11d, edx

.apply:
    cmp r10d, FLOAT_MIN_W
    jge .w_ok
    mov r10d, FLOAT_MIN_W
.w_ok:
    cmp r11d, FLOAT_MIN_H
    jge .h_ok
    mov r11d, FLOAT_MIN_H
.h_ok:
    mov dword [rax + SF_SCREEN_X_OFF], r8d
    mov dword [rax + SF_SCREEN_Y_OFF], r9d
    mov dword [rax + SF_WIDTH_OFF], r10d
    mov dword [rax + SF_HEIGHT_OFF], r11d
.out:
    pop rbx
    ret

; floating_end_resize(wm)
floating_end_resize:
    mov rax, [rdi + WM_RESIZE_SURFACE_OFF]
    test rax, rax
    jz .clear
    mov ecx, dword [rax + SF_WIDTH_OFF]
    cmp ecx, FLOAT_MIN_W
    jge .w_ok
    mov dword [rax + SF_WIDTH_OFF], FLOAT_MIN_W
.w_ok:
    mov ecx, dword [rax + SF_HEIGHT_OFF]
    cmp ecx, FLOAT_MIN_H
    jge .clear
    mov dword [rax + SF_HEIGHT_OFF], FLOAT_MIN_H
.clear:
    mov qword [rdi + WM_RESIZE_SURFACE_OFF], 0
    mov dword [rdi + WM_RESIZE_EDGE_OFF], WM_EDGE_NONE
    ret

; floating_snap_check(wm, surface)
floating_snap_check:
    mov eax, dword [rsi + SF_SCREEN_X_OFF]
    mov ecx, dword [rsi + SF_SCREEN_Y_OFF]
    mov edx, dword [rsi + SF_WIDTH_OFF]
    mov r8d, dword [rsi + SF_HEIGHT_OFF]

    ; left edge snap and half-screen snap
    cmp eax, dword [rdi + WM_OUTPUT_X_OFF]
    jl .snap_left
    mov r9d, eax
    sub r9d, dword [rdi + WM_OUTPUT_X_OFF]
    cmp r9d, FLOAT_SNAP_DISTANCE
    jg .right_edge
.snap_left:
    mov eax, dword [rdi + WM_OUTPUT_X_OFF]
    mov dword [rsi + SF_SCREEN_X_OFF], eax
    mov eax, dword [rdi + WM_OUTPUT_W_OFF]
    sar eax, 1
    mov dword [rsi + SF_WIDTH_OFF], eax
    jmp .top_edge

.right_edge:
    mov r9d, dword [rdi + WM_OUTPUT_X_OFF]
    add r9d, dword [rdi + WM_OUTPUT_W_OFF]
    mov r10d, dword [rsi + SF_SCREEN_X_OFF]
    add r10d, dword [rsi + SF_WIDTH_OFF]
    sub r9d, r10d
    cmp r9d, FLOAT_SNAP_DISTANCE
    jg .top_edge
    mov eax, dword [rdi + WM_OUTPUT_X_OFF]
    add eax, dword [rdi + WM_OUTPUT_W_OFF]
    mov ecx, dword [rdi + WM_OUTPUT_W_OFF]
    sar ecx, 1
    sub eax, ecx
    mov dword [rsi + SF_SCREEN_X_OFF], eax
    mov dword [rsi + SF_WIDTH_OFF], ecx

.top_edge:
    mov eax, dword [rsi + SF_SCREEN_Y_OFF]
    mov ecx, eax
    sub ecx, dword [rdi + WM_OUTPUT_Y_OFF]
    cmp ecx, FLOAT_SNAP_DISTANCE
    jg .bottom_edge
    ; top edge => maximize
    mov eax, dword [rdi + WM_OUTPUT_X_OFF]
    mov dword [rsi + SF_SCREEN_X_OFF], eax
    mov eax, dword [rdi + WM_OUTPUT_Y_OFF]
    mov dword [rsi + SF_SCREEN_Y_OFF], eax
    mov eax, dword [rdi + WM_OUTPUT_W_OFF]
    mov dword [rsi + SF_WIDTH_OFF], eax
    mov eax, dword [rdi + WM_OUTPUT_H_OFF]
    mov dword [rsi + SF_HEIGHT_OFF], eax
    ret

.bottom_edge:
    mov eax, dword [rdi + WM_OUTPUT_Y_OFF]
    add eax, dword [rdi + WM_OUTPUT_H_OFF]
    mov ecx, dword [rsi + SF_SCREEN_Y_OFF]
    add ecx, dword [rsi + SF_HEIGHT_OFF]
    sub eax, ecx
    cmp eax, FLOAT_SNAP_DISTANCE
    jg .done
    mov eax, dword [rdi + WM_OUTPUT_Y_OFF]
    add eax, dword [rdi + WM_OUTPUT_H_OFF]
    sub eax, dword [rsi + SF_HEIGHT_OFF]
    mov dword [rsi + SF_SCREEN_Y_OFF], eax
.done:
    ret
