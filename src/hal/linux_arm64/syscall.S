// syscall.S - Linux ARM64 HAL wrappers (AAPCS64 + svc #0)
.include "src/hal/linux_arm64/defs.S"

.section .bss
.global global_envp
global_envp:
    .quad 0

.section .text

.macro SYSCALL nr
    mov x8, #\nr
    svc #0
.endm

.global hal_write
hal_write:
    // x0=fd, x1=buf, x2=len
    SYSCALL SYS_WRITE
    ret

.global hal_read
hal_read:
    // x0=fd, x1=buf, x2=len
    SYSCALL SYS_READ
    ret

.global hal_open
hal_open:
    // hal_open(path, flags, mode) -> openat(AT_FDCWD, path, flags, mode)
    mov x3, x2
    mov x2, x1
    mov x1, x0
    mov x0, #AT_FDCWD
    SYSCALL SYS_OPENAT
    ret

.global hal_openat
hal_openat:
    // x0=dirfd, x1=path, x2=flags, x3=mode
    SYSCALL SYS_OPENAT
    ret

.global hal_close
hal_close:
    SYSCALL SYS_CLOSE
    ret

.global hal_mmap
hal_mmap:
    // x0=addr, x1=len, x2=prot, x3=flags, x4=fd, x5=off
    SYSCALL SYS_MMAP
    ret

.global hal_mprotect
hal_mprotect:
    // x0=addr, x1=len, x2=prot
    SYSCALL SYS_MPROTECT
    ret

.global hal_munmap
hal_munmap:
    // x0=addr, x1=len
    SYSCALL SYS_MUNMAP
    ret

.global hal_exit
hal_exit:
    // x0=exit_code
    SYSCALL SYS_EXIT_GROUP
1:
    b 1b

.global hal_clock_gettime
hal_clock_gettime:
    // x0=clock_id, x1=timespec*
    SYSCALL SYS_CLOCK_GETTIME
    ret

.global hal_socket
hal_socket:
    // x0=domain, x1=type, x2=proto
    SYSCALL SYS_SOCKET
    ret

.global hal_connect
hal_connect:
    // x0=fd, x1=addr, x2=len
    SYSCALL SYS_CONNECT
    ret

.global hal_bind
hal_bind:
    // x0=fd, x1=addr, x2=len
    SYSCALL SYS_BIND
    ret

.global hal_listen
hal_listen:
    // x0=fd, x1=backlog
    SYSCALL SYS_LISTEN
    ret

.global hal_accept4
hal_accept4:
    // x0=fd, x1=addr, x2=addrlen, x3=flags
    SYSCALL SYS_ACCEPT4
    ret

.global hal_recvmsg
hal_recvmsg:
    // x0=fd, x1=msghdr*, x2=flags
    SYSCALL SYS_RECVMSG
    ret

.global hal_unlink
hal_unlink:
    // unlinkat(AT_FDCWD, path, 0)
    mov x1, x0
    mov x0, #AT_FDCWD
    mov x2, #0
    SYSCALL SYS_UNLINKAT
    ret

.global hal_ftruncate
hal_ftruncate:
    // x0=fd, x1=len
    SYSCALL SYS_FTRUNCATE
    ret

.global hal_memfd_create
hal_memfd_create:
    // x0=name, x1=flags
    SYSCALL SYS_MEMFD_CREATE
    ret

.global hal_lseek
hal_lseek:
    // x0=fd, x1=offset, x2=whence
    SYSCALL SYS_LSEEK
    ret

.global hal_access
hal_access:
    // faccessat(AT_FDCWD, path, mode, 0)
    mov x2, x1
    mov x1, x0
    mov x0, #AT_FDCWD
    mov x3, #0
    SYSCALL SYS_FACCESSAT
    ret

.global hal_fork
hal_fork:
    // clone(SIGCHLD, 0, 0, 0, 0)
    mov x0, #SIGCHLD
    mov x1, #0
    mov x2, #0
    mov x3, #0
    mov x4, #0
    SYSCALL SYS_CLONE
    ret

.global hal_execve
hal_execve:
    // x0=path, x1=argv, x2=envp
    SYSCALL SYS_EXECVE
    ret

.global hal_waitpid
hal_waitpid:
    // x0=pid, x1=status_ptr, x2=options
    mov x3, #0
    SYSCALL SYS_WAIT4
    ret

.global hal_dup2
hal_dup2:
    // dup3(oldfd, newfd, 0)
    mov x2, #0
    SYSCALL SYS_DUP3
    ret

.global hal_pipe
hal_pipe:
    // x0=int pipefd[2]
    mov x1, #0
    SYSCALL SYS_PIPE2
    ret

.global hal_getcwd
hal_getcwd:
    // x0=buf, x1=size
    mov x8, #17          // getcwd on arm64
    svc #0
    ret

.global hal_chdir
hal_chdir:
    // x0=path
    mov x8, #49          // chdir
    svc #0
    ret

.global hal_getenv_raw
hal_getenv_raw:
    adrp x0, global_envp
    add x0, x0, :lo12:global_envp
    ldr x0, [x0]
    ret
