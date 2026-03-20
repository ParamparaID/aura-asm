; defs.inc
; Linux x86_64 syscall and flag constants for Aura HAL
; Author: Aura Shell Team
; Date: 2026-03-19

%ifndef AURA_HAL_LINUX_X86_64_DEFS_INC
%define AURA_HAL_LINUX_X86_64_DEFS_INC

; --- Syscall numbers ---
%define sys_read             0
%define sys_write            1
%define sys_open             2
%define sys_close            3
%define sys_access           21
%define sys_dup2             33
%define sys_mmap             9
%define sys_munmap           11
%define sys_clone            56
%define sys_execve           59
%define sys_exit             60
%define sys_wait4            61
%define sys_ftruncate        77
%define sys_getcwd           79
%define sys_chdir            80
%define sys_futex            202
%define sys_clock_gettime    228
%define sys_epoll_wait       232
%define sys_epoll_ctl        233
%define sys_timerfd_create   283
%define sys_timerfd_settime  286
%define sys_epoll_create1    291
%define sys_pipe2            293
%define sys_memfd_create     319
%define sys_socket           41
%define sys_connect          42
%define sys_sendmsg          46
%define sys_recvmsg          47

; Uppercase aliases for readability in code.
%define SYS_READ             sys_read
%define SYS_WRITE            sys_write
%define SYS_OPEN             sys_open
%define SYS_CLOSE            sys_close
%define SYS_ACCESS           sys_access
%define SYS_DUP2             sys_dup2
%define SYS_MMAP             sys_mmap
%define SYS_MUNMAP           sys_munmap
%define SYS_CLONE            sys_clone
%define SYS_EXECVE           sys_execve
%define SYS_EXIT             sys_exit
%define SYS_WAIT4            sys_wait4
%define SYS_FTRUNCATE        sys_ftruncate
%define SYS_GETCWD           sys_getcwd
%define SYS_CHDIR            sys_chdir
%define SYS_FUTEX            sys_futex
%define SYS_CLOCK_GETTIME    sys_clock_gettime
%define SYS_EPOLL_WAIT       sys_epoll_wait
%define SYS_EPOLL_CTL        sys_epoll_ctl
%define SYS_TIMERFD_CREATE   sys_timerfd_create
%define SYS_TIMERFD_SETTIME  sys_timerfd_settime
%define SYS_EPOLL_CREATE1    sys_epoll_create1
%define SYS_PIPE2            sys_pipe2
%define SYS_MEMFD_CREATE     sys_memfd_create
%define SYS_SOCKET           sys_socket
%define SYS_CONNECT          sys_connect
%define SYS_SENDMSG          sys_sendmsg
%define SYS_RECVMSG          sys_recvmsg

; --- open(2) flags ---
%define O_RDONLY             0
%define O_WRONLY             1
%define O_RDWR               2
%define O_CREAT              64
%define O_TRUNC              512
%define O_APPEND             1024

; --- mmap(2) protection flags ---
%define PROT_READ            1
%define PROT_WRITE           2
%define PROT_EXEC            4

; --- mmap(2) mapping flags ---
%define MAP_SHARED           1
%define MAP_PRIVATE          2
%define MAP_ANONYMOUS        32

; --- epoll flags and operations ---
%define EPOLLIN              0x001
%define EPOLLOUT             0x004
%define EPOLLERR             0x008
%define EPOLLHUP             0x010
%define EPOLL_CTL_ADD        1
%define EPOLL_CTL_DEL        2
%define EPOLL_CTL_MOD        3

; --- clock ids ---
%define CLOCK_REALTIME       0
%define CLOCK_MONOTONIC      1

; --- clone(2) flags ---
%define CLONE_VM             0x00000100
%define CLONE_FS             0x00000200
%define CLONE_FILES          0x00000400
%define CLONE_SIGHAND        0x00000800
%define CLONE_SYSVSEM        0x00040000
%define CLONE_THREAD         0x00010000

; --- futex operations ---
%define FUTEX_WAIT           0
%define FUTEX_WAKE           1

; --- signal/wait flags ---
%define SIGCHLD              17
%define WNOHANG              1

; --- access(2) modes ---
%define F_OK                 0
%define X_OK                 1

; --- standard file descriptors ---
%define STDIN                0
%define STDOUT               1
%define STDERR               2

%endif
