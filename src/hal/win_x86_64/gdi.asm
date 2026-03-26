; gdi.asm - Win32 GDI helper wrappers for Aura Canvas
%include "src/hal/win_x86_64/defs.inc"

extern bootstrap_init
extern win32_CreateCompatibleDC
extern win32_CreateDIBSection
extern win32_SelectObject
extern win32_BitBlt
extern win32_DeleteObject
extern win32_DeleteDC

section .text
global gdi_create_surface
global gdi_present_surface
global gdi_destroy_surface

; gdi_create_surface(width, height, out_memdc, out_hbitmap, out_bits) -> 1/0
gdi_create_surface:
    push rbx
    push r12
    mov r12d, edi
    mov ebx, esi
    call bootstrap_init
    cmp eax, 1
    jne .fail

    ; memdc = CreateCompatibleDC(NULL)
    xor ecx, ecx
    sub rsp, 40
    mov rax, [rel win32_CreateCompatibleDC]
    call rax
    add rsp, 40
    test rax, rax
    jz .fail
    mov [rdx], rax

    ; CreateDIBSection
    sub rsp, 176
    lea rdi, [rsp + 32]
    mov ecx, 80
    xor eax, eax
    rep stosb
    mov dword [rsp + 32 + 0], BITMAPINFOHEADER_SIZE
    mov dword [rsp + 32 + 4], r12d
    mov eax, ebx
    neg eax
    mov dword [rsp + 32 + 8], eax
    mov word [rsp + 32 + 12], 1
    mov word [rsp + 32 + 14], 32
    mov dword [rsp + 32 + 16], BI_RGB
    mov qword [rsp + 32], 0
    mov qword [rsp + 40], 0
    mov rcx, [rdx]
    lea rdx, [rsp + 32]
    mov r8d, DIB_RGB_COLORS
    mov r9, r8
    mov rax, [rel win32_CreateDIBSection]
    call rax
    add rsp, 176
    test rax, rax
    jz .fail
    mov [rcx], rax

    ; SelectObject(memdc, bitmap)
    mov rcx, [rdx]
    mov rdx, [rcx]
    sub rsp, 40
    mov rax, [rel win32_SelectObject]
    call rax
    add rsp, 40
    mov eax, 1
    pop r12
    pop rbx
    ret
.fail:
    xor eax, eax
    pop r12
    pop rbx
    ret

; gdi_present_surface(hwnd_dc, width, height, memdc) -> 1/0
gdi_present_surface:
    sub rsp, 88
    mov dword [rsp + 32], ecx
    mov [rsp + 40], r8
    mov qword [rsp + 48], 0
    mov qword [rsp + 56], 0
    mov qword [rsp + 64], SRCCOPY
    mov rcx, rdi
    xor edx, edx
    xor r8d, r8d
    mov r9d, esi
    mov rax, [rel win32_BitBlt]
    call rax
    add rsp, 88
    ret

; gdi_destroy_surface(memdc, hbitmap) -> 0
gdi_destroy_surface:
    mov rcx, rsi
    sub rsp, 40
    mov rax, [rel win32_DeleteObject]
    call rax
    add rsp, 40
    mov rcx, rdi
    sub rsp, 40
    mov rax, [rel win32_DeleteDC]
    call rax
    add rsp, 40
    xor eax, eax
    ret
