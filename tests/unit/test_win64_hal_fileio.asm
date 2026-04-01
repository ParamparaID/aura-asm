; test_win64_hal_fileio.asm — STEP 60C: file read/write + getdents (temp dir)
%include "src/hal/win_x86_64/defs.inc"

extern bootstrap_init
extern hal_open
extern hal_close
extern hal_read
extern hal_write
extern hal_getdents64
extern hal_getenv
extern win32_ExitProcess
extern win64_call_1

section .rodata
msg_pass     db "ALL TESTS PASSED", 13, 10
msg_pass_len equ $ - msg_pass
msg_fail     db "TEST FAILED", 13, 10
msg_fail_len equ $ - msg_fail
msg_f_env    db "FAIL: TEMP", 13, 10
msg_f_env_len equ $ - msg_f_env
msg_f_rw     db "FAIL: file rw", 13, 10
msg_f_rw_len equ $ - msg_f_rw
msg_f_dir    db "FAIL: getdents", 13, 10
msg_f_dir_len equ $ - msg_f_dir

env_temp     db "TEMP", 0
mark_name    db 'a', 'u', 'r', 'a', '_', 'w', '6', '4', '_', 'f', 'i', 'o', '.', 't', 'm', 'p', 0
mark_len     equ $ - mark_name - 1

payload      db "hello hal fileio", 0
payload_len  equ $ - payload - 1

section .bss
    dir_path     resb 520
    file_path    resb 520
    read_buf     resb 256
    dents_buf    resb 8192

section .text

; rdx = ptr, r8d = len
write_stdout:
    mov edi, STDOUT
    mov rsi, rdx
    mov edx, r8d
    jmp hal_write

global _start
_start:
    sub rsp, 8
    call bootstrap_init
    cmp eax, 1
    jne .fail

    lea rdi, [rel env_temp]
    lea rsi, [rel dir_path]
    mov edx, 519
    call hal_getenv
    cmp eax, 0
    jle .fail_env
    cmp eax, 480
    ja .fail_env

    xor ecx, ecx
    lea r15, [rel dir_path]
.len0:
    cmp byte [r15 + rcx], 0
    je .got_dir_len
    inc ecx
    cmp ecx, 500
    jb .len0
    jmp .fail_env
.got_dir_len:
    test ecx, ecx
    jz .fail_env

    mov r8d, ecx
    lea rdi, [rel file_path]
    lea rsi, [rel dir_path]
    mov ecx, r8d
    rep movsb
    cmp byte [rdi - 1], '\'
    je .has_slash
    cmp byte [rdi - 1], '/'
    je .has_slash
    mov byte [rdi], '\'
    inc rdi
.has_slash:
    lea rsi, [rel mark_name]
    mov ecx, mark_len
.copy_name:
    jecxz .name_done
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    dec ecx
    jmp .copy_name
.name_done:
    mov byte [rdi], 0

    lea rdi, [rel file_path]
    mov esi, O_CREAT | O_TRUNC | O_RDWR
    xor edx, edx
    call hal_open
    cmp rax, -1
    je .fail_rw
    mov r12, rax

    mov rdi, r12
    lea rsi, [rel payload]
    mov edx, payload_len
    call hal_write
    cmp eax, payload_len
    jne .fail_rw_close
    mov rdi, r12
    call hal_close
    cmp eax, 0
    jne .fail_rw

    lea rdi, [rel file_path]
    mov esi, O_RDONLY
    xor edx, edx
    call hal_open
    cmp rax, -1
    je .fail_rw
    mov r12, rax

    mov rdi, r12
    lea rsi, [rel read_buf]
    mov edx, 255
    call hal_read
    cmp eax, payload_len
    jne .fail_rw_close2
    mov rdi, r12
    call hal_close
    cmp eax, 0
    jne .fail_rw

    lea r15, [rel read_buf]
    lea r14, [rel payload]
    xor ecx, ecx
.cmp_loop:
    cmp ecx, payload_len
    jae .cmp_ok
    mov al, [r15 + rcx]
    mov dl, [r14 + rcx]
    cmp al, dl
    jne .fail_rw
    inc ecx
    jmp .cmp_loop
.cmp_ok:

    lea rdi, [rel dir_path]
    mov esi, O_RDONLY | O_DIRECTORY
    xor edx, edx
    call hal_open
    cmp rax, -1
    je .fail_dir
    mov r12, rax

.dents_again:
    mov rdi, r12
    lea rsi, [rel dents_buf]
    mov edx, 8192
    call hal_getdents64
    cmp rax, 0
    jl .fail_dir_close
    je .fail_dir_close
    mov r13, rax
    lea r10, [rel dents_buf]
    xor ebx, ebx
.search:
    cmp rbx, r13
    jae .dents_again
    lea r15, [r10 + rbx]
    movzx r9d, word [r15 + 16]
    cmp r9w, 19
    jb .fail_dir_close
    lea rsi, [r15 + 19]
    lea rdi, [rel mark_name]
    mov ecx, mark_len
.name_cmp:
    jecxz .found_mark
    mov al, [rsi]
    mov dl, [rdi]
    cmp al, dl
    jne .next_dent
    inc rsi
    inc rdi
    dec ecx
    jmp .name_cmp
.found_mark:
    cmp byte [rsi], 0
    jne .next_dent
    jmp .dir_ok
.next_dent:
    add rbx, r9
    jmp .search
.dir_ok:

    mov rdi, r12
    call hal_close
    cmp eax, 0
    jne .fail_dir

    lea rdx, [rel msg_pass]
    mov r8d, msg_pass_len
    call write_stdout
    mov rdi, [rel win32_ExitProcess]
    xor esi, esi
    call win64_call_1

.fail_env:
    lea rdx, [rel msg_f_env]
    mov r8d, msg_f_env_len
    jmp .fail_out
.fail_rw_close2:
    mov rdi, r12
    call hal_close
    jmp .fail_rw
.fail_rw_close:
    mov rdi, r12
    call hal_close
.fail_rw:
    lea rdx, [rel msg_f_rw]
    mov r8d, msg_f_rw_len
    jmp .fail_out
.fail_dir_close:
    mov rdi, r12
    call hal_close
.fail_dir:
    lea rdx, [rel msg_f_dir]
    mov r8d, msg_f_dir_len
    jmp .fail_out
.fail:
    lea rdx, [rel msg_fail]
    mov r8d, msg_fail_len
.fail_out:
    call write_stdout
    mov rdi, [rel win32_ExitProcess]
    mov esi, 1
    call win64_call_1
