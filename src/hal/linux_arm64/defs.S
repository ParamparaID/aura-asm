// defs.S - Linux ARM64 syscall/constants for Aura HAL

// ARM64 syscall numbers
.equ SYS_IO_SETUP,         0
.equ SYS_IO_DESTROY,       1
.equ SYS_READ,             63
.equ SYS_WRITE,            64
.equ SYS_OPENAT,           56
.equ SYS_CLOSE,            57
.equ SYS_LSEEK,            62
.equ SYS_MMAP,             222
.equ SYS_MPROTECT,         226
.equ SYS_MUNMAP,           215
.equ SYS_EXIT,             93
.equ SYS_EXIT_GROUP,       94
.equ SYS_CLOCK_GETTIME,    113
.equ SYS_CLONE,            220
.equ SYS_EXECVE,           221
.equ SYS_WAIT4,            260
.equ SYS_DUP3,             24
.equ SYS_PIPE2,            59
.equ SYS_GETCWD,           17
.equ SYS_CHDIR,            49
.equ SYS_SOCKET,           198
.equ SYS_CONNECT,          203
.equ SYS_BIND,             200
.equ SYS_LISTEN,           201
.equ SYS_ACCEPT4,          242
.equ SYS_SENDMSG,          211
.equ SYS_RECVMSG,          212
.equ SYS_UNLINKAT,         35
.equ SYS_FTRUNCATE,        46
.equ SYS_MEMFD_CREATE,     279
.equ SYS_FACCESSAT,        48
.equ SYS_GETDENTS64,       61
.equ SYS_NEWFSTATAT,       79
.equ SYS_RENAMEAT2,        276
.equ SYS_MKDIRAT,          34
.equ SYS_EPOLL_CREATE1,    20
.equ SYS_EPOLL_CTL,        21
.equ SYS_EPOLL_PWAIT,      22
.equ SYS_TIMERFD_CREATE,   85
.equ SYS_TIMERFD_SETTIME,  86

// constants
.equ AT_FDCWD,             -100
.equ AT_REMOVEDIR,         0x200
.equ AT_SYMLINK_NOFOLLOW,  0x100

.equ O_RDONLY,             0
.equ O_WRONLY,             1
.equ O_RDWR,               2
.equ O_CREAT,              64
.equ O_TRUNC,              512
.equ O_APPEND,             1024
.equ O_NONBLOCK,           2048
.equ O_CLOEXEC,            524288
.equ O_DIRECTORY,          65536

.equ PROT_READ,            1
.equ PROT_WRITE,           2
.equ PROT_EXEC,            4
.equ MAP_SHARED,           1
.equ MAP_PRIVATE,          2
.equ MAP_ANONYMOUS,        32

.equ AF_UNIX,              1
.equ AF_INET,              2
.equ SOCK_STREAM,          1

.equ CLOCK_REALTIME,       0
.equ CLOCK_MONOTONIC,      1

.equ SIGCHLD,              17
.equ WNOHANG,              1
.equ WUNTRACED,            2
.equ WCONTINUED,           8

.equ STDIN,                0
.equ STDOUT,               1
.equ STDERR,               2
