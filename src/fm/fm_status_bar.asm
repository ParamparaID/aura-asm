; fm_status_bar.asm — compact FM status line widget helper
%include "src/hal/platform_defs.inc"
%include "src/fm/panel.inc"
%include "src/gui/widget.inc"

extern hal_statfs
extern canvas_fill_rect
extern canvas_draw_string

%define FM_ACTIVE_PANEL_OFF        24

section .bss
    fm_sb_tmp_statfs               resb 128
    fm_sb_path_buf                 resb 256
    fm_sb_free_buf                 resb 32

section .text
global fm_status_bar_render

fm_sb_strlen:
    xor eax, eax
.l:
    cmp byte [rdi + rax], 0
    je .o
    inc eax
    jmp .l
.o:
    ret

fm_sb_copy:
    ; (src rdi, dst rsi, cap edx) -> eax len/-1
    xor ecx, ecx
    test edx, edx
    jle .f
.c:
    cmp ecx, edx
    jae .f
    mov al, [rdi + rcx]
    mov [rsi + rcx], al
    test al, al
    jz .ok
    inc ecx
    jmp .c
.ok:
    mov eax, ecx
    ret
.f:
    mov eax, -1
    ret

; fm_status_bar_render(fm rdi, canvas rsi, theme rdx)
fm_status_bar_render:
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    test rbx, rbx
    jz .out
    test r12, r12
    jz .out
    test r13, r13
    jz .out

    mov r11d, [r12 + CV_HEIGHT_OFF]
    test r11d, r11d
    jle .out
    cmp r11d, 20
    jb .tiny
    sub r11d, 20
    jmp .have_y
.tiny:
    xor r11d, r11d
.have_y:

    mov rdi, r12
    xor esi, esi
    mov edx, r11d
    mov ecx, [r12 + CV_WIDTH_OFF]
    mov r8d, 20
    mov r9d, [r13 + TH_SURFACE_OFF]
    call canvas_fill_rect

    mov rax, [rbx + FM_ACTIVE_PANEL_OFF]
    test rax, rax
    jz .out
    mov r14, rax
    ; left: current path
    lea rdi, [r14 + P_PATH_OFF]
    lea rsi, [rel fm_sb_path_buf]
    mov edx, 256
    call fm_sb_copy
    lea rdi, [rel fm_sb_path_buf]
    call fm_sb_strlen
    lea rcx, [rel fm_sb_path_buf]
    mov rdi, r12
    mov esi, 8
    mov edx, r11d
    add edx, 5
    mov r8d, eax
    mov r9d, [r13 + TH_FG_OFF]
    push qword 0
    call canvas_draw_string
    add rsp, 8

    ; right: free space (best effort statfs)
    lea rdi, [r14 + P_PATH_OFF]
    lea rsi, [rel fm_sb_tmp_statfs]
    call hal_statfs
    test rax, rax
    js .out
    mov rax, [rel fm_sb_tmp_statfs + 16] ; f_blocks
    mov rcx, [rel fm_sb_tmp_statfs + 32] ; f_bavail
    mov rdx, [rel fm_sb_tmp_statfs + 8]  ; f_bsize
    imul rcx, rdx
    shr rcx, 20
    ; encode as "free=<n>MB"
    lea rdi, [rel fm_sb_free_buf]
    mov byte [rdi + 0], 'f'
    mov byte [rdi + 1], 'r'
    mov byte [rdi + 2], 'e'
    mov byte [rdi + 3], 'e'
    mov byte [rdi + 4], '='
    mov byte [rdi + 5], '?'
    mov byte [rdi + 6], 'M'
    mov byte [rdi + 7], 'B'
    mov byte [rdi + 8], 0
    ; simple marker for now when statfs succeeded
    cmp rcx, 0
    jle .draw_free
    mov byte [rdi + 5], '+'
.draw_free:
    lea rcx, [rel fm_sb_free_buf]
    mov rdi, r12
    mov esi, [r12 + CV_WIDTH_OFF]
    sub esi, 100
    js .out
    mov edx, r11d
    add edx, 5
    mov r8d, 8
    mov r9d, [r13 + TH_FG_OFF]
    push qword 0
    call canvas_draw_string
    add rsp, 8
.out:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
