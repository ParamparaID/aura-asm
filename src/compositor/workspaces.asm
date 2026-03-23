; workspaces.asm — virtual workspaces (Module Spaces) for compositor
%include "src/compositor/compositor.inc"
%include "src/compositor/workspaces.inc"
%include "src/canvas/canvas.inc"

extern spring_init
extern spring_update
extern spring_value
extern spring_is_settled
extern compositor_render

%define FP_ONE                       0x00010000
%define FP_DT_60                     1092
%define WS_DEFAULT_COUNT             4
%define WS_TRANS_STIFF               0x00024000
%define WS_TRANS_DAMP                0x00010000
%define WS_BG_COLOR                  0xFF0F1018
%define WS_TMP_MAX                   128

section .bss
    workspaces_mgr_global            resb WSM_STRUCT_SIZE
    ws_tmp_count                     resd 1
    ws_tmp_surfaces                  resq WS_TMP_MAX
    ws_tmp_orig_x                    resd WS_TMP_MAX
    ws_tmp_orig_mapped               resd WS_TMP_MAX

section .text
global workspaces_get_manager
global workspaces_init
global workspaces_switch
global workspaces_switch_relative
global workspaces_move_surface
global workspaces_get_active
global workspaces_get_surfaces
global workspaces_render

workspaces_get_manager:
    lea rax, [rel workspaces_mgr_global]
    ret

; wsm_get_workspace(mgr, index) -> rax or 0
wsm_get_workspace:
    cmp esi, 0
    jl .none
    cmp esi, dword [rdi + WSM_COUNT_OFF]
    jge .none
    mov eax, esi
    imul eax, WS_STRUCT_SIZE
    lea rax, [rdi + WSM_WORKSPACES_OFF + rax]
    ret
.none:
    xor eax, eax
    ret

; wsm_apply_active_mapping(mgr)
wsm_apply_active_mapping:
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdi
    xor r12d, r12d
.ws_loop:
    cmp r12d, dword [rbx + WSM_COUNT_OFF]
    jae .done
    mov esi, r12d
    mov rdi, rbx
    call wsm_get_workspace
    test rax, rax
    jz .next_ws
    mov r13, rax
    xor r14d, r14d
.sf_loop:
    cmp r14d, dword [r13 + WS_SURFACE_COUNT_OFF]
    jae .next_ws
    mov rax, [r13 + WS_SURFACES_OFF + r14*8]
    inc r14d
    test rax, rax
    jz .sf_loop
    mov dword [rax + SF_WORKSPACE_OFF], r12d
    mov ecx, dword [rbx + WSM_ACTIVE_IDX_OFF]
    cmp r12d, ecx
    jne .unmap
    mov dword [rax + SF_MAPPED_OFF], 1
    jmp .sf_loop
.unmap:
    mov dword [rax + SF_MAPPED_OFF], 0
    jmp .sf_loop
.next_ws:
    inc r12d
    jmp .ws_loop
.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ws_remove_surface(ws, surface) -> eax removed(1/0)
ws_remove_surface:
    push rbx
    push r12
    mov rbx, rdi
    mov r12, rsi
    xor ecx, ecx
.find:
    cmp ecx, dword [rbx + WS_SURFACE_COUNT_OFF]
    jae .not_found
    mov rax, [rbx + WS_SURFACES_OFF + rcx*8]
    cmp rax, r12
    je .shift
    inc ecx
    jmp .find
.shift:
    mov edx, dword [rbx + WS_SURFACE_COUNT_OFF]
    dec edx
.shift_loop:
    cmp ecx, edx
    jae .commit
    mov rax, [rbx + WS_SURFACES_OFF + rcx*8 + 8]
    mov [rbx + WS_SURFACES_OFF + rcx*8], rax
    inc ecx
    jmp .shift_loop
.commit:
    mov dword [rbx + WS_SURFACE_COUNT_OFF], edx
    mov eax, 1
    jmp .out
.not_found:
    xor eax, eax
.out:
    pop r12
    pop rbx
    ret

; ws_add_surface(ws, surface) -> eax added(1/0)
ws_add_surface:
    mov eax, dword [rdi + WS_SURFACE_COUNT_OFF]
    cmp eax, WORKSPACE_MAX_SURFACES
    jae .full
    mov [rdi + WS_SURFACES_OFF + rax*8], rsi
    inc dword [rdi + WS_SURFACE_COUNT_OFF]
    mov eax, 1
    ret
.full:
    xor eax, eax
    ret

; workspaces_init(count) -> rax WorkspaceManager*
workspaces_init:
    push rbx
    push r12
    mov r12d, edi
    cmp r12d, 1
    jge .clamp_hi
    mov r12d, WS_DEFAULT_COUNT
.clamp_hi:
    cmp r12d, WORKSPACE_MAX_COUNT
    jle .clear
    mov r12d, WORKSPACE_MAX_COUNT
.clear:
    lea rdi, [rel workspaces_mgr_global]
    mov ecx, WSM_STRUCT_SIZE / 8
    xor eax, eax
    rep stosq

    lea rbx, [rel workspaces_mgr_global]
    mov dword [rbx + WSM_COUNT_OFF], r12d
    xor ecx, ecx
.init_ws:
    cmp ecx, r12d
    jae .done_ws
    mov esi, ecx
    mov rdi, rbx
    call wsm_get_workspace
    test rax, rax
    jz .next
    mov dword [rax + WS_ID_OFF], ecx
    mov dword [rax + WS_NAME_LEN_OFF], 0
    mov dword [rax + WS_SURFACE_COUNT_OFF], 0
    mov dword [rax + WS_ACTIVE_OFF], 0
    mov qword [rax + WS_TILING_ROOT_OFF], 0
.next:
    inc ecx
    jmp .init_ws
.done_ws:
    mov dword [rbx + WSM_ACTIVE_IDX_OFF], 0
    mov dword [rbx + WSM_PREV_IDX_OFF], 0
    mov dword [rbx + WSM_TRANSITIONING_OFF], 0
    mov dword [rbx + WSM_HUB_MODE_OFF], 0
    mov dword [rbx + WSM_OVERVIEW_MODE_OFF], 0
    mov dword [rbx + WSM_WORKSPACES_OFF + WS_ACTIVE_OFF], 1

    lea rdi, [rbx + WSM_TRANSITION_OFF]
    xor esi, esi
    xor edx, edx
    mov ecx, WS_TRANS_STIFF
    mov r8d, WS_TRANS_DAMP
    call spring_init

    mov rdi, rbx
    call wsm_apply_active_mapping
    mov rax, rbx
    pop r12
    pop rbx
    ret

; workspaces_switch(mgr, index) -> eax changed(1/0)
workspaces_switch:
    push rbx
    push r12
    mov rbx, rdi
    mov r12d, esi
    test rbx, rbx
    jz .no
    cmp r12d, 0
    jl .no
    cmp r12d, dword [rbx + WSM_COUNT_OFF]
    jge .no
    cmp r12d, dword [rbx + WSM_ACTIVE_IDX_OFF]
    je .no

    mov eax, dword [rbx + WSM_ACTIVE_IDX_OFF]
    mov dword [rbx + WSM_PREV_IDX_OFF], eax
    mov dword [rbx + WSM_ACTIVE_IDX_OFF], r12d

    mov esi, eax
    mov rdi, rbx
    call wsm_get_workspace
    test rax, rax
    jz .new_ws
    mov dword [rax + WS_ACTIVE_OFF], 0
.new_ws:
    mov esi, r12d
    mov rdi, rbx
    call wsm_get_workspace
    test rax, rax
    jz .start_anim
    mov dword [rax + WS_ACTIVE_OFF], 1
.start_anim:
    lea rdi, [rbx + WSM_TRANSITION_OFF]
    xor esi, esi
    mov edx, FP_ONE
    mov ecx, WS_TRANS_STIFF
    mov r8d, WS_TRANS_DAMP
    call spring_init
    mov dword [rbx + WSM_TRANSITIONING_OFF], 1
    mov rdi, rbx
    call wsm_apply_active_mapping
    mov eax, 1
    jmp .out
.no:
    xor eax, eax
.out:
    pop r12
    pop rbx
    ret

; workspaces_switch_relative(mgr, delta) -> eax changed
workspaces_switch_relative:
    push rbx
    mov rbx, rdi
    test rbx, rbx
    jz .no
    mov eax, dword [rbx + WSM_COUNT_OFF]
    test eax, eax
    jz .no
    mov ecx, dword [rbx + WSM_ACTIVE_IDX_OFF]
    add ecx, esi
.wrap_down:
    cmp ecx, 0
    jge .wrap_up
    add ecx, eax
    jmp .wrap_down
.wrap_up:
    cmp ecx, eax
    jl .do
    sub ecx, eax
    jmp .wrap_up
.do:
    mov rdi, rbx
    mov esi, ecx
    call workspaces_switch
    jmp .out
.no:
    xor eax, eax
.out:
    pop rbx
    ret

; workspaces_move_surface(mgr, surface, target_workspace) -> eax moved
workspaces_move_surface:
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12, rsi
    mov r13d, edx
    test rbx, rbx
    jz .no
    test r12, r12
    jz .no
    cmp r13d, 0
    jl .no
    cmp r13d, dword [rbx + WSM_COUNT_OFF]
    jge .no

    mov eax, dword [r12 + SF_WORKSPACE_OFF]
    mov ecx, eax
    cmp ecx, 0
    jl .target_add
    cmp ecx, dword [rbx + WSM_COUNT_OFF]
    jge .target_add
    mov esi, ecx
    mov rdi, rbx
    call wsm_get_workspace
    test rax, rax
    jz .target_add
    mov rdi, rax
    mov rsi, r12
    call ws_remove_surface
.target_add:
    mov esi, r13d
    mov rdi, rbx
    call wsm_get_workspace
    test rax, rax
    jz .no
    mov rdi, rax
    mov rsi, r12
    call ws_add_surface
    test eax, eax
    jz .no

    mov dword [r12 + SF_WORKSPACE_OFF], r13d
    mov eax, dword [rbx + WSM_ACTIVE_IDX_OFF]
    cmp eax, r13d
    jne .unmap
    mov dword [r12 + SF_MAPPED_OFF], 1
    mov eax, 1
    jmp .out
.unmap:
    mov dword [r12 + SF_MAPPED_OFF], 0
    mov eax, 1
    jmp .out
.no:
    xor eax, eax
.out:
    pop r13
    pop r12
    pop rbx
    ret

; workspaces_get_active(mgr) -> rax Workspace*
workspaces_get_active:
    mov esi, dword [rdi + WSM_ACTIVE_IDX_OFF]
    jmp wsm_get_workspace

; workspaces_get_surfaces(mgr) -> rax qword surfaces[]
workspaces_get_surfaces:
    push rbx
    mov rbx, rdi
    call workspaces_get_active
    test rax, rax
    jz .none
    lea rax, [rax + WS_SURFACES_OFF]
    jmp .out
.none:
    xor eax, eax
.out:
    pop rbx
    ret

; ws_collect_offset(ws, x_offset, force_mapped)
; rdi=Workspace*, esi=x_offset, edx=force_mapped
ws_collect_offset:
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12d, esi
    mov r13d, edx
    xor ecx, ecx
.loop:
    cmp ecx, dword [rbx + WS_SURFACE_COUNT_OFF]
    jae .out
    mov rax, [rbx + WS_SURFACES_OFF + rcx*8]
    inc ecx
    test rax, rax
    jz .loop
    mov edx, dword [rel ws_tmp_count]
    cmp edx, WS_TMP_MAX
    jae .loop
    mov [rel ws_tmp_surfaces + rdx*8], rax
    mov esi, dword [rax + SF_SCREEN_X_OFF]
    mov [rel ws_tmp_orig_x + rdx*4], esi
    mov esi, dword [rax + SF_MAPPED_OFF]
    mov [rel ws_tmp_orig_mapped + rdx*4], esi
    inc dword [rel ws_tmp_count]
    add dword [rax + SF_SCREEN_X_OFF], r12d
    test r13d, r13d
    jz .loop
    mov dword [rax + SF_MAPPED_OFF], 1
    jmp .loop
.out:
    pop r13
    pop r12
    pop rbx
    ret

; ws_restore_offsets()
ws_restore_offsets:
    xor ecx, ecx
.loop:
    cmp ecx, dword [rel ws_tmp_count]
    jae .done
    mov rax, [rel ws_tmp_surfaces + rcx*8]
    test rax, rax
    jz .next
    mov edx, [rel ws_tmp_orig_x + rcx*4]
    mov [rax + SF_SCREEN_X_OFF], edx
    mov edx, [rel ws_tmp_orig_mapped + rcx*4]
    mov [rax + SF_MAPPED_OFF], edx
.next:
    inc ecx
    jmp .loop
.done:
    mov dword [rel ws_tmp_count], 0
    ret

; workspaces_render(mgr, server, canvas)
workspaces_render:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    test rbx, rbx
    jz .out
    test r12, r12
    jz .out
    test r13, r13
    jz .out

    cmp dword [rbx + WSM_TRANSITIONING_OFF], 0
    je .plain

    lea rdi, [rbx + WSM_TRANSITION_OFF]
    mov esi, FP_DT_60
    call spring_update

    lea rdi, [rbx + WSM_TRANSITION_OFF]
    call spring_value
    mov r14d, eax                    ; t fp
    mov eax, dword [r13 + CV_WIDTH_OFF]
    mov r15d, eax                    ; output_w

    mov eax, r15d
    imul eax, r14d
    sar eax, 16
    mov r14d, eax
    neg r14d                         ; prev offset
    mov r15d, dword [r13 + CV_WIDTH_OFF]
    sub r15d, eax                    ; new offset

    mov dword [rel ws_tmp_count], 0

    mov esi, dword [rbx + WSM_PREV_IDX_OFF]
    mov rdi, rbx
    call wsm_get_workspace
    test rax, rax
    jz .collect_new
    mov rdi, rax
    mov esi, r14d
    mov edx, 1
    call ws_collect_offset

.collect_new:
    mov esi, dword [rbx + WSM_ACTIVE_IDX_OFF]
    mov rdi, rbx
    call wsm_get_workspace
    test rax, rax
    jz .render_t
    mov rdi, rax
    mov esi, r15d
    mov edx, 1
    call ws_collect_offset

.render_t:
    mov rdi, r12
    mov rsi, r13
    mov edx, WS_BG_COLOR
    call compositor_render
    call ws_restore_offsets

    lea rdi, [rbx + WSM_TRANSITION_OFF]
    call spring_is_settled
    test eax, eax
    jz .out
    mov dword [rbx + WSM_TRANSITIONING_OFF], 0
    mov eax, dword [rbx + WSM_ACTIVE_IDX_OFF]
    mov dword [rbx + WSM_PREV_IDX_OFF], eax
    mov rdi, rbx
    call wsm_apply_active_mapping
    jmp .out

.plain:
    mov rdi, rbx
    call wsm_apply_active_mapping
    mov rdi, r12
    mov rsi, r13
    mov edx, WS_BG_COLOR
    call compositor_render

.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
