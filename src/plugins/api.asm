; api.asm — plugin ABI table + registries
%include "src/hal/linux_x86_64/defs.inc"
%include "src/fm/vfs.inc"

extern hal_write
extern hal_mmap
extern hal_munmap

%define AURA_API_VERSION            1
%define HOST_API_ENTRY_COUNT        16

%define PLUGIN_MAX_LOADED           64
%define PLUGIN_MAX_COMMANDS         64
%define PLUGIN_MAX_VIEWERS          32
%define PLUGIN_MAX_ARCHIVES         32

; PluginCommand layout
%define PC_NAME_OFF                 0
%define PC_NAME_LEN_OFF             8
%define PC_CALLBACK_OFF             16
%define PC_HELP_PTR_OFF             24
%define PC_HELP_LEN_OFF             32
%define PC_PLUGIN_OFF               40
%define PLUGIN_COMMAND_SIZE         48

; Ext handler layout
%define EH_EXT_OFF                  0
%define EH_EXT_LEN_OFF              8
%define EH_HANDLER_OFF              16
%define EH_PLUGIN_OFF               24
%define EXT_HANDLER_SIZE            32

section .data
    api_entry_table:
        dq aura_api_version_fn
        dq plugin_register_command
        dq plugin_register_widget
        dq plugin_register_vfs
        dq plugin_register_viewer
        dq plugin_register_archive
        dq plugin_register_theme
        dq plugin_register_gesture
        dq plugin_register_hub_widget
        dq plugin_subscribe_event
        dq plugin_get_theme
        dq plugin_get_canvas
        dq plugin_log_message
        dq plugin_alloc_memory
        dq plugin_free_memory
        dq plugin_get_config_dir

    plugin_cfg_dir db "/tmp/aura/plugins",0

section .bss
    plugin_current_handle      resq 1
    plugin_loaded              resq PLUGIN_MAX_LOADED
    plugin_loaded_count        resd 1
    plugin_commands            resb PLUGIN_COMMAND_SIZE * PLUGIN_MAX_COMMANDS
    plugin_commands_count      resd 1
    plugin_viewers             resb EXT_HANDLER_SIZE * PLUGIN_MAX_VIEWERS
    plugin_viewers_count       resd 1
    plugin_archives            resb EXT_HANDLER_SIZE * PLUGIN_MAX_ARCHIVES
    plugin_archives_count      resd 1
    plugin_theme_ptr           resq 1
    plugin_canvas_ptr          resq 1
    plugin_vfs_register_fn     resq 1
    plugin_alloc_sizes         resq 256

section .text
global plugin_api_init
global plugin_api_get_host_table
global plugin_api_set_current_plugin
global plugin_api_set_theme_ptr
global plugin_api_set_canvas_ptr
global plugin_api_bind_vfs_register
global plugin_registry_add
global plugin_registry_remove_handle
global plugin_registry_count
global plugin_registry_get_name
global plugin_registry_find
global plugin_unregister_all_for_plugin
global plugin_command_dispatch
global plugin_viewer_find_handler
global plugin_archive_find_handler
global plugin_register_command
global plugin_register_widget
global plugin_register_vfs
global plugin_register_viewer
global plugin_register_archive
global plugin_register_theme
global plugin_register_gesture
global plugin_register_hub_widget
global plugin_subscribe_event
global plugin_get_theme
global plugin_get_canvas
global plugin_log_message
global plugin_alloc_memory
global plugin_free_memory
global plugin_get_config_dir

plugin_strlen:
    xor eax, eax
.l:
    cmp byte [rdi + rax], 0
    je .o
    inc eax
    jmp .l
.o:
    ret

plugin_streq_len:
    ; (a rdi, b rsi, len edx) -> eax 1/0
    xor eax, eax
    test edx, edx
    jz .yes
.cp:
    mov cl, [rdi]
    cmp cl, [rsi]
    jne .no
    inc rdi
    inc rsi
    dec edx
    jnz .cp
.yes:
    mov eax, 1
    ret
.no:
    xor eax, eax
    ret

plugin_api_init:
    mov dword [rel plugin_loaded_count], 0
    mov dword [rel plugin_commands_count], 0
    mov dword [rel plugin_viewers_count], 0
    mov dword [rel plugin_archives_count], 0
    mov qword [rel plugin_current_handle], 0
    xor eax, eax
    ret

plugin_api_get_host_table:
    lea rax, [rel api_entry_table]
    ret

plugin_api_set_current_plugin:
    mov [rel plugin_current_handle], rdi
    ret

plugin_api_set_theme_ptr:
    mov [rel plugin_theme_ptr], rdi
    ret

plugin_api_set_canvas_ptr:
    mov [rel plugin_canvas_ptr], rdi
    ret

plugin_api_bind_vfs_register:
    ; (fn_ptr rdi)
    mov [rel plugin_vfs_register_fn], rdi
    ret

plugin_registry_add:
    ; (handle rdi) -> eax 0/-1
    mov ecx, [rel plugin_loaded_count]
    cmp ecx, PLUGIN_MAX_LOADED
    jae .fail
    mov [rel plugin_loaded + rcx*8], rdi
    inc ecx
    mov [rel plugin_loaded_count], ecx
    xor eax, eax
    ret
.fail:
    mov eax, -1
    ret

plugin_registry_remove_handle:
    ; (handle rdi) -> eax 0/-1
    xor ecx, ecx
.find:
    cmp ecx, [rel plugin_loaded_count]
    jae .fail
    mov rax, [rel plugin_loaded + rcx*8]
    cmp rax, rdi
    je .rm
    inc ecx
    jmp .find
.rm:
    mov edx, ecx
.sh:
    inc edx
    cmp edx, [rel plugin_loaded_count]
    jae .done
    mov rax, [rel plugin_loaded + rdx*8]
    mov [rel plugin_loaded + rcx*8], rax
    inc ecx
    jmp .sh
.done:
    dec dword [rel plugin_loaded_count]
    xor eax, eax
    ret
.fail:
    mov eax, -1
    ret

plugin_registry_count:
    mov eax, [rel plugin_loaded_count]
    ret

plugin_registry_get_name:
    ; (index edi) -> rax ptr, edx len; 0 if bad
    cmp edi, [rel plugin_loaded_count]
    jae .bad
    mov rax, [rel plugin_loaded + rdi*8]
    test rax, rax
    jz .bad
    lea rax, [rax + 40]                 ; PH_NAME_OFF
    mov rdi, rax
    call plugin_strlen
    mov edx, eax
    mov rax, rdi
    ret
.bad:
    xor eax, eax
    xor edx, edx
    ret

plugin_registry_find:
    ; (name rdi, len esi) -> rax handle or 0
    push rbx
    push r12
    mov rbx, rdi
    mov r12d, esi
    xor ecx, ecx
.loop:
    cmp ecx, [rel plugin_loaded_count]
    jae .none
    mov rax, [rel plugin_loaded + rcx*8]
    test rax, rax
    jz .n
    lea rdi, [rax + 40]
    call plugin_strlen
    cmp eax, r12d
    jne .n
    mov r8d, ecx
    mov rdi, [rel plugin_loaded + rcx*8]
    lea rdi, [rdi + 40]
    mov rsi, rbx
    mov edx, r12d
    call plugin_streq_len
    cmp eax, 1
    jne .n
    mov rax, [rel plugin_loaded + r8*8]
    jmp .out
.n:
    inc ecx
    jmp .loop
.none:
    xor eax, eax
.out:
    pop r12
    pop rbx
    ret

plugin_unregister_all_for_plugin:
    ; (handle rdi)
    push rbx
    mov rbx, rdi
    xor ecx, ecx
.cmd_loop:
    cmp ecx, [rel plugin_commands_count]
    jae .viewers
    mov eax, ecx
    imul eax, PLUGIN_COMMAND_SIZE
    lea rax, [rel plugin_commands + rax]
    cmp [rax + PC_PLUGIN_OFF], rbx
    jne .cmd_next
    ; remove by shift
    mov edx, ecx
.cmd_shift:
    inc edx
    cmp edx, [rel plugin_commands_count]
    jae .cmd_dec
    mov eax, edx
    imul eax, PLUGIN_COMMAND_SIZE
    lea r8, [rel plugin_commands + rax]
    mov eax, ecx
    imul eax, PLUGIN_COMMAND_SIZE
    lea r9, [rel plugin_commands + rax]
    mov rsi, r8
    mov rdi, r9
    mov r10d, PLUGIN_COMMAND_SIZE
    mov ecx, r10d
    cld
    rep movsb
    jmp .cmd_shift
.cmd_dec:
    dec dword [rel plugin_commands_count]
    jmp .cmd_loop
.cmd_next:
    inc ecx
    jmp .cmd_loop

.viewers:
    xor ecx, ecx
.v_loop:
    cmp ecx, [rel plugin_viewers_count]
    jae .archives
    mov eax, ecx
    shl eax, 5
    lea rax, [rel plugin_viewers + rax]
    cmp [rax + EH_PLUGIN_OFF], rbx
    jne .v_next
    mov edx, ecx
.v_shift:
    inc edx
    cmp edx, [rel plugin_viewers_count]
    jae .v_dec
    mov eax, edx
    shl eax, 5
    lea r8, [rel plugin_viewers + rax]
    mov eax, ecx
    shl eax, 5
    lea r9, [rel plugin_viewers + rax]
    mov rsi, r8
    mov rdi, r9
    mov r10d, EXT_HANDLER_SIZE
    mov ecx, r10d
    cld
    rep movsb
    jmp .v_shift
.v_dec:
    dec dword [rel plugin_viewers_count]
    jmp .v_loop
.v_next:
    inc ecx
    jmp .v_loop

.archives:
    xor ecx, ecx
.a_loop:
    cmp ecx, [rel plugin_archives_count]
    jae .out
    mov eax, ecx
    shl eax, 5
    lea rax, [rel plugin_archives + rax]
    cmp [rax + EH_PLUGIN_OFF], rbx
    jne .a_next
    mov edx, ecx
.a_shift:
    inc edx
    cmp edx, [rel plugin_archives_count]
    jae .a_dec
    mov eax, edx
    shl eax, 5
    lea r8, [rel plugin_archives + rax]
    mov eax, ecx
    shl eax, 5
    lea r9, [rel plugin_archives + rax]
    mov rsi, r8
    mov rdi, r9
    mov r10d, EXT_HANDLER_SIZE
    mov ecx, r10d
    cld
    rep movsb
    jmp .a_shift
.a_dec:
    dec dword [rel plugin_archives_count]
    jmp .a_loop
.a_next:
    inc ecx
    jmp .a_loop
.out:
    pop rbx
    ret

plugin_command_dispatch:
    ; (cmd_name rdi, cmd_len rsi, cmd_node rdx, state rcx) -> eax code or -1
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12d, esi
    mov r13, rdx
    xor eax, eax
.loop:
    cmp eax, [rel plugin_commands_count]
    jae .none
    mov r11d, eax
    mov edx, eax
    imul edx, PLUGIN_COMMAND_SIZE
    lea r8, [rel plugin_commands + rdx]
    mov edx, [r8 + PC_NAME_LEN_OFF]
    cmp edx, r12d
    jne .n
    mov r10, r8
    mov rdi, [r8 + PC_NAME_OFF]
    mov rsi, rbx
    call plugin_streq_len
    cmp eax, 1
    jne .n
    mov r9, [r10 + PC_CALLBACK_OFF]
    test r9, r9
    jz .none
    mov edi, [r13 + 4]                  ; argc
    lea rsi, [r13 + 8]                  ; argv array
    lea rdx, [r13 + 136]                ; argv lens
    ; rcx already state from caller
    call r9
    jmp .out
.n:
    mov eax, r11d
    inc eax
    jmp .loop
.none:
    mov eax, -1
.out:
    pop r13
    pop r12
    pop rbx
    ret

plugin_find_ext_handler:
    ; (path rdi, len esi, table rdx, count_ptr rcx) -> rax handler or 0
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12d, esi
    mov r13, rdx
    mov r11, rcx                         ; count_ptr
    xor eax, eax
    xor r8d, r8d                        ; last dot idx
.scan:
    cmp eax, r12d
    jae .have
    cmp byte [rbx + rax], '.'
    jne .snext
    mov r8d, eax
    inc r8d
.snext:
    inc eax
    jmp .scan
.have:
    test r8d, r8d
    jz .none
    mov r9d, r12d
    sub r9d, r8d                         ; ext len
    jle .none
    xor eax, eax
.loop:
    cmp eax, [r11]
    jae .none
    mov r10d, eax
    mov edx, eax
    shl edx, 5
    lea rdx, [r13 + rdx]
    mov r10d, [rdx + EH_EXT_LEN_OFF]
    cmp r10d, r9d
    jne .next
    lea rdi, [rbx + r8]
    mov rsi, [rdx + EH_EXT_OFF]
    mov edx, r9d
    call plugin_streq_len
    cmp eax, 1
    jne .next
    mov rax, [rdx + EH_HANDLER_OFF]
    jmp .out
.next:
    mov eax, r10d
    inc eax
    jmp .loop
.none:
    xor eax, eax
.out:
    pop r13
    pop r12
    pop rbx
    ret

plugin_viewer_find_handler:
    lea rdx, [rel plugin_viewers]
    lea rcx, [rel plugin_viewers_count]
    call plugin_find_ext_handler
    ret

plugin_archive_find_handler:
    lea rdx, [rel plugin_archives]
    lea rcx, [rel plugin_archives_count]
    call plugin_find_ext_handler
    ret

; ---- Host API entries ----
aura_api_version_fn:
    mov eax, AURA_API_VERSION
    ret

plugin_register_command:
    ; (name rdi, name_len rsi, callback rdx, help rcx, help_len r8)
    mov r10, rdx
    mov eax, [rel plugin_commands_count]
    cmp eax, PLUGIN_MAX_COMMANDS
    jae .fail
    mov edx, eax
    imul edx, PLUGIN_COMMAND_SIZE
    lea r9, [rel plugin_commands + rdx]
    mov [r9 + PC_NAME_OFF], rdi
    mov [r9 + PC_NAME_LEN_OFF], esi
    mov [r9 + PC_CALLBACK_OFF], r10
    mov [r9 + PC_HELP_PTR_OFF], rcx
    mov [r9 + PC_HELP_LEN_OFF], r8d
    mov rax, [rel plugin_current_handle]
    mov [r9 + PC_PLUGIN_OFF], rax
    inc dword [rel plugin_commands_count]
    xor eax, eax
    ret
.fail:
    mov eax, -1
    ret

plugin_register_widget:
    xor eax, eax
    ret

plugin_register_vfs:
    ; (scheme rdi, scheme_len rsi, provider rdx)
    test rdi, rdi
    jz .f
    test rdx, rdx
    jz .f
    mov [rdx + VFS_NAME_OFF], rdi
    mov r11, [rel plugin_vfs_register_fn]
    test r11, r11
    jz .f
    mov rdi, rdx
    call r11
    ret
.f:
    mov eax, -1
    ret

plugin_register_viewer:
    ; (ext rdi, ext_len rsi, handler rdx)
    mov r10, rdx
    mov eax, [rel plugin_viewers_count]
    cmp eax, PLUGIN_MAX_VIEWERS
    jae .fail
    mov edx, eax
    shl edx, 5
    lea rcx, [rel plugin_viewers + rdx]
    mov [rcx + EH_EXT_OFF], rdi
    mov [rcx + EH_EXT_LEN_OFF], esi
    mov [rcx + EH_HANDLER_OFF], r10
    mov rax, [rel plugin_current_handle]
    mov [rcx + EH_PLUGIN_OFF], rax
    inc dword [rel plugin_viewers_count]
    xor eax, eax
    ret
.fail:
    mov eax, -1
    ret

plugin_register_archive:
    mov r10, rdx
    mov eax, [rel plugin_archives_count]
    cmp eax, PLUGIN_MAX_ARCHIVES
    jae .fail
    mov edx, eax
    shl edx, 5
    lea rcx, [rel plugin_archives + rdx]
    mov [rcx + EH_EXT_OFF], rdi
    mov [rcx + EH_EXT_LEN_OFF], esi
    mov [rcx + EH_HANDLER_OFF], r10
    mov rax, [rel plugin_current_handle]
    mov [rcx + EH_PLUGIN_OFF], rax
    inc dword [rel plugin_archives_count]
    xor eax, eax
    ret
.fail:
    mov eax, -1
    ret

plugin_register_theme:
    xor eax, eax
    ret
plugin_register_gesture:
    xor eax, eax
    ret
plugin_register_hub_widget:
    xor eax, eax
    ret
plugin_subscribe_event:
    xor eax, eax
    ret

plugin_get_theme:
    mov rax, [rel plugin_theme_ptr]
    ret

plugin_get_canvas:
    mov rax, [rel plugin_canvas_ptr]
    ret

plugin_log_message:
    ; (level rdi, msg rsi, len rdx)
    mov rdi, STDOUT
    call hal_write
    xor eax, eax
    ret

plugin_alloc_memory:
    ; (size rdi) -> ptr rax, stores size in side-table by 4K slot
    push rbx
    mov rbx, rdi
    xor rdi, rdi
    mov rsi, rbx
    mov rdx, PROT_READ | PROT_WRITE
    mov rcx, MAP_PRIVATE | MAP_ANONYMOUS
    mov r8, -1
    xor r9, r9
    call hal_mmap
    test rax, rax
    js .fail
    mov rcx, rax
    shr rcx, 12
    and ecx, 255
    mov [rel plugin_alloc_sizes + rcx*8], rbx
    pop rbx
    ret
.fail:
    xor eax, eax
    pop rbx
    ret

plugin_free_memory:
    ; (ptr rdi)
    push rbx
    mov rbx, rdi
    mov rcx, rdi
    shr rcx, 12
    and ecx, 255
    mov rsi, [rel plugin_alloc_sizes + rcx*8]
    test rsi, rsi
    jz .out
    call hal_munmap
    mov qword [rel plugin_alloc_sizes + rcx*8], 0
.out:
    pop rbx
    ret

plugin_get_config_dir:
    lea rax, [rel plugin_cfg_dir]
    ret
