; memory.asm — STEP 60B: hal_mmap / hal_munmap / hal_mprotect (Win32 via win64_call_*)
%include "src/hal/win_x86_64/defs.inc"

extern win_bootstrap_ensure
extern win32_VirtualAlloc
extern win32_VirtualFree
extern win32_VirtualProtect
extern win64_call_3
extern win64_call_4

section .text
global hal_mmap
global hal_munmap
global hal_mprotect

; hal_mmap(addr, len, prot, flags, fd, off) -> ptr or -1
; Anonymous only (VirtualAlloc); fd/offset ignored like prior Win HAL.
hal_mmap:
    push rbx
    push r12
    mov r12, rsi
    mov ebx, edx
    call win_bootstrap_ensure
    test eax, eax
    js .fail

    mov r8d, PAGE_READWRITE
    test ebx, PROT_EXEC
    jz .pg
    test ebx, PROT_WRITE
    jz .exec_ro
    mov r8d, PAGE_EXECUTE_READWRITE
    jmp .pg
.exec_ro:
    mov r8d, PAGE_EXECUTE_READ
.pg:
    mov rdi, [rel win32_VirtualAlloc]
    xor esi, esi
    mov rdx, r12
    mov ecx, MEM_COMMIT | MEM_RESERVE
    call win64_call_4
    test rax, rax
    jz .fail
    pop r12
    pop rbx
    ret
.fail:
    mov rax, -1
    pop r12
    pop rbx
    ret

; hal_munmap(addr, len) -> 0 / -1
hal_munmap:
    push rbx
    mov rbx, rdi
    call win_bootstrap_ensure
    test eax, eax
    js .fail
    mov rdi, [rel win32_VirtualFree]
    mov rsi, rbx
    xor edx, edx
    mov ecx, MEM_RELEASE
    call win64_call_3
    test eax, eax
    jz .fail
    xor eax, eax
    pop rbx
    ret
.fail:
    mov eax, -1
    pop rbx
    ret

; hal_mprotect(addr, len, prot) -> 0 / -1
hal_mprotect:
    push rbx
    push r12
    push r13
    push r14
    mov r12, rdi
    mov r13, rsi
    mov r14d, edx
    call win_bootstrap_ensure
    test eax, eax
    js .fail

    xor ebx, ebx
    test r14d, PROT_EXEC
    jnz .mpx
    test r14d, PROT_WRITE
    jnz .mp_rw
    test r14d, PROT_READ
    jz .fail
    mov ebx, PAGE_READONLY
    jmp .mp_go
.mp_rw:
    mov ebx, PAGE_READWRITE
    jmp .mp_go
.mpx:
    test r14d, PROT_WRITE
    jnz .mp_xrw
    mov ebx, PAGE_EXECUTE_READ
    jmp .mp_go
.mp_xrw:
    mov ebx, PAGE_EXECUTE_READWRITE
.mp_go:
    sub rsp, 24
    lea r9, [rsp+16]
    mov rdi, [rel win32_VirtualProtect]
    mov rsi, r12
    mov rdx, r13
    mov ecx, ebx
    call win64_call_4
    add rsp, 24
    test eax, eax
    jz .fail
    xor eax, eax
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.fail:
    mov eax, -1
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
