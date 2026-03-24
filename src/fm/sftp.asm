; sftp.asm — minimal SFTP packet helpers (MVP)
%include "src/hal/linux_x86_64/defs.inc"
%include "src/fm/vfs.inc"

%define SSH_FXP_INIT                 1
%define SSH_FXP_VERSION              2
%define SSH_FXP_OPEN                 3
%define SSH_FXP_CLOSE                4
%define SSH_FXP_READ                 5
%define SSH_FXP_WRITE                6
%define SSH_FXP_LSTAT                7
%define SSH_FXP_STAT                 9
%define SSH_FXP_OPENDIR              11
%define SSH_FXP_READDIR              12
%define SSH_FXP_REMOVE               13
%define SSH_FXP_MKDIR                14
%define SSH_FXP_RMDIR                15
%define SSH_FXP_REALPATH             16
%define SSH_FXP_RENAME               18
%define SSH_FXP_STATUS               101
%define SSH_FXP_HANDLE               102
%define SSH_FXP_DATA                 103
%define SSH_FXP_NAME                 104
%define SSH_FXP_ATTRS                105

%define SFTP_ATTR_SIZE               0x00000001
%define SFTP_ATTR_UIDGID             0x00000002
%define SFTP_ATTR_PERMISSIONS        0x00000004
%define SFTP_ATTR_ACMODTIME          0x00000008
%define SFTP_ATTR_EXTENDED           0x80000000

section .text
global sftp_parse_name
global sftp_init
global sftp_opendir
global sftp_readdir
global sftp_closedir
global sftp_stat
global sftp_open
global sftp_read
global sftp_write
global sftp_close
global sftp_mkdir
global sftp_rmdir
global sftp_remove
global sftp_rename

sftp_be32:
    ; (ptr rdi) -> eax
    mov eax, [rdi]
    bswap eax
    ret

sftp_skip_attrs:
    ; (ptr rdi, end rsi) -> rax new ptr or 0
    push rbx
    push r12
    mov r12, rdi
    lea rbx, [rdi + 4]
    cmp rbx, rsi
    ja .fail
    call sftp_be32
    mov edx, eax                        ; flags
    mov r12, rbx
    test edx, SFTP_ATTR_SIZE
    jz .uidgid
    add r12, 8
    cmp r12, rsi
    ja .fail
.uidgid:
    test edx, SFTP_ATTR_UIDGID
    jz .perm
    add r12, 8
    cmp r12, rsi
    ja .fail
.perm:
    test edx, SFTP_ATTR_PERMISSIONS
    jz .time
    add r12, 4
    cmp r12, rsi
    ja .fail
.time:
    test edx, SFTP_ATTR_ACMODTIME
    jz .ext
    add r12, 8
    cmp r12, rsi
    ja .fail
.ext:
    test edx, SFTP_ATTR_EXTENDED
    jz .ok
    lea rdi, [r12]
    call sftp_be32
    mov ecx, eax                        ; ext count
    add r12, 4
    cmp r12, rsi
    ja .fail
.ext_loop:
    test ecx, ecx
    jz .ok
    ; ext type string
    lea rdi, [r12]
    call sftp_be32
    mov ebx, eax
    add r12, 4
    add r12, rbx
    cmp r12, rsi
    ja .fail
    ; ext data string
    lea rdi, [r12]
    call sftp_be32
    mov ebx, eax
    add r12, 4
    add r12, rbx
    cmp r12, rsi
    ja .fail
    dec ecx
    jmp .ext_loop
.ok:
    mov rax, r12
    pop r12
    pop rbx
    ret
.fail:
    xor eax, eax
    pop r12
    pop rbx
    ret

sftp_parse_name:
    ; (pkt rdi, pkt_size esi, entries_out rdx, max_entries ecx) -> eax count or -1
    push rbx
    push rbp
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    mov rbx, rdi                        ; pkt
    mov r12d, esi                       ; pkt_size
    mov r13, rdx                        ; entries_out
    mov r14d, ecx                       ; max_entries
    mov dword [rsp], r14d

    cmp r12d, 13
    jb .fail
    lea rdi, [rbx]
    call sftp_be32
    mov ebp, eax                        ; payload len
    add ebp, 4
    cmp ebp, r12d
    ja .fail
    cmp byte [rbx + 4], SSH_FXP_NAME
    jne .fail
    lea rdi, [rbx + 9]
    call sftp_be32
    mov r15d, eax                       ; reported count
    mov r12d, ebp
    add r12, rbx                        ; end = pkt + 4 + payload_len
    lea rbp, [rbx + 13]                 ; cursor
    xor r14d, r14d                      ; out count
    xor ecx, ecx                        ; iter

.entry_loop:
    cmp ecx, r15d
    jae .done
    cmp rbp, r12
    jae .done

    lea rdi, [rbp]
    call sftp_be32
    mov esi, eax                        ; name_len
    add rbp, 4
    mov rax, rbp
    add rax, rsi
    cmp rax, r12
    ja .fail

    ; skip if output full, but still parse/advance
    cmp r14d, dword [rsp]
    jae .skip_store

    mov eax, r14d
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
    jbe .len_ok
    mov eax, 255
.len_ok:
    mov r9d, eax
    xor edi, edi
.cpy_name:
    cmp edi, r9d
    jae .name_done
    mov al, [rbp + rdi]
    mov [r8 + DE_NAME_OFF + rdi], al
    inc edi
    jmp .cpy_name
.name_done:
    mov byte [r8 + DE_NAME_OFF + r9], 0
    mov dword [r8 + DE_NAME_LEN_OFF], r9d
    cmp r9d, 0
    je .stored
    mov eax, r9d
    dec eax
    cmp byte [r8 + DE_NAME_OFF + rax], '/'
    jne .stored
    mov byte [r8 + DE_NAME_OFF + rax], 0
    mov dword [r8 + DE_NAME_LEN_OFF], eax
    mov dword [r8 + DE_TYPE_OFF], DT_DIR
.stored:
    inc r14d

.skip_store:
    add rbp, rsi

    ; longname
    lea rdi, [rbp]
    cmp rdi, r12
    jae .fail
    call sftp_be32
    mov esi, eax
    add rbp, 4
    add rbp, rsi
    cmp rbp, r12
    ja .fail

    ; attrs
    mov rdi, rbp
    mov rsi, r12
    call sftp_skip_attrs
    test rax, rax
    jz .fail
    mov rbp, rax

    inc ecx
    jmp .entry_loop

.done:
    mov eax, r14d
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret
.fail:
    mov eax, -1
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret

sftp_init:
    mov eax, -1
    ret
sftp_opendir:
    mov eax, -1
    ret
sftp_readdir:
    mov eax, -1
    ret
sftp_closedir:
    mov eax, -1
    ret
sftp_stat:
    mov eax, -1
    ret
sftp_open:
    mov eax, -1
    ret
sftp_read:
    mov eax, -1
    ret
sftp_write:
    mov eax, -1
    ret
sftp_close:
    mov eax, -1
    ret
sftp_mkdir:
    mov eax, -1
    ret
sftp_rmdir:
    mov eax, -1
    ret
sftp_remove:
    mov eax, -1
    ret
sftp_rename:
    mov eax, -1
    ret
