; test_wm.asm — unit tests for hybrid window manager
%include "src/hal/platform_defs.inc"
%include "src/compositor/compositor.inc"
%include "src/compositor/wm.inc"

extern hal_write
extern hal_exit
extern wm_init
extern wm_add_surface
extern wm_remove_surface
extern wm_set_focus
extern wm_get_focused
extern wm_set_surface_mode
extern floating_start_drag
extern floating_update_drag
extern floating_end_drag
extern floating_snap_check
extern tiling_find_neighbor

section .data
    pass_msg        db "ALL TESTS PASSED", 10
    pass_len        equ $ - pass_msg
    fail_t1         db "FAIL: t1 add/tiling", 10
    fail_t1_len     equ $ - fail_t1
    fail_t1w        db "FAIL: t1 width/height not set", 10
    fail_t1w_len    equ $ - fail_t1w
    fail_t1x        db "FAIL: t1 x split not applied", 10
    fail_t1x_len    equ $ - fail_t1x
    fail_t1y        db "FAIL: t1 y split not applied", 10
    fail_t1y_len    equ $ - fail_t1y
    fail_t2         db "FAIL: t2 remove", 10
    fail_t2_len     equ $ - fail_t2
    fail_t3         db "FAIL: t3 focus/neighbor", 10
    fail_t3_len     equ $ - fail_t3
    fail_t4         db "FAIL: t4 floating drag", 10
    fail_t4_len     equ $ - fail_t4
    fail_t5         db "FAIL: t5 snap", 10
    fail_t5_len     equ $ - fail_t5

section .bss
    wm_ptr          resq 1
    surf1           resb SF_STRUCT_SIZE
    surf2           resb SF_STRUCT_SIZE
    surf3           resb SF_STRUCT_SIZE
    x_before        resd 1

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

clear_surface:
    ; rdi = surface ptr
    push rdi
    mov ecx, SF_STRUCT_SIZE / 4
    xor eax, eax
    rep stosd
    pop rdi
    ret

_start:
    ; init wm 1200x800 gap=10
    mov edi, 1200
    mov esi, 800
    mov edx, 10
    call wm_init
    test rax, rax
    jz .f1
    mov [rel wm_ptr], rax

    ; prepare surfaces
    lea rdi, [rel surf1]
    call clear_surface
    lea rdi, [rel surf2]
    call clear_surface
    lea rdi, [rel surf3]
    call clear_surface
    mov dword [rel surf1 + SF_ID_OFF], 101
    mov dword [rel surf2 + SF_ID_OFF], 102
    mov dword [rel surf3 + SF_ID_OFF], 103

    ; TEST 1: add 3 surfaces in tiling
    mov rdi, [rel wm_ptr]
    lea rsi, [rel surf1]
    call wm_add_surface
    mov rdi, [rel wm_ptr]
    lea rsi, [rel surf2]
    call wm_add_surface
    mov rdi, [rel wm_ptr]
    lea rsi, [rel surf3]
    call wm_add_surface

    mov rax, [rel wm_ptr]
    cmp dword [rax + WM_SURFACE_COUNT_OFF], 3
    jne .f1
    cmp dword [rel surf1 + SF_WIDTH_OFF], 0
    jle .f1w
    cmp dword [rel surf2 + SF_WIDTH_OFF], 0
    jle .f1w
    cmp dword [rel surf3 + SF_WIDTH_OFF], 0
    jle .f1w
    cmp dword [rel surf1 + SF_HEIGHT_OFF], 0
    jle .f1w
    cmp dword [rel surf2 + SF_HEIGHT_OFF], 0
    jle .f1w
    cmp dword [rel surf3 + SF_HEIGHT_OFF], 0
    jle .f1w
    mov eax, dword [rel surf2 + SF_SCREEN_X_OFF]
    cmp eax, dword [rel surf1 + SF_SCREEN_X_OFF]
    je .f1x
    mov eax, dword [rel surf2 + SF_SCREEN_Y_OFF]
    cmp eax, dword [rel surf3 + SF_SCREEN_Y_OFF]
    je .f1y

    ; TEST 3: neighbor + focus stack (before remove)
    mov rdi, [rel wm_ptr]
    mov rdi, [rdi + WM_TILING_ROOT_OFF]
    lea rsi, [rel surf1]
    mov edx, WM_DIR_RIGHT
    call tiling_find_neighbor
    cmp rax, 0
    je .f3
    lea rcx, [rel surf2]
    cmp rax, rcx
    jne .f3
    mov rdi, [rel wm_ptr]
    lea rsi, [rel surf2]
    call wm_set_focus
    mov rdi, [rel wm_ptr]
    call wm_get_focused
    lea rcx, [rel surf2]
    cmp rax, rcx
    jne .f3

    ; TEST 2: remove middle surface, relayout
    mov rdi, [rel wm_ptr]
    lea rsi, [rel surf2]
    call wm_remove_surface
    mov rax, [rel wm_ptr]
    cmp dword [rax + WM_SURFACE_COUNT_OFF], 2
    jne .f2
    cmp dword [rel surf2 + SF_MAPPED_OFF], 0
    jne .f2
    cmp dword [rel surf1 + SF_WIDTH_OFF], 0
    jle .f2
    cmp dword [rel surf3 + SF_WIDTH_OFF], 0
    jle .f2

    ; TEST 4: floating mode + drag
    mov rdi, [rel wm_ptr]
    lea rsi, [rel surf1]
    mov edx, WM_MODE_FLOATING
    call wm_set_surface_mode
    mov eax, dword [rel surf1 + SF_SCREEN_X_OFF]
    mov dword [rel x_before], eax
    mov rdi, [rel wm_ptr]
    lea rsi, [rel surf1]
    mov edx, dword [rel surf1 + SF_SCREEN_X_OFF]
    mov ecx, dword [rel surf1 + SF_SCREEN_Y_OFF]
    call floating_start_drag
    mov rdi, [rel wm_ptr]
    mov esi, dword [rel surf1 + SF_SCREEN_X_OFF]
    add esi, 50
    mov edx, dword [rel surf1 + SF_SCREEN_Y_OFF]
    add edx, 50
    call floating_update_drag
    mov rdi, [rel wm_ptr]
    call floating_end_drag
    mov eax, dword [rel surf1 + SF_SCREEN_X_OFF]
    sub eax, dword [rel x_before]
    cmp eax, 40
    jl .f4

    ; TEST 5: snap-to-left edge
    mov dword [rel surf1 + SF_SCREEN_X_OFF], 5
    mov rdi, [rel wm_ptr]
    lea rsi, [rel surf1]
    call floating_snap_check
    cmp dword [rel surf1 + SF_SCREEN_X_OFF], 0
    jne .f5

    write_stdout pass_msg, pass_len
    xor edi, edi
    call hal_exit

.f1:
    fail fail_t1, fail_t1_len
.f1w:
    fail fail_t1w, fail_t1w_len
.f1x:
    fail fail_t1x, fail_t1x_len
.f1y:
    fail fail_t1y, fail_t1y_len
.f2:
    fail fail_t2, fail_t2_len
.f3:
    fail fail_t3, fail_t3_len
.f4:
    fail fail_t4, fail_t4_len
.f5:
    fail fail_t5, fail_t5_len
