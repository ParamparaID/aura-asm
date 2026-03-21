; radial_menu.asm — Context Bloom: items on circle, open spring, sector pick by dot
%include "src/hal/linux_x86_64/defs.inc"
%include "src/gui/widget.inc"

%define FP_DT_60 1092

extern canvas_fill_rect
extern font_draw_string
extern spring_init
extern spring_set_target
extern spring_update
extern spring_value
extern widget_set_dirty

; RadialData
%define RD_ITEMS    0
%define RD_N        8
%define RD_FONT     16
%define RD_FG       24
%define RD_ACCENT   28
%define RD_OPEN     32          ; Spring
%define RD_ACTIVE   60
%define RD_DRAG     64

section .rodata
; cos/sin * 256 for angles -90 + i*60 (i=0..5)
rd_cx:
    dd 0, 221, 221, 0, -221, -221
rd_sy:
    dd -256, -128, 128, 256, 128, -128

section .text
global w_radial_render
global w_radial_measure
global w_radial_handle_input
global w_radial_layout
global w_radial_destroy

w_radial_measure:
    mov dword [rdi + W_PREF_W_OFF], 200
    mov dword [rdi + W_PREF_H_OFF], 200
    mov dword [rdi + W_MIN_W_OFF], TOUCH_TARGET_MIN
    mov dword [rdi + W_MIN_H_OFF], TOUCH_TARGET_MIN
    ret

w_radial_render:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push r10
    mov r12, rdi
    mov r13, rsi
    mov r14d, ecx
    mov r15d, r8d
    mov rbx, [r12 + W_DATA_OFF]
    test rbx, rbx
    jz .out

    lea rdi, [rbx + RD_OPEN]
    mov esi, FP_DT_60
    call spring_update
    lea rdi, [rbx + RD_OPEN]
    call spring_value
    mov r11d, eax                 ; fp open
    add r11d, 0x8000
    sar r11d, 16
    cmp r11d, 1
    jl .out

    xor r10d, r10d
.item:
    cmp r10d, [rbx + RD_N]
    jae .out
    cmp r10d, [rbx + RD_ACTIVE]
    jne .ca
    mov r9d, [rbx + RD_ACCENT]
    jmp .mk
.ca:
    mov r9d, 0xFF444444
.mk:
    mov eax, r10d
    cdqe
    lea r9, [rel rd_cx]
    mov ecx, [r9 + rax*4]
    imul ecx, r11d
    sar ecx, 8
    lea r9, [rel rd_sy]
    mov edx, [r9 + rax*4]
    imul edx, r11d
    sar edx, 8
    mov esi, [r12 + W_WIDTH_OFF]
    sar esi, 1
    add esi, r14d
    add esi, ecx
    sub esi, 4
    mov eax, [r12 + W_HEIGHT_OFF]
    sar eax, 1
    add eax, r15d
    add eax, edx
    sub eax, 4
    mov edx, eax
    mov rdi, r13
    mov ecx, 8
    mov r8d, 8
    push r10
    call canvas_fill_rect
    pop r10
.lbl:
    mov rax, [rbx + RD_ITEMS]
    mov r8, [rax + r10*8]
    mov rdi, [rbx + RD_FONT]
    test rdi, rdi
    jz .ni
    mov eax, r10d
    cdqe
    lea r9, [rel rd_cx]
    mov esi, [r9 + rax*4]
    imul esi, r11d
    sar esi, 8
    lea r9, [rel rd_sy]
    mov edi, [r9 + rax*4]
    imul edi, r11d
    sar edi, 8
    mov edx, [r12 + W_WIDTH_OFF]
    sar edx, 1
    add edx, r14d
    add edx, esi
    add edx, 10
    mov ecx, [r12 + W_HEIGHT_OFF]
    sar ecx, 1
    add ecx, r15d
    add ecx, edi
    add ecx, 6
    mov rdi, [rbx + RD_FONT]
    mov rsi, r13
    mov r9d, 6
    push r10
    sub rsp, 24
    mov dword [rsp], 11
    mov eax, [rbx + RD_FG]
    mov [rsp + 8], eax
    mov dword [rsp + 16], 0
    call font_draw_string
    add rsp, 24
    pop r10
.ni:
    inc r10d
    jmp .item

.out:
    pop r10
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

w_radial_handle_input:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13, rsi
    mov r14d, edx
    mov r15d, ecx
    mov rbx, [r12 + W_DATA_OFF]
    test rbx, rbx
    jz .no

    cmp dword [r13 + IE_TYPE_OFF], INPUT_TOUCH_DOWN
    je .open
    cmp dword [r13 + IE_TYPE_OFF], INPUT_TOUCH_MOVE
    je .mv
    cmp dword [r13 + IE_TYPE_OFF], INPUT_TOUCH_UP
    je .up
    jmp .no

.open:
    lea rdi, [rbx + RD_OPEN]
    xor esi, esi
    mov edx, esi
    mov ecx, 0x00012000
    mov r8d, 0x0000A000
    call spring_init
    lea rdi, [rbx + RD_OPEN]
    mov esi, 0x00010000
    call spring_set_target
    mov dword [rbx + RD_DRAG], 1
    jmp .pick

.mv:
    cmp dword [rbx + RD_DRAG], 0
    je .no
.pick:
    mov eax, [r13 + IE_MOUSE_X_OFF]
    sub eax, r14d
    mov esi, [r12 + W_WIDTH_OFF]
    sar esi, 1
    sub eax, esi
    mov ecx, eax
    mov eax, [r13 + IE_MOUSE_Y_OFF]
    sub eax, r15d
    mov esi, [r12 + W_HEIGHT_OFF]
    sar esi, 1
    sub eax, esi
    mov edx, eax
    xor r10d, r10d
    mov r8d, -0x40000000
.best:
    cmp r10d, [rbx + RD_N]
    jae .bdone
    mov eax, r10d
    cdqe
    lea r9, [rel rd_cx]
    mov esi, [r9 + rax*4]
    imul esi, ecx
    lea r9, [rel rd_sy]
    mov edi, [r9 + rax*4]
    imul edi, edx
    add esi, edi
    cmp esi, r8d
    jle .nb
    mov r8d, esi
    mov [rbx + RD_ACTIVE], r10d
.nb:
    inc r10d
    jmp .best
.bdone:
    mov rdi, r12
    call widget_set_dirty
    mov eax, 1
    jmp .ret

.up:
    mov dword [rbx + RD_DRAG], 0
    mov eax, 1
    jmp .ret

.no:
    xor eax, eax
.ret:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

w_radial_layout:
    ret

w_radial_destroy:
    ret
