global aura_plugin_init
global aura_plugin_shutdown
global aura_plugin_get_info
global greet_handler

%define AURA_API_VERSION 1

section .data
    cmd_greet        db "greet",0
    help_greet       db "Greet from plugin",0
    info_name        db "test-plugin-cmd",0
    info_author      db "Aura",0
    info_desc        db "command plugin",0

section .text
aura_plugin_init:
    ; rdi = host api table
    push rbx
    test rdi, rdi
    jz .fail
    mov rbx, rdi
    ; api_version()
    mov rax, [rbx + 0]
    call rax
    cmp eax, AURA_API_VERSION
    jne .fail
    ; register_command("greet", greet_handler, help)
    mov rax, [rbx + 8]
    lea rdi, [rel cmd_greet]
    mov esi, 5
    lea rdx, [rel greet_handler]
    lea rcx, [rel help_greet]
    mov r8d, 17
    call rax
    test eax, eax
    jne .fail
    xor eax, eax
    pop rbx
    ret
.fail:
    mov eax, -1
    pop rbx
    ret

aura_plugin_shutdown:
    ret

aura_plugin_get_info:
    ; info_out layout (MVP): [0]=name*, [8]=version, [16]=author*, [24]=desc*
    test rdi, rdi
    jz .out
    lea rax, [rel info_name]
    mov [rdi + 0], rax
    mov dword [rdi + 8], 1
    lea rax, [rel info_author]
    mov [rdi + 16], rax
    lea rax, [rel info_desc]
    mov [rdi + 24], rax
.out:
    ret

greet_handler:
    ; (argc, argv, argv_lens, state) -> 0
    xor eax, eax
    ret
