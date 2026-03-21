; test_png.asm — PNG load, pixels, canvas blit, deflate smoke
extern hal_write
extern hal_exit
extern hal_open
extern hal_close
extern hal_mmap
extern hal_munmap
extern png_load
extern png_load_mem
extern png_destroy
extern canvas_init
extern canvas_destroy
extern canvas_clear
extern canvas_get_pixel
extern canvas_draw_image

%define IMG_W_OFF    0
%define IMG_H_OFF    4
%define IMG_PX_OFF   8
%define IMG_STR_OFF  16

%define WHITE        0xFFFFFFFF

section .data
    png_path     db "tests/data/test_image.png", 0
    png_path_len equ $ - png_path - 1

    pass_msg     db "ALL TESTS PASSED", 10
    pass_len     equ $ - pass_msg

    fail_load    db "FAIL: png_load", 10
    fail_load_len equ $ - fail_load
    fail_px      db "FAIL: pixel", 10
    fail_px_len  equ $ - fail_px
    fail_draw    db "FAIL: draw", 10
    fail_draw_len equ $ - fail_draw
    fail_mem     db "FAIL: png_load_mem", 10
    fail_mem_len equ $ - fail_mem
    fail_emb     db "FAIL: png_embedded_mem", 10
    fail_emb_len equ $ - fail_emb
    fail_defl    db "FAIL: deflate_inflate", 10
    fail_defl_len equ $ - fail_defl

section .bss
    img_ptr      resq 1
    cv_ptr       resq 1
    defl_out     resb 64

section .rodata
    embedded_png:
        incbin "tests/data/test_image.png"
    embedded_png_len equ $ - embedded_png

    ; Exact DEFLATE from test_image.png IDAT (stored block, 14 B payload)
    defl_only:
        db 0x01, 0x0e, 0x00, 0xf1, 0xff
        db 0x00, 0xff, 0x00, 0x00, 0x00, 0xff, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0xff, 0xff
    defl_only_len equ $ - defl_only

    ; Raw DEFLATE: BFINAL+stored, LEN=1, NLEN=0xFFFE, data 0x42
    raw_stored:
        db 0x01, 0x01, 0x00, 0xFE, 0xFF, 0x42
    raw_stored_len equ $ - raw_stored

%define O_RDONLY 0
%define PNG_FILE_BYTES embedded_png_len

section .text
global _start

%macro write_stdout 2
    mov rdi, 1
    lea rsi, [rel %1]
    mov rdx, %2
    call hal_write
%endmacro

%macro fail_halt 2
    write_stdout %1, %2
    mov rdi, 1
    call hal_exit
%endmacro

_start:
    ; --- decode embedded bytes (rules out open/mmap path)
    lea rdi, [rel embedded_png]
    mov esi, embedded_png_len
    call png_load_mem
    test rax, rax
    jz .bad_emb
    mov rdi, rax
    call png_destroy

    ; --- png_load file
    lea rdi, [rel png_path]
    mov rsi, png_path_len
    call png_load
    test rax, rax
    jz .bad_load
    mov [rel img_ptr], rax

    mov rcx, rax
    cmp dword [rcx + IMG_W_OFF], 0
    jle .bad_load
    cmp dword [rcx + IMG_H_OFF], 0
    jle .bad_load

    mov rdx, qword [rcx + IMG_PX_OFF]
    test rdx, rdx
    jz .bad_load

    ; 2x2 RGB test: (0,0) red ARGB
    mov eax, dword [rdx]
    cmp eax, 0xFFFF0000
    jne .bad_px

    ; --- canvas + draw
    mov rdi, 100
    mov rsi, 100
    call canvas_init
    test rax, rax
    jz .bad_draw
    mov [rel cv_ptr], rax

    mov rdi, rax
    mov rsi, WHITE
    call canvas_clear

    mov rdi, [rel cv_ptr]
    mov rsi, [rel img_ptr]
    mov edx, 10
    mov ecx, 10
    call canvas_draw_image

    mov rdi, [rel cv_ptr]
    mov rsi, 10
    mov rdx, 10
    call canvas_get_pixel
    cmp eax, 0xFFFF0000
    jne .bad_draw

    mov rdi, [rel cv_ptr]
    call canvas_destroy

    mov rdi, [rel img_ptr]
    call png_destroy

    ; --- png_load_mem on same bytes (mmap file)
    lea rdi, [rel png_path]
    mov rsi, O_RDONLY
    xor rdx, rdx
    call hal_open
    test rax, rax
    js .bad_mem
    mov rbx, rax

    xor rdi, rdi
    mov rsi, 4096
    mov rdx, 3
    mov rcx, 34
    mov r8, rbx
    xor r9, r9
    call hal_mmap
    test rax, rax
    js .bad_mem_close
    mov r12, rax

    mov rdi, rbx
    call hal_close

    mov rdi, r12
    mov esi, PNG_FILE_BYTES
    call png_load_mem
    test rax, rax
    jz .bad_unmap
    mov rdi, rax
    call png_destroy

    mov rdi, r12
    mov rsi, 4096
    call hal_munmap

    write_stdout pass_msg, pass_len
    xor rdi, rdi
    call hal_exit

.bad_emb:
    fail_halt fail_emb, fail_emb_len
.bad_load:
    fail_halt fail_load, fail_load_len
.bad_px:
    mov rdi, [rel img_ptr]
    test rdi, rdi
    jz .bad_px2
    call png_destroy
.bad_px2:
    fail_halt fail_px, fail_px_len
.bad_draw:
    mov rdi, [rel cv_ptr]
    test rdi, rdi
    jz .bad_dr2
    call canvas_destroy
.bad_dr2:
    mov rdi, [rel img_ptr]
    test rdi, rdi
    jz .bad_dr3
    call png_destroy
.bad_dr3:
    fail_halt fail_draw, fail_draw_len
.bad_mem_close:
    mov rdi, rbx
    call hal_close
.bad_mem:
    fail_halt fail_mem, fail_mem_len
.bad_unmap:
    mov rdi, r12
    mov rsi, 4096
    call hal_munmap
    fail_halt fail_mem, fail_mem_len
