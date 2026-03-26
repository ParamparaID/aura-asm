; syscall.asm - Win32 HAL wrappers with SysV-compatible entry ABI
%include "src/hal/win_x86_64/defs.inc"

extern bootstrap_init

extern win32_CreateFileA
extern win32_ReadFile
extern win32_WriteFile
extern win32_CloseHandle
extern win32_VirtualAlloc
extern win32_VirtualFree
extern win32_ExitProcess
extern win32_GetStdHandle
extern win32_QueryPerformanceCounter
extern win32_QueryPerformanceFrequency
extern win32_CreateThread
extern win32_CreatePipe
extern win32_CreateProcessA
extern win32_GetExitCodeProcess
extern win32_GetEnvironmentVariableA
extern win32_SetStdHandle
extern win32_WaitForSingleObject
extern win32_AcquireSRWLockExclusive
extern win32_ReleaseSRWLockExclusive
extern win32_InterlockedIncrement64
extern win32_WSAPoll
extern win32_Sleep
extern win32_socket
extern win32_connect
extern win32_bind
extern win32_listen
extern win32_accept
extern win32_closesocket

section .text
global hal_write
global hal_read
global hal_open
global hal_close
global hal_mmap
global hal_munmap
global hal_exit
global hal_clock_gettime
global hal_getenv
global hal_getenv_raw
global hal_fork
global hal_execve
global hal_pipe
global hal_dup2
global hal_spawn
global hal_waitpid
global hal_socket
global hal_connect
global hal_bind
global hal_listen
global hal_accept4
global hal_sleep_ms
global hal_wsapoll
global hal_event_poll
global hal_thread_create
global hal_thread_join
global hal_mutex_init
global hal_mutex_lock
global hal_mutex_unlock
global hal_mutex_destroy
global hal_atomic_inc

section .text
win_thread_entry:
    ; rcx = ctx ptr {fn,arg}
    push rbx
    mov rbx, rcx
    mov rax, [rbx]
    mov rdi, [rbx + 8]
    call rax
    xor eax, eax
    pop rbx
    ret

section .text

win_bootstrap_ensure:
    call bootstrap_init
    cmp eax, 1
    jne .fail
    xor eax, eax
    ret
.fail:
    mov eax, -1
    ret

win_pick_handle:
    ; rdi = linux fd or native HANDLE, returns rax handle
    cmp edi, 1
    je .stdout
    cmp edi, 2
    je .stderr
    cmp edi, 0
    je .stdin
    mov rax, rdi
    ret
.stdout:
    mov ecx, STD_OUTPUT_HANDLE
    jmp .std
.stderr:
    mov ecx, STD_ERROR_HANDLE
    jmp .std
.stdin:
    mov ecx, STD_INPUT_HANDLE
.std:
    mov rax, [rel win32_GetStdHandle]
    sub rsp, 40
    call rax
    add rsp, 40
    ret

hal_write:
    ; (fd, buf, len) -> bytes or -1
    push rbx
    mov rbx, rsi
    mov r10d, edx
    call win_bootstrap_ensure
    test eax, eax
    js .fail

    call win_pick_handle
    mov r11, rax
    sub rsp, 72
    lea r9, [rsp + 64]               ; DWORD bytesWritten
    mov qword [rsp + 32], 0          ; OVERLAPPED = NULL
    mov rcx, r11
    mov rdx, rbx
    mov r8d, r10d
    mov rax, [rel win32_WriteFile]
    call rax
    test eax, eax
    jz .err
    mov eax, [rsp + 64]
    add rsp, 72
    pop rbx
    ret
.err:
    add rsp, 72
.fail:
    mov eax, -1
    pop rbx
    ret

hal_read:
    ; (fd, buf, len) -> bytes or -1
    push rbx
    mov rbx, rsi
    mov r10d, edx
    call win_bootstrap_ensure
    test eax, eax
    js .fail

    call win_pick_handle
    mov r11, rax
    sub rsp, 72
    lea r9, [rsp + 64]               ; DWORD bytesRead
    mov qword [rsp + 32], 0          ; OVERLAPPED = NULL
    mov rcx, r11
    mov rdx, rbx
    mov r8d, r10d
    mov rax, [rel win32_ReadFile]
    call rax
    test eax, eax
    jz .err
    mov eax, [rsp + 64]
    add rsp, 72
    pop rbx
    ret
.err:
    add rsp, 72
.fail:
    mov eax, -1
    pop rbx
    ret

hal_open:
    ; (path, flags, mode) -> HANDLE or -1
    push rbx
    mov rbx, rdi
    mov r10d, esi
    call win_bootstrap_ensure
    test eax, eax
    js .fail

    mov edx, GENERIC_READ            ; desired access
    mov eax, r10d
    test eax, O_WRONLY
    jnz .wr
    test eax, O_RDWR
    jnz .rdwr
    jmp .disp
.wr:
    mov edx, GENERIC_WRITE
    jmp .disp
.rdwr:
    mov edx, GENERIC_READ | GENERIC_WRITE

.disp:
    mov r11d, OPEN_EXISTING
    mov eax, r10d
    test eax, O_CREAT
    jz .call
    test eax, O_TRUNC
    jz .call
    mov r11d, CREATE_ALWAYS

.call:
    sub rsp, 64
    mov qword [rsp + 32], 0          ; lpSecurityAttributes
    mov dword [rsp + 40], r11d       ; dwCreationDisposition
    mov dword [rsp + 48], FILE_ATTRIBUTE_NORMAL
    mov qword [rsp + 56], 0          ; hTemplateFile
    mov rcx, rbx
    mov r8d, FILE_SHARE_READ | FILE_SHARE_WRITE
    mov r9, 0
    mov rax, [rel win32_CreateFileA]
    call rax
    add rsp, 64
    cmp rax, -1
    je .fail
    pop rbx
    ret
.fail:
    mov eax, -1
    pop rbx
    ret

hal_close:
    ; (handle) -> 0/-1
    call win_bootstrap_ensure
    test eax, eax
    js .fail
    mov rcx, rdi
    sub rsp, 40
    mov rax, [rel win32_CloseHandle]
    call rax
    add rsp, 40
    test eax, eax
    jz .fail
    xor eax, eax
    ret
.fail:
    mov eax, -1
    ret

hal_mmap:
    ; (addr, len, prot, flags, fd, off) -> ptr or -1
    ; MVP supports anonymous allocation via VirtualAlloc.
    push rbx
    mov rbx, rsi                     ; len
    mov r10d, edx                    ; prot
    call win_bootstrap_ensure
    test eax, eax
    js .fail

    mov r9d, PAGE_READWRITE
    test r10d, PROT_EXEC
    jz .alloc
    test r10d, PROT_WRITE
    jz .exec_ro
    mov r9d, PAGE_EXECUTE_READWRITE
    jmp .alloc
.exec_ro:
    mov r9d, PAGE_EXECUTE_READ

.alloc:
    mov rcx, 0
    mov rdx, rbx
    mov r8d, MEM_COMMIT | MEM_RESERVE
    sub rsp, 40
    mov rax, [rel win32_VirtualAlloc]
    call rax
    add rsp, 40
    test rax, rax
    jz .fail
    pop rbx
    ret
.fail:
    mov rax, -1
    pop rbx
    ret

hal_munmap:
    ; (addr, len) -> 0/-1
    call win_bootstrap_ensure
    test eax, eax
    js .fail
    mov rcx, rdi
    mov rdx, 0
    mov r8d, MEM_RELEASE
    sub rsp, 40
    mov rax, [rel win32_VirtualFree]
    call rax
    add rsp, 40
    test eax, eax
    jz .fail
    xor eax, eax
    ret
.fail:
    mov eax, -1
    ret

hal_exit:
    ; (code)
    call win_bootstrap_ensure
    mov ecx, edi
    mov rax, [rel win32_ExitProcess]
    sub rsp, 40
    call rax
    add rsp, 40
    hlt

hal_clock_gettime:
    ; (clock_id, timespec*) -> 0/-1
    ; timespec: [0]=sec, [8]=nsec
    push rbx
    push r12
    mov r12, rsi
    call win_bootstrap_ensure
    test eax, eax
    js .fail

    sub rsp, 72
    lea rcx, [rsp + 48]              ; counter (LARGE_INTEGER)
    mov rax, [rel win32_QueryPerformanceCounter]
    call rax
    test eax, eax
    jz .err
    lea rcx, [rsp + 56]              ; freq (LARGE_INTEGER)
    mov rax, [rel win32_QueryPerformanceFrequency]
    call rax
    test eax, eax
    jz .err

    mov rax, [rsp + 48]              ; ticks
    xor edx, edx
    mov rbx, [rsp + 56]              ; ticks/sec
    test rbx, rbx
    jz .err
    div rbx                          ; rax=sec, rdx=rem
    mov [r12 + TIMESPEC_SEC_OFF], rax

    mov rax, rdx
    mov rbx, NSECS_PER_SEC
    mul rbx
    mov rbx, [rsp + 56]
    xor edx, edx
    div rbx
    mov [r12 + TIMESPEC_NSEC_OFF], rax
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

hal_getenv:
    ; (name, out, out_cap) -> len or -1
    mov r10d, edx
    call win_bootstrap_ensure
    test eax, eax
    js .fail
    mov rcx, rdi
    mov rdx, rsi
    mov r8d, r10d
    sub rsp, 40
    mov rax, [rel win32_GetEnvironmentVariableA]
    call rax
    add rsp, 40
    test eax, eax
    jz .fail
    ret
.fail:
    mov eax, -1
    ret

hal_getenv_raw:
    xor eax, eax
    ret

hal_fork:
    ; no fork on Win32 - use hal_spawn/CreateProcess path
    mov eax, -1
    ret

hal_spawn:
    ; (cmdline, stdin_h, stdout_h) -> process handle or -1
    ; cmdline must be mutable buffer for CreateProcessA.
    push rbx
    mov rbx, rdi                     ; cmdline
    mov r10, rsi                     ; stdin
    mov r11, rdx                     ; stdout
    call win_bootstrap_ensure
    test eax, eax
    js .fail

    test r10, r10
    jnz .have_stdin
    mov ecx, STD_INPUT_HANDLE
    sub rsp, 40
    mov rax, [rel win32_GetStdHandle]
    call rax
    add rsp, 40
    mov r10, rax
.have_stdin:
    test r11, r11
    jnz .have_stdout
    mov ecx, STD_OUTPUT_HANDLE
    sub rsp, 40
    mov rax, [rel win32_GetStdHandle]
    call rax
    add rsp, 40
    mov r11, rax
.have_stdout:

    sub rsp, 304                     ; shadow + call args + local structs
    ; STARTUPINFOA at rsp+128
    ; PROCESS_INFORMATION at rsp+240
    lea rdi, [rsp + 128]
    mov ecx, STARTUPINFOA_SIZE
    xor eax, eax
    rep stosb
    mov dword [rsp + 128], STARTUPINFOA_SIZE
    mov dword [rsp + 128 + STARTUPINFOA_DWFLAGS_OFF], STARTF_USESTDHANDLES
    mov [rsp + 128 + STARTUPINFOA_HSTDIN_OFF], r10
    mov [rsp + 128 + STARTUPINFOA_HSTDOUT_OFF], r11
    mov [rsp + 128 + STARTUPINFOA_HSTDERR_OFF], r11

    ; BOOL CreateProcessA(lpAppName, lpCmdLine, lpProcAttr, lpThreadAttr,
    ;   bInheritHandles, dwCreationFlags, lpEnv, lpCwd, lpStartupInfo, lpProcessInfo)
    mov qword [rsp + 32], 0          ; lpProcessAttributes
    mov qword [rsp + 40], 0          ; lpThreadAttributes
    mov qword [rsp + 48], 1          ; bInheritHandles
    mov qword [rsp + 56], 0          ; dwCreationFlags
    mov qword [rsp + 64], 0          ; lpEnvironment
    mov qword [rsp + 72], 0          ; lpCurrentDirectory
    lea rax, [rsp + 128]             ; STARTUPINFOA
    mov [rsp + 80], rax
    lea rax, [rsp + 240]             ; PROCESS_INFORMATION
    mov [rsp + 88], rax
    mov rcx, 0
    mov rdx, rbx
    mov r8, 0
    mov r9, 0
    mov rax, [rel win32_CreateProcessA]
    call rax
    test eax, eax
    jz .spawn_fail

    ; close thread handle, return process handle
    mov rcx, [rsp + 240 + PROCINFO_HTHREAD_OFF]
    mov rax, [rel win32_CloseHandle]
    call rax
    mov rax, [rsp + 240 + PROCINFO_HPROCESS_OFF]
    add rsp, 304
    pop rbx
    ret

.spawn_fail:
    add rsp, 304
.fail:
    mov rax, -1
    pop rbx
    ret

hal_execve:
    ; (path, argv, envp) -> -1 (use hal_spawn in Windows path)
    mov eax, -1
    ret

hal_pipe:
    ; (ptr_to_two_handles) -> 0/-1
    call win_bootstrap_ensure
    test eax, eax
    js .fail
    sub rsp, 56
    mov qword [rsp + 32], 0
    mov qword [rsp + 40], 0
    mov rcx, rdi
    lea rdx, [rdi + 8]
    mov r8, 0
    mov r9d, 0
    mov rax, [rel win32_CreatePipe]
    call rax
    add rsp, 56
    test eax, eax
    jz .fail
    xor eax, eax
    ret
.fail:
    mov eax, -1
    ret

hal_dup2:
    ; (old_handle, new_fd[0/1/2]) -> 0/-1
    call win_bootstrap_ensure
    test eax, eax
    js .fail
    cmp esi, 0
    je .in
    cmp esi, 1
    je .out
    cmp esi, 2
    je .err
    jmp .fail
.in:
    mov ecx, STD_INPUT_HANDLE
    jmp .set
.out:
    mov ecx, STD_OUTPUT_HANDLE
    jmp .set
.err:
    mov ecx, STD_ERROR_HANDLE
.set:
    mov rdx, rdi
    sub rsp, 40
    mov rax, [rel win32_SetStdHandle]
    call rax
    add rsp, 40
    test eax, eax
    jz .fail
    xor eax, eax
    ret
.fail:
    mov eax, -1
    ret

hal_waitpid:
    ; (process_handle, status_ptr, options_ignored) -> 0/-1
    push rbx
    mov rbx, rsi
    call win_bootstrap_ensure
    test eax, eax
    js .fail
    mov rcx, rdi
    mov edx, INFINITE
    sub rsp, 56
    mov rax, [rel win32_WaitForSingleObject]
    call rax
    cmp eax, WAIT_OBJECT_0
    jne .err
    mov rcx, rdi
    lea rdx, [rsp + 48]
    mov rax, [rel win32_GetExitCodeProcess]
    call rax
    test eax, eax
    jz .err
    test rbx, rbx
    jz .close
    mov eax, [rsp + 48]
    mov [rbx], eax
.close:
    mov rcx, rdi
    mov rax, [rel win32_CloseHandle]
    call rax
    add rsp, 56
    xor eax, eax
    pop rbx
    ret
.err:
    add rsp, 56
.fail:
    mov eax, -1
    pop rbx
    ret

hal_socket:
    ; (domain, type, proto) -> socket or -1
    mov r10d, edx
    call win_bootstrap_ensure
    test eax, eax
    js .fail
    mov ecx, edi
    mov edx, esi
    mov r8d, r10d
    sub rsp, 40
    mov rax, [rel win32_socket]
    call rax
    add rsp, 40
    cmp eax, -1
    je .fail
    ret
.fail:
    mov eax, -1
    ret

hal_connect:
    ; (sock, sockaddr*, len) -> 0/-1
    mov r10d, edx
    call win_bootstrap_ensure
    test eax, eax
    js .fail
    mov rcx, rdi
    mov rdx, rsi
    mov r8d, r10d
    sub rsp, 40
    mov rax, [rel win32_connect]
    call rax
    add rsp, 40
    ret
.fail:
    mov eax, -1
    ret

hal_bind:
    ; (sock, sockaddr*, len) -> 0/-1
    mov r10d, edx
    call win_bootstrap_ensure
    test eax, eax
    js .fail
    mov rcx, rdi
    mov rdx, rsi
    mov r8d, r10d
    sub rsp, 40
    mov rax, [rel win32_bind]
    call rax
    add rsp, 40
    ret
.fail:
    mov eax, -1
    ret

hal_listen:
    ; (sock, backlog) -> 0/-1
    call win_bootstrap_ensure
    test eax, eax
    js .fail
    mov rcx, rdi
    mov rdx, rsi
    sub rsp, 40
    mov rax, [rel win32_listen]
    call rax
    add rsp, 40
    ret
.fail:
    mov eax, -1
    ret

hal_accept4:
    ; (sock, addr, lenptr, flags_ignored) -> client sock or -1
    mov r10, rdx
    call win_bootstrap_ensure
    test eax, eax
    js .fail
    mov rcx, rdi
    mov rdx, rsi
    mov r8, r10
    sub rsp, 40
    mov rax, [rel win32_accept]
    call rax
    add rsp, 40
    ret
.fail:
    mov eax, -1
    ret

hal_sleep_ms:
    ; (milliseconds) -> 0
    call win_bootstrap_ensure
    test eax, eax
    js .fail
    mov ecx, edi
    sub rsp, 40
    mov rax, [rel win32_Sleep]
    test rax, rax
    jz .err
    call rax
    add rsp, 40
    xor eax, eax
    ret
.err:
    add rsp, 40
.fail:
    mov eax, -1
    ret

hal_wsapoll:
    ; (fds_ptr, nfds, timeout_ms) -> ready_count or -1
    test esi, esi
    jz .zero
    mov r10d, edx
    call win_bootstrap_ensure
    test eax, eax
    js .fail
    mov rcx, rdi
    mov edx, esi
    mov r8d, r10d
    sub rsp, 40
    mov rax, [rel win32_WSAPoll]
    test rax, rax
    jz .err
    call rax
    add rsp, 40
    ret
.err:
    add rsp, 40
.fail:
    mov eax, -1
    ret
.zero:
    xor eax, eax
    ret

hal_event_poll:
    ; alias to WSAPoll-based event polling
    jmp hal_wsapoll

hal_thread_create:
    ; (fn_ptr, arg_ptr, stack_size) -> handle or -1
    ; Context block via VirtualAlloc: [0]=fn, [8]=arg
    push rbx
    push r12
    mov rbx, rdi
    mov r12, rdx
    test rbx, rbx
    jz .fail
    call win_bootstrap_ensure
    test eax, eax
    js .fail

    ; allocate 16-byte context
    mov rcx, 0
    mov rdx, 16
    mov r8d, MEM_COMMIT | MEM_RESERVE
    mov r9d, PAGE_READWRITE
    sub rsp, 56
    mov rax, [rel win32_VirtualAlloc]
    call rax
    test rax, rax
    jz .alloc_fail
    mov [rax], rbx
    mov [rax + 8], rsi
    mov r11, rax                      ; context

    ; CreateThread(NULL, stack, win_thread_entry, ctx, 0, NULL)
    mov qword [rsp + 32], 0           ; dwCreationFlags (5th arg)
    mov qword [rsp + 40], 0           ; lpThreadId (6th arg)
    xor ecx, ecx
    mov rdx, r12
    lea r8, [rel win_thread_entry]
    mov r9, r11
    mov rax, [rel win32_CreateThread]
    call rax
    test rax, rax
    jz .alloc_fail
    add rsp, 56
    pop r12
    pop rbx
    ret

.alloc_fail:
    add rsp, 56
.fail:
    mov rax, -1
    pop r12
    pop rbx
    ret

hal_thread_join:
    ; (thread_handle) -> 0/-1
    call win_bootstrap_ensure
    test eax, eax
    js .fail
    mov rcx, rdi
    mov edx, INFINITE
    sub rsp, 40
    mov rax, [rel win32_WaitForSingleObject]
    call rax
    cmp eax, WAIT_OBJECT_0
    jne .err
    mov rcx, rdi
    mov rax, [rel win32_CloseHandle]
    call rax
    add rsp, 40
    xor eax, eax
    ret
.err:
    add rsp, 40
.fail:
    mov eax, -1
    ret

hal_mutex_init:
    ; (mutex_ptr) -> 0/-1, SRWLOCK init is zero
    test rdi, rdi
    jz .fail
    mov qword [rdi], 0
    xor eax, eax
    ret
.fail:
    mov eax, -1
    ret

hal_mutex_lock:
    ; (mutex_ptr) -> 0/-1
    call win_bootstrap_ensure
    test eax, eax
    js .fail
    test rdi, rdi
    jz .fail
    mov rcx, rdi
    sub rsp, 40
    mov rax, [rel win32_AcquireSRWLockExclusive]
    test rax, rax
    jz .err
    call rax
    add rsp, 40
    xor eax, eax
    ret
.err:
    add rsp, 40
.fail:
    mov eax, -1
    ret

hal_mutex_unlock:
    ; (mutex_ptr) -> 0/-1
    call win_bootstrap_ensure
    test eax, eax
    js .fail
    test rdi, rdi
    jz .fail
    mov rcx, rdi
    sub rsp, 40
    mov rax, [rel win32_ReleaseSRWLockExclusive]
    test rax, rax
    jz .err
    call rax
    add rsp, 40
    xor eax, eax
    ret
.err:
    add rsp, 40
.fail:
    mov eax, -1
    ret

hal_mutex_destroy:
    ; SRWLOCK has no destroy
    xor eax, eax
    ret

hal_atomic_inc:
    ; (ptr qword*) -> new value or -1
    call win_bootstrap_ensure
    test eax, eax
    js .fail
    test rdi, rdi
    jz .fail
    mov rcx, rdi
    sub rsp, 40
    mov rax, [rel win32_InterlockedIncrement64]
    test rax, rax
    jz .err
    call rax
    add rsp, 40
    ret
.err:
    add rsp, 40
.fail:
    mov rax, -1
    ret
