; test_win64_fm_ascii.asm — STEP 61B: FM ASCII listing (FindFirstFileA), TextOutA, navigation
%include "src/hal/win_x86_64/defs.inc"
%include "src/fm/vfs.inc"
%include "src/fm/panel.inc"

extern bootstrap_init
extern hal_open
extern hal_close
extern hal_write
extern hal_exit
extern hal_sleep_ms
extern input_queue_init
extern win32_CreateDirectoryA
extern win32_GetTickCount64
extern window_create_win32
extern window_destroy
extern window_get_canvas
extern window_present_win32
extern window_process_events
extern window_should_close
extern window_draw_text_overlay
extern vfs_init
extern panel_init
extern panel_navigate
extern panel_go_parent
extern canvas_clear

%define O_CREAT     0x0040
%define O_TRUNC     0x0200
%define O_WRONLY    0x0001

section .rodata
msg_pass     db "ALL TESTS PASSED", 13, 10
msg_pass_len equ $ - msg_pass
msg_fail     db "TEST FAILED", 13, 10
msg_fail_len equ $ - msg_fail
root_prefix  db "C:\Windows\Temp\aura_fm61b_", 0
mark_sub     db "\subdir", 0
mark_a       db "\alpha.txt", 0
mark_b       db "\beta.txt", 0
mark_inner   db "\inner.txt", 0
win_title    db "STEP 61B FM ASCII", 0
name_sub     db "subdir", 0
name_inner   db "inner.txt", 0

section .bss
root_dir     resb 520
path_tmp     resb 520
panel_path   resb 520
panel_ptr    resq 1
wnd_ptr      resq 1

section .text
global _start

; rdi dest cstr, rsi suffix cstr — append (dest must have room)
t_append:
    xor eax, eax
.find:
    cmp byte [rdi + rax], 0
    je .fnd
    inc rax
    cmp rax, 480
    jb .find
    ret
.fnd:
    add rdi, rax
.lp:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    test al, al
    jnz .lp
    ret

; rdi, rsi -> eax 0 equal
t_strcmp:
    xor eax, eax
.l:
    mov cl, [rdi + rax]
    cmp cl, [rsi + rax]
    jne .ne
    test cl, cl
    je .eq
    inc rax
    jmp .l
.ne:
    mov eax, 1
    ret
.eq:
    xor eax, eax
    ret

; rdi entry ptr, rsi name -> eax 1 if DE_NAME matches
t_entry_is:
    push rdi
    lea rdi, [rdi + DE_NAME_OFF]
    call t_strcmp
    pop rdi
    test eax, eax
    setz al
    movzx eax, al
    ret

; Append hex of rax (low 32 bits) to rdi string (at null); clobbers rax rcx rdx rsi rdi
t_append_hex8:
    push rbx
    push r12
    mov r12, rdi
    xor ecx, ecx
.len:
    cmp byte [r12 + rcx], 0
    je .le
    inc rcx
    jmp .len
.le:
    add r12, rcx
    mov ebx, 8
    mov ecx, 28
.hx:
    mov edx, eax
    shr edx, cl
    and edx, 0xF
    cmp dl, 10
    jb .d
    add dl, ('a' - 10)
    jmp .st
.d:
    add dl, '0'
.st:
    mov [r12], dl
    inc r12
    sub ecx, 4
    dec ebx
    jnz .hx
    mov byte [r12], 0
    pop r12
    pop rbx
    ret

t_fail:
    mov edi, 2
    lea rsi, [rel msg_fail]
    mov edx, msg_fail_len
    call hal_write
    mov edi, 1
    call hal_exit

_start:
    cld
    sub rsp, 8
    call bootstrap_init
    cmp eax, 1
    jne t_fail
    call vfs_init
    call input_queue_init

    mov byte [rel root_dir], 0
    lea rdi, [rel root_dir]
    lea rsi, [rel root_prefix]
    call t_append

    lea rdi, [rel root_dir]
    mov rax, [rel win32_GetTickCount64]
    test rax, rax
    jz .notick
    sub rsp, 32
    call rax
    add rsp, 32
    jmp .htick
.notick:
    xor eax, eax
.htick:
    lea rdi, [rel root_dir]
    call t_append_hex8

    lea rcx, [rel root_dir]
    xor edx, edx
    mov rax, [rel win32_CreateDirectoryA]
    test rax, rax
    jz t_fail
    sub rsp, 32
    call rax
    add rsp, 32
    test eax, eax
    jnz .mkdir_ok
    ; allow ERROR_ALREADY_EXISTS
.mkdir_ok:

    lea rdi, [rel path_tmp]
    lea rsi, [rel root_dir]
    xor ecx, ecx
.cpr:
    mov al, [rsi + rcx]
    mov [rdi + rcx], al
    test al, al
    je .cprd
    inc rcx
    cmp rcx, 500
    jb .cpr
    jmp t_fail
.cprd:
    lea rdi, [rel path_tmp]
    lea rsi, [rel mark_sub]
    call t_append
    lea rcx, [rel path_tmp]
    xor edx, edx
    mov rax, [rel win32_CreateDirectoryA]
    sub rsp, 32
    call rax
    add rsp, 32
    test eax, eax
    jnz .msub_ok
.msub_ok:

    lea rdi, [rel path_tmp]
    lea rsi, [rel root_dir]
    xor ecx, ecx
.cpa:
    mov al, [rsi + rcx]
    mov [rdi + rcx], al
    test al, al
    je .cpad
    inc rcx
    jmp .cpa
.cpad:
    lea rdi, [rel path_tmp]
    lea rsi, [rel mark_a]
    call t_append
    lea rdi, [rel path_tmp]
    mov esi, O_CREAT | O_TRUNC | O_WRONLY
    xor edx, edx
    call hal_open
    cmp rax, -1
    je t_fail
    mov rdi, rax
    call hal_close

    lea rdi, [rel path_tmp]
    lea rsi, [rel root_dir]
    xor ecx, ecx
.cpb:
    mov al, [rsi + rcx]
    mov [rdi + rcx], al
    test al, al
    je .cpbd
    inc rcx
    jmp .cpb
.cpbd:
    lea rdi, [rel path_tmp]
    lea rsi, [rel mark_b]
    call t_append
    lea rdi, [rel path_tmp]
    mov esi, O_CREAT | O_TRUNC | O_WRONLY
    xor edx, edx
    call hal_open
    cmp rax, -1
    je t_fail
    mov rdi, rax
    call hal_close

    lea rdi, [rel path_tmp]
    lea rsi, [rel root_dir]
    xor ecx, ecx
.cps:
    mov al, [rsi + rcx]
    mov [rdi + rcx], al
    test al, al
    je .cpsd
    inc ecx
    jmp .cps
.cpsd:
    lea rdi, [rel path_tmp]
    lea rsi, [rel mark_sub]
    call t_append
    lea rdi, [rel path_tmp]
    lea rsi, [rel mark_inner]
    call t_append
    lea rdi, [rel path_tmp]
    mov esi, O_CREAT | O_TRUNC | O_WRONLY
    xor edx, edx
    call hal_open
    cmp rax, -1
    je t_fail
    mov rdi, rax
    call hal_close

    lea rdi, [rel panel_path]
    lea rsi, [rel root_dir]
    xor ecx, ecx
.norm:
    mov al, [rsi + rcx]
    test al, al
    je .normd
    cmp al, 92
    jne .nsl
    mov al, '/'
.nsl:
    mov [rdi + rcx], al
    inc ecx
    cmp ecx, 510
    jb .norm
    jmp t_fail
.normd:
    mov byte [rdi + rcx], 0
    mov r14d, ecx

    lea rdi, [rel panel_path]
    mov esi, r14d
    call panel_init
    test rax, rax
    jz t_fail
    mov [rel panel_ptr], rax

    mov r15, rax
    cmp dword [r15 + P_ENTRY_COUNT_OFF], 3
    jl t_fail

    xor ebx, ebx
.find_sub:
    cmp ebx, [r15 + P_ENTRY_COUNT_OFF]
    jge t_fail
    mov eax, ebx
    imul eax, DIR_ENTRY_SIZE
    lea rdi, [r15 + P_ENTRIES_BUF_OFF + rax]
    lea rsi, [rel name_sub]
    call t_entry_is
    test eax, eax
    jnz .got_sub
    inc ebx
    jmp .find_sub
.got_sub:
    mov rdi, r15
    mov esi, ebx
    call panel_navigate
    cmp eax, 1
    jne t_fail
    cmp dword [r15 + P_ENTRY_COUNT_OFF], 1
    jl t_fail
    xor ebx, ebx
.find_inner:
    cmp ebx, [r15 + P_ENTRY_COUNT_OFF]
    jge t_fail
    mov eax, ebx
    imul eax, DIR_ENTRY_SIZE
    lea rdi, [r15 + P_ENTRIES_BUF_OFF + rax]
    lea rsi, [rel name_inner]
    call t_entry_is
    test eax, eax
    jnz .got_inner
    inc ebx
    jmp .find_inner
.got_inner:

    mov rdi, r15
    call panel_go_parent
    cmp eax, 0
    jne t_fail
    cmp dword [r15 + P_ENTRY_COUNT_OFF], 3
    jl t_fail

    mov rdi, 640
    mov rsi, 480
    lea rdx, [rel win_title]
    call window_create_win32
    test rax, rax
    jz t_fail
    mov [rel wnd_ptr], rax
    mov rdi, rax
    call window_get_canvas
    test rax, rax
    jz .bad_wnd
    mov rdi, rax
    mov esi, 0xFF1A1B26
    call canvas_clear

    mov r15, [rel panel_ptr]
    xor ebx, ebx
.draw_rows:
    cmp ebx, 3
    jge .draw_done
    mov eax, ebx
    imul eax, DIR_ENTRY_SIZE
    lea r9, [r15 + P_ENTRIES_BUF_OFF + rax]
    mov ecx, [r9 + DE_NAME_LEN_OFF]
    cmp ecx, 1
    jl .dr_next
    cmp ecx, 64
    jle .dr_len
    mov ecx, 64
.dr_len:
    lea rdx, [r9 + DE_NAME_OFF]
    mov edi, 16
    mov esi, ebx
    imul esi, 24
    add esi, 48
    mov r8d, 0x00C0CAF5
    call window_draw_text_overlay
.dr_next:
    inc ebx
    jmp .draw_rows
.draw_done:
    mov rdi, [rel wnd_ptr]
    call window_present_win32
    mov r12d, 20
.pump:
    mov rdi, [rel wnd_ptr]
    call window_process_events
    mov edi, 40
    call hal_sleep_ms
    mov rdi, [rel wnd_ptr]
    call window_should_close
    test eax, eax
    jnz .wnd_ok
    dec r12d
    jnz .pump
.wnd_ok:
    mov rdi, [rel wnd_ptr]
    call window_destroy
.done_ok:
    mov edi, 1
    lea rsi, [rel msg_pass]
    mov edx, msg_pass_len
    call hal_write
    xor edi, edi
    call hal_exit

.bad_wnd:
    mov rdi, [rel wnd_ptr]
    call window_destroy
    jmp t_fail
