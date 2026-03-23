; panel.asm — File manager panel model and navigation
%include "src/hal/linux_x86_64/defs.inc"
%include "src/fm/vfs.inc"
%include "src/fm/panel.inc"

extern vfs_init
extern vfs_get_provider
extern vfs_read_entries
extern vfs_path_len

section .bss
    panel_pool                       resb PANEL_STRUCT_SIZE * PANEL_MAX_INSTANCES
    panel_used                       resb PANEL_MAX_INSTANCES

section .text
global panel_init
global panel_load
global panel_navigate
global panel_go_parent
global panel_go_path
global panel_sort
global panel_toggle_mark
global panel_mark_range
global panel_mark_all
global panel_unmark_all
global panel_get_marked
global panel_toggle_hidden
global panel_set_filter

panel_strcmp:
    ; rdi s1, rsi s2 -> eax {-1,0,1}
.loop:
    mov al, [rdi]
    mov dl, [rsi]
    cmp al, dl
    jne .diff
    test al, al
    je .eq
    inc rdi
    inc rsi
    jmp .loop
.diff:
    jb .lt
    mov eax, 1
    ret
.lt:
    mov eax, -1
    ret
.eq:
    xor eax, eax
    ret

panel_ext_ptr:
    ; rdi name_ptr -> rax pointer to extension start, or end-of-string
    mov rax, rdi
    xor r8d, r8d
.scan:
    mov dl, [rax]
    test dl, dl
    je .out
    cmp dl, '.'
    jne .next
    lea r8, [rax + 1]
.next:
    inc rax
    jmp .scan
.out:
    test r8, r8
    jz .no_ext
    mov rax, r8
    ret
.no_ext:
    mov rax, rdi
    ; move to end
.to_end:
    cmp byte [rax], 0
    je .ret
    inc rax
    jmp .to_end
.ret:
    ret

panel_mark_bit_get:
    ; rdi panel*, esi idx -> eax 0/1
    mov eax, esi
    shr eax, 3
    movzx edx, byte [rdi + P_MARK_BITS_OFF + rax]
    mov ecx, esi
    and ecx, 7
    shr edx, cl
    and edx, 1
    mov eax, edx
    ret

panel_mark_bit_set:
    ; rdi panel*, esi idx
    mov eax, esi
    shr eax, 3
    mov ecx, esi
    and ecx, 7
    mov dl, 1
    shl dl, cl
    or byte [rdi + P_MARK_BITS_OFF + rax], dl
    ret

panel_mark_bit_clear:
    ; rdi panel*, esi idx
    mov eax, esi
    shr eax, 3
    mov ecx, esi
    and ecx, 7
    mov dl, 1
    shl dl, cl
    not dl
    and byte [rdi + P_MARK_BITS_OFF + rax], dl
    ret

panel_alloc:
    xor ecx, ecx
.loop:
    cmp ecx, PANEL_MAX_INSTANCES
    jae .fail
    cmp byte [rel panel_used + rcx], 0
    je .slot
    inc ecx
    jmp .loop
.slot:
    mov byte [rel panel_used + rcx], 1
    mov eax, ecx
    imul eax, PANEL_STRUCT_SIZE
    lea rax, [rel panel_pool + rax]
    ret
.fail:
    xor eax, eax
    ret

panel_join_path:
    ; rdi out, rsi base, edx base_len, rcx name, r8d name_len -> eax len or -1
    push rbx
    push r12
    mov rbx, rdi
    mov r12, rcx
    cmp edx, VFS_MAX_PATH - 2
    ja .fail
    mov eax, edx
    add eax, r8d
    add eax, 2
    cmp eax, VFS_MAX_PATH
    ja .fail

    ; copy base
    mov ecx, 0
.bcopy:
    cmp ecx, edx
    jae .base_done
    mov al, [rsi + rcx]
    mov [rbx + rcx], al
    inc ecx
    jmp .bcopy
.base_done:
    mov eax, edx
    test eax, eax
    jz .add_slash
    cmp byte [rbx + rax - 1], '/'
    je .copy_name
.add_slash:
    mov byte [rbx + rax], '/'
    inc eax
.copy_name:
    mov ecx, 0
.ncopy:
    cmp ecx, r8d
    jae .term
    mov dl, [r12 + rcx]
    mov [rbx + rax], dl
    inc eax
    inc ecx
    jmp .ncopy
.term:
    mov byte [rbx + rax], 0
    pop r12
    pop rbx
    ret
.fail:
    mov eax, -1
    pop r12
    pop rbx
    ret

panel_filter_match:
    ; rdi panel*, rsi entry_name -> eax 1 pass /0 reject
    cmp dword [rdi + P_FILTER_LEN_OFF], 0
    je .pass
    ; simple wildcard: leading/trailing * support and exact fallback
    lea rdx, [rdi + P_FILTER_OFF]
    cmp byte [rdx], '*'
    jne .exact
    ; suffix match for "*.ext"
    cmp byte [rdx + 1], '.'
    jne .pass
    lea r8, [rdx + 1]
    ; find end of name
    mov r9, rsi
.nend:
    cmp byte [r9], 0
    je .got_nend
    inc r9
    jmp .nend
.got_nend:
    ; find last '.'
    mov r10, rsi
    xor r11d, r11d
.dot:
    cmp byte [r10], 0
    je .cmp
    cmp byte [r10], '.'
    jne .dn
    mov r11, r10
.dn:
    inc r10
    jmp .dot
.cmp:
    test r11, r11
    jz .reject
    mov rdi, r11
    mov rsi, r8
    call panel_strcmp
    test eax, eax
    jne .reject
    jmp .pass
.exact:
    mov rsi, rdx
    call panel_strcmp
    test eax, eax
    jne .reject
.pass:
    mov eax, 1
    ret
.reject:
    xor eax, eax
    ret

panel_compare_entries:
    ; rdi panel*, rsi a_ptr, rdx b_ptr -> eax >0 means a>b
    push rbx
    mov ebx, [rdi + P_SORT_COLUMN_OFF]
    cmp ebx, SORT_NAME
    jne .size
    lea rdi, [rsi + DE_NAME_OFF]
    lea rsi, [rdx + DE_NAME_OFF]
    call panel_strcmp
    jmp .maybe_rev
.size:
    cmp ebx, SORT_SIZE
    jne .date
    mov eax, [rsi + DE_TYPE_OFF]
    cmp eax, DT_DIR
    je .adir
    mov eax, [rdx + DE_TYPE_OFF]
    cmp eax, DT_DIR
    je .bdir
    mov rax, [rsi + DE_SIZE_OFF]
    cmp rax, [rdx + DE_SIZE_OFF]
    jb .lt
    ja .gt
    xor eax, eax
    jmp .maybe_rev
.date:
    cmp ebx, SORT_DATE
    jne .ext
    mov rax, [rsi + DE_MTIME_OFF]
    cmp rax, [rdx + DE_MTIME_OFF]
    jb .lt
    ja .gt
    xor eax, eax
    jmp .maybe_rev
.ext:
    ; SORT_EXT
    lea rdi, [rsi + DE_NAME_OFF]
    call panel_ext_ptr
    mov r8, rax
    lea rdi, [rdx + DE_NAME_OFF]
    call panel_ext_ptr
    mov rdi, r8
    mov rsi, rax
    call panel_strcmp
    test eax, eax
    jne .maybe_rev
    lea rdi, [rsi + DE_NAME_OFF]
    lea rsi, [rdx + DE_NAME_OFF]
    call panel_strcmp
    jmp .maybe_rev
.adir:
    mov eax, -1
    jmp .maybe_rev
.bdir:
    mov eax, 1
    jmp .maybe_rev
.lt:
    mov eax, -1
    jmp .maybe_rev
.gt:
    mov eax, 1
.maybe_rev:
    cmp dword [rdi + P_SORT_ASC_OFF], 0
    jne .out
    neg eax
.out:
    pop rbx
    ret

panel_sort_entries:
    ; rdi panel*
    push rbx
    push r12
    push r13
    push r14
    mov r12, rdi
    mov ebx, [r12 + P_ENTRY_COUNT_OFF]
    cmp ebx, 2
    jl .out
    dec ebx
.outer:
    xor r13d, r13d
    mov r14d, 0
.inner:
    cmp r13d, ebx
    jge .after_inner
    mov eax, r13d
    imul eax, DIR_ENTRY_SIZE
    lea rsi, [r12 + P_ENTRIES_BUF_OFF + rax]
    lea rdx, [rsi + DIR_ENTRY_SIZE]
    mov rdi, r12
    call panel_compare_entries
    cmp eax, 0
    jle .next
    ; swap entries (DIR_ENTRY_SIZE bytes)
    push rcx
    push r8
    push r9
    push r10
    mov ecx, DIR_ENTRY_SIZE
.sw:
    mov al, [rsi]
    mov dl, [rdx]
    mov [rsi], dl
    mov [rdx], al
    inc rsi
    inc rdx
    dec ecx
    jnz .sw
    pop r10
    pop r9
    pop r8
    pop rcx
    mov r14d, 1
.next:
    inc r13d
    jmp .inner
.after_inner:
    test r14d, r14d
    jz .out
    dec ebx
    jg .outer
.out:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

panel_init:
    ; (path_ptr rdi, path_len esi) -> rax Panel*
    push rbx
    mov rbx, rdi
    call vfs_init
    call panel_alloc
    test rax, rax
    jz .fail
    mov rdi, rax
    mov ecx, PANEL_STRUCT_SIZE
    xor eax, eax
    rep stosb
    sub rdi, PANEL_STRUCT_SIZE
    ; rdi now panel*
    lea rax, [rdi + P_ENTRIES_BUF_OFF]
    mov [rdi + P_ENTRIES_PTR_OFF], rax
    lea rax, [rdi + P_MARK_BITS_OFF]
    mov [rdi + P_MARKED_PTR_OFF], rax
    mov dword [rdi + P_SORT_COLUMN_OFF], SORT_NAME
    mov dword [rdi + P_SORT_ASC_OFF], 1
    mov dword [rdi + P_SELECTED_IDX_OFF], 0
    mov dword [rdi + P_SCROLL_OFF], 0
    mov dword [rdi + P_SHOW_HIDDEN_OFF], 0
    mov dword [rdi + P_ACTIVE_OFF], 0
    cmp esi, 0
    jne .copy
    mov byte [rdi + P_PATH_OFF], '/'
    mov byte [rdi + P_PATH_OFF + 1], 0
    mov dword [rdi + P_PATH_LEN_OFF], 1
    jmp .load
.copy:
    mov edx, esi
    cmp edx, VFS_MAX_PATH - 1
    jbe .cp_ok
    mov edx, VFS_MAX_PATH - 1
.cp_ok:
    lea r8, [rdi + P_PATH_OFF]
    mov rcx, rdx
    mov rsi, rbx
    mov rdi, r8
    rep movsb
    mov byte [r8 + rdx], 0
    mov [r8 - P_PATH_OFF + P_PATH_LEN_OFF], edx
    mov rdi, r8
    sub rdi, P_PATH_OFF
.load:
    push rdi
    lea rsi, [rdi + P_PATH_OFF]
    mov edx, [rdi + P_PATH_LEN_OFF]
    mov rdi, rsi
    mov esi, edx
    call vfs_get_provider
    pop rdi
    mov [rdi + P_VFS_PROVIDER_OFF], rax
    push rdi
    call panel_load
    pop rax
    pop rbx
    ret
.fail:
    xor eax, eax
    pop rbx
    ret

panel_load:
    ; (panel* rdi) -> eax count or -1
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdi
    lea rdi, [rbx + P_PATH_OFF]
    mov esi, [rbx + P_PATH_LEN_OFF]
    lea rdx, [rbx + P_ENTRIES_BUF_OFF]
    mov ecx, VFS_MAX_DIR_ENTRIES
    call vfs_read_entries
    test eax, eax
    js .fail
    mov r12d, eax                      ; raw count
    xor r13d, r13d                     ; out count
    xor r14d, r14d
.filter_loop:
    cmp r14d, r12d
    jae .filtered
    mov eax, r14d
    imul eax, DIR_ENTRY_SIZE
    lea rsi, [rbx + P_ENTRIES_BUF_OFF + rax]
    ; hidden filter
    cmp dword [rbx + P_SHOW_HIDDEN_OFF], 0
    jne .flt
    cmp dword [rsi + DE_HIDDEN_OFF], 0
    jne .skip
.flt:
    mov rdi, rbx
    lea rsi, [rsi + DE_NAME_OFF]
    call panel_filter_match
    test eax, eax
    jz .skip
    cmp r13d, r14d
    je .keep
    ; move entry i -> out
    mov eax, r13d
    imul eax, DIR_ENTRY_SIZE
    lea rdi, [rbx + P_ENTRIES_BUF_OFF + rax]
    mov eax, r14d
    imul eax, DIR_ENTRY_SIZE
    lea rsi, [rbx + P_ENTRIES_BUF_OFF + rax]
    mov ecx, DIR_ENTRY_SIZE
    rep movsb
.keep:
    inc r13d
.skip:
    inc r14d
    jmp .filter_loop
.filtered:
    mov [rbx + P_ENTRY_COUNT_OFF], r13d
    mov rdi, rbx
    call panel_unmark_all
    mov rdi, rbx
    call panel_sort_entries
    mov eax, [rbx + P_ENTRY_COUNT_OFF]
    test eax, eax
    jz .clamp_done
    mov ecx, [rbx + P_SELECTED_IDX_OFF]
    cmp ecx, eax
    jl .clamp_done
    dec eax
    mov [rbx + P_SELECTED_IDX_OFF], eax
.clamp_done:
    mov eax, [rbx + P_ENTRY_COUNT_OFF]
    jmp .out
.fail:
    mov eax, -1
.out:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

panel_navigate:
    ; (panel* rdi, entry_index esi) -> eax 1 navigated dir, 0 file/noop, -1 error
    push rbx
    mov rbx, rdi
    cmp esi, 0
    jl .bad
    cmp esi, [rbx + P_ENTRY_COUNT_OFF]
    jge .bad
    mov eax, esi
    imul eax, DIR_ENTRY_SIZE
    lea rdx, [rbx + P_ENTRIES_BUF_OFF + rax]
    cmp dword [rdx + DE_TYPE_OFF], DT_DIR
    jne .file
    lea rdi, [rbx + P_TMP_PATH_OFF]
    lea rsi, [rbx + P_PATH_OFF]
    mov edx, [rbx + P_PATH_LEN_OFF]
    lea rcx, [rdx + DE_NAME_OFF]
    mov r8d, [rdx + DE_NAME_LEN_OFF]
    call panel_join_path
    test eax, eax
    js .bad
    lea rsi, [rbx + P_TMP_PATH_OFF]
    lea rdi, [rbx + P_PATH_OFF]
    mov ecx, eax
    rep movsb
    mov byte [rbx + P_PATH_OFF + rax], 0
    mov [rbx + P_PATH_LEN_OFF], eax
    mov rdi, rbx
    call panel_load
    mov eax, 1
    jmp .out
.file:
    xor eax, eax
    jmp .out
.bad:
    mov eax, -1
.out:
    pop rbx
    ret

panel_go_parent:
    ; (panel* rdi) -> eax 0/-1
    push rbx
    mov rbx, rdi
    mov ecx, [rbx + P_PATH_LEN_OFF]
    cmp ecx, 1
    jle .root
    lea rdi, [rbx + P_PATH_OFF]
    dec ecx
.scan:
    cmp ecx, 1
    jl .root
    cmp byte [rdi + rcx], '/'
    je .cut
    dec ecx
    jmp .scan
.cut:
    mov byte [rdi + rcx], 0
    mov [rbx + P_PATH_LEN_OFF], ecx
    mov rdi, rbx
    call panel_load
    xor eax, eax
    jmp .out
.root:
    mov byte [rbx + P_PATH_OFF], '/'
    mov byte [rbx + P_PATH_OFF + 1], 0
    mov dword [rbx + P_PATH_LEN_OFF], 1
    mov rdi, rbx
    call panel_load
    xor eax, eax
.out:
    pop rbx
    ret

panel_go_path:
    ; (panel* rdi, path rsi, path_len edx) -> eax 0/-1
    push rbx
    mov rbx, rdi
    cmp edx, 0
    jg .cpy
    mov byte [rbx + P_PATH_OFF], '/'
    mov byte [rbx + P_PATH_OFF + 1], 0
    mov dword [rbx + P_PATH_LEN_OFF], 1
    jmp .ld
.cpy:
    cmp edx, VFS_MAX_PATH - 1
    jbe .ok
    mov edx, VFS_MAX_PATH - 1
.ok:
    lea rdi, [rbx + P_PATH_OFF]
    mov ecx, edx
    rep movsb
    mov byte [rbx + P_PATH_OFF + rdx], 0
    mov [rbx + P_PATH_LEN_OFF], edx
.ld:
    mov rdi, rbx
    call panel_load
    test eax, eax
    js .fail
    xor eax, eax
    pop rbx
    ret
.fail:
    mov eax, -1
    pop rbx
    ret

panel_sort:
    ; (panel* rdi, column esi) -> eax 0/-1
    cmp esi, SORT_NAME
    jb .bad
    cmp esi, SORT_EXT
    ja .bad
    cmp esi, [rdi + P_SORT_COLUMN_OFF]
    jne .set
    xor eax, 1
    mov eax, [rdi + P_SORT_ASC_OFF]
    xor eax, 1
    mov [rdi + P_SORT_ASC_OFF], eax
    jmp .load
.set:
    mov [rdi + P_SORT_COLUMN_OFF], esi
    mov dword [rdi + P_SORT_ASC_OFF], 1
.load:
    call panel_load
    test eax, eax
    js .bad
    xor eax, eax
    ret
.bad:
    mov eax, -1
    ret

panel_toggle_mark:
    ; (panel* rdi, idx esi) -> eax 0/-1
    cmp esi, 0
    jl .bad
    cmp esi, [rdi + P_ENTRY_COUNT_OFF]
    jge .bad
    push rdi
    push rsi
    call panel_mark_bit_get
    pop rsi
    pop rdi
    test eax, eax
    jz .set
    call panel_mark_bit_clear
    dec dword [rdi + P_MARKED_COUNT_OFF]
    js .fix
    xor eax, eax
    ret
.fix:
    mov dword [rdi + P_MARKED_COUNT_OFF], 0
    xor eax, eax
    ret
.set:
    call panel_mark_bit_set
    inc dword [rdi + P_MARKED_COUNT_OFF]
    xor eax, eax
    ret
.bad:
    mov eax, -1
    ret

panel_mark_range:
    ; (panel* rdi, from esi, to edx)
    cmp esi, edx
    jle .o
    xchg esi, edx
.o:
    cmp esi, 0
    jge .c1
    xor esi, esi
.c1:
    mov ecx, [rdi + P_ENTRY_COUNT_OFF]
    dec ecx
    cmp edx, ecx
    jle .loop
    mov edx, ecx
.loop:
    cmp esi, edx
    jg .done
    push rsi
    call panel_mark_bit_get
    pop rsi
    test eax, eax
    jnz .n
    call panel_mark_bit_set
    inc dword [rdi + P_MARKED_COUNT_OFF]
.n:
    inc esi
    jmp .loop
.done:
    xor eax, eax
    ret

panel_mark_all:
    ; (panel* rdi)
    push rbx
    xor ebx, ebx
.m:
    cmp ebx, [rdi + P_ENTRY_COUNT_OFF]
    jge .out
    mov esi, ebx
    call panel_mark_bit_set
    inc ebx
    jmp .m
.out:
    mov [rdi + P_MARKED_COUNT_OFF], ebx
    xor eax, eax
    pop rbx
    ret

panel_unmark_all:
    ; (panel* rdi)
    lea rsi, [rdi + P_MARK_BITS_OFF]
    mov ecx, (VFS_MAX_DIR_ENTRIES / 8)
    xor eax, eax
    mov rdi, rsi
    rep stosb
    sub rdi, (VFS_MAX_DIR_ENTRIES / 8)
    mov dword [rdi - P_MARK_BITS_OFF + P_MARKED_COUNT_OFF], 0
    xor eax, eax
    ret

panel_get_marked:
    ; (panel* rdi, paths_out rsi, count_out rdx) -> eax count
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdi
    mov r12, rsi
    mov r14, rdx
    xor r13d, r13d
    xor ecx, ecx
.loop:
    cmp ecx, [rbx + P_ENTRY_COUNT_OFF]
    jge .done
    mov esi, ecx
    mov rdi, rbx
    call panel_mark_bit_get
    test eax, eax
    jz .n
    mov eax, r13d
    imul eax, VFS_MAX_PATH
    lea rdi, [r12 + rax]
    lea rsi, [rbx + P_PATH_OFF]
    mov edx, [rbx + P_PATH_LEN_OFF]
    mov eax, ecx
    imul eax, DIR_ENTRY_SIZE
    lea r8, [rbx + P_ENTRIES_BUF_OFF + rax + DE_NAME_LEN_OFF]
    mov r8d, [r8]
    lea rcx, [rbx + P_ENTRIES_BUF_OFF + rax + DE_NAME_OFF]
    call panel_join_path
    test eax, eax
    js .n
    inc r13d
.n:
    inc ecx
    jmp .loop
.done:
    test r14, r14
    jz .ret
    mov [r14], r13d
.ret:
    mov eax, r13d
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

panel_toggle_hidden:
    ; (panel* rdi) -> eax 0/-1
    mov eax, [rdi + P_SHOW_HIDDEN_OFF]
    xor eax, 1
    mov [rdi + P_SHOW_HIDDEN_OFF], eax
    call panel_load
    test eax, eax
    js .bad
    xor eax, eax
    ret
.bad:
    mov eax, -1
    ret

panel_set_filter:
    ; (panel* rdi, pattern rsi, len edx) -> eax 0/-1
    cmp edx, 0
    jge .ok
    xor edx, edx
.ok:
    cmp edx, 63
    jbe .cpy
    mov edx, 63
.cpy:
    lea r8, [rdi + P_FILTER_OFF]
    mov rdi, r8
    mov ecx, edx
    rep movsb
    mov byte [r8 + rdx], 0
    mov [r8 - P_FILTER_OFF + P_FILTER_LEN_OFF], edx
    mov rdi, r8
    sub rdi, P_FILTER_OFF
    call panel_load
    test eax, eax
    js .bad
    xor eax, eax
    ret
.bad:
    mov eax, -1
    ret
