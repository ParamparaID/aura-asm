
; =============================================================================
; png_unfilter(raw, w, h, bpp, out)
; =============================================================================
png_unfilter:
    push rbx
    push rbp
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi
    mov r13d, esi
    mov r14d, edx
    mov r15d, ecx
    mov rbp, r8

    mov eax, r13d
    imul eax, r15d
    mov ebx, eax
    lea r8d, [rax + 1]

    xor r9d, r9d
.yloop:
    cmp r9d, r14d
    jae .udone

    mov eax, r9d
    imul eax, r8d
    cdqe
    lea rsi, [r12 + rax]
    mov bl, byte [rsi]
    lea rsi, [rsi + 1]

    mov eax, r9d
    imul eax, ebx
    cdqe
    lea rdi, [rbp + rax]

    xor r11d, r11d
.xloop:
    cmp r11d, ebx
    jae .ynext

    movzx ecx, byte [rsi + r11]

    mov eax, r11d
    cmp eax, r15d
    jl .a0
    sub eax, r15d
    movzx eax, byte [rdi + rax]
    jmp .a1
.a0:
    xor eax, eax
.a1:
    push rax

    test r9d, r9d
    jz .b0
    mov edx, r9d
    dec edx
    imul edx, ebx
    add edx, r11d
    movzx edx, byte [rbp + rdx]
    jmp .b1
.b0:
    xor edx, edx
.b1:

    xor r10d, r10d
    test r9d, r9d
    jz .c1
    cmp r11d, r15d
    jl .c1
    mov r10d, r9d
    dec r10d
    imul r10d, ebx
    add r10d, r11d
    sub r10d, r15d
    movzx r10d, byte [rbp + r10]
.c1:

    pop rax

    cmp bl, 0
    je .st
    cmp bl, 1
    je .f1
    cmp bl, 2
    je .f2
    cmp bl, 3
    je .f3
    cmp bl, 4
    je .f4
    jmp .st

.f1:
    add ecx, eax
    jmp .st
.f2:
    add ecx, edx
    jmp .st
.f3:
    push rax
    add eax, edx
    shr eax, 1
    add ecx, eax
    pop rax
    jmp .st

.f4:
    push r11
    push rcx
    push rax

    mov eax, dword [rsp]
    add eax, edx
    sub eax, r10d

    mov edi, eax
    sub edi, dword [rsp]
    mov esi, edi
    sar esi, 31
    xor edi, esi
    sub edi, esi

    mov esi, eax
    sub esi, edx
    mov r11d, esi
    sar r11d, 31
    xor esi, r11d
    sub esi, r11d

    mov r11d, eax
    sub r11d, r10d
    mov eax, r11d
    sar eax, 31
    xor r11d, eax
    sub r11d, eax

    cmp edi, esi
    ja .pbw
    cmp edi, r11d
    ja .pcw
    mov eax, dword [rsp]
    jmp .padd
.pbw:
    cmp esi, r11d
    ja .pcw2
    mov eax, edx
    jmp .padd
.pcw:
    mov eax, dword [rsp]
    jmp .padd
.pcw2:
    mov eax, r10d
.padd:
    add eax, dword [rsp + 8]
    mov ecx, eax

    pop rax
    pop rax
    pop r11
    jmp .st

.st:
    and ecx, 0xFF
    mov [rdi + r11], cl
    inc r11d
    jmp .xloop

.ynext:
    inc r9d
    jmp .yloop

.udone:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret

; =============================================================================
; png_convert_to_argb32(filtered, w, h, bpp, plte, plte_len, out)
; =============================================================================
png_convert_to_argb32:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi
    mov r13d, esi
    mov r14d, edx
    mov ebx, ecx
    mov r15, r8
    mov eax, r9d
    push rax                      ; plte_len on stack
    mov r9, r10

    xor edx, edx
.cy:
    cmp edx, r14d
    jae .cdone

    xor ecx, ecx
.cx:
    cmp ecx, r13d
    jae .cny

    mov eax, edx
    imul eax, r13d
    add eax, ecx
    imul eax, ebx
    cdqe
    lea rsi, [r12 + rax]

    movzx al, byte [rel png_dec_ct]
    cmp al, 0
    je .ct0
    cmp al, 2
    je .ct2
    cmp al, 3
    je .ct3
    cmp al, 4
    je .ct4
    cmp al, 6
    je .ct6
    xor edi, edi
    jmp .cw

.ct0:
    movzx edi, byte [rsi]
    mov eax, edi
    shl eax, 8
    or edi, eax
    mov eax, edi
    shl eax, 8
    or edi, eax
    or edi, 0xFF000000
    jmp .cw

.ct2:
    movzx eax, byte [rsi]
    shl eax, 16
    movzx edi, byte [rsi + 1]
    shl edi, 8
    or eax, edi
    movzx edi, byte [rsi + 2]
    or eax, edi
    or eax, 0xFF000000
    mov edi, eax
    jmp .cw

.ct3:
    movzx eax, byte [rsi]
    imul eax, 3
    cmp eax, dword [rsp]
    jae .czero
    mov r10d, eax
    movzx eax, byte [r15 + r10]
    shl eax, 16
    movzx edi, byte [r15 + r10 + 1]
    shl edi, 8
    or eax, edi
    movzx edi, byte [r15 + r10 + 2]
    or eax, edi
    or eax, 0xFF000000
    mov edi, eax
    jmp .cw
.czero:
    xor edi, edi
    jmp .cw

.ct4:
    movzx edi, byte [rsi]
    mov eax, edi
    shl eax, 8
    or edi, eax
    mov eax, edi
    shl eax, 8
    or edi, eax
    movzx eax, byte [rsi + 1]
    shl eax, 24
    or edi, eax
    jmp .cw

.ct6:
    movzx eax, byte [rsi + 3]
    shl eax, 24
    movzx edi, byte [rsi]
    shl edi, 16
    or eax, edi
    movzx edi, byte [rsi + 1]
    shl edi, 8
    or eax, edi
    movzx edi, byte [rsi + 2]
    or eax, edi
    mov edi, eax

.cw:
    mov eax, edx
    imul eax, r13d
    add eax, ecx
    shl eax, 2
    cdqe
    mov dword [r9 + rax], edi

    inc ecx
    jmp .cx
.cny:
    inc edx
    jmp .cy

.cdone:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; =============================================================================
; png_destroy
; =============================================================================
png_destroy:
    test rdi, rdi
    jz .pd0
    mov rsi, qword [rdi - 8]
    lea rdi, [rdi - 8]
    call hal_munmap
.pd0:
    ret

%define SYS_LSEEK 8

png_lseek:
    mov rax, SYS_LSEEK
    syscall
    ret

; =============================================================================
; png_load(path, path_len)
; =============================================================================
png_load:
    push rbx
    push r12
    push r13
    push r14
    push r15

    test rdi, rdi
    jz .lfail
    mov rbx, rdi
    mov r12d, esi

    cmp r12d, 4095
    ja .lfail

    xor ecx, ecx
.cp:
    cmp ecx, r12d
    jae .cz
    mov al, byte [rbx + rcx]
    mov byte [rel png_path_tmp + rcx], al
    inc ecx
    jmp .cp
.cz:
    mov byte [rel png_path_tmp + rcx], 0

    lea rdi, [rel png_path_tmp]
    mov rsi, O_RDONLY
    xor rdx, rdx
    call hal_open
    test rax, rax
    js .lfail
    mov r13, rax

    mov rdi, r13
    xor rsi, rsi
    mov rdx, 2
    call png_lseek
    cmp rax, 0
    jle .lclose
    mov r14, rax

    mov rdi, r13
    xor rsi, rsi
    xor rdx, rdx
    call png_lseek

    xor rdi, rdi
    mov rsi, r14
    mov rdx, PROT_READ
    mov rcx, MAP_PRIVATE
    mov r8, r13
    xor r9, r9
    call hal_mmap
    test rax, rax
    js .lclose
    mov r15, rax

    mov rdi, r13
    call hal_close

    mov rdi, r15
    mov rsi, r14
    call png_load_mem
    mov rbx, rax

    mov rdi, r15
    mov rsi, r14
    call hal_munmap

    mov rax, rbx
    jmp .lout
.lclose:
    mov rdi, r13
    call hal_close
.lfail:
    xor eax, eax
.lout:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; Stack frame png_load_mem (sub rsp, 80)
; +0 raw q, +8 filt q, +16 plte q
; +24 idat_total dword, +28 bpp, +32 exp_raw, +36 ihdr_ok, +40 plte_len
; +44 ihdr 16 bytes (use 13), +60 hdword

; =============================================================================
; png_load_mem(buf, len)
; =============================================================================
png_load_mem:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp
    sub rsp, 80

    mov r12, rdi
    mov r13, rsi

    cmp r13, 33
    jb .mfail0

    lea rsi, [rel png_sig]
    lea rdi, [r12]
    mov ecx, 8
    repe cmpsb
    jne .mfail0

    mov rdi, PNG_ARENA_SIZE
    call arena_init
    test rax, rax
    jz .mfail0
    mov rbp, rax

    xor r14d, r14d
    mov r8, 8
.sum:
    lea rax, [r8 + 12]
    cmp rax, r13
    ja .mfail1
    mov eax, dword [r12 + r8]
    bswap eax
    mov ebx, eax
    lea rax, [r8 + 12]
    add rax, rbx
    cmp rax, r13
    ja .mfail1
    mov eax, dword [r12 + r8 + 4]
    bswap eax
    cmp eax, CHUNK_IDAT
    jne .sum_adv
    add r14d, ebx
.sum_adv:
    cmp eax, CHUNK_IEND
    je .sum_done
    lea r8, [r8 + rbx + 12]
    cmp r8, r13
    jb .sum
.sum_done:
    test r14d, r14d
    jz .mfail1
    mov dword [rsp + 24], r14d

    mov rdi, rbp
    mov rsi, r14
    call arena_alloc
    test rax, rax
    jz .mfail1
    mov r15, rax                  ; idat dst

    mov dword [rsp + 36], 0
    mov dword [rsp + 40], 0
    mov qword [rsp + 16], 0

    xor r9d, r9d
    mov r8, 8
.pass2:
    lea rax, [r8 + 12]
    cmp rax, r13
    ja .mfail1
    mov eax, dword [r12 + r8]
    bswap eax
    mov ebx, eax
    lea rax, [r8 + 12]
    add rax, rbx
    cmp rax, r13
    ja .mfail1
    mov eax, dword [r12 + r8 + 4]
    bswap eax

    cmp eax, CHUNK_IHDR
    je .p2_ihdr
    cmp eax, CHUNK_PLTE
    je .p2_plte
    cmp eax, CHUNK_IDAT
    je .p2_idat
    cmp eax, CHUNK_IEND
    je .p2_done
.p2_next:
    lea r8, [r8 + rbx + 12]
    cmp r8, r13
    jb .pass2
    jmp .p2_done

.p2_ihdr:
    cmp ebx, 13
    jne .mfail1
    lea rsi, [r12 + r8 + 8]
    lea rdi, [rsp + 44]
    mov ecx, 13
    rep movsb
    mov dword [rsp + 36], 1
    jmp .p2_next

.p2_plte:
    cmp ebx, 768
    ja .mfail1
    mov eax, ebx
    xor edx, edx
    mov ecx, 3
    div ecx
    test edx, edx
    jnz .mfail1
    mov rdi, rbp
    mov rsi, rbx
    call arena_alloc
    test rax, rax
    jz .mfail1
    mov qword [rsp + 16], rax
    mov dword [rsp + 40], ebx
    lea rsi, [r12 + r8 + 8]
    mov rdi, rax
    mov rcx, rbx
    rep movsb
    jmp .p2_next

.p2_idat:
    lea rsi, [r12 + r8 + 8]
    mov rdi, r15
    add rdi, r9
    mov rcx, rbx
    rep movsb
    add r9, rbx
    jmp .p2_next

.p2_done:
    cmp dword [rsp + 36], 1
    jne .mfail1
    cmp r9d, dword [rsp + 24]
    jne .mfail1

    mov eax, dword [rsp + 44]
    bswap eax
    mov ebx, eax                  ; w

    mov eax, dword [rsp + 48]
    bswap eax
    mov dword [rsp + 60], eax     ; h

    test ebx, ebx
    jz .mfail1
    cmp dword [rsp + 60], 0
    je .mfail1

    movzx eax, byte [rsp + 52]
    cmp eax, 8
    jne .mfail1

    movzx eax, byte [rsp + 53]
    mov byte [rel png_dec_ct], al

    movzx eax, byte [rsp + 54]
    test eax, eax
    jnz .mfail1
    movzx eax, byte [rsp + 55]
    test eax, eax
    jnz .mfail1
    movzx eax, byte [rsp + 56]
    test eax, eax
    jnz .mfail1

    cmp byte [rel png_dec_ct], 3
    jne .plte_ok
    cmp dword [rsp + 40], 0
    je .mfail1
.plte_ok:

    movzx edi, byte [rel png_dec_ct]
    call png_bpp_from_ct
    test eax, eax
    jz .mfail1
    mov dword [rsp + 28], eax

    mov eax, ebx
    imul eax, dword [rsp + 28]
    jo .mfail1
    mov r10d, eax                 ; w*bpp
    mov eax, dword [rsp + 60]
    imul eax, r10d
    jo .mfail1
    mov r10d, eax                 ; w*bpp*h

    mov eax, dword [rsp + 60]
    add eax, r10d
    jc .mfail1
    mov dword [rsp + 32], eax     ; exp_raw

    mov rdi, rbp
    mov rsi, rax
    call arena_alloc
    test rax, rax
    jz .mfail1
    mov qword [rsp], rax

    mov eax, dword [rsp + 24]
    cmp eax, 2
    jb .mfail1
    lea rdi, [r15 + 2]
    mov esi, eax
    sub esi, 2
    mov rdx, qword [rsp]
    mov ecx, dword [rsp + 32]
    call deflate_inflate
    cmp eax, dword [rsp + 32]
    jne .mfail1

    mov eax, ebx
    imul eax, dword [rsp + 28]
    imul eax, dword [rsp + 60]
    jo .mfail1
    mov r10d, eax                 ; filt bytes

    mov rdi, rbp
    mov rsi, rax
    call arena_alloc
    test rax, rax
    jz .mfail1
    mov qword [rsp + 8], rax

    mov rdi, qword [rsp]
    mov esi, ebx
    mov edx, dword [rsp + 60]
    mov ecx, dword [rsp + 28]
    mov r8, qword [rsp + 8]
    call png_unfilter

    mov eax, ebx
    imul eax, dword [rsp + 60]
    jo .mfail1
    imul eax, 4
    jo .mfail1
    mov r10d, eax

    mov rax, r10
    add rax, IMG_META_SIZE
    jc .mfail1
    add rax, 4095
    and rax, -4096
    mov r14, rax

    xor rdi, rdi
    mov rsi, r14
    mov rdx, PROT_READ | PROT_WRITE
    mov rcx, MAP_PRIVATE | MAP_ANONYMOUS
    mov r8, -1
    xor r9, r9
    call hal_mmap
    test rax, rax
    js .mfail1
    mov r15, rax

    mov qword [r15], r14

    lea r11, [r15 + 8]
    mov [r11 + IMG_WIDTH_OFF], ebx
    mov eax, dword [rsp + 60]
    mov [r11 + IMG_HEIGHT_OFF], eax
    lea rcx, [r15 + IMG_META_SIZE]
    mov [r11 + IMG_PIXELS_OFF], rcx
    mov ecx, ebx
    shl ecx, 2
    mov [r11 + IMG_STRIDE_OFF], ecx

    mov rdi, qword [rsp + 8]
    mov esi, ebx
    mov edx, dword [rsp + 60]
    mov ecx, dword [rsp + 28]
    mov r8, qword [rsp + 16]
    mov r9d, dword [rsp + 40]
    mov r10, qword [r11 + IMG_PIXELS_OFF]
    call png_convert_to_argb32

    mov rdi, rbp
    call arena_destroy

    lea rax, [r15 + 8]
    add rsp, 80
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

.mfail1:
    mov rdi, rbp
    test rdi, rdi
    jz .mfail0
    call arena_destroy
.mfail0:
    xor eax, eax
    add rsp, 80
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
