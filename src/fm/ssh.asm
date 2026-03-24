; ssh.asm — minimal SSH helpers for FM (MVP exec path)
%include "src/hal/linux_x86_64/defs.inc"

extern hal_socket
extern hal_connect
extern hal_close
extern hal_read
extern hal_access
extern hal_pipe
extern hal_fork
extern hal_dup2
extern hal_execve
extern hal_waitpid
extern hal_getenv_raw
extern hal_exit

section .data
    ssh_path_usr                     db "/usr/bin/ssh",0
    ssh_path_bin                     db "/bin/ssh",0
    shell_path                       db "/bin/sh",0
    shell_arg_c                      db "-c",0

    ssh_cmd_pfx                      db "ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -p ",0
    ssh_cmd_mid                      db " ",0
    ssh_cmd_at                       db "@",0
    ssh_cmd_q                        db "'",0

section .bss
    ssh_cmd_buf                      resb 2048
    ssh_dec_tmp                      resb 16

section .text
global tcp_connect
global ssh_is_available
global ssh_exec_command

ssh_append_cstr:
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

ssh_append_dec:
    jmp ssh_append_dec_real

ssh_is_available:
    mov rdi, ssh_path_usr
    xor esi, esi                        ; F_OK
    call hal_access
    test rax, rax
    jns .yes
    mov rdi, ssh_path_bin
    xor esi, esi
    call hal_access
    test rax, rax
    jns .yes
    xor eax, eax
    ret
.yes:
    mov eax, 1
    ret

tcp_connect:
    ; (host rdi, host_len esi, port edx) -> eax fd or -1
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 32                         ; octets[4] + sockaddr
    mov r12, rdi
    mov r13d, esi
    mov r14d, edx

    ; parse dotted IPv4 into octets at [rsp+0..3]
    xor ebx, ebx                        ; current number
    xor ecx, ecx                        ; current digits
    xor edx, edx                        ; octet index
    xor esi, esi                        ; input index
.ipv4_loop:
    cmp esi, r13d
    jae .ipv4_last
    mov al, [r12 + rsi]
    cmp al, '.'
    je .ipv4_dot
    cmp al, '0'
    jb .fail
    cmp al, '9'
    ja .fail
    imul ebx, ebx, 10
    movzx eax, al
    sub eax, '0'
    add ebx, eax
    cmp ebx, 255
    ja .fail
    inc ecx
    inc esi
    jmp .ipv4_loop
.ipv4_dot:
    test ecx, ecx
    jz .fail
    cmp edx, 3
    jae .fail
    mov [rsp + rdx], bl
    inc edx
    xor ebx, ebx
    xor ecx, ecx
    inc esi
    jmp .ipv4_loop
.ipv4_last:
    test ecx, ecx
    jz .fail
    cmp edx, 3
    jne .fail
    mov [rsp + 3], bl

    mov edi, AF_INET
    mov esi, SOCK_STREAM
    xor edx, edx
    call hal_socket
    test rax, rax
    js .fail
    mov ebx, eax

    lea rdi, [rsp + 8]
    mov ecx, SOCKADDR_IN_SIZE
    xor eax, eax
    rep stosb
    mov word [rsp + 8 + SIN_FAMILY_OFF], AF_INET
    mov ax, r14w
    rol ax, 8
    mov [rsp + 8 + SIN_PORT_OFF], ax
    mov al, [rsp + 0]
    mov [rsp + 8 + SIN_ADDR_OFF + 0], al
    mov al, [rsp + 1]
    mov [rsp + 8 + SIN_ADDR_OFF + 1], al
    mov al, [rsp + 2]
    mov [rsp + 8 + SIN_ADDR_OFF + 2], al
    mov al, [rsp + 3]
    mov [rsp + 8 + SIN_ADDR_OFF + 3], al

    movsx rdi, ebx
    lea rsi, [rsp + 8]
    mov edx, SOCKADDR_IN_SIZE
    call hal_connect
    test rax, rax
    js .close_fail

    mov eax, ebx
    add rsp, 32
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

.close_fail:
    movsx rdi, ebx
    call hal_close
.fail:
    mov eax, -1
    add rsp, 32
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

ssh_append_dec_real:
    ; (dst rdi, val esi, end rdx) -> rax new dst or 0
    push rbx
    push r12
    push r13
    mov r12, rdi                        ; dst
    mov r13, rdx                        ; end
    lea rbx, [rel ssh_dec_tmp]
    xor ecx, ecx
    mov eax, esi
    test eax, eax
    jnz .cv
    mov byte [rbx], '0'
    mov ecx, 1
    jmp .cp
.cv:
    mov esi, 10
.d:
    xor edx, edx
    div esi
    add dl, '0'
    mov [rbx + rcx], dl
    inc ecx
    test eax, eax
    jnz .d
.cp:
    test ecx, ecx
    jz .ok
.cp_loop:
    cmp r12, r13
    jae .fail
    dec ecx
    mov al, [rbx + rcx]
    mov [r12], al
    inc r12
    test ecx, ecx
    jnz .cp_loop
.ok:
    mov rax, r12
    pop r13
    pop r12
    pop rbx
    ret
.fail:
    xor eax, eax
    pop r13
    pop r12
    pop rbx
    ret

ssh_exec_command:
    ; (host rdi, user rsi or 0, port edx, cmd rcx, out r8, out_max r9) -> eax bytes/-1
    push rbx
    push rbp
    push r12
    push r13
    push r14
    push r15
    sub rsp, 64                         ; pipefds[8], wait_status[4], argv[32]
    mov r12, rdi                        ; host
    mov r13, rsi                        ; user
    mov r14d, edx                       ; port
    mov r15, rcx                        ; cmd
    mov rbp, r8                         ; out
    mov ebx, r9d                        ; out_max

    call ssh_is_available
    test eax, eax
    jz .fail

    lea rdi, [rel ssh_cmd_buf]
    lea rdx, [rel ssh_cmd_buf + 2047]

    mov rsi, ssh_cmd_pfx
    call ssh_append_cstr
    test rax, rax
    jz .fail
    mov rdi, rax
    mov esi, r14d
    call ssh_append_dec_real
    test rax, rax
    jz .fail
    mov rdi, rax
    mov rsi, ssh_cmd_mid
    call ssh_append_cstr
    test rax, rax
    jz .fail
    mov rdi, rax
    test r13, r13
    jz .host
    cmp byte [r13], 0
    je .host
    mov rsi, r13
    call ssh_append_cstr
    test rax, rax
    jz .fail
    mov rdi, rax
    mov rsi, ssh_cmd_at
    call ssh_append_cstr
    test rax, rax
    jz .fail
    mov rdi, rax
.host:
    mov rsi, r12
    call ssh_append_cstr
    test rax, rax
    jz .fail
    mov rdi, rax
    mov rsi, ssh_cmd_mid
    call ssh_append_cstr
    test rax, rax
    jz .fail
    mov rdi, rax
    mov rsi, ssh_cmd_q
    call ssh_append_cstr
    test rax, rax
    jz .fail
    mov rdi, rax
    mov rsi, r15
    call ssh_append_cstr
    test rax, rax
    jz .fail
    mov rdi, rax
    mov rsi, ssh_cmd_q
    call ssh_append_cstr
    test rax, rax
    jz .fail
    cmp rax, rdx
    jae .fail
    mov byte [rax], 0

    lea rdi, [rsp + 0]                  ; int pipefd[2]
    call hal_pipe
    test rax, rax
    js .fail

    call hal_fork
    test rax, rax
    js .pipe_fail
    jz .child

    ; parent
    mov r12d, eax                       ; pid
    movsx rdi, dword [rsp + 4]          ; close write end
    call hal_close

    xor r13d, r13d                      ; total read
.rd:
    cmp r13d, ebx
    jae .rd_done
    movsx rdi, dword [rsp + 0]
    lea rsi, [rbp + r13]
    mov eax, ebx
    sub eax, r13d
    mov edx, eax
    call hal_read
    test rax, rax
    jle .rd_done
    add r13d, eax
    jmp .rd
.rd_done:
    movsx rdi, dword [rsp + 0]
    call hal_close
    mov rdi, r12
    lea rsi, [rsp + 8]
    xor edx, edx
    call hal_waitpid
    test rax, rax
    js .fail
    cmp dword [rsp + 8], 0
    jne .fail
    mov eax, r13d
    jmp .out

.child:
    ; redirect stdout/stderr -> pipe write end
    movsx rdi, dword [rsp + 0]
    call hal_close
    movsx rdi, dword [rsp + 4]
    mov esi, STDOUT
    call hal_dup2
    movsx rdi, dword [rsp + 4]
    mov esi, STDERR
    call hal_dup2
    movsx rdi, dword [rsp + 4]
    call hal_close

    mov qword [rsp + 16], shell_path
    mov qword [rsp + 24], shell_arg_c
    lea rax, [rel ssh_cmd_buf]
    mov [rsp + 32], rax
    mov qword [rsp + 40], 0

    mov rdi, shell_path
    lea rsi, [rsp + 16]
    call hal_getenv_raw
    mov rdx, rax
    call hal_execve
    mov rdi, 127
    call hal_exit
    ud2

.pipe_fail:
    movsx rdi, dword [rsp + 0]
    call hal_close
    movsx rdi, dword [rsp + 4]
    call hal_close
.fail:
    mov eax, -1
.out:
    add rsp, 64
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret
