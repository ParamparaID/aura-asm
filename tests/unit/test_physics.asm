; test_physics.asm — spring, inertia, snap, anim scheduler
%include "src/hal/platform_defs.inc"

extern hal_write
extern hal_exit
extern fp_from_int
extern spring_init
extern spring_update
extern spring_value
extern spring_is_settled
extern inertia_init
extern inertia_fling
extern inertia_update
extern inertia_value
extern inertia_is_settled
extern snap_init
extern snap_nearest
extern anim_scheduler_init
extern anim_scheduler_add
extern anim_scheduler_tick

%define FP_DT_60  1092
%define FP_DT_SUB 273

section .data
    pass_msg    db "ALL TESTS PASSED", 10
    pass_len    equ $ - pass_msg
    f1          db "FAIL: spring converge", 10
    f1l         equ $ - f1
    f2          db "FAIL: spring overshoot", 10
    f2l         equ $ - f2
    f3          db "FAIL: inertia decel", 10
    f3l         equ $ - f3
    f4          db "FAIL: inertia bounce", 10
    f4l         equ $ - f4
    f5          db "FAIL: snap", 10
    f5l         equ $ - f5
    f6          db "FAIL: scheduler", 10
    f6l         equ $ - f6

section .bss
    spring_a    resb 32
    spring_b    resb 32
    spring_c    resb 32
    inertia_a   resb 32
    snap_pts    resd 8
    snap_cfg    resq 4
    sched       resb 1200

section .text
global _start

%macro die 2
    mov rdi, 1
    lea rsi, [rel %1]
    mov rdx, %2
    call hal_write
    mov rdi, 1
    call hal_exit
%endmacro

_start:
    ; --- Test 1: spring convergence ---
    lea rdi, [rel spring_a]
    xor esi, esi
    mov edi, 100
    call fp_from_int
    mov edx, eax
    mov edi, 200
    call fp_from_int
    mov ecx, eax
    mov edi, 20
    call fp_from_int
    mov r8d, eax
    lea rdi, [rel spring_a]
    call spring_init

    mov ecx, 1000
.t1:
    jecxz .t1_done
    lea rdi, [rel spring_a]
    mov esi, FP_DT_60
    call spring_update
    dec ecx
    jmp .t1
.t1_done:
    lea rdi, [rel spring_a]
    call spring_is_settled
    cmp eax, 1
    jne .bad1

    lea rdi, [rel spring_a]
    call spring_value
    mov ebx, eax
    mov eax, [rel spring_a + 8]
    sub eax, ebx
    mov edi, eax
    call abs32
    cmp eax, 1
    jae .bad1
    jmp .t2
.bad1:
    die f1, f1l

    ; --- Test 2: overshoot then settle ---
.t2:
    lea rdi, [rel spring_b]
    xor esi, esi
    mov edi, 100
    call fp_from_int
    mov edx, eax
    mov edi, 300
    call fp_from_int
    mov ecx, eax
    mov edi, 14
    call fp_from_int
    mov r8d, eax
    lea rdi, [rel spring_b]
    call spring_init
    mov edi, 120
    call fp_from_int
    mov dword [rel spring_b + 4], eax

    xor r12d, r12d
    xor r14d, r14d
.t2l:
    cmp r14d, 40000
    jae .bad2
    lea rdi, [rel spring_b]
    mov esi, FP_DT_SUB
    call spring_update
    lea rdi, [rel spring_b]
    call spring_value
    mov ebx, eax
    mov edi, 100
    call fp_from_int
    cmp ebx, eax
    jle .t2n
    mov r12d, 1
.t2n:
    lea rdi, [rel spring_b]
    call spring_is_settled
    cmp eax, 1
    je .t2done
    inc r14d
    jmp .t2l
.t2done:
    cmp r12d, 1
    jne .bad2
    lea rdi, [rel spring_b]
    call spring_value
    mov ebx, eax
    mov edi, 100
    call fp_from_int
    sub ebx, eax
    mov edi, ebx
    call abs32
    cmp eax, 0x30000
    jae .bad2
    jmp .t3
.bad2:
    die f2, f2l

    ; --- Test 3: inertia ---
.t3:
    lea rbx, [rel inertia_a]
    xor esi, esi
    mov edi, -1000
    call fp_from_int
    mov edx, eax
    mov edi, 1000
    call fp_from_int
    mov ecx, eax
    mov r8d, 62259
    mov rdi, rbx
    call inertia_init

    mov edi, 500
    call fp_from_int
    mov esi, eax
    lea rdi, [rel inertia_a]
    call inertia_fling

    mov r15d, 800
.t3l:
    test r15d, r15d
    jz .t3c
    lea rdi, [rel inertia_a]
    mov esi, FP_DT_60
    call inertia_update
    dec r15d
    jmp .t3l
.t3c:
    lea rdi, [rel inertia_a]
    call inertia_is_settled
    cmp eax, 1
    jne .bad3
    mov eax, [rel inertia_a + 4]
    mov edi, eax
    call abs32
    cmp eax, 512
    ja .bad3
    jmp .t4
.bad3:
    die f3, f3l

    ; --- Test 4: bounce past max ---
.t4:
    lea rbx, [rel inertia_a]
    mov edi, 990
    call fp_from_int
    mov esi, eax
    xor edx, edx
    mov edi, 1000
    call fp_from_int
    mov ecx, eax
    mov r8d, 62259
    mov rdi, rbx
    call inertia_init

    mov edi, 400
    call fp_from_int
    mov esi, eax
    lea rdi, [rel inertia_a]
    call inertia_fling

    xor r12d, r12d
    xor r14d, r14d
    mov edi, 1000
    call fp_from_int
    mov r13d, eax
.t4l:
    cmp r14d, 2000
    ja .bad4
    lea rdi, [rel inertia_a]
    mov esi, FP_DT_60
    call inertia_update
    lea rdi, [rel inertia_a]
    call inertia_value
    cmp eax, r13d
    jne .t4n
    mov r12d, 1
.t4n:
    lea rdi, [rel inertia_a]
    call inertia_is_settled
    cmp eax, 1
    je .t4done
    inc r14d
    jmp .t4l
.t4done:
    cmp r12d, 1
    jne .bad4
    jmp .t5
.bad4:
    die f4, f4l

    ; --- Test 5: snap ---
.t5:
    xor eax, eax
    mov dword [rel snap_pts], eax
    mov edi, 100
    call fp_from_int
    mov dword [rel snap_pts + 4], eax
    mov edi, 200
    call fp_from_int
    mov dword [rel snap_pts + 8], eax
    mov edi, 300
    call fp_from_int
    mov dword [rel snap_pts + 12], eax

    mov edi, 30
    call fp_from_int
    mov ecx, eax
    lea rdi, [rel snap_cfg]
    lea rsi, [rel snap_pts]
    mov edx, 4
    call snap_init

    lea rdi, [rel snap_cfg]
    mov edi, 110
    call fp_from_int
    mov esi, eax
    lea rdi, [rel snap_cfg]
    call snap_nearest
    mov ebx, eax
    mov edi, 100
    call fp_from_int
    cmp ebx, eax
    jne .bad5

    lea rdi, [rel snap_cfg]
    mov edi, 150
    call fp_from_int
    mov esi, eax
    lea rdi, [rel snap_cfg]
    call snap_nearest
    mov ebx, eax
    mov edi, 150
    call fp_from_int
    cmp ebx, eax
    jne .bad5
    jmp .t6
.bad5:
    die f5, f5l

    ; --- Test 6: scheduler ---
.t6:
    lea rdi, [rel sched]
    call anim_scheduler_init

    lea rdi, [rel spring_a]
    xor esi, esi
    mov edi, 50
    call fp_from_int
    mov edx, eax
    mov edi, 260
    call fp_from_int
    mov ecx, eax
    mov edi, 22
    call fp_from_int
    mov r8d, eax
    lea rdi, [rel spring_a]
    call spring_init

    lea rdi, [rel spring_b]
    xor esi, esi
    mov edi, 80
    call fp_from_int
    mov edx, eax
    mov edi, 260
    call fp_from_int
    mov ecx, eax
    mov edi, 22
    call fp_from_int
    mov r8d, eax
    lea rdi, [rel spring_b]
    call spring_init

    lea rdi, [rel spring_c]
    xor esi, esi
    mov edi, 120
    call fp_from_int
    mov edx, eax
    mov edi, 260
    call fp_from_int
    mov ecx, eax
    mov edi, 22
    call fp_from_int
    mov r8d, eax
    lea rdi, [rel spring_c]
    call spring_init

    lea rdi, [rel sched]
    lea rsi, [rel spring_a]
    mov edx, 1
    xor ecx, ecx
    call anim_scheduler_add

    lea rdi, [rel sched]
    lea rsi, [rel spring_b]
    mov edx, 1
    xor ecx, ecx
    call anim_scheduler_add

    lea rdi, [rel sched]
    lea rsi, [rel spring_c]
    mov edx, 1
    xor ecx, ecx
    call anim_scheduler_add

    mov r15d, 15000
.t6l:
    test r15d, r15d
    jz .t6c
    lea rdi, [rel sched]
    call anim_scheduler_tick
    dec r15d
    jmp .t6l
.t6c:
    lea rdi, [rel spring_a]
    call spring_is_settled
    cmp eax, 1
    jne .bad6
    lea rdi, [rel spring_b]
    call spring_is_settled
    cmp eax, 1
    jne .bad6
    lea rdi, [rel spring_c]
    call spring_is_settled
    cmp eax, 1
    jne .bad6

    lea rdi, [rel spring_a]
    call spring_value
    mov ebx, eax
    mov edi, 50
    call fp_from_int
    sub ebx, eax
    mov edi, ebx
    call abs32
    cmp eax, 0x4000
    ja .bad6

    lea rdi, [rel spring_b]
    call spring_value
    mov ebx, eax
    mov edi, 80
    call fp_from_int
    sub ebx, eax
    mov edi, ebx
    call abs32
    cmp eax, 0x4000
    ja .bad6

    lea rdi, [rel spring_c]
    call spring_value
    mov ebx, eax
    mov edi, 120
    call fp_from_int
    sub ebx, eax
    mov edi, ebx
    call abs32
    cmp eax, 0x4000
    ja .bad6
    jmp .all_ok
.bad6:
    die f6, f6l

.all_ok:
    mov rdi, 1
    lea rsi, [rel pass_msg]
    mov rdx, pass_len
    call hal_write
    xor rdi, rdi
    call hal_exit

abs32:
    mov eax, edi
    test eax, eax
    jns .aok
    neg eax
.aok:
    ret
