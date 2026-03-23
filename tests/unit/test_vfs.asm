; test_vfs.asm — unit tests for Phase 4 STEP 40
%include "src/hal/linux_x86_64/defs.inc"
%include "src/fm/vfs.inc"

extern hal_write
extern hal_exit
extern hal_open
extern hal_close
extern hal_read
extern hal_access
extern hal_mkdir
extern hal_unlink
extern hal_rmdir
extern vfs_init
extern vfs_path_len
extern vfs_read_entries
extern vfs_stat
extern op_copy
extern op_delete
extern op_compare_dirs
extern search_by_name

%define SEARCH_PATH_MAX 512

section .data
    root_path       db "/tmp/aura_test_vfs", 0
    src_file        db "/tmp/aura_test_vfs/src.txt", 0
    dst_file        db "/tmp/aura_test_vfs/dst.txt", 0
    dir_a           db "/tmp/aura_test_vfs/dir_a", 0
    dir_b           db "/tmp/aura_test_vfs/dir_b", 0
    dir_a_file      db "/tmp/aura_test_vfs/dir_a/a.txt", 0
    dir_a_sub       db "/tmp/aura_test_vfs/dir_a/sub", 0
    dir_a_sub_file  db "/tmp/aura_test_vfs/dir_a/sub/deep.txt", 0
    dir_copy        db "/tmp/aura_test_vfs/dir_copy", 0
    dir_copy_deep   db "/tmp/aura_test_vfs/dir_copy/sub/deep.txt", 0
    left_dir        db "/tmp/aura_test_vfs/left", 0
    right_dir       db "/tmp/aura_test_vfs/right", 0
    left_only       db "/tmp/aura_test_vfs/left/only_left.txt", 0
    right_only      db "/tmp/aura_test_vfs/right/only_right.txt", 0
    same_left       db "/tmp/aura_test_vfs/left/same.txt", 0
    same_right      db "/tmp/aura_test_vfs/right/same.txt", 0
    pattern_txt     db "*.txt", 0

    content_src     db "hello-vfs", 0
    content_same    db "same-content", 0

    pass_msg        db "ALL TESTS PASSED", 10
    pass_len        equ $ - pass_msg
    fail_t1         db "FAIL: t1 readdir", 10
    fail_t1_len     equ $ - fail_t1
    fail_t2         db "FAIL: t2 stat", 10
    fail_t2_len     equ $ - fail_t2
    fail_t3         db "FAIL: t3 copy file", 10
    fail_t3_len     equ $ - fail_t3
    fail_t4         db "FAIL: t4 copy dir recursive", 10
    fail_t4_len     equ $ - fail_t4
    fail_t5         db "FAIL: t5 delete recursive", 10
    fail_t5_len     equ $ - fail_t5
    fail_t6         db "FAIL: t6 search by name", 10
    fail_t6_len     equ $ - fail_t6
    fail_t7         db "FAIL: t7 compare dirs", 10
    fail_t7_len     equ $ - fail_t7

section .bss
    entries_buf      resb DIR_ENTRY_SIZE * 64
    stat_buf         resb ST_STRUCT_SIZE
    read_buf         resb 64
    cmp_buf          resb CMP_ENTRY_SIZE * 32
    res_buf          resb SEARCH_PATH_MAX * 64
    cancel_flag      resd 1

section .text
global _start

%macro write_stdout 2
    mov rdi, STDOUT
    lea rsi, [rel %1]
    mov rdx, %2
    call hal_write
%endmacro

%macro fail 2
    write_stdout %1, %2
    mov rdi, 1
    call hal_exit
%endmacro

cstr_len:
    xor eax, eax
.l:
    cmp byte [rdi + rax], 0
    je .o
    inc eax
    jmp .l
.o:
    ret

write_file:
    ; (path_ptr, content_ptr)
    push rbx
    push r12
    mov rbx, rdi
    mov r12, rsi
    mov rdi, rbx
    mov esi, O_WRONLY | O_CREAT | O_TRUNC
    mov edx, 0o644
    call hal_open
    test rax, rax
    js .f
    mov ebx, eax
    mov rdi, r12
    call cstr_len
    mov edx, eax
    movsx rdi, ebx
    mov rsi, r12
    call hal_write
    movsx rdi, ebx
    call hal_close
    xor eax, eax
    pop r12
    pop rbx
    ret
.f:
    mov eax, -1
    pop r12
    pop rbx
    ret

mkdir_p:
    ; (path_ptr)
    mov rsi, 0o755
    call hal_mkdir
    ret

exists_path:
    ; (path_ptr) -> eax 1/0
    mov esi, F_OK
    call hal_access
    test eax, eax
    jnz .no
    mov eax, 1
    ret
.no:
    xor eax, eax
    ret

cleanup_tree:
    ; best-effort cleanup of known paths
    lea rdi, [rel dir_copy]
    mov esi, 1
    call op_delete
    lea rdi, [rel dir_a]
    mov esi, 1
    call op_delete
    lea rdi, [rel dir_b]
    mov esi, 1
    call op_delete
    lea rdi, [rel left_dir]
    mov esi, 1
    call op_delete
    lea rdi, [rel right_dir]
    mov esi, 1
    call op_delete
    lea rdi, [rel src_file]
    call hal_unlink
    lea rdi, [rel dst_file]
    call hal_unlink
    lea rdi, [rel root_path]
    call hal_rmdir
    ret

_start:
    call cleanup_tree

    call vfs_init
    lea rdi, [rel root_path]
    call mkdir_p
    lea rdi, [rel dir_a]
    call mkdir_p
    lea rdi, [rel dir_b]
    call mkdir_p
    lea rdi, [rel dir_a_sub]
    call mkdir_p
    lea rdi, [rel left_dir]
    call mkdir_p
    lea rdi, [rel right_dir]
    call mkdir_p

    lea rdi, [rel src_file]
    lea rsi, [rel content_src]
    call write_file
    lea rdi, [rel dir_a_file]
    lea rsi, [rel content_src]
    call write_file
    lea rdi, [rel dir_a_sub_file]
    lea rsi, [rel content_src]
    call write_file
    lea rdi, [rel left_only]
    lea rsi, [rel content_src]
    call write_file
    lea rdi, [rel right_only]
    lea rsi, [rel content_src]
    call write_file
    lea rdi, [rel same_left]
    lea rsi, [rel content_same]
    call write_file
    lea rdi, [rel same_right]
    lea rsi, [rel content_same]
    call write_file

    ; TEST 1: readdir count >= 4
    lea rdi, [rel root_path]
    call cstr_len
    mov esi, eax
    lea rdx, [rel entries_buf]
    mov ecx, 64
    lea rdi, [rel root_path]
    call vfs_read_entries
    cmp eax, 4
    jl .f1

    ; TEST 2: stat size/type for src.txt
    lea rdi, [rel src_file]
    call cstr_len
    mov esi, eax
    lea rdx, [rel stat_buf]
    lea rdi, [rel src_file]
    call vfs_stat
    test eax, eax
    js .f2
    mov rax, [rel stat_buf + ST_SIZE_OFF]
    cmp rax, 9
    jne .f2
    mov eax, [rel stat_buf + ST_MODE_OFF]
    and eax, S_IFMT
    cmp eax, S_IFREG
    jne .f2

    ; TEST 3: copy file src->dst
    mov dword [rel cancel_flag], 0
    lea rdi, [rel src_file]
    lea rsi, [rel dst_file]
    mov edx, 0
    xor ecx, ecx
    lea r8, [rel cancel_flag]
    call op_copy
    test eax, eax
    js .f3
    lea rdi, [rel dst_file]
    call exists_path
    test eax, eax
    jz .f3

    ; TEST 4: copy dir recursive
    lea rdi, [rel dir_a]
    lea rsi, [rel dir_copy]
    mov edx, 1
    xor ecx, ecx
    lea r8, [rel cancel_flag]
    call op_copy
    test eax, eax
    js .f4
    ; verify deep file exists
    lea rdi, [rel dir_copy_deep]
    call exists_path
    test eax, eax
    jz .f4

    ; TEST 5: delete recursive
    lea rdi, [rel dir_copy]
    mov esi, 1
    call op_delete
    lea rdi, [rel dir_copy]
    call exists_path
    test eax, eax
    jnz .f5

    ; TEST 6: search_by_name *.txt
    lea rdi, [rel root_path]
    lea rsi, [rel pattern_txt]
    mov edx, 5
    lea rcx, [rel res_buf]
    mov r8d, 64
    lea r9, [rel cancel_flag]
    call search_by_name
    cmp eax, 5
    jl .f6

    ; TEST 7: compare dirs
    lea rdi, [rel left_dir]
    lea rsi, [rel right_dir]
    lea rdx, [rel cmp_buf]
    call op_compare_dirs
    cmp eax, 3
    jl .f7

    call cleanup_tree
    write_stdout pass_msg, pass_len
    xor edi, edi
    call hal_exit

.f1:
    fail fail_t1, fail_t1_len
.f2:
    fail fail_t2, fail_t2_len
.f3:
    fail fail_t3, fail_t3_len
.f4:
    fail fail_t4, fail_t4_len
.f5:
    fail fail_t5, fail_t5_len
.f6:
    fail fail_t6, fail_t6_len
.f7:
    fail fail_t7, fail_t7_len
