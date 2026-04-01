; layout.asm — simplified flex-like measure + arrange for widget trees
%include "src/hal/platform_defs.inc"
%include "src/gui/widget.inc"
%include "src/gui/layout.inc"

extern widget_measure

section .bss
    layout_tmp_main     resd 64
    layout_tmp_grow     resd 64
    layout_tmp_shrink   resd 64
    layout_tmp_cross    resd 64
    layout_vis_ptrs     resq 64
    layout_extra_between resd 1
    default_child_lp    resb LP_STRUCT_SIZE

section .text
global layout_get_form_factor
global layout_set_responsive
global layout_apply_viewport
global layout_measure
global layout_arrange

layout_get_form_factor:
    cmp esi, BREAKPOINT_PHONE
    jl .phone
    cmp esi, BREAKPOINT_TABLET
    jl .tablet
    mov eax, FORM_DESKTOP
    ret
.phone:
    xor eax, eax
    ret
.tablet:
    mov eax, FORM_TABLET
    ret

layout_set_responsive:
    push rbx
    mov rbx, [rdi + W_DATA_OFF]
    test rbx, rbx
    jz .out
    mov [rbx + FCD_LP_PHONE_OFF], rsi
    mov [rbx + FCD_LP_TABLET_OFF], rdx
    mov [rbx + FCD_LP_DESKTOP_OFF], rcx
.out:
    pop rbx
    ret

layout_apply_viewport:
    push rbx
    push r12
    push r13
    mov r12, rdi
    mov r13d, esi
    mov rbx, [r12 + W_DATA_OFF]
    test rbx, rbx
    jz .bad
    mov edi, r13d
    call layout_get_form_factor
    cmp eax, FORM_PHONE
    je .phone
    cmp eax, FORM_TABLET
    je .tablet
    mov rsi, [rbx + FCD_LP_DESKTOP_OFF]
    jmp .copy
.phone:
    mov rsi, [rbx + FCD_LP_PHONE_OFF]
    jmp .copy
.tablet:
    mov rsi, [rbx + FCD_LP_TABLET_OFF]
.copy:
    test rsi, rsi
    jz .bad
    lea rdi, [rbx + FCD_LAYOUT_OFF]
    mov rcx, 6
    rep movsq
.bad:
    pop r13
    pop r12
    pop rbx
    ret

layout_child_lp:
    mov rax, [rdi + W_DATA_OFF]
    test rax, rax
    jnz .ok
    lea rax, [rel default_child_lp]
.ok:
    ret

; layout_measure(container rdi, max_w esi, max_h edx)
layout_measure:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi
    mov r14d, edx
    mov rbx, [r12 + W_DATA_OFF]
    test rbx, rbx
    jz .m_done
    mov eax, [rbx + FCD_PAD_LEFT_OFF]
    add eax, [rbx + FCD_PAD_RIGHT_OFF]
    sub r13d, eax
    jns .iw_ok
    xor r13d, r13d
.iw_ok:
    mov eax, [rbx + FCD_PAD_TOP_OFF]
    add eax, [rbx + FCD_PAD_BOTTOM_OFF]
    sub r14d, eax
    jns .ih_ok
    xor r14d, r14d
.ih_ok:

    xor r8d, r8d
    cmp dword [rbx + LP_DIRECTION_OFF], LAYOUT_ROW
    sete r8b

    xor ecx, ecx
    xor esi, esi
    xor edi, edi
.cm_loop:
    cmp ecx, [r12 + W_CHILD_COUNT_OFF]
    jae .cm_after
    mov rax, [r12 + W_CHILDREN_OFF]
    mov rdi, [rax + rcx*8]
    test rdi, rdi
    jz .cm_next
    cmp dword [rdi + W_VISIBLE_OFF], 0
    je .cm_next
    push rcx
    push rsi
    push rdi
    push r8
    mov esi, r13d
    mov edx, r14d
    call widget_measure
    pop r8
    pop rdi
    call layout_child_lp
    mov r10, rax
    test r8b, r8b
    jz .cm_col
    cmp dword [r10 + LP_FLEX_GROW_OFF], 0
    je .cm_row_done
    mov dword [rdi + W_PREF_W_OFF], 0
    jmp .cm_row_done
.cm_col:
    cmp dword [r10 + LP_FLEX_GROW_OFF], 0
    je .cm_row_done
    mov dword [rdi + W_PREF_H_OFF], 0
.cm_row_done:
    mov eax, [rdi + W_PREF_W_OFF]
    mov edx, [r10 + LP_MARGIN_L_OFF]
    add eax, edx
    add eax, [r10 + LP_MARGIN_R_OFF]
    mov edx, [rdi + W_PREF_H_OFF]
    add edx, [r10 + LP_MARGIN_T_OFF]
    add edx, [r10 + LP_MARGIN_B_OFF]
    test r8b, r8b
    jz .cm_acc_col
    add esi, eax
    cmp edx, edi
    cmovg edi, edx
    jmp .cm_pop
.cm_acc_col:
    add esi, edx
    cmp eax, edi
    cmovg edi, eax
.cm_pop:
    pop rsi
    pop rcx
.cm_next:
    inc ecx
    jmp .cm_loop

.cm_after:
    mov eax, ecx
    xor ecx, ecx
    ; count visible for gap
    xor eax, eax
.cv:
    cmp ecx, [r12 + W_CHILD_COUNT_OFF]
    jae .cv_done
    mov rdx, [r12 + W_CHILDREN_OFF]
    mov rdi, [rdx + rcx*8]
    test rdi, rdi
    jz .cv_next
    cmp dword [rdi + W_VISIBLE_OFF], 0
    je .cv_next
    inc eax
.cv_next:
    inc ecx
    jmp .cv
.cv_done:
    cmp eax, 1
    jl .no_gap_m
    dec eax
    mov ecx, [rbx + LP_GAP_OFF]
    imul ecx, eax
    add esi, ecx
.no_gap_m:
    add esi, [rbx + FCD_PAD_LEFT_OFF]
    add esi, [rbx + FCD_PAD_RIGHT_OFF]
    test r8b, r8b
    jz .m_pref_col
    mov [r12 + W_PREF_W_OFF], esi
    mov eax, edi
    add eax, [rbx + FCD_PAD_TOP_OFF]
    add eax, [rbx + FCD_PAD_BOTTOM_OFF]
    mov [r12 + W_PREF_H_OFF], eax
    jmp .m_done
.m_pref_col:
    mov [r12 + W_PREF_H_OFF], esi
    mov eax, edi
    add eax, [rbx + FCD_PAD_LEFT_OFF]
    add eax, [rbx + FCD_PAD_RIGHT_OFF]
    mov [r12 + W_PREF_W_OFF], eax
.m_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; layout_arrange(container rdi)
layout_arrange:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push r10
    push r11
    mov r12, rdi
    mov rbx, [r12 + W_DATA_OFF]
    test rbx, rbx
    jz .a_out
    mov r13d, [r12 + W_WIDTH_OFF]
    mov r14d, [r12 + W_HEIGHT_OFF]
    mov eax, [rbx + FCD_PAD_LEFT_OFF]
    add eax, [rbx + FCD_PAD_RIGHT_OFF]
    sub r13d, eax
    jns .a_iw
    xor r13d, r13d
.a_iw:
    mov eax, [rbx + FCD_PAD_TOP_OFF]
    add eax, [rbx + FCD_PAD_BOTTOM_OFF]
    sub r14d, eax
    jns .a_ih
    xor r14d, r14d
.a_ih:

    xor r8d, r8d
    cmp dword [rbx + LP_DIRECTION_OFF], LAYOUT_ROW
    sete r8b

    xor ecx, ecx
    xor r9d, r9d
.build:
    cmp ecx, [r12 + W_CHILD_COUNT_OFF]
    jae .built
    mov rax, [r12 + W_CHILDREN_OFF]
    mov rdi, [rax + rcx*8]
    inc ecx
    test rdi, rdi
    jz .build
    cmp dword [rdi + W_VISIBLE_OFF], 0
    je .build
    mov [rel layout_vis_ptrs + r9*8], rdi
    call layout_child_lp
    mov r10, rax
    test r8b, r8b
    jz .bd_col
    mov eax, [rdi + W_PREF_W_OFF]
    add eax, [r10 + LP_MARGIN_L_OFF]
    add eax, [r10 + LP_MARGIN_R_OFF]
    mov [rel layout_tmp_main + r9*4], eax
    mov eax, [rdi + W_PREF_H_OFF]
    mov [rel layout_tmp_cross + r9*4], eax
    jmp .bd_g
.bd_col:
    mov eax, [rdi + W_PREF_H_OFF]
    add eax, [r10 + LP_MARGIN_T_OFF]
    add eax, [r10 + LP_MARGIN_B_OFF]
    mov [rel layout_tmp_main + r9*4], eax
    mov eax, [rdi + W_PREF_W_OFF]
    mov [rel layout_tmp_cross + r9*4], eax
.bd_g:
    mov eax, [r10 + LP_FLEX_GROW_OFF]
    mov [rel layout_tmp_grow + r9*4], eax
    mov eax, [r10 + LP_FLEX_SHRINK_OFF]
    mov [rel layout_tmp_shrink + r9*4], eax
    inc r9d
    jmp .build

.built:
    test r9d, r9d
    jz .a_out

    xor esi, esi
    xor ecx, ecx
.sum1:
    cmp ecx, r9d
    jae .s1d
    mov eax, [rel layout_tmp_main + rcx*4]
    add esi, eax
    inc ecx
    jmp .sum1
.s1d:
    mov eax, [rbx + LP_GAP_OFF]
    mov r10d, r9d
    dec r10d
    jl .ng
    imul eax, r10d
    add esi, eax
.ng:
    test r8b, r8b
    jnz .av_row
    mov r10d, r14d
    mov r11d, r13d
    jmp .av_set
.av_row:
    mov r10d, r13d
    mov r11d, r14d
.av_set:
    mov eax, r10d
    sub eax, esi
    mov r15d, eax

    xor esi, esi
    xor ecx, ecx
.sg:
    cmp ecx, r9d
    jae .sgd
    mov eax, [rel layout_tmp_grow + rcx*4]
    add esi, eax
    inc ecx
    jmp .sg
.sgd:
    cmp r15d, 0
    jle .try_shrink
    cmp esi, 0
    je .try_shrink
    xor ecx, ecx
    mov edi, r15d
.grow_loop:
    cmp ecx, r9d
    jae .try_shrink
    mov eax, [rel layout_tmp_grow + rcx*4]
    test eax, eax
    jz .gnext
    push rbx
    mov ebx, eax
    mov eax, edi
    mul ebx
    div esi
    add [rel layout_tmp_main + rcx*4], eax
    pop rbx
.gnext:
    inc ecx
    jmp .grow_loop

.try_shrink:
    xor esi, esi
    xor ecx, ecx
.sum2:
    cmp ecx, r9d
    jae .s2d
    mov eax, [rel layout_tmp_main + rcx*4]
    add esi, eax
    inc ecx
    jmp .sum2
.s2d:
    mov eax, [rbx + LP_GAP_OFF]
    mov edx, r9d
    dec edx
    jl .ng2
    imul eax, edx
    add esi, eax
.ng2:
    mov eax, esi
    cmp eax, r10d
    jle .justify_setup
    sub eax, r10d
    mov r15d, eax
    xor esi, esi
    xor ecx, ecx
.ssum:
    cmp ecx, r9d
    jae .ssd
    mov eax, [rel layout_tmp_shrink + rcx*4]
    cmp eax, 0
    jne .ss1
    mov eax, 1
.ss1:
    add esi, eax
    inc ecx
    jmp .ssum
.ssd:
    cmp esi, 0
    je .justify_setup
    xor ecx, ecx
    mov edi, r15d
.sh_loop:
    cmp ecx, r9d
    jae .justify_setup
    mov eax, [rel layout_tmp_shrink + rcx*4]
    cmp eax, 0
    jne .sh_ok
    mov eax, 1
.sh_ok:
    imul eax, edi
    xor edx, edx
    div esi
    mov r11d, eax
    mov eax, [rel layout_tmp_main + rcx*4]
    sub eax, r11d
    cmp eax, 0
    jge .sh_st
    xor eax, eax
.sh_st:
    mov [rel layout_tmp_main + rcx*4], eax
    inc ecx
    jmp .sh_loop

.justify_setup:
    xor esi, esi
    xor ecx, ecx
.sum3:
    cmp ecx, r9d
    jae .s3d
    mov eax, [rel layout_tmp_main + rcx*4]
    add esi, eax
    inc ecx
    jmp .sum3
.s3d:
    mov eax, [rbx + LP_GAP_OFF]
    mov edi, r9d
    dec edi
    jl .ng3
    imul eax, edi
    jmp .ng3a
.ng3:
    xor eax, eax
.ng3a:
    add esi, eax
    mov eax, r10d
    sub eax, esi
    mov r15d, eax

    mov dword [rel layout_extra_between], 0
    mov eax, [rbx + LP_JUSTIFY_OFF]
    cmp eax, JUSTIFY_START
    je .j0
    cmp eax, JUSTIFY_CENTER
    je .j1
    cmp eax, JUSTIFY_END
    je .j2
    cmp eax, JUSTIFY_BETWEEN
    je .j3
    cmp eax, JUSTIFY_AROUND
    je .j4
.j0:
    xor r11d, r11d
    jmp .jgo
.j1:
    mov r11d, r15d
    sar r11d, 1
    jmp .jgo
.j2:
    mov r11d, r15d
    jmp .jgo
.j3:
    xor r11d, r11d
    cmp r9d, 1
    jle .jgo
    mov eax, r15d
    xor edx, edx
    mov ecx, r9d
    dec ecx
    test ecx, ecx
    jz .jgo
    div ecx
    mov [rel layout_extra_between], eax
    jmp .jgo
.j4:
    xor r11d, r11d
    cmp r9d, 1
    jle .j1
    mov eax, r15d
    xor edx, edx
    mov ecx, r9d
    dec ecx
    test ecx, ecx
    jz .jgo
    div ecx
    mov [rel layout_extra_between], eax
    mov r11d, eax
    sar r11d, 1
.jgo:

    xor ecx, ecx
.place:
    cmp ecx, r9d
    jae .rec_done
    mov rdi, [rel layout_vis_ptrs + rcx*8]
    call layout_child_lp
    mov r10, rax
    test r8b, r8b
    jz .pl_col

    mov eax, [rbx + FCD_PAD_LEFT_OFF]
    add eax, r11d
    mov esi, eax
    mov eax, [rel layout_tmp_main + rcx*4]
    mov edx, [r10 + LP_MARGIN_L_OFF]
    add esi, edx
    sub eax, edx
    sub eax, [r10 + LP_MARGIN_R_OFF]
    mov [rdi + W_X_OFF], esi
    mov [rdi + W_WIDTH_OFF], eax

    mov eax, [rbx + LP_ALIGN_OFF]
    cmp eax, ALIGN_STRETCH
    je .ra_st
    cmp eax, ALIGN_CENTER
    je .ra_ce
    cmp eax, ALIGN_END
    je .ra_en
    mov eax, [rbx + FCD_PAD_TOP_OFF]
    add eax, [r10 + LP_MARGIN_T_OFF]
    mov [rdi + W_Y_OFF], eax
    mov eax, [rel layout_tmp_cross + rcx*4]
    mov [rdi + W_HEIGHT_OFF], eax
    jmp .ra_done
.ra_st:
    mov eax, [rbx + FCD_PAD_TOP_OFF]
    mov [rdi + W_Y_OFF], eax
    mov eax, r14d
    sub eax, [r10 + LP_MARGIN_T_OFF]
    sub eax, [r10 + LP_MARGIN_B_OFF]
    mov [rdi + W_HEIGHT_OFF], eax
    jmp .ra_done
.ra_ce:
    mov eax, [rel layout_tmp_cross + rcx*4]
    mov edx, r14d
    sub edx, eax
    sar edx, 1
    add edx, [rbx + FCD_PAD_TOP_OFF]
    mov [rdi + W_Y_OFF], edx
    mov [rdi + W_HEIGHT_OFF], eax
    jmp .ra_done
.ra_en:
    mov eax, [rel layout_tmp_cross + rcx*4]
    mov edx, r14d
    sub edx, eax
    add edx, [rbx + FCD_PAD_TOP_OFF]
    sub edx, [r10 + LP_MARGIN_B_OFF]
    mov [rdi + W_Y_OFF], edx
    mov [rdi + W_HEIGHT_OFF], eax
.ra_done:
    mov eax, [rel layout_tmp_main + rcx*4]
    add eax, [rbx + LP_GAP_OFF]
    mov edx, ecx
    inc edx
    cmp edx, r9d
    jge .ra_no_bet
    add eax, [rel layout_extra_between]
.ra_no_bet:
    add r11d, eax
    jmp .pl_rec

.pl_col:
    mov eax, [rbx + FCD_PAD_TOP_OFF]
    add eax, r11d
    mov esi, eax
    mov eax, [rel layout_tmp_main + rcx*4]
    mov edx, [r10 + LP_MARGIN_T_OFF]
    add esi, edx
    sub eax, edx
    sub eax, [r10 + LP_MARGIN_B_OFF]
    mov [rdi + W_Y_OFF], esi
    mov [rdi + W_HEIGHT_OFF], eax

    mov eax, [rbx + LP_ALIGN_OFF]
    cmp eax, ALIGN_STRETCH
    je .ca_st
    cmp eax, ALIGN_CENTER
    je .ca_ce
    cmp eax, ALIGN_END
    je .ca_en
    mov eax, [rbx + FCD_PAD_LEFT_OFF]
    add eax, [r10 + LP_MARGIN_L_OFF]
    mov [rdi + W_X_OFF], eax
    mov eax, [rel layout_tmp_cross + rcx*4]
    mov [rdi + W_WIDTH_OFF], eax
    jmp .ca_done
.ca_st:
    mov eax, [rbx + FCD_PAD_LEFT_OFF]
    mov [rdi + W_X_OFF], eax
    mov eax, r13d
    sub eax, [r10 + LP_MARGIN_L_OFF]
    sub eax, [r10 + LP_MARGIN_R_OFF]
    mov [rdi + W_WIDTH_OFF], eax
    jmp .ca_done
.ca_ce:
    mov eax, [rel layout_tmp_cross + rcx*4]
    mov edx, r13d
    sub edx, eax
    sar edx, 1
    add edx, [rbx + FCD_PAD_LEFT_OFF]
    mov [rdi + W_X_OFF], edx
    mov [rdi + W_WIDTH_OFF], eax
    jmp .ca_done
.ca_en:
    mov eax, [rel layout_tmp_cross + rcx*4]
    mov edx, r13d
    sub edx, eax
    add edx, [rbx + FCD_PAD_LEFT_OFF]
    sub edx, [r10 + LP_MARGIN_R_OFF]
    mov [rdi + W_X_OFF], edx
    mov [rdi + W_WIDTH_OFF], eax
.ca_done:
    mov eax, [rel layout_tmp_main + rcx*4]
    add eax, [rbx + LP_GAP_OFF]
    mov edx, ecx
    inc edx
    cmp edx, r9d
    jge .ca_no_bet
    add eax, [rel layout_extra_between]
.ca_no_bet:
    add r11d, eax

.pl_rec:
    cmp dword [rdi + W_TYPE_OFF], WIDGET_CONTAINER
    jne .pl_next
    cmp qword [rdi + W_DATA_OFF], 0
    je .pl_next
    push rcx
    push r8
    push r9
    push r10
    push r11
    push r12
    call layout_arrange
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rcx
.pl_next:
    inc ecx
    jmp .place

.rec_done:
.a_out:
    pop r11
    pop r10
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
