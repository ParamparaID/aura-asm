; Plugin registry / marketplace (MVP, local-only core)
%include "src/hal/linux_x86_64/defs.inc"

section .text
global http_get
global apkg_init
global apkg_list_count
global apkg_is_installed
global apkg_install_local
global apkg_remove
global apkg_search
global apkg_install
global apkg_update
global apkg_list

%define APKG_MAX_ITEMS       64
%define APKG_NAME_MAX        64

section .bss
    apkg_count              resd 1
    apkg_names              resb APKG_MAX_ITEMS * APKG_NAME_MAX

section .text

apkg_strlen:
    xor eax, eax
.l:
    cmp byte [rdi + rax], 0
    je .r
    inc eax
    jmp .l
.r:
    ret

apkg_streq:
    ; rdi a, rsi b -> eax 1/0
    push rbx
    xor ebx, ebx
.l:
    mov al, [rdi + rbx]
    cmp al, [rsi + rbx]
    jne .n
    test al, al
    je .y
    inc ebx
    jmp .l
.y:
    mov eax, 1
    pop rbx
    ret
.n:
    xor eax, eax
    pop rbx
    ret

apkg_find_index:
    ; rdi name cstr -> eax idx or -1
    push rbx
    push r12
    mov r12, rdi
    xor ebx, ebx
.l:
    cmp ebx, [rel apkg_count]
    jae .n
    mov eax, ebx
    imul eax, APKG_NAME_MAX
    lea rdi, [rel apkg_names + rax]
    mov rsi, r12
    call apkg_streq
    cmp eax, 1
    je .y
    inc ebx
    jmp .l
.y:
    mov eax, ebx
    pop r12
    pop rbx
    ret
.n:
    mov eax, -1
    pop r12
    pop rbx
    ret

http_get:
    ; (url rdi, url_len rsi, out rdx, out_max rcx) -> bytes_read/-1
    ; MVP: offline-safe no-op
    mov eax, -1
    ret

apkg_init:
    ; () -> 0
    mov dword [rel apkg_count], 0
    xor eax, eax
    ret

apkg_list_count:
    mov eax, [rel apkg_count]
    ret

apkg_is_installed:
    ; rdi name cstr -> 1/0
    call apkg_find_index
    cmp eax, -1
    je .n
    mov eax, 1
    ret
.n:
    xor eax, eax
    ret

apkg_install_local:
    ; (path rdi ignored, name rsi) -> 0/-1
    push rbx
    mov rbx, rsi
    test rbx, rbx
    jz .f
    cmp dword [rel apkg_count], APKG_MAX_ITEMS
    jae .f
    mov rdi, rbx
    call apkg_find_index
    cmp eax, -1
    jne .ok
    mov eax, [rel apkg_count]
    imul eax, APKG_NAME_MAX
    lea rdi, [rel apkg_names + rax]
    xor ecx, ecx
.cp:
    cmp ecx, APKG_NAME_MAX - 1
    jae .term
    mov al, [rbx + rcx]
    test al, al
    je .term
    mov [rdi + rcx], al
    inc ecx
    jmp .cp
.term:
    mov byte [rdi + rcx], 0
    inc dword [rel apkg_count]
.ok:
    xor eax, eax
    pop rbx
    ret
.f:
    mov eax, -1
    pop rbx
    ret

apkg_remove:
    ; (name rdi) -> 0/-1
    push rbx
    push r12
    mov r12, rdi
    call apkg_find_index
    cmp eax, -1
    je .f
    mov ebx, eax
    mov ecx, [rel apkg_count]
    dec ecx
.sh:
    cmp ebx, ecx
    jae .done
    mov eax, ebx
    imul eax, APKG_NAME_MAX
    lea rdi, [rel apkg_names + rax]
    mov eax, ebx
    inc eax
    imul eax, APKG_NAME_MAX
    lea rsi, [rel apkg_names + rax]
    mov edx, APKG_NAME_MAX
    rep movsb
    inc ebx
    jmp .sh
.done:
    dec dword [rel apkg_count]
    xor eax, eax
    pop r12
    pop rbx
    ret
.f:
    mov eax, -1
    pop r12
    pop rbx
    ret

apkg_search:
    ; MVP no-op success
    xor eax, eax
    ret

apkg_install:
    ; (name rdi) -> 0/-1
    mov rsi, rdi
    xor edi, edi
    jmp apkg_install_local

apkg_update:
    xor eax, eax
    ret

apkg_list:
    ; MVP no-op (count via apkg_list_count)
    xor eax, eax
    ret
