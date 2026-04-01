; physics.asm — UI animation: springs, inertia, snap, scheduler (fixed-point 16.16)
%include "src/hal/platform_defs.inc"

section .rodata
FP_ONE      equ 0x00010000
FP_HALF     equ 0x00008000
FP_NS_DIV   equ 1000000000       ; dt_fp = (dt_ns * FP_ONE) / FP_NS_DIV
FP_DT_60    equ 1092             ; ~1/60 second in 16.16 (65536/60)
SPRING_EPS  equ 1024             ; position settle band (fp)
VEL_EPS     equ 1024
INERTIA_VEL_EPS equ 128

ANIM_SPRING   equ 1
ANIM_INERTIA  equ 2

SCHED_MAX     equ 64
SCHED_ANIM_OFF    equ 0          ; 64 * 8
SCHED_TYPES_OFF   equ 512        ; 64 * 1 (pad to 576 for callback align)
SCHED_CB_OFF      equ 576        ; 64 * 8
SCHED_COUNT_OFF   equ 1088
SCHED_LASTNS_OFF  equ 1092       ; dq after dd count + padding

section .text

extern hal_clock_gettime

global fp_mul
global fp_div
global fp_from_int
global fp_to_int

global spring_init
global spring_set_target
global spring_update
global spring_value
global spring_is_settled

global inertia_init
global inertia_fling
global inertia_update
global inertia_value
global inertia_is_settled

global snap_init
global snap_nearest
global snap_apply

global anim_scheduler_init
global anim_scheduler_add
global anim_scheduler_remove
global anim_scheduler_tick

; -----------------------------------------------------------------------------
; fp_mul(edi=a, esi=b) -> eax  signed 16.16
; -----------------------------------------------------------------------------
fp_mul:
    movsxd rax, edi
    movsxd rcx, esi
    imul rax, rcx
    sar rax, 16
    mov eax, eax
    ret

; -----------------------------------------------------------------------------
; fp_div(edi=a, esi=b) -> eax  (a << 16) / b, signed
; -----------------------------------------------------------------------------
fp_div:
    test esi, esi
    jz .zero
    movsxd rax, edi
    sal rax, 16
    movsxd rcx, esi
    cqo
    idiv rcx
    mov eax, eax
    ret
.zero:
    xor eax, eax
    ret

; -----------------------------------------------------------------------------
; fp_from_int(edi=n) -> eax
; -----------------------------------------------------------------------------
fp_from_int:
    mov eax, edi
    shl eax, 16
    ret

; -----------------------------------------------------------------------------
; fp_to_int(edi=fp) -> eax  rounded
; -----------------------------------------------------------------------------
fp_to_int:
    mov eax, edi
    add eax, FP_HALF
    sar eax, 16
    ret

; =============================================================================
; Spring  (28 bytes)
; =============================================================================
spring_init:
    mov dword [rdi], esi           ; value
    mov dword [rdi + 4], 0         ; velocity
    mov dword [rdi + 8], edx       ; target
    mov dword [rdi + 12], ecx      ; stiffness
    mov dword [rdi + 16], r8d      ; damping
    mov dword [rdi + 20], FP_ONE   ; mass
    mov dword [rdi + 24], 0        ; settled
    ret

spring_set_target:
    mov dword [rdi + 8], esi
    mov dword [rdi + 24], 0
    ret

; spring_update(rdi=spring, esi=dt_fp)
spring_update:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi

    mov eax, [r12 + 24]
    test eax, eax
    jnz .done

    mov ebx, [r12]                 ; value
    mov ecx, [r12 + 8]             ; target
    mov r14d, [r12 + 4]            ; velocity
    mov r15d, [r12 + 12]           ; stiffness

    mov edi, ebx
    sub edi, ecx                   ; value - target
    mov esi, r15d
    call fp_mul                    ; stiffness * (value-target)
    mov r8d, eax
    neg r8d                        ; -stiffness * (value-target)

    mov edi, [r12 + 16]
    mov esi, r14d
    call fp_mul                    ; damping * velocity
    sub r8d, eax                   ; force

    mov edi, r8d
    mov esi, [r12 + 20]
    call fp_div                    ; acc = force / mass

    mov edi, eax
    mov esi, r13d
    call fp_mul                    ; acc * dt
    add r14d, eax                  ; velocity +=

    mov edi, r14d
    mov esi, r13d
    call fp_mul                    ; velocity * dt
    add ebx, eax                   ; value +=

    mov [r12], ebx
    mov [r12 + 4], r14d

    mov edi, ebx
    sub edi, [r12 + 8]
    call .abs_eax
    cmp eax, SPRING_EPS
    ja .not_set

    mov edi, r14d
    call .abs_eax
    cmp eax, VEL_EPS
    ja .not_set

    mov ecx, [r12 + 8]
    mov [r12], ecx
    mov dword [r12 + 4], 0
    mov dword [r12 + 24], 1
    jmp .done
.not_set:
    mov dword [r12 + 24], 0
.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

.abs_eax:
    mov eax, edi
    test eax, eax
    jns .abs_ok
    neg eax
.abs_ok:
    ret

spring_value:
    mov eax, [rdi]
    ret

spring_is_settled:
    mov eax, [rdi + 24]
    ret

; =============================================================================
; Inertia  (28 bytes: +20 bounce fp)
; =============================================================================
inertia_init:
    mov dword [rdi], esi
    mov dword [rdi + 4], 0
    mov dword [rdi + 8], r8d       ; friction (fp), 5th SysV arg
    mov dword [rdi + 12], edx      ; min
    mov dword [rdi + 16], ecx      ; max
    mov dword [rdi + 20], 0x00004CCC ; ~0.3 * FP_ONE bounce
    mov dword [rdi + 24], 1
    ret

inertia_fling:
    mov dword [rdi + 4], esi
    mov dword [rdi + 24], 0
    ret

; inertia_update(rdi=ptr, esi=dt_fp)
inertia_update:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi

    mov ebx, [r12]                 ; value
    mov r14d, [r12 + 4]            ; velocity

    mov edi, r14d
    mov esi, r13d
    call fp_mul
    add ebx, eax                   ; value += v*dt

    mov edi, [r12 + 4]
    mov esi, [r12 + 8]
    call fp_mul
    mov [r12 + 4], eax             ; velocity *= friction
    mov r14d, eax

    mov r15d, [r12 + 12]           ; min
    mov ecx, [r12 + 16]            ; max

    cmp ebx, r15d
    jge .above_min
    mov ebx, r15d
    mov edi, r14d
    neg edi
    mov esi, [r12 + 20]
    call fp_mul
    mov [r12 + 4], eax
    mov r14d, eax
    jmp .check_vel
.above_min:
    cmp ebx, ecx
    jle .check_vel
    mov ebx, ecx
    mov edi, r14d
    neg edi
    mov esi, [r12 + 20]
    call fp_mul
    mov [r12 + 4], eax
    mov r14d, eax

.check_vel:
    mov [r12], ebx

    mov edi, r14d
    call spring_update.abs_eax
    cmp eax, INERTIA_VEL_EPS
    ja .active
    mov dword [r12 + 24], 1
    jmp .iu_out
.active:
    mov dword [r12 + 24], 0
.iu_out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

inertia_value:
    mov eax, [rdi]
    ret

inertia_is_settled:
    mov eax, [rdi + 24]
    ret

; =============================================================================
; SnapConfig: points dq, count dd, snap_dist dd  (16 bytes + padding)
; =============================================================================
snap_init:
    mov qword [rdi], rsi
    mov dword [rdi + 8], edx
    mov dword [rdi + 12], ecx
    ret

; snap_nearest(rdi=config, esi=value_fp) -> eax nearest fp
snap_nearest:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi

    mov r14, [r12]                 ; points
    mov r15d, [r12 + 8]            ; count
    mov ebx, [r12 + 12]            ; snap_dist

    test r15d, r15d
    jz .sn_ret_orig

    xor ecx, ecx
    mov edx, 0x7FFFFFFF            ; best dist (large)
    xor r8d, r8d                   ; best idx
.find:
    cmp ecx, r15d
    jae .found_pt
    mov edi, r13d
    mov esi, [r14 + rcx*4]
    sub esi, edi
    mov edi, esi
    call spring_update.abs_eax
    cmp eax, edx
    jae .next_pt
    mov edx, eax
    mov r8d, ecx
.next_pt:
    inc ecx
    jmp .find
.found_pt:
    cmp edx, ebx
    ja .sn_ret_orig
    mov eax, [r14 + r8*4]
    jmp .sn_out
.sn_ret_orig:
    mov eax, r13d
.sn_out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; snap_apply(rdi=config, rsi=spring_ptr)
snap_apply:
    push rbx
    push r12
    mov r12, rsi
    mov rbx, rdi
    mov esi, [r12]
    mov rdi, rbx
    call snap_nearest
    mov rdi, r12
    mov esi, eax
    call spring_set_target
    pop r12
    pop rbx
    ret

; =============================================================================
; Animation scheduler
; =============================================================================
anim_scheduler_init:
    push rdi
    mov ecx, (SCHED_LASTNS_OFF + 8 + 7) / 8
    xor eax, eax
    rep stosq
    pop rdi
    mov dword [rdi + SCHED_COUNT_OFF], 0
    mov qword [rdi + SCHED_LASTNS_OFF], 0
    ret

; anim_scheduler_add(rdi=sched, rsi=anim, edx=type, rcx=callback) -> eax id or -1
anim_scheduler_add:
    push rbx
    push r12
    push r13
    push r14
    mov r12, rdi
    mov r13, rsi
    mov r14d, edx
    xor ebx, ebx
.slot:
    cmp ebx, SCHED_MAX
    jge .full
    cmp qword [r12 + rbx*8], 0
    je .got
    inc ebx
    jmp .slot
.full:
    mov eax, -1
    jmp .add_out
.got:
    mov [r12 + rbx*8], r13
    mov byte [r12 + SCHED_TYPES_OFF + rbx], r14b
    mov [r12 + SCHED_CB_OFF + rbx*8], rcx
    inc dword [r12 + SCHED_COUNT_OFF]
    mov eax, ebx
.add_out:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

anim_scheduler_remove:
    cmp esi, 0
    jl .rm_done
    cmp esi, SCHED_MAX
    jge .rm_done
    movsxd rsi, esi
    cmp qword [rdi + rsi*8], 0
    je .rm_done
    mov qword [rdi + rsi*8], 0
    mov byte [rdi + SCHED_TYPES_OFF + rsi], 0
    mov qword [rdi + SCHED_CB_OFF + rsi*8], 0
    dec dword [rdi + SCHED_COUNT_OFF]
.rm_done:
    ret

; anim_scheduler_tick(rdi=sched) -> eax 1 if any active else 0
anim_scheduler_tick:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16
    mov r12, rdi

    mov rdi, CLOCK_MONOTONIC
    lea rsi, [rsp]
    call hal_clock_gettime
    test rax, rax
    js .bad_clock

    mov rax, [rsp]
    mov rcx, 1000000000
    mul rcx
    add rax, [rsp + 8]
    adc rdx, 0
    test rdx, rdx
    jnz .bad_clock
    mov rbx, rax

    mov r8, qword [r12 + SCHED_LASTNS_OFF]
    test r8, r8
    jz .sched_first

    mov rcx, rbx
    sub rcx, r8
    mov qword [r12 + SCHED_LASTNS_OFF], rbx
    jc .sched_dt_ns_def
    cmp rcx, 200000000
    ja .sched_dt_ns_def
    cmp rcx, 5000000
    jb .sched_dt_ns_def
    jmp .sched_dt_calc
.sched_first:
    mov qword [r12 + SCHED_LASTNS_OFF], rbx
    mov r14d, FP_DT_60
    jmp .upd_loop

.sched_dt_ns_def:
    mov rcx, 16666666
.sched_dt_calc:
    mov rax, rcx
    mov r10, 1000000000
    mov r11, FP_ONE
    mul r11
    div r10
    cmp rax, 256
    jae .sched_dt_min_ok
    mov eax, 256
.sched_dt_min_ok:
    mov r9, FP_DT_60
    shl r9, 1
    cmp rax, r9
    jbe .sched_dt_set
    mov rax, r9
.sched_dt_set:
    mov r14d, eax

.upd_loop:
    xor r15, r15
.slot_loop:
    cmp r15, SCHED_MAX
    jae .tick_done

    mov r13, [r12 + r15*8]
    test r13, r13
    jz .next_slot

    lea rax, [r12 + SCHED_TYPES_OFF]
    movzx eax, byte [rax + r15]
    cmp al, ANIM_SPRING
    je .do_spring
    cmp al, ANIM_INERTIA
    je .do_inertia
    jmp .next_slot

.do_spring:
    mov rdi, r13
    mov esi, r14d
    call spring_update
    jmp .after_upd

.do_inertia:
    mov rdi, r13
    mov esi, r14d
    call inertia_update

.after_upd:
    mov rdi, r13
    mov eax, [r13]
    mov r8d, eax

    lea rax, [r12 + SCHED_TYPES_OFF]
    movzx eax, byte [rax + r15]
    cmp al, ANIM_SPRING
    jne .chk_inertia
    mov rdi, r13
    call spring_is_settled
    jmp .do_cb
.chk_inertia:
    mov rdi, r13
    call inertia_is_settled

.do_cb:
    test eax, eax
    jz .cb_each_frame

    mov rcx, [r12 + SCHED_CB_OFF + r15*8]
    test rcx, rcx
    jz .remove_slot
    mov rdi, r13
    mov esi, r8d
    call rcx
.remove_slot:
    mov rdi, r12
    mov esi, r15d
    call anim_scheduler_remove
    jmp .next_slot

.cb_each_frame:
    mov rcx, [r12 + SCHED_CB_OFF + r15*8]
    test rcx, rcx
    jz .next_slot
    mov rdi, r13
    mov esi, r8d
    call rcx

.next_slot:
    inc r15
    jmp .slot_loop

.tick_done:
    xor eax, eax
    xor r15, r15
.count_act:
    cmp r15, SCHED_MAX
    jae .ret_tick
    cmp qword [r12 + r15*8], 0
    jne .ret_one
    inc r15
    jmp .count_act
.ret_one:
    mov eax, 1
.ret_tick:
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

.bad_clock:
    xor eax, eax
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
