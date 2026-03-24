; fs.asm
; Extra filesystem syscall wrappers for Aura HAL

%include "src/hal/linux_x86_64/defs.inc"

section .text

global hal_getdents64
global hal_newfstatat
global hal_stat
global hal_lstat
global hal_rename
global hal_unlinkat
global hal_rmdir
global hal_mkdir
global hal_symlink
global hal_readlink
global hal_chmod
global hal_chown
global hal_utimensat
global hal_statfs

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

; hal_getdents64(fd, buf, size)
hal_getdents64:
    syscall_6 SYS_GETDENTS64, rdi, rsi, rdx, 0, 0, 0
    ret

; hal_newfstatat(dirfd, path, stat_buf, flags)
; flags is passed in rcx (SysV arg4)
hal_newfstatat:
    mov r10, rcx
    syscall_6 SYS_NEWFSTATAT, rdi, rsi, rdx, r10, 0, 0
    ret

; hal_stat(path, stat_buf)
hal_stat:
    mov rdx, rsi
    mov rsi, rdi
    mov rdi, AT_FDCWD
    xor ecx, ecx
    call hal_newfstatat
    ret

; hal_lstat(path, stat_buf)
hal_lstat:
    mov rdx, rsi
    mov rsi, rdi
    mov rdi, AT_FDCWD
    mov ecx, AT_SYMLINK_NOFOLLOW
    call hal_newfstatat
    ret

; hal_rename(old_path, new_path)
hal_rename:
    syscall_6 SYS_RENAME, rdi, rsi, 0, 0, 0, 0
    ret

; hal_unlinkat(dirfd, path, flags)
hal_unlinkat:
    syscall_6 SYS_UNLINKAT, rdi, rsi, rdx, 0, 0, 0
    ret

; hal_rmdir(path)
hal_rmdir:
    mov rsi, rdi
    mov rdi, AT_FDCWD
    mov edx, AT_REMOVEDIR
    call hal_unlinkat
    ret

; hal_mkdir(path, mode)
hal_mkdir:
    syscall_6 SYS_MKDIR, rdi, rsi, 0, 0, 0, 0
    ret

; hal_symlink(target, linkpath)
hal_symlink:
    syscall_6 SYS_SYMLINK, rdi, rsi, 0, 0, 0, 0
    ret

; hal_readlink(path, buf, bufsz)
hal_readlink:
    syscall_6 SYS_READLINK, rdi, rsi, rdx, 0, 0, 0
    ret

; hal_chmod(path, mode)
hal_chmod:
    syscall_6 SYS_CHMOD, rdi, rsi, 0, 0, 0, 0
    ret

; hal_chown(path, uid, gid)
hal_chown:
    syscall_6 SYS_CHOWN, rdi, rsi, rdx, 0, 0, 0
    ret

; hal_utimensat(dirfd, path, timespec2_ptr, flags)
; flags passed in rcx (arg4)
hal_utimensat:
    mov r10, rcx
    syscall_6 SYS_UTIMENSAT, rdi, rsi, rdx, r10, 0, 0
    ret

; hal_statfs(path, statfs_buf)
hal_statfs:
    syscall_6 SYS_STATFS, rdi, rsi, 0, 0, 0, 0
    ret
