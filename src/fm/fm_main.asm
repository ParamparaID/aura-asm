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
extern file_panel_create
extern font_draw_string
extern canvas_fill_rect_alpha
extern canvas_fill_rounded_rect
extern widget_init
extern widget_add_child
extern widget_layout
extern widget_render
extern widget_handle_input
extern widget_arena_alloc
extern op_copy
extern op_delete
extern vfs_mkdir
extern vfs_path_len
extern vfs_sftp_connect

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
%define FM_STRUCT_SIZE             (FM_REMOTE_HOST_OFF + 128)

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

section .bss
    fm_pool                        resb FM_STRUCT_SIZE * FM_MAX_INSTANCES
    fm_used                        resb FM_MAX_INSTANCES
    fm_conn_mask_buf               resb 96
    fm_conn_hist_hosts             resb 128 * FM_CONN_HISTORY_MAX
    fm_conn_hist_ports             resb 16 * FM_CONN_HISTORY_MAX
    fm_conn_hist_users             resb 64 * FM_CONN_HISTORY_MAX
    fm_conn_hist_count             resd 1
    fm_conn_hist_sel               resd 1

section .text
global fm_init
global fm_render
global fm_handle_input
global fm_copy_selected
global fm_delete_selected
global fm_mkdir

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
    jae .fail
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
.fail:
    xor eax, eax
    add rsp, 16
    pop rbx
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
    mov dword [rax + P_ACTIVE_OFF], 1

    mov rdi, rax
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
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov rax, [rdi + FM_SPLIT_PANE_OFF]
    test rax, rax
    jz .dlg
    mov rdi, rax
    mov rsi, r12
    xor ecx, ecx
    xor r8d, r8d
    call widget_render
.dlg:
    mov rdi, rbx
    mov rsi, r12
    mov rdx, r13
    call fm_render_connect_dialog
    mov rdi, rbx
    mov rsi, r12
    mov rdx, r13
    call fm_render_connected_status
.out:
    pop r13
    pop r12
    pop rbx
    ret

fm_copy_selected:
    ; stub until operation dialog/progress glue is added
    mov eax, -1
    ret

fm_delete_selected:
    mov eax, -1
    ret

fm_mkdir:
    ; dialog-driven mkdir is implemented in next step
    mov eax, -1
    ret

fm_handle_input:
    ; (fm rdi, event rsi) -> eax consumed
    push rbx
    push r12
    mov rbx, rdi
    mov r12, rsi
    mov eax, [r12 + IE_TYPE_OFF]
    cmp dword [rbx + FM_CONN_ACTIVE_OFF], 0
    jne .dialog
    cmp eax, INPUT_KEY
    jne .delegate
    cmp dword [r12 + IE_KEY_STATE_OFF], KEY_PRESSED
    jne .delegate
    mov eax, [r12 + IE_KEY_CODE_OFF]
    cmp eax, KEY_TAB
    je .tab
    cmp eax, 63                      ; F5
    je .f5
    cmp eax, 66                      ; F8
    je .f8
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
    mov rdi, rbx
    call fm_copy_selected
    jmp .cons
.f8:
    mov rdi, rbx
    call fm_delete_selected
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
