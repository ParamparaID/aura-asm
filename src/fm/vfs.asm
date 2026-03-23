; vfs.asm — VFS provider registry and dispatch
%include "src/fm/vfs.inc"

extern local_provider_get

section .bss
    vfs_providers            resq VFS_MAX_PROVIDERS
    vfs_provider_count       resd 1

section .text
global vfs_init
global vfs_register_provider
global vfs_get_provider
global vfs_open_dir
global vfs_read_entries
global vfs_stat
global vfs_read_file
global vfs_write_file
global vfs_mkdir
global vfs_rmdir
global vfs_unlink
global vfs_rename
global vfs_copy
global vfs_path_len

vfs_path_len:
    xor eax, eax
.loop:
    cmp byte [rdi + rax], 0
    je .out
    inc eax
    jmp .loop
.out:
    ret

vfs_init:
    xor eax, eax
    mov dword [rel vfs_provider_count], eax
    call local_provider_get
    test rax, rax
    jz .ok
    mov rdi, rax
    call vfs_register_provider
.ok:
    xor eax, eax
    ret

; vfs_register_provider(provider) -> eax 0 ok, -1 full
vfs_register_provider:
    mov ecx, [rel vfs_provider_count]
    cmp ecx, VFS_MAX_PROVIDERS
    jae .full
    mov [rel vfs_providers + rcx*8], rdi
    inc ecx
    mov [rel vfs_provider_count], ecx
    xor eax, eax
    ret
.full:
    mov eax, -1
    ret

; vfs_get_provider(path_ptr, path_len) -> rax provider*
vfs_get_provider:
    push rbx
    push r12
    mov rbx, rdi
    mov r12d, esi

    mov edx, VFS_LOCAL
    cmp r12d, 7
    jb .search
    cmp byte [rbx + 0], 's'
    jne .chk_tar
    cmp byte [rbx + 1], 'f'
    jne .chk_tar
    cmp byte [rbx + 2], 't'
    jne .chk_tar
    cmp byte [rbx + 3], 'p'
    jne .chk_tar
    cmp byte [rbx + 4], ':'
    jne .chk_tar
    cmp byte [rbx + 5], '/'
    jne .chk_tar
    cmp byte [rbx + 6], '/'
    jne .chk_tar
    mov edx, VFS_SFTP
    jmp .search
.chk_tar:
    cmp r12d, 6
    jb .search
    cmp byte [rbx + 0], 't'
    jne .search
    cmp byte [rbx + 1], 'a'
    jne .search
    cmp byte [rbx + 2], 'r'
    jne .search
    cmp byte [rbx + 3], ':'
    jne .search
    cmp byte [rbx + 4], '/'
    jne .search
    cmp byte [rbx + 5], '/'
    jne .search
    mov edx, VFS_ARCHIVE

.search:
    xor ecx, ecx
.loop:
    cmp ecx, [rel vfs_provider_count]
    jae .fallback
    mov rax, [rel vfs_providers + rcx*8]
    inc ecx
    test rax, rax
    jz .loop
    cmp dword [rax + VFS_TYPE_OFF], edx
    jne .loop
    jmp .out
.fallback:
    xor ecx, ecx
.fb_loop:
    cmp ecx, [rel vfs_provider_count]
    jae .none
    mov rax, [rel vfs_providers + rcx*8]
    inc ecx
    test rax, rax
    jz .fb_loop
    cmp dword [rax + VFS_TYPE_OFF], VFS_LOCAL
    jne .fb_loop
    jmp .out
.none:
    xor eax, eax
.out:
    pop r12
    pop rbx
    ret

; vfs_open_dir(path, path_len) -> rax handle*
vfs_open_dir:
    push rbx
    push r12
    mov rbx, rdi
    mov r12d, esi
    mov rdi, rbx
    mov esi, r12d
    call vfs_get_provider
    test rax, rax
    jz .fail
    mov r9, [rax + VFS_FN_OPEN_DIR_OFF]
    test r9, r9
    jz .fail
    mov rdi, rax
    mov rsi, rbx
    mov edx, r12d
    call r9
    pop r12
    pop rbx
    ret
.fail:
    xor eax, eax
    pop r12
    pop rbx
    ret

; vfs_read_entries(path, path_len, entries_out, max_entries) -> eax count or -1
vfs_read_entries:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, DIR_ENTRY_SIZE + 16
    mov rbx, rdi
    mov r12d, esi
    mov r13, rdx
    mov r14d, ecx

    mov rdi, rbx
    mov esi, r12d
    call vfs_get_provider
    test rax, rax
    jz .err
    mov r15, rax

    mov r9, [r15 + VFS_FN_OPEN_DIR_OFF]
    mov rdi, r15
    mov rsi, rbx
    mov edx, r12d
    call r9
    test rax, rax
    jz .err
    mov [rsp + DIR_ENTRY_SIZE], rax

    xor ebx, ebx
.next:
    cmp ebx, r14d
    jae .done
    mov r9, [r15 + VFS_FN_READ_ENTRY_OFF]
    mov rdi, r15
    mov rsi, [rsp + DIR_ENTRY_SIZE]
    lea rdx, [rsp]
    call r9
    cmp eax, 1
    je .copy
    cmp eax, 0
    je .done
    jmp .err_close
.copy:
    mov eax, ebx
    imul eax, DIR_ENTRY_SIZE
    lea rdi, [r13 + rax]
    lea rsi, [rsp]
    mov ecx, DIR_ENTRY_SIZE
    rep movsb
    inc ebx
    jmp .next

.done:
    mov r9, [r15 + VFS_FN_CLOSE_DIR_OFF]
    mov rdi, r15
    mov rsi, [rsp + DIR_ENTRY_SIZE]
    call r9
    mov eax, ebx
    add rsp, DIR_ENTRY_SIZE + 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

.err_close:
    mov r9, [r15 + VFS_FN_CLOSE_DIR_OFF]
    mov rdi, r15
    mov rsi, [rsp + DIR_ENTRY_SIZE]
    call r9
.err:
    mov eax, -1
    add rsp, DIR_ENTRY_SIZE + 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; helpers for single-dispatch calls
%macro VFS_DISPATCH3 4
    ; name(path,len,arg3) -> provider fn offset
    push rbx
    mov rbx, rdi
    mov rdi, rbx
    call vfs_get_provider
    test rax, rax
    jz %%fail
    mov r9, [rax + %4]
    test r9, r9
    jz %%fail
    mov rdi, rax
    mov rsi, rbx
    call r9
    pop rbx
    ret
%%fail:
    mov eax, -1
    pop rbx
    ret
%endmacro

; vfs_stat(path, path_len, stat_out)
vfs_stat:
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12d, esi
    mov r13, rdx
    mov rdi, rbx
    mov esi, r12d
    call vfs_get_provider
    test rax, rax
    jz .stat_fail
    mov r9, [rax + VFS_FN_STAT_OFF]
    test r9, r9
    jz .stat_fail
    mov rdi, rax
    mov rsi, rbx
    mov edx, r12d
    mov rcx, r13
    call r9
    pop r13
    pop r12
    pop rbx
    ret
.stat_fail:
    mov eax, -1
    pop r13
    pop r12
    pop rbx
    ret

; vfs_read_file(path,path_len,buf,max_len)
vfs_read_file:
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdi
    mov r12d, esi
    mov r13, rdx
    mov r14, rcx
    mov rdi, rbx
    mov esi, r12d
    call vfs_get_provider
    test rax, rax
    jz .rf_fail
    mov r9, [rax + VFS_FN_READ_FILE_OFF]
    test r9, r9
    jz .rf_fail
    mov rdi, rax
    mov rsi, rbx
    mov edx, r12d
    mov rcx, r13
    mov r8, r14
    call r9
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.rf_fail:
    mov eax, -1
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; vfs_write_file(path,path_len,buf,len,flags)
vfs_write_file:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi
    mov r12d, esi
    mov r13, rdx                        ; buf
    mov r14, rcx                        ; len
    mov r15, r8                         ; flags
    mov rdi, rbx
    mov esi, r12d
    call vfs_get_provider
    test rax, rax
    jz .wf_fail
    mov r11, [rax + VFS_FN_WRITE_FILE_OFF]
    test r11, r11
    jz .wf_fail
    mov rdi, rax
    mov rsi, rbx
    mov edx, r12d
    mov rcx, r13
    mov r8, r14
    mov r9, r15
    call r11
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.wf_fail:
    mov eax, -1
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; vfs_mkdir(path,path_len,mode)
vfs_mkdir:
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12d, esi
    mov r13d, edx
    mov rdi, rbx
    mov esi, r12d
    call vfs_get_provider
    test rax, rax
    jz .mk_fail
    mov r9, [rax + VFS_FN_MKDIR_OFF]
    test r9, r9
    jz .mk_fail
    mov rdi, rax
    mov rsi, rbx
    mov edx, r12d
    mov ecx, r13d
    call r9
    pop r13
    pop r12
    pop rbx
    ret
.mk_fail:
    mov eax, -1
    pop r13
    pop r12
    pop rbx
    ret

; vfs_rmdir(path,path_len)
vfs_rmdir:
    push rbx
    push r12
    mov rbx, rdi
    mov r12d, esi
    mov rdi, rbx
    mov esi, r12d
    call vfs_get_provider
    test rax, rax
    jz .rd_fail
    mov r9, [rax + VFS_FN_RMDIR_OFF]
    test r9, r9
    jz .rd_fail
    mov rdi, rax
    mov rsi, rbx
    mov edx, r12d
    call r9
    pop r12
    pop rbx
    ret
.rd_fail:
    mov eax, -1
    pop r12
    pop rbx
    ret

; vfs_unlink(path,path_len)
vfs_unlink:
    push rbx
    push r12
    mov rbx, rdi
    mov r12d, esi
    mov rdi, rbx
    mov esi, r12d
    call vfs_get_provider
    test rax, rax
    jz .ul_fail
    mov r9, [rax + VFS_FN_UNLINK_OFF]
    test r9, r9
    jz .ul_fail
    mov rdi, rax
    mov rsi, rbx
    mov edx, r12d
    call r9
    pop r12
    pop rbx
    ret
.ul_fail:
    mov eax, -1
    pop r12
    pop rbx
    ret

; vfs_rename(old_path, old_len, new_path, new_len)
vfs_rename:
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdi
    mov r12d, esi
    mov r13, rdx
    mov r14d, ecx
    mov rdi, rbx
    mov esi, r12d
    call vfs_get_provider
    test rax, rax
    jz .rn_fail
    mov r9, [rax + VFS_FN_RENAME_OFF]
    test r9, r9
    jz .rn_fail
    mov rdi, rax
    mov rsi, rbx
    mov edx, r12d
    mov rcx, r13
    mov r8d, r14d
    call r9
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.rn_fail:
    mov eax, -1
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; vfs_copy(src, src_len, dst, dst_len, progress_cb)
vfs_copy:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi
    mov r12d, esi
    mov r13, rdx
    mov r14d, ecx
    mov r15, r8
    mov rdi, rbx
    mov esi, r12d
    call vfs_get_provider
    test rax, rax
    jz .cp_fail
    mov r10, [rax + VFS_FN_COPY_OFF]
    test r10, r10
    jz .cp_fail
    mov rdi, rax
    mov rsi, rbx
    mov edx, r12d
    mov rcx, r13
    mov r8d, r14d
    mov r9, r15
    call r10
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.cp_fail:
    mov eax, -1
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
