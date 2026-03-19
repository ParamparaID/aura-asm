; errno.asm
; Linux syscall error helpers for Aura HAL
; Author: Aura Shell Team
; Date: 2026-03-19

%define EAGAIN      11
%define ENOMEM      12
%define EACCES      13
%define ENOENT      2
%define EINTR       4
%define EBADF       9
%define MAX_ERRNO   4095

section .data

section .bss

section .text

global hal_is_error
global hal_errno

; hal_is_error(rax_value)
; Params:
;   rdi = syscall return value
; Return:
;   rax = 1 if value is in [-4095, -1], else 0
hal_is_error:
    xor eax, eax
    test rdi, rdi
    jns .done
    mov rax, rdi
    neg rax
    cmp rax, MAX_ERRNO
    jbe .is_error
    xor eax, eax
    ret
.is_error:
    mov eax, 1
.done:
    ret

; hal_errno(rax_value)
; Params:
;   rdi = syscall return value
; Return:
;   rax = positive errno if value is in [-4095, -1], else 0
hal_errno:
    xor eax, eax
    test rdi, rdi
    jns .done
    mov rax, rdi
    neg rax
    cmp rax, MAX_ERRNO
    jbe .done
    xor eax, eax
.done:
    ret
