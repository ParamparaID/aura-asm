; gradient.asm — linear & radial gradients (ARGB)

%include "src/canvas/canvas.inc"

extern canvas_put_pixel
extern canvas_fill_rect_scalar

section .rodata
sin0_90:
    dd 0,1144,2287,3430,4572,5712,6850,7987,9121,10252,11380,12505,13626,14742,15855,16962,18064,19161,20252,21336,22415,23486,24550,25607,26656,27697,28729,29753,30767,31772,32768,33754,34729,35693,36647,37590,38521,39441,40348,41243,42126,42995,43852,44695,45525,46341,47143,47930,48703,49461,50203,50931,51643,52339,53020,53684,54332,54963,55578,56175,56756,57319,57865,58393,58903,59396,59870,60326,60764,61183,61584,61966,62328,62672,62997,63303,63589,63856,64104,64332,64540,64729,64898,65048,65177,65287,65376,65446,65496,65526,65536

section .text
global canvas_gradient_linear
global canvas_gradient_radial

sin_cos_from_deg:
    xor edx, edx
    mov ecx, 360
    div ecx
    mov eax, edx
    cmp eax, 90
    ja .sc_q1
    movsxd rcx, eax
    mov ebx, dword [sin0_90 + rcx*4]
    mov ecx, 90
    sub ecx, eax
    movsxd rcx, ecx
    mov ebp, dword [sin0_90 + rcx*4]
    ret
.sc_q1:
    cmp eax, 180
    ja .sc_q2
    sub eax, 90
    mov ecx, 90
    sub ecx, eax
    movsxd rcx, ecx
    mov ebx, dword [sin0_90 + rcx*4]
    movsxd rcx, eax
    mov ebp, dword [sin0_90 + rcx*4]
    neg ebp
    ret
.sc_q2:
    cmp eax, 270
    ja .sc_q3
    sub eax, 180
    movsxd rcx, eax
    mov ebx, dword [sin0_90 + rcx*4]
    neg ebx
    mov ecx, 90
    sub ecx, eax
    movsxd rcx, ecx
    mov ebp, dword [sin0_90 + rcx*4]
    neg ebp
    ret
.sc_q3:
    sub eax, 270
    mov ecx, 90
    sub ecx, eax
    movsxd rcx, ecx
    mov ebx, dword [sin0_90 + rcx*4]
    neg ebx
    movsxd rcx, eax
    mov ebp, dword [sin0_90 + rcx*4]
    ret

isqrt32:
    xor ecx, ecx
    mov edx, 1 << 30
.isq_lp:
    test edx, edx
    jz .isq_done
    lea esi, [rcx + rdx]
    cmp eax, esi
    jb .isq_skip
    sub eax, esi
    shr ecx, 1
    add ecx, edx
    jmp .isq_next
.isq_skip:
    shr ecx, 1
.isq_next:
    shr edx, 2
    jmp .isq_lp
.isq_done:
    mov eax, ecx
    ret

; lerp byte: ecx=c1b edx=c2b eax=t 0..65536
lerp_byte:
    push rsi
    mov esi, 65536
    sub esi, eax
    imul ecx, esi
    imul edx, eax
    add ecx, edx
    add ecx, 32768
    shr ecx, 16
    mov eax, ecx
    pop rsi
    ret

; canvas_gradient_linear(canvas,x,y,w,h,c1,c2,angle)
canvas_gradient_linear:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 72

    test rdi, rdi
    jz .gl_bad
    test rcx, rcx
    jle .gl_bad
    test r8, r8
    jle .gl_bad

    mov qword [rsp + 64], rdi
    mov dword [rsp + 32], esi
    mov dword [rsp + 36], edx
    mov dword [rsp + 40], ecx
    mov dword [rsp + 44], r8d
    mov dword [rsp + 48], r9d
    mov eax, dword [rbp + 16]
    mov dword [rsp + 52], eax
    mov eax, dword [rbp + 24]
    call sin_cos_from_deg
    mov dword [rsp + 56], ebx
    mov dword [rsp + 60], ebp

    mov rbx, qword [rsp + 64]
    mov esi, dword [rsp + 32]
    mov edx, dword [rsp + 36]
    mov ecx, dword [rsp + 40]
    mov r8d, dword [rsp + 44]

    xor r9d, r9d
    cmp esi, 0
    cmovge r9, rsi
    xor r10d, r10d
    cmp edx, 0
    cmovge r10, rdx
    mov r11, rsi
    add r11, rcx
    mov eax, [rbx + CV_WIDTH_OFF]
    cmp r11, rax
    cmova r11, rax
    mov rsi, rdx
    add rsi, r8
    mov eax, [rbx + CV_HEIGHT_OFF]
    cmp rsi, rax
    cmova rsi, rax
    cmp r11, r9
    jle .gl_ok
    cmp rsi, r10
    jle .gl_ok

    mov eax, [rbx + CV_CLIP_W_OFF]
    test eax, eax
    jz .gl_ok
    mov eax, [rbx + CV_CLIP_X_OFF]
    mov ecx, [rbx + CV_CLIP_Y_OFF]
    mov r8d, eax
    add r8d, [rbx + CV_CLIP_W_OFF]
    mov r12d, ecx
    add r12d, [rbx + CV_CLIP_H_OFF]
    cmp r9, rax
    cmovl r9, rax
    cmp r10, rcx
    cmovl r10, rcx
    cmp r11, r8
    cmova r11, r8
    cmp rsi, r12
    cmova rsi, r12
    cmp r11, r9
    jle .gl_ok
    cmp rsi, r10
    jle .gl_ok

    mov [rsp + 24], esi

    mov ecx, dword [rsp + 40]
    dec ecx
    xor rax, rax
    cmp ecx, 0
    jl .gl_a10
    movsxd rax, ecx
    movsxd rcx, dword [rsp + 60]
    imul rax, rcx
    sar rax, 16
.gl_a10:
    mov qword [rsp], rax

    mov ecx, dword [rsp + 44]
    dec ecx
    xor rax, rax
    cmp ecx, 0
    jl .gl_a01
    movsxd rax, ecx
    movsxd rcx, dword [rsp + 56]
    imul rax, rcx
    sar rax, 16
.gl_a01:
    mov qword [rsp + 8], rax

    mov rax, qword [rsp]
    mov rcx, qword [rsp + 8]
    lea rdx, [rax + rcx]
    mov qword [rsp + 16], rdx

    xor rdi, rdi
    mov rax, qword [rsp]
    cmp rax, rdi
    cmovl rdi, rax
    mov rax, qword [rsp + 8]
    cmp rax, rdi
    cmovl rdi, rax
    mov rax, qword [rsp + 16]
    cmp rax, rdi
    cmovl rdi, rax

    xor r8, r8
    mov rax, qword [rsp]
    cmp rax, r8
    cmovg r8, rax
    mov rax, qword [rsp + 8]
    cmp rax, r8
    cmovg r8, rax
    mov rax, qword [rsp + 16]
    cmp rax, r8
    cmovg r8, rax

    mov r12, rdi
    mov r13, r8
    mov r14, r13
    sub r14, r12
    jz .gl_solid

    mov r15d, r10d
.gl_y:
    mov eax, [rsp + 24]
    cmp r15d, eax
    jae .gl_ok
    mov r8d, r9d
.gl_x:
    cmp r8d, r11d
    jae .gl_ny

    movsxd rax, r8d
    sub eax, dword [rsp + 32]
    movsxd rax, eax
    movsxd rcx, dword [rsp + 60]
    imul rax, rcx
    sar rax, 16
    mov rcx, rax

    movsxd rax, r15d
    sub eax, dword [rsp + 36]
    movsxd rax, eax
    movsxd rdx, dword [rsp + 56]
    imul rax, rdx
    sar rax, 16
    add rax, rcx

    sub rax, r12
    jl .gl_tz
    cmp r14, 0
    jle .gl_tz
    imul rax, 65536
    cqo
    idiv r14
    cmp rax, 65536
    jge .gl_tcap
    jmp .gl_tset
.gl_tz:
    xor eax, eax
    jmp .gl_tset
.gl_tcap:
    mov eax, 65536
.gl_tset:
    mov r10d, eax

    mov ecx, dword [rsp + 48]
    mov edx, dword [rsp + 52]
    and ecx, 0xFF
    and edx, 0xFF
    mov eax, r10d
    call lerp_byte
    mov ebp, eax

    mov ecx, dword [rsp + 48]
    mov edx, dword [rsp + 52]
    shr ecx, 8
    shr edx, 8
    and ecx, 0xFF
    and edx, 0xFF
    mov eax, r10d
    call lerp_byte
    mov dword [rsp], eax

    mov ecx, dword [rsp + 48]
    mov edx, dword [rsp + 52]
    shr ecx, 16
    shr edx, 16
    and ecx, 0xFF
    and edx, 0xFF
    mov eax, r10d
    call lerp_byte
    mov ecx, eax
    shl ecx, 16
    mov eax, dword [rsp]
    shl eax, 8
    or ecx, eax
    or ecx, ebp
    or ecx, 0xFF000000

    mov rdi, qword [rsp + 64]
    mov esi, r8d
    mov edx, r15d
    call canvas_put_pixel

    inc r8d
    jmp .gl_x
.gl_ny:
    inc r15d
    jmp .gl_y

.gl_solid:
    mov rdi, qword [rsp + 64]
    mov esi, dword [rsp + 32]
    mov edx, dword [rsp + 36]
    mov ecx, dword [rsp + 40]
    mov r8d, dword [rsp + 44]
    mov r9d, dword [rsp + 48]
    call canvas_fill_rect_scalar
    jmp .gl_ok

.gl_bad:
    mov rax, -1
    jmp .gl_end
.gl_ok:
    xor eax, eax
.gl_end:
    add rsp, 72
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; canvas_gradient_radial(canvas, cx, cy, radius, c_center, c_edge)
canvas_gradient_radial:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 40

    test rdi, rdi
    jz .gr_bad
    test rcx, rcx
    jle .gr_bad

    mov qword [rsp + 32], rdi
    mov dword [rsp + 16], esi
    mov dword [rsp + 20], edx
    mov dword [rsp + 24], ecx
    mov dword [rsp + 28], r8d
    mov dword [rsp + 0], r9d

    mov ebx, esi
    sub ebx, ecx
    mov r12d, edx
    sub r12d, ecx
    lea r13d, [rcx + rcx]

    xor r9d, r9d
    cmp ebx, 0
    cmovge r9, rbx
    xor r10d, r10d
    cmp r12d, 0
    cmovge r10, r12

    mov r11, rbx
    add r11, r13
    mov rax, qword [rsp + 32]
    mov eax, [rax + CV_WIDTH_OFF]
    cmp r11, rax
    cmova r11, rax

    mov rsi, r12
    add rsi, r13
    mov rax, qword [rsp + 32]
    mov eax, [rax + CV_HEIGHT_OFF]
    cmp rsi, rax
    cmova rsi, rax

    cmp r11, r9
    jle .gr_ok
    cmp rsi, r10
    jle .gr_ok

    mov rbx, qword [rsp + 32]
    mov eax, [rbx + CV_CLIP_W_OFF]
    test eax, eax
    jz .gr_ok
    mov eax, [rbx + CV_CLIP_X_OFF]
    mov ecx, [rbx + CV_CLIP_Y_OFF]
    mov r8d, eax
    add r8d, [rbx + CV_CLIP_W_OFF]
    mov r14d, ecx
    add r14d, [rbx + CV_CLIP_H_OFF]
    cmp r9, rax
    cmovl r9, rax
    cmp r10, rcx
    cmovl r10, rcx
    cmp r11, r8
    cmova r11, r8
    cmp rsi, r14
    cmova rsi, r14

    cmp r11, r9
    jle .gr_ok
    cmp rsi, r10
    jle .gr_ok

    mov r15d, r10d
.gr_y:
    cmp r15d, esi
    jae .gr_ok
    mov r12d, r9d
.gr_x:
    cmp r12d, r11d
    jae .gr_ny

    mov eax, r12d
    sub eax, dword [rsp + 16]
    imul eax, eax
    mov ecx, eax
    mov eax, r15d
    sub eax, dword [rsp + 20]
    imul eax, eax
    add eax, ecx

    call isqrt32
    mov ecx, 65536
    mul ecx
    mov ecx, dword [rsp + 24]
    test ecx, ecx
    jz .gr_tc
    div ecx
    cmp eax, 65536
    jge .gr_tc
    jmp .gr_tset
.gr_tc:
    mov eax, 65536
.gr_tset:
    mov r10d, eax

    mov ecx, dword [rsp + 0]
    mov edx, dword [rsp + 28]
    and ecx, 0xFF
    and edx, 0xFF
    mov eax, r10d
    call lerp_byte
    mov ebp, eax

    mov ecx, dword [rsp + 0]
    mov edx, dword [rsp + 28]
    shr ecx, 8
    shr edx, 8
    and ecx, 0xFF
    and edx, 0xFF
    mov eax, r10d
    call lerp_byte
    mov r8d, eax

    mov ecx, dword [rsp + 0]
    mov edx, dword [rsp + 28]
    shr ecx, 16
    shr edx, 16
    and ecx, 0xFF
    and edx, 0xFF
    mov eax, r10d
    call lerp_byte
    mov ecx, eax
    shl ecx, 16
    mov eax, r8d
    shl eax, 8
    or ecx, eax
    or ecx, ebp
    or ecx, 0xFF000000

    mov rdi, qword [rsp + 32]
    mov esi, r12d
    mov edx, r15d
    call canvas_put_pixel

    inc r12d
    jmp .gr_x
.gr_ny:
    inc r15d
    jmp .gr_y

.gr_bad:
    mov rax, -1
    jmp .gr_end
.gr_ok:
    xor eax, eax
.gr_end:
    add rsp, 40
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret