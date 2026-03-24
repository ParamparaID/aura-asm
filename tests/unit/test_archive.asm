; test_archive.asm — unit tests for STEP 42 archive
%include "src/hal/linux_x86_64/defs.inc"
%include "src/fm/vfs.inc"

extern hal_write
extern hal_exit
extern hal_open
extern hal_close
extern hal_read
extern hal_mkdir
extern vfs_init
extern vfs_read_entries
extern tar_create
extern tar_list
extern tar_extract
extern zip_create
extern zip_list
extern zip_extract

section .data
    root_dir         db "/tmp/aura_test_archive",0
    file_a           db "/tmp/aura_test_archive/a.txt",0
    file_b           db "/tmp/aura_test_archive/b.txt",0
    out_a            db "/tmp/aura_test_archive/out_a.txt",0
    tar_path         db "/tmp/aura_test_archive/test.tar",0
    zip_path         db "/tmp/aura_test_archive/test.zip",0
    tar_uri          db "tar:///tmp/aura_test_archive/test.tar/",0
    name_a           db "a.txt",0
    content_a        db "hello-archive-A",0
    content_b        db "hello-archive-B",0
    src_paths:
        dq file_a
        dq file_b

    pass_msg         db "ALL TESTS PASSED",10
    pass_len         equ $ - pass_msg
    fail_t1          db "FAIL: tar create/list",10
    fail_t1_len      equ $ - fail_t1
    fail_t2          db "FAIL: tar extract",10
    fail_t2_len      equ $ - fail_t2
    fail_t3          db "FAIL: zip list/extract",10
    fail_t3_len      equ $ - fail_t3
    fail_t4          db "FAIL: vfs archive dir",10
    fail_t4_len      equ $ - fail_t4

section .bss
    tar_buf          resb (1024 * 1024)
    zip_buf          resb (1024 * 1024)
    out_buf          resb 4096
    entries_buf      resb DIR_ENTRY_SIZE * 64
    zip_size_saved   resd 1

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
    mov edx, 0644o
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

read_file_small:
    ; (path_ptr rdi, out_buf rsi, out_max rdx) -> eax bytes/-1
    push rbx
    push r12
    push r13
    mov rbx, rsi
    mov r12, rdx
    mov rsi, O_RDONLY
    xor edx, edx
    call hal_open
    test rax, rax
    js .f
    mov ebp, eax
    movsx rdi, ebp
    mov rsi, rbx
    mov rdx, r12
    call hal_read
    mov r13d, eax
    movsx rdi, ebp
    call hal_close
    mov eax, r13d
    pop r13
    pop r12
    pop rbx
    ret
.f:
    mov eax, -1
    pop r13
    pop r12
    pop rbx
    ret

_start:
    ; setup
    mov rdi, root_dir
    mov rsi, 0755o
    call hal_mkdir
    mov rdi, file_a
    mov rsi, content_a
    call write_file
    mov rdi, file_b
    mov rsi, content_b
    call write_file

    ; test 1: tar create + non-empty archive
    lea rdi, [rel src_paths]
    mov esi, 2
    mov rdx, tar_path
    mov ecx, 0
    xor r8, r8
    call tar_create
    test eax, eax
    js .f1

    mov rdi, tar_path
    lea rsi, [rel tar_buf]
    mov rdx, 1024*1024
    call read_file_small
    cmp eax, 0
    jle .f1
    mov r8d, eax
    cmp r8d, 1024
    jl .f1
    lea rdi, [rel tar_buf]
    mov esi, r8d
    lea rdx, [rel entries_buf]
    mov ecx, 64
    call tar_list
    cmp eax, 2
    jl .f1

    ; test 2: tar extract file and read it
    lea rdi, [rel tar_buf]
    mov rsi, r8
    mov rdx, name_a
    mov ecx, 5
    mov r8, out_a
    mov r9d, 0
    call tar_extract
    test eax, eax
    js .f2
    mov rdi, out_a
    lea rsi, [rel out_buf]
    mov rdx, 4096
    call read_file_small
    cmp eax, 5
    jl .f2

    ; test 3: zip create/list/extract
    lea rdi, [rel src_paths]
    mov esi, 2
    mov rdx, zip_path
    xor ecx, ecx
    xor r8, r8
    call zip_create
    test eax, eax
    js .f3
    mov rdi, zip_path
    lea rsi, [rel zip_buf]
    mov rdx, 1024*1024
    call read_file_small
    cmp eax, 0
    jle .f3
    mov [zip_size_saved], eax
    lea rdi, [rel zip_buf]
    mov esi, [zip_size_saved]
    lea rdx, [rel entries_buf]
    mov ecx, 64
    call zip_list
    cmp eax, 2
    jl .f3
    lea rdi, [rel zip_buf]
    mov esi, [zip_size_saved]
    mov rdx, name_a
    mov ecx, 5
    lea r8, [rel out_buf]
    mov r9, 4096
    call zip_extract
    cmp eax, 5
    jl .f3

    ; test 4: VFS archive dir listing via tar://
    call vfs_init
    test eax, eax
    js .f4
    mov rdi, tar_uri
    call cstr_len
    mov esi, eax
    lea rdx, [rel entries_buf]
    mov ecx, 64
    mov rdi, tar_uri
    mov esi, eax
    call vfs_read_entries
    cmp eax, 2
    jl .f4

    write_stdout pass_msg, pass_len
    xor rdi, rdi
    call hal_exit

.f1:
    fail fail_t1, fail_t1_len
.f2:
    fail fail_t2, fail_t2_len
.f3:
    fail fail_t3, fail_t3_len
.f4:
    fail fail_t4, fail_t4_len
