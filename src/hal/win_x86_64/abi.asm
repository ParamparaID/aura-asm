; ============================================================
; Win64 Call Adapter (STEP 60A)
; ============================================================
; Arguments in SysV order: rdi, rsi, rdx, rcx, r8, r9
; Win32 API: rcx, rdx, r8, r9, [rsp+32], ...
;
; Shadow space (32 bytes), 16-byte alignment at CALL, argument shuffle.
; Preserves Microsoft x64 callee-saved: rbx, rbp, rdi, rsi, r12–r15 (rdi holds
; fn ptr — saved in frame before call).
; ============================================================

section .text

global win64_call_0
win64_call_0:
    push rbp
    mov rbp, rsp
    push rdi
    sub rsp, 40
    call qword [rbp-8]
    add rsp, 40
    pop rdi
    pop rbp
    ret

global win64_call_1
win64_call_1:
    push rbp
    mov rbp, rsp
    push rdi
    sub rsp, 40
    mov rcx, rsi
    call qword [rbp-8]
    add rsp, 40
    pop rdi
    pop rbp
    ret

global win64_call_2
win64_call_2:
    push rbp
    mov rbp, rsp
    push rdi
    sub rsp, 40
    mov rcx, rsi
    call qword [rbp-8]
    add rsp, 40
    pop rdi
    pop rbp
    ret

global win64_call_3
win64_call_3:
    push rbp
    mov rbp, rsp
    push rdi
    sub rsp, 40
    mov r8, rcx
    mov rcx, rsi
    call qword [rbp-8]
    add rsp, 40
    pop rdi
    pop rbp
    ret

global win64_call_4
win64_call_4:
    push rbp
    mov rbp, rsp
    push rdi
    sub rsp, 40
    mov r9, r8
    mov r8, rcx
    mov rcx, rsi
    call qword [rbp-8]
    add rsp, 40
    pop rdi
    pop rbp
    ret

global win64_call_5
win64_call_5:
    push rbp
    mov rbp, rsp
    push rdi
    sub rsp, 40
    mov [rsp+32], r9
    mov r9, r8
    mov r8, rcx
    mov rcx, rsi
    call qword [rbp-8]
    add rsp, 40
    pop rdi
    pop rbp
    ret

; win64_call_6(fn, a1..a5 in rsi..r9, a6 at [rbp+16] after this prologue)
global win64_call_6
win64_call_6:
    push rbp
    mov rbp, rsp
    push rdi
    sub rsp, 56
    mov rax, [rbp+16]
    mov [rsp+40], rax
    mov [rsp+32], r9
    mov r9, r8
    mov r8, rcx
    mov rcx, rsi
    call qword [rbp-8]
    add rsp, 56
    pop rdi
    pop rbp
    ret

; win64_call_7(fn, a1..a5 regs; a6=[rbp+16], a7=[rbp+24] at entry after pushes)
global win64_call_7
win64_call_7:
    push rbp
    mov rbp, rsp
    push rdi
    sub rsp, 72
    mov rax, [rbp+24]
    mov [rsp+48], rax
    mov rax, [rbp+16]
    mov [rsp+40], rax
    mov [rsp+32], r9
    mov r9, r8
    mov r8, rcx
    mov rcx, rsi
    call qword [rbp-8]
    add rsp, 72
    pop rdi
    pop rbp
    ret
