; process.asm
; Linux x86_64 process-related syscall wrappers for Aura HAL

%include "src/hal/linux_x86_64/defs.inc"

section .text
global global_envp
global hal_fork
global hal_execve
global hal_waitpid
global hal_dup2
global hal_pipe
global hal_access
global hal_getcwd
global hal_chdir
global hal_getenv_raw

section .bss
    global_envp          resq 1

section .text

%macro syscall_6 7
    mov rax, %1
    mov rdi, %2
    mov rsi, %3
    mov rdx, %4
    mov r10, %5
    mov r8,  %6
    mov r9,  %7
    syscall
%endmacro

; hal_fork()
; Returns: rax=0 in child, rax=child pid in parent, rax<0 on error
hal_fork:
    syscall_6 SYS_CLONE, SIGCHLD, 0, 0, 0, 0, 0
    ret

; hal_execve(path, argv, envp)
; rdi=path, rsi=argv, rdx=envp
; Returns only on error (rax<0)
hal_execve:
    syscall_6 SYS_EXECVE, rdi, rsi, rdx, 0, 0, 0
    ret

; hal_waitpid(pid, status_ptr, options)
; rdi=pid, rsi=status_ptr, rdx=options
; Returns pid or error (rax<0)
hal_waitpid:
    syscall_6 SYS_WAIT4, rdi, rsi, rdx, 0, 0, 0
    ret

; hal_dup2(oldfd, newfd)
; rdi=oldfd, rsi=newfd
; Returns newfd or error
hal_dup2:
    syscall_6 SYS_DUP2, rdi, rsi, 0, 0, 0, 0
    ret

; hal_pipe(pipefd_ptr)
; rdi=pointer to int[2]
; Returns 0 or error
hal_pipe:
    syscall_6 SYS_PIPE2, rdi, 0, 0, 0, 0, 0
    ret

; hal_access(path, mode)
; rdi=path, rsi=mode
; Returns 0 or error
hal_access:
    syscall_6 SYS_ACCESS, rdi, rsi, 0, 0, 0, 0
    ret

; hal_getcwd(buf, size)
; rdi=buf, rsi=size
; Returns buf ptr or error
hal_getcwd:
    syscall_6 SYS_GETCWD, rdi, rsi, 0, 0, 0, 0
    ret

; hal_chdir(path)
; rdi=path
; Returns 0 or error
hal_chdir:
    syscall_6 SYS_CHDIR, rdi, 0, 0, 0, 0, 0
    ret

; hal_getenv_raw()
; Returns: rax = envp pointer captured at _start
hal_getenv_raw:
    mov rax, [rel global_envp]
    ret
