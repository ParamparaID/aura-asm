; alias.asm
; Simple alias storage

extern arena_alloc

section .text
global alias_init
global alias_set
global alias_get
global alias_unset
global alias_list
global alias_expand

%define AL_CAP_DEFAULT               128
%define AL_ENTRY_SIZE                32

%define AE_NAME_PTR_OFF              0
%define AE_NAME_LEN_OFF              8
%define AE_VALUE_PTR_OFF             16
%define AE_VALUE_LEN_OFF             24

%define AS_ENTRIES_OFF               0
%define AS_CAPACITY_OFF              8
%define AS_COUNT_OFF                 16
%define AS_ARENA_PTR_OFF             24
%define AS_SIZE                      32

%define TOKEN_TYPE_OFF               0
%define TOKEN_START_OFF              8
%define TOKEN_LENGTH_OFF             16
%define TOK_WORD                     1

memcpy_alias:
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

memeq_alias:
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

find_alias:
    ; rdi=store rsi=name rdx=len -> rax=entry or 0
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    xor rcx, rcx
.loop:
    cmp rcx, [rbx + AS_CAPACITY_OFF]
    jae .none
    mov r8, [rbx + AS_ENTRIES_OFF]
    imul r9, rcx, AL_ENTRY_SIZE
    add r8, r9
    cmp qword [r8 + AE_NAME_PTR_OFF], 0
    je .next
    cmp dword [r8 + AE_NAME_LEN_OFF], r13d
    jne .next
    mov rdi, [r8 + AE_NAME_PTR_OFF]
    mov rsi, r12
    mov rdx, r13
    call memeq_alias
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

find_empty_alias:
    ; rdi=store -> rax=entry or 0
    push rbx
    mov rbx, rdi
    xor rcx, rcx
.loop:
    cmp rcx, [rbx + AS_CAPACITY_OFF]
    jae .none
    mov r8, [rbx + AS_ENTRIES_OFF]
    imul r9, rcx, AL_ENTRY_SIZE
    add r8, r9
    cmp qword [r8 + AE_NAME_PTR_OFF], 0
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

copy_cstr_alias:
    ; rdi=store rsi=src rdx=len -> rax=cstr or 0
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov rdi, [rbx + AS_ARENA_PTR_OFF]
    mov rsi, r13
    inc rsi
    call arena_alloc
    test rax, rax
    jz .fail
    mov r8, rax
    mov rdi, r8
    mov rsi, r12
    mov rdx, r13
    call memcpy_alias
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

alias_init:
    ; rdi=arena -> store
    test rdi, rdi
    jz .fail
    push rbx
    push r12
    mov rbx, rdi
    mov rdi, rbx
    mov rsi, AS_SIZE
    call arena_alloc
    test rax, rax
    jz .fail_pop
    mov r12, rax
    mov rdi, rbx
    mov rsi, AL_CAP_DEFAULT * AL_ENTRY_SIZE
    call arena_alloc
    test rax, rax
    jz .fail_pop
    mov [r12 + AS_ENTRIES_OFF], rax
    mov qword [r12 + AS_CAPACITY_OFF], AL_CAP_DEFAULT
    mov qword [r12 + AS_COUNT_OFF], 0
    mov [r12 + AS_ARENA_PTR_OFF], rbx
    mov rax, r12
    pop r12
    pop rbx
    ret
.fail_pop:
    pop r12
    pop rbx
.fail:
    xor eax, eax
    ret

alias_set:
    ; rdi=store rsi=name rdx=name_len rcx=val r8=val_len
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
    call find_alias
    test rax, rax
    jnz .have_slot
    mov rdi, rbx
    call find_empty_alias
    test rax, rax
    jz .fail
    inc qword [rbx + AS_COUNT_OFF]
.have_slot:
    mov [rsp + 0], rax                 ; slot

    mov rdi, rbx
    mov rsi, r12
    mov rdx, r13
    call copy_cstr_alias
    test rax, rax
    jz .fail
    mov [rsp + 8], rax                 ; copied name

    mov rdi, rbx
    mov rsi, r14
    mov rdx, r15
    call copy_cstr_alias
    test rax, rax
    jz .fail

    mov r10, [rsp + 0]
    mov r11, [rsp + 8]
    mov [r10 + AE_NAME_PTR_OFF], r11
    mov dword [r10 + AE_NAME_LEN_OFF], r13d
    mov [r10 + AE_VALUE_PTR_OFF], rax
    mov dword [r10 + AE_VALUE_LEN_OFF], r15d
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

alias_get:
    ; rdi=store rsi=name rdx=len -> value ptr
    test rdi, rdi
    jz .none
    call find_alias
    test rax, rax
    jz .none
    mov rax, [rax + AE_VALUE_PTR_OFF]
    ret
.none:
    xor eax, eax
    ret

alias_unset:
    ; rdi=store rsi=name rdx=len -> 0/-1
    test rdi, rdi
    jz .fail
    push rbx
    mov rbx, rdi
    call find_alias
    test rax, rax
    jz .fail_pop
    mov qword [rax + AE_NAME_PTR_OFF], 0
    mov qword [rax + AE_VALUE_PTR_OFF], 0
    mov dword [rax + AE_NAME_LEN_OFF], 0
    mov dword [rax + AE_VALUE_LEN_OFF], 0
    cmp qword [rbx + AS_COUNT_OFF], 0
    je .ok
    dec qword [rbx + AS_COUNT_OFF]
.ok:
    xor eax, eax
    pop rbx
    ret
.fail_pop:
    pop rbx
.fail:
    mov eax, -1
    ret

alias_list:
    ; rdi=store rsi=callback(name_ptr, value_ptr)
    test rdi, rdi
    jz .ret
    test rsi, rsi
    jz .ret
    push rbx
    push r12
    mov rbx, rdi
    mov r12, rsi
    xor rcx, rcx
.loop:
    cmp rcx, [rbx + AS_CAPACITY_OFF]
    jae .done
    mov r8, [rbx + AS_ENTRIES_OFF]
    imul r9, rcx, AL_ENTRY_SIZE
    add r8, r9
    cmp qword [r8 + AE_NAME_PTR_OFF], 0
    je .next
    mov rdi, [r8 + AE_NAME_PTR_OFF]
    mov rsi, [r8 + AE_VALUE_PTR_OFF]
    call r12
.next:
    inc rcx
    jmp .loop
.done:
    pop r12
    pop rbx
.ret:
    ret

alias_expand:
    ; rdi=store rsi=tokens rdx=token_count -> alias value ptr or 0
    test rdi, rdi
    jz .none
    test rsi, rsi
    jz .none
    test rdx, rdx
    jz .none
    cmp dword [rsi + TOKEN_TYPE_OFF], TOK_WORD
    jne .none
    mov rcx, [rsi + TOKEN_START_OFF]
    mov r8d, dword [rsi + TOKEN_LENGTH_OFF]
    mov rdi, rdi
    mov rsi, rcx
    mov rdx, r8
    call alias_get
    ret
.none:
    xor eax, eax
    ret
