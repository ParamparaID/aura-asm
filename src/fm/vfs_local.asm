; vfs_local.asm — Local filesystem provider
%include "src/hal/platform_defs.inc"
%include "src/fm/vfs.inc"

extern hal_open
extern hal_close
extern hal_read
extern hal_write
extern hal_getdents64
extern hal_stat
extern hal_lstat
extern hal_rename
extern hal_unlink
extern hal_rmdir
extern hal_mkdir
extern hal_chmod

%define LOCAL_MAX_HANDLES          16
%define LOCAL_DIR_BUF_SIZE         8192

; LocalDirHandle (Win64: directory HANDLE is 64-bit — store full qword at LD_FD_OFF)
%define LD_IN_USE_OFF              0
%define LD_FD_OFF                  8
%define LD_BUF_POS_OFF             16
%define LD_BUF_LEN_OFF             20
%define LD_PATH_LEN_OFF            24
%define LD_PATH_OFF                32
%define LD_BUF_OFF                 (LD_PATH_OFF + VFS_MAX_PATH)
%define LD_STRUCT_SIZE             (LD_BUF_OFF + LOCAL_DIR_BUF_SIZE)

section .rodata
    local_name db "local", 0

section .data
align 8
local_provider:
    dd VFS_LOCAL
    dd 0
    dq local_name
    dq local_open_dir
    dq local_read_entry
    dq local_close_dir
    dq local_stat
    dq local_read_file
    dq local_write_file
    dq local_mkdir
    dq local_rmdir
    dq local_unlink
    dq local_rename
    dq local_copy

section .bss
    local_handles                resb LD_STRUCT_SIZE * LOCAL_MAX_HANDLES
    local_path_tmp               resb VFS_MAX_PATH
    local_path_tmp2              resb VFS_MAX_PATH
    local_stat_tmp               resb ST_STRUCT_SIZE
    local_copy_buf               resb 65536

section .text
default rel
global local_provider_get
global local_open_dir
global local_read_entry
global local_close_dir
global local_stat
global local_read_file
global local_write_file
global local_mkdir
global local_rmdir
global local_unlink
global local_rename
global local_copy

local_provider_get:
    lea rax, [rel local_provider]
    ret

local_copy_path_to_tmp:
    ; (src_ptr, src_len, dst_ptr) -> rax dst_ptr or 0
    test rsi, rsi
    jz .ok
    cmp rsi, VFS_MAX_PATH - 1
    ja .fail
    mov rcx, rsi
    rep movsb
.ok:
    mov byte [rdi], 0
    mov rax, rdi
    ret
.fail:
    xor eax, eax
    ret

local_build_child_path:
    ; (base_ptr, base_len, name_ptr, name_len, out_ptr) -> rax out_ptr or 0
    push rbx
    push r12
    mov rbx, r8
    cmp rsi, VFS_MAX_PATH - 2
    ja .fail
    mov rdi, rbx
    mov rcx, rsi
    rep movsb
    mov r12, rdi
    cmp r12, rbx
    je .need_slash
    cmp byte [r12 - 1], '/'
    je .copy_name
.need_slash:
    mov byte [r12], '/'
    inc r12
.copy_name:
    cmp rcx, VFS_MAX_PATH - 1
    ; rcx currently 0 after rep
    mov rcx, r9
    mov rsi, rdx
    mov rdi, r12
    add rcx, r12
    sub rcx, rbx
    cmp rcx, VFS_MAX_PATH - 1
    ja .fail
    mov rcx, r9
    rep movsb
    mov byte [rdi], 0
    mov rax, rbx
    pop r12
    pop rbx
    ret
.fail:
    xor eax, eax
    pop r12
    pop rbx
    ret

local_find_handle_slot:
    xor ecx, ecx
    lea r10, [rel local_handles]
.loop:
    cmp ecx, LOCAL_MAX_HANDLES
    jae .none
    mov eax, ecx
    imul eax, LD_STRUCT_SIZE
    lea rax, [r10 + rax]
    cmp dword [rax + LD_IN_USE_OFF], 0
    je .found
    inc ecx
    jmp .loop
.found:
    ret
.none:
    xor eax, eax
    ret

; local_open_dir(provider, path, path_len) -> rax handle*
local_open_dir:
    push rbx
    push r12
    push r13
    mov r13, rsi                        ; path ptr
    mov r12d, edx
    call local_find_handle_slot
    test rax, rax
    jz .fail
    mov rbx, rax                        ; handle ptr

    mov dword [rbx + LD_IN_USE_OFF], 1
    mov dword [rbx + LD_BUF_POS_OFF], 0
    mov dword [rbx + LD_BUF_LEN_OFF], 0
    mov dword [rbx + LD_PATH_LEN_OFF], r12d
    lea rdi, [rbx + LD_PATH_OFF]
    mov rsi, r13
    mov ecx, r12d
    cmp ecx, VFS_MAX_PATH - 1
    jbe .cpy
    mov ecx, VFS_MAX_PATH - 1
.cpy:
    rep movsb
    mov byte [rdi], 0

    lea rdi, [rbx + LD_PATH_OFF]
    mov esi, O_RDONLY | O_DIRECTORY
    xor edx, edx
    call hal_open
    test rax, rax
    js .open_fail
    mov [rbx + LD_FD_OFF], rax
    mov rax, rbx
    pop r13
    pop r12
    pop rbx
    ret

.open_fail:
    mov dword [rbx + LD_IN_USE_OFF], 0
.fail:
    xor eax, eax
    pop r13
    pop r12
    pop rbx
    ret

; local_close_dir(provider, handle)
local_close_dir:
    push rbx
    mov rbx, rsi
    test rsi, rsi
    jz .out
    lea rax, [rel local_handles]
    cmp rbx, rax
    jb .out
    lea rax, [rel local_handles + LD_STRUCT_SIZE * LOCAL_MAX_HANDLES]
    cmp rbx, rax
    jae .out
    cmp dword [rbx + LD_IN_USE_OFF], 0
    je .out
    mov rdi, [rbx + LD_FD_OFF]
    call hal_close
    mov dword [rbx + LD_IN_USE_OFF], 0
.out:
    pop rbx
    ret

local_fill_entry_stat:
    ; rdi=handle, rdx=name_ptr, rcx=entry_out, r9d=name_len
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12, rcx
    mov r13, rdx

    ; copy base path to local_path_tmp
    lea rdi, [rel local_path_tmp]
    lea rsi, [rbx + LD_PATH_OFF]
    xor ecx, ecx
.bcopy:
    cmp ecx, VFS_MAX_PATH - 2
    jae .out
    mov al, [rsi + rcx]
    mov [rdi + rcx], al
    test al, al
    je .bdone
    inc ecx
    jmp .bcopy
.bdone:
    test ecx, ecx
    jz .slash
    cmp byte [rdi + rcx - 1], '/'
    je .ncopy
.slash:
    mov byte [rdi + rcx], '/'
    inc ecx
.ncopy:
    xor edx, edx
.nloop:
    cmp edx, r9d
    jae .term
    cmp ecx, VFS_MAX_PATH - 1
    jae .out
    mov al, [r13 + rdx]
    mov [rdi + rcx], al
    inc ecx
    inc edx
    jmp .nloop
.term:
    mov byte [rdi + rcx], 0

    lea rdi, [rel local_path_tmp]
    lea rsi, [rel local_stat_tmp]
    call hal_lstat
    test rax, rax
    js .out
    mov rax, [rel local_stat_tmp + ST_SIZE_OFF]
    mov [r12 + DE_SIZE_OFF], rax
    mov rax, [rel local_stat_tmp + ST_MTIME_OFF]
    mov [r12 + DE_MTIME_OFF], rax
    mov eax, [rel local_stat_tmp + ST_MODE_OFF]
    mov [r12 + DE_MODE_OFF], eax
    mov eax, [rel local_stat_tmp + ST_UID_OFF]
    mov [r12 + DE_UID_OFF], eax
    mov eax, [rel local_stat_tmp + ST_GID_OFF]
    mov [r12 + DE_GID_OFF], eax
.out:
    pop r13
    pop r12
    pop rbx
    ret

; local_read_entry(provider, handle, entry_out) -> eax 1/0/-1
local_read_entry:
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rsi
    mov r12, rdx
    test rbx, rbx
    jz .err
.refill_check:
    mov eax, [rbx + LD_BUF_POS_OFF]
    cmp eax, [rbx + LD_BUF_LEN_OFF]
    jb .parse
    mov rdi, [rbx + LD_FD_OFF]
    lea rsi, [rbx + LD_BUF_OFF]
    mov edx, LOCAL_DIR_BUF_SIZE
    call hal_getdents64
    test rax, rax
    jz .end
    js .err
    mov [rbx + LD_BUF_LEN_OFF], eax
    mov dword [rbx + LD_BUF_POS_OFF], 0

.parse:
    mov eax, [rbx + LD_BUF_POS_OFF]
    lea r13, [rbx + LD_BUF_OFF + rax]
    movzx r14d, word [r13 + 16]        ; d_reclen
    add eax, r14d
    mov [rbx + LD_BUF_POS_OFF], eax
    cmp r14d, 19
    jb .refill_check

    lea rsi, [r13 + 19]                ; d_name
    cmp byte [rsi], '.'
    jne .not_dot
    cmp byte [rsi + 1], 0
    je .refill_check
    cmp byte [rsi + 1], '.'
    jne .not_dot
    cmp byte [rsi + 2], 0
    je .refill_check
.not_dot:
    ; clear entry
    mov rdi, r12
    mov ecx, DIR_ENTRY_SIZE
    xor eax, eax
    cld
    rep stosb

    ; copy name
    lea rsi, [r13 + 19]
    lea rdi, [r12 + DE_NAME_OFF]
    xor ecx, ecx
.name_loop:
    mov al, [rsi + rcx]
    mov [rdi + rcx], al
    test al, al
    je .name_done
    inc ecx
    cmp ecx, 255
    jb .name_loop
    mov byte [rdi + rcx], 0
.name_done:
    mov [r12 + DE_NAME_LEN_OFF], ecx
    movzx eax, byte [r13 + 18]         ; d_type
    mov [r12 + DE_TYPE_OFF], eax
    cmp byte [r12 + DE_NAME_OFF], '.'
    jne .vis
    mov dword [r12 + DE_HIDDEN_OFF], 1
.vis:
    mov rdi, rbx
    lea rdx, [r12 + DE_NAME_OFF]
    mov r9d, [r12 + DE_NAME_LEN_OFF]
    mov rcx, r12
    call local_fill_entry_stat
    mov eax, 1
    jmp .out

.end:
    xor eax, eax
    jmp .out
.err:
    mov eax, -1
.out:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; local_stat(provider, path, path_len, stat_out)
local_stat:
    push rbx
    mov rbx, rcx
    lea rdi, [rel local_path_tmp]
    mov rcx, rdx
    cmp ecx, VFS_MAX_PATH - 1
    jbe .cpy
    mov ecx, VFS_MAX_PATH - 1
.cpy:
    mov rdx, rcx
    mov rsi, rsi
    rep movsb
    mov byte [rdi], 0
    lea rdi, [rel local_path_tmp]
    mov rsi, rbx
    call hal_stat
    pop rbx
    ret

; local_read_file(provider, path, path_len, buf, max_len)
local_read_file:
    push rbx
    push r12
    mov rbx, rcx
    mov r12, r8
    lea rdi, [rel local_path_tmp]
    mov rcx, rdx
    cmp ecx, VFS_MAX_PATH - 1
    jbe .rf_copy
    mov ecx, VFS_MAX_PATH - 1
.rf_copy:
    rep movsb
    mov byte [rdi], 0
    lea rdi, [rel local_path_tmp]
    xor esi, esi
    xor edx, edx
    call hal_open
    test rax, rax
    js .rf_fail
    mov ebp, eax
    movsx rdi, ebp
    mov rsi, rbx
    mov rdx, r12
    call hal_read
    mov r12, rax
    movsx rdi, ebp
    call hal_close
    mov rax, r12
    pop r12
    pop rbx
    ret
.rf_fail:
    mov rax, -1
    pop r12
    pop rbx
    ret

; local_write_file(provider, path, path_len, buf, len, flags)
local_write_file:
    push rbx
    push r12
    push r13
    mov rbx, rcx
    mov r12, r8
    mov r13, r9
    lea rdi, [rel local_path_tmp]
    mov rcx, rdx
    cmp ecx, VFS_MAX_PATH - 1
    jbe .wf_copy
    mov ecx, VFS_MAX_PATH - 1
.wf_copy:
    rep movsb
    mov byte [rdi], 0
    lea rdi, [rel local_path_tmp]
    mov esi, O_WRONLY | O_CREAT | O_TRUNC
    test r13d, r13d
    jz .wf_open
    mov esi, r13d
.wf_open:
    mov edx, 0o644
    call hal_open
    test rax, rax
    js .wf_fail
    mov ebp, eax
    movsx rdi, ebp
    mov rsi, rbx
    mov rdx, r12
    call hal_write
    mov r12, rax
    movsx rdi, ebp
    call hal_close
    mov rax, r12
    pop r13
    pop r12
    pop rbx
    ret
.wf_fail:
    mov rax, -1
    pop r13
    pop r12
    pop rbx
    ret

; local_mkdir(provider, path, path_len, mode)
local_mkdir:
    mov r8d, ecx
    lea rdi, [rel local_path_tmp]
    mov rcx, rdx
    cmp ecx, VFS_MAX_PATH - 1
    jbe .mk_copy
    mov ecx, VFS_MAX_PATH - 1
.mk_copy:
    rep movsb
    mov byte [rdi], 0
    lea rdi, [rel local_path_tmp]
    mov esi, r8d
    call hal_mkdir
    ret

; local_rmdir(provider, path, path_len)
local_rmdir:
    lea rdi, [rel local_path_tmp]
    mov rcx, rdx
    cmp ecx, VFS_MAX_PATH - 1
    jbe .rd_copy
    mov ecx, VFS_MAX_PATH - 1
.rd_copy:
    rep movsb
    mov byte [rdi], 0
    lea rdi, [rel local_path_tmp]
    call hal_rmdir
    ret

; local_unlink(provider, path, path_len)
local_unlink:
    lea rdi, [rel local_path_tmp]
    mov rcx, rdx
    cmp ecx, VFS_MAX_PATH - 1
    jbe .ul_copy
    mov ecx, VFS_MAX_PATH - 1
.ul_copy:
    rep movsb
    mov byte [rdi], 0
    lea rdi, [rel local_path_tmp]
    call hal_unlink
    ret

; local_rename(provider, old_path, old_len, new_path, new_len)
local_rename:
    push rbx
    mov rbx, rcx
    lea rdi, [rel local_path_tmp]
    mov rcx, rdx
    cmp ecx, VFS_MAX_PATH - 1
    jbe .rn_copy1
    mov ecx, VFS_MAX_PATH - 1
.rn_copy1:
    rep movsb
    mov byte [rdi], 0

    lea rdi, [rel local_path_tmp2]
    mov rsi, rbx
    mov rcx, r8
    cmp ecx, VFS_MAX_PATH - 1
    jbe .rn_copy2
    mov ecx, VFS_MAX_PATH - 1
.rn_copy2:
    rep movsb
    mov byte [rdi], 0

    lea rdi, [rel local_path_tmp]
    lea rsi, [rel local_path_tmp2]
    call hal_rename
    pop rbx
    ret

; local_copy(provider, src, src_len, dst, dst_len, progress_cb)
local_copy:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, ST_STRUCT_SIZE + 16
    mov rbx, rsi
    mov r12d, edx
    mov r13, rcx
    mov r14d, r8d
    mov r15, r9

    ; src -> tmp1
    lea rdi, [rel local_path_tmp]
    mov rsi, rbx
    mov ecx, r12d
    cmp ecx, VFS_MAX_PATH - 1
    jbe .cp1
    mov ecx, VFS_MAX_PATH - 1
.cp1:
    rep movsb
    mov byte [rdi], 0

    ; dst -> tmp2
    lea rdi, [rel local_path_tmp2]
    mov rsi, r13
    mov ecx, r14d
    cmp ecx, VFS_MAX_PATH - 1
    jbe .cp2
    mov ecx, VFS_MAX_PATH - 1
.cp2:
    rep movsb
    mov byte [rdi], 0

    ; total size + mode
    lea rdi, [rel local_path_tmp]
    lea rsi, [rsp + 8]
    call hal_stat
    test rax, rax
    js .fail
    mov r10, [rsp + 8 + ST_SIZE_OFF]    ; total
    mov r11d, [rsp + 8 + ST_MODE_OFF]

    ; open src/dst
    lea rdi, [rel local_path_tmp]
    xor esi, esi
    xor edx, edx
    call hal_open
    test rax, rax
    js .fail
    mov ebp, eax

    lea rdi, [rel local_path_tmp2]
    mov esi, O_WRONLY | O_CREAT | O_TRUNC
    mov edx, 0o644
    call hal_open
    test rax, rax
    js .fail_close_src
    mov r8d, eax                        ; dst fd

    xor r9, r9                           ; copied
.loop:
    movsx rdi, ebp
    lea rsi, [rel local_copy_buf]
    mov edx, 65536
    call hal_read
    test rax, rax
    jz .done
    js .fail_close_both
    mov r12, rax
    movsx rdi, r8d
    lea rsi, [rel local_copy_buf]
    mov rdx, r12
    call hal_write
    cmp rax, r12
    jne .fail_close_both
    add r9, r12
    test r15, r15
    jz .loop
    mov rdi, r9
    mov rsi, r10
    xor rdx, rdx
    call r15
    jmp .loop

.done:
    ; copy mode bits
    lea rdi, [rel local_path_tmp2]
    mov esi, r11d
    call hal_chmod
    movsx rdi, r8d
    call hal_close
    movsx rdi, ebp
    call hal_close
    xor eax, eax
    jmp .out

.fail_close_both:
    movsx rdi, r8d
    call hal_close
.fail_close_src:
    movsx rdi, ebp
    call hal_close
.fail:
    mov eax, -1
.out:
    add rsp, ST_STRUCT_SIZE + 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
