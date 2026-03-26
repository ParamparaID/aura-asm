; bootstrap.asm - Windows function resolver without libc
%include "src/hal/win_x86_64/defs.inc"

section .data
    ; modules
    win_mod_kernel32                 dq 0
    win_mod_user32                   dq 0
    win_mod_ws2_32                   dq 0
    win_mod_gdi32                    dq 0

    ; resolved function table
    win32_GetProcAddress             dq 0
    win32_LoadLibraryA               dq 0
    win32_CreateFileA                dq 0
    win32_ReadFile                   dq 0
    win32_WriteFile                  dq 0
    win32_CloseHandle                dq 0
    win32_VirtualAlloc               dq 0
    win32_VirtualFree                dq 0
    win32_VirtualProtect             dq 0
    win32_ExitProcess                dq 0
    win32_GetStdHandle               dq 0
    win32_QueryPerformanceCounter    dq 0
    win32_QueryPerformanceFrequency  dq 0
    win32_CreateThread               dq 0
    win32_WaitForSingleObject        dq 0
    win32_CreatePipe                 dq 0
    win32_CreateProcessA             dq 0
    win32_GetExitCodeProcess         dq 0
    win32_GetEnvironmentVariableA    dq 0
    win32_GetModuleHandleA           dq 0
    win32_SetStdHandle               dq 0
    win32_AcquireSRWLockExclusive    dq 0
    win32_ReleaseSRWLockExclusive    dq 0
    win32_InterlockedIncrement64     dq 0

    ; winsock
    win32_WSAStartup                 dq 0
    win32_WSAPoll                    dq 0
    win32_socket                     dq 0
    win32_connect                    dq 0
    win32_bind                       dq 0
    win32_listen                     dq 0
    win32_accept                     dq 0
    win32_closesocket                dq 0

    bootstrap_ready                  dd 0
    bootstrap_pad                    dd 0

    ; module names
    mod_user32                       db "user32.dll",0
    mod_ws2_32                       db "ws2_32.dll",0
    mod_gdi32                        db "gdi32.dll",0

    ; exported function names
    s_GetProcAddress                 db "GetProcAddress",0
    s_LoadLibraryA                   db "LoadLibraryA",0
    s_CreateFileA                    db "CreateFileA",0
    s_ReadFile                       db "ReadFile",0
    s_WriteFile                      db "WriteFile",0
    s_CloseHandle                    db "CloseHandle",0
    s_VirtualAlloc                   db "VirtualAlloc",0
    s_VirtualFree                    db "VirtualFree",0
    s_VirtualProtect                 db "VirtualProtect",0
    s_ExitProcess                    db "ExitProcess",0
    s_GetStdHandle                   db "GetStdHandle",0
    s_QueryPerformanceCounter        db "QueryPerformanceCounter",0
    s_QueryPerformanceFrequency      db "QueryPerformanceFrequency",0
    s_CreateThread                   db "CreateThread",0
    s_WaitForSingleObject            db "WaitForSingleObject",0
    s_CreatePipe                     db "CreatePipe",0
    s_CreateProcessA                 db "CreateProcessA",0
    s_GetExitCodeProcess             db "GetExitCodeProcess",0
    s_GetEnvironmentVariableA        db "GetEnvironmentVariableA",0
    s_GetModuleHandleA               db "GetModuleHandleA",0
    s_SetStdHandle                   db "SetStdHandle",0
    s_AcquireSRWLockExclusive        db "AcquireSRWLockExclusive",0
    s_ReleaseSRWLockExclusive        db "ReleaseSRWLockExclusive",0
    s_InterlockedIncrement64         db "InterlockedIncrement64",0

    ; winsock names
    s_WSAStartup                     db "WSAStartup",0
    s_WSAPoll                        db "WSAPoll",0
    s_socket                         db "socket",0
    s_connect                        db "connect",0
    s_bind                           db "bind",0
    s_listen                         db "listen",0
    s_accept                         db "accept",0
    s_closesocket                    db "closesocket",0

section .bss
    wsadata_buf                      resb WSADATA_SIZE

section .text
global bootstrap_init
global boot_find_export_hash
global boot_hash_name

global win_mod_kernel32
global win_mod_user32
global win_mod_ws2_32
global win_mod_gdi32

global win32_GetProcAddress
global win32_LoadLibraryA
global win32_CreateFileA
global win32_ReadFile
global win32_WriteFile
global win32_CloseHandle
global win32_VirtualAlloc
global win32_VirtualFree
global win32_VirtualProtect
global win32_ExitProcess
global win32_GetStdHandle
global win32_QueryPerformanceCounter
global win32_QueryPerformanceFrequency
global win32_CreateThread
global win32_WaitForSingleObject
global win32_CreatePipe
global win32_CreateProcessA
global win32_GetExitCodeProcess
global win32_GetEnvironmentVariableA
global win32_GetModuleHandleA
global win32_SetStdHandle
global win32_AcquireSRWLockExclusive
global win32_ReleaseSRWLockExclusive
global win32_InterlockedIncrement64

global win32_WSAStartup
global win32_WSAPoll
global win32_socket
global win32_connect
global win32_bind
global win32_listen
global win32_accept
global win32_closesocket

%define HASH_GetProcAddress         0xCF31BB1F

boot_hash_name:
    ; rdi = zero-terminated ascii, returns eax hash (djb2, case-insensitive)
    mov eax, 5381
.h_loop:
    movzx edx, byte [rdi]
    test edx, edx
    jz .out
    ; upper->lower
    cmp dl, 'A'
    jb .mix
    cmp dl, 'Z'
    ja .mix
    add dl, 32
.mix:
    lea eax, [rax + rax*4]          ; hash * 5
    lea eax, [rdx + rax*8]          ; hash * 33 + c
    inc rdi
    jmp .h_loop
.out:
    ret

boot_find_kernel32:
    ; returns rax = kernel32 base or 0
    mov rax, [gs:0x60]              ; PEB*
    test rax, rax
    jz .fail
    mov rax, [rax + 0x18]           ; PEB_LDR_DATA*
    test rax, rax
    jz .fail
    mov rax, [rax + 0x20]           ; InMemoryOrderModuleList.Flink (1st)
    test rax, rax
    jz .fail
    mov rax, [rax]                  ; 2nd
    test rax, rax
    jz .fail
    mov rax, [rax]                  ; 3rd
    test rax, rax
    jz .fail
    sub rax, 0x10                   ; LIST_ENTRY -> LDR_DATA_TABLE_ENTRY base
    mov rax, [rax + 0x20]           ; DllBase (per project spec)
    ret
.fail:
    xor eax, eax
    ret

boot_find_export_hash:
    ; (dll_base rdi, hash esi) -> rax function address or 0
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi                    ; dll base
    mov r13d, esi                   ; hash target

    test r12, r12
    jz .fail
    mov eax, [r12 + 0x3C]           ; e_lfanew
    lea r14, [r12 + rax]            ; nt headers
    mov eax, [r14 + 0x88]           ; export directory RVA (PE32+)
    test eax, eax
    jz .fail
    lea r15, [r12 + rax]            ; IMAGE_EXPORT_DIRECTORY*

    mov ebx, [r15 + 0x18]           ; NumberOfNames
    test ebx, ebx
    jz .fail

    mov eax, [r15 + 0x20]           ; AddressOfNames RVA
    lea r8, [r12 + rax]
    mov eax, [r15 + 0x24]           ; AddressOfNameOrdinals RVA
    lea r9, [r12 + rax]
    mov eax, [r15 + 0x1C]           ; AddressOfFunctions RVA
    lea r10, [r12 + rax]

    xor ecx, ecx
.loop:
    cmp ecx, ebx
    jae .fail
    mov eax, [r8 + rcx*4]           ; name RVA
    lea rdi, [r12 + rax]
    call boot_hash_name
    cmp eax, r13d
    jne .next

    movzx eax, word [r9 + rcx*2]    ; ordinal
    mov eax, [r10 + rax*4]          ; function RVA
    lea rax, [r12 + rax]
    jmp .out
.next:
    inc ecx
    jmp .loop

.fail:
    xor eax, eax
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

boot_getproc:
    ; (module_base rdi, name_ptr rsi) -> rax or 0
    push rbx
    mov rbx, [rel win32_GetProcAddress]
    test rbx, rbx
    jz .fail
    mov rcx, rdi
    mov rdx, rsi
    sub rsp, 40
    call rbx
    add rsp, 40
    pop rbx
    ret
.fail:
    xor eax, eax
    pop rbx
    ret

boot_loadlibrary:
    ; (name_ptr rdi) -> rax module base or 0
    push rbx
    mov rbx, [rel win32_LoadLibraryA]
    test rbx, rbx
    jz .fail
    mov rcx, rdi
    sub rsp, 40
    call rbx
    add rsp, 40
    pop rbx
    ret
.fail:
    xor eax, eax
    pop rbx
    ret

bootstrap_init:
    ; returns eax = 1 success, 0 fail
    cmp dword [rel bootstrap_ready], 1
    je .ok

    call boot_find_kernel32
    test rax, rax
    jz .fail
    mov [rel win_mod_kernel32], rax

    mov rdi, rax
    mov esi, HASH_GetProcAddress
    call boot_find_export_hash
    test rax, rax
    jz .fail
    mov [rel win32_GetProcAddress], rax

    ; LoadLibraryA from kernel32
    mov rdi, [rel win_mod_kernel32]
    lea rsi, [rel s_LoadLibraryA]
    call boot_getproc
    test rax, rax
    jz .fail
    mov [rel win32_LoadLibraryA], rax

    ; load user32/ws2_32/gdi32
    lea rdi, [rel mod_user32]
    call boot_loadlibrary
    mov [rel win_mod_user32], rax
    lea rdi, [rel mod_ws2_32]
    call boot_loadlibrary
    mov [rel win_mod_ws2_32], rax
    lea rdi, [rel mod_gdi32]
    call boot_loadlibrary
    mov [rel win_mod_gdi32], rax

    ; kernel32 exports
    mov rdi, [rel win_mod_kernel32]
    lea rsi, [rel s_CreateFileA]
    call boot_getproc
    mov [rel win32_CreateFileA], rax
    mov rdi, [rel win_mod_kernel32]
    lea rsi, [rel s_ReadFile]
    call boot_getproc
    mov [rel win32_ReadFile], rax
    mov rdi, [rel win_mod_kernel32]
    lea rsi, [rel s_WriteFile]
    call boot_getproc
    mov [rel win32_WriteFile], rax
    mov rdi, [rel win_mod_kernel32]
    lea rsi, [rel s_CloseHandle]
    call boot_getproc
    mov [rel win32_CloseHandle], rax
    mov rdi, [rel win_mod_kernel32]
    lea rsi, [rel s_VirtualAlloc]
    call boot_getproc
    mov [rel win32_VirtualAlloc], rax
    mov rdi, [rel win_mod_kernel32]
    lea rsi, [rel s_VirtualFree]
    call boot_getproc
    mov [rel win32_VirtualFree], rax
    mov rdi, [rel win_mod_kernel32]
    lea rsi, [rel s_VirtualProtect]
    call boot_getproc
    mov [rel win32_VirtualProtect], rax
    mov rdi, [rel win_mod_kernel32]
    lea rsi, [rel s_ExitProcess]
    call boot_getproc
    mov [rel win32_ExitProcess], rax
    mov rdi, [rel win_mod_kernel32]
    lea rsi, [rel s_GetStdHandle]
    call boot_getproc
    mov [rel win32_GetStdHandle], rax
    mov rdi, [rel win_mod_kernel32]
    lea rsi, [rel s_QueryPerformanceCounter]
    call boot_getproc
    mov [rel win32_QueryPerformanceCounter], rax
    mov rdi, [rel win_mod_kernel32]
    lea rsi, [rel s_QueryPerformanceFrequency]
    call boot_getproc
    mov [rel win32_QueryPerformanceFrequency], rax
    mov rdi, [rel win_mod_kernel32]
    lea rsi, [rel s_CreateThread]
    call boot_getproc
    mov [rel win32_CreateThread], rax
    mov rdi, [rel win_mod_kernel32]
    lea rsi, [rel s_WaitForSingleObject]
    call boot_getproc
    mov [rel win32_WaitForSingleObject], rax
    mov rdi, [rel win_mod_kernel32]
    lea rsi, [rel s_CreatePipe]
    call boot_getproc
    mov [rel win32_CreatePipe], rax
    mov rdi, [rel win_mod_kernel32]
    lea rsi, [rel s_CreateProcessA]
    call boot_getproc
    mov [rel win32_CreateProcessA], rax
    mov rdi, [rel win_mod_kernel32]
    lea rsi, [rel s_GetExitCodeProcess]
    call boot_getproc
    mov [rel win32_GetExitCodeProcess], rax
    mov rdi, [rel win_mod_kernel32]
    lea rsi, [rel s_GetEnvironmentVariableA]
    call boot_getproc
    mov [rel win32_GetEnvironmentVariableA], rax
    mov rdi, [rel win_mod_kernel32]
    lea rsi, [rel s_GetModuleHandleA]
    call boot_getproc
    mov [rel win32_GetModuleHandleA], rax
    mov rdi, [rel win_mod_kernel32]
    lea rsi, [rel s_SetStdHandle]
    call boot_getproc
    mov [rel win32_SetStdHandle], rax
    mov rdi, [rel win_mod_kernel32]
    lea rsi, [rel s_AcquireSRWLockExclusive]
    call boot_getproc
    mov [rel win32_AcquireSRWLockExclusive], rax
    mov rdi, [rel win_mod_kernel32]
    lea rsi, [rel s_ReleaseSRWLockExclusive]
    call boot_getproc
    mov [rel win32_ReleaseSRWLockExclusive], rax
    mov rdi, [rel win_mod_kernel32]
    lea rsi, [rel s_InterlockedIncrement64]
    call boot_getproc
    mov [rel win32_InterlockedIncrement64], rax

    ; ws2_32 exports (optional but initialized for networking wrappers)
    mov rdi, [rel win_mod_ws2_32]
    test rdi, rdi
    jz .finish
    lea rsi, [rel s_WSAStartup]
    call boot_getproc
    mov [rel win32_WSAStartup], rax
    mov rdi, [rel win_mod_ws2_32]
    lea rsi, [rel s_WSAPoll]
    call boot_getproc
    mov [rel win32_WSAPoll], rax
    mov rdi, [rel win_mod_ws2_32]
    lea rsi, [rel s_socket]
    call boot_getproc
    mov [rel win32_socket], rax
    mov rdi, [rel win_mod_ws2_32]
    lea rsi, [rel s_connect]
    call boot_getproc
    mov [rel win32_connect], rax
    mov rdi, [rel win_mod_ws2_32]
    lea rsi, [rel s_bind]
    call boot_getproc
    mov [rel win32_bind], rax
    mov rdi, [rel win_mod_ws2_32]
    lea rsi, [rel s_listen]
    call boot_getproc
    mov [rel win32_listen], rax
    mov rdi, [rel win_mod_ws2_32]
    lea rsi, [rel s_accept]
    call boot_getproc
    mov [rel win32_accept], rax
    mov rdi, [rel win_mod_ws2_32]
    lea rsi, [rel s_closesocket]
    call boot_getproc
    mov [rel win32_closesocket], rax

    ; WSAStartup(2.2, &wsadata_buf)
    mov rax, [rel win32_WSAStartup]
    test rax, rax
    jz .finish
    mov ecx, 0x0202
    lea rdx, [rel wsadata_buf]
    sub rsp, 40
    call rax
    add rsp, 40

.finish:
    ; minimum required for HAL write/read path
    cmp qword [rel win32_GetStdHandle], 0
    je .fail
    cmp qword [rel win32_WriteFile], 0
    je .fail
    cmp qword [rel win32_ReadFile], 0
    je .fail
    cmp qword [rel win32_CloseHandle], 0
    je .fail

    mov dword [rel bootstrap_ready], 1
.ok:
    mov eax, 1
    ret
.fail:
    xor eax, eax
    ret
