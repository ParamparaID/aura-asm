; variables.asm
; Simple variable store for Aura Shell (MVP)

extern arena_alloc
extern global_envp

section .text
global vars_init
global vars_get
global vars_set
global vars_unset
global vars_export
global vars_build_envp
global vars_expand

%define VAR_CAP_DEFAULT              256
%define VAR_ENTRY_SIZE               40

%define VE_NAME_PTR_OFF              0
%define VE_NAME_LEN_OFF              8
%define VE_VALUE_PTR_OFF             16
%define VE_VALUE_LEN_OFF             24
%define VE_EXPORTED_OFF              28
%define VE_HASH_OFF                  32

%define VS_ENTRIES_OFF               0
%define VS_CAPACITY_OFF              8
%define VS_COUNT_OFF                 16
%define VS_ARENA_PTR_OFF             24
%define VS_SIZE                      32

section .rodata
    empty_cstr_vars db 0

section .text

memcpy_v:
    test rdx, rdx
    jz .ret
.loop:
    mov al, [rsi]
    mov [rdi], al
    inc rdi
    inc rsi
    dec rdx
    jnz .loop
.ret:
    ret

memeq_v:
    xor eax, eax
    test rdx, rdx
    jz .yes
.loop:
    mov cl, [rdi]
    cmp cl, [rsi]
    jne .no
    inc rdi
    inc rsi
    dec rdx
    jnz .loop
.yes:
    mov eax, 1
    ret
.no:
    xor eax, eax
    ret

cstrlen_v:
    xor eax, eax
.loop:
    cmp byte [rdi + rax], 0
    je .ret
    inc rax
    jmp .loop
.ret:
    ret

find_var:
    ; rdi=store rsi=name rdx=len -> rax=entry or 0
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    xor rcx, rcx
.loop:
    cmp rcx, [rbx + VS_CAPACITY_OFF]
    jae .none
    mov r8, [rbx + VS_ENTRIES_OFF]
    imul r9, rcx, VAR_ENTRY_SIZE
    add r8, r9
    cmp qword [r8 + VE_NAME_PTR_OFF], 0
    je .next
    cmp dword [r8 + VE_NAME_LEN_OFF], r13d
    jne .next
    mov rdi, [r8 + VE_NAME_PTR_OFF]
    mov rsi, r12
    mov rdx, r13
    call memeq_v
    cmp rax, 1
    jne .next
    mov rax, r8
    jmp .ret
.next:
    inc rcx
    jmp .loop
.none:
    xor eax, eax
.ret:
    pop r13
    pop r12
    pop rbx
    ret

find_empty_var:
    ; rdi=store -> rax=entry or 0
    push rbx
    mov rbx, rdi
    xor rcx, rcx
.loop:
    cmp rcx, [rbx + VS_CAPACITY_OFF]
    jae .none
    mov r8, [rbx + VS_ENTRIES_OFF]
    imul r9, rcx, VAR_ENTRY_SIZE
    add r8, r9
    cmp qword [r8 + VE_NAME_PTR_OFF], 0
    je .ok
    inc rcx
    jmp .loop
.ok:
    mov rax, r8
    pop rbx
    ret
.none:
    xor eax, eax
    pop rbx
    ret

copy_cstr_store:
    ; rdi=store rsi=src rdx=len -> rax=cstr or 0
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov rdi, [rbx + VS_ARENA_PTR_OFF]
    mov rsi, r13
    inc rsi
    call arena_alloc
    test rax, rax
    jz .fail
    mov r8, rax
    mov rdi, r8
    mov rsi, r12
    mov rdx, r13
    call memcpy_v
    mov byte [r8 + r13], 0
    mov rax, r8
    jmp .ret
.fail:
    xor eax, eax
.ret:
    pop r13
    pop r12
    pop rbx
    ret

vars_set_internal:
    ; rdi=store rsi=name rdx=name_len rcx=val r8=val_len r9d=export_mode(-1 keep/0/1)
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r14, rcx
    mov r15, r8

    mov rdi, rbx
    mov rsi, r12
    mov rdx, r13
    call find_var
    test rax, rax
    jnz .have_entry
    mov rdi, rbx
    call find_empty_var
    test rax, rax
    jz .fail
    inc qword [rbx + VS_COUNT_OFF]
.have_entry:
    mov [rsp + 0], rax                 ; slot

    mov rdi, rbx
    mov rsi, r12
    mov rdx, r13
    call copy_cstr_store
    test rax, rax
    jz .fail
    mov [rsp + 8], rax                 ; copied name

    mov rdi, rbx
    mov rsi, r14
    mov rdx, r15
    call copy_cstr_store
    test rax, rax
    jz .fail

    mov r10, [rsp + 0]
    mov r11, [rsp + 8]
    mov [r10 + VE_NAME_PTR_OFF], r11
    mov dword [r10 + VE_NAME_LEN_OFF], r13d
    mov [r10 + VE_VALUE_PTR_OFF], rax
    mov dword [r10 + VE_VALUE_LEN_OFF], r15d
    cmp r9d, -1
    je .keep
    mov dword [r10 + VE_EXPORTED_OFF], r9d
.keep:
    xor eax, eax
    jmp .ret
.fail:
    mov eax, -1
.ret:
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

vars_init:
    ; rdi=arena -> store
    test rdi, rdi
    jz .fail
    push rbx
    push r12
    push r13
    mov rbx, rdi

    mov rdi, rbx
    mov rsi, VS_SIZE
    call arena_alloc
    test rax, rax
    jz .fail_pop
    mov r12, rax

    mov rdi, rbx
    mov rsi, VAR_CAP_DEFAULT * VAR_ENTRY_SIZE
    call arena_alloc
    test rax, rax
    jz .fail_pop
    mov [r12 + VS_ENTRIES_OFF], rax
    mov qword [r12 + VS_CAPACITY_OFF], VAR_CAP_DEFAULT
    mov qword [r12 + VS_COUNT_OFF], 0
    mov [r12 + VS_ARENA_PTR_OFF], rbx

    ; import envp if available
    mov r13, [rel global_envp]
    test r13, r13
    jz .ok
    xor rcx, rcx
.env_loop:
    mov rax, [r13 + rcx*8]
    test rax, rax
    jz .ok
    xor r8, r8
.eq_loop:
    cmp byte [rax + r8], 0
    je .next_env
    cmp byte [rax + r8], '='
    je .have_eq
    inc r8
    jmp .eq_loop
.have_eq:
    mov rdi, r12
    mov rsi, rax
    mov rdx, r8
    lea r9, [rax + r8 + 1]
    mov rdi, r9
    call cstrlen_v
    mov r8, rax
    mov rdi, r12
    mov rsi, [r13 + rcx*8]
    mov rdx, r8
    ; restore name len from scan
    mov rdx, 0
    ; recompute '=' quickly
.eq2:
    cmp byte [rsi + rdx], '='
    je .set_env
    inc rdx
    jmp .eq2
.set_env:
    lea rcx, [rsi + rdx + 1]
    mov rdi, rcx
    call cstrlen_v
    mov r8, rax
    mov rdi, r12
    mov r9d, 1
    call vars_set_internal
.next_env:
    inc rcx
    jmp .env_loop

.ok:
    mov rax, r12
    pop r13
    pop r12
    pop rbx
    ret
.fail_pop:
    pop r13
    pop r12
    pop rbx
.fail:
    xor eax, eax
    ret

vars_get:
    ; rdi=store rsi=name rdx=len -> value ptr
    test rdi, rdi
    jz .none
    call find_var
    test rax, rax
    jz .none
    mov rax, [rax + VE_VALUE_PTR_OFF]
    ret
.none:
    xor eax, eax
    ret

vars_set:
    mov r9d, -1
    jmp vars_set_internal

vars_unset:
    ; rdi=store rsi=name rdx=len
    test rdi, rdi
    jz .fail
    push rbx
    mov rbx, rdi
    call find_var
    test rax, rax
    jz .fail_pop
    mov qword [rax + VE_NAME_PTR_OFF], 0
    mov qword [rax + VE_VALUE_PTR_OFF], 0
    mov dword [rax + VE_NAME_LEN_OFF], 0
    mov dword [rax + VE_VALUE_LEN_OFF], 0
    mov dword [rax + VE_EXPORTED_OFF], 0
    cmp qword [rbx + VS_COUNT_OFF], 0
    je .ok
    dec qword [rbx + VS_COUNT_OFF]
.ok:
    xor eax, eax
    pop rbx
    ret
.fail_pop:
    pop rbx
.fail:
    mov eax, -1
    ret

vars_export:
    ; rdi=store rsi=name rdx=len
    test rdi, rdi
    jz .fail
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov rdi, rbx
    mov rsi, r12
    mov rdx, r13
    call find_var
    test rax, rax
    jz .create
    mov dword [rax + VE_EXPORTED_OFF], 1
    xor eax, eax
    pop r13
    pop r12
    pop rbx
    ret
.create:
    mov rdi, rbx
    mov rsi, r12
    mov rdx, r13
    lea rcx, [rel empty_cstr_vars]
    xor r8d, r8d
    mov r9d, 1
    call vars_set_internal
    pop r13
    pop r12
    pop rbx
    ret
.fail:
    mov eax, -1
    ret

vars_build_envp:
    ; rdi=store rsi=arena -> char**
    test rdi, rdi
    jz .none
    test rsi, rsi
    jz .none
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12, rsi

    xor r13, r13
    xor rcx, rcx
.count:
    cmp rcx, [rbx + VS_CAPACITY_OFF]
    jae .alloc_arr
    mov r8, [rbx + VS_ENTRIES_OFF]
    imul r9, rcx, VAR_ENTRY_SIZE
    add r8, r9
    cmp qword [r8 + VE_NAME_PTR_OFF], 0
    je .next_count
    cmp dword [r8 + VE_EXPORTED_OFF], 1
    jne .next_count
    inc r13
.next_count:
    inc rcx
    jmp .count

.alloc_arr:
    mov rdi, r12
    mov rsi, r13
    inc rsi
    imul rsi, 8
    call arena_alloc
    test rax, rax
    jz .none_pop
    mov r10, rax

    xor r11, r11
    xor rcx, rcx
.build:
    cmp rcx, [rbx + VS_CAPACITY_OFF]
    jae .done
    mov r8, [rbx + VS_ENTRIES_OFF]
    imul r9, rcx, VAR_ENTRY_SIZE
    add r8, r9
    cmp qword [r8 + VE_NAME_PTR_OFF], 0
    je .next
    cmp dword [r8 + VE_EXPORTED_OFF], 1
    jne .next
    mov r14d, dword [r8 + VE_NAME_LEN_OFF]
    mov r15d, dword [r8 + VE_VALUE_LEN_OFF]
    mov rdi, r12
    mov rsi, r14
    add rsi, r15
    add rsi, 2
    call arena_alloc
    test rax, rax
    jz .none_pop
    mov [r10 + r11*8], rax
    mov rdi, rax
    mov rsi, [r8 + VE_NAME_PTR_OFF]
    mov rdx, r14
    call memcpy_v
    mov byte [rax + r14], '='
    lea rdi, [rax + r14 + 1]
    mov rsi, [r8 + VE_VALUE_PTR_OFF]
    mov rdx, r15
    call memcpy_v
    lea rdx, [rax + r14 + 1]
    mov byte [rdx + r15], 0
    inc r11
.next:
    inc rcx
    jmp .build

.done:
    mov qword [r10 + r11*8], 0
    mov rax, r10
    pop r13
    pop r12
    pop rbx
    ret
.none_pop:
    pop r13
    pop r12
    pop rbx
.none:
    xor eax, eax
    ret

vars_expand:
    ; rdi=store rsi=input rdx=input_len rcx=out r8=out_max -> out_len/-1
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi                        ; store
    mov r12, rsi                        ; input
    mov r13, rdx                        ; input len
    mov r14, rcx                        ; output
    mov r15, r8                         ; output max
    xor r9, r9                          ; i
    xor r10, r10                        ; o

.next_char:
    cmp r9, r13
    jae .finish
    mov al, [r12 + r9]
    cmp al, '$'
    jne .emit_char

    inc r9
    cmp r9, r13
    jae .finish
    cmp byte [r12 + r9], '{'
    jne .scan_plain

    inc r9
    mov r11, r9                         ; name start
.scan_braced:
    cmp r9, r13
    jae .finish
    cmp byte [r12 + r9], '}'
    je .braced_done
    inc r9
    jmp .scan_braced
.braced_done:
    mov rdx, r9
    sub rdx, r11                        ; name len
    test rdx, rdx
    jz .skip_close
    mov rdi, rbx
    lea rsi, [r12 + r11]
    push r9
    push r10
    call vars_get
    pop r10
    pop r9
    test rax, rax
    jz .skip_close
    mov rdi, rax
    push r9
    push r10
    call cstrlen_v
    pop r10
    pop r9
    mov rcx, rax                        ; val len
    add rcx, r10
    cmp rcx, r15
    jae .overflow
    sub rcx, r10
    mov rdi, rbx
    lea rsi, [r12 + r11]
    mov rdx, r9
    sub rdx, r11
    push rcx
    push r9
    push r10
    call vars_get
    pop r10
    pop r9
    pop rcx
    lea rdi, [r14 + r10]
    mov rsi, rax
    mov rdx, rcx
    push r9
    push r10
    call memcpy_v
    pop r10
    pop r9
    add r10, rcx
.skip_close:
    inc r9                              ; skip '}'
    jmp .next_char

.scan_plain:
    mov r11, r9
.scan_plain_loop:
    cmp r9, r13
    jae .plain_done
    mov al, [r12 + r9]
    cmp al, '_'
    je .plain_adv
    cmp al, '0'
    jb .plain_alpha
    cmp al, '9'
    jbe .plain_adv
.plain_alpha:
    cmp al, 'A'
    jb .plain_done
    cmp al, 'Z'
    jbe .plain_adv
    cmp al, 'a'
    jb .plain_done
    cmp al, 'z'
    ja .plain_done
.plain_adv:
    inc r9
    jmp .scan_plain_loop
.plain_done:
    mov rdx, r9
    sub rdx, r11
    test rdx, rdx
    jz .next_char
    mov rdi, rbx
    lea rsi, [r12 + r11]
    push r9
    push r10
    call vars_get
    pop r10
    pop r9
    test rax, rax
    jz .next_char
    mov rdi, rax
    push r9
    push r10
    call cstrlen_v
    pop r10
    pop r9
    mov rcx, rax
    add rcx, r10
    cmp rcx, r15
    jae .overflow
    sub rcx, r10
    mov rdi, rbx
    lea rsi, [r12 + r11]
    mov rdx, r9
    sub rdx, r11
    push rcx
    push r9
    push r10
    call vars_get
    pop r10
    pop r9
    pop rcx
    lea rdi, [r14 + r10]
    mov rsi, rax
    mov rdx, rcx
    push r9
    push r10
    call memcpy_v
    pop r10
    pop r9
    add r10, rcx
    jmp .next_char

.emit_char:
    cmp r10, r15
    jae .overflow
    mov [r14 + r10], al
    inc r10
    inc r9
    jmp .next_char

.finish:
    cmp r10, r15
    jae .overflow
    mov byte [r14 + r10], 0
    mov rax, r10
    jmp .ret
.overflow:
    mov rax, -1
.ret:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
