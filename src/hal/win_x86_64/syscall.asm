; syscall.asm - Win32 HAL wrappers with SysV-compatible entry ABI
%include "src/hal/win_x86_64/defs.inc"

extern hal_open
extern hal_close
extern win32_CloseHandle
extern win32_VirtualFree
extern win32_ExitProcess
extern win32_GetStdHandle
extern hal_spawn
extern hal_pipe
extern hal_waitpid
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
global hal_exit
global hal_getenv
global hal_getenv_raw
global hal_fork
global hal_execve
global hal_dup2
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
    global_envp                      resq 1

section .text

extern win_bootstrap_ensure

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

hal_execve:
    ; (path, argv, envp) -> -1 (use hal_spawn in Windows path)
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
    cld
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
    cld
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
