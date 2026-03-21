; test_rendering.asm — gradients, rounded rect, blur, composite, clip

extern hal_write
extern hal_exit
extern canvas_init
extern canvas_destroy
extern canvas_clear
extern canvas_get_pixel
extern canvas_fill_rect
extern canvas_gradient_linear
extern canvas_fill_rounded_rect
extern canvas_box_blur
extern canvas_composite
extern canvas_push_clip
extern canvas_pop_clip
extern arena_init
extern arena_destroy
extern arena_alloc
extern canvas_blur_region

%define BLACK    0xFF000000
%define WHITE    0xFFFFFFFF
%define RED      0xFFFF0000
%define GREEN    0xFF00FF00
%define BLUE     0xFF0000FF
%define BLUE_A   0x800000FF

section .data
    pass_msg     db "ALL TESTS PASSED", 10
    pass_len     equ $ - pass_msg
    fail_g       db "FAIL: gradient", 10
    fail_g_len   equ $ - fail_g
    fail_r       db "FAIL: rounded", 10
    fail_r_len   equ $ - fail_r
    fail_b       db "FAIL: blur", 10
    fail_b_len   equ $ - fail_b
    fail_c       db "FAIL: composite", 10
    fail_c_len   equ $ - fail_c
    fail_k       db "FAIL: clip", 10
    fail_k_len   equ $ - fail_k

section .bss
    cv           resq 1
    cv2          resq 1
    arena        resq 1

section .text
global _start

%macro write_stdout 2
    mov rdi, 1
    lea rsi, [rel %1]
    mov rdx, %2
    call hal_write
%endmacro

%macro fail 2
    write_stdout %1, %2
    mov rdi, 1
    call hal_exit
%endmacro

_start:
    ; --- gradient ---
    mov rdi, 100
    mov rsi, 10
    call canvas_init
    test rax, rax
    jz .fg
    mov [rel cv], rax

    mov rdi, rax
    mov rsi, BLACK
    call canvas_clear

    mov rdi, [rel cv]
    xor esi, esi
    xor edx, edx
    mov ecx, 100
    mov r8d, 10
    mov r9d, RED
    mov rax, 0
    push rax
    mov rax, 0x00000000FF0000FF
    push rax
    call canvas_gradient_linear
    add rsp, 16

    mov rdi, [rel cv]
    xor esi, esi
    mov edx, 5
    call canvas_get_pixel
    mov ecx, eax
    shr ecx, 16
    and ecx, 0xFF
    cmp ecx, 200
    jl .fg
    mov rdi, [rel cv]
    mov esi, 99
    mov edx, 5
    call canvas_get_pixel
    mov ecx, eax
    and ecx, 0xFF
    cmp ecx, 200
    jl .fg
    mov rdi, [rel cv]
    mov esi, 50
    mov edx, 5
    call canvas_get_pixel
    mov ebx, eax
    shr ebx, 16
    and ebx, 0xFF
    mov ecx, eax
    and ecx, 0xFF
    cmp ebx, 80
    jl .fg
    cmp ecx, 80
    jl .fg

    mov rdi, [rel cv]
    call canvas_destroy

    ; --- rounded ---
    mov rdi, 100
    mov rsi, 100
    call canvas_init
    test rax, rax
    jz .fr
    mov [rel cv], rax
    mov rdi, rax
    mov rsi, BLACK
    call canvas_clear
    mov rdi, [rel cv]
    mov esi, 10
    mov edx, 10
    mov ecx, 80
    mov r8d, 80
    mov r9d, 15
    mov eax, 0xFFFFFFFF
    push rax
    call canvas_fill_rounded_rect
    add rsp, 8
    mov rdi, [rel cv]
    mov esi, 10
    mov edx, 10
    call canvas_get_pixel
    cmp eax, BLACK
    jne .fr
    mov rdi, [rel cv]
    mov esi, 25
    mov edx, 25
    call canvas_get_pixel
    cmp eax, WHITE
    jne .fr
    mov rdi, [rel cv]
    call canvas_destroy

    ; --- blur ---
    mov rdi, 100
    mov rsi, 100
    call canvas_init
    test rax, rax
    jz .fb
    mov [rel cv], rax
    mov rdi, rax
    mov rsi, BLACK
    call canvas_clear
    mov rdi, [rel cv]
    xor esi, esi
    xor edx, edx
    mov ecx, 50
    mov r8d, 100
    mov r9, BLACK
    call canvas_fill_rect
    mov rdi, [rel cv]
    mov esi, 50
    xor edx, edx
    mov ecx, 50
    mov r8d, 100
    mov r9, WHITE
    call canvas_fill_rect
    mov rdi, [rel cv]
    xor esi, esi
    xor edx, edx
    mov ecx, 100
    mov r8d, 100
    mov r9d, 5
    call canvas_box_blur
    cmp rax, 0
    jne .fb
    mov rdi, [rel cv]
    mov esi, 50
    mov edx, 50
    call canvas_get_pixel
    mov ebx, eax
    and ebx, 0xFF
    cmp ebx, 40
    jl .fb
    cmp ebx, 220
    ja .fb
    mov rdi, [rel cv]
    call canvas_destroy

    ; --- blur_region via arena ---
    mov rdi, 65536
    call arena_init
    test rax, rax
    jz .fb
    mov [rel arena], rax

    mov rdi, 32
    mov rsi, 32
    call canvas_init
    test rax, rax
    jz .fb
    mov [rel cv], rax
    mov rdi, rax
    mov rsi, WHITE
    call canvas_clear
    mov rdi, [rel cv]
    mov rsi, [rel arena]
    xor edx, edx
    xor ecx, ecx
    mov r8d, 32
    mov r9d, 32
    push qword 2
    call canvas_blur_region
    add rsp, 8
    cmp rax, 0
    jne .fb
    mov rdi, [rel cv]
    call canvas_destroy
    mov rdi, [rel arena]
    call arena_destroy

    ; --- composite ---
    mov rdi, 50
    mov rsi, 50
    call canvas_init
    test rax, rax
    jz .fc
    mov [rel cv], rax
    mov rdi, rax
    mov rsi, RED
    call canvas_clear

    mov rdi, 50
    mov rsi, 50
    call canvas_init
    test rax, rax
    jz .fc
    mov [rel cv2], rax
    mov rdi, rax
    mov rsi, BLUE_A
    call canvas_clear

    mov rdi, [rel cv]
    mov rsi, [rel cv2]
    xor edx, edx
    xor ecx, ecx
    call canvas_composite

    mov rdi, [rel cv]
    mov esi, 10
    mov edx, 10
    call canvas_get_pixel
    mov ebx, eax
    shr ebx, 16
    and ebx, 0xFF
    cmp ebx, 110
    jl .fc
    cmp ebx, 145
    ja .fc
    mov ecx, eax
    and ecx, 0xFF
    cmp ecx, 110
    jl .fc
    cmp ecx, 145
    ja .fc

    mov rdi, [rel cv]
    call canvas_destroy
    mov rdi, [rel cv2]
    call canvas_destroy

    ; --- clip ---
    mov rdi, 100
    mov rsi, 100
    call canvas_init
    test rax, rax
    jz .fk
    mov [rel cv], rax
    mov rdi, rax
    mov rsi, BLACK
    call canvas_clear
    mov rdi, [rel cv]
    mov esi, 10
    mov edx, 10
    mov ecx, 50
    mov r8d, 50
    call canvas_push_clip
    cmp rax, 0
    jne .fk
    mov rdi, [rel cv]
    xor esi, esi
    xor edx, edx
    mov ecx, 100
    mov r8d, 100
    mov r9, GREEN
    call canvas_fill_rect
    mov rdi, [rel cv]
    mov esi, 5
    mov edx, 5
    call canvas_get_pixel
    cmp eax, GREEN
    je .fk
    mov rdi, [rel cv]
    mov esi, 25
    mov edx, 25
    call canvas_get_pixel
    cmp eax, GREEN
    jne .fk
    mov rdi, [rel cv]
    call canvas_pop_clip
    cmp rax, 0
    jne .fk
    mov rdi, [rel cv]
    call canvas_destroy

    write_stdout pass_msg, pass_len
    xor edi, edi
    call hal_exit

.fg:
    fail fail_g, fail_g_len
.fr:
    fail fail_r, fail_r_len
.fb:
    fail fail_b, fail_b_len
.fc:
    fail fail_c, fail_c_len
.fk:
    fail fail_k, fail_k_len
