; surface.asm — wl_compositor / wl_surface (Phase 3)
%include "src/hal/platform_defs.inc"
%include "src/compositor/compositor.inc"

extern arena_alloc
extern client_resource_add
extern client_resource_find
extern proto_send_event
extern proto_send_delete_id
extern shm_buffer_release_for_client

section .text
global surface_dispatch_compositor
global surface_dispatch_surface
global surface_find_by_id
global surface_set_screen_pos

; surface_set_screen_pos(surface*, x, y)
surface_set_screen_pos:
    mov dword [rdi + SF_SCREEN_X_OFF], esi
    mov dword [rdi + SF_SCREEN_Y_OFF], edx
    ret

; surface_find_by_id(client, surface_id) -> rax Surface* or 0
surface_find_by_id:
    push rbx
    mov rbx, rdi
    call client_resource_find
    test rax, rax
    jz .none
    cmp dword [rax + RES_TYPE_OFF], RESOURCE_SURFACE
    jne .none
    mov rax, [rax + RES_DATA_OFF]
    test rax, rax
    jz .none
    pop rbx
    ret
.none:
    xor eax, eax
    pop rbx
    ret

; surface_dispatch_compositor(client, object_id, opcode, payload, payload_len)
; object_id = wl_compositor id (unused for create_surface payload)
surface_dispatch_compositor:
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdi
    mov r12d, edx                ; opcode
    mov r13, rcx                 ; payload
    mov r14d, r8d                ; payload_len

    cmp r12d, 0
    jne .out
    cmp r14d, 4
    jb .out
    mov r12d, dword [r13 + 0]    ; new surface id

    mov rdi, [rbx + CC_SERVER_OFF]
    mov rdi, [rdi + CS_ARENA_OFF]
    mov rsi, SF_STRUCT_SIZE
    call arena_alloc
    test rax, rax
    jz .out
    mov r13, rax
    mov rdi, r13
    mov ecx, SF_STRUCT_SIZE / 4
    xor eax, eax
    rep stosd

    mov dword [r13 + SF_ID_OFF], r12d
    mov qword [r13 + SF_CLIENT_OFF], rbx
    mov dword [r13 + SF_Z_ORDER_OFF], 1
    mov dword [r13 + SF_WORKSPACE_OFF], 0

    mov rdi, rbx
    mov esi, r12d
    mov edx, RESOURCE_SURFACE
    mov rcx, r13
    call client_resource_add
.out:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; surface_dispatch_surface(client, object_id, opcode, payload, payload_len)
surface_dispatch_surface:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi
    mov r12d, esi                ; surface object id
    mov r13d, edx                ; opcode
    mov r14, rcx                 ; payload
    mov r15d, r8d                ; payload_len

    mov rdi, rbx
    mov esi, r12d
    call surface_find_by_id
    test rax, rax
    jz .out
    mov r12, rax                 ; r12 = Surface* (clobber surface id)

    cmp r13d, 1                  ; attach
    je .attach
    cmp r13d, 2                  ; damage
    je .damage
    cmp r13d, 3                  ; frame
    je .frame
    cmp r13d, 6                  ; commit
    je .commit
    jmp .out

.attach:
    cmp r15d, 12
    jb .out
    mov eax, dword [r14 + 0]
    mov dword [r12 + SF_ATTACH_DIRTY_OFF], 1
    mov qword [r12 + SF_PENDING_BUF_OFF], 0
    test eax, eax
    jz .out
    mov rdi, rbx
    mov esi, eax
    call client_resource_find
    test rax, rax
    jz .out
    cmp dword [rax + RES_TYPE_OFF], RESOURCE_BUFFER
    jne .out
    mov rax, [rax + RES_DATA_OFF]
    mov qword [r12 + SF_PENDING_BUF_OFF], rax
    movsxd rax, dword [r14 + 4]
    mov dword [r12 + SF_PENDING_X_OFF], eax
    movsxd rax, dword [r14 + 8]
    mov dword [r12 + SF_PENDING_Y_OFF], eax
    jmp .out

.damage:
    cmp r15d, 16
    jb .out
    mov eax, dword [r14 + 0]
    mov dword [r12 + SF_PENDING_DMG_OFF + 0], eax
    mov eax, dword [r14 + 4]
    mov dword [r12 + SF_PENDING_DMG_OFF + 4], eax
    mov eax, dword [r14 + 8]
    mov dword [r12 + SF_PENDING_DMG_OFF + 8], eax
    mov eax, dword [r14 + 12]
    mov dword [r12 + SF_PENDING_DMG_OFF + 12], eax
    mov dword [r12 + SF_PENDING_HAS_DMG_OFF], 1
    jmp .out

.frame:
    cmp r15d, 4
    jb .out
    mov eax, dword [r14 + 0]
    mov dword [r12 + SF_FRAME_CB_OFF], eax
    jmp .out

.commit:
    mov rdi, rbx
    mov rsi, r12
    call surface_commit_internal
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; surface_commit_internal(client, surface*)
surface_commit_internal:
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdi
    mov r12, rsi

    cmp dword [r12 + SF_ATTACH_DIRTY_OFF], 0
    je .no_attach_swap

    mov dword [r12 + SF_ATTACH_DIRTY_OFF], 0

    mov rax, [r12 + SF_CURRENT_BUF_OFF]
    mov r13, [r12 + SF_PENDING_BUF_OFF]

    test rax, rax
    jz .no_rel_old
    cmp r13, rax
    je .no_rel_old
    mov r14d, dword [rax + BUF_ID_OFF]
    mov rdi, rbx
    mov esi, r14d
    call shm_buffer_release_for_client
.no_rel_old:

    mov qword [r12 + SF_CURRENT_BUF_OFF], r13
    mov eax, dword [r12 + SF_PENDING_X_OFF]
    mov dword [r12 + SF_CURRENT_X_OFF], eax
    mov eax, dword [r12 + SF_PENDING_Y_OFF]
    mov dword [r12 + SF_CURRENT_Y_OFF], eax

    xor eax, eax
    mov qword [r12 + SF_PENDING_BUF_OFF], rax

    xor edx, edx
    test r13, r13
    jz .no_dim
    mov edx, dword [r13 + BUF_WIDTH_OFF]
    mov dword [r12 + SF_WIDTH_OFF], edx
    mov edx, dword [r13 + BUF_HEIGHT_OFF]
    mov dword [r12 + SF_HEIGHT_OFF], edx
.no_dim:

    mov dword [r12 + SF_MAPPED_OFF], 0
    test r13, r13
    jz .unmap_done
    cmp dword [r12 + SF_XDG_TOP_ID_OFF], 0
    je .unmap_done
    cmp dword [r12 + SF_XDG_CONFIGURED_OFF], 0
    je .unmap_done
    mov dword [r12 + SF_MAPPED_OFF], 1
.unmap_done:
    jmp .commit_done

.no_attach_swap:
.commit_done:

    pop r14
    pop r13
    pop r12
    pop rbx
    ret
