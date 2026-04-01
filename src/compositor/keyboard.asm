; keyboard.asm — wl_keyboard keymap, focus, key forwarding, modifiers (MVP)
%include "src/hal/platform_defs.inc"
%include "src/compositor/compositor.inc"

extern hal_memfd_create
extern hal_write
extern hal_close
extern hal_lseek
extern proto_send_event
extern proto_send_fd
extern compositor_bump_serial
extern wm_handle_hotkey

section .rodata
    memfd_xkb db "xkb", 0
    keymap_text db "xkb_keymap {", 10
                db "  xkb_keycodes { include ", 34, "evdev+aliases(qwerty)", 34, "; };", 10
                db "  xkb_types { include ", 34, "complete", 34, "; };", 10
                db "  xkb_compat { include ", 34, "complete", 34, "; };", 10
                db "  xkb_symbols { include ", 34, "pc+us+inet(evdev)", 34, "; };", 10
                db "};", 10, 0
    keymap_text_len equ $ - keymap_text - 1

%define WL_KEYBOARD_KEYMAP_FORMAT_XKB_V1  1
%define WL_KEYBOARD_KEY_STATE_RELEASED      0
%define WL_KEYBOARD_KEY_STATE_PRESSED       1

section .text
global keyboard_send_keymap
global keyboard_set_focus
global keyboard_handle_key

; keyboard_send_keymap(client, keyboard_id)
keyboard_send_keymap:
    push rbx
    push r12
    push r13
    sub rsp, 32
    mov rbx, rdi
    mov r12d, esi

    lea rdi, [rel memfd_xkb]
    mov esi, MFD_CLOEXEC
    call hal_memfd_create
    test rax, rax
    js .fail
    mov r13d, eax

    movsxd rdi, r13d
    lea rsi, [rel keymap_text]
    mov rdx, keymap_text_len
    call hal_write
    cmp rax, 0
    jle .bad_fd

    movsxd rdi, r13d
    xor esi, esi
    xor edx, edx
    call hal_lseek
    cmp rax, 0
    jl .bad_fd

    mov dword [rsp + 16], WL_KEYBOARD_KEYMAP_FORMAT_XKB_V1
    mov dword [rsp + 20], 0
    mov dword [rsp + 24], keymap_text_len

    mov rdi, rbx
    mov esi, r12d
    xor edx, edx
    lea rcx, [rsp + 16]
    mov r8, 12
    mov r9d, r13d
    call proto_send_fd
    test rax, rax
    js .bad_fd

    movsx rdi, r13d
    call hal_close
    xor eax, eax
    jmp .done
.bad_fd:
    movsx rdi, r13d
    call hal_close
.fail:
    mov rax, -1
.done:
    add rsp, 32
    pop r13
    pop r12
    pop rbx
    ret

; keyboard_set_focus(server, surface*) — rsi=0 clears focus
keyboard_set_focus:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi
    mov r12, rsi

    mov r13, [rbx + CS_KEYBOARD_FOCUS_OFF]
    cmp r13, r12
    je .same

    test r13, r13
    jz .no_leave
    mov r14, [r13 + SF_CLIENT_OFF]
    test r14, r14
    jz .no_leave
    cmp dword [r14 + CC_KEYBOARD_ID_OFF], 0
    je .no_leave
    sub rsp, 24
    mov rdi, r14
    call compositor_bump_serial
    mov dword [rsp + 8], eax
    mov eax, dword [r13 + SF_ID_OFF]
    mov dword [rsp + 12], eax
    mov rdi, r14
    mov esi, dword [r14 + CC_KEYBOARD_ID_OFF]
    mov edx, 2
    lea rcx, [rsp + 8]
    mov r8, 8
    call proto_send_event
    add rsp, 24
.no_leave:
    ; Only commit CS_KEYBOARD_FOCUS after wl_keyboard.enter is queued, so we
    ; never get r13==r12 with a surface that never received enter (would skip
    ; enter forever on the next keyboard_set_focus(same)).
    test r12, r12
    jz .kbd_clear_focus

    mov r14, [r12 + SF_CLIENT_OFF]
    test r14, r14
    jz .kbd_clear_focus
    cmp dword [r14 + CC_KEYBOARD_ID_OFF], 0
    jz .kbd_clear_focus

    sub rsp, 24
    mov rdi, r14
    call compositor_bump_serial
    mov dword [rsp + 8], eax
    mov eax, dword [r12 + SF_ID_OFF]
    mov dword [rsp + 12], eax
    mov dword [rsp + 16], 0
    mov rdi, r14
    mov esi, dword [r14 + CC_KEYBOARD_ID_OFF]
    mov edx, 1
    lea rcx, [rsp + 8]
    mov r8, 12
    call proto_send_event
    add rsp, 24
    mov [rbx + CS_KEYBOARD_FOCUS_OFF], r12
    jmp .same

.kbd_clear_focus:
    mov qword [rbx + CS_KEYBOARD_FOCUS_OFF], 0
.same:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; compositor_meta_down(server) -> al 0/1
compositor_meta_down:
    mov ecx, KEY_LEFTMETA
    mov eax, ecx
    shr eax, 3
    and ecx, 7
    mov dl, [rdi + CS_KEY_STATE_OFF + rax]
    mov al, 1
    shl al, cl
    test dl, al
    setnz al
    ret

; keyboard_handle_key(server, evdev_keycode, state 0/1/2)
keyboard_handle_key:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi
    mov r12d, esi
    mov r13d, edx

    cmp r12d, 255
    ja .out

    mov eax, r12d
    mov r14d, eax
    shr eax, 3
    and r14d, 7
    lea rdi, [rbx + CS_KEY_STATE_OFF]
    movzx edx, byte [rdi + rax]
    cmp r13d, WL_KEYBOARD_KEY_STATE_PRESSED
    je .press
    cmp r13d, 2
    je .press
    mov cl, r14b
    mov sil, 1
    shl sil, cl
    not sil
    and [rdi + rax], sil
    jmp .after_map
.press:
    mov cl, r14b
    mov sil, 1
    shl sil, cl
    or [rdi + rax], sil
.after_map:

    cmp r13d, WL_KEYBOARD_KEY_STATE_PRESSED
    jne .forward
    mov rdi, rbx
    call compositor_meta_down
    test al, al
    jz .forward
    mov rdi, rbx
    mov esi, r12d
    call wm_handle_hotkey
    test eax, eax
    jnz .hotkey
.forward:

    mov r14, [rbx + CS_KEYBOARD_FOCUS_OFF]
    test r14, r14
    jz .out
    mov r15, [r14 + SF_CLIENT_OFF]
    test r15, r15
    jz .out
    cmp dword [r15 + CC_KEYBOARD_ID_OFF], 0
    je .out

    sub rsp, 32
    mov rdi, r15
    call compositor_bump_serial
    mov dword [rsp + 8], eax
    xor eax, eax
    mov dword [rsp + 12], eax
    lea eax, [r12 + 8]
    mov dword [rsp + 16], eax
    mov dword [rsp + 20], r13d
    mov rdi, r15
    mov esi, dword [r15 + CC_KEYBOARD_ID_OFF]
    mov edx, 3
    lea rcx, [rsp + 8]
    mov r8, 16
    call proto_send_event

    mov rdi, r15
    call compositor_bump_serial
    mov dword [rsp + 8], eax
    xor eax, eax
    mov dword [rsp + 12], eax
    mov dword [rsp + 16], eax
    mov dword [rsp + 20], eax
    mov dword [rsp + 24], eax
    mov rdi, r15
    mov esi, dword [r15 + CC_KEYBOARD_ID_OFF]
    mov edx, 4
    lea rcx, [rsp + 8]
    mov r8, 20
    call proto_send_event
    add rsp, 32
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

.hotkey:
    jmp .out
