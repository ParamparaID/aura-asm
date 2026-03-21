; test_truetype.asm
; Unit tests for TrueType loader/rasterizer
; Author: Aura Shell Team
; Date: 2026-03-20

extern hal_write
extern hal_exit
extern font_load
extern font_destroy
extern font_get_glyph_id
extern font_rasterize_glyph
extern font_measure_string
extern font_draw_string
extern canvas_init
extern canvas_destroy
extern canvas_clear
extern canvas_get_pixel

%define WHITE        0xFFFFFFFF
%define BLACK        0xFF000000

%define G_WIDTH_OFF      0
%define G_HEIGHT_OFF     4
%define G_BITMAP_OFF     8

section .data
    font_path        db "tests/data/test_font.ttf", 0
    txt_hello        db "Hello"
    txt_hi           db "Hi"
    txt_test         db "A"

    pass_msg         db "ALL TESTS PASSED", 10
    pass_len         equ $ - pass_msg

    fail_load_msg    db "TEST FAILED: truetype_load", 10
    fail_load_len    equ $ - fail_load_msg
    fail_cmap_msg    db "TEST FAILED: truetype_cmap", 10
    fail_cmap_len    equ $ - fail_cmap_msg
    fail_rast_msg    db "TEST FAILED: truetype_rasterize", 10
    fail_rast_len    equ $ - fail_rast_msg
    fail_meas_msg    db "TEST FAILED: truetype_measure", 10
    fail_meas_len    equ $ - fail_meas_msg
    fail_draw_msg    db "TEST FAILED: truetype_draw", 10
    fail_draw_len    equ $ - fail_draw_msg
    fail_cache_msg   db "TEST FAILED: truetype_cache", 10
    fail_cache_len   equ $ - fail_cache_msg

section .bss
    font_ptr         resq 1
    canvas_ptr       resq 1
    glyph_a_id       resq 1
    glyph1_ptr       resq 1
    glyph2_ptr       resq 1
    w_hello          resq 1
    h_hello          resq 1
    w_hi             resq 1
    h_hi             resq 1

section .text
global _start

%macro write_stdout 2
    mov rdi, 1
    lea rsi, [rel %1]
    mov rdx, %2
    call hal_write
%endmacro

%macro fail_exit 2
    write_stdout %1, %2
    mov rdi, 1
    call hal_exit
%endmacro

_start:
    ; Test 1: font_load
    lea rdi, [rel font_path]
    mov rsi, 24
    call font_load
    test rax, rax
    jz .fail_load
    mov [rel font_ptr], rax

    movzx ecx, word [rax + 18]          ; units_per_em
    test ecx, ecx
    jz .fail_load_destroy
    movzx ecx, word [rax + 16]          ; num_glyphs
    test ecx, ecx
    jz .fail_load_destroy

    ; Test 2: cmap lookup
    mov rdi, [rel font_ptr]
    mov rsi, 'A'
    call font_get_glyph_id
    test eax, eax
    jz .fail_cmap_destroy
    mov [rel glyph_a_id], rax

    mov rdi, [rel font_ptr]
    mov rsi, 'Z'
    call font_get_glyph_id
    test eax, eax
    jz .fail_cmap_destroy

    mov rdi, [rel font_ptr]
    mov rsi, ' '
    call font_get_glyph_id
    ; space can be 0 or >0 in some fonts

    ; Test 3 + 6: rasterize + cache
    mov rdi, [rel font_ptr]
    mov rsi, [rel glyph_a_id]
    mov rdx, 16
    call font_rasterize_glyph
    test rax, rax
    jz .fail_rast_destroy
    mov [rel glyph1_ptr], rax

    mov ecx, [rax + G_WIDTH_OFF]
    test ecx, ecx
    jle .fail_rast_destroy
    mov ecx, [rax + G_HEIGHT_OFF]
    test ecx, ecx
    jle .fail_rast_destroy
    mov r8, [rax + G_BITMAP_OFF]
    test r8, r8
    jz .fail_rast_destroy

    ; bitmap has at least one non-zero alpha
    mov ecx, [rax + G_WIDTH_OFF]
    mov edx, [rax + G_HEIGHT_OFF]
    imul ecx, edx
    xor edx, edx
.scan_nonzero:
    cmp edx, ecx
    jae .fail_rast_destroy
    movzx eax, byte [r8 + rdx]
    test eax, eax
    jnz .rast_ok
    inc edx
    jmp .scan_nonzero
.rast_ok:

    ; second call should return same ptr (cache hit)
    mov rdi, [rel font_ptr]
    mov rsi, [rel glyph_a_id]
    mov rdx, 16
    call font_rasterize_glyph
    test rax, rax
    jz .fail_cache_destroy
    mov [rel glyph2_ptr], rax
    cmp rax, [rel glyph1_ptr]
    jne .fail_cache_destroy

    ; Test 4: measure
    mov rdi, [rel font_ptr]
    lea rsi, [rel txt_hello]
    mov rdx, 5
    mov rcx, 16
    call font_measure_string
    mov [rel w_hello], rax
    mov [rel h_hello], rdx
    test rax, rax
    jle .fail_meas_destroy
    test rdx, rdx
    jle .fail_meas_destroy

    mov rdi, [rel font_ptr]
    lea rsi, [rel txt_hi]
    mov rdx, 2
    mov rcx, 16
    call font_measure_string
    mov [rel w_hi], rax
    mov [rel h_hi], rdx
    cmp qword [rel w_hello], rax
    jle .fail_meas_destroy

    ; Test 5: draw string
    mov rdi, 200
    mov rsi, 50
    call canvas_init
    test rax, rax
    jz .fail_draw_destroy
    mov [rel canvas_ptr], rax

    mov rdi, rax
    mov rsi, WHITE
    call canvas_clear

    mov rdi, [rel font_ptr]
    mov rsi, [rel canvas_ptr]
    mov rdx, 10
    mov rcx, 30
    lea r8, [rel txt_test]
    mov r9, 1
    sub rsp, 16
    mov qword [rsp], 16              ; pixel_size
    mov dword [rsp + 8], BLACK       ; color
    mov dword [rsp + 12], 0
    call font_draw_string
    add rsp, 16

    ; check at least one pixel changed from white
    xor r8d, r8d                     ; y
.scan_y:
    cmp r8d, 50
    jae .fail_draw_canvas
    xor r9d, r9d                     ; x
.scan_x:
    cmp r9d, 200
    jae .next_scan_row
    mov rdi, [rel canvas_ptr]
    mov rsi, r9
    mov rdx, r8
    call canvas_get_pixel
    cmp eax, WHITE
    jne .draw_ok
    inc r9d
    jmp .scan_x
.next_scan_row:
    inc r8d
    jmp .scan_y

.draw_ok:
    mov rdi, [rel canvas_ptr]
    call canvas_destroy
    mov qword [rel canvas_ptr], 0

    mov rdi, [rel font_ptr]
    call font_destroy
    mov qword [rel font_ptr], 0

    write_stdout pass_msg, pass_len
    xor rdi, rdi
    call hal_exit

.fail_load_destroy:
    mov rdi, [rel font_ptr]
    test rdi, rdi
    jz .fail_load
    call font_destroy
    mov qword [rel font_ptr], 0
    jmp .fail_load

.fail_cmap_destroy:
    mov rdi, [rel font_ptr]
    test rdi, rdi
    jz .fail_cmap
    call font_destroy
    mov qword [rel font_ptr], 0
    jmp .fail_cmap

.fail_rast_destroy:
    mov rdi, [rel font_ptr]
    test rdi, rdi
    jz .fail_rast
    call font_destroy
    mov qword [rel font_ptr], 0
    jmp .fail_rast

.fail_meas_destroy:
    mov rdi, [rel font_ptr]
    test rdi, rdi
    jz .fail_meas
    call font_destroy
    mov qword [rel font_ptr], 0
    jmp .fail_meas

.fail_draw_destroy:
    mov rdi, [rel font_ptr]
    test rdi, rdi
    jz .fail_draw
    call font_destroy
    mov qword [rel font_ptr], 0
    jmp .fail_draw

.fail_cache_destroy:
    mov rdi, [rel font_ptr]
    test rdi, rdi
    jz .fail_cache
    call font_destroy
    mov qword [rel font_ptr], 0
    jmp .fail_cache

.fail_draw_canvas:
    mov rdi, [rel canvas_ptr]
    test rdi, rdi
    jz .after_canvas_destroy
    call canvas_destroy
    mov qword [rel canvas_ptr], 0
.after_canvas_destroy:
    mov rdi, [rel font_ptr]
    test rdi, rdi
    jz .fail_draw
    call font_destroy
    mov qword [rel font_ptr], 0
    jmp .fail_draw

.fail_load:
    fail_exit fail_load_msg, fail_load_len
.fail_cmap:
    fail_exit fail_cmap_msg, fail_cmap_len
.fail_rast:
    fail_exit fail_rast_msg, fail_rast_len
.fail_meas:
    fail_exit fail_meas_msg, fail_meas_len
.fail_draw:
    fail_exit fail_draw_msg, fail_draw_len
.fail_cache:
    fail_exit fail_cache_msg, fail_cache_len
