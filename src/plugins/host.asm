; host.asm — minimal ELF64 shared-object plugin loader (no libc)
%include "src/hal/platform_defs.inc"

extern hal_open
extern hal_close
extern hal_lstat
extern hal_mmap
extern hal_munmap
extern hal_mprotect
extern hal_fork
extern hal_waitpid
extern hal_exit

%define SEEK_END                    2

%define EI_CLASS                    4
%define EI_DATA                     5
%define ELFCLASS64                  2
%define ELFDATA2LSB                 1
%define ET_DYN                      3
%define EM_X86_64                   62

%define EH_E_TYPE_OFF               16
%define EH_E_MACHINE_OFF            18
%define EH_E_PHOFF_OFF              32
%define EH_E_PHENTSIZE_OFF          54
%define EH_E_PHNUM_OFF              56

%define PH_P_TYPE_OFF               0
%define PH_P_FLAGS_OFF              4
%define PH_P_OFFSET_OFF             8
%define PH_P_VADDR_OFF              16
%define PH_P_FILESZ_OFF             32
%define PH_P_MEMSZ_OFF              40

%define PT_LOAD                     1
%define PT_DYNAMIC                  2

%define PF_X                        1
%define PF_W                        2
%define PF_R                        4

%define DT_NULL                     0
%define DT_HASH                     4
%define DT_STRTAB                   5
%define DT_SYMTAB                   6
%define DT_RELA                     7
%define DT_RELASZ                   8
%define DT_RELAENT                  9
%define DT_STRSZ                    10
%define DT_SYMENT                   11
%define DT_PLTRELSZ                 2
%define DT_JMPREL                   23

%define R_X86_64_64                 1
%define R_X86_64_GLOB_DAT           6
%define R_X86_64_JUMP_SLOT          7
%define R_X86_64_RELATIVE           8

%define SHN_UNDEF                   0

%define PLUGIN_UNLOADED             0
%define PLUGIN_LOADED               1
%define PLUGIN_ACTIVE               2
%define PLUGIN_ERROR                3

%define ST_SIZE_OFF                 48
%define ST_STRUCT_SIZE              144

; PluginHandle layout
%define PH_BASE_ADDR_OFF            0
%define PH_TOTAL_SIZE_OFF           8
%define PH_DYNSYM_OFF               16
%define PH_DYNSTR_OFF               24
%define PH_SYM_COUNT_OFF            32
%define PH_NAME_OFF                 40
%define PH_VERSION_OFF              104
%define PH_STATE_OFF                108
%define PH_LOAD_BIAS_OFF            112
%define PH_MIN_VADDR_OFF            120
%define PH_STRSZ_OFF                128
%define PH_SYMENT_OFF               136
%define PLUGIN_HANDLE_SIZE          144

%define PLUGIN_MAX_HANDLES          16

section .bss
    plugin_pool                     resb PLUGIN_HANDLE_SIZE * PLUGIN_MAX_HANDLES
    plugin_used                     resb PLUGIN_MAX_HANDLES
    plugin_stat_tmp                 resb ST_STRUCT_SIZE

section .text
global plugin_load
global plugin_get_symbol
global plugin_unload
global plugin_activate

plugin_cstr_len:
    xor eax, eax
.l:
    cmp byte [rdi + rax], 0
    je .o
    inc eax
    jmp .l
.o:
    ret

plugin_name_from_path:
    ; (src rdi, dst rsi, cap edx)
    push rbx
    push r12
    mov rbx, rdi
    mov r12, rsi
    test edx, edx
    jle .out
    xor ecx, ecx
    mov r8, rbx
.scan:
    mov al, [rbx + rcx]
    test al, al
    jz .copy
    cmp al, '/'
    jne .nxt
    lea r8, [rbx + rcx + 1]
.nxt:
    inc ecx
    jmp .scan
.copy:
    xor ecx, ecx
    dec edx
    js .term
.cl:
    cmp ecx, edx
    jae .term
    mov al, [r8 + rcx]
    mov [r12 + rcx], al
    test al, al
    jz .out
    inc ecx
    jmp .cl
.term:
    mov byte [r12 + rcx], 0
.out:
    pop r12
    pop rbx
    ret

plugin_alloc_handle:
    xor ecx, ecx
.l:
    cmp ecx, PLUGIN_MAX_HANDLES
    jae .fail
    lea rdx, [rel plugin_used]
    cmp byte [rdx + rcx], 0
    je .slot
    inc ecx
    jmp .l
.slot:
    mov byte [rdx + rcx], 1
    mov eax, ecx
    imul eax, PLUGIN_HANDLE_SIZE
    lea rdx, [rel plugin_pool]
    add rdx, rax
    mov rax, rdx
    mov rdi, rax
    mov ecx, PLUGIN_HANDLE_SIZE
    xor eax, eax
    rep stosb
    sub rdi, PLUGIN_HANDLE_SIZE
    mov rax, rdi
    ret
.fail:
    xor eax, eax
    ret

plugin_free_handle:
    ; (handle rdi)
    lea rax, [rel plugin_pool]
    cmp rdi, rax
    jb .out
    lea rcx, [rel plugin_pool + (PLUGIN_HANDLE_SIZE * PLUGIN_MAX_HANDLES)]
    cmp rdi, rcx
    jae .out
    sub rdi, rax
    mov rax, rdi
    xor edx, edx
    mov ecx, PLUGIN_HANDLE_SIZE
    div ecx
    cmp eax, PLUGIN_MAX_HANDLES
    jae .out
    lea rcx, [rel plugin_used]
    mov byte [rcx + rax], 0
.out:
    ret

plugin_apply_rela:
    ; (handle rdi, rela_ptr rsi, rela_size rdx, rela_ent rcx)
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r14, rcx
    cmp r14, 24
    je .okent
    mov r14, 24
.okent:
    xor r15d, r15d
.loop:
    mov rax, r15
    imul rax, r14
    cmp rax, r13
    jae .out
    lea rsi, [r12 + rax]
    mov r8, [rsi + 0]                 ; r_offset
    mov r9, [rsi + 8]                 ; r_info
    mov r10, [rsi + 16]               ; r_addend
    mov rcx, r9
    and ecx, 0xFFFFFFFF               ; type
    mov rdx, [rbx + PH_LOAD_BIAS_OFF]
    lea r11, [rdx + r8]               ; reloc target

    cmp ecx, R_X86_64_RELATIVE
    je .rel_relative
    cmp ecx, R_X86_64_64
    je .rel_sym
    cmp ecx, R_X86_64_GLOB_DAT
    je .rel_sym_noadd
    cmp ecx, R_X86_64_JUMP_SLOT
    je .rel_sym_noadd
    jmp .next

.rel_relative:
    lea rax, [rdx + r10]
    mov [r11], rax
    jmp .next

.rel_sym:
    mov rax, r9
    shr rax, 32                       ; sym idx
    mov r8, [rbx + PH_DYNSYM_OFF]
    mov rcx, [rbx + PH_SYMENT_OFF]
    test rcx, rcx
    jnz .sym_ent_ok
    mov ecx, 24
.sym_ent_ok:
    imul rax, rcx
    lea rax, [r8 + rax]
    movzx ecx, word [rax + 6]         ; st_shndx
    cmp ecx, SHN_UNDEF
    je .write_zero_add
    mov rax, [rax + 8]                ; st_value
    lea rax, [rdx + rax]
    add rax, r10
    mov [r11], rax
    jmp .next
.write_zero_add:
    mov rax, r10
    mov [r11], rax
    jmp .next

.rel_sym_noadd:
    mov rax, r9
    shr rax, 32
    mov r8, [rbx + PH_DYNSYM_OFF]
    mov rcx, [rbx + PH_SYMENT_OFF]
    test rcx, rcx
    jnz .sym_ent_ok2
    mov ecx, 24
.sym_ent_ok2:
    imul rax, rcx
    lea rax, [r8 + rax]
    movzx ecx, word [rax + 6]
    cmp ecx, SHN_UNDEF
    je .write_zero
    mov rax, [rax + 8]
    lea rax, [rdx + rax]
    mov [r11], rax
    jmp .next
.write_zero:
    mov qword [r11], 0

.next:
    inc r15
    jmp .loop
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

plugin_load:
    ; plugin_load(path rdi) -> rax handle or 0
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 64
    mov r12, rdi
    mov [rsp + 56], rdi                ; keep input path pointer
    xor r13d, r13d
    xor r14d, r14d

    ; open + lstat
    mov rsi, O_RDONLY
    xor edx, edx
    mov rdi, r12
    call hal_open
    test rax, rax
    js .fail
    mov [rsp + 0], rax                ; fd

    lea rsi, [rel plugin_stat_tmp]
    mov rdi, r12
    call hal_lstat
    test rax, rax
    js .close_fail

    mov r13, [rel plugin_stat_tmp + ST_SIZE_OFF]
    test r13, r13
    jle .close_fail

    ; map file read-only
    xor rdi, rdi
    mov rsi, r13
    mov edx, PROT_READ
    mov ecx, MAP_PRIVATE
    mov r8, [rsp + 0]
    xor r9, r9
    call hal_mmap
    test rax, rax
    js .close_fail
    mov r14, rax                      ; file_map

    mov rdi, [rsp + 0]
    call hal_close

    ; ELF header checks
    cmp byte [r14 + 0], 0x7F
    jne .unmap_file_fail
    cmp byte [r14 + 1], 'E'
    jne .unmap_file_fail
    cmp byte [r14 + 2], 'L'
    jne .unmap_file_fail
    cmp byte [r14 + 3], 'F'
    jne .unmap_file_fail
    cmp byte [r14 + EI_CLASS], ELFCLASS64
    jne .unmap_file_fail
    cmp byte [r14 + EI_DATA], ELFDATA2LSB
    jne .unmap_file_fail
    cmp word [r14 + EH_E_TYPE_OFF], ET_DYN
    jne .unmap_file_fail
    cmp word [r14 + EH_E_MACHINE_OFF], EM_X86_64
    jne .unmap_file_fail

    mov rbx, [r14 + EH_E_PHOFF_OFF]
    movzx r15d, word [r14 + EH_E_PHNUM_OFF]
    movzx r8d, word [r14 + EH_E_PHENTSIZE_OFF]
    cmp r8d, 56
    jb .unmap_file_fail

    ; find LOAD span [min_vaddr, max_vaddr)
    mov qword [rsp + 16], -1          ; min
    mov qword [rsp + 24], 0           ; max
    xor ecx, ecx
.ph_span_loop:
    cmp ecx, r15d
    jae .ph_span_done
    mov eax, ecx
    imul rax, r8
    mov rsi, r14
    add rsi, rbx
    add rsi, rax
    cmp dword [rsi + PH_P_TYPE_OFF], PT_LOAD
    jne .ph_span_next
    mov rax, [rsi + PH_P_VADDR_OFF]
    cmp rax, [rsp + 16]
    jae .min_ok
    mov [rsp + 16], rax
.min_ok:
    mov rdx, [rsi + PH_P_MEMSZ_OFF]
    add rdx, rax
    cmp rdx, [rsp + 24]
    jbe .ph_span_next
    mov [rsp + 24], rdx
.ph_span_next:
    inc ecx
    jmp .ph_span_loop
.ph_span_done:
    cmp qword [rsp + 16], -1
    je .unmap_file_fail
    mov rax, [rsp + 16]
    and rax, -4096
    mov [rsp + 16], rax
    mov rdx, [rsp + 24]
    add rdx, 4095
    and rdx, -4096
    mov [rsp + 24], rdx
    sub rdx, rax
    test rdx, rdx
    jle .unmap_file_fail
    mov [rsp + 32], rdx               ; total span

    ; allocate image
    xor rdi, rdi
    mov rsi, rdx
    mov edx, PROT_READ | PROT_WRITE | PROT_EXEC
    mov ecx, MAP_PRIVATE | MAP_ANONYMOUS
    mov r8, -1
    xor r9, r9
    call hal_mmap
    test rax, rax
    js .unmap_file_fail
    mov [rsp + 40], rax               ; image base mapped
    mov rdx, [rsp + 16]               ; min_vaddr
    sub rax, rdx
    mov [rsp + 48], rax               ; load_bias

    ; copy PT_LOAD segments
    movzx r8d, word [r14 + EH_E_PHENTSIZE_OFF]
    xor ecx, ecx
.ph_copy_loop:
    cmp ecx, r15d
    jae .ph_copy_done
    mov eax, ecx
    imul rax, r8
    mov rsi, r14
    add rsi, rbx
    add rsi, rax
    cmp dword [rsi + PH_P_TYPE_OFF], PT_LOAD
    jne .ph_copy_next
    mov rax, [rsi + PH_P_VADDR_OFF]
    add rax, [rsp + 48]
    mov r9, rax                        ; dst
    mov r10, [rsi + PH_P_OFFSET_OFF]
    lea r11, [r14 + r10]               ; src
    mov rdx, [rsi + PH_P_FILESZ_OFF]
    xor eax, eax
.cpy:
    cmp rax, rdx
    jae .zero
    mov dil, [r11 + rax]
    mov [r9 + rax], dil
    inc rax
    jmp .cpy
.zero:
    mov r10, [rsi + PH_P_MEMSZ_OFF]
    cmp r10, rdx
    jbe .ph_copy_next
    mov rax, rdx
.zloop:
    cmp rax, r10
    jae .ph_copy_next
    mov byte [r9 + rax], 0
    inc rax
    jmp .zloop
.ph_copy_next:
    inc ecx
    jmp .ph_copy_loop
.ph_copy_done:

    ; allocate handle
    call plugin_alloc_handle
    test rax, rax
    jz .unmap_image_fail
    mov r12, rax
    mov rax, [rsp + 40]
    mov [r12 + PH_BASE_ADDR_OFF], rax
    mov rax, [rsp + 32]
    mov [r12 + PH_TOTAL_SIZE_OFF], rax
    mov rax, [rsp + 48]
    mov [r12 + PH_LOAD_BIAS_OFF], rax
    mov rax, [rsp + 16]
    mov [r12 + PH_MIN_VADDR_OFF], rax
    mov dword [r12 + PH_VERSION_OFF], 1
    mov dword [r12 + PH_STATE_OFF], PLUGIN_LOADED
    mov rdi, [rsp + 56]
    lea rsi, [r12 + PH_NAME_OFF]
    mov edx, 64
    call plugin_name_from_path

    ; parse PT_DYNAMIC and dynamic tags
    movzx r8d, word [r14 + EH_E_PHENTSIZE_OFF]
    mov qword [rsp + 0], 0            ; rela ptr
    mov qword [rsp + 8], 0            ; rela size
    mov qword [rsp + 16], 24          ; rela ent
    mov qword [rsp + 24], 0           ; jmprel ptr
    mov qword [rsp + 32], 0           ; pltrelsz
    xor ecx, ecx
    mov qword [rsp + 56], 0           ; dyn ptr
.ph_dyn_loop:
    cmp ecx, r15d
    jae .ph_dyn_done
    mov eax, ecx
    imul rax, r8
    mov rsi, r14
    add rsi, rbx
    add rsi, rax
    cmp dword [rsi + PH_P_TYPE_OFF], PT_DYNAMIC
    jne .ph_dyn_next
    mov rax, [rsi + PH_P_OFFSET_OFF]
    add rax, r14
    mov [rsp + 56], rax
    jmp .ph_dyn_done
.ph_dyn_next:
    inc ecx
    jmp .ph_dyn_loop
.ph_dyn_done:
    cmp qword [rsp + 56], 0
    je .protect_segments

    mov rsi, [rsp + 56]
.dyn_iter:
    mov rax, [rsi + 0]                 ; tag
    mov rdx, [rsi + 8]                 ; val
    cmp rax, DT_NULL
    je .dyn_done
    cmp rax, DT_SYMTAB
    jne .dyn_str
    mov rcx, [rsp + 48]
    add rcx, rdx
    mov [r12 + PH_DYNSYM_OFF], rcx
    jmp .dyn_next
.dyn_str:
    cmp rax, DT_STRTAB
    jne .dyn_hash
    mov rcx, [rsp + 48]
    add rcx, rdx
    mov [r12 + PH_DYNSTR_OFF], rcx
    jmp .dyn_next
.dyn_hash:
    cmp rax, DT_HASH
    jne .dyn_rela
    mov rcx, [rsp + 48]
    add rcx, rdx
    mov eax, [rcx + 4]                 ; nchain
    mov [r12 + PH_SYM_COUNT_OFF], rax
    jmp .dyn_next
.dyn_rela:
    cmp rax, DT_RELA
    jne .dyn_relasz
    mov rcx, [rsp + 48]
    add rcx, rdx
    mov [rsp + 0], rcx                 ; rela ptr
    jmp .dyn_next
.dyn_relasz:
    cmp rax, DT_RELASZ
    jne .dyn_relaent
    mov [rsp + 8], rdx                 ; rela size
    jmp .dyn_next
.dyn_relaent:
    cmp rax, DT_RELAENT
    jne .dyn_jmprel
    mov [rsp + 16], rdx                ; rela ent
    jmp .dyn_next
.dyn_jmprel:
    cmp rax, DT_JMPREL
    jne .dyn_pltrelsz
    mov rcx, [rsp + 48]
    add rcx, rdx
    mov [rsp + 24], rcx                ; jmprel
    jmp .dyn_next
.dyn_pltrelsz:
    cmp rax, DT_PLTRELSZ
    jne .dyn_strsz
    mov [rsp + 32], rdx                ; pltrelsz
    jmp .dyn_next
.dyn_strsz:
    cmp rax, DT_STRSZ
    jne .dyn_syment
    mov [r12 + PH_STRSZ_OFF], rdx
    jmp .dyn_next
.dyn_syment:
    cmp rax, DT_SYMENT
    jne .dyn_next
    mov [r12 + PH_SYMENT_OFF], rdx
.dyn_next:
    add rsi, 16
    jmp .dyn_iter
.dyn_done:
    ; apply RELA and JMPREL relocations
    cmp qword [rsp + 0], 0
    je .rel_plt
    mov rdi, r12
    mov rsi, [rsp + 0]
    mov rdx, [rsp + 8]
    mov rcx, [rsp + 16]
    test rcx, rcx
    jnz .do_rela
    mov ecx, 24
.do_rela:
    call plugin_apply_rela
.rel_plt:
    cmp qword [rsp + 24], 0
    je .protect_segments
    mov rdi, r12
    mov rsi, [rsp + 24]
    mov rdx, [rsp + 32]
    mov rcx, [rsp + 16]
    test rcx, rcx
    jnz .do_plt
    mov ecx, 24
.do_plt:
    call plugin_apply_rela

.protect_segments:
    movzx r8d, word [r14 + EH_E_PHENTSIZE_OFF]
    xor ecx, ecx
.ph_prot_loop:
    cmp ecx, r15d
    jae .ok
    mov eax, ecx
    imul rax, r8
    mov rsi, r14
    add rsi, rbx
    add rsi, rax
    cmp dword [rsi + PH_P_TYPE_OFF], PT_LOAD
    jne .ph_prot_next
    mov rax, [rsi + PH_P_VADDR_OFF]
    add rax, [rsp + 48]
    and rax, -4096
    mov r10, [rsi + PH_P_VADDR_OFF]
    add r10, [rsp + 48]
    add r10, [rsi + PH_P_MEMSZ_OFF]
    add r10, 4095
    and r10, -4096
    sub r10, rax
    mov edx, 0
    test dword [rsi + PH_P_FLAGS_OFF], PF_R
    jz .no_r
    or edx, PROT_READ
.no_r:
    test dword [rsi + PH_P_FLAGS_OFF], PF_W
    jz .no_w
    or edx, PROT_WRITE
.no_w:
    test dword [rsi + PH_P_FLAGS_OFF], PF_X
    jz .no_x
    or edx, PROT_EXEC
.no_x:
    mov rdi, rax
    mov rsi, r10
    call hal_mprotect
.ph_prot_next:
    inc ecx
    jmp .ph_prot_loop

.ok:
    ; release file map
    test r14, r14
    jz .ret_ok
    mov rdi, r14
    mov rsi, r13
    call hal_munmap
.ret_ok:
    mov rax, r12
    add rsp, 64
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

.close_fail:
    mov rdi, [rsp + 0]
    call hal_close
    jmp .fail

.unmap_image_fail:
    mov rdi, [rsp + 40]
    mov rsi, [rsp + 32]
    call hal_munmap
    jmp .unmap_file_fail

.unmap_file_fail:
    test r14, r14
    jz .fail
    mov rdi, r14
    mov rsi, r13
    call hal_munmap
.fail:
    xor eax, eax
    add rsp, 64
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

plugin_get_symbol:
    ; plugin_get_symbol(handle rdi, name rsi, name_len edx) -> rax addr or 0
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi
    mov r12, rsi
    mov r13d, edx
    test rbx, rbx
    jz .not_found
    test r12, r12
    jz .not_found
    cmp r13d, 0
    jg .len_ok
    mov rdi, r12
    call plugin_cstr_len
    mov r13d, eax
.len_ok:
    mov r14, [rbx + PH_DYNSYM_OFF]
    mov r15, [rbx + PH_DYNSTR_OFF]
    test r14, r14
    jz .not_found
    test r15, r15
    jz .not_found
    mov r11, [rbx + PH_SYMENT_OFF]
    test r11, r11
    jnz .ent_ok
    mov r11d, 24
.ent_ok:
    mov r10, [rbx + PH_SYM_COUNT_OFF]
    test r10, r10
    jnz .cnt_ok
    mov r10d, 256
.cnt_ok:
    mov r9, [rbx + PH_STRSZ_OFF]
    xor ecx, ecx
.sym_loop:
    cmp rcx, r10
    jae .not_found
    mov rax, rcx
    imul rax, r11
    lea rdi, [r14 + rax]
    mov edx, [rdi + 0]                 ; st_name
    test edx, edx
    jz .next
    test r9, r9
    jz .str_ok
    cmp rdx, r9
    jae .next
.str_ok:
    lea rsi, [r15 + rdx]
    mov eax, 0
.cmp_loop:
    cmp eax, r13d
    jae .cmp_term
    mov dl, [rsi + rax]
    cmp dl, [r12 + rax]
    jne .next
    inc eax
    jmp .cmp_loop
.cmp_term:
    cmp byte [rsi + r13], 0
    jne .next
    mov rax, [rdi + 8]                 ; st_value
    add rax, [rbx + PH_LOAD_BIAS_OFF]
    jmp .out
.next:
    inc rcx
    jmp .sym_loop
.not_found:
    xor eax, eax
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

plugin_validate_exports:
    ; plugin_validate_exports(handle rdi) -> eax 0/-1
    push rbx
    mov rbx, rdi
    test rbx, rbx
    jz .fail
    ; required exports: init/shutdown/get_info
    mov rdi, rbx
    lea rsi, [rel plugin_init_name]
    mov edx, 16
    call plugin_get_symbol
    test rax, rax
    jz .fail
    mov rdi, rbx
    lea rsi, [rel plugin_shutdown_name]
    mov edx, 20
    call plugin_get_symbol
    test rax, rax
    jz .fail
    mov rdi, rbx
    lea rsi, [rel plugin_get_info_name]
    mov edx, 20
    call plugin_get_symbol
    test rax, rax
    jz .fail
    xor eax, eax
    pop rbx
    ret
.fail:
    mov eax, -1
    pop rbx
    ret

plugin_activate:
    ; plugin_activate(handle rdi, host_api rsi) -> eax 0/-1
    push rbx
    push r12
    sub rsp, 16
    mov rbx, rdi
    mov r12, rsi
    test rbx, rbx
    jz .fail
    mov rdi, rbx
    call plugin_validate_exports
    test eax, eax
    jne .fail_set
    mov rdi, rbx
    lea rsi, [rel plugin_init_name]
    mov edx, 16
    call plugin_get_symbol
    test rax, rax                        ; init fn ptr
    jz .ok

    ; crash isolation MVP: run init in child first.
    mov [rsp + 0], rax
    call hal_fork
    test rax, rax
    js .fail_set
    jz .child
    ; parent
    mov [rsp + 8], rax                   ; child pid
    lea rsi, [rsp + 12]                  ; int status
    mov rdi, [rsp + 8]
    xor edx, edx
    call hal_waitpid
    test rax, rax
    js .fail_set
    mov eax, [rsp + 12]
    test eax, eax
    jne .fail_set
    ; run real init in parent so registrations are persisted.
    mov rax, [rsp + 0]
    mov rdi, r12
    call rax
    test eax, eax
    jnz .fail_set
    jmp .ok

.child:
    mov rax, [rsp + 0]
    mov rdi, r12
    call rax
    test eax, eax
    jz .child_ok
    mov edi, 1
    call hal_exit
.child_ok:
    xor edi, edi
    call hal_exit
.ok:
    mov dword [rbx + PH_STATE_OFF], PLUGIN_ACTIVE
    xor eax, eax
    add rsp, 16
    pop r12
    pop rbx
    ret
.fail_set:
    mov dword [rbx + PH_STATE_OFF], PLUGIN_ERROR
.fail:
    mov eax, -1
    add rsp, 16
    pop r12
    pop rbx
    ret

plugin_init_name:
    db "aura_plugin_init", 0

plugin_unload:
    ; plugin_unload(handle rdi) -> eax 0/-1
    push rbx
    mov rbx, rdi
    test rbx, rbx
    jz .fail
    ; call shutdown if present
    mov rdi, rbx
    lea rsi, [rel plugin_shutdown_name]
    mov edx, 20
    call plugin_get_symbol
    test rax, rax
    jz .no_shutdown
    call rax
.no_shutdown:
    mov rdi, [rbx + PH_BASE_ADDR_OFF]
    mov rsi, [rbx + PH_TOTAL_SIZE_OFF]
    test rdi, rdi
    jz .mark
    test rsi, rsi
    jz .mark
    call hal_munmap
.mark:
    mov dword [rbx + PH_STATE_OFF], PLUGIN_UNLOADED
    mov qword [rbx + PH_BASE_ADDR_OFF], 0
    mov qword [rbx + PH_TOTAL_SIZE_OFF], 0
    mov rdi, rbx
    call plugin_free_handle
    xor eax, eax
    pop rbx
    ret
.fail:
    mov eax, -1
    pop rbx
    ret

plugin_shutdown_name:
    db "aura_plugin_shutdown", 0
plugin_get_info_name:
    db "aura_plugin_get_info", 0
