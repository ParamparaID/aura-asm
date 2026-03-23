; tiling.asm — basic master/stack binary split tiling tree
%include "src/compositor/compositor.inc"
%include "src/compositor/wm.inc"

%define TILING_MAX_NODES            512
%define MASTER_RATIO_DEFAULT        0x00009999    ; ~60%
%define MASTER_RATIO_MIN            0x00003333    ; ~20%
%define MASTER_RATIO_MAX            0x0000CCCC    ; ~80%

section .bss
    tiling_output_x          resd 1
    tiling_output_y          resd 1
    tiling_output_w          resd 1
    tiling_output_h          resd 1
    tiling_gap_px            resd 1
    tiling_surface_count     resd 1
    tiling_surfaces          resq WM_MAX_SURFACES
    tiling_master_ratio      resd 1
    tiling_next_split        resd 1
    tiling_root_ptr          resq 1
    tiling_nodes_used        resd 1
    tiling_nodes_pool        resb TILING_MAX_NODES * TN_STRUCT_SIZE
    tiling_leaf_count        resd 1
    tiling_leaf_nodes        resq WM_MAX_SURFACES

section .text
global tiling_init
global tiling_add
global tiling_remove
global tiling_layout
global tiling_resize
global tiling_swap
global tiling_find_leaf
global tiling_find_neighbor
global tiling_set_split_mode

tiling_alloc_node:
    mov eax, dword [rel tiling_nodes_used]
    cmp eax, TILING_MAX_NODES
    jae .none
    mov edx, TN_STRUCT_SIZE
    imul eax, edx
    lea rax, [rel tiling_nodes_pool + rax]
    inc dword [rel tiling_nodes_used]
    push rdi
    mov rdi, rax
    mov ecx, TN_STRUCT_SIZE / 4
    xor eax, eax
    rep stosd
    pop rdi
    ret
.none:
    xor eax, eax
    ret

; build equal-height vertical stack as a right chain
; rdi = start_index (first stack surface index)
; esi = stack_count
; returns rax = subtree root
tiling_build_stack_chain:
    push rbx
    push r12
    push r13
    mov ebx, edi
    mov r12d, esi
    cmp r12d, 1
    ja .mk_split
    call tiling_alloc_node
    test rax, rax
    jz .out
    mov dword [rax + TN_TYPE_OFF], TILING_LEAF
    movsxd rdx, ebx
    mov rdx, [rel tiling_surfaces + rdx*8]
    mov [rax + TN_SURFACE_OFF], rdx
    jmp .out
.mk_split:
    call tiling_alloc_node
    test rax, rax
    jz .out
    mov r13, rax
    mov dword [r13 + TN_TYPE_OFF], TILING_SPLIT_V

    call tiling_alloc_node
    test rax, rax
    jz .out_zero
    mov dword [rax + TN_TYPE_OFF], TILING_LEAF
    movsxd rdx, ebx
    mov rdx, [rel tiling_surfaces + rdx*8]
    mov [rax + TN_SURFACE_OFF], rdx
    mov [r13 + TN_FIRST_OFF], rax

    lea edi, [ebx + 1]
    mov esi, r12d
    dec esi
    call tiling_build_stack_chain
    test rax, rax
    jz .out_zero
    mov [r13 + TN_SECOND_OFF], rax

    mov eax, FP_ONE
    cdq
    idiv r12d
    mov [r13 + TN_RATIO_OFF], eax
    mov rax, r13
    jmp .out
.out_zero:
    xor eax, eax
.out:
    pop r13
    pop r12
    pop rbx
    ret

tiling_rebuild_tree:
    mov dword [rel tiling_nodes_used], 0
    mov dword [rel tiling_leaf_count], 0

    mov eax, dword [rel tiling_surface_count]
    test eax, eax
    jz .empty

    cmp eax, 1
    jne .multi
    call tiling_alloc_node
    test rax, rax
    jz .empty
    mov dword [rax + TN_TYPE_OFF], TILING_LEAF
    mov rdx, [rel tiling_surfaces]
    mov [rax + TN_SURFACE_OFF], rdx
    mov [rel tiling_root_ptr], rax
    ret

.multi:
    call tiling_alloc_node
    test rax, rax
    jz .empty
    mov r8, rax
    mov dword [r8 + TN_TYPE_OFF], TILING_SPLIT_H
    mov eax, dword [rel tiling_master_ratio]
    mov [r8 + TN_RATIO_OFF], eax

    call tiling_alloc_node
    test rax, rax
    jz .empty
    mov dword [rax + TN_TYPE_OFF], TILING_LEAF
    mov rdx, [rel tiling_surfaces]
    mov [rax + TN_SURFACE_OFF], rdx
    mov [r8 + TN_FIRST_OFF], rax

    mov eax, dword [rel tiling_surface_count]
    dec eax
    mov edi, 1
    mov esi, eax
    call tiling_build_stack_chain
    test rax, rax
    jz .empty
    mov [r8 + TN_SECOND_OFF], rax
    mov [rel tiling_root_ptr], r8
    ret

.empty:
    xor eax, eax
    mov [rel tiling_root_ptr], rax
    ret

; gather leaves in traversal order for quick neighbor lookups
; rdi = node*
tiling_collect_leaves:
    test rdi, rdi
    jz .ret
    mov eax, dword [rdi + TN_TYPE_OFF]
    cmp eax, TILING_LEAF
    jne .recur
    mov eax, dword [rel tiling_leaf_count]
    cmp eax, WM_MAX_SURFACES
    jae .ret
    mov [rel tiling_leaf_nodes + rax*8], rdi
    inc dword [rel tiling_leaf_count]
    ret
.recur:
    mov rax, [rdi + TN_FIRST_OFF]
    mov rdx, [rdi + TN_SECOND_OFF]
    push rdx
    mov rdi, rax
    call tiling_collect_leaves
    pop rdi
    call tiling_collect_leaves
.ret:
    ret

; rdi=node, esi=x, edx=y, ecx=w, r8d=h
tiling_layout_node:
    push rbx
    push r12
    push r13
    push r14
    push r15
    test rdi, rdi
    jz .ret
    mov [rdi + TN_X_OFF], esi
    mov [rdi + TN_Y_OFF], edx
    mov [rdi + TN_W_OFF], ecx
    mov [rdi + TN_H_OFF], r8d

    mov eax, dword [rdi + TN_TYPE_OFF]
    cmp eax, TILING_LEAF
    jne .split

    mov rax, [rdi + TN_SURFACE_OFF]
    test rax, rax
    jz .ret
    mov ebx, dword [rel tiling_gap_px]
    mov r12d, esi
    mov r13d, edx
    add r12d, ebx
    add r13d, ebx
    mov dword [rax + SF_SCREEN_X_OFF], r12d
    mov dword [rax + SF_SCREEN_Y_OFF], r13d
    mov r12d, ecx
    mov r13d, r8d
    lea ebx, [ebx*2]
    sub r12d, ebx
    sub r13d, ebx
    cmp r12d, 1
    jge .w_ok
    mov r12d, 1
.w_ok:
    cmp r13d, 1
    jge .h_ok
    mov r13d, 1
.h_ok:
    mov dword [rax + SF_WIDTH_OFF], r12d
    mov dword [rax + SF_HEIGHT_OFF], r13d
    jmp .ret

.split:
    mov rbx, [rdi + TN_FIRST_OFF]
    mov r12, [rdi + TN_SECOND_OFF]
    test rbx, rbx
    jz .ret
    test r12, r12
    jz .ret

    mov eax, dword [rdi + TN_RATIO_OFF]
    cmp eax, 1
    jge .ratio_ok
    mov eax, 1
.ratio_ok:
    cmp eax, FP_ONE
    jl .ratio_ok2
    mov eax, FP_ONE-1
.ratio_ok2:
    mov edx, dword [rel tiling_gap_px]
    mov r14d, esi                    ; save x
    mov r15d, edx                    ; save gap
    mov r11d, ecx                    ; save w
    mov r10d, r8d                    ; save h
    mov r9d, dword [rdi + TN_Y_OFF]  ; save y
    mov r13d, dword [rdi + TN_TYPE_OFF]
    cmp r13d, TILING_SPLIT_H
    jne .split_v

    mov r13d, r11d
    sub r13d, r15d
    cmp r13d, 1
    jge .h_space_ok
    mov r13d, 1
.h_space_ok:
    movsx r9, r13d
    movsx r10, eax
    imul r9, r10
    shr r9, 16
    mov r13d, r9d                    ; left_w
    cmp r13d, 1
    jge .left_ok
    mov r13d, 1
.left_ok:
    mov r8d, r11d
    sub r8d, r15d
    sub r8d, r13d                    ; right_w
    cmp r8d, 1
    jge .right_ok
    mov r8d, 1
.right_ok:
    mov rdi, rbx
    mov esi, r14d
    mov edx, r9d
    mov ecx, r13d
    mov r8d, r10d
    call tiling_layout_node

    mov rdi, r12
    mov esi, r14d
    add esi, r13d
    add esi, r15d
    mov edx, r9d
    mov ecx, r8d
    mov r8d, r10d
    call tiling_layout_node
    jmp .ret

.split_v:
    mov r13d, r10d
    sub r13d, r15d
    cmp r13d, 1
    jge .v_space_ok
    mov r13d, 1
.v_space_ok:
    movsx r9, r13d
    movsx r10, eax
    imul r9, r10
    shr r9, 16
    mov r13d, r9d                    ; top_h
    cmp r13d, 1
    jge .top_ok
    mov r13d, 1
.top_ok:
    mov r8d, r10d
    sub r8d, r15d
    sub r8d, r13d                    ; bottom_h
    cmp r8d, 1
    jge .bottom_ok
    mov r8d, 1
.bottom_ok:
    mov rdi, rbx
    mov esi, r14d
    mov edx, r9d
    mov ecx, r11d
    mov r8d, r13d
    call tiling_layout_node

    mov rdi, r12
    mov esi, r14d
    mov edx, r9d
    add edx, r13d
    add edx, r15d
    mov ecx, r11d
    mov r8d, r8d
    call tiling_layout_node

.ret:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; tiling_init(output_x, output_y, output_w, output_h, gap) -> rax root
tiling_init:
    mov dword [rel tiling_output_x], edi
    mov dword [rel tiling_output_y], esi
    mov dword [rel tiling_output_w], edx
    mov dword [rel tiling_output_h], ecx
    mov dword [rel tiling_gap_px], r8d
    mov dword [rel tiling_surface_count], 0
    mov dword [rel tiling_master_ratio], MASTER_RATIO_DEFAULT
    mov dword [rel tiling_next_split], TILING_SPLIT_H
    call tiling_rebuild_tree
    mov rax, [rel tiling_root_ptr]
    ret

; tiling_add(root, surface)
tiling_add:
    mov eax, dword [rel tiling_surface_count]
    cmp eax, WM_MAX_SURFACES
    jae .done
    mov [rel tiling_surfaces + rax*8], rsi
    inc dword [rel tiling_surface_count]
    call tiling_rebuild_tree
    mov rdi, [rel tiling_root_ptr]
    call tiling_layout
.done:
    ret

; tiling_remove(root, surface)
tiling_remove:
    push rbx
    push r12
    mov rbx, rsi
    xor r12d, r12d
.find:
    cmp r12d, dword [rel tiling_surface_count]
    jae .out
    mov rax, [rel tiling_surfaces + r12*8]
    cmp rax, rbx
    je .found
    inc r12d
    jmp .find
.found:
    mov ecx, dword [rel tiling_surface_count]
    dec ecx
.shift:
    cmp r12d, ecx
    jae .dec
    mov rax, [rel tiling_surfaces + r12*8 + 8]
    mov [rel tiling_surfaces + r12*8], rax
    inc r12d
    jmp .shift
.dec:
    dec dword [rel tiling_surface_count]
    call tiling_rebuild_tree
    mov rdi, [rel tiling_root_ptr]
    call tiling_layout
.out:
    pop r12
    pop rbx
    ret

; tiling_layout(node)
tiling_layout:
    mov rdi, [rel tiling_root_ptr]
    test rdi, rdi
    jz .done
    mov esi, dword [rel tiling_output_x]
    mov edx, dword [rel tiling_output_y]
    mov ecx, dword [rel tiling_output_w]
    mov r8d, dword [rel tiling_output_h]
    call tiling_layout_node
    mov dword [rel tiling_leaf_count], 0
    mov rdi, [rel tiling_root_ptr]
    call tiling_collect_leaves
.done:
    mov rax, [rel tiling_root_ptr]
    ret

; tiling_resize(node, surface, delta_x, delta_y)
tiling_resize:
    mov eax, dword [rel tiling_master_ratio]
    mov ecx, edx
    shl ecx, 9                       ; delta_x * 512
    add eax, ecx
    cmp eax, MASTER_RATIO_MIN
    jge .min_ok
    mov eax, MASTER_RATIO_MIN
.min_ok:
    cmp eax, MASTER_RATIO_MAX
    jle .max_ok
    mov eax, MASTER_RATIO_MAX
.max_ok:
    mov dword [rel tiling_master_ratio], eax
    mov rdi, [rel tiling_root_ptr]
    call tiling_layout
    ret

; tiling_swap(root, surface1, surface2)
tiling_swap:
    push rbx
    push r12
    push r13
    xor ebx, ebx
    xor r12d, r12d
    mov r13d, -1
.fs1:
    cmp ebx, dword [rel tiling_surface_count]
    jae .s1_done
    mov rax, [rel tiling_surfaces + rbx*8]
    cmp rax, rsi
    jne .n1
    mov r12d, ebx
    mov r13d, 1
    jmp .s1_done
.n1:
    inc ebx
    jmp .fs1
.s1_done:
    cmp r13d, 1
    jne .out
    xor ebx, ebx
    mov r13d, -1
.fs2:
    cmp ebx, dword [rel tiling_surface_count]
    jae .s2_done
    mov rax, [rel tiling_surfaces + rbx*8]
    cmp rax, rdx
    jne .n2
    mov r13d, ebx
    jmp .s2_done
.n2:
    inc ebx
    jmp .fs2
.s2_done:
    cmp r13d, 0
    jl .out
    mov rax, [rel tiling_surfaces + r12*8]
    mov rcx, [rel tiling_surfaces + r13*8]
    mov [rel tiling_surfaces + r12*8], rcx
    mov [rel tiling_surfaces + r13*8], rax
    mov rdi, [rel tiling_root_ptr]
    call tiling_rebuild_tree
    mov rdi, [rel tiling_root_ptr]
    call tiling_layout
.out:
    pop r13
    pop r12
    pop rbx
    ret

; tiling_find_leaf(root, surface) -> rax leaf*
tiling_find_leaf:
    push rbx
    xor ebx, ebx
.loop:
    cmp ebx, dword [rel tiling_leaf_count]
    jae .none
    mov rax, [rel tiling_leaf_nodes + rbx*8]
    cmp [rax + TN_SURFACE_OFF], rsi
    je .done
    inc ebx
    jmp .loop
.none:
    xor eax, eax
.done:
    pop rbx
    ret

; tiling_find_neighbor(root, surface, direction) -> rax Surface* or 0
tiling_find_neighbor:
    push rbx
    push r12
    push r13
    mov r12d, edx
    xor ebx, ebx
    mov r13d, -1
.idx:
    cmp ebx, dword [rel tiling_surface_count]
    jae .have_idx
    mov rax, [rel tiling_surfaces + rbx*8]
    cmp rax, rsi
    jne .next
    mov r13d, ebx
    jmp .have_idx
.next:
    inc ebx
    jmp .idx
.have_idx:
    cmp r13d, 0
    jl .none
    cmp dword [rel tiling_surface_count], 1
    jle .none

    cmp r13d, 0
    jne .stack_case
    ; master
    cmp r12d, WM_DIR_RIGHT
    jne .none
    mov rax, [rel tiling_surfaces + 8]
    jmp .done

.stack_case:
    cmp r12d, WM_DIR_LEFT
    je .to_master
    cmp r12d, WM_DIR_UP
    je .up_stack
    cmp r12d, WM_DIR_DOWN
    je .down_stack
    jmp .none
.to_master:
    mov rax, [rel tiling_surfaces]
    jmp .done
.up_stack:
    cmp r13d, 1
    jle .none
    lea ebx, [r13d - 1]
    mov rax, [rel tiling_surfaces + rbx*8]
    jmp .done
.down_stack:
    mov ebx, dword [rel tiling_surface_count]
    dec ebx
    cmp r13d, ebx
    jge .none
    lea ebx, [r13d + 1]
    mov rax, [rel tiling_surfaces + rbx*8]
    jmp .done
.none:
    xor eax, eax
.done:
    pop r13
    pop r12
    pop rbx
    ret

; tiling_set_split_mode(mode) — stored as preference for future splits
tiling_set_split_mode:
    mov dword [rel tiling_next_split], edi
    ret
