; executor_win.asm - Windows process execution helpers (CreateProcess path)
%include "src/hal/win_x86_64/defs.inc"

extern hal_pipe
extern hal_spawn
extern hal_waitpid
extern hal_read
extern hal_close
extern hal_write

section .data
    ew_msg_fail      db "exec_pipeline_win: fail",13,10
    ew_msg_fail_len  equ $ - ew_msg_fail
    reg_cmd_prefix   db 'cmd.exe /c reg add "HKCU\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /v Shell /t REG_SZ /d "',0
    reg_cmd_suffix   db '" /f',0

section .bss
    reg_cmd_buf      resb 1024

section .text
global hal_spawn_wait
global exec_pipeline_win
global win_capture_cmd_output
global shell_replacement_register

hal_spawn_wait:
    ; (process_handle) -> exit_code or -1
    push rbx
    mov rbx, rdi
    sub rsp, 16
    mov rdi, rbx
    lea rsi, [rsp]
    xor edx, edx
    call hal_waitpid
    cmp eax, 0
    jne .fail
    mov eax, [rsp]
    add rsp, 16
    pop rbx
    ret
.fail:
    add rsp, 16
    mov eax, -1
    pop rbx
    ret

exec_pipeline_win:
    ; (cmd_ptr_array rdi, count esi) -> 0/-1
    ; MVP: sequential spawn+wait.
    push rbx
    push r12
    mov r12, rdi
    mov ebx, esi
    test r12, r12
    jz .fail
    test ebx, ebx
    jle .fail
    xor ecx, ecx
.loop:
    cmp ecx, ebx
    jae .ok
    mov rdi, [r12 + rcx*8]
    test rdi, rdi
    jz .fail
    xor rsi, rsi
    xor rdx, rdx
    call hal_spawn
    cmp rax, -1
    je .fail
    mov rdi, rax
    call hal_spawn_wait
    cmp eax, -1
    je .fail
    inc ecx
    jmp .loop
.ok:
    xor eax, eax
    pop r12
    pop rbx
    ret
.fail:
    mov rdi, 2
    lea rsi, [rel ew_msg_fail]
    mov rdx, ew_msg_fail_len
    call hal_write
    mov eax, -1
    pop r12
    pop rbx
    ret

win_capture_cmd_output:
    ; (cmdline rdi, out_buf rsi, out_max edx) -> bytes_read or -1
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12, rsi
    mov r13d, edx
    sub rsp, 16                      ; pipe [read,write] handles
    lea rdi, [rsp]
    call hal_pipe
    cmp eax, 0
    jne .fail

    ; spawn with stdout redirected to pipe write-end
    mov rdi, rbx
    xor rsi, rsi
    mov rdx, [rsp + 8]
    call hal_spawn
    cmp rax, -1
    je .cleanup
    mov r11, rax

    ; close write end in parent
    mov rdi, [rsp + 8]
    call hal_close

    ; read from pipe read end
    mov rdi, [rsp]
    mov rsi, r12
    mov edx, r13d
    call hal_read
    mov r10d, eax

    ; close read end and wait process
    mov rdi, [rsp]
    call hal_close
    mov rdi, r11
    call hal_spawn_wait
    mov eax, r10d
    jmp .out

.cleanup:
    mov rdi, [rsp]
    call hal_close
    mov rdi, [rsp + 8]
    call hal_close
.fail:
    mov eax, -1
.out:
    add rsp, 16
    pop r13
    pop r12
    pop rbx
    ret

shell_replacement_register:
    ; (exe_path cstr) -> 0/-1
    push rbx
    push r12
    mov r12, rdi
    test r12, r12
    jz .fail
    lea rbx, [rel reg_cmd_buf]
    lea rsi, [rel reg_cmd_prefix]
.cp1:
    mov al, [rsi]
    test al, al
    jz .cp_path
    mov [rbx], al
    inc rbx
    inc rsi
    jmp .cp1
.cp_path:
    mov rsi, r12
.cp2:
    mov al, [rsi]
    test al, al
    jz .cp_sfx
    mov [rbx], al
    inc rbx
    inc rsi
    jmp .cp2
.cp_sfx:
    lea rsi, [rel reg_cmd_suffix]
.cp3:
    mov al, [rsi]
    mov [rbx], al
    inc rbx
    inc rsi
    test al, al
    jnz .cp3

    lea rdi, [rel reg_cmd_buf]
    xor rsi, rsi
    xor rdx, rdx
    call hal_spawn
    cmp rax, -1
    je .fail
    mov rdi, rax
    call hal_spawn_wait
    cmp eax, -1
    je .fail
    xor eax, eax
    pop r12
    pop rbx
    ret
.fail:
    mov eax, -1
    pop r12
    pop rbx
    ret
