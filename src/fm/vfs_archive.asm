; vfs_archive.asm — archive-backed VFS provider (tar://, zip://)
%include "src/hal/platform_defs.inc"
%include "src/fm/vfs.inc"

extern hal_open
extern hal_close
extern hal_read
extern hal_lseek
extern hal_mmap
extern hal_munmap
extern tar_list
extern zip_list

%define SEEK_SET                    0
%define SEEK_END                    2
%define ARH_MAX_HANDLES             4

%define AH_IN_USE_OFF               0
%define AH_KIND_OFF                 4
%define AH_DATA_PTR_OFF             8
%define AH_DATA_SIZE_OFF            16
%define AH_INDEX_OFF                24
%define AH_COUNT_OFF                28
%define AH_ENTRIES_OFF              32
%define AH_STRUCT_SIZE              (32 + (DIR_ENTRY_SIZE * VFS_MAX_DIR_ENTRIES))

section .data
    archive_name                    db "archive",0
    align 8
    archive_provider:
        dd VFS_ARCHIVE
        dd 0
        dq archive_name
        dq archive_open_dir
        dq archive_read_entry
        dq archive_close_dir
        dq archive_stat
        dq archive_read_file
        dq archive_write_file
        dq archive_mkdir
        dq archive_rmdir
        dq archive_unlink
        dq archive_rename
        dq archive_copy

section .bss
    archive_handles                 resb AH_STRUCT_SIZE * ARH_MAX_HANDLES
    archive_path_tmp                resb VFS_MAX_PATH

section .text
global archive_provider_get

archive_provider_get:
    lea rax, [rel archive_provider]
    ret

archive_alloc_handle:
    xor ecx, ecx
.loop:
    cmp ecx, ARH_MAX_HANDLES
    jae .fail
    mov eax, ecx
    imul eax, AH_STRUCT_SIZE
    lea rax, [rel archive_handles + rax]
    cmp dword [rax + AH_IN_USE_OFF], 0
    je .found
    inc ecx
    jmp .loop
.found:
    mov dword [rax + AH_IN_USE_OFF], 1
    ret
.fail:
    xor eax, eax
    ret

archive_extract_archive_path:
    ; (path rdi, path_len esi) -> rax kind (1 tar /2 zip / -1), rdx archive_ptr (tmp)
    push rbx
    mov rbx, rdi
    mov eax, -1
    cmp esi, 7
    jb .fail
    mov r8d, 0
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
    mov eax, 1
    mov r8d, 6
    jmp .scan
.chk_zip:
    cmp byte [rbx + 0], 'z'
    jne .fail
    cmp byte [rbx + 1], 'i'
    jne .fail
    cmp byte [rbx + 2], 'p'
    jne .fail
    cmp byte [rbx + 3], ':'
    jne .fail
    cmp byte [rbx + 4], '/'
    jne .fail
    cmp byte [rbx + 5], '/'
    jne .fail
    mov eax, 2
    mov r8d, 6
.scan:
    mov ecx, r8d
    mov r9d, -1
.s:
    cmp ecx, esi
    jae .stop
    cmp byte [rbx + rcx], '/'
    jne .n
    mov r9d, ecx
.n:
    inc ecx
    jmp .s
.stop:
    cmp r9d, -1
    je .fail
    mov edx, r9d
    sub edx, r8d
    cmp edx, VFS_MAX_PATH - 1
    jbe .cpy
    mov edx, VFS_MAX_PATH - 1
.cpy:
    lea rdi, [rel archive_path_tmp]
    xor ecx, ecx
.cp:
    cmp ecx, edx
    jae .term
    mov r10d, r8d
    add r10d, ecx
    mov r11b, [rbx + r10]
    mov [rdi + rcx], r11b
    inc ecx
    jmp .cp
.term:
    mov byte [rdi + rcx], 0
    lea rdx, [rel archive_path_tmp]
    pop rbx
    ret
.fail:
    mov eax, -1
    xor edx, edx
    pop rbx
    ret

archive_load_file:
    ; (path rdi) -> rax ptr, rdx size
    push rbx
    sub rsp, 16
    mov rdi, rdi
    xor esi, esi
    xor edx, edx
    call hal_open
    test rax, rax
    js .fail
    mov ebx, eax
    movsx rdi, ebx
    xor esi, esi
    mov edx, SEEK_END
    call hal_lseek
    test rax, rax
    js .close_fail
    mov [rsp], rax
    movsx rdi, ebx
    xor esi, esi
    mov edx, SEEK_SET
    call hal_lseek
    xor rdi, rdi
    mov rsi, [rsp]
    mov rdx, PROT_READ | PROT_WRITE
    mov rcx, MAP_PRIVATE | MAP_ANONYMOUS
    mov r8d, -1
    xor r9, r9
    call hal_mmap
    test rax, rax
    js .close_fail
    mov [rsp + 8], rax
    movsx rdi, ebx
    mov rsi, [rsp + 8]
    mov rdx, [rsp]
    call hal_read
    movsx rdi, ebx
    call hal_close
    mov rax, [rsp + 8]
    mov rdx, [rsp]
    add rsp, 16
    pop rbx
    ret
.close_fail:
    movsx rdi, ebx
    call hal_close
.fail:
    xor eax, eax
    xor edx, edx
    add rsp, 16
    pop rbx
    ret

archive_open_dir:
    ; (provider rdi, path rsi, path_len edx) -> rax handle
    push rbx
    push r12
    push r13
    mov r12, rsi
    mov r13d, edx
    call archive_alloc_handle
    test rax, rax
    jz .fail
    mov rbx, rax
    mov rdi, rbx
    mov ecx, AH_STRUCT_SIZE
    xor eax, eax
    cld
    rep stosb
    mov dword [rbx + AH_IN_USE_OFF], 1

    mov rdi, r12
    mov esi, r13d
    call archive_extract_archive_path
    test eax, eax
    js .free_fail
    mov [rbx + AH_KIND_OFF], eax
    mov rdi, rdx
    call archive_load_file
    test rax, rax
    jz .free_fail
    mov [rbx + AH_DATA_PTR_OFF], rax
    mov [rbx + AH_DATA_SIZE_OFF], rdx
    mov rdi, rax
    mov rsi, rdx
    lea rdx, [rbx + AH_ENTRIES_OFF]
    mov ecx, VFS_MAX_DIR_ENTRIES
    cmp dword [rbx + AH_KIND_OFF], 1
    je .do_tar
    call zip_list
    jmp .set
.do_tar:
    call tar_list
.set:
    cmp eax, 0
    jl .free_mapped
    mov [rbx + AH_COUNT_OFF], eax
    mov dword [rbx + AH_INDEX_OFF], 0
    mov rax, rbx
    pop r13
    pop r12
    pop rbx
    ret
.free_mapped:
    mov rdi, [rbx + AH_DATA_PTR_OFF]
    mov rsi, [rbx + AH_DATA_SIZE_OFF]
    call hal_munmap
.free_fail:
    mov dword [rbx + AH_IN_USE_OFF], 0
.fail:
    xor eax, eax
    pop r13
    pop r12
    pop rbx
    ret

archive_read_entry:
    ; (provider rdi, handle rsi, out rdx) -> eax 1/0
    push rbx
    mov rbx, rsi
    mov ecx, [rbx + AH_INDEX_OFF]
    cmp ecx, [rbx + AH_COUNT_OFF]
    jae .end
    mov eax, ecx
    imul eax, DIR_ENTRY_SIZE
    lea rsi, [rbx + AH_ENTRIES_OFF + rax]
    mov rdi, rdx
    mov ecx, DIR_ENTRY_SIZE
    cld
    rep movsb
    inc dword [rbx + AH_INDEX_OFF]
    mov eax, 1
    pop rbx
    ret
.end:
    xor eax, eax
    pop rbx
    ret

archive_close_dir:
    ; (provider rdi, handle rsi) -> eax 0
    push rbx
    test rsi, rsi
    jz .ok
    mov rbx, rsi
    cmp dword [rbx + AH_IN_USE_OFF], 0
    je .ok
    mov rax, [rbx + AH_DATA_PTR_OFF]
    test rax, rax
    jz .mark
    mov rdi, rax
    mov rsi, [rbx + AH_DATA_SIZE_OFF]
    call hal_munmap
.mark:
    mov dword [rbx + AH_IN_USE_OFF], 0
.ok:
    xor eax, eax
    pop rbx
    ret

archive_stat:
    mov eax, -1
    ret
archive_read_file:
    mov eax, -1
    ret
archive_write_file:
    mov eax, -1
    ret
archive_mkdir:
    mov eax, -1
    ret
archive_rmdir:
    mov eax, -1
    ret
archive_unlink:
    mov eax, -1
    ret
archive_rename:
    mov eax, -1
    ret
archive_copy:
    mov eax, -1
    ret
