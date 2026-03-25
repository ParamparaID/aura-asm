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
%define sys_mprotect         10
%define sys_munmap           11
%define sys_rt_sigaction     13
%define sys_ioctl            16
%define sys_clone            56
%define sys_execve           59
%define sys_exit             60
%define sys_kill             62
%define sys_wait4            61
%define sys_getpid           39
%define sys_ftruncate        77
%define sys_getcwd           79
%define sys_chdir            80
%define sys_setpgid          109
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
%define sys_bind             49
%define sys_listen           50
%define sys_accept4          288
%define sys_unlink           87
%define sys_lseek            8
%define sys_openat           257
%define sys_getdents64       217
%define sys_newfstatat       262
%define sys_rename           82
%define sys_renameat2        316
%define sys_unlinkat         263
%define sys_rmdir            84
%define sys_mkdir            83
%define sys_symlink          88
%define sys_readlink         89
%define sys_chmod            90
%define sys_chown            92
%define sys_utimensat        280
%define sys_fchmodat         268
%define sys_fchownat         260
%define sys_symlinkat        266
%define sys_readlinkat       267
%define sys_statfs           137

; Uppercase aliases for readability in code.
%define SYS_READ             sys_read
%define SYS_WRITE            sys_write
%define SYS_OPEN             sys_open
%define SYS_CLOSE            sys_close
%define SYS_ACCESS           sys_access
%define SYS_DUP2             sys_dup2
%define SYS_MMAP             sys_mmap
%define SYS_MPROTECT         sys_mprotect
%define SYS_MUNMAP           sys_munmap
%define SYS_RT_SIGACTION     sys_rt_sigaction
%define SYS_IOCTL            sys_ioctl
%define SYS_CLONE            sys_clone
%define SYS_EXECVE           sys_execve
%define SYS_EXIT             sys_exit
%define SYS_WAIT4            sys_wait4
%define SYS_KILL             sys_kill
%define SYS_GETPID           sys_getpid
%define SYS_FTRUNCATE        sys_ftruncate
%define SYS_GETCWD           sys_getcwd
%define SYS_CHDIR            sys_chdir
%define SYS_SETPGID          sys_setpgid
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
%define SYS_BIND             sys_bind
%define SYS_LISTEN           sys_listen
%define SYS_ACCEPT4          sys_accept4
%define SYS_UNLINK           sys_unlink
%define SYS_LSEEK            sys_lseek
%define SYS_OPENAT           sys_openat
%define SYS_GETDENTS64       sys_getdents64
%define SYS_NEWFSTATAT       sys_newfstatat
%define SYS_RENAME           sys_rename
%define SYS_RENAMEAT2        sys_renameat2
%define SYS_UNLINKAT         sys_unlinkat
%define SYS_RMDIR            sys_rmdir
%define SYS_MKDIR            sys_mkdir
%define SYS_SYMLINK          sys_symlink
%define SYS_READLINK         sys_readlink
%define SYS_CHMOD            sys_chmod
%define SYS_CHOWN            sys_chown
%define SYS_UTIMENSAT        sys_utimensat
%define SYS_FCHMODAT         sys_fchmodat
%define SYS_FCHOWNAT         sys_fchownat
%define SYS_SYMLINKAT        sys_symlinkat
%define SYS_READLINKAT       sys_readlinkat
%define SYS_STATFS          sys_statfs

; --- socket ---
%define AF_UNIX              1
%define AF_INET              2
%define SOCK_STREAM          1
%define SOCK_NONBLOCK        0x800
%define SOCK_CLOEXEC         0x80000

; struct sockaddr_in (IPv4)
%define SOCKADDR_IN_SIZE     16
%define SIN_FAMILY_OFF       0
%define SIN_PORT_OFF         2
%define SIN_ADDR_OFF         4
%define SIN_ZERO_OFF         8

; --- open(2) flags ---
%define O_RDONLY             0
%define O_WRONLY             1
%define O_RDWR               2
%define O_CREAT              64
%define O_TRUNC              512
%define O_APPEND             1024
%define O_NONBLOCK           2048
%define O_CLOEXEC            524288
%define O_DIRECTORY          65536
%define AT_FDCWD             -100
%define AT_REMOVEDIR         0x200
%define AT_SYMLINK_NOFOLLOW  0x100

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
%define SIGINT               2
%define SIGQUIT              3
%define SIGTERM              15
%define SIGCONT              18
%define SIGTSTP              20
%define SIGTTIN              21
%define SIGTTOU              22
%define WNOHANG              1
%define WUNTRACED            2
%define WCONTINUED           8

; sigaction flags and handlers
%define SIG_DFL              0
%define SIG_IGN              1
%define SA_SIGINFO           0x00000004
%define SA_RESTORER          0x04000000
%define SA_RESTART           0x10000000
%define SA_NOCLDSTOP         0x00000001

; tty ioctls
%define TIOCGPGRP            0x540F
%define TIOCSPGRP            0x5410

; --- access(2) modes ---
%define F_OK                 0
%define X_OK                 1

; --- standard file descriptors ---
%define STDIN                0
%define STDOUT               1
%define STDERR               2

; --- dirent/stat types ---
%define DT_UNKNOWN           0
%define DT_FIFO              1
%define DT_CHR               2
%define DT_DIR               4
%define DT_BLK               6
%define DT_REG               8
%define DT_LNK               10
%define DT_SOCK              12

%define S_IFMT               0xF000
%define S_IFDIR              0x4000
%define S_IFREG              0x8000
%define S_IFLNK              0xA000

; --- socket cmsg / memfd ---
%define SOL_SOCKET           1
%define SCM_RIGHTS           1
%define MFD_CLOEXEC          1

; --- evdev / input.h (subset) ---
%define EV_SYN               0
%define EV_KEY               1
%define EV_REL               2
%define EV_ABS               3
%define SYN_REPORT           0
%define REL_X                0
%define REL_Y                1
%define REL_WHEEL            8
%define ABS_MT_POSITION_X    53
%define ABS_MT_POSITION_Y    54
%define KEY_A                30
%define KEY_Z                44
%define KEY_Q                16
%define KEY_ENTER            28
%define KEY_LEFTMETA         125
%define KEY_RIGHTMETA        126
%define BTN_LEFT             0x110
%define BTN_RIGHT            0x111
%define BTN_MIDDLE           0x112

; EVIOCGBIT(ev,len) — Linux input.h
%define EVIOCGBIT_EV_KEY_64  0x80404521   ; _IOC(_IOC_READ,'E',0x21,64)
%define EVIOCGBIT_0          0x80084520   ; EVIOCGBIT(0, sizeof(long))
%define EVIOCGNAME_256       0x80FF4506   ; EVIOCGNAME(256)

%endif
