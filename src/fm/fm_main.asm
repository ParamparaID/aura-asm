; fm_main.asm — File Manager container/state
%include "src/hal/linux_x86_64/defs.inc"
%include "src/gui/widget.inc"
%include "src/fm/panel.inc"

extern panel_init
extern panel_get_marked
extern panel_navigate
extern panel_go_parent
extern panel_load
extern file_panel_create
extern widget_init
extern widget_add_child
extern widget_layout
extern widget_render
extern widget_handle_input
extern widget_arena_alloc
extern op_copy
extern op_delete
extern vfs_mkdir
extern vfs_path_len

%define FM_DUAL_PANEL              1
%define FM_SINGLE_PANEL            2

%define FM_MODE_OFF                0
%define FM_LEFT_PANEL_OFF          8
%define FM_RIGHT_PANEL_OFF         16
%define FM_ACTIVE_PANEL_OFF        24
%define FM_SPLIT_PANE_OFF          32
%define FM_VIEWER_ACTIVE_OFF       40
%define FM_VIEWER_OFF              48
%define FM_LEFT_WIDGET_OFF         56
%define FM_RIGHT_WIDGET_OFF        64
%define FM_TMP_PATHS_OFF           72
%define FM_TMP_COUNT_OFF           (FM_TMP_PATHS_OFF + (VFS_MAX_PATH * 64))
%define FM_STRUCT_SIZE             (FM_TMP_COUNT_OFF + 8)

%define FM_MAX_INSTANCES           4
%define INPUT_EVENT_MODIFIERS_OFF  24
%define KEY_TAB                    15
%define MOD_CTRL                   0x02

; split pane private data (shared with split_pane.asm)
%define SP_POS                     0
%define SP_DRAG                    4
%define SP_LASTX                   8
%define SP_DATA_SIZE               16

section .bss
    fm_pool                        resb FM_STRUCT_SIZE * FM_MAX_INSTANCES
    fm_used                        resb FM_MAX_INSTANCES

section .text
global fm_init
global fm_render
global fm_handle_input
global fm_copy_selected
global fm_delete_selected
global fm_mkdir

fm_alloc:
    xor ecx, ecx
.loop:
    cmp ecx, FM_MAX_INSTANCES
    jae .fail
    cmp byte [rel fm_used + rcx], 0
    je .slot
    inc ecx
    jmp .loop
.slot:
    mov byte [rel fm_used + rcx], 1
    mov eax, ecx
    imul eax, FM_STRUCT_SIZE
    lea rax, [rel fm_pool + rax]
    ret
.fail:
    xor eax, eax
    ret

fm_init:
    ; (path rdi, mode esi) -> rax FileManager*
    push rbx
    push r12
    push r13
    mov r12, rdi
    mov r13d, esi
    call fm_alloc
    test rax, rax
    jz .fail
    mov rbx, rax
    mov rdi, rbx
    mov ecx, FM_STRUCT_SIZE
    xor eax, eax
    rep stosb

    mov [rbx + FM_MODE_OFF], r13d
    mov rdi, r12
    call vfs_path_len
    mov esi, eax
    mov rdi, r12
    call panel_init
    test rax, rax
    jz .fail
    mov [rbx + FM_LEFT_PANEL_OFF], rax
    mov [rbx + FM_ACTIVE_PANEL_OFF], rax
    mov dword [rax + P_ACTIVE_OFF], 1

    mov rdi, rax
    xor esi, esi
    xor edx, edx
    mov ecx, 400
    mov r8d, 600
    call file_panel_create
    mov [rbx + FM_LEFT_WIDGET_OFF], rax

    cmp r13d, FM_DUAL_PANEL
    jne .single
    mov rdi, r12
    call vfs_path_len
    mov esi, eax
    mov rdi, r12
    call panel_init
    test rax, rax
    jz .fail
    mov [rbx + FM_RIGHT_PANEL_OFF], rax

    mov rdi, rax
    xor esi, esi
    xor edx, edx
    mov ecx, 400
    mov r8d, 600
    call file_panel_create
    mov [rbx + FM_RIGHT_WIDGET_OFF], rax

    mov edi, WIDGET_SPLIT_PANE
    xor esi, esi
    xor edx, edx
    mov ecx, 800
    mov r8d, 600
    call widget_init
    test rax, rax
    jz .fail
    mov [rbx + FM_SPLIT_PANE_OFF], rax
    mov rdi, SP_DATA_SIZE
    call widget_arena_alloc
    test rax, rax
    jz .fail
    mov dword [rax + SP_POS], (400 << 16)
    mov dword [rax + SP_DRAG], 0
    mov dword [rax + SP_LASTX], 0
    mov rdi, [rbx + FM_SPLIT_PANE_OFF]
    mov [rdi + W_DATA_OFF], rax
    mov rsi, [rbx + FM_LEFT_WIDGET_OFF]
    call widget_add_child
    mov rdi, [rbx + FM_SPLIT_PANE_OFF]
    mov rsi, [rbx + FM_RIGHT_WIDGET_OFF]
    call widget_add_child
    mov rdi, [rbx + FM_SPLIT_PANE_OFF]
    call widget_layout
    jmp .ok

.single:
    mov rax, [rbx + FM_LEFT_WIDGET_OFF]
    mov [rbx + FM_SPLIT_PANE_OFF], rax

.ok:
    mov rax, rbx
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

fm_render:
    ; (fm rdi, canvas rsi, theme rdx)
    mov rax, [rdi + FM_SPLIT_PANE_OFF]
    test rax, rax
    jz .out
    mov rdi, rax
    xor ecx, ecx
    xor r8d, r8d
    call widget_render
.out:
    ret

fm_copy_selected:
    ; stub until operation dialog/progress glue is added
    mov eax, -1
    ret

fm_delete_selected:
    mov eax, -1
    ret

fm_mkdir:
    ; dialog-driven mkdir is implemented in next step
    mov eax, -1
    ret

fm_handle_input:
    ; (fm rdi, event rsi) -> eax consumed
    push rbx
    push r12
    mov rbx, rdi
    mov r12, rsi
    mov eax, [r12 + IE_TYPE_OFF]
    cmp eax, INPUT_KEY
    jne .delegate
    cmp dword [r12 + IE_KEY_STATE_OFF], KEY_PRESSED
    jne .delegate
    mov eax, [r12 + IE_KEY_CODE_OFF]
    cmp eax, KEY_TAB
    je .tab
    cmp eax, 63                      ; F5
    je .f5
    cmp eax, 66                      ; F8
    je .f8
    cmp eax, 24                      ; O key
    jne .delegate
    test dword [r12 + INPUT_EVENT_MODIFIERS_OFF], MOD_CTRL
    jz .delegate
    ; toggle mode flag only (MVP)
    cmp dword [rbx + FM_MODE_OFF], FM_DUAL_PANEL
    jne .to_dual
    mov dword [rbx + FM_MODE_OFF], FM_SINGLE_PANEL
    jmp .cons
.to_dual:
    mov dword [rbx + FM_MODE_OFF], FM_DUAL_PANEL
    jmp .cons
.tab:
    cmp dword [rbx + FM_MODE_OFF], FM_DUAL_PANEL
    jne .cons
    mov rax, [rbx + FM_ACTIVE_PANEL_OFF]
    cmp rax, [rbx + FM_LEFT_PANEL_OFF]
    jne .set_left
    mov rax, [rbx + FM_RIGHT_PANEL_OFF]
    mov [rbx + FM_ACTIVE_PANEL_OFF], rax
    mov dword [rax + P_ACTIVE_OFF], 1
    mov rax, [rbx + FM_LEFT_PANEL_OFF]
    mov dword [rax + P_ACTIVE_OFF], 0
    jmp .cons
.set_left:
    mov rax, [rbx + FM_LEFT_PANEL_OFF]
    mov [rbx + FM_ACTIVE_PANEL_OFF], rax
    mov dword [rax + P_ACTIVE_OFF], 1
    mov rax, [rbx + FM_RIGHT_PANEL_OFF]
    mov dword [rax + P_ACTIVE_OFF], 0
    jmp .cons
.f5:
    mov rdi, rbx
    call fm_copy_selected
    jmp .cons
.f8:
    mov rdi, rbx
    call fm_delete_selected
.cons:
    mov eax, 1
    jmp .out
.delegate:
    mov rdi, [rbx + FM_SPLIT_PANE_OFF]
    mov rsi, r12
    call widget_handle_input
.out:
    pop r12
    pop rbx
    ret
