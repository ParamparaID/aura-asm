; test_theme.asm — builtin theme, file parse, font
%include "src/hal/linux_x86_64/defs.inc"
%include "src/gui/theme.inc"

extern hal_write
extern hal_exit
extern hal_open
extern hal_close
extern theme_load_builtin
extern theme_load
extern theme_get_color
extern theme_destroy
extern font_measure_string

section .rodata
    nm_dark         db "dark", 0
    dark_len        equ 4
    str_bg          db "bg", 0
    theme_path      db "/tmp/aura_theme_test.auratheme", 0
    path_len        equ $ - theme_path - 1
    file_content:
        db "[colors]", 10
        db "bg = #112233", 10
        db "fg = #aabbcc", 10
        db "accent = #ff00ff", 10
        db "[window]", 10
        db "border_width = 3", 10
        db "corner_radius = 10", 10
        db "[fonts]", 10
        db "main = fonts/LiberationMono-Regular.ttf 13", 10
        db "[animation]", 10
        db "spring_stiffness = 300", 10
    file_content_len equ $ - file_content
    mstr            db "Hi", 0
    pass_msg        db "ALL TESTS PASSED", 10
    pass_len        equ $ - pass_msg
    f1              db "FAIL:1", 10
    f1l             equ $ - f1
    f2              db "FAIL:2", 10
    f2l             equ $ - f2
    f3              db "FAIL:3", 10
    f3l             equ $ - f3

section .text
global _start

%macro fail 2
    mov rdi, 1
    lea rsi, [rel %1]
    mov rdx, %2
    call hal_write
    mov rdi, 1
    call hal_exit
%endmacro

%macro ok_write 2
    mov rdi, 1
    lea rsi, [rel %1]
    mov rdx, %2
    call hal_write
%endmacro

_start:
    ; 1) Builtin dark
    lea rdi, [rel nm_dark]
    mov esi, dark_len
    call theme_load_builtin
    test rax, rax
    jz .e1
    mov rbx, rax
    cmp dword [rbx + T_BG_OFF], 0
    je .e1
    cmp dword [rbx + T_FG_OFF], 0
    je .e1
    cmp dword [rbx + T_ACCENT_OFF], 0
    je .e1
    lea rsi, [rel str_bg]
    mov edx, 2
    mov rdi, rbx
    call theme_get_color
    cmp eax, [rbx + T_BG_OFF]
    jne .e1
    mov rdi, rbx
    call theme_destroy

    ; 2) Write temp theme file
    lea rdi, [rel theme_path]
    mov esi, 0x241
    mov edx, 0x1A4
    call hal_open
    cmp rax, 0
    jl .e2
    mov r12, rax
    mov rdi, r12
    lea rsi, [rel file_content]
    mov edx, file_content_len
    mov rax, 1
    syscall
    mov rdi, r12
    call hal_close

    lea rdi, [rel theme_path]
    mov esi, path_len
    call theme_load
    test rax, rax
    jz .e2
    mov rbx, rax
    cmp dword [rbx + T_BORDER_WIDTH_OFF], 3
    jne .e2
    cmp dword [rbx + T_CORNER_RADIUS_OFF], 10
    jne .e2
    mov rdi, rbx
    call theme_destroy

    ; 3) Builtin again + font measure
    lea rdi, [rel nm_dark]
    mov esi, dark_len
    call theme_load_builtin
    test rax, rax
    jz .e3
    mov rbx, rax
    cmp qword [rbx + T_FONT_MAIN_OFF], 0
    je .e3
    mov rdi, [rbx + T_FONT_MAIN_OFF]
    lea rsi, [rel mstr]
    mov edx, 2
    mov ecx, [rbx + T_FONT_MAIN_SIZE_OFF]
    call font_measure_string
    test rax, rax
    jz .e3
    mov rdi, rbx
    call theme_destroy

    ok_write pass_msg, pass_len
    xor rdi, rdi
    call hal_exit
.e1:
    fail f1, f1l
.e2:
    fail f2, f2l
.e3:
    fail f3, f3l
