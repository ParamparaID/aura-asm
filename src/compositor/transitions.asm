; transitions.asm — spring-driven slide/scale transitions
%include "src/compositor/workspaces.inc"

extern spring_init
extern spring_set_target
extern spring_value
extern fp_mul

%define FP_ONE                       0x00010000
%define FP_SCALE_MIN                 0x0000CCCD ; ~0.8
%define TR_SPRING_STIFF              0x00024000
%define TR_SPRING_DAMP               0x00010000

; Transition layout
%define TR_SPRING_OFF                0      ; 28 bytes
%define TR_DIRECTION_OFF             28
%define TR_CALLBACK_OFF              32
%define TR_FADE_OFF                  40
%define TR_SCALE_OFF                 44
%define TR_STRUCT_SIZE               48

section .text
global transition_slide_in
global transition_slide_out
global transition_scale_in
global transition_scale_out
global transition_value
global transition_direction
global transition_fade
global transition_scale
global transition_set_callback
global transition_fire_callback

; transition_slide_in(transition, direction)
transition_slide_in:
    mov r10d, esi
    mov ecx, TR_SPRING_STIFF
    mov r8d, TR_SPRING_DAMP
    xor esi, esi
    mov edx, FP_ONE
    call spring_init
    mov [rdi + TR_DIRECTION_OFF], r10d
    mov dword [rdi + TR_FADE_OFF], FP_ONE
    mov dword [rdi + TR_SCALE_OFF], FP_ONE
    ret

; transition_slide_out(transition, direction)
transition_slide_out:
    mov r10d, esi
    mov ecx, TR_SPRING_STIFF
    mov r8d, TR_SPRING_DAMP
    mov esi, FP_ONE
    xor edx, edx
    call spring_init
    mov [rdi + TR_DIRECTION_OFF], r10d
    mov dword [rdi + TR_FADE_OFF], FP_ONE
    mov dword [rdi + TR_SCALE_OFF], FP_ONE
    ret

; transition_scale_in(transition)
transition_scale_in:
    mov ecx, TR_SPRING_STIFF
    mov r8d, TR_SPRING_DAMP
    mov esi, FP_SCALE_MIN
    mov edx, FP_ONE
    call spring_init
    mov dword [rdi + TR_DIRECTION_OFF], TR_DIR_UP
    xor eax, eax
    mov [rdi + TR_FADE_OFF], eax
    mov [rdi + TR_SCALE_OFF], esi
    ret

; transition_scale_out(transition)
transition_scale_out:
    mov ecx, TR_SPRING_STIFF
    mov r8d, TR_SPRING_DAMP
    mov esi, FP_ONE
    mov edx, FP_SCALE_MIN
    call spring_init
    mov dword [rdi + TR_DIRECTION_OFF], TR_DIR_DOWN
    mov dword [rdi + TR_FADE_OFF], FP_ONE
    mov dword [rdi + TR_SCALE_OFF], FP_ONE
    ret

; transition_value(transition) -> eax fp 16.16
transition_value:
    call spring_value
    ret

; transition_direction(transition) -> eax
transition_direction:
    mov eax, [rdi + TR_DIRECTION_OFF]
    ret

; transition_fade(transition) -> eax fp 16.16
transition_fade:
    mov eax, [rdi + TR_FADE_OFF]
    ret

; transition_scale(transition) -> eax fp 16.16
transition_scale:
    mov eax, [rdi + TR_SCALE_OFF]
    ret

; transition_set_callback(transition, callback)
transition_set_callback:
    mov [rdi + TR_CALLBACK_OFF], rsi
    ret

; transition_fire_callback(transition)
transition_fire_callback:
    mov rax, [rdi + TR_CALLBACK_OFF]
    test rax, rax
    jz .out
    call rax
.out:
    ret
