; blur.asm — 2D box blur with edge clamp (tmp + out buffer)

%include "src/hal/platform_defs.inc"
%include "src/canvas/canvas.inc"

extern hal_mmap
extern hal_munmap
extern arena_alloc

section .text
global canvas_box_blur
global canvas_blur_region

canvas_box_blur:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 64
    mov qword [rsp + 56], 0
    jmp blur_main

canvas_blur_region:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 64
    mov qword [rsp + 56], 1
    mov r12, rsi
    mov esi, edx
    mov edx, ecx
    mov ecx, r8d
    mov r8d, r9d
    mov r9d, dword [rbp + 16]

blur_main:
    test rdi, rdi
    jz .fail
    test ecx, ecx
    jle .ok
    test r8, r8
    jle .ok
    cmp r9d, 0
    jl .fail

    mov rbx, rdi
    mov qword [rsp + 0], rbx
    mov dword [rsp + 24], esi
    mov dword [rsp + 28], edx
    mov dword [rsp + 32], ecx
    mov dword [rsp + 36], r8d
    mov dword [rsp + 40], r9d

    mov eax, ecx
    imul eax, r8d
    shl eax, 2
    mov dword [rsp + 52], eax
    mov r14d, eax

    cmp qword [rsp + 56], 0
    jne .arena_src
    xor edi, edi
    movsxd rsi, r14d
    mov edx, PROT_READ | PROT_WRITE
    mov ecx, MAP_PRIVATE | MAP_ANONYMOUS
    mov r8, -1
    xor r9, r9
    call hal_mmap
    test rax, rax
    js .fail
    mov qword [rsp + 8], rax
    jmp .map_dst
.arena_src:
    mov rdi, r12
    movsxd rsi, r14d
    call arena_alloc
    test rax, rax
    jz .fail
    mov qword [rsp + 8], rax

.map_dst:
    xor edi, edi
    movsxd rsi, r14d
    mov edx, PROT_READ | PROT_WRITE
    mov ecx, MAP_PRIVATE | MAP_ANONYMOUS
    mov r8, -1
    xor r9, r9
    call hal_mmap
    test rax, rax
    js .free_src
    mov qword [rsp + 16], rax

    mov r12, qword [rsp + 8]
    mov r13, qword [rsp + 16]

    xor r8d, r8d
.cp_y:
    cmp r8d, dword [rsp + 36]
    jae .do_blur
    xor r9d, r9d
.cp_x:
    cmp r9d, dword [rsp + 32]
    jae .cp_ny
    mov eax, dword [rsp + 24]
    add eax, r9d
    mov edx, dword [rsp + 28]
    add edx, r8d
    mov ecx, r8d
    imul ecx, dword [rsp + 32]
    add ecx, r9d
    movsxd rcx, ecx
    shl rcx, 2
    add rcx, r12
    test eax, eax
    js .cp_z
    test edx, edx
    js .cp_z
    cmp eax, dword [rbx + CV_WIDTH_OFF]
    jge .cp_z
    cmp edx, dword [rbx + CV_HEIGHT_OFF]
    jge .cp_z
    mov r10, [rbx + CV_BUFFER_OFF]
    imul edx, dword [rbx + CV_STRIDE_OFF]
    movsxd rax, eax
    add rdx, r10
    mov eax, dword [rdx + rax*4]
    mov dword [rcx], eax
    jmp .cp_n
.cp_z:
    mov dword [rcx], 0
.cp_n:
    inc r9d
    jmp .cp_x
.cp_ny:
    inc r8d
    jmp .cp_y

.do_blur:
    xor r8d, r8d
.b_y:
    cmp r8d, dword [rsp + 36]
    jae .write_back
    xor r9d, r9d
.b_x:
    cmp r9d, dword [rsp + 32]
    jae .b_ny
    mov dword [rsp + 44], r9d
    mov dword [rsp + 48], r8d
    xor esi, esi
    xor edi, edi
    xor eax, eax
    xor ecx, ecx
    xor r15d, r15d
    mov r10d, dword [rsp + 40]
    neg r10d
.b_dy:
    cmp r10d, dword [rsp + 40]
    jg .b_avg
    mov r11d, dword [rsp + 40]
    neg r11d
.b_dx:
    cmp r11d, dword [rsp + 40]
    jg .b_dny
    mov ebx, dword [rsp + 44]
    add ebx, r11d
    cmp ebx, 0
    jge .bx0
    xor ebx, ebx
.bx0:
    cmp ebx, dword [rsp + 32]
    jl .bx1
    mov ebx, dword [rsp + 32]
    dec ebx
.bx1:
    mov edx, dword [rsp + 48]
    add edx, r10d
    cmp edx, 0
    jge .by0
    xor edx, edx
.by0:
    cmp edx, dword [rsp + 36]
    jl .by1
    mov edx, dword [rsp + 36]
    dec edx
.by1:
    imul edx, dword [rsp + 32]
    add edx, ebx
    movsxd rdx, edx
    shl rdx, 2
    add rdx, r12
    movzx r14d, byte [rdx]
    add esi, r14d
    movzx r14d, byte [rdx + 1]
    add edi, r14d
    movzx r14d, byte [rdx + 2]
    add eax, r14d
    movzx r14d, byte [rdx + 3]
    add ecx, r14d
    inc r15d
    inc r11d
    jmp .b_dx
.b_dny:
    inc r10d
    jmp .b_dy
.b_avg:
    xor r11d, r11d
    test r15d, r15d
    jz .b_st
    push rcx
    push rax
    push rdi
    push rsi
    mov r14d, r15d
    mov eax, dword [rsp]
    xor edx, edx
    div r14d
    mov r11d, eax
    mov eax, dword [rsp + 8]
    xor edx, edx
    div r14d
    shl eax, 8
    or r11d, eax
    mov eax, dword [rsp + 16]
    xor edx, edx
    div r14d
    shl eax, 16
    or r11d, eax
    mov eax, dword [rsp + 24]
    xor edx, edx
    div r14d
    shl eax, 24
    or r11d, eax
    add rsp, 32
.b_st:
    mov eax, dword [rsp + 48]
    imul eax, dword [rsp + 32]
    add eax, dword [rsp + 44]
    cdqe
    shl rax, 2
    add rax, r13
    mov dword [rax], r11d
    inc r9d
    jmp .b_x
.b_ny:
    inc r8d
    jmp .b_y

.write_back:
    mov rbx, qword [rsp + 0]
    xor r8d, r8d
.wy:
    cmp r8d, dword [rsp + 36]
    jae .free_dst
    xor r9d, r9d
.wx:
    cmp r9d, dword [rsp + 32]
    jae .wny
    mov eax, dword [rsp + 24]
    add eax, r9d
    mov edx, dword [rsp + 28]
    add edx, r8d
    test eax, eax
    js .wn
    test edx, edx
    js .wn
    cmp eax, dword [rbx + CV_WIDTH_OFF]
    jge .wn
    cmp edx, dword [rbx + CV_HEIGHT_OFF]
    jge .wn
    mov ecx, r8d
    imul ecx, dword [rsp + 32]
    add ecx, r9d
    movsxd rcx, ecx
    shl rcx, 2
    mov r11d, dword [r13 + rcx]
    mov r10, [rbx + CV_BUFFER_OFF]
    imul edx, dword [rbx + CV_STRIDE_OFF]
    movsxd rax, eax
    add rdx, r10
    mov dword [rdx + rax*4], r11d
.wn:
    inc r9d
    jmp .wx
.wny:
    inc r8d
    jmp .wy

.free_dst:
    mov rdi, qword [rsp + 16]
    movsxd rsi, dword [rsp + 52]
    call hal_munmap
.free_src:
    cmp qword [rsp + 56], 0
    jne .ok
    mov rdi, qword [rsp + 8]
    movsxd rsi, dword [rsp + 52]
    call hal_munmap
    jmp .ok
.fail:
    mov rax, -1
    jmp .out
.ok:
    xor eax, eax
.out:
    add rsp, 64
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret