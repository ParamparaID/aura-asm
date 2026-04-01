; vfs_sftp.asm — SFTP provider over system ssh (MVP)
%include "src/hal/platform_defs.inc"
%include "src/fm/vfs.inc"

extern ssh_exec_command
extern ssh_is_available

%define SFTP_MAX_HANDLES            4
%define SFTP_CMD_MAX                1024
%define SFTP_OUT_MAX                65536

%define SH_IN_USE_OFF               0
%define SH_INDEX_OFF                4
%define SH_COUNT_OFF                8
%define SH_ENTRIES_OFF              16
%define SH_STRUCT_SIZE              (16 + (DIR_ENTRY_SIZE * VFS_MAX_DIR_ENTRIES))

section .data
    sftp_name                        db "sftp",0
    align 8
    sftp_provider:
        dd VFS_SFTP
        dd 0
        dq sftp_name
        dq sftp_open_dir
        dq sftp_read_entry
        dq sftp_close_dir
        dq sftp_stat
        dq sftp_read_file
        dq sftp_write_file
        dq sftp_mkdir
        dq sftp_rmdir
        dq sftp_unlink
        dq sftp_rename
        dq sftp_copy

    sftp_cmd_ls                      db "ls -1Ap '",0
    sftp_cmd_cat                     db "cat '",0
    sftp_cmd_mkdir                   db "mkdir -p '",0
    sftp_cmd_rmdir                   db "rmdir '",0
    sftp_cmd_rm                      db "rm -f '",0
    sftp_cmd_q                       db "'",0

section .bss
    sftp_handles                     resb SH_STRUCT_SIZE * SFTP_MAX_HANDLES
    sftp_uri_user                    resb 128
    sftp_uri_host                    resb 256
    sftp_uri_path                    resb VFS_MAX_PATH
    sftp_uri_port                    resd 1
    sftp_cmd_buf                     resb SFTP_CMD_MAX
    sftp_out_buf                     resb SFTP_OUT_MAX

section .text
global sftp_provider_get
global vfs_sftp_connect

sftp_provider_get:
    lea rax, [rel sftp_provider]
    ret

sftp_cstr_len:
    xor eax, eax
.l:
    cmp byte [rdi + rax], 0
    je .o
    inc eax
    jmp .l
.o:
    ret

sftp_copy_cstr:
    ; (src rdi, dst rsi, dst_max edx) -> eax copied len or -1
    test edx, edx
    jle .fail
    xor ecx, ecx
.cp:
    cmp ecx, edx
    jae .fail
    mov al, [rdi + rcx]
    mov [rsi + rcx], al
    test al, al
    jz .ok
    inc ecx
    jmp .cp
.ok:
    mov eax, ecx
    ret
.fail:
    mov eax, -1
    ret

sftp_copy_span:
    ; (src rdi, len esi, dst rdx, dst_max ecx) -> eax 0/-1
    cmp esi, 0
    jl .fail
    cmp esi, ecx
    jae .fail
    xor eax, eax
.cp:
    cmp eax, esi
    jae .term
    mov bl, [rdi + rax]
    mov [rdx + rax], bl
    inc eax
    jmp .cp
.term:
    mov byte [rdx + rax], 0
    xor eax, eax
    ret
.fail:
    mov eax, -1
    ret

sftp_parse_dec:
    ; (ptr rdi, len esi) -> eax value or -1
    xor eax, eax
    xor ecx, ecx
    cmp esi, 0
    jle .fail
.l:
    cmp ecx, esi
    jae .ok
    mov dl, [rdi + rcx]
    cmp dl, '0'
    jb .fail
    cmp dl, '9'
    ja .fail
    imul eax, eax, 10
    movzx edx, dl
    sub edx, '0'
    add eax, edx
    inc ecx
    jmp .l
.ok:
    ret
.fail:
    mov eax, -1
    ret

sftp_uri_parse:
    ; (uri cstr rdi) -> eax 0/-1, fills sftp_uri_{user,host,port,path}
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi
    cmp byte [rbx + 0], 's'
    jne .fail
    cmp byte [rbx + 1], 'f'
    jne .fail
    cmp byte [rbx + 2], 't'
    jne .fail
    cmp byte [rbx + 3], 'p'
    jne .fail
    cmp byte [rbx + 4], ':'
    jne .fail
    cmp byte [rbx + 5], '/'
    jne .fail
    cmp byte [rbx + 6], '/'
    jne .fail

    mov dword [rel sftp_uri_port], 22
    mov byte [rel sftp_uri_user], 0
    mov byte [rel sftp_uri_host], 0
    mov byte [rel sftp_uri_path], '/'
    mov byte [rel sftp_uri_path + 1], 0

    lea r12, [rbx + 7]                  ; authority start
    mov r13, r12
.find_end:
    mov al, [r13]
    test al, al
    jz .have_end
    cmp al, '/'
    je .have_end
    inc r13
    jmp .find_end
.have_end:
    ; copy path
    cmp byte [r13], '/'
    jne .path_done
    mov rdi, r13
    lea rsi, [rel sftp_uri_path]
    mov edx, VFS_MAX_PATH
    call sftp_copy_cstr
    test eax, eax
    js .fail
.path_done:
    ; find @ and : in authority span [r12, r13)
    mov r14, 0                          ; at ptr
    mov r15, 0                          ; colon ptr
    mov rax, r12
.scan:
    cmp rax, r13
    jae .split
    mov dl, [rax]
    cmp dl, '@'
    jne .chk_col
    mov r14, rax
    jmp .next
.chk_col:
    cmp dl, ':'
    jne .next
    mov r15, rax
.next:
    inc rax
    jmp .scan

.split:
    ; user (optional)
    test r14, r14
    jz .host
    mov rdi, r12
    mov rsi, r14
    sub rsi, rdi                        ; user len
    mov esi, esi
    lea rdx, [rel sftp_uri_user]
    mov ecx, 128
    call sftp_copy_span
    test eax, eax
    js .fail
    lea r12, [r14 + 1]                  ; host starts after '@'

.host:
    mov rdi, r12
    mov rsi, r13
    test r15, r15
    jz .host_len
    cmp r15, r12
    jbe .host_len
    mov rsi, r15
.host_len:
    sub rsi, rdi
    cmp esi, 0
    jle .fail
    lea rdx, [rel sftp_uri_host]
    mov ecx, 256
    call sftp_copy_span
    test eax, eax
    js .fail

    ; port (optional)
    test r15, r15
    jz .ok
    lea rdi, [r15 + 1]
    mov rsi, r13
    sub rsi, rdi
    cmp esi, 0
    jle .fail
    call sftp_parse_dec
    cmp eax, 1
    jl .fail
    cmp eax, 65535
    jg .fail
    mov [rel sftp_uri_port], eax

.ok:
    xor eax, eax
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.fail:
    mov eax, -1
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

sftp_append_cstr:
    ; (dst rdi, src rsi, end rdx) -> rax new dst or 0
    push rbx
    mov rbx, rdi
.l:
    mov al, [rsi]
    test al, al
    jz .ok
    cmp rbx, rdx
    jae .fail
    mov [rbx], al
    inc rbx
    inc rsi
    jmp .l
.ok:
    mov rax, rbx
    pop rbx
    ret
.fail:
    xor eax, eax
    pop rbx
    ret

sftp_build_cmd_1arg:
    ; (prefix rdi, arg rsi) -> rax cmd ptr or 0
    lea r8, [rel sftp_cmd_buf]
    lea r9, [rel sftp_cmd_buf + SFTP_CMD_MAX - 1]
    mov rdx, r9
    mov r10, rsi
    mov rsi, rdi
    mov rdi, r8
    call sftp_append_cstr
    test rax, rax
    jz .fail
    mov rdi, rax
    mov rsi, r10
    mov rdx, r9
    call sftp_append_cstr
    test rax, rax
    jz .fail
    mov rdi, rax
    mov rsi, sftp_cmd_q
    mov rdx, r9
    call sftp_append_cstr
    test rax, rax
    jz .fail
    mov byte [rax], 0
    lea rax, [rel sftp_cmd_buf]
    ret
.fail:
    xor eax, eax
    ret

; Fixed wrapper with explicit argument preservation.
sftp_run_uri_cmd2:
    ; (uri rdi, cmd_ptr rsi, out rdx, out_max ecx) -> eax bytes/-1
    push rbx
    push r12
    push r13
    mov r12, rsi                        ; cmd
    mov r13, rdx                        ; out
    mov ebx, ecx                        ; out_max
    call sftp_uri_parse
    test eax, eax
    js .f
    lea rdi, [rel sftp_uri_host]
    lea rsi, [rel sftp_uri_user]
    cmp byte [rsi], 0
    jne .u
    xor esi, esi
.u:
    mov edx, [rel sftp_uri_port]
    mov rcx, r12
    mov r8, r13
    mov r9d, ebx
    call ssh_exec_command
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

sftp_find_handle:
    xor ecx, ecx
.l:
    cmp ecx, SFTP_MAX_HANDLES
    jae .none
    mov eax, ecx
    imul eax, SH_STRUCT_SIZE
    lea rax, [rel sftp_handles + rax]
    cmp dword [rax + SH_IN_USE_OFF], 0
    je .ok
    inc ecx
    jmp .l
.ok:
    ret
.none:
    xor eax, eax
    ret

sftp_fill_entries_from_ls:
    ; (buf rdi, len esi, entries rdx, max ecx) -> eax count
    push rbx
    push rbp
    push r12
    push r13
    push r14
    mov rbx, rdi
    mov r12d, esi
    mov r13, rdx
    mov r14d, ecx
    xor ebp, ebp                        ; pos
    xor edx, edx                        ; out_count
.line:
    cmp ebp, r12d
    jae .done
    mov ecx, ebp                        ; start
.seek:
    cmp ebp, r12d
    jae .endline
    mov al, [rbx + rbp]
    inc ebp
    cmp al, 10
    jne .seek
.endline:
    mov eax, ebp
    sub eax, ecx
    cmp eax, 0
    jle .line
    mov esi, eax
.trim:
    cmp esi, 0
    jle .line
    mov r10d, ecx
    add r10d, esi
    dec r10d
    mov al, [rbx + r10]
    cmp al, 10
    je .tdec
    cmp al, 13
    jne .trim_ok
.tdec:
    dec esi
    jmp .trim
.trim_ok:
    cmp esi, 0
    jle .line
    cmp edx, r14d
    jae .line
    ; skip . and ..
    cmp esi, 1
    jne .chk2
    cmp byte [rbx + rcx], '.'
    je .line
.chk2:
    cmp esi, 2
    jne .store
    cmp byte [rbx + rcx], '.'
    jne .store
    cmp byte [rbx + rcx + 1], '.'
    je .line
.store:
    mov eax, edx
    imul eax, DIR_ENTRY_SIZE
    lea r8, [r13 + rax]
    mov dword [r8 + DE_TYPE_OFF], DT_REG
    mov qword [r8 + DE_SIZE_OFF], 0
    mov qword [r8 + DE_MTIME_OFF], 0
    mov dword [r8 + DE_MODE_OFF], 0
    mov dword [r8 + DE_UID_OFF], 0
    mov dword [r8 + DE_GID_OFF], 0
    mov dword [r8 + DE_HIDDEN_OFF], 0
    mov eax, esi
    cmp eax, 255
    jbe .lenok
    mov eax, 255
.lenok:
    mov edi, eax
    xor r9d, r9d
.cp:
    cmp r9d, edi
    jae .cp_done
    mov r10d, ecx
    add r10d, r9d
    mov al, [rbx + r10]
    mov [r8 + DE_NAME_OFF + r9], al
    inc r9d
    jmp .cp
.cp_done:
    mov byte [r8 + DE_NAME_OFF + rdi], 0
    mov dword [r8 + DE_NAME_LEN_OFF], edi
    cmp edi, 0
    je .inc
    mov eax, edi
    dec eax
    cmp byte [r8 + DE_NAME_OFF + rax], '/'
    jne .inc
    mov byte [r8 + DE_NAME_OFF + rax], 0
    mov dword [r8 + DE_NAME_LEN_OFF], eax
    mov dword [r8 + DE_TYPE_OFF], DT_DIR
.inc:
    inc edx
    jmp .line
.done:
    mov eax, edx
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret

vfs_sftp_connect:
    ; (host cstr rdi, port edx, user cstr rsi, password rcx) -> eax 0/-1
    ; Password is accepted for API compatibility but not used in exec-based MVP.
    call ssh_is_available
    test eax, eax
    jz .f
    xor eax, eax
    ret
.f:
    mov eax, -1
    ret

sftp_open_dir:
    ; (provider rdi, path rsi, path_len edx) -> rax handle*
    push rbx
    push r12
    mov r12, rsi
    call sftp_find_handle
    test rax, rax
    jz .fail
    mov rbx, rax
    mov dword [rbx + SH_IN_USE_OFF], 1
    mov dword [rbx + SH_INDEX_OFF], 0
    mov dword [rbx + SH_COUNT_OFF], 0

    mov rdi, sftp_cmd_ls
    lea rsi, [rel sftp_uri_path]        ; path will be filled by parser in run helper
    ; ensure path buffer corresponds to URI before command build
    mov rdi, r12
    call sftp_uri_parse
    test eax, eax
    js .free_fail
    mov rdi, sftp_cmd_ls
    lea rsi, [rel sftp_uri_path]
    call sftp_build_cmd_1arg
    test rax, rax
    jz .free_fail

    mov rdi, r12
    lea rsi, [rel sftp_cmd_buf]
    lea rdx, [rel sftp_out_buf]
    mov ecx, SFTP_OUT_MAX
    call sftp_run_uri_cmd2
    test eax, eax
    js .free_fail

    lea rdi, [rel sftp_out_buf]
    mov esi, eax
    lea rdx, [rbx + SH_ENTRIES_OFF]
    mov ecx, VFS_MAX_DIR_ENTRIES
    call sftp_fill_entries_from_ls
    mov [rbx + SH_COUNT_OFF], eax
    mov rax, rbx
    pop r12
    pop rbx
    ret
.free_fail:
    mov dword [rbx + SH_IN_USE_OFF], 0
.fail:
    xor eax, eax
    pop r12
    pop rbx
    ret

sftp_read_entry:
    ; (provider rdi, handle rsi, out rdx) -> eax 1/0
    push rbx
    mov rbx, rsi
    mov ecx, [rbx + SH_INDEX_OFF]
    cmp ecx, [rbx + SH_COUNT_OFF]
    jae .end
    mov eax, ecx
    imul eax, DIR_ENTRY_SIZE
    lea rsi, [rbx + SH_ENTRIES_OFF + rax]
    mov rdi, rdx
    mov ecx, DIR_ENTRY_SIZE
    cld
    rep movsb
    inc dword [rbx + SH_INDEX_OFF]
    mov eax, 1
    pop rbx
    ret
.end:
    xor eax, eax
    pop rbx
    ret

sftp_close_dir:
    ; (provider rdi, handle rsi) -> eax 0
    test rsi, rsi
    jz .ok
    mov dword [rsi + SH_IN_USE_OFF], 0
.ok:
    xor eax, eax
    ret

sftp_stat:
    mov eax, -1
    ret

sftp_read_file:
    ; (provider rdi, path rsi, path_len edx, buf rcx, max r8) -> eax bytes/-1
    push rbx
    push r12
    push r13
    mov r12, rsi                        ; uri
    mov r13, rcx                        ; out buf
    mov ebx, r8d                        ; max
    mov rdi, r12
    call sftp_uri_parse
    test eax, eax
    js .fail
    mov rdi, sftp_cmd_cat
    lea rsi, [rel sftp_uri_path]
    call sftp_build_cmd_1arg
    test rax, rax
    jz .fail
    mov rdi, r12
    lea rsi, [rel sftp_cmd_buf]
    mov rdx, r13
    mov ecx, ebx
    call sftp_run_uri_cmd2
    pop r13
    pop r12
    pop rbx
    ret
.fail:
    mov eax, -1
    pop r13
    pop r12
    pop rbx
    ret

sftp_write_file:
    mov eax, -1
    ret

sftp_mkdir:
    push rbx
    mov rbx, rsi
    mov rdi, rbx
    call sftp_uri_parse
    test eax, eax
    js .f
    mov rdi, sftp_cmd_mkdir
    lea rsi, [rel sftp_uri_path]
    call sftp_build_cmd_1arg
    test rax, rax
    jz .f
    mov rdi, rbx
    lea rsi, [rel sftp_cmd_buf]
    lea rdx, [rel sftp_out_buf]
    mov ecx, SFTP_OUT_MAX
    call sftp_run_uri_cmd2
    test eax, eax
    js .f
    xor eax, eax
    pop rbx
    ret
.f:
    mov eax, -1
    pop rbx
    ret

sftp_rmdir:
    push rbx
    mov rbx, rsi
    mov rdi, rbx
    call sftp_uri_parse
    test eax, eax
    js .f
    mov rdi, sftp_cmd_rmdir
    lea rsi, [rel sftp_uri_path]
    call sftp_build_cmd_1arg
    test rax, rax
    jz .f
    mov rdi, rbx
    lea rsi, [rel sftp_cmd_buf]
    lea rdx, [rel sftp_out_buf]
    mov ecx, SFTP_OUT_MAX
    call sftp_run_uri_cmd2
    test eax, eax
    js .f
    xor eax, eax
    pop rbx
    ret
.f:
    mov eax, -1
    pop rbx
    ret

sftp_unlink:
    push rbx
    mov rbx, rsi
    mov rdi, rbx
    call sftp_uri_parse
    test eax, eax
    js .f
    mov rdi, sftp_cmd_rm
    lea rsi, [rel sftp_uri_path]
    call sftp_build_cmd_1arg
    test rax, rax
    jz .f
    mov rdi, rbx
    lea rsi, [rel sftp_cmd_buf]
    lea rdx, [rel sftp_out_buf]
    mov ecx, SFTP_OUT_MAX
    call sftp_run_uri_cmd2
    test eax, eax
    js .f
    xor eax, eax
    pop rbx
    ret
.f:
    mov eax, -1
    pop rbx
    ret

sftp_rename:
    mov eax, -1
    ret

sftp_copy:
    mov eax, -1
    ret
