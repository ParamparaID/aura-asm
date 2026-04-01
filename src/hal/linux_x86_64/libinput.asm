; libinput.asm — standalone evdev scan + read (MVP; not libinput library)
%include "src/hal/platform_defs.inc"

extern hal_open
extern hal_close
extern hal_read

section .rodata
    dev_input       db "/dev/input/event"
    dev_input_len   equ $ - dev_input

%define EVIOCGBIT_EV_REL_8   0x80084522
%define EVIOCGBIT_EV_ABS_64  0x80404523

section .bss
    evdev_fds       resd 32
    evdev_nfds      resd 1

section .text
global evdev_init
global evdev_count
global evdev_get_fd
global evdev_read
global evdev_read_event

evdev_count:
    mov eax, dword [rel evdev_nfds]
    ret

evdev_get_fd:
    cmp esi, 32
    jae .bad
    cmp esi, dword [rel evdev_nfds]
    jae .bad
    movsxd rax, esi
    mov eax, dword [rel evdev_fds + rax*4]
    ret
.bad:
    mov eax, -1
    ret

; evdev_read_event(fd, out24) -> rax from hal_read
evdev_read_event:
    movsxd rdi, edi
    mov rdx, 24
    jmp hal_read

; evdev_read(fd, out_buf, max_events) -> bytes read
evdev_read:
    mov eax, edx
    imul eax, 24
    mov edx, eax
    movsxd rdi, edi
    jmp hal_read

; key_bit(keycode edi, bitmask rsi) -> al
key_bit:
    mov eax, edi
    mov ecx, edi
    shr ecx, 3
    movzx edx, byte [rsi + rcx]
    and eax, 7
    bt edx, eax
    setc al
    ret

; evdev_try_add(fd) -> eax 0 added, -1 skip
evdev_try_add:
    push rbx
    push r12
    sub rsp, 128
    mov r12d, edi

    mov eax, dword [rel evdev_nfds]
    cmp eax, 32
    jae .reject

    movsxd rdi, r12d
    mov rsi, EVIOCGBIT_EV_KEY_64
    lea rdx, [rsp + 8]
    mov rax, SYS_IOCTL
    syscall
    cmp rax, 0
    jle .no_key
    mov edi, KEY_A
    lea rsi, [rsp + 8]
    call key_bit
    test al, al
    jz .no_key
    mov edi, KEY_Z
    lea rsi, [rsp + 8]
    call key_bit
    test al, al
    jz .no_key
    jmp .add
.no_key:
    movsxd rdi, r12d
    mov rsi, EVIOCGBIT_EV_REL_8
    lea rdx, [rsp + 8]
    mov rax, SYS_IOCTL
    syscall
    cmp rax, 0
    jle .no_rel
    mov rax, qword [rsp + 8]
    bt rax, REL_X
    jnc .no_rel
    bt rax, REL_Y
    jnc .no_rel
    jmp .add
.no_rel:
    movsxd rdi, r12d
    mov rsi, EVIOCGBIT_EV_ABS_64
    lea rdx, [rsp + 8]
    mov rax, SYS_IOCTL
    syscall
    cmp rax, 0
    jle .reject
    mov edi, ABS_MT_POSITION_X
    lea rsi, [rsp + 8]
    call key_bit
    test al, al
    jz .reject
.add:
    mov eax, dword [rel evdev_nfds]
    mov dword [rel evdev_fds + rax*4], r12d
    inc dword [rel evdev_nfds]
    xor eax, eax
    jmp .done
.reject:
    mov eax, -1
.done:
    add rsp, 128
    pop r12
    pop rbx
    ret

; build_event_path(buf40, index)
build_event_path:
    push rbx
    push r12
    mov rbx, rdi
    mov r12d, esi
    lea rsi, [rel dev_input]
    mov rdi, rbx
    mov ecx, dev_input_len
    rep movsb
    mov eax, r12d
    cmp eax, 100
    jae .z
    cmp eax, 10
    jb .oned
    xor edx, edx
    mov ecx, 10
    div ecx
    add al, '0'
    mov [rdi], al
    inc rdi
    add dl, '0'
    mov [rdi], dl
    inc rdi
    jmp .z
.oned:
    add al, '0'
    mov [rdi], al
    inc rdi
.z:
    mov byte [rdi], 0
    pop r12
    pop rbx
    ret

evdev_init:
    push rbx
    push r12
    push r13
    mov dword [rel evdev_nfds], 0
    xor r12d, r12d
.loop:
    cmp r12d, 32
    jae .done

    sub rsp, 48
    mov rdi, rsp
    mov esi, r12d
    call build_event_path

    mov rdi, rsp
    mov esi, O_RDONLY | O_NONBLOCK | O_CLOEXEC
    xor edx, edx
    call hal_open
    mov r13d, eax
    add rsp, 48
    test r13d, r13d
    js .next

    mov edi, r13d
    call evdev_try_add
    test eax, eax
    jz .next
    movsx rdi, r13d
    call hal_close
.next:
    inc r12d
    jmp .loop
.done:
    xor eax, eax
    pop r13
    pop r12
    pop rbx
    ret
