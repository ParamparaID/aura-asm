; fm_main.asm — File Manager container/state
%include "src/hal/linux_x86_64/defs.inc"
%include "src/gui/widget.inc"
%include "src/fm/panel.inc"

extern panel_init
extern panel_get_marked
extern panel_navigate
extern panel_go_parent
extern panel_load
extern panel_go_path
extern panel_toggle_mark
extern file_panel_create
extern font_draw_string
extern canvas_draw_string
extern canvas_fill_rect
extern canvas_fill_rect_alpha
extern canvas_fill_rounded_rect
extern widget_init
extern widget_add_child
extern widget_layout
extern widget_render
extern widget_handle_input
extern widget_arena_alloc
extern op_copy
extern op_move
extern op_delete
extern vfs_mkdir
extern vfs_path_len
extern vfs_sftp_connect
extern viewer_open
extern viewer_close
extern viewer_render
extern viewer_handle_input
extern fm_status_bar_render
extern threadpool_init
extern threadpool_submit
extern op_copy_async

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
%define FM_CONN_ACTIVE_OFF         (FM_TMP_COUNT_OFF + 8)
%define FM_CONN_FIELD_OFF          (FM_CONN_ACTIVE_OFF + 4)
%define FM_CONN_STATUS_LEN_OFF     (FM_CONN_FIELD_OFF + 4)
%define FM_CONN_STATUS_KIND_OFF    (FM_CONN_STATUS_LEN_OFF + 4)
%define FM_CONN_HOST_OFF           (FM_CONN_STATUS_KIND_OFF + 4)
%define FM_CONN_PORT_OFF           (FM_CONN_HOST_OFF + 128)
%define FM_CONN_USER_OFF           (FM_CONN_PORT_OFF + 16)
%define FM_CONN_PASS_OFF           (FM_CONN_USER_OFF + 64)
%define FM_CONN_STATUS_OFF         (FM_CONN_PASS_OFF + 64)
%define FM_CONN_URI_OFF            (FM_CONN_STATUS_OFF + 128)
%define FM_REMOTE_CONNECTED_OFF    (FM_CONN_URI_OFF + 256)
%define FM_REMOTE_HOST_OFF         (FM_REMOTE_CONNECTED_OFF + 4)
%define FM_STATUS_PATH_OFF         (FM_REMOTE_HOST_OFF + 128)
%define FM_STATUS_SUMMARY_OFF      (FM_STATUS_PATH_OFF + 256)
%define FM_STATUS_FREE_OFF         (FM_STATUS_SUMMARY_OFF + 128)
%define FM_PROGRESS_ACTIVE_OFF     (FM_STATUS_FREE_OFF + 64)
%define FM_PROGRESS_PERCENT_OFF    (FM_PROGRESS_ACTIVE_OFF + 4)
%define FM_PROGRESS_CANCEL_OFF     (FM_PROGRESS_PERCENT_OFF + 4)
%define FM_PROGRESS_TITLE_OFF      (FM_PROGRESS_CANCEL_OFF + 4)
%define FM_BLOOM_ACTIVE_OFF        (FM_PROGRESS_TITLE_OFF + 128)
%define FM_BLOOM_SELECTED_OFF      (FM_BLOOM_ACTIVE_OFF + 4)
%define FM_STRUCT_SIZE             (FM_BLOOM_SELECTED_OFF + 4)

%define FM_STATUS_NEUTRAL          0
%define FM_STATUS_OK               1
%define FM_STATUS_ERR              2
%define FM_CONN_HISTORY_MAX        5

%define FM_MAX_INSTANCES           4
%define INPUT_EVENT_MODIFIERS_OFF  24
%define KEY_TAB                    15
%define KEY_F                      33
%define KEY_ESC                    1
%define KEY_ENTER                  28
%define KEY_BACKSPACE              14
%define KEY_UP                     103
%define KEY_DOWN                   108
%define KEY_LEFT                   105
%define KEY_RIGHT                  106
%define KEY_F1                     59
%define KEY_F2                     60
%define KEY_F3                     61
%define KEY_F4                     62
%define KEY_F5                     63
%define KEY_F6                     64
%define KEY_F7                     65
%define KEY_F8                     66
%define KEY_F9                     67
%define KEY_F10                    68
%define MOD_CTRL                   0x02

; split pane private data (shared with split_pane.asm)
%define SP_POS                     0
%define SP_DRAG                    4
%define SP_LASTX                   8
%define SP_DATA_SIZE               16

section .rodata
    fm_sftp_host_default           db "localhost",0
    fm_sftp_port_default           db "22",0
    fm_sftp_user_default           db "user",0
    fm_conn_title                  db "Connect SFTP",0
    fm_conn_lbl_host               db "Host:",0
    fm_conn_lbl_port               db "Port:",0
    fm_conn_lbl_user               db "User:",0
    fm_conn_lbl_pass               db "Password:",0
    fm_conn_status_ok              db "Connected",0
    fm_conn_status_fail            db "Connect failed",0
    fm_conn_status_open_fail       db "Open path failed",0
    fm_conn_status_host_required   db "Host is required",0
    fm_conn_status_port_invalid    db "Port must be 1..65535",0
    fm_conn_hint                   db "Tab=next Enter=connect Esc=cancel Up/Down=history",0
    fm_conn_btn_connect            db "Connect",0
    fm_conn_btn_cancel             db "Cancel",0
    fm_status_connected_prefix     db "Connected to ",0
    fm_conn_hist_prefix            db "History: ",0
    fm_conn_hist_none              db "History: (empty)",0
    fm_sftp_uri_a                  db "sftp://",0
    fm_sftp_uri_at                 db "@",0
    fm_sftp_uri_colon              db ":",0
    fm_sftp_uri_home               db "/home/",0
    fm_sftp_uri_tmp                db "/tmp",0
    fm_progress_copy               db "Copying...",0
    fm_progress_delete             db "Deleting...",0
    fm_overlay_text                db "[FM ACTIVE]",0
    fm_overlay_text_len            equ 11
    fm_left_label                  db "LEFT PANEL",0
    fm_left_label_len              equ 10
    fm_right_label                 db "RIGHT PANEL",0
    fm_right_label_len             equ 11
    fm_stub_label                  db "VFS STUB: NO ENTRIES YET",0
    fm_stub_label_len              equ 24
    fm_bloom_title                 db "Context Bloom",0
    fm_bloom_0                     db "Open",0
    fm_bloom_1                     db "Copy",0
    fm_bloom_2                     db "Move",0
    fm_bloom_3                     db "Delete",0
    fm_bloom_4                     db "Rename",0
    fm_bloom_5                     db "Properties",0
    fm_bloom_6                     db "Archive",0
    fm_bloom_7                     db "Open in Terminal",0
    fm_bloom_8                     db "Extract Here",0
    fm_bloom_9                     db "Extract To...",0
    fm_status_todo                 db "Action is queued for Phase 5 polish",0

section .bss
    fm_pool                        resb FM_STRUCT_SIZE * FM_MAX_INSTANCES
    fm_used                        resb FM_MAX_INSTANCES
    fm_conn_mask_buf               resb 96
    fm_conn_hist_hosts             resb 128 * FM_CONN_HISTORY_MAX
    fm_conn_hist_ports             resb 16 * FM_CONN_HISTORY_MAX
    fm_conn_hist_users             resb 64 * FM_CONN_HISTORY_MAX
    fm_conn_hist_count             resd 1
    fm_conn_hist_sel               resd 1
    fm_threadpool_ptr              resq 1
    fm_async_task                  resq 8
    fm_progress_owner              resq 1

section .text
global fm_init
global fm_render
global fm_handle_input
global fm_copy_selected
global fm_delete_selected
global fm_mkdir
global fm_open_path

fm_cstr_len:
    xor eax, eax
.l:
    cmp byte [rdi + rax], 0
    je .o
    inc eax
    jmp .l
.o:
    ret

fm_copy_cstr:
    ; (src rdi, dst rsi, max edx) -> eax len or -1
    test edx, edx
    jle .fail
    xor ecx, ecx
.cp:
    cmp ecx, edx
    jae .fail
    mov al, [rdi + rcx]
    mov [rsi + rcx], al
    test al, al
    jz .ok
    inc ecx
    jmp .cp
.ok:
    mov eax, ecx
    ret
.fail:
    mov eax, -1
    ret

fm_append_cstr:
    ; (dst rdi, src rsi, end rdx) -> rax new dst or 0
    push rbx
    mov rbx, rdi
.l:
    mov al, [rsi]
    test al, al
    jz .ok
    cmp rbx, rdx
    jae .fail
    mov [rbx], al
    inc rbx
    inc rsi
    jmp .l
.ok:
    mov rax, rbx
    pop rbx
    ret
.fail:
    xor eax, eax
    pop rbx
    ret

fm_set_status:
    ; (fm rdi, msg rsi)
    mov edx, FM_STATUS_NEUTRAL
    jmp fm_set_status_kind

fm_set_status_kind:
    ; (fm rdi, msg rsi, kind edx)
    push rbx
    push r12
    mov rbx, rdi
    mov r12d, edx
    mov rdi, rsi
    lea rsi, [rbx + FM_CONN_STATUS_OFF]
    mov edx, 128
    call fm_copy_cstr
    test eax, eax
    js .out
    mov [rbx + FM_CONN_STATUS_LEN_OFF], eax
    mov [rbx + FM_CONN_STATUS_KIND_OFF], r12d
.out:
    pop r12
    pop rbx
    ret

fm_history_apply:
    ; (fm rdi, index esi) -> eax 0/-1
    push rbx
    push r12
    mov rbx, rdi
    mov r12d, esi
    cmp r12d, 0
    jl .fail
    cmp r12d, [rel fm_conn_hist_count]
    jge .fail

    mov eax, r12d
    imul eax, 128
    lea rdi, [rel fm_conn_hist_hosts + rax]
    lea rsi, [rbx + FM_CONN_HOST_OFF]
    mov edx, 128
    call fm_copy_cstr
    test eax, eax
    js .fail

    mov eax, r12d
    imul eax, 16
    lea rdi, [rel fm_conn_hist_ports + rax]
    lea rsi, [rbx + FM_CONN_PORT_OFF]
    mov edx, 16
    call fm_copy_cstr
    test eax, eax
    js .fail

    mov eax, r12d
    imul eax, 64
    lea rdi, [rel fm_conn_hist_users + rax]
    lea rsi, [rbx + FM_CONN_USER_OFF]
    mov edx, 64
    call fm_copy_cstr
    test eax, eax
    js .fail

    xor eax, eax
    pop r12
    pop rbx
    ret
.fail:
    mov eax, -1
    pop r12
    pop rbx
    ret

fm_hist_cmp_str:
    ; (a rdi, b rsi) -> eax 0 match / 1 differ
    xor ecx, ecx
.l:
    mov al, [rdi + rcx]
    mov dl, [rsi + rcx]
    cmp al, dl
    jne .diff
    test al, al
    jz .eq
    inc ecx
    jmp .l
.eq:
    xor eax, eax
    ret
.diff:
    mov eax, 1
    ret

fm_hist_remove_at:
    ; (index esi, count -> decremented) shift entries left from index+1
    push rbx
    push r12
    mov r12d, esi
    mov ebx, [rel fm_conn_hist_count]
.loop:
    mov eax, r12d
    inc eax
    cmp eax, ebx
    jge .done

    mov ecx, eax
    imul ecx, 128
    lea rdi, [rel fm_conn_hist_hosts + rcx]
    mov ecx, r12d
    imul ecx, 128
    lea rsi, [rel fm_conn_hist_hosts + rcx]
    mov edx, 128
    call fm_copy_cstr

    mov eax, r12d
    inc eax
    mov ecx, eax
    imul ecx, 16
    lea rdi, [rel fm_conn_hist_ports + rcx]
    mov ecx, r12d
    imul ecx, 16
    lea rsi, [rel fm_conn_hist_ports + rcx]
    mov edx, 16
    call fm_copy_cstr

    mov eax, r12d
    inc eax
    mov ecx, eax
    imul ecx, 64
    lea rdi, [rel fm_conn_hist_users + rcx]
    mov ecx, r12d
    imul ecx, 64
    lea rsi, [rel fm_conn_hist_users + rcx]
    mov edx, 64
    call fm_copy_cstr

    inc r12d
    jmp .loop
.done:
    dec dword [rel fm_conn_hist_count]
    pop r12
    pop rbx
    ret

fm_history_push_current:
    ; (fm rdi) -> eax 0/-1
    push rbx
    push r12
    push r13
    mov rbx, rdi

    ; dedup: find and remove existing match
    xor r13d, r13d
.dedup:
    cmp r13d, [rel fm_conn_hist_count]
    jge .dedup_done
    mov eax, r13d
    imul eax, 128
    lea rdi, [rel fm_conn_hist_hosts + rax]
    lea rsi, [rbx + FM_CONN_HOST_OFF]
    call fm_hist_cmp_str
    test eax, eax
    jnz .dedup_next
    mov eax, r13d
    imul eax, 16
    lea rdi, [rel fm_conn_hist_ports + rax]
    lea rsi, [rbx + FM_CONN_PORT_OFF]
    call fm_hist_cmp_str
    test eax, eax
    jnz .dedup_next
    mov eax, r13d
    imul eax, 64
    lea rdi, [rel fm_conn_hist_users + rax]
    lea rsi, [rbx + FM_CONN_USER_OFF]
    call fm_hist_cmp_str
    test eax, eax
    jnz .dedup_next
    mov esi, r13d
    call fm_hist_remove_at
    jmp .dedup
.dedup_next:
    inc r13d
    jmp .dedup
.dedup_done:

    mov r12d, [rel fm_conn_hist_count]
    cmp r12d, FM_CONN_HISTORY_MAX
    jl .slot_ready

    ; shift left to drop oldest
    xor ecx, ecx
.shift_loop:
    cmp ecx, FM_CONN_HISTORY_MAX - 1
    jge .slot_last
    mov eax, ecx
    inc eax
    mov edx, eax
    imul edx, 128
    lea rdi, [rel fm_conn_hist_hosts + rdx]
    mov edx, ecx
    imul edx, 128
    lea rsi, [rel fm_conn_hist_hosts + rdx]
    mov edx, 128
    call fm_copy_cstr

    mov eax, ecx
    inc eax
    mov edx, eax
    imul edx, 16
    lea rdi, [rel fm_conn_hist_ports + rdx]
    mov edx, ecx
    imul edx, 16
    lea rsi, [rel fm_conn_hist_ports + rdx]
    mov edx, 16
    call fm_copy_cstr

    mov eax, ecx
    inc eax
    mov edx, eax
    imul edx, 64
    lea rdi, [rel fm_conn_hist_users + rdx]
    mov edx, ecx
    imul edx, 64
    lea rsi, [rel fm_conn_hist_users + rdx]
    mov edx, 64
    call fm_copy_cstr

    inc ecx
    jmp .shift_loop

.slot_last:
    mov r12d, FM_CONN_HISTORY_MAX - 1
    jmp .write

.slot_ready:

.write:
    mov eax, r12d
    imul eax, 128
    lea rdi, [rbx + FM_CONN_HOST_OFF]
    lea rsi, [rel fm_conn_hist_hosts + rax]
    mov edx, 128
    call fm_copy_cstr
    test eax, eax
    js .fail

    mov eax, r12d
    imul eax, 16
    lea rdi, [rbx + FM_CONN_PORT_OFF]
    lea rsi, [rel fm_conn_hist_ports + rax]
    mov edx, 16
    call fm_copy_cstr
    test eax, eax
    js .fail

    mov eax, r12d
    imul eax, 64
    lea rdi, [rbx + FM_CONN_USER_OFF]
    lea rsi, [rel fm_conn_hist_users + rax]
    mov edx, 64
    call fm_copy_cstr
    test eax, eax
    js .fail

    cmp dword [rel fm_conn_hist_count], FM_CONN_HISTORY_MAX
    jge .set_sel
    inc dword [rel fm_conn_hist_count]
.set_sel:
    mov eax, [rel fm_conn_hist_count]
    dec eax
    mov [rel fm_conn_hist_sel], eax
    xor eax, eax
    pop r13
    pop r12
    pop rbx
    ret
.fail:
    mov eax, -1
    pop r13
    pop r12
    pop rbx
    ret

fm_parse_port:
    ; (str rdi) -> eax port (1..65535) or 22
    xor eax, eax
    xor ecx, ecx
.l:
    mov dl, [rdi + rcx]
    test dl, dl
    jz .done
    cmp dl, '0'
    jb .bad
    cmp dl, '9'
    ja .bad
    imul eax, eax, 10
    movzx edx, dl
    sub edx, '0'
    add eax, edx
    cmp eax, 65535
    ja .bad
    inc ecx
    jmp .l
.done:
    cmp ecx, 0
    je .bad
    cmp eax, 1
    jl .bad
    ret
.bad:
    mov eax, 22
    ret

fm_parse_port_strict:
    ; (str rdi) -> eax port (1..65535) or -1
    xor eax, eax
    xor ecx, ecx
.l:
    mov dl, [rdi + rcx]
    test dl, dl
    jz .done
    cmp dl, '0'
    jb .bad
    cmp dl, '9'
    ja .bad
    imul eax, eax, 10
    movzx edx, dl
    sub edx, '0'
    add eax, edx
    cmp eax, 65535
    ja .bad
    inc ecx
    jmp .l
.done:
    cmp ecx, 0
    je .bad
    cmp eax, 1
    jl .bad
    ret
.bad:
    mov eax, -1
    ret

fm_append_dec:
    ; (dst rdi, val esi, end rdx) -> rax new dst or 0
    push rbx
    sub rsp, 16
    mov rbx, rdi
    mov r11, rdx
    xor ecx, ecx
    mov eax, esi
    test eax, eax
    jnz .cv
    mov byte [rsp], '0'
    mov ecx, 1
    jmp .cp
.cv:
    mov esi, 10
.d:
    xor edx, edx
    div esi
    add dl, '0'
    mov [rsp + rcx], dl
    inc ecx
    test eax, eax
    jnz .d
.cp:
    test ecx, ecx
    jz .ok
.cp_l:
    cmp rbx, r11
    jae .adec_fail
    dec ecx
    mov al, [rsp + rcx]
    mov [rbx], al
    inc rbx
    test ecx, ecx
    jnz .cp_l
.ok:
    mov rax, rbx
    add rsp, 16
    pop rbx
    ret
.adec_fail:
    xor eax, eax
    add rsp, 16
    pop rbx
    ret

fm_progress_cb:
    ; (percent edi)
    mov rax, [rel fm_progress_owner]
    test rax, rax
    jz .out
    mov [rax + FM_PROGRESS_PERCENT_OFF], edi
.out:
    ret

fm_connect_open:
    ; (fm rdi)
    push rbx
    mov rbx, rdi
    mov dword [rdi + FM_CONN_ACTIVE_OFF], 1
    mov dword [rdi + FM_CONN_FIELD_OFF], 0
    mov dword [rdi + FM_CONN_STATUS_LEN_OFF], 0
    mov dword [rdi + FM_CONN_STATUS_KIND_OFF], FM_STATUS_NEUTRAL
    mov rdi, fm_sftp_host_default
    lea rsi, [rbx + FM_CONN_HOST_OFF]
    mov edx, 128
    call fm_copy_cstr
    mov rdi, fm_sftp_port_default
    lea rsi, [rbx + FM_CONN_PORT_OFF]
    mov edx, 16
    call fm_copy_cstr
    mov rdi, fm_sftp_user_default
    lea rsi, [rbx + FM_CONN_USER_OFF]
    mov edx, 64
    call fm_copy_cstr
    lea rax, [rbx + FM_CONN_PASS_OFF]
    mov byte [rax], 0
    mov eax, [rel fm_conn_hist_count]
    test eax, eax
    jle .out
    dec eax
    mov [rel fm_conn_hist_sel], eax
    mov rdi, rbx
    mov esi, eax
    call fm_history_apply
.out:
    pop rbx
    ret

fm_connect_build_uri:
    ; (fm rdi, port esi) -> eax len or -1
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12d, esi
    lea rdi, [rbx + FM_CONN_URI_OFF]
    lea r13, [rbx + FM_CONN_URI_OFF + 255]
    mov rsi, fm_sftp_uri_a
    mov rdx, r13
    call fm_append_cstr
    test rax, rax
    jz .fail
    mov rdi, rax
    lea rsi, [rbx + FM_CONN_USER_OFF]
    cmp byte [rsi], 0
    je .host
    mov rdx, r13
    call fm_append_cstr
    test rax, rax
    jz .fail
    mov rdi, rax
    mov rsi, fm_sftp_uri_at
    mov rdx, r13
    call fm_append_cstr
    test rax, rax
    jz .fail
    mov rdi, rax
.host:
    lea rsi, [rbx + FM_CONN_HOST_OFF]
    mov rdx, r13
    call fm_append_cstr
    test rax, rax
    jz .fail
    mov rdi, rax
    mov rsi, fm_sftp_uri_colon
    mov rdx, r13
    call fm_append_cstr
    test rax, rax
    jz .fail
    mov rdi, rax
    mov esi, r12d
    mov rdx, r13
    call fm_append_dec
    test rax, rax
    jz .fail
    mov rdi, rax
    lea rsi, [rbx + FM_CONN_USER_OFF]
    cmp byte [rsi], 0
    je .tmp
    mov rsi, fm_sftp_uri_home
    mov rdx, r13
    call fm_append_cstr
    test rax, rax
    jz .fail
    mov rdi, rax
    lea rsi, [rbx + FM_CONN_USER_OFF]
    mov rdx, r13
    call fm_append_cstr
    test rax, rax
    jz .fail
    jmp .term
.tmp:
    mov rsi, fm_sftp_uri_tmp
    mov rdx, r13
    call fm_append_cstr
    test rax, rax
    jz .fail
.term:
    cmp rax, r13
    jae .fail
    mov byte [rax], 0
    lea rdi, [rbx + FM_CONN_URI_OFF]
    call fm_cstr_len
    pop r13
    pop r12
    pop rbx
    ret
.fail:
    mov eax, -1
    pop r13
    pop r12
    pop rbx
    ret

fm_connect_apply:
    ; (fm rdi) -> eax 0 ok / -1
    push rbx
    push r12
    mov rbx, rdi

    ; host is required
    lea rdi, [rbx + FM_CONN_HOST_OFF]
    cmp byte [rdi], 0
    jne .host_ok
    lea rdi, [rbx]
    mov rsi, fm_conn_status_host_required
    mov edx, FM_STATUS_ERR
    call fm_set_status_kind
    mov dword [rbx + FM_CONN_FIELD_OFF], 0
    mov eax, -1
    pop r12
    pop rbx
    ret
.host_ok:

    lea rdi, [rbx + FM_CONN_PORT_OFF]
    call fm_parse_port_strict
    test eax, eax
    jg .port_ok
    lea rdi, [rbx]
    mov rsi, fm_conn_status_port_invalid
    mov edx, FM_STATUS_ERR
    call fm_set_status_kind
    mov dword [rbx + FM_CONN_FIELD_OFF], 1
    mov eax, -1
    pop r12
    pop rbx
    ret
.port_ok:
    mov r12d, eax                       ; port
    lea rdi, [rbx + FM_CONN_HOST_OFF]
    lea rsi, [rbx + FM_CONN_USER_OFF]
    cmp byte [rsi], 0
    jne .uok
    xor esi, esi
.uok:
    mov edx, r12d
    lea rcx, [rbx + FM_CONN_PASS_OFF]
    cmp byte [rcx], 0
    jne .pok
    xor ecx, ecx
.pok:
    call vfs_sftp_connect
    test eax, eax
    js .fail
    mov esi, r12d
    mov rdi, rbx
    call fm_connect_build_uri
    test eax, eax
    js .open_fail
    mov edx, eax
    mov rdi, [rbx + FM_ACTIVE_PANEL_OFF]
    lea rsi, [rbx + FM_CONN_URI_OFF]
    call panel_go_path
    test eax, eax
    js .open_fail
    mov dword [rbx + FM_CONN_ACTIVE_OFF], 0
    mov dword [rbx + FM_REMOTE_CONNECTED_OFF], 1
    mov rdi, rbx
    call fm_history_push_current
    lea rdi, [rbx + FM_CONN_HOST_OFF]
    lea rsi, [rbx + FM_REMOTE_HOST_OFF]
    mov edx, 128
    call fm_copy_cstr
    lea rdi, [rbx]
    mov rsi, fm_conn_status_ok
    mov edx, FM_STATUS_OK
    call fm_set_status_kind
    xor eax, eax
    pop r12
    pop rbx
    ret
.open_fail:
    lea rdi, [rbx]
    mov rsi, fm_conn_status_open_fail
    mov edx, FM_STATUS_ERR
    call fm_set_status_kind
    mov eax, -1
    pop r12
    pop rbx
    ret
.fail:
    lea rdi, [rbx]
    mov rsi, fm_conn_status_fail
    mov edx, FM_STATUS_ERR
    call fm_set_status_kind
    mov eax, -1
    pop r12
    pop rbx
    ret

fm_draw_text:
    ; (font rdi, canvas rsi, x edx, y ecx, text r8, len r9d, color eax)
    push rax
    sub rsp, 24
    mov dword [rsp], 13
    mov [rsp + 8], eax
    mov dword [rsp + 16], 0
    call font_draw_string
    add rsp, 24
    pop rax
    ret

fm_render_connected_status:
    ; (fm rdi, canvas rsi, theme rdx)
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    cmp dword [rbx + FM_REMOTE_CONNECTED_OFF], 0
    je .out
    mov rdi, [r13 + TH_FONT_OFF]
    test rdi, rdi
    jz .out
    lea rsi, [rel fm_conn_mask_buf]
    lea rdx, [rel fm_conn_mask_buf + 95]
    mov r8, rsi
    mov rsi, fm_status_connected_prefix
    mov rdi, r8
    call fm_append_cstr
    test rax, rax
    jz .out
    mov rdi, rax
    lea rsi, [rbx + FM_REMOTE_HOST_OFF]
    lea rdx, [rel fm_conn_mask_buf + 95]
    call fm_append_cstr
    test rax, rax
    jz .out
    mov byte [rax], 0
    lea r8, [rel fm_conn_mask_buf]
    mov rdi, r8
    call fm_cstr_len
    mov r9d, eax
    mov rdi, [r13 + TH_FONT_OFF]
    mov rsi, r12
    mov edx, 8
    mov ecx, 8
    mov eax, 0xFF7EDB8A
    call fm_draw_text
.out:
    pop r13
    pop r12
    pop rbx
    ret

fm_render_connect_dialog:
    ; (fm rdi, canvas rsi, theme rdx)
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    cmp dword [rbx + FM_CONN_ACTIVE_OFF], 0
    je .out

    ; backdrop
    mov rdi, r12
    xor esi, esi
    xor edx, edx
    mov ecx, 800
    mov r8d, 600
    mov r9d, 0x90000000
    call canvas_fill_rect_alpha

    ; dialog panel
    mov eax, 0xFF1F2430
    push rax
    mov rdi, r12
    mov esi, 180
    mov edx, 150
    mov ecx, 440
    mov r8d, 290
    mov r9d, 10
    call canvas_fill_rounded_rect
    add rsp, 8

    mov r14, [r13 + TH_FONT_OFF]
    test r14, r14
    jz .out
    mov r15d, [r13 + TH_FG_OFF]

    ; title
    mov rdi, fm_conn_title
    call fm_cstr_len
    mov r9d, eax
    mov rdi, r14
    mov rsi, r12
    mov edx, 200
    mov ecx, 172
    mov r8, fm_conn_title
    mov eax, r15d
    call fm_draw_text

    ; labels + values
    ; active field highlight
    mov eax, [rbx + FM_CONN_FIELD_OFF]
    cmp eax, 0
    jl .hl_done
    cmp eax, 3
    jg .hl_done
    imul eax, eax, 30
    add eax, 193
    mov edx, eax
    mov eax, [r13 + TH_ACCENT_OFF]
    push rax
    mov rdi, r12
    mov esi, 260
    sub edx, 2
    mov ecx, 324
    mov r8d, 28
    mov r9d, 6
    call canvas_fill_rounded_rect
    add rsp, 8
    add edx, 2
    mov eax, 0xFF2F3D52
    push rax
    mov rdi, r12
    mov esi, 262
    mov ecx, 320
    mov r8d, 24
    mov r9d, 5
    call canvas_fill_rounded_rect
    add rsp, 8
.hl_done:

    ; labels + values
    mov rdi, r14
    mov rsi, r12
    mov eax, r15d
    ; Host label
    mov edx, 200
    mov ecx, 205
    mov r8, fm_conn_lbl_host
    mov r9d, 5
    call fm_draw_text
    ; Port label
    mov edx, 200
    mov ecx, 235
    mov r8, fm_conn_lbl_port
    mov r9d, 5
    call fm_draw_text
    ; User label
    mov edx, 200
    mov ecx, 265
    mov r8, fm_conn_lbl_user
    mov r9d, 5
    call fm_draw_text
    ; Pass label
    mov edx, 200
    mov ecx, 295
    mov r8, fm_conn_lbl_pass
    mov r9d, 9
    call fm_draw_text

    ; Host value
    lea rdi, [rbx + FM_CONN_HOST_OFF]
    call fm_cstr_len
    mov r9d, eax
    mov rdi, r14
    mov rsi, r12
    mov edx, 270
    mov ecx, 205
    lea r8, [rbx + FM_CONN_HOST_OFF]
    mov eax, r15d
    call fm_draw_text
    ; Port value
    lea rdi, [rbx + FM_CONN_PORT_OFF]
    call fm_cstr_len
    mov r9d, eax
    mov rdi, r14
    mov rsi, r12
    mov edx, 270
    mov ecx, 235
    lea r8, [rbx + FM_CONN_PORT_OFF]
    mov eax, r15d
    call fm_draw_text
    ; User value
    lea rdi, [rbx + FM_CONN_USER_OFF]
    call fm_cstr_len
    mov r9d, eax
    mov rdi, r14
    mov rsi, r12
    mov edx, 270
    mov ecx, 265
    lea r8, [rbx + FM_CONN_USER_OFF]
    mov eax, r15d
    call fm_draw_text
    ; Password masked
    lea rdi, [rbx + FM_CONN_PASS_OFF]
    call fm_cstr_len
    mov ecx, eax
    cmp ecx, 90
    jbe .mask_ok
    mov ecx, 90
.mask_ok:
    xor edx, edx
.mask_loop:
    cmp edx, ecx
    jae .mask_done
    mov byte [rel fm_conn_mask_buf + rdx], '*'
    inc edx
    jmp .mask_loop
.mask_done:
    mov byte [rel fm_conn_mask_buf + rcx], 0
    mov r9d, ecx
    mov rdi, r14
    mov rsi, r12
    mov edx, 270
    mov ecx, 295
    lea r8, [rel fm_conn_mask_buf]
    mov eax, r15d
    call fm_draw_text

    ; status
    mov r9d, [rbx + FM_CONN_STATUS_LEN_OFF]
    cmp r9d, 0
    jle .hint
    mov rdi, r14
    mov rsi, r12
    mov edx, 200
    mov ecx, 328
    lea r8, [rbx + FM_CONN_STATUS_OFF]
    mov eax, [rbx + FM_CONN_STATUS_KIND_OFF]
    cmp eax, FM_STATUS_OK
    je .st_ok
    cmp eax, FM_STATUS_ERR
    je .st_err
    mov eax, 0xFFD0D7E2
    jmp .st_draw
.st_ok:
    mov eax, 0xFF7EDB8A
    jmp .st_draw
.st_err:
    mov eax, 0xFFF08C8C
.st_draw:
    call fm_draw_text
    jmp .buttons
.hint:
    mov rdi, fm_conn_hint
    call fm_cstr_len
    mov r9d, eax
    mov rdi, r14
    mov rsi, r12
    mov edx, 200
    mov ecx, 328
    mov r8, fm_conn_hint
    mov eax, 0xFF9AA4B2
    call fm_draw_text

    ; history preview
    mov eax, [rel fm_conn_hist_count]
    test eax, eax
    jle .hist_empty
    mov eax, [rel fm_conn_hist_sel]
    cmp eax, 0
    jl .hist_empty
    cmp eax, [rel fm_conn_hist_count]
    jge .hist_empty

    lea rdi, [rel fm_conn_mask_buf]
    lea r10, [rel fm_conn_mask_buf + 95]
    mov rsi, fm_conn_hist_prefix
    mov rdx, r10
    call fm_append_cstr
    test rax, rax
    jz .hist_empty
    mov rdi, rax

    mov ecx, [rel fm_conn_hist_sel]
    mov eax, ecx
    imul eax, 64
    lea rsi, [rel fm_conn_hist_users + rax]
    cmp byte [rsi], 0
    je .hist_host
    mov rdx, r10
    call fm_append_cstr
    test rax, rax
    jz .hist_empty
    mov rdi, rax
    mov rsi, fm_sftp_uri_at
    mov rdx, r10
    call fm_append_cstr
    test rax, rax
    jz .hist_empty
    mov rdi, rax
.hist_host:
    mov ecx, [rel fm_conn_hist_sel]
    mov eax, ecx
    imul eax, 128
    lea rsi, [rel fm_conn_hist_hosts + rax]
    mov rdx, r10
    call fm_append_cstr
    test rax, rax
    jz .hist_empty
    mov rdi, rax
    mov rsi, fm_sftp_uri_colon
    mov rdx, r10
    call fm_append_cstr
    test rax, rax
    jz .hist_empty
    mov rdi, rax
    mov ecx, [rel fm_conn_hist_sel]
    mov eax, ecx
    imul eax, 16
    lea rsi, [rel fm_conn_hist_ports + rax]
    mov rdx, r10
    call fm_append_cstr
    test rax, rax
    jz .hist_empty
    mov byte [rax], 0
    lea r8, [rel fm_conn_mask_buf]
    mov rdi, r8
    call fm_cstr_len
    mov r9d, eax
    mov rdi, r14
    mov rsi, r12
    mov edx, 200
    mov ecx, 386
    lea r8, [rel fm_conn_mask_buf]
    mov eax, 0xFF9AA4B2
    call fm_draw_text
    jmp .buttons
.hist_empty:
    mov rdi, r14
    mov rsi, r12
    mov edx, 200
    mov ecx, 386
    mov r8, fm_conn_hist_none
    mov r9d, 16
    mov eax, 0xFF9AA4B2
    call fm_draw_text

.buttons:
    ; button backgrounds with focus highlight
    mov eax, [rbx + FM_CONN_FIELD_OFF]
    cmp eax, 4
    jne .btn_conn_norm
    mov eax, 0xFF2E6B43
    jmp .btn_conn_color
.btn_conn_norm:
    mov eax, 0xFF254A35
.btn_conn_color:
    push rax
    mov rdi, r12
    mov esi, 200
    mov edx, 348
    mov ecx, 100
    mov r8d, 28
    mov r9d, 6
    call canvas_fill_rounded_rect
    add rsp, 8

    mov eax, [rbx + FM_CONN_FIELD_OFF]
    cmp eax, 5
    jne .btn_cancel_norm
    mov eax, 0xFF7A2C2C
    jmp .btn_cancel_color
.btn_cancel_norm:
    mov eax, 0xFF5D2929
.btn_cancel_color:
    push rax
    mov rdi, r12
    mov esi, 320
    mov edx, 348
    mov ecx, 100
    mov r8d, 28
    mov r9d, 6
    call canvas_fill_rounded_rect
    add rsp, 8

    mov rdi, r14
    mov rsi, r12
    mov edx, 217
    mov ecx, 356
    mov r8, fm_conn_btn_connect
    mov r9d, 7
    mov eax, 0xFF7EDB8A
    call fm_draw_text
    mov rdi, r14
    mov rsi, r12
    mov edx, 346
    mov ecx, 356
    mov r8, fm_conn_btn_cancel
    mov r9d, 6
    mov eax, 0xFFF08C8C
    call fm_draw_text
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

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
    mov rdi, rax
    mov dword [rdi + P_ACTIVE_OFF], 1

    mov rdi, [rbx + FM_LEFT_PANEL_OFF]
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
    push rdi
    push rsi
    push rbx
    push r12
    push r13
    sub rsp, 16
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx

    ; Reset clip to full canvas each frame on Win native path.
    mov dword [r12 + CV_CLIP_DEPTH_OFF], 0
    mov dword [r12 + CV_CLIP_X_OFF], 0
    mov dword [r12 + CV_CLIP_Y_OFF], 0
    mov eax, [r12 + CV_WIDTH_OFF]
    mov [r12 + CV_CLIP_W_OFF], eax
    mov eax, [r12 + CV_HEIGHT_OFF]
    mov [r12 + CV_CLIP_H_OFF], eax

    ; Clear full canvas first to avoid stale/black regions when widget
    ; subtree does not cover the entire framebuffer.
    mov r9d, 0xFF1A1B26
    test r13, r13
    jz .bg_ready
    mov r9d, [r13 + TH_BG_OFF]
.bg_ready:
    ; Hard clear framebuffer directly (ignore clip state entirely).
    mov rdi, [r12 + CV_BUFFER_OFF]
    test rdi, rdi
    jz .out
    mov ecx, [r12 + CV_SIZE_OFF]
    shr ecx, 2
    jz .out
    mov eax, r9d
    cld
    rep stosd
    ; Stable FM fallback scaffold (no font rendering) for Win native path.
    ; Keeps UI visible while text/theme/TT paths are being stabilized.
    mov eax, [r12 + CV_WIDTH_OFF]
    shr eax, 1
    mov dword [rsp + 0], eax            ; half width
    mov eax, [r12 + CV_HEIGHT_OFF]
    cmp eax, 20
    jb .fallback_h_ok
    sub eax, 20
.fallback_h_ok:
    mov dword [rsp + 4], eax            ; work height
    ; left panel shell
    mov rdi, r12
    mov esi, 8
    mov edx, 24
    mov ecx, [rsp + 0]
    sub ecx, 12
    mov r8d, [rsp + 4]
    sub r8d, 32
    mov r9d, 0xFF2A3045
    call canvas_fill_rect_alpha
    ; right panel shell
    mov rdi, r12
    mov esi, [rsp + 0]
    add esi, 4
    mov edx, 24
    mov ecx, [r12 + CV_WIDTH_OFF]
    sub ecx, esi
    sub ecx, 8
    mov r8d, [rsp + 4]
    sub r8d, 32
    mov r9d, 0xFF334B6A
    call canvas_fill_rect_alpha
    ; top bars for active panel cue (stable geometry-only indicator)
    mov rdi, r12
    mov esi, 8
    mov edx, 24
    mov ecx, [rsp + 0]
    sub ecx, 12
    mov r8d, 3
    mov r9d, 0xFF3E4A60
    call canvas_fill_rect_alpha
    mov rdi, r12
    mov esi, [rsp + 0]
    add esi, 4
    mov edx, 24
    mov ecx, [r12 + CV_WIDTH_OFF]
    sub ecx, esi
    sub ecx, 8
    mov r8d, 3
    mov r9d, 0xFF3E4A60
    call canvas_fill_rect_alpha
    mov rax, [rbx + FM_ACTIVE_PANEL_OFF]
    cmp rax, [rbx + FM_LEFT_PANEL_OFF]
    jne .fb_act_right
    mov rdi, r12
    mov esi, 8
    mov edx, 24
    mov ecx, [rsp + 0]
    sub ecx, 12
    mov r8d, 3
    mov r9d, 0xFF7EC8FF
    call canvas_fill_rect_alpha
    jmp .fb_act_done
.fb_act_right:
    mov rdi, r12
    mov esi, [rsp + 0]
    add esi, 4
    mov edx, 24
    mov ecx, [r12 + CV_WIDTH_OFF]
    sub ecx, esi
    sub ecx, 8
    mov r8d, 3
    mov r9d, 0xFF7EC8FF
    call canvas_fill_rect_alpha
.fb_act_done:
    ; center divider
    mov rdi, r12
    mov esi, [rsp + 0]
    sub esi, 1
    mov edx, 24
    mov ecx, 2
    mov r8d, [rsp + 4]
    sub r8d, 32
    mov r9d, 0xFF5C9CFF
    call canvas_fill_rect_alpha
    ; bottom status strip (visual only)
    mov rdi, r12
    mov esi, 8
    mov edx, [r12 + CV_HEIGHT_OFF]
    sub edx, 20
    mov ecx, [r12 + CV_WIDTH_OFF]
    sub ecx, 16
    mov r8d, 12
    mov r9d, 0xFF1F2433
    call canvas_fill_rect_alpha
    ; Render rows from live panel model as geometry only (no text path).
    ; Left panel rows.
    mov eax, 1
    mov r11, [rbx + FM_LEFT_PANEL_OFF]
    test r11, r11
    jz .fb_left_count_ready
    mov eax, [r11 + P_ENTRY_COUNT_OFF]
    cmp eax, 1
    jge .fb_left_count_ready
    mov eax, 1
.fb_left_count_ready:
    cmp eax, 10
    jle .fb_left_count_clamped
    mov eax, 10
.fb_left_count_clamped:
    mov [rsp + 12], eax
    xor eax, eax
    mov [rsp + 8], eax
.fb_left_rows_loop:
    mov eax, [rsp + 8]
    cmp eax, [rsp + 12]
    jae .fb_right_rows_start
    mov rdi, r12
    mov esi, 20
    mov edx, eax
    imul edx, 14
    add edx, 44
    mov ecx, [rsp + 0]
    sub ecx, 36
    mov r10d, eax
    and r10d, 3
    shl r10d, 4
    sub ecx, r10d
    mov r8d, 6
    mov r9d, 0xFF6F7F99
    mov r11, [rbx + FM_LEFT_PANEL_OFF]
    test r11, r11
    jz .fb_left_draw
    mov r10d, [r11 + P_SELECTED_IDX_OFF]
    cmp r10d, eax
    jne .fb_left_draw
    mov r9d, 0xFFB8C6DD
.fb_left_draw:
    call canvas_fill_rect_alpha
    inc dword [rsp + 8]
    jmp .fb_left_rows_loop

.fb_right_rows_start:
    mov eax, 1
    mov r11, [rbx + FM_RIGHT_PANEL_OFF]
    test r11, r11
    jz .fb_right_count_ready
    mov eax, [r11 + P_ENTRY_COUNT_OFF]
    cmp eax, 1
    jge .fb_right_count_ready
    mov eax, 1
.fb_right_count_ready:
    cmp eax, 10
    jle .fb_right_count_clamped
    mov eax, 10
.fb_right_count_clamped:
    mov [rsp + 12], eax
    xor eax, eax
    mov [rsp + 8], eax
.fb_right_rows_loop:
    mov eax, [rsp + 8]
    cmp eax, [rsp + 12]
    jae .fb_rows_done
    mov rdi, r12
    mov esi, [rsp + 0]
    add esi, 16
    mov edx, eax
    imul edx, 14
    add edx, 44
    mov ecx, [r12 + CV_WIDTH_OFF]
    sub ecx, esi
    sub ecx, 20
    mov r10d, eax
    and r10d, 3
    shl r10d, 4
    sub ecx, r10d
    mov r8d, 6
    mov r9d, 0xFF8EA2BF
    mov r11, [rbx + FM_RIGHT_PANEL_OFF]
    test r11, r11
    jz .fb_right_draw
    mov r10d, [r11 + P_SELECTED_IDX_OFF]
    cmp r10d, eax
    jne .fb_right_draw
    mov r9d, 0xFFD2DEEE
.fb_right_draw:
    call canvas_fill_rect_alpha
    inc dword [rsp + 8]
    jmp .fb_right_rows_loop
.fb_rows_done:
    jmp .out

    mov rax, [rbx + FM_SPLIT_PANE_OFF]
    test rax, rax
    jz .dlg
    ; Stretch root FM widget to full client area (status bar kept at bottom).
    mov ecx, [r12 + CV_WIDTH_OFF]
    mov r10d, [r12 + CV_HEIGHT_OFF]
    cmp r10d, 20
    jb .no_work_h
    sub r10d, 20
    jmp .have_work_h
.no_work_h:
    xor r10d, r10d
.have_work_h:
    mov dword [rax + W_X_OFF], 0
    mov dword [rax + W_Y_OFF], 0
    mov dword [rax + W_WIDTH_OFF], ecx
    mov dword [rax + W_HEIGHT_OFF], r10d
    mov rdi, rax
    call widget_layout
.render_root:
    mov rdi, [rbx + FM_SPLIT_PANE_OFF]
    mov rsi, r12
    mov rdx, r13
    xor ecx, ecx
    xor r8d, r8d
    call widget_render
.dlg:
    mov rdi, rbx
    mov rsi, r12
    mov rdx, r13
    call fm_status_bar_render

    cmp dword [rbx + FM_VIEWER_ACTIVE_OFF], 0
    je .dialogs
    mov rdi, [rbx + FM_VIEWER_OFF]
    test rdi, rdi
    jz .dialogs
    mov rsi, r12
    mov rdx, r13
    call viewer_render
.dialogs:
    cmp dword [rbx + FM_PROGRESS_ACTIVE_OFF], 0
    je .dlg_conn
    mov rdi, [r13 + TH_FONT_OFF]
    test rdi, rdi
    jz .dlg_conn
    mov rsi, r12
    mov edx, 250
    mov ecx, 280
    mov r8, fm_conn_title
    mov r9d, 7
    mov eax, 0xFFE7EDF7
    call fm_draw_text
    mov eax, [rbx + FM_PROGRESS_PERCENT_OFF]
    cmp eax, 100
    jle .pct_ok
    mov eax, 100
.pct_ok:
    mov ecx, eax
    imul ecx, 3
    mov rdi, r12
    mov esi, 250
    mov edx, 308
    mov r8d, 20
    mov r9d, 0xFF2B3341
    mov ecx, 300
    call canvas_fill_rect_alpha
    mov rdi, r12
    mov esi, 250
    mov edx, 308
    mov ecx, ecx
    mov r8d, 20
    mov r9d, 0xFF5C9CFF
    call canvas_fill_rect_alpha
.dlg_conn:
    mov rdi, rbx
    mov rsi, r12
    mov rdx, r13
    call fm_render_connect_dialog
    mov rdi, rbx
    mov rsi, r12
    mov rdx, r13
    call fm_render_bloom_dialog
    mov rdi, rbx
    mov rsi, r12
    mov rdx, r13
    call fm_render_connected_status
.out:
    add rsp, 16
    pop r13
    pop r12
    pop rbx
    pop rsi
    pop rdi
    ret

fm_copy_selected:
    ; copy marked files from active panel to passive panel path
    push rbx
    sub rsp, (VFS_MAX_PATH * 64) + VFS_MAX_PATH + 16
    mov rbx, rdi
    mov rdi, [rbx + FM_ACTIVE_PANEL_OFF]
    lea rsi, [rbx + FM_TMP_PATHS_OFF]
    lea rdx, [rbx + FM_TMP_COUNT_OFF]
    call panel_get_marked
    mov ecx, [rbx + FM_TMP_COUNT_OFF]
    cmp ecx, 0
    jg .have
    mov rdi, [rbx + FM_ACTIVE_PANEL_OFF]
    mov eax, [rdi + P_SELECTED_IDX_OFF]
    mov esi, eax
    call panel_toggle_mark
    mov rdi, [rbx + FM_ACTIVE_PANEL_OFF]
    lea rsi, [rbx + FM_TMP_PATHS_OFF]
    lea rdx, [rbx + FM_TMP_COUNT_OFF]
    call panel_get_marked
    mov ecx, [rbx + FM_TMP_COUNT_OFF]
    cmp ecx, 0
    jle .fail
.have:
    mov rax, [rbx + FM_LEFT_PANEL_OFF]
    mov rdx, [rbx + FM_RIGHT_PANEL_OFF]
    cmp [rbx + FM_ACTIVE_PANEL_OFF], rax
    jne .dst_left
    mov rdi, rdx
    jmp .dst_ok
.dst_left:
    mov rdi, rax
.dst_ok:
    test rdi, rdi
    jz .fail
    ; first item only for MVP integration
    lea rsi, [rbx + FM_TMP_PATHS_OFF]
    lea rdi, [rsp]
    lea rcx, [rdi]
    mov rdx, rsi
.src_find_name:
    mov al, [rdx]
    test al, al
    jz .name_start
    inc rdx
    jmp .src_find_name
.name_start:
    mov r8, rdx
    ; build dst path = passive_panel.path + "/" + basename
    mov rdi, [rbx + FM_LEFT_PANEL_OFF]
    mov rax, [rbx + FM_ACTIVE_PANEL_OFF]
    cmp rax, [rbx + FM_LEFT_PANEL_OFF]
    jne .use_right
    mov rdi, [rbx + FM_RIGHT_PANEL_OFF]
.use_right:
    lea rsi, [rdi + P_PATH_OFF]
    mov edx, [rdi + P_PATH_LEN_OFF]
    mov rdi, rsp
    xor ecx, ecx
.cp_base:
    cmp ecx, edx
    jae .after_base
    mov al, [rsi + rcx]
    mov [rdi + rcx], al
    inc ecx
    jmp .cp_base
.after_base:
    cmp ecx, 0
    je .add_sl
    cmp byte [rdi + rcx - 1], '/'
    je .copy_name
.add_sl:
    mov byte [rdi + rcx], '/'
    inc ecx
.copy_name:
    mov r9, r8
    inc r9
.cp_name:
    mov al, [r9]
    mov [rdi + rcx], al
    inc rcx
    inc r9
    test al, al
    jnz .cp_name
    ; do copy via threadpool facade (sync today, async-ready API)
    mov [rel fm_progress_owner], rbx
    cmp qword [rel fm_threadpool_ptr], 0
    jne .have_tp
    mov rdi, 1
    mov rsi, 8
    call threadpool_init
    mov [rel fm_threadpool_ptr], rax
.have_tp:
    cmp qword [rel fm_threadpool_ptr], 0
    jne .submit_tp
    lea rdi, [rbx + FM_TMP_PATHS_OFF]
    mov rsi, rsp
    mov edx, 1
    mov rcx, fm_progress_cb
    lea r8, [rbx + FM_PROGRESS_CANCEL_OFF]
    call op_copy
    jmp .after_copy
.submit_tp:
    lea rax, [rbx + FM_TMP_PATHS_OFF]
    mov [rel fm_async_task + 0], rax
    mov [rel fm_async_task + 8], rsp
    mov dword [rel fm_async_task + 16], 1
    mov qword [rel fm_async_task + 24], fm_progress_cb
    lea rax, [rbx + FM_PROGRESS_CANCEL_OFF]
    mov [rel fm_async_task + 32], rax
    mov rdi, [rel fm_threadpool_ptr]
    mov rsi, op_copy_async
    lea rdx, [rel fm_async_task]
    call threadpool_submit
.after_copy:
    mov rdi, [rbx + FM_LEFT_PANEL_OFF]
    call panel_load
    mov rdi, [rbx + FM_RIGHT_PANEL_OFF]
    test rdi, rdi
    jz .ok
    call panel_load
.ok:
    xor eax, eax
    add rsp, (VFS_MAX_PATH * 64) + VFS_MAX_PATH + 16
    pop rbx
    ret
.fail:
    mov eax, -1
    add rsp, (VFS_MAX_PATH * 64) + VFS_MAX_PATH + 16
    pop rbx
    ret

fm_delete_selected:
    push rbx
    mov rbx, rdi
    mov rdi, [rbx + FM_ACTIVE_PANEL_OFF]
    lea rsi, [rbx + FM_TMP_PATHS_OFF]
    lea rdx, [rbx + FM_TMP_COUNT_OFF]
    call panel_get_marked
    mov ecx, [rbx + FM_TMP_COUNT_OFF]
    cmp ecx, 0
    jg .have
    mov rdi, [rbx + FM_ACTIVE_PANEL_OFF]
    mov eax, [rdi + P_SELECTED_IDX_OFF]
    mov esi, eax
    call panel_toggle_mark
    mov rdi, [rbx + FM_ACTIVE_PANEL_OFF]
    lea rsi, [rbx + FM_TMP_PATHS_OFF]
    lea rdx, [rbx + FM_TMP_COUNT_OFF]
    call panel_get_marked
    mov ecx, [rbx + FM_TMP_COUNT_OFF]
    cmp ecx, 0
    jle .fail
.have:
    lea rdi, [rbx + FM_TMP_PATHS_OFF]
    mov esi, 1
    call op_delete
    mov rdi, [rbx + FM_ACTIVE_PANEL_OFF]
    call panel_load
    xor eax, eax
    pop rbx
    ret
.fail:
    mov eax, -1
    pop rbx
    ret

fm_mkdir:
    ; quick mkdir with timestamp-free default name
    push rbx
    mov rbx, rdi
    mov rdi, [rbx + FM_ACTIVE_PANEL_OFF]
    lea rsi, [rdi + P_PATH_OFF]
    mov edx, [rdi + P_PATH_LEN_OFF]
    lea rcx, [rel fm_conn_mask_buf]
    xor eax, eax
.cp:
    cmp eax, edx
    jae .mk_name
    mov bl, [rsi + rax]
    mov [rcx + rax], bl
    inc eax
    jmp .cp
.mk_name:
    cmp eax, 0
    je .slash
    cmp byte [rcx + rax - 1], '/'
    je .nm
.slash:
    mov byte [rcx + rax], '/'
    inc eax
.nm:
    mov byte [rcx + rax], 'n'
    mov byte [rcx + rax + 1], 'e'
    mov byte [rcx + rax + 2], 'w'
    mov byte [rcx + rax + 3], '_'
    mov byte [rcx + rax + 4], 'd'
    mov byte [rcx + rax + 5], 'i'
    mov byte [rcx + rax + 6], 'r'
    mov byte [rcx + rax + 7], 0
    lea rdi, [rel fm_conn_mask_buf]
    call vfs_path_len
    mov esi, eax
    mov edx, 0o755
    lea rdi, [rel fm_conn_mask_buf]
    call vfs_mkdir
    mov rdi, [rbx + FM_ACTIVE_PANEL_OFF]
    call panel_load
    xor eax, eax
    pop rbx
    ret

fm_open_path:
    ; (fm rdi, path rsi, path_len edx) -> eax 0/-1
    mov rax, [rdi + FM_ACTIVE_PANEL_OFF]
    test rax, rax
    jz .fail
    mov rdi, rax
    call panel_go_path
    ret
.fail:
    mov eax, -1
    ret

fm_open_viewer_selected:
    ; (fm rdi) -> eax 0/-1
    push rbx
    mov rbx, rdi
    mov rdi, [rbx + FM_ACTIVE_PANEL_OFF]
    test rdi, rdi
    jz .fail
    mov eax, [rdi + P_SELECTED_IDX_OFF]
    cmp eax, 0
    jl .fail
    cmp eax, [rdi + P_ENTRY_COUNT_OFF]
    jge .fail
    imul eax, DIR_ENTRY_SIZE
    lea rcx, [rdi + P_ENTRIES_BUF_OFF + rax]
    cmp dword [rcx + DE_TYPE_OFF], DT_DIR
    je .fail
    ; build absolute path into FM_CONN_URI_OFF buffer
    lea rsi, [rdi + P_PATH_OFF]
    mov edx, [rdi + P_PATH_LEN_OFF]
    lea r8, [rbx + FM_CONN_URI_OFF]
    xor eax, eax
.cpb:
    cmp eax, edx
    jae .slash
    mov bl, [rsi + rax]
    mov [r8 + rax], bl
    inc eax
    jmp .cpb
.slash:
    cmp eax, 0
    je .adds
    cmp byte [r8 + rax - 1], '/'
    je .name
.adds:
    mov byte [r8 + rax], '/'
    inc eax
.name:
    lea rsi, [rcx + DE_NAME_OFF]
    xor edx, edx
.cpn:
    mov bl, [rsi + rdx]
    mov [r8 + rax], bl
    inc rax
    inc rdx
    test bl, bl
    jnz .cpn
    lea rdi, [rbx + FM_CONN_URI_OFF]
    call vfs_path_len
    mov esi, eax
    lea rdi, [rbx + FM_CONN_URI_OFF]
    call viewer_open
    test rax, rax
    jz .fail
    mov [rbx + FM_VIEWER_OFF], rax
    mov dword [rbx + FM_VIEWER_ACTIVE_OFF], 1
    xor eax, eax
    pop rbx
    ret
.fail:
    mov eax, -1
    pop rbx
    ret

fm_bloom_get_label:
    ; (idx edi) -> rax cstr
    cmp edi, 0
    je .i0
    cmp edi, 1
    je .i1
    cmp edi, 2
    je .i2
    cmp edi, 3
    je .i3
    cmp edi, 4
    je .i4
    cmp edi, 5
    je .i5
    cmp edi, 6
    je .i6
    cmp edi, 7
    je .i7
    cmp edi, 8
    je .i8
    mov rax, fm_bloom_9
    ret
.i0: mov rax, fm_bloom_0
    ret
.i1: mov rax, fm_bloom_1
    ret
.i2: mov rax, fm_bloom_2
    ret
.i3: mov rax, fm_bloom_3
    ret
.i4: mov rax, fm_bloom_4
    ret
.i5: mov rax, fm_bloom_5
    ret
.i6: mov rax, fm_bloom_6
    ret
.i7: mov rax, fm_bloom_7
    ret
.i8: mov rax, fm_bloom_8
    ret

fm_render_bloom_dialog:
    ; (fm rdi, canvas rsi, theme rdx)
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    cmp dword [rbx + FM_BLOOM_ACTIVE_OFF], 0
    je .out
    mov rdi, r12
    xor esi, esi
    xor edx, edx
    mov ecx, 800
    mov r8d, 600
    mov r9d, 0x90000000
    call canvas_fill_rect_alpha
    mov eax, 0xFF1C2230
    push rax
    mov rdi, r12
    mov esi, 220
    mov edx, 130
    mov ecx, 360
    mov r8d, 340
    mov r9d, 10
    call canvas_fill_rounded_rect
    add rsp, 8
    mov r14, [r13 + TH_FONT_OFF]
    test r14, r14
    jz .out
    mov rdi, fm_bloom_title
    call fm_cstr_len
    mov r9d, eax
    mov rdi, r14
    mov rsi, r12
    mov edx, 240
    mov ecx, 152
    mov r8, fm_bloom_title
    mov eax, 0xFFE7EDF7
    call fm_draw_text
    xor r10d, r10d
.items:
    cmp r10d, 10
    jge .out
    mov eax, [rbx + FM_BLOOM_SELECTED_OFF]
    cmp eax, r10d
    jne .norm
    mov eax, 0xFF2E3D55
    push rax
    mov rdi, r12
    mov esi, 238
    mov edx, r10d
    imul edx, 28
    add edx, 170
    mov ecx, 324
    mov r8d, 24
    mov r9d, 6
    call canvas_fill_rounded_rect
    add rsp, 8
.norm:
    mov edi, r10d
    call fm_bloom_get_label
    mov r8, rax
    mov rdi, r8
    call fm_cstr_len
    mov r9d, eax
    mov rdi, r14
    mov rsi, r12
    mov edx, 248
    mov eax, r10d
    imul eax, 28
    add eax, 186
    mov ecx, eax
    mov eax, 0xFFD4DCE8
    call fm_draw_text
    inc r10d
    jmp .items
.out:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

fm_bloom_apply:
    ; (fm rdi) -> eax 0/-1
    push rbx
    mov rbx, rdi
    mov eax, [rbx + FM_BLOOM_SELECTED_OFF]
    cmp eax, 0
    je .open
    cmp eax, 1
    je .copy
    cmp eax, 2
    je .move
    cmp eax, 3
    je .del
    cmp eax, 5
    je .props
    ; todo actions
    mov rdi, rbx
    mov rsi, fm_status_todo
    call fm_set_status
    xor eax, eax
    pop rbx
    ret
.open:
    mov rdi, [rbx + FM_ACTIVE_PANEL_OFF]
    mov esi, [rdi + P_SELECTED_IDX_OFF]
    call panel_navigate
    test eax, eax
    jnz .viewer_try
    mov rdi, rbx
    call fm_open_viewer_selected
.viewer_try:
    xor eax, eax
    pop rbx
    ret
.copy:
    mov dword [rbx + FM_PROGRESS_ACTIVE_OFF], 1
    mov dword [rbx + FM_PROGRESS_PERCENT_OFF], 5
    mov dword [rbx + FM_PROGRESS_CANCEL_OFF], 0
    mov rdi, fm_progress_copy
    lea rsi, [rbx + FM_PROGRESS_TITLE_OFF]
    mov edx, 128
    call fm_copy_cstr
    mov rdi, rbx
    call fm_copy_selected
    mov dword [rbx + FM_PROGRESS_PERCENT_OFF], 100
    mov dword [rbx + FM_PROGRESS_ACTIVE_OFF], 0
    xor eax, eax
    pop rbx
    ret
.move:
    mov rdi, rbx
    mov rsi, fm_status_todo
    call fm_set_status
    xor eax, eax
    pop rbx
    ret
.del:
    mov dword [rbx + FM_PROGRESS_ACTIVE_OFF], 1
    mov dword [rbx + FM_PROGRESS_PERCENT_OFF], 5
    mov dword [rbx + FM_PROGRESS_CANCEL_OFF], 0
    mov rdi, fm_progress_delete
    lea rsi, [rbx + FM_PROGRESS_TITLE_OFF]
    mov edx, 128
    call fm_copy_cstr
    mov rdi, rbx
    call fm_delete_selected
    mov dword [rbx + FM_PROGRESS_PERCENT_OFF], 100
    mov dword [rbx + FM_PROGRESS_ACTIVE_OFF], 0
    xor eax, eax
    pop rbx
    ret
.props:
    mov rdi, rbx
    mov rsi, fm_conn_hint
    call fm_set_status
    xor eax, eax
    pop rbx
    ret

fm_handle_input:
    ; (fm rdi, event rsi) -> eax consumed
    push rbx
    push r12
    mov rbx, rdi
    mov r12, rsi
    mov eax, [r12 + IE_TYPE_OFF]
    ; Win backend sends VK codes for WM_KEYDOWN/WM_KEYUP. Normalize
    ; control/navigation keys to the legacy Linux-like codes used by FM.
    cmp eax, INPUT_KEY
    jne .key_norm_done
    mov edx, [r12 + IE_KEY_CODE_OFF]
    cmp edx, 0x26                    ; VK_UP
    jne .chk_vk_down
    mov dword [r12 + IE_KEY_CODE_OFF], KEY_UP
    jmp .key_norm_done
.chk_vk_down:
    cmp edx, 0x28                    ; VK_DOWN
    jne .chk_vk_enter
    mov dword [r12 + IE_KEY_CODE_OFF], KEY_DOWN
    jmp .key_norm_done
.chk_vk_enter:
    cmp edx, 0x25                    ; VK_LEFT
    jne .chk_vk_right
    mov dword [r12 + IE_KEY_CODE_OFF], KEY_LEFT
    jmp .key_norm_done
.chk_vk_right:
    cmp edx, 0x27                    ; VK_RIGHT
    jne .chk_vk_enter_real
    mov dword [r12 + IE_KEY_CODE_OFF], KEY_RIGHT
    jmp .key_norm_done
.chk_vk_enter_real:
    cmp edx, 0x0D                    ; VK_RETURN
    jne .chk_vk_tab
    mov dword [r12 + IE_KEY_CODE_OFF], KEY_ENTER
    jmp .key_norm_done
.chk_vk_tab:
    cmp edx, 0x09                    ; VK_TAB
    jne .chk_vk_esc
    mov dword [r12 + IE_KEY_CODE_OFF], KEY_TAB
    jmp .key_norm_done
.chk_vk_esc:
    cmp edx, 0x1B                    ; VK_ESCAPE
    jne .chk_vk_back
    mov dword [r12 + IE_KEY_CODE_OFF], KEY_ESC
    jmp .key_norm_done
.chk_vk_back:
    cmp edx, 0x08                    ; VK_BACK
    jne .chk_vk_fkeys
    mov dword [r12 + IE_KEY_CODE_OFF], KEY_BACKSPACE
    jmp .key_norm_done
.chk_vk_fkeys:
    cmp edx, 0x70                    ; VK_F1
    jb .key_norm_done
    cmp edx, 0x79                    ; VK_F10
    ja .key_norm_done
    sub edx, 0x70
    add edx, KEY_F1
    mov [r12 + IE_KEY_CODE_OFF], edx
.key_norm_done:
    mov eax, [r12 + IE_TYPE_OFF]
    cmp dword [rbx + FM_PROGRESS_ACTIVE_OFF], 0
    je .no_progress
    cmp eax, INPUT_KEY
    jne .cons
    cmp dword [r12 + IE_KEY_STATE_OFF], KEY_PRESSED
    jne .cons
    cmp dword [r12 + IE_KEY_CODE_OFF], KEY_ESC
    jne .cons
    mov dword [rbx + FM_PROGRESS_CANCEL_OFF], 1
    mov dword [rbx + FM_PROGRESS_ACTIVE_OFF], 0
    jmp .cons
.no_progress:
    cmp dword [rbx + FM_BLOOM_ACTIVE_OFF], 0
    je .no_bloom
    cmp eax, INPUT_KEY
    jne .cons
    cmp dword [r12 + IE_KEY_STATE_OFF], KEY_PRESSED
    jne .cons
    mov eax, [r12 + IE_KEY_CODE_OFF]
    cmp eax, KEY_ESC
    je .b_cancel
    cmp eax, KEY_UP
    je .b_up
    cmp eax, KEY_DOWN
    je .b_down
    cmp eax, KEY_ENTER
    je .b_enter
    jmp .cons
.b_cancel:
    mov dword [rbx + FM_BLOOM_ACTIVE_OFF], 0
    jmp .cons
.b_up:
    cmp dword [rbx + FM_BLOOM_SELECTED_OFF], 0
    jle .cons
    dec dword [rbx + FM_BLOOM_SELECTED_OFF]
    jmp .cons
.b_down:
    cmp dword [rbx + FM_BLOOM_SELECTED_OFF], 9
    jge .cons
    inc dword [rbx + FM_BLOOM_SELECTED_OFF]
    jmp .cons
.b_enter:
    mov rdi, rbx
    call fm_bloom_apply
    mov dword [rbx + FM_BLOOM_ACTIVE_OFF], 0
    jmp .cons
.no_bloom:
    cmp dword [rbx + FM_VIEWER_ACTIVE_OFF], 0
    je .no_viewer
    cmp eax, INPUT_KEY
    jne .cons
    mov rdi, [rbx + FM_VIEWER_OFF]
    mov rsi, r12
    call viewer_handle_input
    cmp eax, -1
    jne .cons
    mov rdi, [rbx + FM_VIEWER_OFF]
    call viewer_close
    mov qword [rbx + FM_VIEWER_OFF], 0
    mov dword [rbx + FM_VIEWER_ACTIVE_OFF], 0
    jmp .cons
.no_viewer:
    cmp dword [rbx + FM_CONN_ACTIVE_OFF], 0
    jne .dialog
    cmp eax, INPUT_KEY
    jne .delegate
    cmp dword [r12 + IE_KEY_STATE_OFF], KEY_PRESSED
    jne .delegate
    mov eax, [r12 + IE_KEY_CODE_OFF]
    cmp eax, KEY_TAB
    je .tab
    cmp eax, KEY_LEFT
    je .tab
    cmp eax, KEY_RIGHT
    je .tab
    cmp eax, 0x09                    ; raw VK_TAB fallback
    je .tab
    cmp eax, KEY_F1
    je .cons
    cmp eax, KEY_F2
    je .cons
    cmp eax, KEY_F3
    je .f3
    cmp eax, KEY_F4
    je .cons
    cmp eax, KEY_F5
    je .f5
    cmp eax, KEY_F6
    je .f6
    cmp eax, KEY_F7
    je .f7
    cmp eax, KEY_F8
    je .f8
    cmp eax, KEY_F9
    je .f9
    cmp eax, KEY_F10
    je .f10
    cmp eax, KEY_F
    je .fkey
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
    mov dword [rbx + FM_PROGRESS_ACTIVE_OFF], 1
    mov dword [rbx + FM_PROGRESS_PERCENT_OFF], 25
    mov rdi, rbx
    call fm_copy_selected
    mov dword [rbx + FM_PROGRESS_PERCENT_OFF], 100
    mov dword [rbx + FM_PROGRESS_ACTIVE_OFF], 0
    jmp .cons
.f3:
    mov rdi, rbx
    call fm_open_viewer_selected
    jmp .cons
.f6:
    ; rename/move placeholder: move selected to same path (no-op)
    jmp .cons
.f7:
    mov rdi, rbx
    call fm_mkdir
    jmp .cons
.f8:
    mov rdi, rbx
    call fm_delete_selected
    jmp .cons
.f9:
    mov dword [rbx + FM_CONN_ACTIVE_OFF], 1
    mov dword [rbx + FM_CONN_FIELD_OFF], 0
    jmp .cons
.f10:
    mov dword [rbx + FM_BLOOM_ACTIVE_OFF], 1
    mov dword [rbx + FM_BLOOM_SELECTED_OFF], 0
    jmp .cons
.fkey:
    test dword [r12 + INPUT_EVENT_MODIFIERS_OFF], MOD_CTRL
    jz .delegate
    mov rdi, rbx
    call fm_connect_open
    jmp .cons
.dialog:
    cmp eax, INPUT_MOUSE_BUTTON
    je .dlg_point
    cmp eax, INPUT_TOUCH_DOWN
    je .dlg_point
    cmp eax, INPUT_KEY
    jne .cons
    cmp dword [r12 + IE_KEY_STATE_OFF], KEY_PRESSED
    jne .cons
    mov eax, [r12 + IE_KEY_CODE_OFF]
    cmp eax, KEY_ESC
    je .dlg_cancel
    cmp eax, KEY_TAB
    je .dlg_tab
    cmp eax, KEY_ENTER
    je .dlg_enter
    cmp eax, KEY_UP
    je .dlg_up
    cmp eax, KEY_DOWN
    je .dlg_down
    cmp eax, KEY_BACKSPACE
    je .dlg_back
    cmp eax, 32
    jl .cons
    cmp eax, 126
    ja .cons
    jmp .dlg_put
.dlg_point:
    cmp eax, INPUT_MOUSE_BUTTON
    jne .pt_xy
    cmp dword [r12 + IE_KEY_STATE_OFF], KEY_PRESSED
    jne .cons
.pt_xy:
    mov ecx, [r12 + IE_MOUSE_X_OFF]
    mov edx, [r12 + IE_MOUSE_Y_OFF]
    ; field boxes x=[262..581], y starts 193, step 30
    cmp ecx, 262
    jl .pt_buttons
    cmp ecx, 582
    jge .pt_buttons
    cmp edx, 193
    jl .pt_buttons
    cmp edx, 307
    jg .pt_buttons
    mov eax, edx
    sub eax, 193
    mov esi, 30
    xor edx, edx
    div esi
    cmp eax, 3
    jg .pt_buttons
    mov [rbx + FM_CONN_FIELD_OFF], eax
    jmp .cons
.pt_buttons:
    ; Connect button rect x=[200..299], y=[348..375]
    cmp ecx, 200
    jl .pt_cancel
    cmp ecx, 300
    jge .pt_cancel
    cmp edx, 348
    jl .pt_cancel
    cmp edx, 376
    jge .pt_cancel
    mov dword [rbx + FM_CONN_FIELD_OFF], 4
    mov rdi, rbx
    call fm_connect_apply
    jmp .cons
.pt_cancel:
    ; Cancel button rect x=[320..419], y=[348..375]
    cmp ecx, 320
    jl .cons
    cmp ecx, 420
    jge .cons
    cmp edx, 348
    jl .cons
    cmp edx, 376
    jge .cons
    mov dword [rbx + FM_CONN_FIELD_OFF], 5
    jmp .dlg_cancel
.dlg_cancel:
    mov dword [rbx + FM_CONN_ACTIVE_OFF], 0
    jmp .cons
.dlg_tab:
    inc dword [rbx + FM_CONN_FIELD_OFF]
    cmp dword [rbx + FM_CONN_FIELD_OFF], 6
    jl .cons
    mov dword [rbx + FM_CONN_FIELD_OFF], 0
    jmp .cons
.dlg_enter:
    mov eax, [rbx + FM_CONN_FIELD_OFF]
    cmp eax, 5
    je .dlg_cancel
    mov rdi, rbx
    call fm_connect_apply
    jmp .cons
.dlg_up:
    cmp dword [rel fm_conn_hist_count], 0
    jle .cons
    mov eax, [rel fm_conn_hist_sel]
    cmp eax, 0
    jle .cons
    dec eax
    mov [rel fm_conn_hist_sel], eax
    mov rdi, rbx
    mov esi, eax
    call fm_history_apply
    jmp .cons
.dlg_down:
    mov ecx, [rel fm_conn_hist_count]
    test ecx, ecx
    jle .cons
    mov eax, [rel fm_conn_hist_sel]
    inc eax
    cmp eax, ecx
    jge .cons
    mov [rel fm_conn_hist_sel], eax
    mov rdi, rbx
    mov esi, eax
    call fm_history_apply
    jmp .cons
.dlg_back:
    mov ecx, [rbx + FM_CONN_FIELD_OFF]
    cmp ecx, 4
    jge .cons
    cmp ecx, 0
    je .fld_host_b
    cmp ecx, 1
    je .fld_port_b
    cmp ecx, 2
    je .fld_user_b
    lea rdi, [rbx + FM_CONN_PASS_OFF]
    jmp .do_back
.fld_host_b:
    lea rdi, [rbx + FM_CONN_HOST_OFF]
    jmp .do_back
.fld_port_b:
    lea rdi, [rbx + FM_CONN_PORT_OFF]
    jmp .do_back
.fld_user_b:
    lea rdi, [rbx + FM_CONN_USER_OFF]
.do_back:
    call fm_cstr_len
    test eax, eax
    jle .cons
    dec eax
    mov byte [rdi + rax], 0
    jmp .cons
.dlg_put:
    mov dl, al
    mov ecx, [rbx + FM_CONN_FIELD_OFF]
    cmp ecx, 4
    jge .cons
    cmp ecx, 0
    je .fld_host_p
    cmp ecx, 1
    je .fld_port_p
    cmp ecx, 2
    je .fld_user_p
    lea rdi, [rbx + FM_CONN_PASS_OFF]
    mov ecx, 63
    jmp .do_put
.fld_host_p:
    lea rdi, [rbx + FM_CONN_HOST_OFF]
    mov ecx, 127
    jmp .do_put
.fld_port_p:
    lea rdi, [rbx + FM_CONN_PORT_OFF]
    mov ecx, 15
    jmp .do_put
.fld_user_p:
    lea rdi, [rbx + FM_CONN_USER_OFF]
    mov ecx, 63
.do_put:
    call fm_cstr_len
    cmp eax, ecx
    jge .cons
    mov [rdi + rax], dl
    mov byte [rdi + rax + 1], 0
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
