; threads.asm — STEP 60B: threads, CRITICAL_SECTION mutex, atomics
%include "src/hal/win_x86_64/defs.inc"

extern win_bootstrap_ensure
extern win32_VirtualAlloc
extern win32_VirtualFree
extern win32_CreateThread
extern win32_WaitForSingleObject
extern win32_CloseHandle
extern win32_InitializeCriticalSection
extern win32_EnterCriticalSection
extern win32_LeaveCriticalSection
extern win32_DeleteCriticalSection
extern win64_call_1
extern win64_call_2
extern win64_call_3
extern win64_call_4
extern win64_call_6

section .text
global win_thread_entry
global hal_thread_create
global hal_thread_join
global hal_mutex_init
global hal_mutex_lock
global hal_mutex_unlock
global hal_mutex_destroy
global hal_atomic_inc
global hal_atomic_dec
global hal_atomic_cas

; CreateThread start: rcx = ctx { fn, arg } (Microsoft x64)
win_thread_entry:
    push rbp
    push rbx
    push rdi
    push rsi
    push r12
    push r13
    push r14
    push r15
    mov rbx, rcx
    mov rax, [rbx]
    mov rdi, [rbx+8]
    call rax
    mov rdi, [rel win32_VirtualFree]
    mov rsi, rbx
    xor edx, edx
    mov ecx, MEM_RELEASE
    call win64_call_3
    xor eax, eax
    pop r15
    pop r14
    pop r13
    pop r12
    pop rsi
    pop rdi
    pop rbx
    pop rbp
    ret

; hal_thread_create(fn, arg, stack_size) -> handle / -1
hal_thread_create:
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    test rbx, rbx
    jz .fail
    call win_bootstrap_ensure
    test eax, eax
    js .fail

    mov rdi, [rel win32_VirtualAlloc]
    xor esi, esi
    mov edx, 16
    mov ecx, MEM_COMMIT | MEM_RESERVE
    mov r8d, PAGE_READWRITE
    call win64_call_4
    test rax, rax
    jz .fail
    mov [rax], rbx
    mov [rax+8], r12
    mov r12, rax

    sub rsp, 8
    push qword 0
    mov rdi, [rel win32_CreateThread]
    xor esi, esi
    mov rdx, r13
    lea rcx, [rel win_thread_entry]
    mov r8, r12
    xor r9d, r9d
    call win64_call_6
    add rsp, 16
    test rax, rax
    jz .free_ctx
    pop r13
    pop r12
    pop rbx
    ret

.free_ctx:
    mov rdi, [rel win32_VirtualFree]
    mov rsi, r12
    xor edx, edx
    mov ecx, MEM_RELEASE
    call win64_call_3
.fail:
    mov rax, -1
    pop r13
    pop r12
    pop rbx
    ret

; hal_thread_join(handle) -> 0 / -1
hal_thread_join:
    push rbx
    mov rbx, rdi
    test rbx, rbx
    jz .fail
    call win_bootstrap_ensure
    test eax, eax
    js .fail

    mov rdi, [rel win32_WaitForSingleObject]
    mov rsi, rbx
    mov edx, INFINITE
    call win64_call_2
    cmp eax, 0xFFFFFFFF
    je .close_fail

    mov rdi, [rel win32_CloseHandle]
    mov rsi, rbx
    call win64_call_1
    test eax, eax
    jz .fail
    xor eax, eax
    pop rbx
    ret

.close_fail:
    mov rdi, [rel win32_CloseHandle]
    mov rsi, rbx
    call win64_call_1
.fail:
    mov eax, -1
    pop rbx
    ret

hal_mutex_init:
    test rdi, rdi
    jz .fail
    call win_bootstrap_ensure
    test eax, eax
    js .fail
    mov rsi, rdi
    mov rdi, [rel win32_InitializeCriticalSection]
    call win64_call_1
    xor eax, eax
    ret
.fail:
    mov eax, -1
    ret

hal_mutex_lock:
    test rdi, rdi
    jz .fail
    call win_bootstrap_ensure
    test eax, eax
    js .fail
    mov rsi, rdi
    mov rdi, [rel win32_EnterCriticalSection]
    call win64_call_1
    xor eax, eax
    ret
.fail:
    mov eax, -1
    ret

hal_mutex_unlock:
    test rdi, rdi
    jz .fail
    call win_bootstrap_ensure
    test eax, eax
    js .fail
    mov rsi, rdi
    mov rdi, [rel win32_LeaveCriticalSection]
    call win64_call_1
    xor eax, eax
    ret
.fail:
    mov eax, -1
    ret

hal_mutex_destroy:
    test rdi, rdi
    jz .noop
    call win_bootstrap_ensure
    test eax, eax
    js .fail
    mov rsi, rdi
    mov rdi, [rel win32_DeleteCriticalSection]
    call win64_call_1
    xor eax, eax
    ret
.fail:
    mov eax, -1
    ret
.noop:
    xor eax, eax
    ret

hal_atomic_inc:
    test rdi, rdi
    jz .fail
    mov rax, 1
    lock xadd [rdi], rax
    add rax, 1
    ret
.fail:
    mov rax, -1
    ret

hal_atomic_dec:
    test rdi, rdi
    jz .fail
    lock sub qword [rdi], 1
    mov rax, [rdi]
    ret
.fail:
    mov rax, -1
    ret

; hal_atomic_cas(ptr, expected, desired) -> 0 if stored, -1 if *ptr != expected
hal_atomic_cas:
    test rdi, rdi
    jz .fail
    mov rax, rsi
    lock cmpxchg [rdi], rdx
    jz .ok
    mov rax, -1
    ret
.ok:
    xor eax, eax
    ret
.fail:
    mov rax, -1
    ret
