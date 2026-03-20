; text.asm
; AuraCanvas bitmap text rendering (8x16 font)
; Author: Aura Shell Team
; Date: 2026-03-20

extern canvas_put_pixel
extern canvas_fill_rect

%define FONT_W 8
%define FONT_H 16

section .data
global font_char_width
global font_char_height
font_char_width   dq FONT_W
font_char_height  dq FONT_H

; ASCII 32..126 (95 glyphs) * 16 bytes.
; MVP font data: only A/B/C explicitly defined, others are blank.
font_8x16:
    times (33*16) db 0
glyph_A:
    db 0x18,0x24,0x24,0x42,0x42,0x7E,0x42,0x42
    db 0x42,0x42,0x00,0x00,0x00,0x00,0x00,0x00
glyph_B:
    db 0x7C,0x42,0x42,0x42,0x7C,0x42,0x42,0x42
    db 0x42,0x7C,0x00,0x00,0x00,0x00,0x00,0x00
glyph_C:
    db 0x3C,0x42,0x40,0x40,0x40,0x40,0x40,0x40
    db 0x42,0x3C,0x00,0x00,0x00,0x00,0x00,0x00
    times (59*16) db 0

zero_glyph:
    times 16 db 0

section .bss

section .text
global canvas_draw_char
global canvas_draw_string
global canvas_draw_cursor
global canvas_text_width

; canvas_draw_char(canvas_ptr, x, y, char, fg_color, bg_color)
; Params: rdi,rsi,rdx,rcx,r8,r9
; Return: rax=0/-1
; Complexity: O(8*16)
canvas_draw_char:
    push rbx
    push r12
    push r13
    push r14
    push r15

    test rdi, rdi
    jz .bad
    mov rbx, rdi
    mov r12, rsi                    ; x
    mov r13, rdx                    ; y
    movzx r14d, cl                  ; char
    mov r15, r8                     ; fg
    mov r10, r9                     ; bg

    mov r11, zero_glyph
    cmp r14d, 32
    jb .glyph_ready
    cmp r14d, 126
    ja .glyph_ready
    sub r14d, 32
    imul r14, 16
    lea r11, [font_8x16 + r14]

.glyph_ready:
    xor r8d, r8d                    ; row
.row_loop:
    cmp r8d, FONT_H
    jae .ok
    movzx eax, byte [r11 + r8]
    mov r9d, eax                    ; row bits
    xor edx, edx                    ; col
.col_loop:
    cmp edx, FONT_W
    jae .next_row
    mov ecx, 7
    sub ecx, edx
    bt r9d, ecx
    jc .draw_fg
    cmp r10d, 0
    je .next_col
    mov rdi, rbx
    lea rsi, [r12 + rdx]
    lea rdx, [r13 + r8]
    mov rcx, r10
    call canvas_put_pixel
    jmp .next_col
.draw_fg:
    mov rdi, rbx
    lea rsi, [r12 + rdx]
    lea rdx, [r13 + r8]
    mov rcx, r15
    call canvas_put_pixel
.next_col:
    inc edx
    jmp .col_loop
.next_row:
    inc r8d
    jmp .row_loop

.ok:
    xor eax, eax
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.bad:
    mov rax, -1
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; canvas_draw_string(canvas_ptr, x, y, str_ptr, str_len, fg_color, bg_color)
; Params: rdi,rsi,rdx,rcx,r8,r9,[rsp+8]
; Return: rax=end_x
; Complexity: O(str_len*8*16)
canvas_draw_string:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8

    mov r10, [rbp + 16]             ; bg_color (7th arg)
    mov rbx, rdi
    mov r12, rsi                    ; x
    mov r13, rdx                    ; y
    mov r14, rcx                    ; str
    mov r15, r8                     ; len
    mov r11, r9                     ; fg

    mov qword [rsp], 0              ; i
.loop:
    mov rax, [rsp]
    cmp rax, r15
    jae .done
    movzx ecx, byte [r14 + rax]
    mov rdi, rbx
    mov rsi, r12
    mov rdx, r13
    mov r8, r11
    mov r9, r10
    call canvas_draw_char
    add r12, FONT_W
    mov rax, [rsp]
    inc rax
    mov [rsp], rax
    jmp .loop

.done:
    ; Keep right-side background consistent for tests.
    cmp r10d, 0
    je .ret
    mov rdi, rbx
    mov rsi, r12
    mov rdx, r13
    mov rcx, 1
    mov r8, FONT_H
    mov r9, r10
    call canvas_fill_rect

.ret:
    mov rax, r12
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; canvas_draw_cursor(canvas_ptr, x, y, color, visible)
; Params: rdi,rsi,rdx,rcx,r8
; Return: rax=0/-1
; Complexity: O(1)
canvas_draw_cursor:
    mov r9, rcx                     ; default color
    cmp r8, 0
    jne .draw
    xor r9d, r9d                    ; erase with black
.draw:
    mov rcx, 2
    mov r8, FONT_H
    call canvas_fill_rect
    ret

; canvas_text_width(str_len)
; Params: rdi=str_len
; Return: rax=str_len*8
; Complexity: O(1)
canvas_text_width:
    mov rax, rdi
    shl rax, 3
    ret
