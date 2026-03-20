; test_canvas.asm
; Unit tests for AuraCanvas rasterizer/text/simd modules
; Author: Aura Shell Team
; Date: 2026-03-20

extern hal_write
extern hal_exit
extern canvas_init
extern canvas_destroy
extern canvas_clear
extern canvas_put_pixel
extern canvas_get_pixel
extern canvas_fill_rect
extern canvas_fill_rect_simd
extern canvas_draw_string
extern canvas_has_sse2

%define WHITE        0xFFFFFFFF
%define BLACK        0xFF000000
%define RED          0xFFFF0000
%define GREEN        0xFF00FF00
%define BLUE         0xFF0000FF
%define TEST_CLEAR   0xFF112233

section .data
    txt_abc          db "ABC"
    txt_abc_len      equ $ - txt_abc

    pass_msg         db "ALL TESTS PASSED", 10
    pass_len         equ $ - pass_msg

    fail_clear_msg   db "TEST FAILED: canvas_clear", 10
    fail_clear_len   equ $ - fail_clear_msg
    fail_fill_msg    db "TEST FAILED: canvas_fill_rect", 10
    fail_fill_len    equ $ - fail_fill_msg
    fail_clip_msg    db "TEST FAILED: canvas_clipping", 10
    fail_clip_len    equ $ - fail_clip_msg
    fail_text_msg    db "TEST FAILED: canvas_text", 10
    fail_text_len    equ $ - fail_text_msg
    fail_simd_msg    db "TEST FAILED: canvas_simd", 10
    fail_simd_len    equ $ - fail_simd_msg

section .bss
    cv_ptr           resq 1
    pixel_before     resq 1
    pixel_after      resq 1

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
    mov rdi, 100
    mov rsi, 100
    call canvas_init
    test rax, rax
    jz .fail_clear
    mov [rel cv_ptr], rax

    ; Test 1: clear
    mov rdi, [rel cv_ptr]
    mov rsi, TEST_CLEAR
    call canvas_clear
    mov rdi, [rel cv_ptr]
    xor rsi, rsi
    xor rdx, rdx
    call canvas_get_pixel
    cmp eax, TEST_CLEAR
    jne .fail_clear_destroy
    mov rdi, [rel cv_ptr]
    mov rsi, 99
    mov rdx, 99
    call canvas_get_pixel
    cmp eax, TEST_CLEAR
    jne .fail_clear_destroy

    ; Test 2: fill rect
    mov rdi, [rel cv_ptr]
    mov rsi, WHITE
    call canvas_clear
    mov rdi, [rel cv_ptr]
    mov rsi, 10
    mov rdx, 10
    mov rcx, 20
    mov r8, 20
    mov r9, RED
    call canvas_fill_rect
    mov rdi, [rel cv_ptr]
    mov rsi, 15
    mov rdx, 15
    call canvas_get_pixel
    cmp eax, RED
    jne .fail_fill_destroy
    mov rdi, [rel cv_ptr]
    mov rsi, 5
    mov rdx, 5
    call canvas_get_pixel
    cmp eax, WHITE
    jne .fail_fill_destroy

    ; Test 3: clipping
    mov rdi, [rel cv_ptr]
    mov rsi, -10
    mov rdx, -10
    mov rcx, 30
    mov r8, 30
    mov r9, BLUE
    call canvas_fill_rect
    mov rdi, [rel cv_ptr]
    xor rsi, rsi
    xor rdx, rdx
    call canvas_get_pixel
    cmp eax, BLUE
    jne .fail_clip_destroy
    mov rdi, [rel cv_ptr]
    mov rsi, 90
    mov rdx, 90
    mov rcx, 30
    mov r8, 30
    mov r9, BLUE
    call canvas_fill_rect
    mov rdi, [rel cv_ptr]
    mov rsi, 99
    mov rdx, 99
    call canvas_get_pixel
    cmp eax, BLUE
    jne .fail_clip_destroy

    ; Test 4: text
    mov rdi, [rel cv_ptr]
    mov rsi, GREEN
    call canvas_clear
    mov rdi, [rel cv_ptr]
    xor rsi, rsi
    xor rdx, rdx
    call canvas_get_pixel
    mov [rel pixel_before], rax

    mov rdi, [rel cv_ptr]
    xor rsi, rsi
    xor rdx, rdx
    lea rcx, [rel txt_abc]
    mov r8, txt_abc_len
    mov r9, WHITE
    sub rsp, 8
    xor rax, rax
    mov eax, BLACK
    mov [rsp], rax
    call canvas_draw_string
    add rsp, 8

    mov rdi, [rel cv_ptr]
    xor rsi, rsi
    xor rdx, rdx
    call canvas_get_pixel
    mov [rel pixel_after], rax
    mov rax, [rel pixel_before]
    cmp rax, [rel pixel_after]
    je .fail_text_destroy

    mov rdi, [rel cv_ptr]
    mov rsi, 24
    xor rdx, rdx
    call canvas_get_pixel
    mov edx, BLACK
    cmp eax, edx
    jne .fail_text_destroy

    ; Test 5: SIMD fill (if available)
    call canvas_has_sse2
    cmp eax, 1
    jne .finish

    mov rdi, [rel cv_ptr]
    mov rsi, 0
    mov rdx, 0
    mov rcx, 100
    mov r8, 100
    mov r9, GREEN
    call canvas_fill_rect_simd

    ; check sample points
    mov rdi, [rel cv_ptr]
    mov rsi, 0
    mov rdx, 0
    call canvas_get_pixel
    cmp eax, GREEN
    jne .fail_simd_destroy
    mov rdi, [rel cv_ptr]
    mov rsi, 11
    mov rdx, 7
    call canvas_get_pixel
    cmp eax, GREEN
    jne .fail_simd_destroy
    mov rdi, [rel cv_ptr]
    mov rsi, 23
    mov rdx, 19
    call canvas_get_pixel
    cmp eax, GREEN
    jne .fail_simd_destroy
    mov rdi, [rel cv_ptr]
    mov rsi, 37
    mov rdx, 29
    call canvas_get_pixel
    cmp eax, GREEN
    jne .fail_simd_destroy
    mov rdi, [rel cv_ptr]
    mov rsi, 48
    mov rdx, 31
    call canvas_get_pixel
    cmp eax, GREEN
    jne .fail_simd_destroy
    mov rdi, [rel cv_ptr]
    mov rsi, 59
    mov rdx, 43
    call canvas_get_pixel
    cmp eax, GREEN
    jne .fail_simd_destroy
    mov rdi, [rel cv_ptr]
    mov rsi, 64
    mov rdx, 52
    call canvas_get_pixel
    cmp eax, GREEN
    jne .fail_simd_destroy
    mov rdi, [rel cv_ptr]
    mov rsi, 73
    mov rdx, 67
    call canvas_get_pixel
    cmp eax, GREEN
    jne .fail_simd_destroy
    mov rdi, [rel cv_ptr]
    mov rsi, 88
    mov rdx, 76
    call canvas_get_pixel
    cmp eax, GREEN
    jne .fail_simd_destroy
    mov rdi, [rel cv_ptr]
    mov rsi, 99
    mov rdx, 99
    call canvas_get_pixel
    cmp eax, GREEN
    jne .fail_simd_destroy

    ; Compare with scalar fill result
    mov rdi, [rel cv_ptr]
    mov rsi, RED
    call canvas_clear
    mov rdi, [rel cv_ptr]
    mov rsi, 0
    mov rdx, 0
    mov rcx, 100
    mov r8, 100
    mov r9, GREEN
    call canvas_fill_rect
    mov rdi, [rel cv_ptr]
    mov rsi, 73
    mov rdx, 67
    call canvas_get_pixel
    cmp eax, GREEN
    jne .fail_simd_destroy

.finish:
    mov rdi, [rel cv_ptr]
    call canvas_destroy
    write_stdout pass_msg, pass_len
    xor rdi, rdi
    call hal_exit

.fail_clear_destroy:
    mov rdi, [rel cv_ptr]
    call canvas_destroy
.fail_clear:
    fail_exit fail_clear_msg, fail_clear_len

.fail_fill_destroy:
    mov rdi, [rel cv_ptr]
    call canvas_destroy
.fail_fill:
    fail_exit fail_fill_msg, fail_fill_len

.fail_clip_destroy:
    mov rdi, [rel cv_ptr]
    call canvas_destroy
.fail_clip:
    fail_exit fail_clip_msg, fail_clip_len

.fail_text_destroy:
    mov rdi, [rel cv_ptr]
    call canvas_destroy
.fail_text:
    fail_exit fail_text_msg, fail_text_len

.fail_simd_destroy:
    mov rdi, [rel cv_ptr]
    call canvas_destroy
.fail_simd:
    fail_exit fail_simd_msg, fail_simd_len
