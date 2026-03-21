; widget.asm — base Widget tree, hit-test, dirty, focus, render dispatch
%include "src/hal/linux_x86_64/defs.inc"
%include "src/gui/widget.inc"

extern arena_init
extern arena_destroy
extern arena_alloc

extern w_label_render
extern w_label_measure
extern w_label_handle_input
extern w_label_layout
extern w_label_destroy

extern w_button_render
extern w_button_measure
extern w_button_handle_input
extern w_button_layout
extern w_button_destroy

extern w_text_input_render
extern w_text_input_measure
extern w_text_input_handle_input
extern w_text_input_layout
extern w_text_input_destroy

extern w_text_area_render
extern w_text_area_measure
extern w_text_area_handle_input
extern w_text_area_layout
extern w_text_area_destroy

extern w_list_render
extern w_list_measure
extern w_list_handle_input
extern w_list_layout
extern w_list_destroy

extern w_table_render
extern w_table_measure
extern w_table_handle_input
extern w_table_layout
extern w_table_destroy

extern w_tree_render
extern w_tree_measure
extern w_tree_handle_input
extern w_tree_layout
extern w_tree_destroy

extern w_scrollbar_render
extern w_scrollbar_measure
extern w_scrollbar_handle_input
extern w_scrollbar_layout
extern w_scrollbar_destroy

extern w_radial_render
extern w_radial_measure
extern w_radial_handle_input
extern w_radial_layout
extern w_radial_destroy

extern w_bottom_sheet_render
extern w_bottom_sheet_measure
extern w_bottom_sheet_handle_input
extern w_bottom_sheet_layout
extern w_bottom_sheet_destroy

extern w_tab_bar_render
extern w_tab_bar_measure
extern w_tab_bar_handle_input
extern w_tab_bar_layout
extern w_tab_bar_destroy

extern w_progress_render
extern w_progress_measure
extern w_progress_handle_input
extern w_progress_layout
extern w_progress_destroy

extern w_dialog_render
extern w_dialog_measure
extern w_dialog_handle_input
extern w_dialog_layout
extern w_dialog_destroy

extern w_status_render
extern w_status_measure
extern w_status_handle_input
extern w_status_layout
extern w_status_destroy

extern w_split_render
extern w_split_measure
extern w_split_handle_input
extern w_split_layout
extern w_split_destroy

extern w_container_render
extern w_container_measure
extern w_container_handle_input
extern w_container_layout
extern w_container_destroy

section .bss
    widget_arena_ptr        resq 1
    widget_focused_ptr    resq 1
    widget_next_id          resd 1
    widget_pad              resd 1

section .text

global widget_system_init
global widget_system_shutdown
global widget_init
global widget_add_child
global widget_remove_child
global widget_render
global widget_handle_input
global widget_set_dirty
global widget_hit_test
global widget_focus
global widget_destroy
global widget_measure
global widget_layout
global widget_abs_pos
global widget_arena_alloc

; widget_arena_alloc(size rdi) -> rax ptr
widget_arena_alloc:
    mov rsi, rdi
    mov rdi, [rel widget_arena_ptr]
    jmp arena_alloc

; widget_system_init() -> rax 0 ok, -1 fail
widget_system_init:
    mov qword [rel widget_arena_ptr], 0
    mov qword [rel widget_focused_ptr], 0
    mov dword [rel widget_next_id], 1
    mov rdi, 512 * 1024
    call arena_init
    test rax, rax
    jz .bad
    mov [rel widget_arena_ptr], rax
    xor eax, eax
    ret
.bad:
    mov eax, -1
    ret

widget_system_shutdown:
    mov rdi, [rel widget_arena_ptr]
    test rdi, rdi
    jz .done
    call arena_destroy
    mov qword [rel widget_arena_ptr], 0
.done:
    ret

; widget_init(type edi, x esi, y edx, w ecx, h r8d) -> rax Widget*
widget_init:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push r8                       ; height (r8 clobbered by arena_alloc)
    mov r12d, edi                 ; type
    mov r13d, esi                 ; x
    mov r14d, edx                 ; y
    mov r15d, ecx                 ; w

    mov rdi, [rel widget_arena_ptr]
    test rdi, rdi
    jz .fail
    mov rsi, WIDGET_STRUCT_SIZE
    call arena_alloc
    test rax, rax
    jz .fail
    mov rbx, rax
    mov rdi, rbx
    mov rcx, WIDGET_STRUCT_SIZE / 8
    xor eax, eax
    rep stosq

    mov dword [rbx + W_TYPE_OFF], r12d
    mov ecx, [rel widget_next_id]
    mov [rbx + W_ID_OFF], ecx
    inc dword [rel widget_next_id]

    mov dword [rbx + W_X_OFF], r13d
    mov dword [rbx + W_Y_OFF], r14d
    mov dword [rbx + W_WIDTH_OFF], r15d
    pop rsi
    mov [rbx + W_HEIGHT_OFF], esi

    mov dword [rbx + W_VISIBLE_OFF], 1
    mov dword [rbx + W_ENABLED_OFF], 1
    mov dword [rbx + W_FOCUSED_OFF], 0
    mov dword [rbx + W_DIRTY_OFF], 1

    mov edi, r12d
    mov rsi, rbx
    call .set_vtable
    mov rax, rbx

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.fail:
    xor eax, eax
    pop r8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; set_vtable(edi=type, rsi=widget*)
.set_vtable:
    cmp edi, WIDGET_LABEL
    je .lbl
    cmp edi, WIDGET_BUTTON
    je .btn
    cmp edi, WIDGET_TEXT_INPUT
    je .tin
    cmp edi, WIDGET_TEXT_AREA
    je .tar
    cmp edi, WIDGET_LIST
    je .lst
    cmp edi, WIDGET_TABLE
    je .tbl
    cmp edi, WIDGET_TREE
    je .tre
    cmp edi, WIDGET_SCROLLBAR
    je .scr
    cmp edi, WIDGET_RADIAL_MENU
    je .rad
    cmp edi, WIDGET_BOTTOM_SHEET
    je .bs
    cmp edi, WIDGET_TAB_BAR
    je .tab
    cmp edi, WIDGET_PROGRESS_BAR
    je .prg
    cmp edi, WIDGET_DIALOG
    je .dlg
    cmp edi, WIDGET_STATUS_BAR
    je .stb
    cmp edi, WIDGET_SPLIT_PANE
    je .spt
    jmp .ctr
.lbl:
    lea rax, [rel w_label_render]
    mov [rsi + W_FN_RENDER_OFF], rax
    lea rax, [rel w_label_handle_input]
    mov [rsi + W_FN_HANDLE_OFF], rax
    lea rax, [rel w_label_measure]
    mov [rsi + W_FN_MEASURE_OFF], rax
    lea rax, [rel w_label_layout]
    mov [rsi + W_FN_LAYOUT_OFF], rax
    lea rax, [rel w_label_destroy]
    mov [rsi + W_FN_DESTROY_OFF], rax
    ret
.btn:
    lea rax, [rel w_button_render]
    mov [rsi + W_FN_RENDER_OFF], rax
    lea rax, [rel w_button_handle_input]
    mov [rsi + W_FN_HANDLE_OFF], rax
    lea rax, [rel w_button_measure]
    mov [rsi + W_FN_MEASURE_OFF], rax
    lea rax, [rel w_button_layout]
    mov [rsi + W_FN_LAYOUT_OFF], rax
    lea rax, [rel w_button_destroy]
    mov [rsi + W_FN_DESTROY_OFF], rax
    ret
.tin:
    lea rax, [rel w_text_input_render]
    mov [rsi + W_FN_RENDER_OFF], rax
    lea rax, [rel w_text_input_handle_input]
    mov [rsi + W_FN_HANDLE_OFF], rax
    lea rax, [rel w_text_input_measure]
    mov [rsi + W_FN_MEASURE_OFF], rax
    lea rax, [rel w_text_input_layout]
    mov [rsi + W_FN_LAYOUT_OFF], rax
    lea rax, [rel w_text_input_destroy]
    mov [rsi + W_FN_DESTROY_OFF], rax
    ret
.tar:
    lea rax, [rel w_text_area_render]
    mov [rsi + W_FN_RENDER_OFF], rax
    lea rax, [rel w_text_area_handle_input]
    mov [rsi + W_FN_HANDLE_OFF], rax
    lea rax, [rel w_text_area_measure]
    mov [rsi + W_FN_MEASURE_OFF], rax
    lea rax, [rel w_text_area_layout]
    mov [rsi + W_FN_LAYOUT_OFF], rax
    lea rax, [rel w_text_area_destroy]
    mov [rsi + W_FN_DESTROY_OFF], rax
    ret
.lst:
    lea rax, [rel w_list_render]
    mov [rsi + W_FN_RENDER_OFF], rax
    lea rax, [rel w_list_handle_input]
    mov [rsi + W_FN_HANDLE_OFF], rax
    lea rax, [rel w_list_measure]
    mov [rsi + W_FN_MEASURE_OFF], rax
    lea rax, [rel w_list_layout]
    mov [rsi + W_FN_LAYOUT_OFF], rax
    lea rax, [rel w_list_destroy]
    mov [rsi + W_FN_DESTROY_OFF], rax
    ret
.tbl:
    lea rax, [rel w_table_render]
    mov [rsi + W_FN_RENDER_OFF], rax
    lea rax, [rel w_table_handle_input]
    mov [rsi + W_FN_HANDLE_OFF], rax
    lea rax, [rel w_table_measure]
    mov [rsi + W_FN_MEASURE_OFF], rax
    lea rax, [rel w_table_layout]
    mov [rsi + W_FN_LAYOUT_OFF], rax
    lea rax, [rel w_table_destroy]
    mov [rsi + W_FN_DESTROY_OFF], rax
    ret
.tre:
    lea rax, [rel w_tree_render]
    mov [rsi + W_FN_RENDER_OFF], rax
    lea rax, [rel w_tree_handle_input]
    mov [rsi + W_FN_HANDLE_OFF], rax
    lea rax, [rel w_tree_measure]
    mov [rsi + W_FN_MEASURE_OFF], rax
    lea rax, [rel w_tree_layout]
    mov [rsi + W_FN_LAYOUT_OFF], rax
    lea rax, [rel w_tree_destroy]
    mov [rsi + W_FN_DESTROY_OFF], rax
    ret
.scr:
    lea rax, [rel w_scrollbar_render]
    mov [rsi + W_FN_RENDER_OFF], rax
    lea rax, [rel w_scrollbar_handle_input]
    mov [rsi + W_FN_HANDLE_OFF], rax
    lea rax, [rel w_scrollbar_measure]
    mov [rsi + W_FN_MEASURE_OFF], rax
    lea rax, [rel w_scrollbar_layout]
    mov [rsi + W_FN_LAYOUT_OFF], rax
    lea rax, [rel w_scrollbar_destroy]
    mov [rsi + W_FN_DESTROY_OFF], rax
    ret
.rad:
    lea rax, [rel w_radial_render]
    mov [rsi + W_FN_RENDER_OFF], rax
    lea rax, [rel w_radial_handle_input]
    mov [rsi + W_FN_HANDLE_OFF], rax
    lea rax, [rel w_radial_measure]
    mov [rsi + W_FN_MEASURE_OFF], rax
    lea rax, [rel w_radial_layout]
    mov [rsi + W_FN_LAYOUT_OFF], rax
    lea rax, [rel w_radial_destroy]
    mov [rsi + W_FN_DESTROY_OFF], rax
    ret
.bs:
    lea rax, [rel w_bottom_sheet_render]
    mov [rsi + W_FN_RENDER_OFF], rax
    lea rax, [rel w_bottom_sheet_handle_input]
    mov [rsi + W_FN_HANDLE_OFF], rax
    lea rax, [rel w_bottom_sheet_measure]
    mov [rsi + W_FN_MEASURE_OFF], rax
    lea rax, [rel w_bottom_sheet_layout]
    mov [rsi + W_FN_LAYOUT_OFF], rax
    lea rax, [rel w_bottom_sheet_destroy]
    mov [rsi + W_FN_DESTROY_OFF], rax
    ret
.tab:
    lea rax, [rel w_tab_bar_render]
    mov [rsi + W_FN_RENDER_OFF], rax
    lea rax, [rel w_tab_bar_handle_input]
    mov [rsi + W_FN_HANDLE_OFF], rax
    lea rax, [rel w_tab_bar_measure]
    mov [rsi + W_FN_MEASURE_OFF], rax
    lea rax, [rel w_tab_bar_layout]
    mov [rsi + W_FN_LAYOUT_OFF], rax
    lea rax, [rel w_tab_bar_destroy]
    mov [rsi + W_FN_DESTROY_OFF], rax
    ret
.prg:
    lea rax, [rel w_progress_render]
    mov [rsi + W_FN_RENDER_OFF], rax
    lea rax, [rel w_progress_handle_input]
    mov [rsi + W_FN_HANDLE_OFF], rax
    lea rax, [rel w_progress_measure]
    mov [rsi + W_FN_MEASURE_OFF], rax
    lea rax, [rel w_progress_layout]
    mov [rsi + W_FN_LAYOUT_OFF], rax
    lea rax, [rel w_progress_destroy]
    mov [rsi + W_FN_DESTROY_OFF], rax
    ret
.dlg:
    lea rax, [rel w_dialog_render]
    mov [rsi + W_FN_RENDER_OFF], rax
    lea rax, [rel w_dialog_handle_input]
    mov [rsi + W_FN_HANDLE_OFF], rax
    lea rax, [rel w_dialog_measure]
    mov [rsi + W_FN_MEASURE_OFF], rax
    lea rax, [rel w_dialog_layout]
    mov [rsi + W_FN_LAYOUT_OFF], rax
    lea rax, [rel w_dialog_destroy]
    mov [rsi + W_FN_DESTROY_OFF], rax
    ret
.stb:
    lea rax, [rel w_status_render]
    mov [rsi + W_FN_RENDER_OFF], rax
    lea rax, [rel w_status_handle_input]
    mov [rsi + W_FN_HANDLE_OFF], rax
    lea rax, [rel w_status_measure]
    mov [rsi + W_FN_MEASURE_OFF], rax
    lea rax, [rel w_status_layout]
    mov [rsi + W_FN_LAYOUT_OFF], rax
    lea rax, [rel w_status_destroy]
    mov [rsi + W_FN_DESTROY_OFF], rax
    ret
.spt:
    lea rax, [rel w_split_render]
    mov [rsi + W_FN_RENDER_OFF], rax
    lea rax, [rel w_split_handle_input]
    mov [rsi + W_FN_HANDLE_OFF], rax
    lea rax, [rel w_split_measure]
    mov [rsi + W_FN_MEASURE_OFF], rax
    lea rax, [rel w_split_layout]
    mov [rsi + W_FN_LAYOUT_OFF], rax
    lea rax, [rel w_split_destroy]
    mov [rsi + W_FN_DESTROY_OFF], rax
    ret
.ctr:
    lea rax, [rel w_container_render]
    mov [rsi + W_FN_RENDER_OFF], rax
    lea rax, [rel w_container_handle_input]
    mov [rsi + W_FN_HANDLE_OFF], rax
    lea rax, [rel w_container_measure]
    mov [rsi + W_FN_MEASURE_OFF], rax
    lea rax, [rel w_container_layout]
    mov [rsi + W_FN_LAYOUT_OFF], rax
    lea rax, [rel w_container_destroy]
    mov [rsi + W_FN_DESTROY_OFF], rax
    ret

; widget_add_child(parent rdi, child rsi)
widget_add_child:
    push rbx
    push r12
    push r13
    mov r12, rdi
    mov r13, rsi
    test r12, r12
    jz .bad
    test r13, r13
    jz .bad
    mov rdi, [r13 + W_PARENT_OFF]
    test rdi, rdi
    jz .no_old
    mov rsi, r13
    call widget_remove_child
.no_old:
    mov rax, [r12 + W_CHILDREN_OFF]
    test rax, rax
    jnz .have_arr
    mov rdi, [rel widget_arena_ptr]
    test rdi, rdi
    jz .bad
    mov esi, 8 * 8
    call arena_alloc
    test rax, rax
    jz .bad
    mov [r12 + W_CHILDREN_OFF], rax
    mov dword [r12 + W_CHILD_CAP_OFF], 8
    mov dword [r12 + W_CHILD_COUNT_OFF], 0
.have_arr:
    mov ecx, [r12 + W_CHILD_COUNT_OFF]
    mov edx, [r12 + W_CHILD_CAP_OFF]
    cmp ecx, edx
    jb .room
    ; grow: alloc cap*2*8
    mov rdi, [rel widget_arena_ptr]
    mov esi, edx
    shl esi, 4
    call arena_alloc
    test rax, rax
    jz .bad
    mov rbx, rax
    mov r8, [r12 + W_CHILDREN_OFF]
    xor ecx, ecx
.copy:
    cmp ecx, [r12 + W_CHILD_COUNT_OFF]
    jae .copied
    mov rax, [r8 + rcx*8]
    mov [rbx + rcx*8], rax
    inc ecx
    jmp .copy
.copied:
    mov eax, [r12 + W_CHILD_CAP_OFF]
    add eax, eax
    mov [r12 + W_CHILD_CAP_OFF], eax
    mov [r12 + W_CHILDREN_OFF], rbx
.room:
    mov ecx, [r12 + W_CHILD_COUNT_OFF]
    mov rax, [r12 + W_CHILDREN_OFF]
    mov [rax + rcx*8], r13
    inc dword [r12 + W_CHILD_COUNT_OFF]
    mov [r13 + W_PARENT_OFF], r12
    mov rdi, r12
    call widget_set_dirty
    mov eax, 1
    pop r13
    pop r12
    pop rbx
    ret
.bad:
    xor eax, eax
    pop r13
    pop r12
    pop rbx
    ret

; widget_remove_child(parent rdi, child rsi)
widget_remove_child:
    push rbx
    push r12
    push r13
    mov r12, rdi
    mov r13, rsi
    test r12, r12
    jz .bad
    test r13, r13
    jz .bad
    mov rax, [r12 + W_CHILDREN_OFF]
    test rax, rax
    jz .bad
    xor ebx, ebx
.find:
    cmp ebx, [r12 + W_CHILD_COUNT_OFF]
    jae .bad
    cmp [rax + rbx*8], r13
    je .found
    inc ebx
    jmp .find
.found:
    mov ecx, [r12 + W_CHILD_COUNT_OFF]
    dec ecx
    mov [r12 + W_CHILD_COUNT_OFF], ecx
    mov rdx, [rax + rcx*8]
    mov [rax + rbx*8], rdx
    mov qword [r13 + W_PARENT_OFF], 0
    mov rdi, r12
    call widget_set_dirty
    mov eax, 1
    pop r13
    pop r12
    pop rbx
    ret
.bad:
    xor eax, eax
    pop r13
    pop r12
    pop rbx
    ret

; widget_set_dirty(widget rdi)
widget_set_dirty:
    test rdi, rdi
    jz .done
.loop:
    mov dword [rdi + W_DIRTY_OFF], 1
    mov rdi, [rdi + W_PARENT_OFF]
    test rdi, rdi
    jnz .loop
.done:
    ret

; widget_abs_pos(widget rdi, esi* out_x, rdx* out_y)
widget_abs_pos:
    push rbx
    xor ebx, ebx
    xor ecx, ecx
    mov r8, rdi
.walk:
    test r8, r8
    jz .store
    add ebx, [r8 + W_X_OFF]
    add ecx, [r8 + W_Y_OFF]
    mov r8, [r8 + W_PARENT_OFF]
    jmp .walk
.store:
    mov [rsi], ebx
    mov [rdx], ecx
    pop rbx
    ret

; widget_measure(widget rdi, esi max_w, edx max_h)
widget_measure:
    test rdi, rdi
    jz .done
    mov rax, [rdi + W_FN_MEASURE_OFF]
    test rax, rax
    jz .done
    jmp rax
.done:
    ret

; widget_layout(widget rdi)
widget_layout:
    test rdi, rdi
    jz .done
    mov rax, [rdi + W_FN_LAYOUT_OFF]
    test rax, rax
    jz .done
    jmp rax
.done:
    ret

; widget_render(widget rdi, rsi canvas, rdx theme, ecx abs_x, r8d abs_y)
widget_render:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13, rsi
    mov r14, rdx
    mov r15d, ecx                  ; parent abs x
    mov ebx, r8d                   ; parent abs y

    test r12, r12
    jz .out
    cmp dword [r12 + W_VISIBLE_OFF], 0
    je .out

    mov eax, [r12 + W_X_OFF]
    add eax, r15d
    mov r15d, eax                ; this abs x (reuse r15)

    mov eax, [r12 + W_Y_OFF]
    add eax, ebx
    mov ebx, eax                 ; this abs y

    cmp dword [r12 + W_DIRTY_OFF], 0
    je .skip_self
    mov rax, [r12 + W_FN_RENDER_OFF]
    test rax, rax
    jz .after_render
    mov rdi, r12
    mov rsi, r13
    mov rdx, r14
    mov ecx, r15d
    mov r8d, ebx
    call rax
.after_render:
    mov dword [r12 + W_DIRTY_OFF], 0
    jmp .kids
.skip_self:
.kids:
    push r10
    xor r10d, r10d
.child_loop:
    cmp r10d, [r12 + W_CHILD_COUNT_OFF]
    jae .kids_done
    mov rax, [r12 + W_CHILDREN_OFF]
    mov rdi, [rax + r10*8]
    mov rsi, r13
    mov rdx, r14
    mov ecx, r15d
    mov r8d, ebx
    call widget_render
    inc r10d
    jmp .child_loop
.kids_done:
    pop r10
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; widget_hit_test(widget rdi, esi x, edx y, ecx abs_x, r8d abs_y) -> rax Widget*
widget_hit_test:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi
    mov r14d, edx
    mov ebx, ecx
    mov r15d, r8d

    test r12, r12
    jz .nil
    cmp dword [r12 + W_VISIBLE_OFF], 0
    jz .nil

    mov eax, [r12 + W_X_OFF]
    add eax, ebx
    mov ecx, eax                 ; this abs x

    mov eax, [r12 + W_Y_OFF]
    add eax, r15d
    mov edx, eax                 ; this abs y

    cmp r13d, ecx
    jl .nil
    cmp r14d, edx
    jl .nil
    mov eax, [r12 + W_WIDTH_OFF]
    add eax, ecx
    cmp r13d, eax
    jge .nil
    mov eax, [r12 + W_HEIGHT_OFF]
    add eax, edx
    cmp r14d, eax
    jge .nil

    mov rbx, r12
    push rdx                     ; save this abs y
    mov r15d, ecx                ; this abs x (reuse r15)

    mov eax, [r12 + W_CHILD_COUNT_OFF]
    test eax, eax
    jz .ret_cand
    dec eax
.walk:
    jl .ret_cand
    mov r9, [r12 + W_CHILDREN_OFF]
    push rax
    mov rdi, [r9 + rax*8]
    mov esi, r13d
    mov edx, r14d
    mov ecx, r15d
    mov r8d, dword [rsp + 8]       ; parent abs_y ([rsp]=saved index, [rsp+8]=push rdx)
    call widget_hit_test
    pop r9                         ; loop index — must not clobber rax (child hit ptr)
    test rax, rax
    jnz .ret_pop
    mov eax, r9d
    dec eax
    jmp .walk
.ret_cand:
    mov rax, rbx
.ret_pop:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.nil:
    xor eax, eax
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; widget_handle_input(root rdi, event rsi) -> eax consumed 1/0
widget_handle_input:
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 16
    mov r12, rdi
    mov r13, rsi
    test r12, r12
    jz .no
    test r13, r13
    jz .no

    mov eax, [r13 + IE_TYPE_OFF]
    cmp eax, INPUT_MOUSE_BUTTON
    je .xy
    cmp eax, INPUT_TOUCH_DOWN
    je .xy
    cmp eax, INPUT_TOUCH_UP
    je .xy
    cmp eax, INPUT_TOUCH_MOVE
    je .xy
    cmp eax, INPUT_SCROLL
    je .xy
    cmp eax, INPUT_KEY
    jne .bubble

.xy:
    mov esi, [r13 + IE_MOUSE_X_OFF]
    mov edx, [r13 + IE_MOUSE_Y_OFF]
    xor ecx, ecx
    xor r8d, r8d
    mov rdi, r12
    call widget_hit_test
    jmp .got_hit

.bubble:
    mov rdi, r12
    call widget_hit_deepest_focused

.got_hit:
    test rax, rax
    jz .no
    mov r14, rax
    cmp dword [r14 + W_ENABLED_OFF], 0
    je .no

    lea rsi, [rsp + 8]
    lea rdx, [rsp + 12]
    mov rdi, r14
    call widget_abs_pos
    mov edx, [rsp + 8]
    mov ecx, [rsp + 12]

    mov rax, [r14 + W_FN_HANDLE_OFF]
    test rax, rax
    jz .no
    mov rdi, r14
    mov rsi, r13
    call rax
    add rsp, 16
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

.no:
    xor eax, eax
    add rsp, 16
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; widget_hit_deepest_focused(root rdi) -> rax widget or 0
widget_hit_deepest_focused:
    mov rax, [rel widget_focused_ptr]
    test rax, rax
    jnz .check_root
    xor eax, eax
    ret
.check_root:
    ; ensure focused is within root subtree
    mov rcx, rax
.walk_up:
    test rcx, rcx
    jz .bad
    cmp rcx, rdi
    je .ok
    mov rcx, [rcx + W_PARENT_OFF]
    jmp .walk_up
.bad:
    xor eax, eax
    ret
.ok:
    mov rax, [rel widget_focused_ptr]
    ret

; widget_focus(widget rdi)
widget_focus:
    push rbx
    mov rbx, rdi
    mov rdi, [rel widget_focused_ptr]
    test rdi, rdi
    jz .set_new
    cmp rdi, rbx
    je .same
    mov dword [rdi + W_FOCUSED_OFF], 0
.set_new:
    mov [rel widget_focused_ptr], rbx
    test rbx, rbx
    jz .done
    mov dword [rbx + W_FOCUSED_OFF], 1
    mov rdi, rbx
    call widget_set_dirty
.same:
.done:
    pop rbx
    ret

; widget_destroy(widget rdi)
widget_destroy:
    push rbx
    push r12
    push r13
    push r14
    mov r12, rdi
    test r12, r12
    jz .out
    mov r13d, [r12 + W_CHILD_COUNT_OFF]
    mov r14, [r12 + W_CHILDREN_OFF]
    xor ebx, ebx
.child:
    cmp ebx, r13d
    jae .free_kids
    mov rdi, [r14 + rbx*8]
    call widget_destroy
    inc ebx
    jmp .child
.free_kids:
    mov rax, [r12 + W_FN_DESTROY_OFF]
    test rax, rax
    jz .unfocus
    mov rdi, r12
    call rax
.unfocus:
    cmp r12, [rel widget_focused_ptr]
    jne .out
    mov qword [rel widget_focused_ptr], 0
.out:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
