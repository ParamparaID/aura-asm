; test_ssh.asm — unit tests for STEP 43 ssh/sftp MVP
%include "src/hal/linux_x86_64/defs.inc"
%include "src/fm/vfs.inc"

extern hal_write
extern hal_exit
extern hal_close
extern tcp_connect
extern ssh_exec_command
extern sftp_parse_name
extern vfs_init
extern vfs_read_entries

section .data
    host_local      db "localhost",0
    host_127        db "127.0.0.1",0
    cmd_echo        db "echo test",0
    sftp_uri_tmp    db "sftp://localhost/tmp",0

    pass_msg        db "ALL TESTS PASSED",10
    pass_len        equ $ - pass_msg
    fail_t2         db "FAIL: ssh exec output",10
    fail_t2_len     equ $ - fail_t2
    fail_t3         db "FAIL: sftp parse name",10
    fail_t3_len     equ $ - fail_t3
    fail_t4         db "FAIL: vfs sftp init",10
    fail_t4_len     equ $ - fail_t4

    skip_t2         db "SKIP: ssh exec not available",10
    skip_t2_len     equ $ - skip_t2
    skip_t4         db "SKIP: vfs sftp integration unavailable",10
    skip_t4_len     equ $ - skip_t4

    ; SSH_FXP_NAME packet with one entry "a.txt"
    ; [len=31][type=104][id=1][count=1][name_len=5]["a.txt"][long_len=5]["a.txt"][attrs_flags=0]
    mock_name_pkt:
        db 0,0,0,31
        db 104
        db 0,0,0,1
        db 0,0,0,1
        db 0,0,0,5
        db "a.txt"
        db 0,0,0,5
        db "a.txt"
        db 0,0,0,0
    mock_name_pkt_len equ $ - mock_name_pkt

section .bss
    out_buf         resb 4096
    entries_buf     resb DIR_ENTRY_SIZE * 8

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

_start:
    ; test 1: tcp_connect should not crash (success or graceful failure)
    mov rdi, host_127
    mov esi, 9
    mov edx, 22
    call tcp_connect
    cmp eax, 0
    jl .t2
    movsx rdi, eax
    call hal_close

.t2:
    ; test 2: ssh exec via system client (skip if unavailable)
    mov rdi, host_local
    xor rsi, rsi                        ; current user
    mov edx, 22
    mov rcx, cmd_echo
    lea r8, [rel out_buf]
    mov r9d, 4096
    call ssh_exec_command
    cmp eax, 0
    jl .skip2
    cmp eax, 4
    jl .f2
    cmp byte [out_buf + 0], 't'
    jne .f2
    cmp byte [out_buf + 1], 'e'
    jne .f2
    cmp byte [out_buf + 2], 's'
    jne .f2
    cmp byte [out_buf + 3], 't'
    jne .f2
    jmp .t3
.skip2:
    write_stdout skip_t2, skip_t2_len

.t3:
    ; test 3: SFTP NAME packet parsing
    lea rdi, [rel mock_name_pkt]
    mov esi, mock_name_pkt_len
    lea rdx, [rel entries_buf]
    mov ecx, 8
    call sftp_parse_name
    cmp eax, 1
    jne .f3
    cmp dword [entries_buf + DE_NAME_LEN_OFF], 5
    jne .f3
    cmp byte [entries_buf + DE_NAME_OFF + 0], 'a'
    jne .f3

    ; test 4: VFS SFTP integration (skip if unavailable)
    call vfs_init
    test eax, eax
    js .f4
    mov rdi, sftp_uri_tmp
    call cstr_len
    mov esi, eax
    lea rdx, [rel entries_buf]
    mov ecx, 8
    mov rdi, sftp_uri_tmp
    call vfs_read_entries
    cmp eax, 0
    jl .skip4
    jmp .ok
.skip4:
    write_stdout skip_t4, skip_t4_len
    jmp .ok

.ok:
    write_stdout pass_msg, pass_len
    xor rdi, rdi
    call hal_exit

.f2:
    fail fail_t2, fail_t2_len
.f3:
    fail fail_t3, fail_t3_len
.f4:
    fail fail_t4, fail_t4_len
