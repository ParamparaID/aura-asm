; defs.inc - Windows x86_64 HAL constants for Aura Shell

; Linux-style fds for hal_read/hal_write shims
%define STDIN                     0
%define STDOUT                    1
%define STDERR                    2

; std handles
%define INVALID_HANDLE_VALUE      -1
%define HANDLE_FLAG_INHERIT       0x00000001
%define STD_INPUT_HANDLE          -10
%define STD_OUTPUT_HANDLE         -11
%define STD_ERROR_HANDLE          -12

; generic access / create disposition
%define GENERIC_READ              0x80000000
%define GENERIC_WRITE             0x40000000
%define FILE_SHARE_READ           0x00000001
%define FILE_SHARE_WRITE          0x00000002
%define OPEN_EXISTING             3
%define CREATE_ALWAYS             2
%define OPEN_ALWAYS               4
%define FILE_ATTRIBUTE_NORMAL     0x80
%define FILE_FLAG_BACKUP_SEMANTICS 0x02000000
%define FILE_ATTRIBUTE_DIRECTORY  0x10
%define FILE_SHARE_DELETE         0x00000004

; memory
%define PAGE_READONLY             0x02
%define PAGE_READWRITE            0x04
%define PAGE_EXECUTE_READ         0x20
%define PAGE_EXECUTE_READWRITE    0x40
%define MEM_COMMIT                0x1000
%define MEM_RESERVE               0x2000
%define MEM_RELEASE               0x8000

; wait
%define INFINITE                  0xFFFFFFFF
%define WAIT_OBJECT_0             0

; linux-style flags used by HAL callers
%define O_RDONLY                  0
%define O_WRONLY                  1
%define O_RDWR                    2
%define O_CREAT                   64
%define O_TRUNC                   512
%define O_APPEND                  1024
%define O_DIRECTORY               65536

%define PROT_READ                 1
%define PROT_WRITE                2
%define PROT_EXEC                 4

; hal_access mode bits (Linux values; Win HAL may ignore)
%define F_OK                      0
%define X_OK                      1

; st_mode file type masks (Linux layout used by stat shims)
%define S_IFMT                    0xF000
%define S_IFDIR                   0x4000

; dirent.d_type (Linux values)
%define DT_DIR                    4
%define DT_REG                    8
%define DT_LNK                    10
%define MAP_PRIVATE               0x02
%define MAP_ANONYMOUS             32

; winsock
%define AF_INET                   2
%define SOCK_STREAM               1
%define WSADATA_SIZE              408
%define SOCKADDR_IN_SIZE          16
%define SIN_FAMILY_OFF            0
%define SIN_PORT_OFF              2
%define SIN_ADDR_OFF              4
%define SIN_ZERO_OFF              8

; time
%define CLOCK_REALTIME            0
%define CLOCK_MONOTONIC           1
%define NSECS_PER_SEC             1000000000

; sigaction shape (repl.asm); Win HAL sigaction is a no-op
%define SIG_DFL                   0
%define SIG_IGN                   1
%define SIGCHLD                   17
%define SIGCONT                   18
%define SIGTSTP                   20
%define SIGTTIN                   21
%define SIGTTOU                   22
%define SA_NOCLDSTOP              0x00000001
%define SA_RESTART                0x10000000
%define SA_RESTORER               0x04000000
%define WNOHANG                   1
%define WUNTRACED                 2
%define WCONTINUED                8

; minimal structure offsets
%define TIMESPEC_SEC_OFF          0
%define TIMESPEC_NSEC_OFF         8

; Win32 RTL_CRITICAL_SECTION (x64)
%define CRITICAL_SECTION_SIZE     40

; STARTUPINFOA / PROCESS_INFORMATION (x64)
%define STARTUPINFOA_SIZE         104
%define STARTUPINFOA_DWFLAGS_OFF  60
%define STARTUPINFOA_HSTDIN_OFF   80
%define STARTUPINFOA_HSTDOUT_OFF  88
%define STARTUPINFOA_HSTDERR_OFF  96
%define STARTF_USESTDHANDLES      0x00000100

%define PROCESS_INFORMATION_SIZE  24
%define PROCINFO_HPROCESS_OFF     0
%define PROCINFO_HTHREAD_OFF      8

; windowing / user32 / gdi
%define CS_HREDRAW                0x0002
%define CS_VREDRAW                0x0001
%define WS_OVERLAPPEDWINDOW       0x00CF0000
%define WS_VISIBLE                0x10000000
%define WS_POPUP                  0x80000000
%define WS_EX_TOOLWINDOW          0x00000080
%define CW_USEDEFAULT             0x80000000
%define SW_SHOW                   5
%define PM_REMOVE                 0x0001
%define WM_NULL                   0x0000
%define WM_CREATE                 0x0001
%define WM_DESTROY                0x0002
%define WM_SIZE                   0x0005
%define WM_PAINT                  0x000F
%define WM_CLOSE                  0x0010
%define WM_QUIT                   0x0012
%define WM_KEYDOWN                0x0100
%define WM_KEYUP                  0x0101
%define WM_CHAR                   0x0102
%define WM_MOUSEMOVE              0x0200
%define WM_LBUTTONDOWN            0x0201
%define WM_LBUTTONUP              0x0202
%define WM_RBUTTONDOWN            0x0204
%define WM_RBUTTONUP              0x0205
%define WM_MOUSEWHEEL             0x020A
%define WM_TOUCH                  0x0240
%define WM_POINTERDOWN            0x0246
%define WM_POINTERUP              0x0247
%define WM_POINTERUPDATE          0x0245
%define IDC_ARROW                 32512
%define DIB_RGB_COLORS            0
%define BI_RGB                    0
%define SRCCOPY                   0x00CC0020
%define SM_CXSCREEN               0
%define SM_CYSCREEN               1
%define MOD_WIN                   0x0008
%define VK_RETURN                 0x0D
%define GWLP_WNDPROC              -4

; Win32 structure sizes used in asm
%define WNDCLASSEXA_SIZE          80
%define MSG_SIZE                  48
%define BITMAPINFOHEADER_SIZE     40

; Windows x64 ABI reminder:
; rcx, rdx, r8, r9 are arg1..arg4, caller allocates 32-byte shadow space.
