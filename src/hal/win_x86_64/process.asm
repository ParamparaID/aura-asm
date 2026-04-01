; process.asm — Win32 process HAL (CreateProcess, pipes, pipelines)
%include "src/hal/win_x86_64/defs.inc"

extern win_bootstrap_ensure
extern win32_GetStdHandle
extern win32_CreateFileA
extern win32_CreatePipe
extern win32_CreateProcessA
extern win32_CloseHandle
extern win32_SetHandleInformation
extern win32_WaitForSingleObject
extern win32_GetExitCodeProcess
extern hal_close

%define MAX_PIPELINE_CMDS       8

section .bss
align 8
    win_spawn_si                resb STARTUPINFOA_SIZE
    win_spawn_pi                resb PROCESS_INFORMATION_SIZE
    hal_pipe_sa                 resb 24
    hal_nul_stdin_cache         resq 1
    ; hal_spawn_pipeline: up to n pipes (n = cmd count), each rd+wr qwords
    pl_pairs                    resq (MAX_PIPELINE_CMDS * 2)
section .data
global hal_pipeline_stdout_read
    hal_pipeline_stdout_read    dq 0

section .rodata
    s_cmd_exe_system32         db "C:\Windows\System32\cmd.exe", 0
    path_nul                   db "NUL", 0

section .text

; Cached read handle to NUL: use as stdin when caller passes stdin=0 and a non-default stdout.
spawn_open_nul_stdin:
    mov rax, [rel hal_nul_stdin_cache]
    test rax, rax
    jnz .nul_done
    sub rsp, 64
    mov dword [rsp + 32], OPEN_EXISTING
    mov dword [rsp + 40], FILE_ATTRIBUTE_NORMAL
    mov qword [rsp + 48], 0
    lea rcx, [rel path_nul]
    mov edx, GENERIC_READ
    mov r8d, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE
    xor r9, r9
    mov rax, [rel win32_CreateFileA]
    test rax, rax
    jz .nul_fail
    call rax
    add rsp, 64
    cmp rax, -1
    je .nul_fail
    mov [rel hal_nul_stdin_cache], rax
.nul_done:
    ret
.nul_fail:
    xor eax, eax
    ret

global hal_spawn
global hal_pipe
global hal_waitpid
global hal_spawn_wait
global hal_spawn_pipeline

; --- (cmdline, stdin_h, stdout_h, stderr_h) rcx=stderr: 0 => GetStdHandle ---
hal_spawn:
    push rdi
    push rsi
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r14, rcx
    call win_bootstrap_ensure
    test eax, eax
    js .fail

    test r12, r12
    jnz .have_stdin
    ; When stdin is "default" (0) but stdout is an explicit handle (e.g. pipe write),
    ; use NUL so the child is not stuck with a console stdin that breaks pipe capture.
    test r13, r13
    jz .stdin_from_console
    call spawn_open_nul_stdin
    test rax, rax
    jz .fail
    mov r12, rax
    jmp .have_stdin
.stdin_from_console:
    mov ecx, STD_INPUT_HANDLE
    sub rsp, 40
    mov rax, [rel win32_GetStdHandle]
    call rax
    add rsp, 40
    mov r12, rax
.have_stdin:
    test r13, r13
    jnz .have_stdout
    mov ecx, STD_OUTPUT_HANDLE
    sub rsp, 40
    mov rax, [rel win32_GetStdHandle]
    call rax
    add rsp, 40
    mov r13, rax
.have_stdout:
    test r14, r14
    jnz .have_stderr
    mov ecx, STD_ERROR_HANDLE
    sub rsp, 40
    mov rax, [rel win32_GetStdHandle]
    call rax
    add rsp, 40
    mov r14, rax
.have_stderr:
    lea rdi, [rel win_spawn_si]
    mov ecx, STARTUPINFOA_SIZE
    xor eax, eax
    cld
    rep stosb
    lea rdi, [rel win_spawn_pi]
    mov ecx, PROCESS_INFORMATION_SIZE
    xor eax, eax
    rep stosb

    mov dword [rel win_spawn_si], STARTUPINFOA_SIZE
    mov dword [rel win_spawn_si + STARTUPINFOA_DWFLAGS_OFF], STARTF_USESTDHANDLES
    mov [rel win_spawn_si + STARTUPINFOA_HSTDIN_OFF], r12
    mov [rel win_spawn_si + STARTUPINFOA_HSTDOUT_OFF], r13
    mov [rel win_spawn_si + STARTUPINFOA_HSTDERR_OFF], r14

    xor rcx, rcx
    mov eax, [rbx]
    test eax, eax
    jz .cp_args_ready
    or eax, 0x20202020
    cmp eax, 0x2E646D63
    jne .cp_args_ready
    lea rcx, [rel s_cmd_exe_system32]
.cp_args_ready:
    sub rsp, 104
    mov qword [rsp + 32], 1
    mov qword [rsp + 40], 0
    mov qword [rsp + 48], 0
    mov qword [rsp + 56], 0
    lea rax, [rel win_spawn_si]
    mov [rsp + 64], rax
    lea rax, [rel win_spawn_pi]
    mov [rsp + 72], rax
    mov rdx, rbx
    xor r8, r8
    xor r9, r9
    mov rax, [rel win32_CreateProcessA]
    call rax
    test eax, eax
    jz .spawn_fail

    mov rcx, [rel win_spawn_pi + PROCINFO_HTHREAD_OFF]
    sub rsp, 32
    mov rax, [rel win32_CloseHandle]
    call rax
    add rsp, 32
    mov rax, [rel win_spawn_pi + PROCINFO_HPROCESS_OFF]
    add rsp, 104
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rsi
    pop rdi
    ret

.spawn_fail:
    add rsp, 104
.fail:
    mov rax, -1
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rsi
    pop rdi
    ret

; --- (pipefd_ptr rdi -> [0]=read [8]=write) -> 0 / -1 ---
; Clears HANDLE_FLAG_INHERIT on the read end so only the write end is inherited
; (Microsoft pattern for capturing child stdout). Pipeline code uses
; hal_pipe_both_inherit so middle segments can pass the read end as stdin.
hal_pipe:
    push rbx
    push r12
    xor r12d, r12d
    jmp hal_pipe_impl
hal_pipe_both_inherit:
    push rbx
    push r12
    mov r12d, 1
hal_pipe_impl:
    mov rbx, rdi
    call win_bootstrap_ensure
    test eax, eax
    js hal_pipe_fail
    mov rcx, rbx
    mov dword [rel hal_pipe_sa], 24
    mov qword [rel hal_pipe_sa + 8], 0
    mov dword [rel hal_pipe_sa + 16], 1
    lea rdx, [rbx + 8]
    lea r8, [rel hal_pipe_sa]
    xor r9, r9
    sub rsp, 40
    mov rax, [rel win32_CreatePipe]
    call rax
    add rsp, 40
    test eax, eax
    jz hal_pipe_fail
    test r12d, r12d
    jnz hal_pipe_done
    mov rcx, [rbx]
    mov edx, HANDLE_FLAG_INHERIT
    xor r8d, r8d
    sub rsp, 32
    mov rax, [rel win32_SetHandleInformation]
    call rax
    add rsp, 32
    test eax, eax
    jz hal_pipe_fail
hal_pipe_done:
    pop r12
    pop rbx
    xor eax, eax
    ret
hal_pipe_fail:
    pop r12
    pop rbx
    mov eax, -1
    ret

; --- (proc, status_ptr, opts) -> 0 / -1 ---
hal_waitpid:
    push rdi
    push rsi
    push rbx
    push r12
    mov rbx, rdi
    mov r12, rsi
    test rbx, rbx
    jz .fail
    call win_bootstrap_ensure
    test eax, eax
    js .fail

    mov rcx, rbx
    mov edx, INFINITE
    sub rsp, 40
    mov rax, [rel win32_WaitForSingleObject]
    call rax
    add rsp, 40
    cmp eax, 0xFFFFFFFF
    je .close_fail

    sub rsp, 48
    mov rcx, rbx
    lea rdx, [rsp + 32]
    mov rax, [rel win32_GetExitCodeProcess]
    call rax
    test eax, eax
    jz .getcode_fail

    test r12, r12
    jz .close_ok
    mov eax, [rsp + 32]
    mov [r12], eax

.close_ok:
    add rsp, 48
    mov rcx, rbx
    sub rsp, 40
    mov rax, [rel win32_CloseHandle]
    call rax
    add rsp, 40
    test eax, eax
    jz .fail
    xor eax, eax
    pop r12
    pop rbx
    pop rsi
    pop rdi
    ret

.getcode_fail:
    add rsp, 48
.close_fail:
    mov rcx, rbx
    sub rsp, 40
    mov rax, [rel win32_CloseHandle]
    call rax
    add rsp, 40
.fail:
    mov eax, -1
    pop r12
    pop rbx
    pop rsi
    pop rdi
    ret

; --- (process_handle) -> exit code or -1 ---
hal_spawn_wait:
    push rbx
    mov rbx, rdi
    sub rsp, 24
    mov rdi, rbx
    lea rsi, [rsp + 8]
    xor edx, edx
    call hal_waitpid
    cmp eax, 0
    jne .fail
    mov eax, [rsp + 8]
    add rsp, 24
    pop rbx
    ret
.fail:
    add rsp, 24
    mov eax, -1
    pop rbx
    ret

; --- (cmds[], count) -> last process handle or -1 ---
; Sets hal_pipeline_stdout_read to the read end of the capture pipe (close after read).
hal_spawn_pipeline:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp
    mov r12, rdi
    mov r13d, esi
    xor eax, eax
    mov [rel hal_pipeline_stdout_read], rax
    cmp r13d, 1
    jl .fail
    cmp r13d, MAX_PIPELINE_CMDS
    ja .fail
    test r12, r12
    jz .fail
    call win_bootstrap_ensure
    test eax, eax
    js .fail

    xor ebx, ebx
.create_pipes:
    cmp ebx, r13d
    jge .pipes_done
    lea rdi, [rel pl_pairs]
    mov eax, ebx
    shl eax, 4
    add rdi, rax
    push rbx
    mov eax, ebx
    inc eax
    cmp eax, r13d
    jl .pipe_bridge
    call hal_pipe
    jmp .pipe_after
.pipe_bridge:
    call hal_pipe_both_inherit
.pipe_after:
    pop rbx
    cmp eax, 0
    jne .fail_cleanup_partial_pipes
    inc ebx
    jmp .create_pipes

.pipes_done:
    xor ebx, ebx
    xor r15, r15
.spawn_loop:
    cmp ebx, r13d
    jge .spawn_done
    mov rdi, [r12 + rbx*8]
    test rdi, rdi
    jz .fail_cleanup_all
    test ebx, ebx
    jnz .not_first_in
    xor esi, esi
    jmp .have_in
.not_first_in:
    lea rax, [rel pl_pairs]
    mov ecx, ebx
    dec ecx
    shl ecx, 4
    add rax, rcx
    mov rsi, [rax]
.have_in:
    lea rax, [rel pl_pairs]
    mov ecx, ebx
    shl ecx, 4
    add rax, rcx
    mov rdx, [rax + 8]
    mov rcx, rdx
    call hal_spawn
    cmp rax, -1
    je .fail_cleanup_all
    test r15, r15
    jz .no_prev_proc
    mov rdi, r15
    push rbx
    push rax
    call hal_close
    pop rax
    pop rbx
.no_prev_proc:
    mov r15, rax

    lea rax, [rel pl_pairs]
    mov ecx, ebx
    shl ecx, 4
    add rax, rcx
    mov rdi, [rax + 8]
    push rbx
    call hal_close
    pop rbx
    test ebx, ebx
    jz .skip_prev_rd
    lea rax, [rel pl_pairs]
    mov ecx, ebx
    dec ecx
    shl ecx, 4
    add rax, rcx
    mov rdi, [rax]
    push rbx
    call hal_close
    pop rbx
.skip_prev_rd:
    inc ebx
    jmp .spawn_loop

.spawn_done:
    mov ecx, r13d
    dec ecx
    shl ecx, 4
    lea rax, [rel pl_pairs]
    add rax, rcx
    mov rax, [rax]
    mov [rel hal_pipeline_stdout_read], rax
    mov rax, r15
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

.fail_cleanup_partial_pipes:
    ; pipes [0, ebx) exist
    dec ebx
    js .fail
.partial_p_close:
    lea rdi, [rel pl_pairs]
    mov eax, ebx
    shl eax, 4
    add rdi, rax
    push rbx
    mov rdi, [rdi]
    call hal_close
    pop rbx
    lea rdi, [rel pl_pairs]
    mov eax, ebx
    shl eax, 4
    add rdi, rax
    push rbx
    mov rdi, [rdi + 8]
    call hal_close
    pop rbx
    dec ebx
    jns .partial_p_close
    jmp .fail

.fail_cleanup_all:
    ; Close all n pipes (both ends), last proc if any
    test r15, r15
    jz .close_pairs_only
    mov rdi, r15
    call hal_close
.close_pairs_only:
    mov ebx, r13d
    dec ebx
.cleanup_all_loop:
    js .fail
    lea rdi, [rel pl_pairs]
    mov eax, ebx
    shl eax, 4
    add rdi, rax
    push rbx
    mov rdi, [rdi]
    call hal_close
    pop rbx
    lea rdi, [rel pl_pairs]
    mov eax, ebx
    shl eax, 4
    add rdi, rax
    push rbx
    mov rdi, [rdi + 8]
    call hal_close
    pop rbx
    dec ebx
    jmp .cleanup_all_loop

.fail:
    xor eax, eax
    mov [rel hal_pipeline_stdout_read], rax
    mov rax, -1
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
