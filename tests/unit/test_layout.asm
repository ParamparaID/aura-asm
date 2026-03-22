; test_layout.asm — flex measure/arrange, grow, responsive
%include "src/hal/linux_x86_64/defs.inc"
%include "src/gui/widget.inc"
%include "src/gui/layout.inc"

extern hal_write
extern hal_exit
extern widget_system_init
extern widget_system_shutdown
extern widget_init
extern widget_add_child
extern layout_measure
extern layout_arrange
extern layout_get_form_factor
extern layout_set_responsive
extern layout_apply_viewport

section .rodata
    pass_msg db "ALL TESTS PASSED", 10
    pass_len equ $ - pass_msg
    f1       db "FAIL:1", 10
    f1l      equ $ - f1
    f2       db "FAIL:2", 10
    f2l      equ $ - f2
    f3       db "FAIL:3", 10
    f3l      equ $ - f3
    f4       db "FAIL:4", 10
    f4l      equ $ - f4

section .bss
    root_w      resq 1
    c1          resq 1
    c2          resq 1
    c3          resq 1
    flex_data   resb FCD_STRUCT_SIZE
    lp1         resb LP_STRUCT_SIZE
    lp2         resb LP_STRUCT_SIZE
    lp3         resb LP_STRUCT_SIZE
    lp_g1       resb LP_STRUCT_SIZE
    lp_g2       resb LP_STRUCT_SIZE
    lp_phone    resb LP_STRUCT_SIZE
    lp_tablet   resb LP_STRUCT_SIZE
    lp_desktop  resb LP_STRUCT_SIZE
    root2       resq 1
    cg1         resq 1
    cg2         resq 1
    flex_g      resb FCD_STRUCT_SIZE

section .text
global _start

%macro fail_exit 2
    mov rdi, 1
    lea rsi, [rel %1]
    mov rdx, %2
    call hal_write
    mov rdi, 1
    call hal_exit
%endmacro

%macro write_stdout 2
    mov rdi, 1
    lea rsi, [rel %1]
    mov rdx, %2
    call hal_write
%endmacro

_start:
    call widget_system_init
    test eax, eax
    jnz .e4

    ; --- Row START (0, 80, 160) ---
    mov edi, WIDGET_CONTAINER
    xor esi, esi
    xor edx, edx
    mov ecx, 300
    mov r8d, 100
    call widget_init
    test rax, rax
    jz .e1
    mov [rel root_w], rax
    mov rax, [rel root_w]
    lea rbx, [rel flex_data]
    mov [rax + W_DATA_OFF], rbx
    mov dword [rbx + LP_DIRECTION_OFF], LAYOUT_ROW
    mov dword [rbx + LP_WRAP_OFF], LAYOUT_WRAP_NONE
    mov dword [rbx + LP_JUSTIFY_OFF], JUSTIFY_START
    mov dword [rbx + LP_ALIGN_OFF], ALIGN_START
    mov dword [rbx + LP_GAP_OFF], 0

    mov edi, WIDGET_CONTAINER
    xor esi, esi
    xor edx, edx
    mov ecx, 80
    mov r8d, 60
    call widget_init
    mov [rel c1], rax
    mov edi, WIDGET_CONTAINER
    mov ecx, 80
    mov r8d, 60
    call widget_init
    mov [rel c2], rax
    mov edi, WIDGET_CONTAINER
    mov ecx, 80
    mov r8d, 60
    call widget_init
    mov [rel c3], rax

    mov rdi, [rel root_w]
    mov rsi, [rel c1]
    call widget_add_child
    mov rdi, [rel root_w]
    mov rsi, [rel c2]
    call widget_add_child
    mov rdi, [rel root_w]
    mov rsi, [rel c3]
    call widget_add_child

    mov rdi, [rel root_w]
    mov esi, 1000
    mov edx, 1000
    call layout_measure
    mov rax, [rel root_w]
    mov dword [rax + W_WIDTH_OFF], 300
    mov dword [rax + W_HEIGHT_OFF], 100
    mov rdi, [rel root_w]
    call layout_arrange

    mov rax, [rel c1]
    cmp dword [rax + W_X_OFF], 0
    jne .e1
    mov rax, [rel c2]
    cmp dword [rax + W_X_OFF], 80
    jne .e1
    mov rax, [rel c3]
    cmp dword [rax + W_X_OFF], 160
    jne .e1

    ; --- Row CENTER (30, 110, 190) ---
    lea rbx, [rel flex_data]
    mov dword [rbx + LP_JUSTIFY_OFF], JUSTIFY_CENTER
    mov rdi, [rel root_w]
    mov esi, 1000
    mov edx, 1000
    call layout_measure
    mov rdi, [rel root_w]
    call layout_arrange
    mov rax, [rel c1]
    cmp dword [rax + W_X_OFF], 30
    jne .e1
    mov rax, [rel c2]
    cmp dword [rax + W_X_OFF], 110
    jne .e1
    mov rax, [rel c3]
    cmp dword [rax + W_X_OFF], 190
    jne .e1

    ; --- Row BETWEEN ---
    mov dword [rbx + LP_JUSTIFY_OFF], JUSTIFY_BETWEEN
    mov rdi, [rel root_w]
    call layout_measure
    mov rdi, [rel root_w]
    call layout_arrange
    mov rax, [rel c1]
    cmp dword [rax + W_X_OFF], 0
    jne .e1
    mov rax, [rel c2]
    cmp dword [rax + W_X_OFF], 110
    jne .e1
    mov rax, [rel c3]
    cmp dword [rax + W_X_OFF], 220
    jne .e1

    ; --- Column START ---
    mov dword [rbx + LP_DIRECTION_OFF], LAYOUT_COLUMN
    mov dword [rbx + LP_JUSTIFY_OFF], JUSTIFY_START
    mov rax, [rel root_w]
    mov dword [rax + W_WIDTH_OFF], 100
    mov dword [rax + W_HEIGHT_OFF], 300
    mov rdi, [rel root_w]
    call layout_measure
    mov rdi, [rel root_w]
    call layout_arrange
    mov rax, [rel c1]
    cmp dword [rax + W_Y_OFF], 0
    jne .e2
    mov rax, [rel c2]
    cmp dword [rax + W_Y_OFF], 60
    jne .e2
    mov rax, [rel c3]
    cmp dword [rax + W_Y_OFF], 120
    jne .e2

    mov dword [rbx + LP_JUSTIFY_OFF], JUSTIFY_CENTER
    mov rdi, [rel root_w]
    call layout_measure
    mov rdi, [rel root_w]
    call layout_arrange
    mov rax, [rel c1]
    cmp dword [rax + W_Y_OFF], 60
    jne .e2
    mov rax, [rel c2]
    cmp dword [rax + W_Y_OFF], 120
    jne .e2
    mov rax, [rel c3]
    cmp dword [rax + W_Y_OFF], 180
    jne .e2

    mov dword [rbx + LP_JUSTIFY_OFF], JUSTIFY_BETWEEN
    mov rdi, [rel root_w]
    call layout_measure
    mov rdi, [rel root_w]
    call layout_arrange
    mov rax, [rel c1]
    cmp dword [rax + W_Y_OFF], 0
    jne .e2
    mov rax, [rel c2]
    cmp dword [rax + W_Y_OFF], 120
    jne .e2
    mov rax, [rel c3]
    cmp dword [rax + W_Y_OFF], 240
    jne .e2

    ; --- Flex grow 1:2 -> 100 + 200 ---
    mov edi, WIDGET_CONTAINER
    xor esi, esi
    xor edx, edx
    mov ecx, 300
    mov r8d, 100
    call widget_init
    mov [rel root2], rax
    mov rax, [rel root2]
    lea rbx, [rel flex_g]
    mov [rax + W_DATA_OFF], rbx
    mov dword [rbx + LP_DIRECTION_OFF], LAYOUT_ROW
    mov dword [rbx + LP_JUSTIFY_OFF], JUSTIFY_START
    mov dword [rbx + LP_GAP_OFF], 0

    mov edi, WIDGET_CONTAINER
    xor esi, esi
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    call widget_init
    mov [rel cg1], rax
    mov edi, WIDGET_CONTAINER
    call widget_init
    mov [rel cg2], rax

    lea rdi, [rel lp_g1]
    xor eax, eax
    mov ecx, LP_STRUCT_SIZE / 4
    rep stosd
    lea rdi, [rel lp_g2]
    mov ecx, LP_STRUCT_SIZE / 4
    rep stosd
    mov dword [rel lp_g1 + LP_FLEX_GROW_OFF], 1
    mov dword [rel lp_g2 + LP_FLEX_GROW_OFF], 2

    mov rax, [rel cg1]
    lea rbx, [rel lp_g1]
    mov [rax + W_DATA_OFF], rbx
    mov rax, [rel cg2]
    lea rbx, [rel lp_g2]
    mov [rax + W_DATA_OFF], rbx

    mov rdi, [rel root2]
    mov rsi, [rel cg1]
    call widget_add_child
    mov rdi, [rel root2]
    mov rsi, [rel cg2]
    call widget_add_child

    mov rdi, [rel root2]
    mov esi, 300
    mov edx, 100
    call layout_measure
    mov rax, [rel root2]
    mov dword [rax + W_WIDTH_OFF], 300
    mov dword [rax + W_HEIGHT_OFF], 100
    mov rdi, [rel root2]
    call layout_arrange

    mov rax, [rel cg1]
    cmp dword [rax + W_WIDTH_OFF], 100
    jne .e3
    mov rax, [rel cg2]
    cmp dword [rax + W_WIDTH_OFF], 200
    jne .e3

    ; --- Form factor + responsive ---
    mov esi, 400
    call layout_get_form_factor
    cmp eax, FORM_PHONE
    jne .e4
    mov esi, 800
    call layout_get_form_factor
    cmp eax, FORM_TABLET
    jne .e4
    mov esi, 1400
    call layout_get_form_factor
    cmp eax, FORM_DESKTOP
    jne .e4

    lea rdi, [rel lp_phone]
    mov ecx, LP_STRUCT_SIZE / 4
    xor eax, eax
    rep stosd
    lea rdi, [rel lp_tablet]
    mov ecx, LP_STRUCT_SIZE / 4
    rep stosd
    lea rdi, [rel lp_desktop]
    mov ecx, LP_STRUCT_SIZE / 4
    rep stosd

    mov dword [rel lp_phone + LP_DIRECTION_OFF], LAYOUT_COLUMN
    mov dword [rel lp_desktop + LP_DIRECTION_OFF], LAYOUT_ROW
    mov dword [rel lp_tablet + LP_DIRECTION_OFF], LAYOUT_ROW

    lea rbx, [rel flex_data]
    mov rdi, rbx
    mov ecx, FCD_STRUCT_SIZE / 4
    xor eax, eax
    rep stosd
    mov dword [rbx + LP_GAP_OFF], 0

    mov rdi, [rel root_w]
    mov [rdi + W_DATA_OFF], rbx
    lea rsi, [rel lp_phone]
    lea rdx, [rel lp_tablet]
    lea rcx, [rel lp_desktop]
    call layout_set_responsive

    mov rdi, [rel root_w]
    mov esi, 400
    call layout_apply_viewport
    lea rbx, [rel flex_data]
    cmp dword [rbx + LP_DIRECTION_OFF], LAYOUT_COLUMN
    jne .e4

    mov rdi, [rel root_w]
    mov esi, 1400
    call layout_apply_viewport
    cmp dword [rbx + LP_DIRECTION_OFF], LAYOUT_ROW
    jne .e4

    write_stdout pass_msg, pass_len
    call widget_system_shutdown
    xor rdi, rdi
    call hal_exit

.e1:
    fail_exit f1, f1l
.e2:
    fail_exit f2, f2l
.e3:
    fail_exit f3, f3l
.e4:
    fail_exit f4, f4l
