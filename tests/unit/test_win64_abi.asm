; test_win64_abi.asm — STEP 60A gate: bootstrap + Win64 ABI adapter + Win32 smoke
; Run on Windows: build/win_x86_64/test_win64_abi.exe
%include "src/hal/win_x86_64/defs.inc"

extern bootstrap_init
extern stdout_handle
extern win32_WriteFile
extern win32_VirtualAlloc
extern win32_VirtualFree
extern win32_QueryPerformanceCounter
extern win32_GetCommandLineA
extern win32_ExitProcess

extern win64_call_0
extern win64_call_1
extern win64_call_3
extern win64_call_4
extern win64_call_5

section .rodata
msg_t2          db "T2 OK", 13, 10
msg_t2_len      equ $ - msg_t2
msg_t5_data     db "."
msg_t5_len      equ $ - msg_t5_data
msg_pass        db "ALL TESTS PASSED", 13, 10
msg_pass_len    equ $ - msg_pass
msg_fail        db "TEST FAILED", 13, 10
msg_fail_len    equ $ - msg_fail
msg_fail_null   db "FAIL: NULL function ptr", 13, 10
msg_fail_null_len equ $ - msg_fail_null
msg_fail_clobber db "FAIL: callee-saved clobbered", 13, 10
msg_fail_clobber_len equ $ - msg_fail_clobber

section .text
global _start

_start:
    sub rsp, 8
    call bootstrap_init
    cmp eax, 1
    jne .fail

    ; === Test 1: first 20 pointers from win32_WriteFile (bootstrap .data layout) ===
    lea rdi, [rel win32_WriteFile]
    mov ecx, 20
.check_loop:
    mov rax, [rdi]
    test rax, rax
    jz .fail_null
    add rdi, 8
    dec ecx
    jnz .check_loop

    ; === Test 2: WriteFile via win64_call_5 ===
    sub rsp, 24
    mov rdi, [rel win32_WriteFile]
    mov rsi, [rel stdout_handle]
    lea rdx, [rel msg_t2]
    mov ecx, msg_t2_len
    lea r8, [rsp+16]
    xor r9d, r9d
    call win64_call_5
    add rsp, 24
    test eax, eax
    jz .fail

    ; === Test 3: VirtualAlloc / touch / VirtualFree via adapter ===
    mov rdi, [rel win32_VirtualAlloc]
    xor esi, esi
    mov edx, 4096
    mov ecx, MEM_COMMIT | MEM_RESERVE
    mov r8d, PAGE_READWRITE
    call win64_call_4
    test rax, rax
    jz .fail
    mov rbx, rax
    mov dword [rbx], 0xDEADBEEF
    cmp dword [rbx], 0xDEADBEEF
    jne .fail
    mov rdi, [rel win32_VirtualFree]
    mov rsi, rbx
    xor edx, edx
    mov ecx, MEM_RELEASE
    call win64_call_3
    test eax, eax
    jz .fail

    ; === Test 4: QueryPerformanceCounter (non-zero count) ===
    sub rsp, 32
    mov rdi, [rel win32_QueryPerformanceCounter]
    lea rsi, [rsp+8]
    call win64_call_1
    test eax, eax
    jz .fail
    mov rax, [rsp+8]
    add rsp, 32
    test rax, rax
    jz .fail

    ; === Test 5: GetCommandLineA via win64_call_0 ===
    mov rdi, [rel win32_GetCommandLineA]
    test rdi, rdi
    jz .fail
    call win64_call_0
    test rax, rax
    jz .fail
    cmp byte [rax], 0
    je .fail

    ; === Test 6: callee-saved registers after Win32 call ===
    mov rbx, 0x1111111111111111
    mov rdi, 0x2222222222222222
    mov rsi, 0x3333333333333333
    mov r12, 0x4444444444444444
    mov r13, 0x5555555555555555
    mov r14, 0x6666666666666666
    mov r15, 0x7777777777777777
    sub rsp, 24
    mov rdi, [rel win32_WriteFile]
    mov rsi, [rel stdout_handle]
    lea rdx, [rel msg_t5_data]
    mov ecx, msg_t5_len
    lea r8, [rsp+16]
    xor r9d, r9d
    call win64_call_5
    add rsp, 24
    test eax, eax
    jz .fail
    cmp rbx, 0x1111111111111111
    jne .fail_clobber
    cmp rdi, 0x2222222222222222
    jne .fail_clobber
    cmp rsi, 0x3333333333333333
    jne .fail_clobber
    cmp r12, 0x4444444444444444
    jne .fail_clobber
    cmp r13, 0x5555555555555555
    jne .fail_clobber
    cmp r14, 0x6666666666666666
    jne .fail_clobber
    cmp r15, 0x7777777777777777
    jne .fail_clobber

    ; === ALL PASSED ===
    sub rsp, 24
    mov rdi, [rel win32_WriteFile]
    mov rsi, [rel stdout_handle]
    lea rdx, [rel msg_pass]
    mov ecx, msg_pass_len
    lea r8, [rsp+16]
    xor r9d, r9d
    call win64_call_5
    add rsp, 24
    mov rdi, [rel win32_ExitProcess]
    xor esi, esi
    call win64_call_1

.fail_null:
    lea rdx, [rel msg_fail_null]
    mov r8d, msg_fail_null_len
    jmp .fail_exit
.fail_clobber:
    lea rdx, [rel msg_fail_clobber]
    mov r8d, msg_fail_clobber_len
    jmp .fail_exit
.fail:
    lea rdx, [rel msg_fail]
    mov r8d, msg_fail_len
.fail_exit:
    sub rsp, 24
    mov rdi, [rel win32_WriteFile]
    mov rsi, [rel stdout_handle]
    mov ecx, r8d
    lea r8, [rsp+16]
    xor r9d, r9d
    call win64_call_5
    add rsp, 24
    mov rdi, [rel win32_ExitProcess]
    mov esi, 1
    call win64_call_1
