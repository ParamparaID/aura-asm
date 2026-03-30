; vfs.asm — VFS provider registry and dispatch
%include "src/fm/vfs.inc"

extern local_provider_get
extern sftp_provider_get
extern archive_provider_get
extern plugin_api_bind_vfs_register
%ifidn __OUTPUT_FORMAT__,win64
extern win32_FindFirstFileW
extern win32_FindNextFileW
extern win32_FindClose
extern win32_WideCharToMultiByte
%endif

%ifndef DT_DIR
%define DT_DIR                  4
%endif
%ifndef DT_REG
%define DT_REG                  8
%endif
%define WIN_FINDDATA_SIZE       592
%define WIN_FINDDATA_NAME_OFF   44
%define WIN_FILE_ATTR_DIR       0x10
%define WIN_FILE_ATTR_HIDDEN    0x02
%define WIN_INVALID_HANDLE      -1
%define WIN_CP_UTF8             65001

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
    lea rdi, [rel vfs_register_provider]
    call plugin_api_bind_vfs_register
    call local_provider_get
    test rax, rax
    jz .ok
    mov rdi, rax
    call vfs_register_provider
.ok_local:
    call sftp_provider_get
    test rax, rax
    jz .ok_sftp
    mov rdi, rax
    call vfs_register_provider
.ok_sftp:
    call archive_provider_get
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
    push r13
    mov rbx, rdi
    mov r12d, esi
    xor r13d, r13d                    ; scheme len (0 => none)

    ; detect "<scheme>://"
    xor ecx, ecx
.sch_scan:
    cmp ecx, r12d
    jae .sch_done
    cmp byte [rbx + rcx], ':'
    jne .sch_next
    mov eax, ecx
    add eax, 2
    cmp eax, r12d
    jae .sch_done
    cmp byte [rbx + rcx + 1], '/'
    jne .sch_done
    cmp byte [rbx + rcx + 2], '/'
    jne .sch_done
    mov r13d, ecx
    jmp .sch_done
.sch_next:
    inc ecx
    jmp .sch_scan
.sch_done:

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
    jb .chk_zip
    cmp byte [rbx + 0], 't'
    jne .chk_zip
    cmp byte [rbx + 1], 'a'
    jne .chk_zip
    cmp byte [rbx + 2], 'r'
    jne .chk_zip
    cmp byte [rbx + 3], ':'
    jne .chk_zip
    cmp byte [rbx + 4], '/'
    jne .chk_zip
    cmp byte [rbx + 5], '/'
    jne .chk_zip
    mov edx, VFS_ARCHIVE
    jmp .search
.chk_zip:
    cmp r12d, 6
    jb .search
    cmp byte [rbx + 0], 'z'
    jne .search
    cmp byte [rbx + 1], 'i'
    jne .search
    cmp byte [rbx + 2], 'p'
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
    je .out
    ; dynamic scheme-based match for plugin providers
    test r13d, r13d
    jle .loop
    mov r8, [rax + VFS_NAME_OFF]
    test r8, r8
    jz .loop
    xor r9d, r9d
.sn_cmp:
    cmp r9d, r13d
    jae .sn_term
    mov r10b, [r8 + r9]
    cmp r10b, [rbx + r9]
    jne .loop
    inc r9d
    jmp .sn_cmp
.sn_term:
    cmp byte [r8 + r13], 0
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
    pop r13
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
%ifidn __OUTPUT_FORMAT__,win64
    ; Native Win32 directory enumeration.
    ; args: rdi=path, esi=path_len, rdx=entries_out, ecx=max_entries
    push rdi
    push rsi
    push rbx
    push r12
    push r13
    push r14
    push r15
    ; locals:
    ; [rsp + 0]    UTF-16 pattern buffer (520 WCHAR = 1040 bytes)
    ; [rsp + 1040] WIN32_FIND_DATAW (592 bytes)
    ; [rsp + 1632] find handle (qword)
    sub rsp, 1664

    mov rbx, rdi                        ; path ptr
    mov r13d, esi                       ; path len
    mov r12, rdx                        ; entries_out
    mov r14d, ecx                       ; max_entries
    xor r15d, r15d                      ; count

    test r12, r12
    jz .w_done
    test r14d, r14d
    jle .w_done

    ; Build UTF-16 "<path>\\*" pattern into local buffer.
    lea r10, [rsp]                      ; pattern ptr (WCHAR*)
    xor ecx, ecx                        ; out wchar index
    xor edx, edx                        ; in byte index
    test r13d, r13d
    jle .w_pat_default
.w_pat_copy:
    cmp edx, r13d
    jae .w_pat_copied
    cmp ecx, 516                        ; leave room for "\*"+NUL (wide)
    jae .w_pat_copied
    mov al, [rbx + rdx]
    cmp al, '/'
    jne .w_pat_store
    mov al, 92
.w_pat_store:
    movzx eax, al
    mov word [r10 + rcx*2], ax
    inc ecx
    inc edx
    jmp .w_pat_copy
.w_pat_copied:
    test ecx, ecx
    jnz .w_pat_append_star
.w_pat_default:
    mov word [r10], '.'
    mov ecx, 1
.w_pat_append_star:
    mov eax, ecx
    dec eax
    js .w_pat_need_sep
    cmp word [r10 + rax*2], 92
    je .w_pat_have_sep
.w_pat_need_sep:
    cmp ecx, 517
    jae .w_pat_have_sep
    mov word [r10 + rcx*2], 92
    inc ecx
.w_pat_have_sep:
    cmp ecx, 518
    jae .w_pat_term
    mov word [r10 + rcx*2], '*'
    inc ecx
.w_pat_term:
    mov word [r10 + rcx*2], 0

    ; FindFirstFileW(pattern, &finddata)
    lea r11, [rsp + 1040]
    mov rcx, r10
    mov rdx, r11
    mov rax, [rel win32_FindFirstFileW]
    test rax, rax
    jz .w_done
    sub rsp, 32
    call rax
    add rsp, 32
    mov [rsp + 1632], rax
    cmp rax, WIN_INVALID_HANDLE
    je .w_done

.w_enum_cur:
    lea r11, [rsp + 1040]
    lea r8, [r11 + WIN_FINDDATA_NAME_OFF] ; cFileName
    movzx eax, word [r8]
    test eax, eax
    jz .w_enum_next
    cmp eax, '.'
    jne .w_accept
    cmp word [r8 + 2], 0
    je .w_enum_next
    cmp word [r8 + 2], '.'
    jne .w_accept
    cmp word [r8 + 4], 0
    je .w_enum_next

.w_accept:
    cmp r15d, r14d
    jae .w_close

    mov eax, r15d
    imul eax, DIR_ENTRY_SIZE
    lea r9, [r12 + rax]
    mov rbx, r9

    ; Convert UTF-16 filename -> UTF-8 (max 255 bytes + NUL).
    mov rax, [rel win32_WideCharToMultiByte]
    test rax, rax
    jz .w_enum_next
    mov ecx, WIN_CP_UTF8
    xor edx, edx
    ; r8 already points to source UTF-16 name
    mov r9d, -1
    sub rsp, 64
    lea rdi, [rbx + DE_NAME_OFF]
    mov [rsp + 32], rdi
    mov dword [rsp + 40], 256
    mov qword [rsp + 48], 0
    mov qword [rsp + 56], 0
    call rax
    add rsp, 64
    mov r9, rbx
    test eax, eax
    jle .w_enum_next
    dec eax
    jns .w_name_len_ok
    xor eax, eax
.w_name_len_ok:
    mov [r9 + DE_NAME_LEN_OFF], eax

    ; Type from dwFileAttributes.
    lea r11, [rsp + 1040]
    mov eax, [r11 + 0]
    test eax, WIN_FILE_ATTR_DIR
    jz .w_type_reg
    mov dword [r9 + DE_TYPE_OFF], DT_DIR
    jmp .w_type_done
.w_type_reg:
    mov dword [r9 + DE_TYPE_OFF], DT_REG
.w_type_done:

    ; Size from nFileSizeHigh/Low.
    mov eax, [r11 + 28]
    mov edx, [r11 + 32]
    shl rdx, 32
    or rax, rdx
    mov [r9 + DE_SIZE_OFF], rax

    ; Hidden flag.
    mov eax, [r11 + 0]
    and eax, WIN_FILE_ATTR_HIDDEN
    setnz al
    movzx eax, al
    mov [r9 + DE_HIDDEN_OFF], eax

    ; Keep optional fields zero for now.
    xor eax, eax
    mov [r9 + DE_MTIME_OFF], rax
    mov dword [r9 + DE_MODE_OFF], 0
    mov dword [r9 + DE_UID_OFF], 0
    mov dword [r9 + DE_GID_OFF], 0

    inc r15d

.w_enum_next:
    mov rcx, [rsp + 1632]
    lea rdx, [rsp + 1040]
    mov rax, [rel win32_FindNextFileW]
    test rax, rax
    jz .w_close
    sub rsp, 32
    call rax
    add rsp, 32
    test eax, eax
    jnz .w_enum_cur

.w_close:
    mov rcx, [rsp + 1632]
    cmp rcx, WIN_INVALID_HANDLE
    je .w_done
    mov rax, [rel win32_FindClose]
    test rax, rax
    jz .w_done
    sub rsp, 32
    call rax
    add rsp, 32

.w_done:
    mov eax, r15d
    add rsp, 1664
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rsi
    pop rdi
    ret
%else
    jmp vfs_read_entries_full
%endif

; Legacy full implementation (kept below for Linux path)
vfs_read_entries_full:
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
    cld
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
