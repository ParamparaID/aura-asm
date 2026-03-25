; manifest.asm — plugin.ini / plugin.toml MVP parser

%define MF_NAME_OFF                  0
%define MF_VERSION_OFF               64
%define MF_AUTHOR_OFF                68
%define MF_DESC_OFF                  132
%define MF_HOOKS_OFF                 260
%define MF_DEPS_OFF                  324
%define MANIFEST_STRUCT_SIZE         452

section .text
global manifest_parse

mf_trim_left:
    mov rax, rdi
    mov edx, esi
.l:
    test edx, edx
    jle .o
    mov cl, [rax]
    cmp cl, ' '
    je .adv
    cmp cl, 9
    jne .o
.adv:
    inc rax
    dec edx
    jmp .l
.o:
    ret

mf_trim_right:
    mov edx, esi
.l:
    test edx, edx
    jle .o
    mov ecx, edx
    dec ecx
    mov al, [rdi + rcx]
    cmp al, ' '
    je .cut
    cmp al, 9
    je .cut
    cmp al, 10
    je .cut
    cmp al, 13
    je .cut
    jmp .o
.cut:
    dec edx
    jmp .l
.o:
    ret

mf_copy_span:
    test ecx, ecx
    jle .out
    dec ecx
    xor r8d, r8d
.cp:
    cmp r8d, esi
    jae .term
    cmp r8d, ecx
    jae .term
    mov al, [rdi + r8]
    mov [rdx + r8], al
    inc r8d
    jmp .cp
.term:
    mov byte [rdx + r8], 0
.out:
    ret

mf_parse_u32:
    xor eax, eax
    xor ecx, ecx
.l:
    cmp ecx, esi
    jae .ok
    mov dl, [rdi + rcx]
    cmp dl, '0'
    jb .bad
    cmp dl, '9'
    ja .bad
    imul eax, eax, 10
    movzx edx, dl
    sub edx, '0'
    add eax, edx
    inc ecx
    jmp .l
.ok:
    ret
.bad:
    mov eax, -1
    ret

mf_key_eq:
    ; (key_ptr rdi, key_len esi, lit_ptr rdx) -> eax 1/0
    push rbx
    mov rbx, rdx
    xor ecx, ecx
.ll:
    cmp byte [rbx + rcx], 0
    je .ll_done
    inc ecx
    jmp .ll
.ll_done:
    cmp ecx, esi
    jne .no
    xor eax, eax
.cmp:
    cmp eax, esi
    jae .yes
    mov dl, [rdi + rax]
    cmp dl, [rbx + rax]
    jne .no
    inc eax
    jmp .cmp
.yes:
    mov eax, 1
    pop rbx
    ret
.no:
    xor eax, eax
    pop rbx
    ret

manifest_parse:
    ; manifest_parse(data rdi, data_len rsi, out rdx) -> eax 0/-1
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 24
    mov r12, rdi                         ; data
    mov r13, rsi                         ; data_len
    mov r14, rdx                         ; out
    test r12, r12
    jz .fail
    test r14, r14
    jz .fail

    mov rdi, r14
    mov ecx, MANIFEST_STRUCT_SIZE
    xor eax, eax
    rep stosb

    xor ebx, ebx                         ; line start idx
.line_loop:
    cmp rbx, r13
    jae .ok
    mov r15, rbx
.find_nl:
    cmp r15, r13
    jae .line_ready
    cmp byte [r12 + r15], 10
    je .line_ready
    inc r15
    jmp .find_nl
.line_ready:
    lea rdi, [r12 + rbx]
    mov esi, r15d
    sub esi, ebx
    call mf_trim_left
    mov r10, rax                         ; line ptr
    mov r11d, edx                        ; line len
    mov rdi, r10
    mov esi, r11d
    call mf_trim_right
    mov r11d, edx
    test r11d, r11d
    jle .next_line
    cmp byte [r10], '#'
    je .next_line
    cmp byte [r10], ';'
    je .next_line
    cmp byte [r10], '['
    je .next_line

    ; find '=' or ':'
    xor ecx, ecx
.find_sep:
    cmp ecx, r11d
    jae .next_line
    mov al, [r10 + rcx]
    cmp al, '='
    je .sep_found
    cmp al, ':'
    je .sep_found
    inc ecx
    jmp .find_sep
.sep_found:
    mov [rsp + 16], ecx                  ; sep idx

    ; key span
    mov r8, r10                          ; key ptr
    mov r9d, ecx                         ; key len raw
    mov rdi, r8
    mov esi, r9d
    call mf_trim_right
    mov r9d, edx                         ; key len trimmed
    test r9d, r9d
    jle .next_line

    ; value span
    mov ecx, [rsp + 16]
    lea rdi, [r10 + rcx + 1]
    mov esi, r11d
    sub esi, ecx
    dec esi
    call mf_trim_left
    mov rdi, rax                          ; keep trimmed-left ptr
    mov esi, edx
    call mf_trim_right
    mov [rsp + 0], rdi                   ; val ptr
    mov [rsp + 8], edx                   ; val len (dword)

    ; optional quote strip
    mov edx, [rsp + 8]
    cmp edx, 2
    jb .dispatch
    mov rax, [rsp + 0]
    mov cl, [rax]
    cmp cl, '"'
    je .uq_dq
    cmp cl, 39
    jne .dispatch
    mov r11d, edx
    dec r11d
    cmp byte [rax + r11], 39
    jne .dispatch
    inc rax
    sub edx, 2
    mov [rsp + 0], rax
    mov [rsp + 8], edx
    jmp .dispatch
.uq_dq:
    mov r11d, edx
    dec r11d
    cmp byte [rax + r11], '"'
    jne .dispatch
    inc rax
    sub edx, 2
    mov [rsp + 0], rax
    mov [rsp + 8], edx

.dispatch:
    ; name
    mov rdi, r8
    mov esi, r9d
    lea rdx, [rel k_name]
    call mf_key_eq
    test eax, eax
    jz .k_ver
    mov rdi, [rsp + 0]
    mov esi, [rsp + 8]
    lea rdx, [r14 + MF_NAME_OFF]
    mov ecx, 64
    call mf_copy_span
    jmp .next_line

.k_ver:
    mov rdi, r8
    mov esi, r9d
    lea rdx, [rel k_version]
    call mf_key_eq
    test eax, eax
    jz .k_author
    mov rdi, [rsp + 0]
    mov esi, [rsp + 8]
    call mf_parse_u32
    test eax, eax
    js .next_line
    mov [r14 + MF_VERSION_OFF], eax
    jmp .next_line

.k_author:
    mov rdi, r8
    mov esi, r9d
    lea rdx, [rel k_author]
    call mf_key_eq
    test eax, eax
    jz .k_desc
    mov rdi, [rsp + 0]
    mov esi, [rsp + 8]
    lea rdx, [r14 + MF_AUTHOR_OFF]
    mov ecx, 64
    call mf_copy_span
    jmp .next_line

.k_desc:
    mov rdi, r8
    mov esi, r9d
    lea rdx, [rel k_description]
    call mf_key_eq
    test eax, eax
    jz .k_hooks
    mov rdi, [rsp + 0]
    mov esi, [rsp + 8]
    lea rdx, [r14 + MF_DESC_OFF]
    mov ecx, 128
    call mf_copy_span
    jmp .next_line

.k_hooks:
    mov rdi, r8
    mov esi, r9d
    lea rdx, [rel k_commands]
    call mf_key_eq
    test eax, eax
    jnz .copy_hooks
    mov rdi, r8
    mov esi, r9d
    lea rdx, [rel k_hooks]
    call mf_key_eq
    test eax, eax
    jnz .copy_hooks
    mov rdi, r8
    mov esi, r9d
    lea rdx, [rel k_hooks_commands]
    call mf_key_eq
    test eax, eax
    jz .k_deps
.copy_hooks:
    mov rdi, [rsp + 0]
    mov esi, [rsp + 8]
    lea rdx, [r14 + MF_HOOKS_OFF]
    mov ecx, 64
    call mf_copy_span
    jmp .next_line

.k_deps:
    mov rdi, r8
    mov esi, r9d
    lea rdx, [rel k_dependencies]
    call mf_key_eq
    test eax, eax
    jnz .copy_deps
    mov rdi, r8
    mov esi, r9d
    lea rdx, [rel k_deps]
    call mf_key_eq
    test eax, eax
    jz .next_line
.copy_deps:
    mov rdi, [rsp + 0]
    mov esi, [rsp + 8]
    lea rdx, [r14 + MF_DEPS_OFF]
    mov ecx, 128
    call mf_copy_span

.next_line:
    mov rbx, r15
    inc rbx
    jmp .line_loop

.ok:
    add rsp, 24
    xor eax, eax
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

.fail:
    add rsp, 24
    mov eax, -1
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

k_name: db "name",0
k_version: db "version",0
k_author: db "author",0
k_description: db "description",0
k_commands: db "commands",0
k_hooks: db "hooks",0
k_hooks_commands: db "hooks.commands",0
k_dependencies: db "dependencies",0
k_deps: db "deps",0
