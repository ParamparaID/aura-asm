; defs.inc - Windows x86_64 HAL constants for Aura Shell

; std handles
%define INVALID_HANDLE_VALUE      -1
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
%define FILE_ATTRIBUTE_NORMAL     0x80

; memory
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

%define PROT_READ                 1
%define PROT_WRITE                2
%define PROT_EXEC                 4
%define MAP_ANONYMOUS             32

; winsock
%define AF_INET                   2
%define SOCK_STREAM               1
%define WSADATA_SIZE              408

; time
%define CLOCK_REALTIME            0
%define CLOCK_MONOTONIC           1
%define NSECS_PER_SEC             1000000000

; minimal structure offsets
%define TIMESPEC_SEC_OFF          0
%define TIMESPEC_NSEC_OFF         8

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

; Windows x64 ABI reminder:
; rcx, rdx, r8, r9 are arg1..arg4, caller allocates 32-byte shadow space.
