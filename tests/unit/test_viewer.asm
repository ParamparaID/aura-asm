; test_viewer.asm — unit tests for STEP 42 viewer
%include "src/hal/platform_defs.inc"
%include "src/gui/widget.inc"
%include "src/fm/viewer.inc"

extern hal_write
extern hal_exit
extern hal_open
extern hal_close
extern hal_mkdir
extern viewer_open
extern viewer_close
extern viewer_search
extern viewer_handle_input

section .data
    t_root           db "/tmp/aura_test_viewer",0
    t_file           db "/tmp/aura_test_viewer/sample.asm",0
    t_content        db "mov rax, 1",10,"hello world",10,"ret",10,0
    pat_hello        db "hello",0

    pass_msg         db "ALL TESTS PASSED",10
    pass_len         equ $ - pass_msg
    fail_t1          db "FAIL: viewer open/lines",10
    fail_t1_len      equ $ - fail_t1
    fail_t2          db "FAIL: viewer search",10
    fail_t2_len      equ $ - fail_t2
    fail_t3          db "FAIL: viewer hex toggle",10
    fail_t3_len      equ $ - fail_t3

section .bss
    key_event        resb 64

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

_start:
    ; best effort prepare dir/file
    mov rdi, t_root
    mov rsi, 0755o
    call hal_mkdir
    mov rdi, t_file
    mov rsi, t_content
    call write_file

    ; test 1: open + line count
    mov rdi, t_file
    call cstr_len
    mov esi, eax
    mov rdi, t_file
    call viewer_open
    test rax, rax
    jz .f1
    mov rbx, rax
    cmp qword [rbx + V_LINE_COUNT_OFF], 3
    jl .f1_close

    ; test 2: search
    mov rdi, rbx
    mov rsi, pat_hello
    mov edx, 5
    call viewer_search
    cmp eax, 1
    jl .f2

    ; test 3: toggle hex mode via key 'h'
    mov dword [key_event + IE_TYPE_OFF], INPUT_KEY
    mov dword [key_event + IE_KEY_STATE_OFF], KEY_PRESSED
    mov dword [key_event + IE_KEY_CODE_OFF], 35
    mov rdi, rbx
    lea rsi, [rel key_event]
    call viewer_handle_input
    cmp dword [rbx + V_HEX_MODE_OFF], 1
    jne .f3

    mov rdi, rbx
    call viewer_close
    write_stdout pass_msg, pass_len
    xor rdi, rdi
    call hal_exit

.f1_close:
    mov rdi, rbx
    call viewer_close
.f1:
    fail fail_t1, fail_t1_len
.f2:
    mov rdi, rbx
    call viewer_close
    fail fail_t2, fail_t2_len
.f3:
    mov rdi, rbx
    call viewer_close
    fail fail_t3, fail_t3_len
