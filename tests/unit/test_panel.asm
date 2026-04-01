; test_panel.asm — STEP 41 panel and file_panel tests
%include "src/hal/platform_defs.inc"
%include "src/gui/widget.inc"
%include "src/fm/vfs.inc"
%include "src/fm/panel.inc"

extern hal_write
extern hal_exit
extern hal_open
extern hal_close
extern hal_mkdir
extern hal_unlink
extern hal_access
extern canvas_init
extern canvas_destroy
extern canvas_clear
extern canvas_get_pixel
extern widget_system_init
extern widget_system_shutdown
extern widget_render
extern panel_init
extern panel_sort
extern panel_navigate
extern panel_go_parent
extern panel_toggle_mark
extern panel_get_marked
extern file_panel_create
extern op_delete
extern vfs_init

section .data
    root_path      db "/tmp/aura_test_fm", 0
    file_a         db "/tmp/aura_test_fm/a.txt", 0
    file_b         db "/tmp/aura_test_fm/b.txt", 0
    dir1_path      db "/tmp/aura_test_fm/dir1", 0
    content_100    times 100 db 'A'
    content_200    times 200 db 'B'

    pass_msg       db "ALL TESTS PASSED", 10
    pass_len       equ $ - pass_msg
    f1             db "FAIL: t1 load", 10
    f1l            equ $ - f1
    f2             db "FAIL: t2 sort", 10
    f2l            equ $ - f2
    f3             db "FAIL: t3 navigate", 10
    f3l            equ $ - f3
    f4             db "FAIL: t4 mark", 10
    f4l            equ $ - f4
    f5             db "FAIL: t5 file panel render", 10
    f5l            equ $ - f5

section .bss
    panel_ptr      resq 1
    canvas_ptr     resq 1
    widget_ptr     resq 1
    theme_mem      resb THEME_STRUCT_SIZE
    marked_buf     resb (VFS_MAX_PATH * 32)
    marked_count   resd 1

section .text
global _start

%macro fail 2
    mov rdi, STDOUT
    lea rsi, [rel %1]
    mov rdx, %2
    call hal_write
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

write_file_fixed:
    ; (path, buf, len)
    push rbx
    mov rbx, rdx
    mov rdx, 0o644
    mov esi, O_WRONLY | O_CREAT | O_TRUNC
    call hal_open
    test rax, rax
    js .f
    mov ebp, eax
    movsx rdi, ebp
    mov rdx, rbx
    call hal_write
    movsx rdi, ebp
    call hal_close
    xor eax, eax
    pop rbx
    ret
.f:
    mov eax, -1
    pop rbx
    ret

name_eq:
    ; (entry_ptr rdi, cstr rsi) -> eax 1/0
    lea rdi, [rdi + DE_NAME_OFF]
.n:
    mov al, [rdi]
    cmp al, [rsi]
    jne .no
    test al, al
    je .yes
    inc rdi
    inc rsi
    jmp .n
.yes:
    mov eax, 1
    ret
.no:
    xor eax, eax
    ret

find_index_by_name:
    ; (panel rdi, name rsi) -> eax idx or -1
    push rbx
    push r12
    mov rbx, rdi
    mov r12, rsi
    xor ecx, ecx
.l:
    cmp ecx, [rbx + P_ENTRY_COUNT_OFF]
    jae .nf
    mov eax, ecx
    imul eax, DIR_ENTRY_SIZE
    lea rdi, [rbx + P_ENTRIES_BUF_OFF + rax]
    mov rsi, r12
    call name_eq
    test eax, eax
    jnz .f
    inc ecx
    jmp .l
.f:
    mov eax, ecx
    pop r12
    pop rbx
    ret
.nf:
    mov eax, -1
    pop r12
    pop rbx
    ret

cleanup:
    lea rdi, [rel root_path]
    mov esi, 1
    call op_delete
    ret

_start:
    call cleanup
    call vfs_init

    ; setup tree
    lea rdi, [rel root_path]
    mov esi, 0o755
    call hal_mkdir
    lea rdi, [rel dir1_path]
    mov esi, 0o755
    call hal_mkdir
    lea rdi, [rel file_a]
    lea rsi, [rel content_100]
    mov edx, 100
    call write_file_fixed
    lea rdi, [rel file_b]
    lea rsi, [rel content_200]
    mov edx, 200
    call write_file_fixed

    ; Test 1: load directory
    lea rdi, [rel root_path]
    call cstr_len
    mov esi, eax
    lea rdi, [rel root_path]
    call panel_init
    test rax, rax
    jz .e1
    mov [rel panel_ptr], rax
    cmp dword [rax + P_ENTRY_COUNT_OFF], 3
    jne .e1

    ; Test 2: sort
    mov rdi, [rel panel_ptr]
    mov esi, SORT_SIZE
    call panel_sort
    test eax, eax
    js .e2
    mov rdi, [rel panel_ptr]
    mov esi, SORT_NAME
    call panel_sort
    test eax, eax
    js .e2
    mov rdi, [rel panel_ptr]
    cmp dword [rdi + P_ENTRY_COUNT_OFF], 3
    jne .e2

    ; Test 3: navigate + parent
    mov rdi, [rel panel_ptr]
    call panel_go_parent
    test eax, eax
    js .e3
    mov rdi, [rel panel_ptr]
    cmp dword [rdi + P_PATH_LEN_OFF], 0
    jle .e3

    ; Test 4: mark
    mov rdi, [rel panel_ptr]
    mov esi, 0
    call panel_toggle_mark
    test eax, eax
    js .e4
    mov rdi, [rel panel_ptr]
    mov esi, 2
    call panel_toggle_mark
    test eax, eax
    js .e4
    mov rdi, [rel panel_ptr]
    lea rsi, [rel marked_buf]
    lea rdx, [rel marked_count]
    call panel_get_marked
    cmp eax, 1
    jl .e4

    ; Test 5: file panel render
    call widget_system_init
    test eax, eax
    jnz .e5
    mov rdi, 400
    mov rsi, 300
    call canvas_init
    test rax, rax
    jz .e5
    mov [rel canvas_ptr], rax
    mov rdi, rax
    mov esi, 0xFF101010
    call canvas_clear

    mov rdi, [rel panel_ptr]
    xor esi, esi
    xor edx, edx
    mov ecx, 400
    mov r8d, 300
    call file_panel_create
    test rax, rax
    jz .e5
    mov [rel widget_ptr], rax
    mov rdi, rax
    mov rsi, [rel canvas_ptr]
    lea rdx, [rel theme_mem]
    xor ecx, ecx
    xor r8d, r8d
    call widget_render

    mov rdi, [rel canvas_ptr]
    mov esi, 10
    mov edx, 40
    call canvas_get_pixel
    cmp eax, 0xFF101010
    je .e5

    mov rdi, [rel canvas_ptr]
    call canvas_destroy
    call widget_system_shutdown
    call cleanup
    mov rdi, STDOUT
    lea rsi, [rel pass_msg]
    mov rdx, pass_len
    call hal_write
    xor edi, edi
    call hal_exit

.e1:
    fail f1, f1l
.e2:
    fail f2, f2l
.e3:
    fail f3, f3l
.e4:
    fail f4, f4l
.e5:
    fail f5, f5l
