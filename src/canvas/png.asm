; png.asm — PNG decode: chunks, zlib DEFLATE inflate, unfilter, ARGB32
; x86_64 Linux NASM. DEFLATE bit order: LSB first within bytes (RFC 1951).

%include "src/hal/platform_defs.inc"

extern hal_open
extern hal_close
extern hal_read
extern hal_mmap
extern hal_munmap
extern arena_init
extern arena_alloc
extern arena_destroy

%define IMG_WIDTH_OFF           0
%define IMG_HEIGHT_OFF          4
%define IMG_PIXELS_OFF          8
%define IMG_STRIDE_OFF          16
%define IMG_META_SIZE           32              ; 8 size + 24 struct/pad before pixels
%define PNG_MAX_FILE            (32 * 1024 * 1024)
%define PNG_ARENA_SIZE          PNG_MAX_FILE
%define TREE_MAX_NODES          4096

%define BC_PTR                  0
%define BC_END                  8
%define BC_BUF                  16
%define BC_NBIT                 24

%define ARENA_BASE_PTR_OFF      0
%define ARENA_SIZE_OFF          8
%define ARENA_OFFSET_OFF        16

%define CHUNK_IHDR              0x49484452
%define CHUNK_IDAT              0x49444154
%define CHUNK_IEND              0x49454E44
%define CHUNK_PLTE              0x504C5445

section .rodata
    png_sig                 db 0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A
    cl_order:
        db 16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15

    len_base:
        dd 3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258
    len_xtr:
        db 0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0

    dist_base:
        dd 1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577
    dist_xtr:
        db 0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13

section .bss
    bit_st                  resb 32
    tree_l                  resw TREE_MAX_NODES
    tree_r                  resw TREE_MAX_NODES
    tree_free               resd 1

    lens_lit                resb 320
    lens_dist               resb 64
    lens_cl                 resb 32

    bl_cnt                  resd 16
    next_code               resd 16
    huff_walk_root          resd 1
    dist_huff_root          resd 1
    dyn_lens                resb 320
    png_path_tmp            resb 4096
    png_dec_ct              resb 1
    png_uf_filt             resb 1

section .text
global png_load
global png_load_mem
global png_destroy
global deflate_inflate

; =============================================================================
; Bit reader
; =============================================================================
bits_init:
    mov qword [rel bit_st + BC_PTR], rdi
    lea rax, [rdi + rsi]
    mov qword [rel bit_st + BC_END], rax
    mov qword [rel bit_st + BC_BUF], 0
    mov dword [rel bit_st + BC_NBIT], 0
    ret

bits_fill:
    push rbx
    mov ebx, ecx
.more:
    mov ecx, dword [rel bit_st + BC_NBIT]
    cmp ecx, ebx
    jae .done
    mov rax, qword [rel bit_st + BC_PTR]
    cmp rax, qword [rel bit_st + BC_END]
    jae .done
    movzx r8d, byte [rax]
    inc qword [rel bit_st + BC_PTR]
    mov r9, qword [rel bit_st + BC_BUF]
    mov ecx, dword [rel bit_st + BC_NBIT]
    shl r8, cl
    or r9, r8
    add ecx, 8
    mov qword [rel bit_st + BC_BUF], r9
    mov dword [rel bit_st + BC_NBIT], ecx
    jmp .more
.done:
    pop rbx
    ret

; bits_read(n) ecx=n -> eax
bits_read:
    push rbx
    push r12
    mov r12d, ecx
    mov ecx, r12d
    call bits_fill
    mov rax, qword [rel bit_st + BC_BUF]
    mov ecx, r12d
    mov r8d, 1
    shl r8d, cl
    dec r8d
    and eax, r8d
    mov ecx, r12d
    shr qword [rel bit_st + BC_BUF], cl
    sub dword [rel bit_st + BC_NBIT], r12d
    pop r12
    pop rbx
    ret

bits_align_byte:
    mov ecx, dword [rel bit_st + BC_NBIT]
    and ecx, 7
    jz .done
    call bits_read
.done:
    ret

; =============================================================================
; Huffman trie (MSB-first walk matches successive bits_read(1))
; =============================================================================
huff_reset:
    mov dword [rel tree_free], 2
    mov word [rel tree_l + 2], 0
    mov word [rel tree_r + 2], 0
    mov dword [rel huff_walk_root], 1
    ret

; Allocate new trie root (empty node), set as huff_walk_root
huff_new_root:
    mov eax, dword [rel tree_free]
    cmp eax, TREE_MAX_NODES - 1
    jae .bad
    mov ecx, eax
    inc dword [rel tree_free]
    mov word [rel tree_l + rcx*2], 0
    mov word [rel tree_r + rcx*2], 0
    mov dword [rel huff_walk_root], ecx
    xor eax, eax
    ret
.bad:
    mov eax, -1
    ret

; huff_insert(sym, code, len) edi esi edx
huff_insert:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov r15d, dword [rel huff_walk_root]
    xor ebx, ebx
.walk:
    cmp ebx, r14d
    jae .leaf
    mov ecx, r14d
    dec ecx
    sub ecx, ebx
    mov eax, r13d
    shr eax, cl
    and eax, 1
    test eax, eax
    jnz .right

.left:
    movzx eax, word [rel tree_l + r15*2]
    test eax, eax
    jnz .L1
    mov eax, dword [rel tree_free]
    cmp eax, TREE_MAX_NODES
    jae .bad
    mov ecx, eax
    inc dword [rel tree_free]
    mov word [rel tree_l + r15*2], cx
    mov word [rel tree_l + rcx*2], 0
    mov word [rel tree_r + rcx*2], 0
    mov r15d, ecx
    inc ebx
    jmp .walk
.L1:
    mov r15d, eax
    inc ebx
    jmp .walk

.right:
    movzx eax, word [rel tree_r + r15*2]
    test eax, eax
    jnz .R1
    mov eax, dword [rel tree_free]
    cmp eax, TREE_MAX_NODES
    jae .bad
    mov ecx, eax
    inc dword [rel tree_free]
    mov word [rel tree_r + r15*2], cx
    mov word [rel tree_l + rcx*2], 0
    mov word [rel tree_r + rcx*2], 0
    mov r15d, ecx
    inc ebx
    jmp .walk
.R1:
    mov r15d, eax
    inc ebx
    jmp .walk

.leaf:
    movzx eax, word [rel tree_l + r15*2]
    movzx ecx, word [rel tree_r + r15*2]
    or eax, ecx
    jnz .bad
    mov ax, r12w
    mov word [rel tree_l + r15*2], ax
    mov word [rel tree_r + r15*2], 0xFFFF
    xor eax, eax
    jmp .out
.bad:
    mov eax, -1
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; huff_count_assign(rdi=lens*, esi=n_sym) — counts + inserts; no huff_reset
huff_count_assign:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r14, rdi
    mov r15d, esi

    xor eax, eax
    lea rdi, [rel bl_cnt]
    mov ecx, 16
    rep stosd

    xor ebx, ebx
.cnt:
    cmp ebx, r15d
    jae .nc_done
    movzx eax, byte [r14 + rbx]
    cmp eax, 15
    ja .hb_fail
    inc dword [rel bl_cnt + rax*4]
    inc rbx
    jmp .cnt
.nc_done:
    mov dword [rel bl_cnt], 0

    xor r12d, r12d               ; code carry
    mov r13d, 1                  ; bits
.nc2:
    cmp r13d, 15
    ja .assign
    mov ecx, r13d
    dec ecx
    mov eax, dword [rel bl_cnt + rcx*4]
    add eax, r12d
    shl eax, 1
    mov r12d, eax
    mov ecx, r13d
    mov dword [rel next_code + rcx*4], r12d
    inc r13d
    jmp .nc2

.assign:
    xor ebx, ebx
.as2:
    cmp ebx, r15d
    jae .ok
    movzx eax, byte [r14 + rbx]
    test eax, eax
    jz .as_next
    mov ecx, eax
    mov r8d, dword [rel next_code + rcx*4]
    mov edi, ebx
    mov esi, r8d
    mov edx, eax
    call huff_insert
    test eax, eax
    js .hb_fail
    movzx ecx, byte [r14 + rbx]
    inc dword [rel next_code + rcx*4]
.as_next:
    inc rbx
    jmp .as2
.ok:
    xor eax, eax
    jmp .hb_out
.hb_fail:
    mov eax, -1
.hb_out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; huff_build(rdi, esi) — reset + count_assign at root 1
huff_build:
    call huff_reset
    jmp huff_count_assign

; huff_decode() — literal/length tree at root 1
huff_decode:
    push rbx
    mov ebx, 1
.loop:
    cmp word [rel tree_r + rbx*2], 0xFFFF
    je .leaf
    mov ecx, 1
    call bits_read
    test eax, eax
    jz .left
    movzx ebx, word [rel tree_r + rbx*2]
    jmp .chk
.left:
    movzx ebx, word [rel tree_l + rbx*2]
.chk:
    test ebx, ebx
    jz .bad
    jmp .loop
.leaf:
    movzx eax, word [rel tree_l + rbx*2]
    jmp .out
.bad:
    mov eax, -1
.out:
    pop rbx
    ret

; huff_decode_at(root_index) ebx=root
huff_decode_at:
    push r12
    mov r12d, ebx
    mov ebx, r12d
.loop:
    cmp word [rel tree_r + rbx*2], 0xFFFF
    je .leaf
    mov ecx, 1
    call bits_read
    test eax, eax
    jz .left
    movzx ebx, word [rel tree_r + rbx*2]
    jmp .chk
.left:
    movzx ebx, word [rel tree_l + rbx*2]
.chk:
    test ebx, ebx
    jz .bad
    jmp .loop
.leaf:
    movzx eax, word [rel tree_l + rbx*2]
    jmp .out
.bad:
    mov eax, -1
.out:
    pop r12
    ret

huff_decode_dist:
    push rbx
    mov ebx, dword [rel dist_huff_root]
.loop_d:
    cmp word [rel tree_r + rbx*2], 0xFFFF
    je .leaf_d
    mov ecx, 1
    call bits_read
    test eax, eax
    jz .left_d
    movzx ebx, word [rel tree_r + rbx*2]
    jmp .chk_d
.left_d:
    movzx ebx, word [rel tree_l + rbx*2]
.chk_d:
    test ebx, ebx
    jz .bad_d
    jmp .loop_d
.leaf_d:
    movzx eax, word [rel tree_l + rbx*2]
    jmp .out_d
.bad_d:
    mov eax, -1
.out_d:
    pop rbx
    ret

; =============================================================================
; Fixed Huffman tables -> lens_lit / lens_dist
; =============================================================================
fill_fixed_litdist:
    push rbx
    xor ebx, ebx
.l8a:
    cmp ebx, 144
    jae .l8b
    mov byte [rel lens_lit + rbx], 8
    inc ebx
    jmp .l8a
.l8b:
    cmp ebx, 256
    jae .l7
    mov byte [rel lens_lit + rbx], 9
    inc ebx
    jmp .l8b
.l7:
    cmp ebx, 280
    jae .l8c
    mov byte [rel lens_lit + rbx], 7
    inc ebx
    jmp .l7
.l8c:
    cmp ebx, 288
    jae .dist
    mov byte [rel lens_lit + rbx], 8
    inc ebx
    jmp .l8c
.dist:
    xor ebx, ebx
.d5:
    cmp ebx, 32
    jae .done
    mov byte [rel lens_dist + rbx], 5
    inc ebx
    jmp .d5
.done:
    pop rbx
    ret

; =============================================================================
; inflate stored block (out ptr in r12, end in r13, updates r12)
; Returns eax 0 / -1
; =============================================================================
inflate_stored:
    push rbx
    push r14
    push r15
    call bits_align_byte
    mov rax, qword [rel bit_st + BC_PTR]
    mov r15, qword [rel bit_st + BC_END]
    lea rcx, [rax + 4]
    cmp rcx, r15
    ja .bad
    movzx edx, byte [rax]
    movzx ecx, byte [rax + 1]
    shl ecx, 8
    or edx, ecx
    movzx ecx, byte [rax + 2]
    movzx r8d, byte [rax + 3]
    shl r8d, 8
    or ecx, r8d
    mov r14d, edx                 ; LEN
    mov ebx, ecx                  ; NLEN
    add ebx, r14d
    cmp ebx, 0xFFFF
    jne .bad
    lea rax, [rax + 4]
    mov rbx, rax
    add rbx, r14
    cmp rbx, r15
    ja .bad
    xor ecx, ecx
.copy:
    cmp ecx, r14d
    jae .finish
    movzx edx, byte [rax + rcx]
    mov byte [r12], dl
    inc r12
    inc ecx
    jmp .copy
.finish:
    mov qword [rel bit_st + BC_PTR], rbx
    mov qword [rel bit_st + BC_BUF], 0
    mov dword [rel bit_st + BC_NBIT], 0
    xor eax, eax
    jmp .out
.bad:
    mov eax, -1
.out:
    pop r15
    pop r14
    pop rbx
    ret

; =============================================================================
; Build fixed Huffman tries (lit @1, dist @dist_huff_root)
; =============================================================================
setup_fixed_huff:
    call huff_reset
    call fill_fixed_litdist
    lea rdi, [rel lens_lit]
    mov esi, 288
    call huff_count_assign
    test eax, eax
    js .bad
    call huff_new_root
    test eax, eax
    js .bad
    mov eax, dword [rel huff_walk_root]
    mov dword [rel dist_huff_root], eax
    lea rdi, [rel lens_dist]
    mov esi, 32
    call huff_count_assign
    test eax, eax
    js .bad
    xor eax, eax
    ret
.bad:
    mov eax, -1
    ret

; =============================================================================
; inflate_dynamic — builds lit/dist tries
; =============================================================================
inflate_dynamic:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov ecx, 5
    call bits_read
    mov r12d, eax
    add r12d, 257                 ; HLIT+257

    mov ecx, 5
    call bits_read
    mov r13d, eax
    add r13d, 1                   ; HDIST+1

    mov ecx, 4
    call bits_read
    mov r14d, eax
    add r14d, 4                   ; HCLEN+4

    xor eax, eax
    lea rdi, [rel lens_cl]
    mov ecx, 32
    rep stosb

    xor ebx, ebx
.cloop:
    cmp ebx, r14d
    jae .cl_done
    mov ecx, 3
    call bits_read
    movzx ecx, byte [rel cl_order + rbx]
    mov byte [rel lens_cl + rcx], al
    inc ebx
    jmp .cloop
.cl_done:
    call huff_reset
    lea rdi, [rel lens_cl]
    mov esi, 19
    call huff_count_assign
    test eax, eax
    js .bad

    mov r15d, r12d
    add r15d, r13d                ; total lengths
    xor ebx, ebx
    xor r8d, r8d                  ; prev len
.dl:
    cmp ebx, r15d
    jae .split
    call huff_decode
    cmp eax, -1
    je .bad
    cmp eax, 16
    jb .sym_lt16
    cmp eax, 16
    je .rep16
    cmp eax, 17
    je .rep17
    jmp .rep18
.sym_lt16:
    mov byte [rel dyn_lens + rbx], al
    mov r8d, eax
    inc ebx
    jmp .dl
.rep16:
    mov ecx, 2
    call bits_read
    lea ecx, [rax + 3]
    xor edx, edx
.r16:
    cmp edx, ecx
    jae .dl
    mov al, r8b
    mov byte [rel dyn_lens + rbx], al
    inc ebx
    inc edx
    jmp .r16
.rep17:
    mov ecx, 3
    call bits_read
    lea ecx, [rax + 3]
    xor edx, edx
.r17:
    cmp edx, ecx
    jae .dl
    mov byte [rel dyn_lens + rbx], 0
    inc ebx
    inc edx
    jmp .r17
.rep18:
    mov ecx, 7
    call bits_read
    lea ecx, [rax + 11]
    xor edx, edx
.r18:
    cmp edx, ecx
    jae .dl
    mov byte [rel dyn_lens + rbx], 0
    inc ebx
    inc edx
    jmp .r18
.split:
    xor eax, eax
    lea rdi, [rel lens_lit]
    mov ecx, 288
    rep stosb
    lea rdi, [rel lens_dist]
    mov ecx, 32
    rep stosb

    xor ebx, ebx
.cp1:
    cmp ebx, r12d
    jae .cp2
    mov al, byte [rel dyn_lens + rbx]
    mov byte [rel lens_lit + rbx], al
    inc ebx
    jmp .cp1
.cp2:
    xor ecx, ecx
.cp3:
    cmp ecx, r13d
    jae .build
    mov al, byte [rel dyn_lens + rbx]
    mov byte [rel lens_dist + rcx], al
    inc ebx
    inc ecx
    jmp .cp3
.build:
    call huff_reset
    lea rdi, [rel lens_lit]
    mov esi, 288
    call huff_count_assign
    test eax, eax
    js .bad
    call huff_new_root
    test eax, eax
    js .bad
    mov eax, dword [rel huff_walk_root]
    mov dword [rel dist_huff_root], eax
    lea rdi, [rel lens_dist]
    mov esi, 32
    call huff_count_assign
    test eax, eax
    js .bad
    xor eax, eax
    jmp .out
.bad:
    mov eax, -1
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; =============================================================================
; deflate_inflate(deflate_ptr, deflate_len, out, out_max) -> out bytes or 0
; Pure DEFLATE stream (no zlib wrapper).
; =============================================================================
deflate_inflate:
    push rbx
    push r12
    push r13
    push r14
    push r15

    test rdi, rdi
    jz .fail
    test rsi, rsi
    jz .fail
    test rdx, rdx
    jz .fail

    call bits_init
    mov r12, rdx                  ; out cursor
    mov r14, rdx                  ; out base
    mov r13, rdx
    add r13, rcx                  ; out end

.outer:
    mov ecx, 1
    call bits_read
    mov r15d, eax                 ; bfinal

    mov ecx, 2
    call bits_read
    cmp eax, 3
    je .fail
    cmp eax, 0
    je .stored
    cmp eax, 1
    je .fixed
    jmp .dynamic

.stored:
    call inflate_stored
    test eax, eax
    js .fail
    jmp .endblk

.fixed:
    call setup_fixed_huff
    test eax, eax
    js .fail
    jmp .codes

.dynamic:
    call inflate_dynamic
    test eax, eax
    js .fail

.codes:
.inner:
    call huff_decode
    cmp eax, -1
    je .fail
    cmp eax, 256
    je .endblk
    cmp eax, 256
    jb .lit

    mov ebx, eax
    sub ebx, 257
    cmp ebx, 28
    ja .fail
    movzx ecx, byte [rel len_xtr + rbx]
    call bits_read
    mov edx, dword [rel len_base + rbx*4]
    add edx, eax
    test edx, edx
    jz .fail

    call huff_decode_dist
    cmp eax, -1
    je .fail
    cmp eax, 30
    jae .fail
    mov ebx, eax
    movzx ecx, byte [rel dist_xtr + rbx]
    call bits_read
    mov r8d, dword [rel dist_base + rbx*4]
    add r8d, eax
    test r8d, r8d
    jz .fail

    mov rcx, r12
    add rcx, rdx
    cmp rcx, r13
    ja .fail

    xor ecx, ecx
.lz:
    cmp ecx, edx
    jae .inner
    mov rax, r12
    sub rax, r8
    cmp rax, r14
    jb .fail
    movzx eax, byte [rax]
    mov byte [r12], al
    inc r12
    inc ecx
    jmp .lz

.lit:
    cmp r12, r13
    jae .fail
    mov byte [r12], al
    inc r12
    jmp .inner

.endblk:
    test r15d, r15d
    jnz .done
    jmp .outer

.done:
    mov rax, r12
    sub rax, r14
    jmp .ok
.fail:
    xor eax, eax
.ok:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; =============================================================================
; png_bpp(color_type in dil per SysV rdi) -> eax
; =============================================================================
png_bpp_from_ct:
    movzx eax, dil
    cmp al, 0
    je .g
    cmp al, 2
    je .rgb
    cmp al, 3
    je .idx
    cmp al, 4
    je .ga
    cmp al, 6
    je .rgba
    xor eax, eax
    ret
.g:
    mov eax, 1
    ret
.rgb:
    mov eax, 3
    ret
.idx:
    mov eax, 1
    ret
.ga:
    mov eax, 2
    ret
.rgba:
    mov eax, 4
    ret

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
    movzx eax, byte [rsi]
    mov byte [rel png_uf_filt], al
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

    cmp byte [rel png_uf_filt], 0
    je .st
    cmp byte [rel png_uf_filt], 1
    je .f1
    cmp byte [rel png_uf_filt], 2
    je .f2
    cmp byte [rel png_uf_filt], 3
    je .f3
    cmp byte [rel png_uf_filt], 4
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

    movzx eax, byte [rel png_dec_ct]
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

; Stack frame png_load_mem (sub rsp, 256)
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
    mov r12, rdi
    mov r13, rsi
    sub rsp, 256

    cld
    xor eax, eax
    mov rdi, rsp
    mov ecx, 256
    rep stosb

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
    mov dword [rsp + 32], eax     ; exp_raw (zlib output size)

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
    mov esi, eax                  ; actual zlib output bytes

    mov eax, dword [rsp + 44]
    bswap eax
    mov ecx, eax                  ; w
    mov eax, dword [rsp + 28]
    imul eax, ecx                 ; w*bpp
    mov ecx, eax
    mov eax, dword [rsp + 60]
    imul eax, ecx                 ; w*bpp*h
    mov ecx, eax
    mov eax, dword [rsp + 60]
    add eax, ecx                  ; h + w*bpp*h = expected raw size

    cmp esi, eax
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
    add rsp, 256
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
    add rsp, 256
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
