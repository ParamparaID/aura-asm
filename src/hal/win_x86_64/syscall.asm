; syscall.asm - Win32 HAL wrappers with SysV-compatible entry ABI
%include "src/hal/win_x86_64/defs.inc"

extern win32_CreateFileA
extern win32_ReadFile
extern win32_WriteFile
extern win32_CloseHandle
extern win32_VirtualFree
extern win32_ExitProcess
extern win32_GetStdHandle
extern win32_CreatePipe
extern win32_CreateProcessA
extern win32_GetExitCodeProcess
extern win32_GetEnvironmentVariableA
extern win32_SetStdHandle
extern win32_WaitForSingleObject
extern win32_WSAPoll
extern win32_Sleep
extern win32_socket
extern win32_connect
extern win32_bind
extern win32_listen
extern win32_accept
extern win32_closesocket
extern win32_GetCurrentDirectoryA

section .text
global hal_write
global hal_read
global hal_open
global hal_close
global hal_exit
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
global hal_sigaction
global hal_sigreturn_restorer
global hal_access
global hal_chdir
global hal_getcwd
global hal_getdents64
global hal_stat
global hal_lstat
global hal_rename
global hal_unlink
global hal_rmdir
global hal_mkdir
global hal_chmod
global hal_statfs
global hal_lseek
global hal_kill
global hal_getpid
global hal_tcsetpgrp
global global_envp

section .bss
    win_spawn_si                     resb STARTUPINFOA_SIZE
    win_spawn_pi                     resb PROCESS_INFORMATION_SIZE
    global_envp                      resq 1

section .text

extern win_bootstrap_ensure

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
    sub rsp, 80
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
    add rsp, 80
    pop rbx
    ret
.err:
    add rsp, 80
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
    sub rsp, 80
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
    add rsp, 80
    pop rbx
    ret
.err:
    add rsp, 80
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

hal_exit:
    ; (code)
    call win_bootstrap_ensure
    mov ecx, edi
    mov rax, [rel win32_ExitProcess]
    sub rsp, 40
    call rax
    add rsp, 40
    hlt

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
    push rdi
    push rsi
    push rbx
    push r12
    push r13
    mov rbx, rdi                     ; cmdline
    mov r12, rsi                     ; stdin
    mov r13, rdx                     ; stdout
    call win_bootstrap_ensure
    test eax, eax
    js .fail

    test r12, r12
    jnz .have_stdin
    mov ecx, STD_INPUT_HANDLE
    sub rsp, 32
    mov rax, [rel win32_GetStdHandle]
    call rax
    add rsp, 32
    mov r12, rax
.have_stdin:
    test r13, r13
    jnz .have_stdout
    mov ecx, STD_OUTPUT_HANDLE
    sub rsp, 32
    mov rax, [rel win32_GetStdHandle]
    call rax
    add rsp, 32
    mov r13, rax
.have_stdout:
    ; zero static STARTUPINFOA/PROCESS_INFORMATION buffers
    lea rdi, [rel win_spawn_si]
    mov ecx, STARTUPINFOA_SIZE
    xor eax, eax
    rep stosb
    lea rdi, [rel win_spawn_pi]
    mov ecx, PROCESS_INFORMATION_SIZE
    xor eax, eax
    rep stosb
    mov dword [rel win_spawn_si + 0], STARTUPINFOA_SIZE
    mov dword [rel win_spawn_si + STARTUPINFOA_DWFLAGS_OFF], STARTF_USESTDHANDLES
    mov [rel win_spawn_si + STARTUPINFOA_HSTDIN_OFF], r12
    mov [rel win_spawn_si + STARTUPINFOA_HSTDOUT_OFF], r13
    mov [rel win_spawn_si + STARTUPINFOA_HSTDERR_OFF], r13

    ; BOOL CreateProcessA(lpAppName, lpCmdLine, lpProcAttr, lpThreadAttr,
    ;   bInheritHandles, dwCreationFlags, lpEnv, lpCwd, lpStartupInfo, lpProcessInfo)
    sub rsp, 96
    mov qword [rsp + 32], 1          ; bInheritHandles
    mov qword [rsp + 40], 0          ; dwCreationFlags
    mov qword [rsp + 48], 0          ; lpEnvironment
    mov qword [rsp + 56], 0          ; lpCurrentDirectory
    lea rax, [rel win_spawn_si]      ; STARTUPINFOA
    mov [rsp + 64], rax              ; 9th arg
    lea rax, [rel win_spawn_pi]      ; PROCESS_INFORMATION
    mov [rsp + 72], rax              ; 10th arg
    mov rcx, 0
    mov rdx, rbx
    mov r8, 0
    mov r9, 0
    mov rax, [rel win32_CreateProcessA]
    call rax
    test eax, eax
    jz .spawn_fail

    ; close thread handle, return process handle
    mov rcx, [rel win_spawn_pi + PROCINFO_HTHREAD_OFF]
    mov rax, [rel win32_CloseHandle]
    sub rsp, 32
    call rax
    add rsp, 32
    mov rax, [rel win_spawn_pi + PROCINFO_HPROCESS_OFF]
    add rsp, 96
    pop r13
    pop r12
    pop rbx
    pop rsi
    pop rdi
    ret

.spawn_fail:
    add rsp, 96
.fail:
    mov rax, -1
    pop r13
    pop r12
    pop rbx
    pop rsi
    pop rdi
    ret

hal_execve:
    ; (path, argv, envp) -> -1 (use hal_spawn in Windows path)
    mov eax, -1
    ret

hal_pipe:
    ; (ptr_to_two_handles) -> 0/-1
    push rdi
    push rsi
    call win_bootstrap_ensure
    test eax, eax
    js .fail
    ; SECURITY_ATTRIBUTES with bInheritHandle=TRUE
    sub rsp, 104
    mov dword [rsp + 32], 24           ; nLength
    mov qword [rsp + 40], 0            ; lpSecurityDescriptor
    mov dword [rsp + 48], 1            ; bInheritHandle
    mov rcx, rdi
    lea rdx, [rdi + 8]
    lea r8, [rsp + 32]
    mov r9d, 0
    mov rax, [rel win32_CreatePipe]
    call rax
    add rsp, 104
    test eax, eax
    jz .fail
    pop rsi
    pop rdi
    xor eax, eax
    ret
.fail:
    pop rsi
    pop rdi
    mov eax, -1
    ret

hal_dup2:
    ; (old_handle, new_fd[0/1/2]) -> 0/-1
    push rdi
    push rsi
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
    pop rsi
    pop rdi
    xor eax, eax
    ret
.fail:
    pop rsi
    pop rdi
    mov eax, -1
    ret

hal_waitpid:
    ; (process_handle, status_ptr, options_ignored) -> 0/-1
    ; Windows HANDLE wait + exit code retrieval.
    push rdi
    push rsi
    push rbx
    push r12
    mov rbx, rdi                      ; process handle
    mov r12, rsi                      ; status_ptr (optional)
    test rbx, rbx
    jz .fail
    call win_bootstrap_ensure
    test eax, eax
    js .fail

    ; WaitForSingleObject(process, INFINITE)
    mov rcx, rbx
    mov edx, 0xFFFFFFFF
    sub rsp, 40
    mov rax, [rel win32_WaitForSingleObject]
    call rax
    add rsp, 40
    cmp eax, 0xFFFFFFFF               ; WAIT_FAILED
    je .close_fail

    ; GetExitCodeProcess(process, &code)
    sub rsp, 48
    mov rcx, rbx
    lea rdx, [rsp + 32]
    mov rax, [rel win32_GetExitCodeProcess]
    call rax
    test eax, eax
    jz .getcode_fail

    test r12, r12
    jz .close_ok
    mov eax, [rsp + 32]
    mov [r12], eax

.close_ok:
    add rsp, 48
    mov rcx, rbx
    sub rsp, 40
    mov rax, [rel win32_CloseHandle]
    call rax
    add rsp, 40
    test eax, eax
    jz .fail
    xor eax, eax
    pop r12
    pop rbx
    pop rsi
    pop rdi
    ret

.getcode_fail:
    add rsp, 48
.close_fail:
    mov rcx, rbx
    sub rsp, 40
    mov rax, [rel win32_CloseHandle]
    call rax
    add rsp, 40
.fail:
    mov eax, -1
    pop r12
    pop rbx
    pop rsi
    pop rdi
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
    test rsi, rsi
    jnz .do_poll
    ; POSIX-compatible behavior: poll/WSAPoll with nfds=0 is valid.
    xor eax, eax
    ret
.do_poll:
    mov r10d, edx
    call win_bootstrap_ensure
    test eax, eax
    js .fail
    mov rcx, rdi
    mov rdx, rsi
    mov r8d, r10d
    sub rsp, 40
    mov rax, [rel win32_WSAPoll]
    test rax, rax
    jz .err
    call rax
    add rsp, 40
    cmp eax, -1
    je .fail
    ret
.err:
    add rsp, 40
.fail:
    mov eax, -1
    ret

hal_event_poll:
    ; alias to WSAPoll-based event polling
    jmp hal_wsapoll

hal_sigaction:
    ; Windows no-op compatibility for REPL signal setup.
    xor eax, eax
    ret

hal_sigreturn_restorer:
    ret

; --- Linux compatibility symbols used by shell/FM on Win build ---
; These are minimal compatibility shims to unblock native Win shell/FM linking.

hal_access:
    ; (path, mode) -> 0/-1
    push rbx
    mov rbx, rdi
    test rbx, rbx
    jz .fail
    mov rdi, rbx
    mov esi, O_RDONLY
    xor edx, edx
    call hal_open
    test rax, rax
    js .fail
    mov rdi, rax
    call hal_close
    xor eax, eax
    pop rbx
    ret
.fail:
    mov eax, -1
    pop rbx
    ret

hal_chdir:
    ; (path) -> 0/-1 (best-effort no-op on Win path)
    test rdi, rdi
    jz .fail
    xor eax, eax
    ret
.fail:
    mov eax, -1
    ret

; hal_getcwd(buf rdi, size rsi) -> rax buf or -1 (Linux-compatible)
hal_getcwd:
    push rbx
    mov rbx, rdi
    test rbx, rbx
    jz .gc_fail
    test rsi, rsi
    jz .gc_fail
    call win_bootstrap_ensure
    test eax, eax
    js .gc_fail
    mov rax, [rel win32_GetCurrentDirectoryA]
    test rax, rax
    jz .gc_fail
    mov ecx, esi
    mov rdx, rbx
    sub rsp, 32
    call rax
    add rsp, 32
    test eax, eax
    jz .gc_fail
    mov rax, rbx
    pop rbx
    ret
.gc_fail:
    mov rax, -1
    pop rbx
    ret

hal_getdents64:
    ; (fd, buf, size) -> bytes or 0/-1
    ; Minimal shim: no directory entries for now.
    xor eax, eax
    ret

hal_stat:
    ; (path, stat_buf) -> 0/-1
    test rdi, rdi
    jz .fail
    test rsi, rsi
    jz .fail
    push rbx
    mov rbx, rsi
    mov rdi, rbx
    mov ecx, 144
    xor eax, eax
    rep stosb
    mov dword [rbx + 24], 0x81A4      ; S_IFREG | 0644
    mov dword [rbx + 28], 0
    mov dword [rbx + 32], 0
    mov qword [rbx + 48], 0
    mov qword [rbx + 88], 0
    xor eax, eax
    pop rbx
    ret
.fail:
    mov eax, -1
    ret

hal_lstat:
    jmp hal_stat

hal_rename:
    ; (old_path, new_path) -> 0/-1 (best-effort success)
    test rdi, rdi
    jz .fail
    test rsi, rsi
    jz .fail
    xor eax, eax
    ret
.fail:
    mov eax, -1
    ret

hal_unlink:
    ; (path) -> 0/-1 (best-effort success)
    test rdi, rdi
    jz .fail
    xor eax, eax
    ret
.fail:
    mov eax, -1
    ret

hal_rmdir:
    ; (path) -> 0/-1
    test rdi, rdi
    jz .fail
    xor eax, eax
    ret
.fail:
    mov eax, -1
    ret

hal_mkdir:
    ; (path, mode) -> 0/-1
    test rdi, rdi
    jz .fail
    xor eax, eax
    ret
.fail:
    mov eax, -1
    ret

hal_chmod:
    ; (path, mode) -> 0/-1
    test rdi, rdi
    jz .fail
    xor eax, eax
    ret
.fail:
    mov eax, -1
    ret

hal_statfs:
    ; (path, statfs_buf) -> 0/-1
    test rsi, rsi
    jz .fail
    push rbx
    mov rbx, rsi
    mov rdi, rbx
    mov ecx, 128
    xor eax, eax
    rep stosb
    mov qword [rbx + 8], 4096         ; f_bsize
    mov qword [rbx + 16], 1           ; f_blocks
    mov qword [rbx + 32], 1           ; f_bavail
    xor eax, eax
    pop rbx
    ret
.fail:
    mov eax, -1
    ret

hal_lseek:
    ; (fd, offset, whence) -> new pos or -1
    xor eax, eax
    ret

hal_kill:
    ; (pid, sig) -> 0/-1
    xor eax, eax
    ret

hal_getpid:
    mov eax, 1
    ret

hal_tcsetpgrp:
    ; (fd, pgid) -> 0/-1
    xor eax, eax
    ret
