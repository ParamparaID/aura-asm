; test_workspaces.asm — unit tests for workspaces/hub/overview
%include "src/hal/platform_defs.inc"
%include "src/compositor/compositor.inc"
%include "src/compositor/workspaces.inc"

extern hal_write
extern hal_exit
extern workspaces_init
extern workspaces_switch
extern workspaces_move_surface
extern hub_toggle
extern hub_get_global
extern overview_enter
extern overview_debug_get_count
extern overview_debug_get_item

section .data
    pass_msg        db "ALL TESTS PASSED", 10
    pass_len        equ $ - pass_msg
    fail_t1         db "FAIL: t1 init", 10
    fail_t1_len     equ $ - fail_t1
    fail_t2         db "FAIL: t2 switch", 10
    fail_t2_len     equ $ - fail_t2
    fail_t3         db "FAIL: t3 move surface", 10
    fail_t3_len     equ $ - fail_t3
    fail_t4         db "FAIL: t4 hub toggle", 10
    fail_t4_len     equ $ - fail_t4
    fail_t5         db "FAIL: t5 overview grid", 10
    fail_t5_len     equ $ - fail_t5

section .bss
    mgr_ptr         resq 1
    surf1           resb SF_STRUCT_SIZE
    surf2           resb SF_STRUCT_SIZE
    surf3           resb SF_STRUCT_SIZE
    item0_ptr       resq 1
    item1_ptr       resq 1

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
    push rdi
    mov ecx, SF_STRUCT_SIZE / 8
    xor eax, eax
    rep stosq
    pop rdi
    ret

ws_ptr:
    ; ws_ptr(mgr, idx) -> rax
    mov eax, esi
    imul eax, WS_STRUCT_SIZE
    lea rax, [rdi + WSM_WORKSPACES_OFF + rax]
    ret

_start:
    ; TEST 1: init
    mov edi, 4
    call workspaces_init
    test rax, rax
    jz .f1
    mov [rel mgr_ptr], rax
    cmp dword [rax + WSM_COUNT_OFF], 4
    jne .f1
    cmp dword [rax + WSM_ACTIVE_IDX_OFF], 0
    jne .f1

    ; prepare surfaces
    lea rdi, [rel surf1]
    call clear_surface
    lea rdi, [rel surf2]
    call clear_surface
    lea rdi, [rel surf3]
    call clear_surface

    ; TEST 2: switch
    mov rdi, [rel mgr_ptr]
    mov esi, 2
    call workspaces_switch
    cmp eax, 1
    jne .f2
    mov rax, [rel mgr_ptr]
    cmp dword [rax + WSM_ACTIVE_IDX_OFF], 2
    jne .f2
    cmp dword [rax + WSM_PREV_IDX_OFF], 0
    jne .f2
    cmp dword [rax + WSM_TRANSITIONING_OFF], 1
    jne .f2

    ; TEST 3: move surface 0 -> 2
    mov rdi, [rel mgr_ptr]
    lea rsi, [rel surf1]
    mov edx, 0
    call workspaces_move_surface
    mov rdi, [rel mgr_ptr]
    lea rsi, [rel surf1]
    mov edx, 2
    call workspaces_move_surface
    cmp eax, 1
    jne .f3
    mov rdi, [rel mgr_ptr]
    xor esi, esi
    call ws_ptr
    cmp dword [rax + WS_SURFACE_COUNT_OFF], 0
    jne .f3
    mov rdi, [rel mgr_ptr]
    mov esi, 2
    call ws_ptr
    cmp dword [rax + WS_SURFACE_COUNT_OFF], 1
    jne .f3

    ; TEST 4: hub toggle on/off
    mov rdi, [rel mgr_ptr]
    call hub_toggle
    cmp eax, 1
    jne .f4
    call hub_get_global
    cmp dword [rax + HUB_ACTIVE_OFF], 1
    jne .f4
    mov rdi, [rel mgr_ptr]
    call hub_toggle
    cmp eax, 0
    jne .f4
    call hub_get_global
    cmp dword [rax + HUB_ACTIVE_OFF], 0
    jne .f4

    ; TEST 5: overview grid on current workspace
    mov rdi, [rel mgr_ptr]
    lea rsi, [rel surf2]
    mov edx, 2
    call workspaces_move_surface
    mov rdi, [rel mgr_ptr]
    lea rsi, [rel surf3]
    mov edx, 2
    call workspaces_move_surface
    mov rdi, [rel mgr_ptr]
    xor rsi, rsi
    call overview_enter
    mov rax, [rel mgr_ptr]
    cmp dword [rax + WSM_OVERVIEW_MODE_OFF], 1
    jne .f5
    call overview_debug_get_count
    cmp eax, 3
    jne .f5
    mov edi, 0
    call overview_debug_get_item
    mov [rel item0_ptr], rax
    mov edi, 1
    call overview_debug_get_item
    mov [rel item1_ptr], rax
    mov rax, [rel item0_ptr]
    mov rdx, [rel item1_ptr]
    test rax, rax
    jz .f5
    test rdx, rdx
    jz .f5
    mov ecx, [rax + OV_THUMB_X_OFF]
    cmp ecx, [rdx + OV_THUMB_X_OFF]
    je .f5

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
.f5:
    fail fail_t5, fail_t5_len
