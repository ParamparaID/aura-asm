; history.asm
; Ring-buffer history storage

extern arena_alloc

section .text
global history_init
global history_add
global history_get
global history_navigate_up
global history_navigate_down
global history_reset_cursor
global history_search
global history_save
global history_load

%define H_ENTRIES_OFF               0
%define H_LENGTHS_OFF               8
%define H_CAPACITY_OFF              16
%define H_COUNT_OFF                 24
%define H_HEAD_OFF                  32
%define H_CURSOR_OFF                40
%define H_FILE_PATH_OFF             48
%define H_ARENA_OFF                 56
%define H_SIZE                      64

memcpy_hist:
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

memeq_hist:
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

contains_sub_hist:
    ; rdi=line, rsi=line_len, rdx=pat, rcx=pat_len -> rax=1/0
    xor eax, eax
    cmp rcx, 0
    je .yes
    cmp rsi, rcx
    jb .no
    xor r8, r8
.outer:
    mov r9, rsi
    sub r9, rcx
    cmp r8, r9
    ja .no
    lea r10, [rdi + r8]
    push rdi
    push rsi
    push rdx
    push rcx
    mov rdi, r10
    mov rsi, rdx
    mov rdx, rcx
    call memeq_hist
    pop rcx
    pop rdx
    pop rsi
    pop rdi
    cmp rax, 1
    je .yes
    inc r8
    jmp .outer
.yes:
    mov eax, 1
    ret
.no:
    xor eax, eax
    ret

; history_init(arena, capacity) -> hist ptr or 0
history_init:
    test rdi, rdi
    jz .fail
    test rsi, rsi
    jz .fail
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12, rsi

    mov rdi, rbx
    mov rsi, H_SIZE
    call arena_alloc
    test rax, rax
    jz .fail_pop
    mov r13, rax

    mov rdi, rbx
    mov rsi, r12
    imul rsi, 8
    call arena_alloc
    test rax, rax
    jz .fail_pop
    mov [r13 + H_ENTRIES_OFF], rax

    mov rdi, rbx
    mov rsi, r12
    imul rsi, 8
    call arena_alloc
    test rax, rax
    jz .fail_pop
    mov [r13 + H_LENGTHS_OFF], rax

    mov [r13 + H_CAPACITY_OFF], r12
    mov qword [r13 + H_COUNT_OFF], 0
    mov qword [r13 + H_HEAD_OFF], 0
    mov qword [r13 + H_CURSOR_OFF], 0
    mov qword [r13 + H_FILE_PATH_OFF], 0
    mov [r13 + H_ARENA_OFF], rbx
    mov rax, r13
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

; history_get(hist, idx_from_newest) -> rax ptr, rdx len
history_get:
    xor edx, edx
    test rdi, rdi
    jz .none
    cmp rsi, [rdi + H_COUNT_OFF]
    jae .none
    mov rcx, [rdi + H_HEAD_OFF]
    cmp rcx, rsi
    ja .calc
    add rcx, [rdi + H_CAPACITY_OFF]
.calc:
    sub rcx, rsi
    dec rcx
    mov rax, [rdi + H_ENTRIES_OFF]
    mov rax, [rax + rcx*8]
    mov rdx, [rdi + H_LENGTHS_OFF]
    mov rdx, [rdx + rcx*8]
    ret
.none:
    xor eax, eax
    xor edx, edx
    ret

; history_add(hist, line, len) -> 0/-1
history_add:
    test rdi, rdi
    jz .fail
    test rsi, rsi
    jz .ok
    test rdx, rdx
    jz .ok
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx

    ; skip consecutive duplicates
    cmp qword [rbx + H_COUNT_OFF], 0
    je .store
    mov rcx, 0
    mov rdi, rbx
    mov rsi, rcx
    call history_get
    test rax, rax
    jz .store
    cmp rdx, r13
    jne .store
    mov rdi, rax
    mov rsi, r12
    mov rdx, r13
    call memeq_hist
    cmp rax, 1
    je .ok_pop

.store:
    mov rdi, [rbx + H_ARENA_OFF]
    mov rsi, r13
    inc rsi
    call arena_alloc
    test rax, rax
    jz .fail_pop
    mov r8, rax
    mov rdi, r8
    mov rsi, r12
    mov rdx, r13
    call memcpy_hist
    mov byte [r8 + r13], 0

    mov rcx, [rbx + H_HEAD_OFF]
    mov r9, [rbx + H_ENTRIES_OFF]
    mov [r9 + rcx*8], r8
    mov r9, [rbx + H_LENGTHS_OFF]
    mov [r9 + rcx*8], r13

    inc rcx
    cmp rcx, [rbx + H_CAPACITY_OFF]
    jb .head_ok
    xor ecx, ecx
.head_ok:
    mov [rbx + H_HEAD_OFF], rcx
    mov rax, [rbx + H_COUNT_OFF]
    cmp rax, [rbx + H_CAPACITY_OFF]
    jae .cur_reset
    inc qword [rbx + H_COUNT_OFF]
.cur_reset:
    mov qword [rbx + H_CURSOR_OFF], 0

.ok_pop:
    xor eax, eax
    pop r13
    pop r12
    pop rbx
    ret
.fail_pop:
    pop r13
    pop r12
    pop rbx
.fail:
    mov eax, -1
    ret
.ok:
    xor eax, eax
    ret

; history_navigate_up(hist) -> rax ptr, rdx len
history_navigate_up:
    test rdi, rdi
    jz .none
    cmp qword [rdi + H_COUNT_OFF], 0
    je .none
    mov rcx, [rdi + H_CURSOR_OFF]
    cmp rcx, [rdi + H_COUNT_OFF]
    jae .maxed
    inc rcx
    mov [rdi + H_CURSOR_OFF], rcx
.maxed:
    mov rsi, [rdi + H_CURSOR_OFF]
    dec rsi
    jmp history_get
.none:
    xor eax, eax
    xor edx, edx
    ret

; history_navigate_down(hist) -> rax ptr (or 0), rdx len
history_navigate_down:
    test rdi, rdi
    jz .none
    cmp qword [rdi + H_CURSOR_OFF], 0
    je .none
    dec qword [rdi + H_CURSOR_OFF]
    cmp qword [rdi + H_CURSOR_OFF], 0
    je .none
    mov rsi, [rdi + H_CURSOR_OFF]
    dec rsi
    jmp history_get
.none:
    xor eax, eax
    xor edx, edx
    ret

history_reset_cursor:
    test rdi, rdi
    jz .ret
    mov qword [rdi + H_CURSOR_OFF], 0
.ret:
    ret

; history_search(hist, pattern, pattern_len) -> rax ptr, rdx len
history_search:
    test rdi, rdi
    jz .none
    test rsi, rsi
    jz .none
    test rdx, rdx
    jz .none
    cmp qword [rdi + H_COUNT_OFF], 0
    je .none
    xor rsi, rsi
    jmp history_get
.none:
    xor eax, eax
    xor edx, edx
    ret

history_save:
    xor eax, eax
    ret

history_load:
    xor eax, eax
    ret
