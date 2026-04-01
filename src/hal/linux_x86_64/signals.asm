; signals.asm
; Linux x86_64 signal/process-group wrappers

%include "src/hal/platform_defs.inc"

section .text
global hal_sigaction
global hal_kill
global hal_getpid
global hal_setpgid
global hal_tcsetpgrp
global hal_tcgetpgrp
global hal_sigreturn_restorer

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

; hal_sigaction(signum, act_ptr, oldact_ptr)
; rdi=signum, rsi=act, rdx=oldact
; rax=0 or error
hal_sigaction:
    syscall_6 SYS_RT_SIGACTION, rdi, rsi, rdx, 8, 0, 0
    ret

; hal_kill(pid, sig)
; rdi=pid, rsi=sig
hal_kill:
    syscall_6 SYS_KILL, rdi, rsi, 0, 0, 0, 0
    ret

; hal_getpid()
hal_getpid:
    syscall_6 SYS_GETPID, 0, 0, 0, 0, 0, 0
    ret

; hal_setpgid(pid, pgid)
; rdi=pid, rsi=pgid
hal_setpgid:
    syscall_6 SYS_SETPGID, rdi, rsi, 0, 0, 0, 0
    ret

; hal_tcsetpgrp(fd, pgid)
; rdi=fd, rsi=pgid
hal_tcsetpgrp:
    sub rsp, 8
    mov [rsp], esi
    syscall_6 SYS_IOCTL, rdi, TIOCSPGRP, rsp, 0, 0, 0
    add rsp, 8
    ret

; hal_tcgetpgrp(fd)
; rdi=fd -> rax=pgid or error
hal_tcgetpgrp:
    sub rsp, 8
    syscall_6 SYS_IOCTL, rdi, TIOCGPGRP, rsp, 0, 0, 0
    test rax, rax
    js .err
    movsx rax, dword [rsp]
.err:
    add rsp, 8
    ret

; rt_sigreturn restorer for SA_RESTORER
hal_sigreturn_restorer:
    mov rax, 15
    syscall
