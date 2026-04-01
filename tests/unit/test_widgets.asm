; test_widgets.asm — STEP 24 widget system smoke tests
%include "src/hal/platform_defs.inc"
%include "src/gui/widget.inc"

extern hal_write
extern hal_exit
extern font_load
extern font_destroy
extern font_measure_string
extern canvas_init
extern canvas_destroy
extern canvas_clear
extern canvas_get_pixel
extern widget_system_init
extern widget_system_shutdown
extern widget_init
extern widget_add_child
extern widget_render
extern widget_handle_input
extern widget_hit_test
extern widget_focus
extern widget_measure
extern inertia_value
extern spring_init
extern spring_set_target
%define LD_INERT    32
%define MOUSE_LEFT  0x110

%define WHITE 0xFFFFFFFF
%define BLACK 0xFF000000

section .rodata
    font_path     db "tests/data/test_font.ttf", 0
    txt_hello     db "Hello"
    hello_len     equ 5
    txt_click     db "Click"
    click_len     equ 5
    item_txt      db "Item", 0
    pass_msg      db "ALL TESTS PASSED", 10
    pass_len      equ $ - pass_msg
    f0            db "FAIL:0", 10
    f0l           equ $ - f0
    f1            db "FAIL:1", 10
    f1l           equ $ - f1
    f2            db "FAIL:2", 10
    f2l           equ $ - f2
    f3            db "FAIL:3", 10
    f3l           equ $ - f3
    f4            db "FAIL:4", 10
    f4l           equ $ - f4
    f5            db "FAIL:5", 10
    f5l           equ $ - f5
    f6            db "FAIL:6", 10
    f6l           equ $ - f6

section .bss
    font_ptr      resq 1
    canvas_ptr    resq 1
    theme_mem     resq 8
    label_w       resq 1
    label_data    resb 64
    button_w      resq 1
    button_data   resb 128
    list_w        resq 1
    list_data     resb 128
    parent_w      resq 1
    child1        resq 1
    child2        resq 1
    child3        resq 1
    radial_w      resq 1
    radial_data   resb 128
    item_ptrs     resq 100
    click_count   resd 1
    event_buf     resb 80
    meas_w        resd 1
    meas_h        resd 1

section .text
global _start

%macro write_stdout 2
    mov rdi, 1
    lea rsi, [rel %1]
    mov rdx, %2
    call hal_write
%endmacro

%macro fail_exit 2
    mov rdi, 1
    lea rsi, [rel %1]
    mov rdx, %2
    call hal_write
    mov rdi, 1
    call hal_exit
%endmacro

button_cb:
    inc dword [rel click_count]
    ret

_start:
    call widget_system_init
    test eax, eax
    jnz .e0

    lea rdi, [rel font_path]
    mov rsi, 24
    call font_load
    test rax, rax
    jz .e0
    mov [rel font_ptr], rax

    mov rdi, 320
    mov rsi, 240
    call canvas_init
    test rax, rax
    jz .e0
    mov [rel canvas_ptr], rax

    mov rax, [rel font_ptr]
    mov [rel theme_mem + TH_FONT_OFF], rax
    mov dword [rel theme_mem + TH_ACCENT_OFF], 0xFF4488FF
    mov dword [rel theme_mem + TH_FG_OFF], BLACK

    ; --- Test 1: Label measure + draw ---
    mov edi, WIDGET_LABEL
    xor esi, esi
    xor edx, edx
    mov ecx, 200
    mov r8d, 48
    call widget_init
    test rax, rax
    jz .e1
    mov [rel label_w], rax

    lea rbx, [rel label_data]
    lea rdi, [rel txt_hello]
    mov [rbx + 0], rdi
    mov dword [rbx + 8], hello_len
    mov dword [rbx + 12], 16
    mov dword [rbx + 16], BLACK
    mov dword [rbx + 20], 0
    mov rdi, [rel font_ptr]
    mov [rbx + 24], rdi
    mov rax, [rel label_w]
    mov [rax + W_DATA_OFF], rbx

    mov rdi, [rel label_w]
    mov esi, 500
    mov edx, 500
    call widget_measure
    mov rax, [rel label_w]
    mov ecx, [rax + W_PREF_W_OFF]
    cmp ecx, 0
    jle .e1
    mov ecx, [rax + W_PREF_H_OFF]
    cmp ecx, 0
    jle .e1

    mov rdi, [rel canvas_ptr]
    mov rsi, WHITE
    call canvas_clear

    mov rdi, [rel label_w]
    mov rsi, [rel canvas_ptr]
    lea rdx, [rel theme_mem]
    xor ecx, ecx
    xor r8d, r8d
    call widget_render

    mov rdi, [rel canvas_ptr]
    mov esi, 6
    mov edx, 22
    call canvas_get_pixel
    mov ecx, eax
    and ecx, 0xFF000000
    cmp ecx, 0xFF000000
    jne .e1

    ; --- Test 2: Button + callback ---
    mov edi, WIDGET_BUTTON
    xor esi, esi
    xor edx, edx
    mov ecx, 120
    mov r8d, 48
    call widget_init
    test rax, rax
    jz .e2
    mov [rel button_w], rax

    lea rbx, [rel button_data]
    lea rdi, [rel txt_click]
    mov [rbx + 0], rdi
    mov dword [rbx + 8], click_len
    lea rax, [rel button_cb]
    mov [rbx + 16], rax
    mov rdi, [rel font_ptr]
    mov [rbx + 24], rdi
    mov dword [rbx + 32], 0xFFDDDDDD
    mov dword [rbx + 36], BLACK
    lea rdi, [rbx + 52]
    xor esi, esi
    mov edx, esi
    mov ecx, 0x00018000
    mov r8d, 0x0000C000
    call spring_init
    mov rax, [rel button_w]
    mov [rax + W_DATA_OFF], rbx

    mov dword [rel click_count], 0
    mov rdi, [rel canvas_ptr]
    call canvas_clear

    mov rdi, [rel button_w]
    mov rsi, [rel canvas_ptr]
    lea rdx, [rel theme_mem]
    xor ecx, ecx
    xor r8d, r8d
    call widget_render

    lea rdi, [rel event_buf]
    mov dword [rdi + IE_TYPE_OFF], INPUT_TOUCH_DOWN
    mov dword [rdi + IE_MOUSE_X_OFF], 20
    mov dword [rdi + IE_MOUSE_Y_OFF], 20
    mov rdi, [rel button_w]
    lea rsi, [rel event_buf]
    call widget_handle_input

    lea rdi, [rel event_buf]
    mov dword [rdi + IE_TYPE_OFF], INPUT_TOUCH_UP
    mov dword [rdi + IE_MOUSE_X_OFF], 20
    mov dword [rdi + IE_MOUSE_Y_OFF], 20
    mov rdi, [rel button_w]
    lea rsi, [rel event_buf]
    call widget_handle_input

    cmp dword [rel click_count], 0
    je .e2

    ; --- Test 3: List scroll ---
    xor ecx, ecx
.ip:
    cmp ecx, 100
    jae .ipd
    lea rax, [rel item_txt]
    mov [rel item_ptrs + rcx*8], rax
    inc ecx
    jmp .ip
.ipd:

    mov edi, WIDGET_LIST
    xor esi, esi
    xor edx, edx
    mov ecx, 200
    mov r8d, 180
    call widget_init
    test rax, rax
    jz .e3
    mov [rel list_w], rax

    lea rbx, [rel list_data]
    lea rdi, [rel item_ptrs]
    mov [rbx + 0], rdi
    mov dword [rbx + 8], 100
    mov dword [rbx + 12], 48
    mov rdi, [rel font_ptr]
    mov [rbx + 16], rdi
    mov dword [rbx + 24], WHITE
    mov dword [rbx + 28], 0
    mov dword [rbx + 72], 0
    mov dword [rbx + 76], 4
    mov rax, [rel list_w]
    mov [rax + W_DATA_OFF], rbx
    mov rdi, rax
    mov esi, 500
    mov edx, 500
    call widget_measure

    lea rdi, [rel event_buf]
    mov dword [rdi + IE_TYPE_OFF], INPUT_TOUCH_DOWN
    mov dword [rdi + IE_MOUSE_X_OFF], 10
    mov dword [rdi + IE_MOUSE_Y_OFF], 60
    mov rdi, [rel list_w]
    lea rsi, [rel event_buf]
    call widget_handle_input
    cmp eax, 1
    jne .e3

    lea rdi, [rel event_buf]
    mov dword [rdi + IE_TYPE_OFF], INPUT_TOUCH_MOVE
    mov dword [rdi + IE_MOUSE_X_OFF], 10
    mov dword [rdi + IE_MOUSE_Y_OFF], 20
    mov rdi, [rel list_w]
    lea rsi, [rel event_buf]
    call widget_handle_input
    cmp eax, 1
    jne .e3

    lea rdi, [rbx + LD_INERT]
    call inertia_value
    cmp eax, 0
    je .e3

    ; --- Test 4: Parent + hit test ---
    mov edi, WIDGET_CONTAINER
    xor esi, esi
    xor edx, edx
    mov ecx, 300
    mov r8d, 200
    call widget_init
    test rax, rax
    jz .e4
    mov [rel parent_w], rax

    mov edi, WIDGET_LABEL
    mov esi, 10
    mov edx, 10
    mov ecx, 80
    mov r8d, 44
    call widget_init
    mov [rel child1], rax
    mov edi, WIDGET_BUTTON
    mov esi, 10
    mov edx, 70
    mov ecx, 100
    mov r8d, 44
    call widget_init
    mov [rel child2], rax
    mov edi, WIDGET_LABEL
    mov esi, 10
    mov edx, 130
    mov ecx, 80
    mov r8d, 44
    call widget_init
    mov [rel child3], rax

    mov rdi, [rel parent_w]
    mov rsi, [rel child1]
    call widget_add_child
    mov rdi, [rel parent_w]
    mov rsi, [rel child2]
    call widget_add_child
    mov rdi, [rel parent_w]
    mov rsi, [rel child3]
    call widget_add_child

    mov rdi, [rel canvas_ptr]
    call canvas_clear
    mov rdi, [rel parent_w]
    mov rsi, [rel canvas_ptr]
    lea rdx, [rel theme_mem]
    xor ecx, ecx
    xor r8d, r8d
    call widget_render

    mov rdi, [rel parent_w]
    mov esi, 50
    mov edx, 90
    xor ecx, ecx
    xor r8d, r8d
    call widget_hit_test
    cmp rax, [rel child2]
    jne .e4

    ; --- Test 5: Radial menu 6 items ---
    mov edi, WIDGET_RADIAL_MENU
    mov ecx, 220
    mov r8d, 220
    xor esi, esi
    xor edx, edx
    call widget_init
    test rax, rax
    jz .e5
    mov [rel radial_w], rax

    lea rbx, [rel radial_data]
    lea rdi, [rel item_ptrs]
    mov [rbx + 0], rdi
    mov dword [rbx + 8], 6
    mov rdi, [rel font_ptr]
    mov [rbx + 16], rdi
    mov dword [rbx + 24], WHITE
    mov dword [rbx + 28], 0xFFFF6600
    lea rdi, [rbx + 32]
    xor esi, esi
    mov edx, esi
    mov ecx, 0x00010000
    mov r8d, 0x00008000
    call spring_init
    lea rdi, [rbx + 32]
    mov esi, 0x00010000
    call spring_set_target
    mov dword [rbx + 32], 0x00500000
    mov dword [rbx + 56], 1
    mov rax, [rel radial_w]
    mov [rax + W_DATA_OFF], rbx

    mov rdi, [rel canvas_ptr]
    call canvas_clear
    mov rdi, [rel radial_w]
    mov rsi, [rel canvas_ptr]
    lea rdx, [rel theme_mem]
    xor ecx, ecx
    xor r8d, r8d
    call widget_render

    mov rdi, [rel canvas_ptr]
    mov esi, 104
    mov edx, 28
    call canvas_get_pixel
    and eax, 0x00FFFFFF
    cmp eax, 0x00FFFFFF
    je .e5

    write_stdout pass_msg, pass_len
    call widget_system_shutdown
    xor rdi, rdi
    call hal_exit

.e0:
    fail_exit f0, f0l
.e1:
    fail_exit f2, f2l
.e2:
    fail_exit f3, f3l
.e3:
    fail_exit f4, f4l
.e4:
    fail_exit f5, f5l
.e5:
    fail_exit f6, f6l
