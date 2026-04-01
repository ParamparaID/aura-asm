; fileio.asm — Win32 file I/O HAL (CreateFile/ReadFile/WriteFile, getdents via FindFirst/Next)
%include "src/hal/win_x86_64/defs.inc"

extern win_bootstrap_ensure
extern win32_CreateFileA
extern win32_ReadFile
extern win32_WriteFile
extern win32_CloseHandle
extern win32_GetStdHandle
extern win32_FindFirstFileA
extern win32_FindNextFileA
extern win32_FindClose

; Per-open-directory state (Windows has no fd-based getdents)
%define DIR_MAX_SLOTS             16
%define DIR_OFF_HANDLE            0
%define DIR_OFF_FIND              8
%define DIR_OFF_EXH               16
%define DIR_OFF_PEND              17
%define DIR_OFF_SEQ               24
%define DIR_OFF_FFD               32
%define WIN32_FIND_DATAA_SIZE     320
%define DIR_OFF_PATH              (DIR_OFF_FFD + WIN32_FIND_DATAA_SIZE)
%define DIR_SLOT_STRIDE           (DIR_OFF_PATH + 1024)
%define W32FFD_ATTR_OFF           0
%define W32FFD_NAME_OFF           44

section .bss
align 8
    dir_slots                   resb DIR_SLOT_STRIDE * DIR_MAX_SLOTS
    pattern_scratch             resb 1032

section .text
global hal_write
global hal_read
global hal_open
global hal_close
global hal_getdents64

win_pick_handle:
    cmp edi, 1
    je .stdout
    cmp edi, 2
    je .stderr
    cmp edi, 0
    je .stdin
    mov rax, rdi
    ret
.stdout:
    mov ecx, STD_OUTPUT_HANDLE
    jmp .std
.stderr:
    mov ecx, STD_ERROR_HANDLE
    jmp .std
.stdin:
    mov ecx, STD_INPUT_HANDLE
.std:
    mov rax, [rel win32_GetStdHandle]
    sub rsp, 40
    call rax
    add rsp, 40
    ret

; --- rcx = handle, rdx = path cstr ---
dir_register:
    push rbx
    push r12
    push r13
    mov r12, rcx
    mov r13, rdx
    xor ebx, ebx
.slot_loop:
    lea rax, [rel dir_slots]
    mov ecx, ebx
    imul ecx, ecx, DIR_SLOT_STRIDE
    lea rax, [rax + rcx]
    cmp qword [rax + DIR_OFF_HANDLE], 0
    je .found_slot
    inc ebx
    cmp ebx, DIR_MAX_SLOTS
    jb .slot_loop
    pop r13
    pop r12
    pop rbx
    ret
.found_slot:
    mov qword [rax + DIR_OFF_HANDLE], r12
    mov qword [rax + DIR_OFF_FIND], 0
    mov byte [rax + DIR_OFF_EXH], 0
    mov byte [rax + DIR_OFF_PEND], 0
    mov qword [rax + DIR_OFF_SEQ], 1
    lea rdi, [rax + DIR_OFF_PATH]
    mov rsi, r13
    mov ecx, 1023
.copy:
    jecxz .zterm
    mov al, [rsi]
    mov [rdi], al
    test al, al
    je .done_copy
    inc rsi
    inc rdi
    dec ecx
    jmp .copy
.zterm:
    mov byte [rdi], 0
.done_copy:
    pop r13
    pop r12
    pop rbx
    ret

; --- rdi = directory handle -> rax slot ptr or 0 ---
dir_find_slot:
    xor eax, eax
    xor ecx, ecx
.loop:
    lea rdx, [rel dir_slots]
    imul r8d, ecx, DIR_SLOT_STRIDE
    lea rdx, [rdx + r8]
    cmp [rdx + DIR_OFF_HANDLE], rdi
    je .hit
    inc ecx
    cmp ecx, DIR_MAX_SLOTS
    jb .loop
    xor eax, eax
    ret
.hit:
    mov rax, rdx
    ret

; --- rax = slot ptr ---
dir_slot_release_find:
    push rbx
    mov rbx, rax
    mov rcx, [rbx + DIR_OFF_FIND]
    test rcx, rcx
    jz .done
    sub rsp, 32
    mov rax, [rel win32_FindClose]
    call rax
    add rsp, 32
    mov qword [rbx + DIR_OFF_FIND], 0
.done:
    mov rax, rbx
    pop rbx
    ret

; --- rax = slot ptr ---
dir_slot_wipe:
    push rdi
    push rcx
    mov rdi, rax
    mov ecx, DIR_SLOT_STRIDE / 8
    xor eax, eax
    rep stosq
    pop rcx
    pop rdi
    ret

; --- r15 = slot: build path\* into pattern_scratch; rdi -> scratch ---
dir_build_pattern:
    push rbx
    push r12
    push r13
    lea rdi, [rel pattern_scratch]
    lea rsi, [r15 + DIR_OFF_PATH]
    mov ecx, 1023
.copy:
    jecxz .end_copy
    mov al, [rsi]
    mov [rdi], al
    test al, al
    je .end_copy
    inc rsi
    inc rdi
    dec ecx
    jmp .copy
.end_copy:
    mov rbx, rdi
    lea rsi, [rel pattern_scratch]
    cmp rbx, rsi
    je .empty
    dec rbx
    mov al, [rbx]
    cmp al, '/'
    je .star
    cmp al, '\'
    je .star
    mov byte [rbx + 1], '\'
    mov byte [rbx + 2], '*'
    mov byte [rbx + 3], 0
    jmp .out
.star:
    mov byte [rbx + 1], '*'
    mov byte [rbx + 2], 0
    jmp .out
.empty:
    mov word [rel pattern_scratch], 0x002A   ; '*' + NUL
    jmp .out
.out:
    lea rdi, [rel pattern_scratch]
    pop r13
    pop r12
    pop rbx
    ret

hal_write:
    push rbx
    mov rbx, rsi
    mov r10d, edx
    call win_bootstrap_ensure
    test eax, eax
    js .fail

    call win_pick_handle
    mov r11, rax
    sub rsp, 80
    lea r9, [rsp + 64]
    mov qword [rsp + 32], 0
    mov rcx, r11
    mov rdx, rbx
    mov r8d, r10d
    mov rax, [rel win32_WriteFile]
    call rax
    test eax, eax
    jz .err
    mov eax, [rsp + 64]
    add rsp, 80
    pop rbx
    ret
.err:
    add rsp, 80
.fail:
    mov eax, -1
    pop rbx
    ret

hal_read:
    push rbx
    mov rbx, rsi
    mov r10d, edx
    call win_bootstrap_ensure
    test eax, eax
    js .fail

    call win_pick_handle
    mov r11, rax
    sub rsp, 80
    lea r9, [rsp + 64]
    mov qword [rsp + 32], 0
    mov rcx, r11
    mov rdx, rbx
    mov r8d, r10d
    mov rax, [rel win32_ReadFile]
    call rax
    test eax, eax
    jz .err
    mov eax, [rsp + 64]
    add rsp, 80
    pop rbx
    ret
.err:
    add rsp, 80
.fail:
    mov eax, -1
    pop rbx
    ret

hal_open:
    ; (path, flags, mode) -> HANDLE or -1
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12d, esi
    call win_bootstrap_ensure
    test eax, eax
    js .fail

    mov r13d, r12d
    test r13d, O_DIRECTORY
    jz .regular

    ; directory: GENERIC_READ + BACKUP_SEMANTICS, OPEN_EXISTING
    mov edx, GENERIC_READ
    mov r11d, OPEN_EXISTING
    mov r8d, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE
    mov r9d, FILE_ATTRIBUTE_NORMAL | FILE_FLAG_BACKUP_SEMANTICS
    jmp .docreate

.regular:
    mov edx, GENERIC_READ
    test r12d, O_WRONLY
    jnz .wr
    test r12d, O_RDWR
    jnz .rdwr
    jmp .disp
.wr:
    mov edx, GENERIC_WRITE
    jmp .disp
.rdwr:
    mov edx, GENERIC_READ | GENERIC_WRITE

.disp:
    mov r11d, OPEN_EXISTING
    test r12d, O_CREAT
    jz .nodisp
    test r12d, O_TRUNC
    jnz .ctrunc
    mov r11d, OPEN_ALWAYS
    jmp .nodisp
.ctrunc:
    mov r11d, CREATE_ALWAYS
.nodisp:
    mov r8d, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE
    mov r9d, FILE_ATTRIBUTE_NORMAL

.docreate:
    mov r10d, r9d
    sub rsp, 64
    ; 5th..7th stack args: dwCreationDisposition, dwFlagsAndAttributes, hTemplateFile
    mov dword [rsp + 32], r11d
    mov dword [rsp + 40], r10d
    mov qword [rsp + 48], 0
    mov rcx, rbx
    xor r9d, r9d
    mov rax, [rel win32_CreateFileA]
    call rax
    add rsp, 64
    cmp rax, -1
    je .fail
    test r12d, O_DIRECTORY
    jz .no_track
    push rax
    mov rcx, rax
    mov rdx, rbx
    call dir_register
    pop rax
.no_track:
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

hal_close:
    ; (handle) -> 0/-1
    push rbx
    mov rbx, rdi
    call win_bootstrap_ensure
    test eax, eax
    js .fail

    mov rdi, rbx
    call dir_find_slot
    test rax, rax
    jz .just_close
    call dir_slot_release_find
    call dir_slot_wipe

.just_close:
    mov rcx, rbx
    sub rsp, 32
    mov rax, [rel win32_CloseHandle]
    call rax
    add rsp, 32
    test eax, eax
    jz .fail
    xor eax, eax
    pop rbx
    ret
.fail:
    mov eax, -1
    pop rbx
    ret

hal_getdents64:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rdi
    mov r14, rdi
    mov r12, rsi
    mov r13, rdx
    xor ebx, ebx

    call win_bootstrap_ensure
    test eax, eax
    js .bad

    mov rdi, r14
    call dir_find_slot
    test rax, rax
    jz .bad
    mov r15, rax

.more:
    cmp rbx, r13
    jae .done
    cmp byte [r15 + DIR_OFF_EXH], 1
    je .done

    cmp byte [r15 + DIR_OFF_PEND], 1
    je .have_entry

    cmp qword [r15 + DIR_OFF_FIND], 0
    jne .do_next

    call dir_build_pattern
    mov rcx, rdi
    lea rdx, [r15 + DIR_OFF_FFD]
    sub rsp, 40
    mov rax, [rel win32_FindFirstFileA]
    call rax
    add rsp, 40
    cmp rax, -1
    jne .ff_ok
    mov byte [r15 + DIR_OFF_EXH], 1
    jmp .done
.ff_ok:
    mov qword [r15 + DIR_OFF_FIND], rax
    mov byte [r15 + DIR_OFF_PEND], 1
    jmp .have_entry

.do_next:
    mov rcx, [r15 + DIR_OFF_FIND]
    lea rdx, [r15 + DIR_OFF_FFD]
    sub rsp, 40
    mov rax, [rel win32_FindNextFileA]
    call rax
    add rsp, 40
    test eax, eax
    jnz .fn_ok
    mov rax, r15
    call dir_slot_release_find
    mov byte [r15 + DIR_OFF_EXH], 1
    jmp .done
.fn_ok:
    mov byte [r15 + DIR_OFF_PEND], 1

.have_entry:
    lea rsi, [r15 + DIR_OFF_FFD + W32FFD_NAME_OFF]
    cmp byte [rsi], '.'
    jne .not_dot
    cmp byte [rsi + 1], 0
    je .skip_entry
    cmp byte [rsi + 1], '.'
    jne .not_dot
    cmp byte [rsi + 2], 0
    je .skip_entry
.not_dot:
    xor ecx, ecx
.len:
    cmp ecx, 259
    ja .skip_entry
    cmp byte [rsi + rcx], 0
    je .got_len
    inc ecx
    jmp .len
.got_len:
    mov r10d, ecx
    mov eax, 19
    add eax, r10d
    inc eax
    add eax, 7
    and eax, 0xFFFFFFF8
    mov r8d, eax
    mov rax, rbx
    add rax, r8
    cmp rax, r13
    ja .done

    lea rdi, [r12 + rbx]
    mov qword [rdi], 1
    mov rax, [r15 + DIR_OFF_SEQ]
    mov qword [rdi + 8], rax
    inc qword [r15 + DIR_OFF_SEQ]

    mov eax, 19
    add eax, r10d
    inc eax
    add eax, 7
    and eax, 0xFFFFFFF8
    mov r9d, eax
    mov word [rdi + 16], r9w

    mov eax, [r15 + DIR_OFF_FFD + W32FFD_ATTR_OFF]
    test eax, FILE_ATTRIBUTE_DIRECTORY
    jz .is_reg
    mov al, DT_DIR
    jmp .store_dt
.is_reg:
    mov al, DT_REG
.store_dt:
    mov byte [rdi + 18], al

    lea rdi, [rdi + 19]
    mov rcx, r10
    rep movsb
    mov byte [rdi], 0

    add rbx, r8
    mov byte [r15 + DIR_OFF_PEND], 0
    jmp .more

.skip_entry:
    mov byte [r15 + DIR_OFF_PEND], 0
    jmp .more

.done:
    mov rax, rbx
    pop rdi
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.bad:
    mov eax, -1
    pop rdi
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
