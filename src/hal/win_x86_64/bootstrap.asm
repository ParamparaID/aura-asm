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
    win32_FindFirstFileA             dq 0
    win32_FindNextFileA              dq 0
    win32_FindClose                  dq 0
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
    win32_GetTickCount64             dq 0
    win32_Sleep                      dq 0

    ; winsock
    win32_WSAStartup                 dq 0
    win32_WSAPoll                    dq 0
    win32_socket                     dq 0
    win32_connect                    dq 0
    win32_bind                       dq 0
    win32_listen                     dq 0
    win32_accept                     dq 0
    win32_closesocket                dq 0

    ; user32 / gdi32
    win32_RegisterClassExA           dq 0
    win32_CreateWindowExA            dq 0
    win32_DefWindowProcA             dq 0
    win32_DestroyWindow              dq 0
    win32_ShowWindow                 dq 0
    win32_UpdateWindow               dq 0
    win32_PeekMessageA               dq 0
    win32_TranslateMessage           dq 0
    win32_DispatchMessageA           dq 0
    win32_PostQuitMessage            dq 0
    win32_LoadCursorA                dq 0
    win32_GetDC                      dq 0
    win32_ReleaseDC                  dq 0
    win32_GetSystemMetrics           dq 0
    win32_RegisterTouchWindow        dq 0
    win32_GetPointerInfo             dq 0
    win32_SendMessageA               dq 0
    win32_RegisterHotKey             dq 0
    win32_EnumWindows                dq 0
    win32_SetWindowPos               dq 0
    win32_SetWindowLongPtrA          dq 0

    win32_CreateCompatibleDC         dq 0
    win32_CreateDIBSection           dq 0
    win32_SelectObject               dq 0
    win32_BitBlt                     dq 0
    win32_DeleteObject               dq 0
    win32_DeleteDC                   dq 0
    win32_SetBkMode                  dq 0
    win32_SetTextColor               dq 0
    win32_TextOutA                   dq 0

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
    s_FindFirstFileA                 db "FindFirstFileA",0
    s_FindNextFileA                  db "FindNextFileA",0
    s_FindClose                      db "FindClose",0
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
    s_GetTickCount64                 db "GetTickCount64",0
    s_Sleep                          db "Sleep",0

    ; winsock names
    s_WSAStartup                     db "WSAStartup",0
    s_WSAPoll                        db "WSAPoll",0
    s_socket                         db "socket",0
    s_connect                        db "connect",0
    s_bind                           db "bind",0
    s_listen                         db "listen",0
    s_accept                         db "accept",0
    s_closesocket                    db "closesocket",0

    ; user32 / gdi32 names
    s_RegisterClassExA               db "RegisterClassExA",0
    s_CreateWindowExA                db "CreateWindowExA",0
    s_DefWindowProcA                 db "DefWindowProcA",0
    s_DestroyWindow                  db "DestroyWindow",0
    s_ShowWindow                     db "ShowWindow",0
    s_UpdateWindow                   db "UpdateWindow",0
    s_PeekMessageA                   db "PeekMessageA",0
    s_TranslateMessage               db "TranslateMessage",0
    s_DispatchMessageA               db "DispatchMessageA",0
    s_PostQuitMessage                db "PostQuitMessage",0
    s_LoadCursorA                    db "LoadCursorA",0
    s_GetDC                          db "GetDC",0
    s_ReleaseDC                      db "ReleaseDC",0
    s_GetSystemMetrics               db "GetSystemMetrics",0
    s_RegisterTouchWindow            db "RegisterTouchWindow",0
    s_GetPointerInfo                 db "GetPointerInfo",0
    s_SendMessageA                   db "SendMessageA",0
    s_RegisterHotKey                 db "RegisterHotKey",0
    s_EnumWindows                    db "EnumWindows",0
    s_SetWindowPos                   db "SetWindowPos",0
    s_SetWindowLongPtrA              db "SetWindowLongPtrA",0

    s_CreateCompatibleDC             db "CreateCompatibleDC",0
    s_CreateDIBSection               db "CreateDIBSection",0
    s_SelectObject                   db "SelectObject",0
    s_BitBlt                         db "BitBlt",0
    s_DeleteObject                   db "DeleteObject",0
    s_DeleteDC                       db "DeleteDC",0
    s_SetBkMode                      db "SetBkMode",0
    s_SetTextColor                   db "SetTextColor",0
    s_TextOutA                       db "TextOutA",0

section .bss
    wsadata_buf                      resb WSADATA_SIZE

section .text
global bootstrap_init
global boot_find_export_hash
global boot_find_export_name
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
global win32_FindFirstFileA
global win32_FindNextFileA
global win32_FindClose
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
global win32_GetTickCount64
global win32_Sleep

global win32_WSAStartup
global win32_WSAPoll
global win32_socket
global win32_connect
global win32_bind
global win32_listen
global win32_accept
global win32_closesocket

global win32_RegisterClassExA
global win32_CreateWindowExA
global win32_DefWindowProcA
global win32_DestroyWindow
global win32_ShowWindow
global win32_UpdateWindow
global win32_PeekMessageA
global win32_TranslateMessage
global win32_DispatchMessageA
global win32_PostQuitMessage
global win32_LoadCursorA
global win32_GetDC
global win32_ReleaseDC
global win32_GetSystemMetrics
global win32_RegisterTouchWindow
global win32_GetPointerInfo
global win32_SendMessageA
global win32_RegisterHotKey
global win32_EnumWindows
global win32_SetWindowPos
global win32_SetWindowLongPtrA

global win32_CreateCompatibleDC
global win32_CreateDIBSection
global win32_SelectObject
global win32_BitBlt
global win32_DeleteObject
global win32_DeleteDC
global win32_SetBkMode
global win32_SetTextColor
global win32_TextOutA

%define HASH_GetProcAddress         0x82172F7F

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
    imul eax, eax, 33               ; hash * 33
    add eax, edx                    ; + c
    inc rdi
    jmp .h_loop
.out:
    ret

boot_find_kernel32:
    ; returns rax = kernel32 base or 0
    ; Robust walk of PEB Ldr InMemoryOrder list by BaseDllName.
    mov rax, [gs:0x60]              ; PEB*
    test rax, rax
    jz .fail
    mov rax, [rax + 0x18]           ; PEB_LDR_DATA*
    test rax, rax
    jz .fail
    lea r11, [rax + 0x20]           ; LIST_ENTRY head
    mov r10, [r11]                  ; first entry
    test r10, r10
    jz .fail
.scan:
    cmp r10, r11
    je .fail
    mov r8, r10
    sub r8, 0x10                    ; InMemoryOrderLinks -> LDR_DATA_TABLE_ENTRY
    movzx ecx, word [r8 + 0x58]     ; BaseDllName.Length (bytes)
    cmp ecx, 24                     ; "kernel32.dll" UTF-16 length
    jne .next
    mov rdi, [r8 + 0x60]            ; BaseDllName.Buffer (PWSTR)
    test rdi, rdi
    jz .next
    ; k e r n e l 3 2 . d l l (case-insensitive for letters)
    movzx eax, word [rdi + 0]
    or al, 32
    cmp al, 'k'
    jne .next
    movzx eax, word [rdi + 2]
    or al, 32
    cmp al, 'e'
    jne .next
    movzx eax, word [rdi + 4]
    or al, 32
    cmp al, 'r'
    jne .next
    movzx eax, word [rdi + 6]
    or al, 32
    cmp al, 'n'
    jne .next
    movzx eax, word [rdi + 8]
    or al, 32
    cmp al, 'e'
    jne .next
    movzx eax, word [rdi + 10]
    or al, 32
    cmp al, 'l'
    jne .next
    movzx eax, word [rdi + 12]
    cmp al, '3'
    jne .next
    movzx eax, word [rdi + 14]
    cmp al, '2'
    jne .next
    movzx eax, word [rdi + 16]
    cmp al, '.'
    jne .next
    movzx eax, word [rdi + 18]
    or al, 32
    cmp al, 'd'
    jne .next
    movzx eax, word [rdi + 20]
    or al, 32
    cmp al, 'l'
    jne .next
    movzx eax, word [rdi + 22]
    or al, 32
    cmp al, 'l'
    jne .next

    mov rax, [r8 + 0x30]            ; DllBase
    ret
.next:
    mov r10, [r10]
    jmp .scan
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
    cmp word [r12], 0x5A4D          ; "MZ"
    jne .fail
    mov eax, [r12 + 0x3C]           ; e_lfanew
    lea r14, [r12 + rax]            ; nt headers
    cmp dword [r14], 0x00004550     ; "PE\0\0"
    jne .fail
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

boot_zstreq:
    ; (a rdi, b rsi) -> eax 1/0
.zs_loop:
    mov al, [rdi]
    mov dl, [rsi]
    cmp al, dl
    jne .zs_no
    test al, al
    jz .zs_yes
    inc rdi
    inc rsi
    jmp .zs_loop
.zs_yes:
    mov eax, 1
    ret
.zs_no:
    xor eax, eax
    ret

boot_find_export_name:
    ; (dll_base rdi, name_ptr rsi) -> rax function address or 0
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi                    ; dll base
    mov r13, rsi                    ; target name

    test r12, r12
    jz .fen_fail
    cmp word [r12], 0x5A4D          ; "MZ"
    jne .fen_fail
    mov eax, [r12 + 0x3C]           ; e_lfanew
    lea r14, [r12 + rax]            ; nt headers
    cmp dword [r14], 0x00004550     ; "PE\0\0"
    jne .fen_fail
    mov eax, [r14 + 0x88]           ; export directory RVA (PE32+)
    test eax, eax
    jz .fen_fail
    lea r15, [r12 + rax]            ; IMAGE_EXPORT_DIRECTORY*

    mov ebx, [r15 + 0x18]           ; NumberOfNames
    test ebx, ebx
    jz .fen_fail

    mov eax, [r15 + 0x20]           ; AddressOfNames RVA
    lea r8, [r12 + rax]
    mov eax, [r15 + 0x24]           ; AddressOfNameOrdinals RVA
    lea r9, [r12 + rax]
    mov eax, [r15 + 0x1C]           ; AddressOfFunctions RVA
    lea r10, [r12 + rax]

    xor ecx, ecx
.fen_loop:
    cmp ecx, ebx
    jae .fen_fail
    mov eax, [r8 + rcx*4]           ; name RVA
    lea rdi, [r12 + rax]
    mov rsi, r13
    call boot_zstreq
    cmp eax, 1
    jne .fen_next

    movzx eax, word [r9 + rcx*2]    ; ordinal
    mov eax, [r10 + rax*4]          ; function RVA
    lea rax, [r12 + rax]
    jmp .fen_out
.fen_next:
    inc ecx
    jmp .fen_loop

.fen_fail:
    xor eax, eax
.fen_out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

boot_getproc:
    ; (module_base rdi, name_ptr rsi) -> rax or 0
    push rbx
    mov rax, [rel win32_GetProcAddress]
    test rax, rax
    jz .fail
    mov rcx, rdi
    mov rdx, rsi
    mov rbx, rsp
    and rsp, -16
    sub rsp, 32
    call rax
    mov rsp, rbx
    pop rbx
    ret
.fail:
    xor eax, eax
    pop rbx
    ret

boot_loadlibrary:
    ; (name_ptr rdi) -> rax module base or 0
    push rbx
    mov rax, [rel win32_LoadLibraryA]
    test rax, rax
    jz .fail
    mov rcx, rdi
    mov rbx, rsp
    and rsp, -16
    sub rsp, 32
    call rax
    mov rsp, rbx
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
    lea rsi, [rel s_GetProcAddress]
    call boot_find_export_name
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
    lea rsi, [rel s_FindFirstFileA]
    call boot_getproc
    mov [rel win32_FindFirstFileA], rax
    mov rdi, [rel win_mod_kernel32]
    lea rsi, [rel s_FindNextFileA]
    call boot_getproc
    mov [rel win32_FindNextFileA], rax
    mov rdi, [rel win_mod_kernel32]
    lea rsi, [rel s_FindClose]
    call boot_getproc
    mov [rel win32_FindClose], rax
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
    mov rdi, [rel win_mod_kernel32]
    lea rsi, [rel s_GetTickCount64]
    call boot_getproc
    mov [rel win32_GetTickCount64], rax
    mov rdi, [rel win_mod_kernel32]
    lea rsi, [rel s_Sleep]
    call boot_getproc
    mov [rel win32_Sleep], rax

    ; user32 exports
    mov rdi, [rel win_mod_user32]
    test rdi, rdi
    jz .skip_user32
    lea rsi, [rel s_RegisterClassExA]
    call boot_getproc
    mov [rel win32_RegisterClassExA], rax
    mov rdi, [rel win_mod_user32]
    lea rsi, [rel s_CreateWindowExA]
    call boot_getproc
    mov [rel win32_CreateWindowExA], rax
    mov rdi, [rel win_mod_user32]
    lea rsi, [rel s_DefWindowProcA]
    call boot_getproc
    mov [rel win32_DefWindowProcA], rax
    mov rdi, [rel win_mod_user32]
    lea rsi, [rel s_DestroyWindow]
    call boot_getproc
    mov [rel win32_DestroyWindow], rax
    mov rdi, [rel win_mod_user32]
    lea rsi, [rel s_ShowWindow]
    call boot_getproc
    mov [rel win32_ShowWindow], rax
    mov rdi, [rel win_mod_user32]
    lea rsi, [rel s_UpdateWindow]
    call boot_getproc
    mov [rel win32_UpdateWindow], rax
    mov rdi, [rel win_mod_user32]
    lea rsi, [rel s_PeekMessageA]
    call boot_getproc
    mov [rel win32_PeekMessageA], rax
    mov rdi, [rel win_mod_user32]
    lea rsi, [rel s_TranslateMessage]
    call boot_getproc
    mov [rel win32_TranslateMessage], rax
    mov rdi, [rel win_mod_user32]
    lea rsi, [rel s_DispatchMessageA]
    call boot_getproc
    mov [rel win32_DispatchMessageA], rax
    mov rdi, [rel win_mod_user32]
    lea rsi, [rel s_PostQuitMessage]
    call boot_getproc
    mov [rel win32_PostQuitMessage], rax
    mov rdi, [rel win_mod_user32]
    lea rsi, [rel s_LoadCursorA]
    call boot_getproc
    mov [rel win32_LoadCursorA], rax
    mov rdi, [rel win_mod_user32]
    lea rsi, [rel s_GetDC]
    call boot_getproc
    mov [rel win32_GetDC], rax
    mov rdi, [rel win_mod_user32]
    lea rsi, [rel s_ReleaseDC]
    call boot_getproc
    mov [rel win32_ReleaseDC], rax
    mov rdi, [rel win_mod_user32]
    lea rsi, [rel s_GetSystemMetrics]
    call boot_getproc
    mov [rel win32_GetSystemMetrics], rax
    mov rdi, [rel win_mod_user32]
    lea rsi, [rel s_RegisterTouchWindow]
    call boot_getproc
    mov [rel win32_RegisterTouchWindow], rax
    mov rdi, [rel win_mod_user32]
    lea rsi, [rel s_GetPointerInfo]
    call boot_getproc
    mov [rel win32_GetPointerInfo], rax
    mov rdi, [rel win_mod_user32]
    lea rsi, [rel s_SendMessageA]
    call boot_getproc
    mov [rel win32_SendMessageA], rax
    mov rdi, [rel win_mod_user32]
    lea rsi, [rel s_RegisterHotKey]
    call boot_getproc
    mov [rel win32_RegisterHotKey], rax
    mov rdi, [rel win_mod_user32]
    lea rsi, [rel s_EnumWindows]
    call boot_getproc
    mov [rel win32_EnumWindows], rax
    mov rdi, [rel win_mod_user32]
    lea rsi, [rel s_SetWindowPos]
    call boot_getproc
    mov [rel win32_SetWindowPos], rax
    mov rdi, [rel win_mod_user32]
    lea rsi, [rel s_SetWindowLongPtrA]
    call boot_getproc
    mov [rel win32_SetWindowLongPtrA], rax
.skip_user32:

    ; gdi32 exports
    mov rdi, [rel win_mod_gdi32]
    test rdi, rdi
    jz .skip_gdi32
    lea rsi, [rel s_CreateCompatibleDC]
    call boot_getproc
    mov [rel win32_CreateCompatibleDC], rax
    mov rdi, [rel win_mod_gdi32]
    lea rsi, [rel s_CreateDIBSection]
    call boot_getproc
    mov [rel win32_CreateDIBSection], rax
    mov rdi, [rel win_mod_gdi32]
    lea rsi, [rel s_SelectObject]
    call boot_getproc
    mov [rel win32_SelectObject], rax
    mov rdi, [rel win_mod_gdi32]
    lea rsi, [rel s_BitBlt]
    call boot_getproc
    mov [rel win32_BitBlt], rax
    mov rdi, [rel win_mod_gdi32]
    lea rsi, [rel s_DeleteObject]
    call boot_getproc
    mov [rel win32_DeleteObject], rax
    mov rdi, [rel win_mod_gdi32]
    lea rsi, [rel s_DeleteDC]
    call boot_getproc
    mov [rel win32_DeleteDC], rax
    mov rdi, [rel win_mod_gdi32]
    lea rsi, [rel s_SetBkMode]
    call boot_getproc
    mov [rel win32_SetBkMode], rax
    mov rdi, [rel win_mod_gdi32]
    lea rsi, [rel s_SetTextColor]
    call boot_getproc
    mov [rel win32_SetTextColor], rax
    mov rdi, [rel win_mod_gdi32]
    lea rsi, [rel s_TextOutA]
    call boot_getproc
    mov [rel win32_TextOutA], rax
.skip_gdi32:

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
    push rbx
    mov rbx, rsp
    and rsp, -16
    sub rsp, 32
    call rax
    mov rsp, rbx
    pop rbx

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
