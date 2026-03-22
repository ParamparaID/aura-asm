; syscall.asm
; Linux x86_64 syscall wrappers for Aura HAL
; Author: Aura Shell Team
; Date: 2026-03-19

%include "src/hal/linux_x86_64/defs.inc"

section .data

section .bss

section .text

global hal_write
global hal_read
global hal_open
global hal_close
global hal_mmap
global hal_munmap
global hal_exit
global hal_clock_gettime
global hal_socket
global hal_bind
global hal_listen
global hal_accept4
global hal_unlink

; syscall_6:
; Universal syscall macro for Linux x86_64.
; Input:
;   %1 = syscall number
;   %2..%7 = args 1..6
; Clobbers: rax, rdi, rsi, rdx, r10, r8, r9
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

; hal_write(fd, buf, len)
; Params:
;   rdi = file descriptor
;   rsi = pointer to buffer
;   rdx = byte length
; Return:
;   rax = bytes written, or negative errno
hal_write:
    syscall_6 SYS_WRITE, rdi, rsi, rdx, 0, 0, 0
    ret

; hal_read(fd, buf, len)
; Params:
;   rdi = file descriptor
;   rsi = pointer to buffer
;   rdx = byte length
; Return:
;   rax = bytes read, or negative errno
hal_read:
    syscall_6 SYS_READ, rdi, rsi, rdx, 0, 0, 0
    ret

; hal_open(path, flags, mode)
; Params:
;   rdi = pathname pointer
;   rsi = open flags
;   rdx = file mode (used with O_CREAT)
; Return:
;   rax = file descriptor, or negative errno
hal_open:
    syscall_6 SYS_OPEN, rdi, rsi, rdx, 0, 0, 0
    ret

; hal_close(fd)
; Params:
;   rdi = file descriptor
; Return:
;   rax = 0 on success, or negative errno
hal_close:
    syscall_6 SYS_CLOSE, rdi, 0, 0, 0, 0, 0
    ret

; hal_mmap(addr, len, prot, flags, fd, offset)
; Params (System V AMD64):
;   rdi = addr
;   rsi = len
;   rdx = prot
;   rcx = flags
;   r8  = fd
;   r9  = offset
; Return:
;   rax = mapped address, or negative errno
hal_mmap:
    syscall_6 SYS_MMAP, rdi, rsi, rdx, rcx, r8, r9
    ret

; hal_munmap(addr, len)
; Params:
;   rdi = mapped address
;   rsi = mapping length
; Return:
;   rax = 0 on success, or negative errno
hal_munmap:
    syscall_6 SYS_MUNMAP, rdi, rsi, 0, 0, 0, 0
    ret

; hal_exit(code)
; Params:
;   rdi = exit code
; Return:
;   Does not return
hal_exit:
    syscall_6 SYS_EXIT, rdi, 0, 0, 0, 0, 0
    ud2

; hal_clock_gettime(clock_id, timespec_ptr)
; Params:
;   rdi = clock id (CLOCK_MONOTONIC/CLOCK_REALTIME)
;   rsi = pointer to struct timespec
; Return:
;   rax = 0 on success, or negative errno
hal_clock_gettime:
    syscall_6 SYS_CLOCK_GETTIME, rdi, rsi, 0, 0, 0, 0
    ret

; hal_socket(domain, type, protocol)
hal_socket:
    syscall_6 SYS_SOCKET, rdi, rsi, rdx, 0, 0, 0
    ret

; hal_bind(fd, addr, addr_len)
hal_bind:
    syscall_6 SYS_BIND, rdi, rsi, rdx, 0, 0, 0
    ret

; hal_listen(fd, backlog)
hal_listen:
    syscall_6 SYS_LISTEN, rdi, rsi, 0, 0, 0, 0
    ret

; hal_accept4(fd, addr, addr_len, flags)
hal_accept4:
    syscall_6 SYS_ACCEPT4, rdi, rsi, rdx, r10, 0, 0
    ret

; hal_unlink(path)
hal_unlink:
    syscall_6 SYS_UNLINK, rdi, 0, 0, 0, 0, 0
    ret
