; operations.asm — High-level file operations over VFS
%include "src/hal/platform_defs.inc"
%include "src/fm/vfs.inc"

extern vfs_path_len
extern vfs_stat
extern vfs_open_dir
extern vfs_read_entries
extern vfs_read_file
extern vfs_write_file
extern vfs_copy
extern vfs_mkdir
extern vfs_rmdir
extern vfs_unlink
extern vfs_rename
extern local_provider_get
extern threadpool_submit

%define EXDEV_NEG               -18

section .bss
    op_entry_tmp                resb DIR_ENTRY_SIZE
    op_stat_tmp                 resb ST_STRUCT_SIZE
    op_stat_tmp2                resb ST_STRUCT_SIZE

section .text
global op_copy
global op_move
global op_delete
global op_calc_dir_size
global op_compare_dirs
global op_copy_async
global op_delete_async

op_is_dir_mode:
    ; eax=st_mode -> eax 1/0
    and eax, S_IFMT
    cmp eax, S_IFDIR
    jne .no
    mov eax, 1
    ret
.no:
    xor eax, eax
    ret

op_join_path:
    ; op_join_path(out, base_ptr, base_len, name_ptr, name_len) -> eax out_len or -1
    ; rdi out, rsi base, edx base_len, rcx name, r8d name_len
    push rbx
    push r9
    mov rbx, rdi
    mov r9, rcx
    cmp edx, VFS_MAX_PATH - 2
    ja .fail
    mov eax, edx
    add eax, r8d
    add eax, 2
    cmp eax, VFS_MAX_PATH
    ja .fail

    mov rdi, rbx
    mov rcx, rdx
    rep movsb
    mov eax, edx
    test eax, eax
    jz .add_slash
    cmp byte [rbx + rax - 1], '/'
    je .copy_name
.add_slash:
    mov byte [rbx + rax], '/'
    inc eax
.copy_name:
    mov rdi, rbx
    add rdi, rax
    mov rsi, r9
    mov ecx, r8d
    rep movsb
    add eax, r8d
    mov byte [rbx + rax], 0
    pop r9
    pop rbx
    ret
.fail:
    mov eax, -1
    pop r9
    pop rbx
    ret

; op_copy(src_path, dst_path, recursive, progress_cb, cancel_flag) -> eax 0/-1/-2(cancel)
op_copy:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, (VFS_MAX_PATH*2) + 32
    mov rbx, rdi                        ; src
    mov r12, rsi                        ; dst
    mov r13d, edx                       ; recursive
    mov r14, rcx                        ; progress_cb
    mov r15, r8                         ; cancel_flag*
    test r14, r14
    jz .stat_src
    mov edi, 5
    call r14

    ; cancel check
    test r15, r15
    jz .stat_src
    cmp dword [r15], 0
    je .stat_src
    mov eax, -2
    jmp .out

.stat_src:
    mov rdi, rbx
    call vfs_path_len
    mov esi, eax
    lea rdx, [rel op_stat_tmp]
    mov rdi, rbx
    call vfs_stat
    test eax, eax
    js .fail

    mov eax, [rel op_stat_tmp + ST_MODE_OFF]
    call op_is_dir_mode
    test eax, eax
    jz .copy_file

    cmp r13d, 0
    je .fail
    ; mkdir dst (ignore EEXIST failures, treat as ok by continuing)
    mov rdi, r12
    call vfs_path_len
    mov esi, eax
    mov edx, 0o755
    mov rdi, r12
    call vfs_mkdir

    ; iterate src entries
    mov rdi, rbx
    call vfs_path_len
    mov esi, eax
    call vfs_open_dir
    test rax, rax
    jz .fail
    mov [rsp + (VFS_MAX_PATH*2)], rax   ; dir handle

    call local_provider_get
    mov [rsp + (VFS_MAX_PATH*2) + 8], rax ; provider

.dir_loop:
    ; cancel check
    test r15, r15
    jz .read_next
    cmp dword [r15], 0
    je .read_next
    mov eax, -2
    jmp .close_dir

.read_next:
    mov r9, [rsp + (VFS_MAX_PATH*2) + 8]
    mov rdi, r9
    mov rsi, [rsp + (VFS_MAX_PATH*2)]
    lea rdx, [rel op_entry_tmp]
    mov r10, [r9 + VFS_FN_READ_ENTRY_OFF]
    call r10
    cmp eax, 1
    jne .dir_done_check

    ; src child path -> rsp[0]
    lea rdi, [rsp]
    mov rsi, rbx
    mov edx, 0
    mov rdi, rbx
    call vfs_path_len
    mov edx, eax
    lea rcx, [rel op_entry_tmp + DE_NAME_OFF]
    mov r8d, [rel op_entry_tmp + DE_NAME_LEN_OFF]
    lea rdi, [rsp]
    mov rsi, rbx
    call op_join_path
    test eax, eax
    js .fail_close_dir

    ; dst child path -> rsp[VFS_MAX_PATH]
    mov rdi, r12
    call vfs_path_len
    mov edx, eax
    lea rcx, [rel op_entry_tmp + DE_NAME_OFF]
    mov r8d, [rel op_entry_tmp + DE_NAME_LEN_OFF]
    lea rdi, [rsp + VFS_MAX_PATH]
    mov rsi, r12
    call op_join_path
    test eax, eax
    js .fail_close_dir

    ; recurse
    lea rdi, [rsp]
    lea rsi, [rsp + VFS_MAX_PATH]
    mov edx, 1
    mov rcx, r14
    mov r8, r15
    call op_copy
    test eax, eax
    js .close_dir
    jmp .dir_loop

.dir_done_check:
    cmp eax, 0
    jne .fail_close_dir
    xor eax, eax
    jmp .close_dir

.copy_file:
    ; Small-file MVP path: read source into temporary buffer and write destination.
    sub rsp, 65552
    mov rdi, rbx
    call vfs_path_len
    mov esi, eax
    lea rdx, [rsp]
    mov ecx, 65536
    mov rdi, rbx
    call vfs_read_file
    test eax, eax
    js .copy_file_fail
    mov r10d, eax
    mov rdi, r12
    call vfs_path_len
    mov esi, eax
    lea rdx, [rsp]
    mov ecx, r10d
    xor r8d, r8d
    mov rdi, r12
    call vfs_write_file
    test eax, eax
    js .copy_file_fail
    xor eax, eax
    test r14, r14
    jz .copy_file_done
    mov edi, 100
    call r14
.copy_file_done:
    add rsp, 65552
    jmp .out
.copy_file_fail:
    mov eax, -1
    add rsp, 65552
    jmp .out

.fail_close_dir:
    mov eax, -1
.close_dir:
    mov r9, [rsp + (VFS_MAX_PATH*2) + 8]
    test r9, r9
    jz .out
    mov r10, [r9 + VFS_FN_CLOSE_DIR_OFF]
    test r10, r10
    jz .out
    mov rdi, r9
    mov rsi, [rsp + (VFS_MAX_PATH*2)]
    call r10
    jmp .out

.fail:
    mov eax, -1
.out:
    add rsp, (VFS_MAX_PATH*2) + 32
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; op_move(src_path, dst_path) -> eax 0/-1
op_move:
    push rbx
    push r12
    mov rbx, rdi
    mov r12, rsi
    mov rdi, rbx
    call vfs_path_len
    mov esi, eax
    mov rdi, r12
    call vfs_path_len
    mov ecx, eax
    mov rdi, rbx
    mov rdx, r12
    call vfs_rename
    test eax, eax
    jz .ok
    cmp eax, EXDEV_NEG
    jne .out
    mov rdi, rbx
    mov rsi, r12
    mov edx, 1
    xor ecx, ecx
    xor r8d, r8d
    call op_copy
    test eax, eax
    js .out
    mov rdi, rbx
    mov esi, 1
    call op_delete
.ok:
    xor eax, eax
.out:
    pop r12
    pop rbx
    ret

; op_delete(path, recursive) -> eax 0/-1/-2(cancel)
op_delete:
    push rbx
    push r12
    push r13
    sub rsp, VFS_MAX_PATH + 32
    mov rbx, rdi
    mov r12d, esi

    mov rdi, rbx
    call vfs_path_len
    mov esi, eax
    lea rdx, [rel op_stat_tmp]
    mov rdi, rbx
    call vfs_stat
    test eax, eax
    js .fail

    mov eax, [rel op_stat_tmp + ST_MODE_OFF]
    call op_is_dir_mode
    test eax, eax
    jz .as_file
    cmp r12d, 0
    je .fail

    mov rdi, rbx
    call vfs_path_len
    mov esi, eax
    call vfs_open_dir
    test rax, rax
    jz .fail
    mov [rsp + VFS_MAX_PATH], rax
    call local_provider_get
    mov [rsp + VFS_MAX_PATH + 8], rax

.dloop:
    mov r9, [rsp + VFS_MAX_PATH + 8]
    mov rdi, r9
    mov rsi, [rsp + VFS_MAX_PATH]
    lea rdx, [rel op_entry_tmp]
    mov r10, [r9 + VFS_FN_READ_ENTRY_OFF]
    call r10
    cmp eax, 1
    jne .ddone
    mov rdi, rbx
    call vfs_path_len
    mov edx, eax
    lea rcx, [rel op_entry_tmp + DE_NAME_OFF]
    mov r8d, [rel op_entry_tmp + DE_NAME_LEN_OFF]
    lea rdi, [rsp]
    mov rsi, rbx
    call op_join_path
    test eax, eax
    js .fail_close
    lea rdi, [rsp]
    mov esi, 1
    call op_delete
    test eax, eax
    js .fail_close
    jmp .dloop

.ddone:
    mov r9, [rsp + VFS_MAX_PATH + 8]
    mov r10, [r9 + VFS_FN_CLOSE_DIR_OFF]
    mov rdi, r9
    mov rsi, [rsp + VFS_MAX_PATH]
    call r10
    mov rdi, rbx
    call vfs_path_len
    mov esi, eax
    mov rdi, rbx
    call vfs_rmdir
    jmp .out

.as_file:
    mov rdi, rbx
    call vfs_path_len
    mov esi, eax
    mov rdi, rbx
    call vfs_unlink
    jmp .out

.fail_close:
    mov r9, [rsp + VFS_MAX_PATH + 8]
    test r9, r9
    jz .fail
    mov r10, [r9 + VFS_FN_CLOSE_DIR_OFF]
    mov rdi, r9
    mov rsi, [rsp + VFS_MAX_PATH]
    call r10
.fail:
    mov eax, -1
.out:
    add rsp, VFS_MAX_PATH + 32
    pop r13
    pop r12
    pop rbx
    ret

; op_calc_dir_size(path, result_ptr, cancel_flag) -> eax 0/-1
op_calc_dir_size:
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov qword [r12], 0

    mov rdi, rbx
    call vfs_path_len
    mov esi, eax
    lea rdx, [rel op_stat_tmp]
    mov rdi, rbx
    call vfs_stat
    test eax, eax
    js .fail
    mov eax, [rel op_stat_tmp + ST_MODE_OFF]
    call op_is_dir_mode
    test eax, eax
    jz .file

    ; read top-level entries and recurse by calling op_calc_dir_size on children
    sub rsp, VFS_MAX_PATH
    mov rdi, rbx
    call vfs_path_len
    mov esi, eax
    call vfs_open_dir
    test rax, rax
    jz .fail_pop
    mov r8, rax
    call local_provider_get
    mov r9, rax
.sz_loop:
    test r13, r13
    jz .sz_read
    cmp dword [r13], 0
    jne .fail_pop
.sz_read:
    mov rdi, r9
    mov rsi, r8
    lea rdx, [rel op_entry_tmp]
    mov r10, [r9 + VFS_FN_READ_ENTRY_OFF]
    call r10
    cmp eax, 1
    jne .sz_done
    mov rdi, rbx
    call vfs_path_len
    mov edx, eax
    lea rcx, [rel op_entry_tmp + DE_NAME_OFF]
    mov r8d, [rel op_entry_tmp + DE_NAME_LEN_OFF]
    mov rdi, rsp
    mov rsi, rbx
    call op_join_path
    test eax, eax
    js .fail_pop
    mov rdi, rsp
    lea rsi, [rel op_stat_tmp2 + ST_SIZE_OFF]
    mov rdx, r13
    call op_calc_dir_size
    test eax, eax
    js .fail_pop
    add rax, [r12]
    mov [r12], rax
    jmp .sz_loop
.sz_done:
    mov r10, [r9 + VFS_FN_CLOSE_DIR_OFF]
    mov rdi, r9
    mov rsi, r8
    call r10
    add rsp, VFS_MAX_PATH
    xor eax, eax
    jmp .out
.file:
    mov rax, [rel op_stat_tmp + ST_SIZE_OFF]
    mov [r12], rax
    xor eax, eax
    jmp .out
.fail_pop:
    add rsp, VFS_MAX_PATH
.fail:
    mov eax, -1
.out:
    pop r13
    pop r12
    pop rbx
    ret

; op_compare_dirs(left, right, result_array) -> eax result_count
op_compare_dirs:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, DIR_ENTRY_SIZE * 64 * 2
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx

    mov rdi, rbx
    call vfs_path_len
    mov esi, eax
    lea rdx, [rsp]
    mov ecx, 64
    mov rdi, rbx
    call vfs_read_entries
    test eax, eax
    js .err
    mov r14d, eax

    mov rdi, r12
    call vfs_path_len
    mov esi, eax
    lea rdx, [rsp + DIR_ENTRY_SIZE*64]
    mov ecx, 64
    mov rdi, r12
    call vfs_read_entries
    test eax, eax
    js .err
    mov r15d, eax

    xor ebx, ebx
    xor r12d, r12d
.left_loop:
    cmp ebx, r14d
    jae .right_only
    mov eax, ebx
    imul eax, DIR_ENTRY_SIZE
    lea r8, [rsp + rax]
    ; find by name in right
    mov dword [rel op_entry_tmp], -1
    xor ecx, ecx
.find_r:
    cmp ecx, r15d
    jae .emit_left
    mov eax, ecx
    imul eax, DIR_ENTRY_SIZE
    lea r9, [rsp + DIR_ENTRY_SIZE*64 + rax]
    ; compare names
    lea rdi, [r8 + DE_NAME_OFF]
    lea rsi, [r9 + DE_NAME_OFF]
    mov edx, 256
.cmp_n:
    mov al, [rdi]
    cmp al, [rsi]
    jne .next_r
    test al, al
    je .same_name
    inc rdi
    inc rsi
    dec edx
    jnz .cmp_n
.same_name:
    mov [rel op_entry_tmp], ecx
    jmp .emit_left
.next_r:
    inc ecx
    jmp .find_r
.emit_left:
    mov eax, r12d
    imul eax, CMP_ENTRY_SIZE
    lea r10, [r13 + rax]
    ; copy name
    lea rdi, [r10 + CMP_NAME_OFF]
    lea rsi, [r8 + DE_NAME_OFF]
    mov ecx, 256
    rep movsb
    mov eax, [rel op_entry_tmp]
    cmp eax, -1
    jne .has_pair
    mov dword [r10 + CMP_STATUS_OFF], CMP_ONLY_LEFT
    jmp .emit_done
.has_pair:
    mov ecx, eax
    imul ecx, DIR_ENTRY_SIZE
    lea r9, [rsp + DIR_ENTRY_SIZE*64 + rcx]
    mov rax, [r8 + DE_SIZE_OFF]
    mov [r10 + CMP_SIZE_LEFT_OFF], rax
    mov rax, [r9 + DE_SIZE_OFF]
    mov [r10 + CMP_SIZE_RIGHT_OFF], rax
    mov rax, [r8 + DE_SIZE_OFF]
    cmp rax, [r9 + DE_SIZE_OFF]
    jne .diff
    mov rax, [r8 + DE_MTIME_OFF]
    cmp rax, [r9 + DE_MTIME_OFF]
    jne .diff
    mov dword [r10 + CMP_STATUS_OFF], CMP_SAME
    jmp .emit_done
.diff:
    mov dword [r10 + CMP_STATUS_OFF], CMP_DIFFERENT
.emit_done:
    inc r12d
    inc ebx
    jmp .left_loop

.right_only:
    ; entries present only in right
    xor ebx, ebx
.ro_loop:
    cmp ebx, r15d
    jae .done
    mov eax, ebx
    imul eax, DIR_ENTRY_SIZE
    lea r8, [rsp + DIR_ENTRY_SIZE*64 + rax]
    ; search in left
    xor ecx, ecx
    mov edx, 0
.find_l:
    cmp ecx, r14d
    jae .emit_ro
    mov eax, ecx
    imul eax, DIR_ENTRY_SIZE
    lea r9, [rsp + rax]
    lea rdi, [r8 + DE_NAME_OFF]
    lea rsi, [r9 + DE_NAME_OFF]
    mov eax, 256
.cmp2:
    mov dl, [rdi]
    cmp dl, [rsi]
    jne .next_l
    test dl, dl
    je .found_l
    inc rdi
    inc rsi
    dec eax
    jnz .cmp2
.found_l:
    mov edx, 1
    jmp .skip_emit
.next_l:
    inc ecx
    jmp .find_l
.emit_ro:
    mov eax, r12d
    imul eax, CMP_ENTRY_SIZE
    lea r10, [r13 + rax]
    lea rdi, [r10 + CMP_NAME_OFF]
    lea rsi, [r8 + DE_NAME_OFF]
    mov ecx, 256
    rep movsb
    mov dword [r10 + CMP_STATUS_OFF], CMP_ONLY_RIGHT
    inc r12d
.skip_emit:
    inc ebx
    jmp .ro_loop

.done:
    mov eax, r12d
    add rsp, DIR_ENTRY_SIZE * 64 * 2
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.err:
    mov eax, -1
    add rsp, DIR_ENTRY_SIZE * 64 * 2
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; async helpers use existing threadpool facade (sync in current implementation)
op_copy_async:
    ; (threadpool, task_arg_ptr) task_arg[0]=src,[8]=dst,[16]=recursive,[24]=progress,[32]=cancel
    mov rax, [rsi + 0]
    mov rdx, [rsi + 8]
    mov ecx, [rsi + 16]
    mov r8, [rsi + 24]
    mov r9, [rsi + 32]
    mov rdi, rax
    mov rsi, rdx
    mov edx, ecx
    mov rcx, r8
    mov r8, r9
    call op_copy
    ret

op_delete_async:
    ; (threadpool, task_arg_ptr) task_arg[0]=path,[8]=recursive
    mov rdi, [rsi + 0]
    mov esi, [rsi + 8]
    call op_delete
    ret
