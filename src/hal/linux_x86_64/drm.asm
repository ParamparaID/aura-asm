; drm.asm — DRM/KMS dumb buffer + modeset (MVP, Linux uapi drm_mode.h layout)
%include "src/hal/linux_x86_64/defs.inc"
%include "src/canvas/canvas.inc"

extern hal_open
extern hal_close
extern hal_mmap
extern hal_munmap

%define DRM_IOCTL_SET_MASTER           0x0000641E
%define DRM_IOCTL_DROP_MASTER          0x0000641F
%define DRM_IOCTL_MODE_GETRESOURCES    0xC03864A0
%define DRM_IOCTL_MODE_GETCRTC         0xC06864A1
%define DRM_IOCTL_MODE_SETCRTC         0xC06864A2
%define DRM_IOCTL_MODE_GETCONNECTOR    0xC05064A7
%define DRM_IOCTL_MODE_CREATE_DUMB     0xC02064B2
%define DRM_IOCTL_MODE_MAP_DUMB        0xC01064B3
%define DRM_IOCTL_MODE_ADDFB           0xC01C64AE
%define DRM_IOCTL_MODE_RMFB            0xC00464AF
%define DRM_IOCTL_MODE_DESTROY_DUMB    0xC00464B4

%define DRM_MODE_CONNECTED             1
%define DRM_MODE_TYPE_PREFERRED        8

; drm_mode_card_res — 56 bytes
%define DMR_CONN_PTR    16
%define DMR_CRTC_PTR    8
%define DMR_COUNT_CONN  40
%define DMR_COUNT_CRTC  36

; drm_mode_get_connector
%define DG_MODES_PTR    8
%define DG_COUNT_MODES  32
%define DG_CONN_ID      48
%define DG_CONNECTION   60

; drm_mode_modeinfo (per mode)
%define MI_HDISPLAY     4
%define MI_VDISPLAY     14
%define MI_FLAGS        28
%define MI_TYPE         32

; drm_mode_crtc
%define MC_SET_CONN_PTR 0
%define MC_COUNT_CONN   8
%define MC_CRTC_ID      12
%define MC_FB_ID        16
%define MC_X            20
%define MC_Y            24
%define MC_GAMMA        28
%define MC_MODE_VALID   32
%define MC_MODE         36

; drm_mode_fb_cmd — 28 bytes (7 dd)
%define FB_FB_ID        0
%define FB_WIDTH        4
%define FB_HEIGHT       8
%define FB_PITCH        12
%define FB_BPP          16
%define FB_DEPTH        20
%define FB_HANDLE       24

section .rodata
    path_card0      db "/dev/dri/card0", 0

section .bss
    drm_fd                  resd 1
    drm_fb_id               resd 1
    drm_dumb_handle         resd 1
    drm_pitch               resd 1
    drm_width               resd 1
    drm_height              resd 1
    drm_connector_id        resd 1
    drm_crtc_id             resd 1
    drm_mmap_ptr            resq 1
    drm_mmap_size           resq 1
    drm_saved_crtc_valid    resd 1
    drm_saved_crtc          resb 120
    drm_work_crtc           resb 120
    drm_card_res            resb 64
    drm_conn_ids            resd 32
    drm_crtc_ids            resd 32
    drm_get_conn            resb 96
    drm_modes               resb (32 * 68)
    drm_one_conn            resd 1

section .text
global drm_init
global drm_present
global drm_cleanup
global drm_get_framebuffer_ptr
global drm_get_pitch
global drm_get_width
global drm_get_height

drm_get_framebuffer_ptr:
    mov rax, [rel drm_mmap_ptr]
    ret

drm_get_pitch:
    mov eax, dword [rel drm_pitch]
    ret

drm_get_width:
    mov eax, dword [rel drm_width]
    ret

drm_get_height:
    mov eax, dword [rel drm_height]
    ret

drm_cleanup:
    push rbx
    mov ebx, dword [rel drm_fd]
    cmp ebx, 0
    jl .out

    cmp dword [rel drm_saved_crtc_valid], 0
    je .no_restore
    mov edi, ebx
    mov rsi, DRM_IOCTL_MODE_SETCRTC
    lea rdx, [rel drm_saved_crtc]
    mov rax, SYS_IOCTL
    syscall
.no_restore:

    cmp dword [rel drm_fb_id], 0
    je .no_rmfb
    sub rsp, 16
    mov eax, dword [rel drm_fb_id]
    mov dword [rsp + 8], eax
    mov edi, ebx
    mov rsi, DRM_IOCTL_MODE_RMFB
    lea rdx, [rsp + 8]
    mov rax, SYS_IOCTL
    syscall
    add rsp, 16
    mov dword [rel drm_fb_id], 0
.no_rmfb:

    cmp dword [rel drm_dumb_handle], 0
    je .no_destroy
    sub rsp, 16
    mov eax, dword [rel drm_dumb_handle]
    mov dword [rsp + 8], eax
    mov edi, ebx
    mov rsi, DRM_IOCTL_MODE_DESTROY_DUMB
    lea rdx, [rsp + 8]
    mov rax, SYS_IOCTL
    syscall
    add rsp, 16
    mov dword [rel drm_dumb_handle], 0
.no_destroy:

    mov rdi, [rel drm_mmap_ptr]
    test rdi, rdi
    jz .no_unmap
    mov rsi, [rel drm_mmap_size]
    call hal_munmap
    mov qword [rel drm_mmap_ptr], 0
.no_unmap:

    mov edi, ebx
    mov rsi, DRM_IOCTL_DROP_MASTER
    xor edx, edx
    mov rax, SYS_IOCTL
    syscall

    movsx rdi, ebx
    call hal_close
    mov dword [rel drm_fd], -1
    mov dword [rel drm_saved_crtc_valid], 0
.out:
    pop rbx
    ret

; drm_present(canvas*)
drm_present:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi

    mov r11, [rel drm_mmap_ptr]
    test r11, r11
    jz .out
    mov r12d, dword [rel drm_pitch]
    mov r13d, dword [rel drm_width]
    mov r14d, dword [rel drm_height]
    mov r15, [rbx + CV_BUFFER_OFF]
    mov ebx, dword [rbx + CV_STRIDE_OFF]

    xor ecx, ecx
.row:
    cmp ecx, r14d
    jae .out
    mov rsi, r15
    mov rdi, r11
    movsxd rdx, ecx
    imul rdx, rbx
    add rsi, rdx
    movsxd rdx, ecx
    imul rdx, r12
    add rdi, rdx
    mov edx, r13d
    shl edx, 2
    push rcx
    mov rcx, rdx
    rep movsb
    pop rcx
    inc ecx
    jmp .row
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; drm_init() -> eax 0 ok, negative errno
drm_init:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 128

    call drm_cleanup
    mov dword [rel drm_fb_id], 0
    mov dword [rel drm_dumb_handle], 0
    mov qword [rel drm_mmap_ptr], 0

    lea rdi, [rel path_card0]
    mov esi, O_RDWR
    xor edx, edx
    call hal_open
    test rax, rax
    js .fail_open
    mov dword [rel drm_fd], eax
    movsxd r12, eax

    mov rdi, r12
    mov rsi, DRM_IOCTL_SET_MASTER
    xor edx, edx
    mov rax, SYS_IOCTL
    syscall
    test rax, rax
    jnz .fail

    lea rdi, [rel drm_card_res]
    mov ecx, 64
    xor eax, eax
    rep stosb

    lea rax, [rel drm_conn_ids]
    mov qword [rel drm_card_res + DMR_CONN_PTR], rax
    mov dword [rel drm_card_res + DMR_COUNT_CONN], 32
    lea rax, [rel drm_crtc_ids]
    mov qword [rel drm_card_res + DMR_CRTC_PTR], rax
    mov dword [rel drm_card_res + DMR_COUNT_CRTC], 32

    mov rdi, r12
    mov rsi, DRM_IOCTL_MODE_GETRESOURCES
    lea rdx, [rel drm_card_res]
    mov rax, SYS_IOCTL
    syscall
    test rax, rax
    jnz .fail

    xor r13d, r13d
.conn_loop:
    cmp r13d, dword [rel drm_card_res + DMR_COUNT_CONN]
    jae .fail
    lea rbx, [rel drm_conn_ids]
    mov eax, dword [rbx + r13*4]
    mov dword [rel drm_connector_id], eax

    lea rdi, [rel drm_get_conn]
    mov ecx, 96
    xor eax, eax
    rep stosb

    mov eax, dword [rel drm_connector_id]
    mov dword [rel drm_get_conn + DG_CONN_ID], eax
    lea rax, [rel drm_modes]
    mov qword [rel drm_get_conn + DG_MODES_PTR], rax
    mov dword [rel drm_get_conn + DG_COUNT_MODES], 32

    mov rdi, r12
    mov rsi, DRM_IOCTL_MODE_GETCONNECTOR
    lea rdx, [rel drm_get_conn]
    mov rax, SYS_IOCTL
    syscall
    test rax, rax
    jnz .next_conn

    cmp dword [rel drm_get_conn + DG_CONNECTION], DRM_MODE_CONNECTED
    jne .next_conn
    cmp dword [rel drm_get_conn + DG_COUNT_MODES], 0
    je .next_conn

    mov r14d, -1
    xor r15d, r15d
.pref:
    mov eax, dword [rel drm_get_conn + DG_COUNT_MODES]
    cmp r15d, eax
    jae .pref_done
    imul eax, r15d, 68
    lea rbx, [rel drm_modes]
    mov eax, dword [rbx + rax + MI_TYPE]
    test eax, DRM_MODE_TYPE_PREFERRED
    jz .pref_next
    mov r14d, r15d
    jmp .pref_done
.pref_next:
    inc r15d
    jmp .pref
.pref_done:
    cmp r14d, 0
    jge .have_mode
    xor r14d, r14d
.have_mode:
    imul eax, r14d, 68
    lea rbx, [rel drm_modes]
    add rbx, rax

    movzx eax, word [rbx + MI_HDISPLAY]
    mov dword [rel drm_width], eax
    movzx eax, word [rbx + MI_VDISPLAY]
    mov dword [rel drm_height], eax

    mov eax, dword [rel drm_crtc_ids]
    mov dword [rel drm_crtc_id], eax

    lea rdi, [rel drm_saved_crtc]
    mov ecx, 120
    xor eax, eax
    rep stosb
    mov eax, dword [rel drm_crtc_id]
    mov dword [rel drm_saved_crtc + MC_CRTC_ID], eax

    mov rdi, r12
    mov rsi, DRM_IOCTL_MODE_GETCRTC
    lea rdx, [rel drm_saved_crtc]
    mov rax, SYS_IOCTL
    syscall
    test rax, rax
    jnz .skip_save
    mov dword [rel drm_saved_crtc_valid], 1
.skip_save:

    mov eax, dword [rel drm_connector_id]
    mov dword [rel drm_one_conn], eax

    sub rsp, 64
    xor eax, eax
    mov ecx, 16
    mov rdi, rsp
    rep stosq

    mov eax, dword [rel drm_height]
    mov dword [rsp], eax
    mov eax, dword [rel drm_width]
    mov dword [rsp + 4], eax
    mov dword [rsp + 8], 32
    mov dword [rsp + 12], 0

    mov rdi, r12
    mov rsi, DRM_IOCTL_MODE_CREATE_DUMB
    mov rdx, rsp
    mov rax, SYS_IOCTL
    syscall
    test rax, rax
    jnz .fail_pop64

    mov eax, dword [rsp + 16]
    mov dword [rel drm_dumb_handle], eax
    mov eax, dword [rsp + 20]
    mov dword [rel drm_pitch], eax
    mov rax, qword [rsp + 24]
    mov qword [rel drm_mmap_size], rax
    add rsp, 64

    sub rsp, 32
    xor eax, eax
    mov dword [rsp + 0], eax
    mov dword [rsp + 4], eax
    mov qword [rsp + 8], rax
    mov eax, dword [rel drm_dumb_handle]
    mov dword [rsp + 0], eax
    mov rdi, r12
    mov rsi, DRM_IOCTL_MODE_MAP_DUMB
    mov rdx, rsp
    mov rax, SYS_IOCTL
    syscall
    test rax, rax
    jnz .fail_pop32
    mov r15, qword [rsp + 8]
    add rsp, 32

    xor edi, edi
    mov rsi, [rel drm_mmap_size]
    mov rdx, PROT_READ | PROT_WRITE
    mov rcx, MAP_SHARED
    mov r8, r12
    mov r9, r15
    call hal_mmap
    test rax, rax
    js .fail
    mov [rel drm_mmap_ptr], rax

    sub rsp, 32
    xor eax, eax
    mov qword [rsp], rax
    mov qword [rsp + 8], rax
    mov qword [rsp + 16], rax
    mov qword [rsp + 24], rax

    mov eax, dword [rel drm_dumb_handle]
    mov dword [rsp + FB_HANDLE], eax
    mov eax, dword [rel drm_width]
    mov dword [rsp + FB_WIDTH], eax
    mov eax, dword [rel drm_height]
    mov dword [rsp + FB_HEIGHT], eax
    mov eax, dword [rel drm_pitch]
    mov dword [rsp + FB_PITCH], eax
    mov dword [rsp + FB_BPP], 32
    mov dword [rsp + FB_DEPTH], 24

    mov rdi, r12
    mov rsi, DRM_IOCTL_MODE_ADDFB
    mov rdx, rsp
    mov rax, SYS_IOCTL
    syscall
    test rax, rax
    jnz .fail_pop_fb
    mov eax, dword [rsp + FB_FB_ID]
    mov dword [rel drm_fb_id], eax
    add rsp, 32

    lea rdi, [rel drm_work_crtc]
    mov ecx, 120
    xor eax, eax
    rep stosb
    lea rax, [rel drm_one_conn]
    mov qword [rel drm_work_crtc + MC_SET_CONN_PTR], rax
    mov dword [rel drm_work_crtc + MC_COUNT_CONN], 1
    mov eax, dword [rel drm_crtc_id]
    mov dword [rel drm_work_crtc + MC_CRTC_ID], eax
    mov eax, dword [rel drm_fb_id]
    mov dword [rel drm_work_crtc + MC_FB_ID], eax
    mov dword [rel drm_work_crtc + MC_X], 0
    mov dword [rel drm_work_crtc + MC_Y], 0
    mov dword [rel drm_work_crtc + MC_MODE_VALID], 1
    imul eax, r14d, 68
    lea rsi, [rel drm_modes]
    add rsi, rax
    lea rdi, [rel drm_work_crtc + MC_MODE]
    mov ecx, 68
    rep movsb

    mov rdi, r12
    mov rsi, DRM_IOCTL_MODE_SETCRTC
    lea rdx, [rel drm_work_crtc]
    mov rax, SYS_IOCTL
    syscall
    test rax, rax
    jnz .fail

    xor eax, eax
    jmp .done

.next_conn:
    inc r13d
    jmp .conn_loop

.fail_pop_fb:
    add rsp, 32
    jmp .fail
.fail_pop32:
    add rsp, 32
    jmp .fail
.fail_pop64:
    add rsp, 64
    jmp .fail
.fail:
.fail_open:
    call drm_cleanup
    mov eax, -1
.done:
    add rsp, 128
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
