; time.asm — STEP 60B: hal_clock_gettime via QPC/QPF (win64_call_*)
%include "src/hal/win_x86_64/defs.inc"

extern win_bootstrap_ensure
extern win32_QueryPerformanceCounter
extern win32_QueryPerformanceFrequency
extern win64_call_1

section .text
global hal_clock_gettime

; hal_clock_gettime(clock_id ignored, timespec*) -> 0 / -1
hal_clock_gettime:
    push rbx
    push r12
    mov r12, rsi
    call win_bootstrap_ensure
    test eax, eax
    js .fail

    sub rsp, 72
    mov rdi, [rel win32_QueryPerformanceCounter]
    lea rsi, [rsp+48]
    call win64_call_1
    test eax, eax
    jz .err
    mov rdi, [rel win32_QueryPerformanceFrequency]
    lea rsi, [rsp+56]
    call win64_call_1
    test eax, eax
    jz .err

    mov rax, [rsp+48]
    xor edx, edx
    mov rbx, [rsp+56]
    test rbx, rbx
    jz .err
    div rbx
    mov [r12+TIMESPEC_SEC_OFF], rax

    mov rax, rdx
    mov rbx, NSECS_PER_SEC
    mul rbx
    mov rbx, [rsp+56]
    xor edx, edx
    div rbx
    mov [r12+TIMESPEC_NSEC_OFF], rax
    add rsp, 72
    xor eax, eax
    pop r12
    pop rbx
    ret
.err:
    add rsp, 72
.fail:
    mov eax, -1
    pop r12
    pop rbx
    ret
