; search.asm — recursive search over VFS
%include "src/hal/platform_defs.inc"
%include "src/fm/vfs.inc"

extern vfs_path_len
extern vfs_open_dir
extern vfs_read_file
extern vfs_stat
extern local_provider_get

%define SEARCH_PATH_MAX         512
%define SEARCH_FILE_BUF         8192

section .bss
    search_entry_tmp            resb DIR_ENTRY_SIZE
    search_file_buf             resb SEARCH_FILE_BUF
    search_stat_tmp             resb ST_STRUCT_SIZE

section .text
global search_glob_match
global search_by_name
global search_by_content
global search_by_criteria

search_glob_match:
    ; (name_ptr, pat_ptr) -> eax 1/0 ; supports * and ?
    push rbx
    push r12
    mov rbx, rdi
    mov r12, rsi
.loop:
    mov al, [r12]
    cmp al, 0
    je .end_pat
    cmp al, '*'
    je .star
    cmp al, '?'
    je .qmark
    cmp al, [rbx]
    jne .no
    test al, al
    je .yes
    inc rbx
    inc r12
    jmp .loop
.qmark:
    cmp byte [rbx], 0
    je .no
    inc rbx
    inc r12
    jmp .loop
.star:
    inc r12
    cmp byte [r12], 0
    je .yes
.star_try:
    mov rdi, rbx
    mov rsi, r12
    call search_glob_match
    test eax, eax
    jnz .yes
    cmp byte [rbx], 0
    je .no
    inc rbx
    jmp .star_try
.end_pat:
    cmp byte [rbx], 0
    jne .no
.yes:
    mov eax, 1
    pop r12
    pop rbx
    ret
.no:
    xor eax, eax
    pop r12
    pop rbx
    ret

search_join_path:
    ; (out, base, name) where base/name are c-strings -> eax len or -1
    push rbx
    mov rbx, rdi
    ; copy base
    xor edx, edx
.copy_base:
    cmp edx, SEARCH_PATH_MAX - 2
    jae .fail
    mov al, [rsi + rdx]
    mov [rbx + rdx], al
    test al, al
    je .base_done
    inc edx
    jmp .copy_base
.base_done:
    test edx, edx
    jz .add_slash
    cmp byte [rbx + rdx - 1], '/'
    je .copy_name
.add_slash:
    mov byte [rbx + rdx], '/'
    inc edx
.copy_name:
    xor ecx, ecx
.copy_n:
    cmp edx, SEARCH_PATH_MAX - 1
    jae .fail
    mov al, [r8 + rcx]
    mov [rbx + rdx], al
    test al, al
    je .ok
    inc ecx
    inc edx
    jmp .copy_n
.ok:
    mov eax, edx
    pop rbx
    ret
.fail:
    mov eax, -1
    pop rbx
    ret

; search_by_name(root, pattern, pattern_len, results, max_results, cancel_flag)
; results array: max_results * SEARCH_PATH_MAX bytes
; returns eax count
search_by_name:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp
    sub rsp, SEARCH_PATH_MAX + 16
    mov rbx, rdi
    mov r12, rsi
    mov r13, rcx
    mov r14d, r8d
    mov r15, r9

    ; open dir
    mov rdi, rbx
    call vfs_path_len
    mov esi, eax
    mov rdi, rbx
    call vfs_open_dir
    test rax, rax
    jz .err
    mov [rsp + SEARCH_PATH_MAX], rax
    call local_provider_get
    mov [rsp + SEARCH_PATH_MAX + 8], rax

    xor ebp, ebp
.loop:
    test r15, r15
    jz .read
    cmp dword [r15], 0
    jne .done
.read:
    mov r10, [rsp + SEARCH_PATH_MAX + 8]
    mov rdi, r10
    mov rsi, [rsp + SEARCH_PATH_MAX]
    lea rdx, [rel search_entry_tmp]
    mov r11, [r10 + VFS_FN_READ_ENTRY_OFF]
    call r11
    cmp eax, 1
    jne .done

    ; match file name
    lea rdi, [rel search_entry_tmp + DE_NAME_OFF]
    mov rsi, r12
    call search_glob_match
    test eax, eax
    jz .maybe_recurse
    cmp ebp, r14d
    jae .maybe_recurse
    ; store full path in results slot
    mov eax, ebp
    imul eax, SEARCH_PATH_MAX
    lea rdi, [r13 + rax]
    mov rsi, rbx
    lea r8, [rel search_entry_tmp + DE_NAME_OFF]
    call search_join_path
    inc ebp

.maybe_recurse:
    mov eax, [rel search_entry_tmp + DE_TYPE_OFF]
    cmp eax, DT_DIR
    jne .loop
    ; recurse into subdir
    lea rdi, [rsp]
    mov rsi, rbx
    lea r8, [rel search_entry_tmp + DE_NAME_OFF]
    call search_join_path
    test eax, eax
    js .loop
    mov eax, ebp
    imul eax, SEARCH_PATH_MAX
    lea rcx, [r13 + rax]
    mov edx, 0
    mov r8d, r14d
    sub r8d, ebp
    mov rdi, rsp
    mov rsi, r12
    mov r9, r15
    call search_by_name
    test eax, eax
    js .loop
    add ebp, eax
    jmp .loop

.done:
    mov r10, [rsp + SEARCH_PATH_MAX + 8]
    mov r11, [r10 + VFS_FN_CLOSE_DIR_OFF]
    mov rdi, r10
    mov rsi, [rsp + SEARCH_PATH_MAX]
    call r11
    mov eax, ebp
    add rsp, SEARCH_PATH_MAX + 16
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.err:
    mov eax, -1
    add rsp, SEARCH_PATH_MAX + 16
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; search_by_content(root, needle, needle_len, results, max_results, cancel_flag)
search_by_content:
    ; MVP implementation: reuse name traversal and check regular files with simple scan.
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, SEARCH_PATH_MAX + 16
    mov rbx, rdi
    mov r12, rsi
    mov r13d, edx
    mov r14, rcx
    mov r15d, r8d
    mov r11, r9

    mov rdi, rbx
    call vfs_path_len
    mov esi, eax
    mov rdi, rbx
    call vfs_open_dir
    test rax, rax
    jz .ce
    mov [rsp + SEARCH_PATH_MAX], rax
    call local_provider_get
    mov [rsp + SEARCH_PATH_MAX + 8], rax

    xor ebx, ebx
.cloop:
    test r11, r11
    jz .cread
    cmp dword [r11], 0
    jne .cdone
.cread:
    mov r10, [rsp + SEARCH_PATH_MAX + 8]
    mov rdi, r10
    mov rsi, [rsp + SEARCH_PATH_MAX]
    lea rdx, [rel search_entry_tmp]
    mov rax, [r10 + VFS_FN_READ_ENTRY_OFF]
    call rax
    cmp eax, 1
    jne .cdone

    lea rdi, [rsp]
    mov rsi, rbx
    lea r8, [rel search_entry_tmp + DE_NAME_OFF]
    call search_join_path
    test eax, eax
    js .cloop

    mov eax, [rel search_entry_tmp + DE_TYPE_OFF]
    cmp eax, DT_DIR
    je .recurse_dir
    cmp eax, DT_REG
    jne .cloop

    mov rdi, rsp
    call vfs_path_len
    mov esi, eax
    lea rdx, [rel search_file_buf]
    mov ecx, SEARCH_FILE_BUF
    mov rdi, rsp
    call vfs_read_file
    test eax, eax
    jle .cloop
    mov r9d, eax                      ; file bytes
    ; naive substring scan
    xor ecx, ecx
.scan:
    cmp ecx, r9d
    jae .cloop
    mov edx, r9d
    sub edx, ecx
    cmp edx, r13d
    jb .cloop
    lea rsi, [rel search_file_buf + rcx]
    mov rdi, r12
    mov edx, r13d
.cmpn:
    mov al, [rsi]
    cmp al, [rdi]
    jne .next_scan
    inc rsi
    inc rdi
    dec edx
    jnz .cmpn
    cmp ebx, r15d
    jae .cloop
    mov eax, ebx
    imul eax, SEARCH_PATH_MAX
    lea rdi, [r14 + rax]
    mov rsi, rsp
    mov ecx, SEARCH_PATH_MAX
    rep movsb
    inc ebx
    jmp .cloop
.next_scan:
    inc ecx
    jmp .scan

.recurse_dir:
    mov eax, ebx
    imul eax, SEARCH_PATH_MAX
    lea rcx, [r14 + rax]
    mov rdi, rsp
    mov rsi, r12
    mov edx, r13d
    mov r8d, r15d
    sub r8d, ebx
    mov r9, r11
    call search_by_content
    test eax, eax
    js .cloop
    add ebx, eax
    jmp .cloop

.cdone:
    mov r10, [rsp + SEARCH_PATH_MAX + 8]
    mov rax, [r10 + VFS_FN_CLOSE_DIR_OFF]
    mov rdi, r10
    mov rsi, [rsp + SEARCH_PATH_MAX]
    call rax
    mov eax, ebx
    add rsp, SEARCH_PATH_MAX + 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.ce:
    mov eax, -1
    add rsp, SEARCH_PATH_MAX + 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; search_by_criteria(root, min_size, max_size, after_date, before_date, results, max_results)
search_by_criteria:
    ; lightweight implementation: recurse and filter by stat fields.
    ; rdi root, rsi min_size, rdx max_size, rcx after, r8 before, r9 results, [rsp+8] max_results
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, SEARCH_PATH_MAX + 24
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r14, rcx
    mov r15, r8
    mov [rsp + SEARCH_PATH_MAX], r9
    mov eax, [rsp + SEARCH_PATH_MAX + 24 + 8]
    mov [rsp + SEARCH_PATH_MAX + 8], eax

    mov rdi, rbx
    call vfs_path_len
    mov esi, eax
    mov rdi, rbx
    call vfs_open_dir
    test rax, rax
    jz .qe
    mov [rsp + SEARCH_PATH_MAX + 16], rax
    call local_provider_get
    mov [rsp + SEARCH_PATH_MAX + 20], rax
    xor ebx, ebx
.qloop:
    mov r10, [rsp + SEARCH_PATH_MAX + 20]
    mov rdi, r10
    mov rsi, [rsp + SEARCH_PATH_MAX + 16]
    lea rdx, [rel search_entry_tmp]
    mov r11, [r10 + VFS_FN_READ_ENTRY_OFF]
    call r11
    cmp eax, 1
    jne .qdone
    lea rdi, [rsp]
    mov rsi, rbx
    lea r8, [rel search_entry_tmp + DE_NAME_OFF]
    call search_join_path
    test eax, eax
    js .qloop

    mov rdi, rsp
    call vfs_path_len
    mov esi, eax
    lea rdx, [rel search_stat_tmp]
    mov rdi, rsp
    call vfs_stat
    test eax, eax
    js .qloop
    mov rax, [rel search_stat_tmp + ST_SIZE_OFF]
    cmp rax, r12
    jb .qrecurse
    cmp r13, 0
    je .date_chk
    cmp rax, r13
    ja .qrecurse
.date_chk:
    mov rax, [rel search_stat_tmp + ST_MTIME_OFF]
    cmp r14, 0
    je .before_chk
    cmp rax, r14
    jb .qrecurse
.before_chk:
    cmp r15, 0
    je .emit
    cmp rax, r15
    ja .qrecurse
.emit:
    cmp ebx, [rsp + SEARCH_PATH_MAX + 8]
    jae .qrecurse
    mov eax, ebx
    imul eax, SEARCH_PATH_MAX
    mov rdi, [rsp + SEARCH_PATH_MAX]
    add rdi, rax
    mov rsi, rsp
    mov ecx, SEARCH_PATH_MAX
    rep movsb
    inc ebx
.qrecurse:
    mov eax, [rel search_entry_tmp + DE_TYPE_OFF]
    cmp eax, DT_DIR
    jne .qloop
    ; recurse
    mov eax, ebx
    imul eax, SEARCH_PATH_MAX
    mov rcx, [rsp + SEARCH_PATH_MAX]
    add rcx, rax
    mov rdi, rsp
    mov rsi, r12
    mov rdx, r13
    mov r8, r15
    mov r9, rcx
    push qword [rsp + SEARCH_PATH_MAX + 8 + 8] ; max_results
    call search_by_criteria
    add rsp, 8
    test eax, eax
    js .qloop
    add ebx, eax
    jmp .qloop

.qdone:
    mov r10, [rsp + SEARCH_PATH_MAX + 20]
    mov r11, [r10 + VFS_FN_CLOSE_DIR_OFF]
    mov rdi, r10
    mov rsi, [rsp + SEARCH_PATH_MAX + 16]
    call r11
    mov eax, ebx
    add rsp, SEARCH_PATH_MAX + 24
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.qe:
    mov eax, -1
    add rsp, SEARCH_PATH_MAX + 24
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
