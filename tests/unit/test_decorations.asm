; test_decorations.asm — decorations/cursor/compositor_render integration
%include "src/hal/linux_x86_64/defs.inc"
%include "src/compositor/compositor.inc"
%include "src/canvas/canvas.inc"

extern hal_write
extern hal_exit
extern canvas_init
extern canvas_destroy
extern canvas_get_pixel
extern canvas_clear
extern decoration_init
extern decoration_render
extern decoration_hit_test
extern cursor_init
extern cursor_update_pos
extern cursor_render
extern compositor_render

%define DECO_HIT_CLOSE                1
%define DECO_HIT_TITLEBAR             4
%define DECO_HIT_CLIENT               5

section .data
    pass_msg        db "ALL TESTS PASSED", 10
    pass_len        equ $ - pass_msg
    fail_t1         db "FAIL: t1 decoration render", 10
    fail_t1_len     equ $ - fail_t1
    fail_t2         db "FAIL: t2 hit-test", 10
    fail_t2_len     equ $ - fail_t2
    fail_t3         db "FAIL: t3 cursor", 10
    fail_t3_len     equ $ - fail_t3
    fail_t4         db "FAIL: t4 compositor flow", 10
    fail_t4_len     equ $ - fail_t4
    title_text      db "Term", 0

section .bss
    surf            resb SF_STRUCT_SIZE
    deco_ptr        resq 1
    canvas_ptr      resq 1
    server          resb CS_STRUCT_SIZE
    client          resb CC_STRUCT_SIZE
    clients_arr     resq 1
    resource        resb RES_STRUCT_SIZE
    buffer          resb BUF_STRUCT_SIZE
    pixels          resd 100 * 100

section .text
global _start

%macro write_stdout 2
    mov rdi, STDOUT
    lea rsi, [rel %1]
    mov rdx, %2
    call hal_write
%endmacro

%macro fail 2
    write_stdout %1, %2
    mov rdi, 1
    call hal_exit
%endmacro

zero_mem:
    ; zero_mem(ptr, bytes)
    push rdi
    mov rcx, rsi
    xor eax, eax
    rep stosb
    pop rdi
    ret

_start:
    ; base surface 400x300 at (40,50)
    lea rdi, [rel surf]
    mov rsi, SF_STRUCT_SIZE
    call zero_mem
    mov dword [rel surf + SF_SCREEN_X_OFF], 40
    mov dword [rel surf + SF_SCREEN_Y_OFF], 50
    mov dword [rel surf + SF_WIDTH_OFF], 400
    mov dword [rel surf + SF_HEIGHT_OFF], 300
    mov dword [rel surf + SF_TITLE_LEN_OFF], 4
    mov dword [rel surf + SF_MAPPED_OFF], 1
    mov dword [rel surf + SF_TITLE_OFF], 'mreT'

    ; TEST 1: decoration render changes title region
    mov rdi, 520
    mov rsi, 420
    call canvas_init
    test rax, rax
    jz .f1
    mov [rel canvas_ptr], rax
    mov rdi, rax
    mov esi, 0xFF101010
    call canvas_clear

    lea rdi, [rel surf]
    xor esi, esi
    call decoration_init
    test rax, rax
    jz .f1
    mov [rel deco_ptr], rax
    mov rdi, rax
    mov rsi, [rel canvas_ptr]
    xor edx, edx
    mov ecx, 1
    call decoration_render

    mov rdi, [rel canvas_ptr]
    mov esi, 60
    mov edx, 26
    call canvas_get_pixel
    mov r12d, eax
    mov rdi, [rel canvas_ptr]
    mov esi, 60
    mov edx, 110
    call canvas_get_pixel
    cmp r12d, eax
    je .f1

    ; TEST 2: hit test close/title/client
    mov rbx, [rel deco_ptr]
    mov esi, 420
    mov edx, 30
    mov rdi, rbx
    call decoration_hit_test
    cmp eax, DECO_HIT_CLOSE
    je .close_ok
    cmp eax, DECO_HIT_TITLEBAR
    jne .f2
.close_ok:

    mov esi, 100
    mov edx, 32
    mov rdi, rbx
    call decoration_hit_test
    cmp eax, DECO_HIT_TITLEBAR
    je .title_ok
    cmp eax, 8
    jne .f2
.title_ok:

    mov esi, 120
    mov edx, 140
    mov rdi, rbx
    call decoration_hit_test
    cmp eax, DECO_HIT_CLIENT
    jne .f2

    ; TEST 3: cursor render changes pixel
    call cursor_init
    mov rbx, rax
    mov rdi, [rel canvas_ptr]
    mov esi, 0xFF101010
    call canvas_clear
    mov rdi, rbx
    mov esi, 20
    mov edx, 20
    call cursor_update_pos
    mov rdi, rbx
    mov rsi, [rel canvas_ptr]
    call cursor_render
    mov rdi, [rel canvas_ptr]
    mov esi, 20
    mov edx, 20
    call canvas_get_pixel
    and eax, 0x00FFFFFF
    cmp eax, 0x00101010
    je .f3

    ; TEST 4: compositor_render draws decoration + content + cursor on top
    lea rdi, [rel server]
    mov rsi, CS_STRUCT_SIZE
    call zero_mem
    lea rdi, [rel client]
    mov rsi, CC_STRUCT_SIZE
    call zero_mem
    lea rdi, [rel resource]
    mov rsi, RES_STRUCT_SIZE
    call zero_mem
    lea rdi, [rel buffer]
    mov rsi, BUF_STRUCT_SIZE
    call zero_mem

    lea rax, [rel client]
    mov [rel clients_arr], rax
    lea rax, [rel clients_arr]
    mov [rel server + CS_CLIENTS_OFF], rax
    mov dword [rel server + CS_CLIENT_COUNT_OFF], 1

    lea rax, [rel resource]
    mov [rel client + CC_RESOURCES_OFF], rax
    mov dword [rel client + CC_RES_COUNT_OFF], 1
    mov dword [rel client + CC_SEND_LEN_OFF], 0

    mov dword [rel resource + RES_TYPE_OFF], RESOURCE_SURFACE
    lea rax, [rel surf]
    mov [rel resource + RES_DATA_OFF], rax

    lea rax, [rel buffer]
    mov [rel surf + SF_CURRENT_BUF_OFF], rax
    mov dword [rel surf + SF_SCREEN_X_OFF], 100
    mov dword [rel surf + SF_SCREEN_Y_OFF], 100
    mov dword [rel surf + SF_WIDTH_OFF], 100
    mov dword [rel surf + SF_HEIGHT_OFF], 100
    mov dword [rel surf + SF_MAPPED_OFF], 1

    lea rax, [rel pixels]
    mov [rel buffer + BUF_PIXELS_OFF], rax
    mov dword [rel buffer + BUF_WIDTH_OFF], 100
    mov dword [rel buffer + BUF_HEIGHT_OFF], 100
    mov dword [rel buffer + BUF_STRIDE_OFF], 400
    lea rdi, [rel pixels]
    mov ecx, 10000
    mov eax, 0xFFFF0000
    rep stosd

    call cursor_init
    mov rdi, rax
    mov esi, 0
    mov edx, 0
    call cursor_update_pos

    mov rdi, [rel canvas_ptr]
    mov esi, 0xFF000000
    call canvas_clear
    lea rdi, [rel server]
    mov rsi, [rel canvas_ptr]
    mov edx, 0xFF000000
    call compositor_render

    ; content pixel should be red
    mov rdi, [rel canvas_ptr]
    mov esi, 120
    mov edx, 120
    call canvas_get_pixel
    and eax, 0x00FFFFFF
    cmp eax, 0x00FF0000
    jne .f4

    ; title/deco region should differ from pure black
    mov rdi, [rel canvas_ptr]
    mov esi, 110
    mov edx, 78
    call canvas_get_pixel
    and eax, 0x00FFFFFF
    cmp eax, 0x00000000
    je .f4

    ; cursor at (0,0) should be visible
    mov rdi, [rel canvas_ptr]
    mov esi, 0
    mov edx, 0
    call canvas_get_pixel
    and eax, 0x00FFFFFF
    cmp eax, 0x00000000
    je .f4

    mov rdi, [rel canvas_ptr]
    call canvas_destroy
    write_stdout pass_msg, pass_len
    xor edi, edi
    call hal_exit

.f1:
    fail fail_t1, fail_t1_len
.f2:
    fail fail_t2, fail_t2_len
.f3:
    fail fail_t3, fail_t3_len
.f4:
    fail fail_t4, fail_t4_len
