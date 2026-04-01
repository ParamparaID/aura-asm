; archive.asm — tar/tar.gz/zip helpers for FM/VFS
%include "src/hal/platform_defs.inc"
%include "src/fm/vfs.inc"

extern hal_open
extern hal_close
extern hal_read
extern hal_write
extern hal_lseek
extern hal_stat
extern hal_mkdir
extern hal_mmap
extern hal_munmap
extern deflate_inflate

%define SEEK_SET                    0
%define SEEK_CUR                    1
%define SEEK_END                    2

%define TAR_BLOCK                   512
%define ARCHIVE_MAX_MM              (32 * 1024 * 1024)

section .bss
    archive_io_buf                  resb 8192
    archive_hdr_buf                 resb 512
    archive_zero_block              resb 512
    archive_gzip_buf                resb ARCHIVE_MAX_MM
    targz_last_size                 resq 1
    zip_tmp_names                   resb 64 * 256
    zip_tmp_name_lens               resw 64
    zip_tmp_offsets                 resd 64
    zip_tmp_sizes                   resd 64
    zip_tmp_cur_off                 resd 1
    zip_tmp_cdir_off                resd 1

section .text
global parse_octal
global tar_find_entry
global tar_list
global tar_extract
global tar_extract_all
global tar_create
global targz_open
global targz_last_size_get
global zip_list
global zip_extract
global zip_create

parse_octal:
    ; (str rdi, len esi) -> rax
    xor rax, rax
    xor ecx, ecx
.loop:
    cmp ecx, esi
    jae .out
    mov dl, [rdi + rcx]
    test dl, dl
    je .out
    cmp dl, ' '
    je .n
    cmp dl, '0'
    jb .n
    cmp dl, '7'
    ja .n
    shl rax, 3
    sub dl, '0'
    movzx rdx, dl
    add rax, rdx
.n:
    inc ecx
    jmp .loop
.out:
    ret

tar_name_copy:
    ; (hdr rdi, out rsi) -> eax len
    xor ecx, ecx
.base:
    cmp ecx, 100
    jae .base_done
    mov al, [rdi + rcx]
    test al, al
    je .base_done
    mov [rsi + rcx], al
    inc ecx
    jmp .base
.base_done:
    mov eax, ecx
    ret

tar_fill_direntry:
    ; (hdr rdi, de rsi)
    push rbx
    push r12
    mov rbx, rdi
    mov r12, rsi
    lea rdi, [rbx + 124]
    mov esi, 12
    call parse_octal
    mov [r12 + DE_SIZE_OFF], rax
    lea rdi, [rbx + 136]
    mov esi, 12
    call parse_octal
    mov [r12 + DE_MTIME_OFF], rax
    mov al, [rbx + 156]
    cmp al, '5'
    je .dir
    cmp al, '2'
    je .lnk
    mov dword [r12 + DE_TYPE_OFF], DT_REG
    jmp .name
.dir:
    mov dword [r12 + DE_TYPE_OFF], DT_DIR
    jmp .name
.lnk:
    mov dword [r12 + DE_TYPE_OFF], DT_LNK
.name:
    lea rdi, [rbx]
    lea rdx, [r12 + DE_NAME_OFF]
    mov rsi, rdx
    call tar_name_copy
    mov [r12 + DE_NAME_LEN_OFF], eax
    mov dword [r12 + DE_MODE_OFF], 0
    mov dword [r12 + DE_UID_OFF], 0
    mov dword [r12 + DE_GID_OFF], 0
    mov dword [r12 + DE_HIDDEN_OFF], 0
    pop r12
    pop rbx
    ret

tar_is_zero_block:
    ; (ptr rdi) -> eax 1/0
    xor ecx, ecx
.loop:
    cmp ecx, TAR_BLOCK
    jae .yes
    cmp byte [rdi + rcx], 0
    jne .no
    inc ecx
    jmp .loop
.yes:
    mov eax, 1
    ret
.no:
    xor eax, eax
    ret

tar_list:
    ; (file_data rdi, file_size rsi, entries_out rdx, max_entries ecx) -> eax count
    push rbx
    push rbp
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r14d, ecx
    xor r15d, r15d                   ; count
    xor rbp, rbp                     ; off
.loop:
    mov rax, rbp
    add rax, TAR_BLOCK
    cmp rax, r12
    ja .done
    lea rdi, [rbx + rbp]
    call tar_is_zero_block
    test eax, eax
    jnz .done
    cmp r15d, r14d
    jae .skip
    mov eax, r15d
    imul eax, DIR_ENTRY_SIZE
    lea rsi, [r13 + rax]
    lea rdi, [rbx + rbp]
    call tar_fill_direntry
    inc r15d
.skip:
    lea rdi, [rbx + rbp + 124]
    mov esi, 12
    call parse_octal
    ; align to 512
    mov rdx, rax
    add rdx, 511
    and rdx, -512
    add rbp, TAR_BLOCK
    add rbp, rdx
    jmp .loop
.done:
    mov eax, r15d
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret

strn_eq:
    ; (a rdi, b rsi, len edx) -> eax 1/0
    xor ecx, ecx
.l:
    cmp ecx, edx
    jae .yes
    mov al, [rdi + rcx]
    cmp al, [rsi + rcx]
    jne .no
    inc ecx
    jmp .l
.yes:
    mov eax, 1
    ret
.no:
    xor eax, eax
    ret

tar_find_entry:
    ; (data rdi, size rsi, name rdx, name_len ecx) -> rax hdr_ptr or 0
    push rbx
    mov rbx, rdi
    xor r8, r8
.loop:
    mov rax, r8
    add rax, TAR_BLOCK
    cmp rax, rsi
    ja .none
    lea rdi, [rbx + r8]
    call tar_is_zero_block
    test eax, eax
    jnz .none
    ; compare name
    lea rdi, [rbx + r8 + 0]
    mov rsi, rdx
    mov edx, ecx
    call strn_eq
    test eax, eax
    jnz .hit
    lea rdi, [rbx + r8 + 124]
    mov esi, 12
    call parse_octal
    mov r9, rax
    add r9, 511
    and r9, -512
    add r8, TAR_BLOCK
    add r8, r9
    jmp .loop
.hit:
    lea rax, [rbx + r8]
    pop rbx
    ret
.none:
    xor eax, eax
    pop rbx
    ret

tar_extract:
    ; (data rdi,size rsi,name rdx,name_len ecx,dst r8,dst_len r9d) -> eax 0/-1
    push rbx
    push r12
    push r13
    mov r12, r8
    mov rdi, rdi
    call tar_find_entry
    test rax, rax
    jz .fail
    mov rbx, rax
    lea rdi, [rbx + 124]
    mov esi, 12
    call parse_octal
    mov r13, rax
    mov rdi, r12
    mov esi, O_WRONLY | O_CREAT | O_TRUNC
    mov edx, 0644o
    call hal_open
    test rax, rax
    js .fail
    mov ebp, eax
    movsx rdi, ebp
    lea rsi, [rbx + TAR_BLOCK]
    mov rdx, r13
    call hal_write
    movsx rdi, ebp
    call hal_close
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

mkpath_simple:
    ; (path rdi) -> create parent dirs best-effort, eax 0
    push rbx
    mov rbx, rdi
    xor ecx, ecx
.l:
    cmp byte [rbx + rcx], 0
    je .out
    cmp byte [rbx + rcx], '/'
    jne .n
    cmp ecx, 0
    je .n
    mov byte [rbx + rcx], 0
    mov rdi, rbx
    mov esi, 0755o
    call hal_mkdir
    mov byte [rbx + rcx], '/'
.n:
    inc ecx
    jmp .l
.out:
    xor eax, eax
    pop rbx
    ret

tar_extract_all:
    ; (data rdi,size rsi,dest rdx,dest_len ecx,progress r8) -> eax extracted_count
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    xor r14d, r14d
    xor r9, r9
.loop:
    mov rax, r9
    add rax, TAR_BLOCK
    cmp rax, r12
    ja .done
    lea rdi, [rbx + r9]
    call tar_is_zero_block
    test eax, eax
    jnz .done
    ; build output path
    lea rdi, [archive_io_buf]
    mov rsi, r13
    xor ecx, ecx
.cp0:
    mov al, [rsi + rcx]
    mov [rdi + rcx], al
    test al, al
    je .join
    inc ecx
    jmp .cp0
.join:
    cmp ecx, 0
    je .name
    cmp byte [rdi + rcx - 1], '/'
    je .name
    mov byte [rdi + rcx], '/'
    inc ecx
.name:
    xor edx, edx
.cpn:
    cmp edx, 100
    jae .term
    mov r10, r9
    add r10, rdx
    mov al, [rbx + r10]
    test al, al
    je .term
    mov [rdi + rcx], al
    inc ecx
    inc edx
    jmp .cpn
.term:
    mov byte [rdi + rcx], 0
    lea rdi, [archive_io_buf]
    call mkpath_simple
    mov al, [rbx + r9 + 156]
    cmp al, '5'
    je .mkdir_only
    mov rdi, archive_io_buf
    mov esi, O_WRONLY | O_CREAT | O_TRUNC
    mov edx, 0644o
    call hal_open
    test rax, rax
    js .advance
    mov ebp, eax
    lea rdi, [rbx + r9 + 124]
    mov esi, 12
    call parse_octal
    mov r10, rax
    movsx rdi, ebp
    lea rsi, [rbx + r9 + TAR_BLOCK]
    mov rdx, r10
    call hal_write
    movsx rdi, ebp
    call hal_close
    inc r14d
    jmp .advance
.mkdir_only:
    lea rdi, [archive_io_buf]
    mov esi, 0755o
    call hal_mkdir
.advance:
    lea rdi, [rbx + r9 + 124]
    mov esi, 12
    call parse_octal
    mov rdx, rax
    add rdx, 511
    and rdx, -512
    add r9, TAR_BLOCK
    add r9, rdx
    jmp .loop
.done:
    mov eax, r14d
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

write_octal_field:
    ; (value rdi, dst rsi, width edx)
    ; writes right-aligned octal with trailing NUL
    push rbx
    mov ebx, edx
    xor ecx, ecx
.sp:
    cmp ecx, ebx
    jae .conv
    mov byte [rsi + rcx], '0'
    inc ecx
    jmp .sp
.conv:
    dec ebx
    mov byte [rsi + rbx], 0
    dec ebx
    mov rax, rdi
.digits:
    cmp ebx, 0
    jl .out
    mov rdx, rax
    and rdx, 7
    add dl, '0'
    mov [rsi + rbx], dl
    shr rax, 3
    dec ebx
    test rax, rax
    jnz .digits
.out:
    pop rbx
    ret

basename_ptr:
    ; (path rdi) -> rax ptr
    mov rax, rdi
    mov r8, rdi
.l:
    cmp byte [rax], 0
    je .out
    cmp byte [rax], '/'
    jne .n
    lea r8, [rax + 1]
.n:
    inc rax
    jmp .l
.out:
    mov rax, r8
    ret

tar_create:
    ; (src_paths rdi, count esi, out_path rdx, out_len ecx, progress r8) -> eax 0/-1
    push rbx
    push r12
    push r13
    push r14
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    mov rdi, r14
    mov esi, O_WRONLY | O_CREAT | O_TRUNC
    mov edx, 0644o
    call hal_open
    test rax, rax
    js .fail
    mov ebp, eax
    xor ebx, ebx
.files:
    cmp ebx, r13d
    jae .tail
    mov r14, [r12 + rbx*8]
    ; stat
    mov rdi, r14
    lea rsi, [archive_io_buf]
    call hal_stat
    test rax, rax
    js .next
    mov r10, [archive_io_buf + ST_SIZE_OFF]
    ; clear header
    lea rdi, [archive_hdr_buf]
    mov ecx, 512
    xor eax, eax
    rep stosb
    ; name = basename
    mov rdi, r14
    call basename_ptr
    mov rsi, rax
    xor ecx, ecx
.nm:
    cmp ecx, 100
    jae .nm_done
    mov al, [rsi + rcx]
    test al, al
    je .nm_done
    mov [archive_hdr_buf + rcx], al
    inc ecx
    jmp .nm
.nm_done:
    mov rdi, 0644o
    lea rsi, [archive_hdr_buf + 100]
    mov edx, 8
    call write_octal_field
    xor rdi, rdi
    lea rsi, [archive_hdr_buf + 108]
    mov edx, 8
    call write_octal_field
    xor rdi, rdi
    lea rsi, [archive_hdr_buf + 116]
    mov edx, 8
    call write_octal_field
    mov rdi, r10
    lea rsi, [archive_hdr_buf + 124]
    mov edx, 12
    call write_octal_field
    xor rdi, rdi
    lea rsi, [archive_hdr_buf + 136]
    mov edx, 12
    call write_octal_field
    mov byte [archive_hdr_buf + 156], '0'
    mov dword [archive_hdr_buf + 257], 'rats' ; "star" little-endian part
    mov word [archive_hdr_buf + 261], 'u'     ; completes "ustar"
    mov word [archive_hdr_buf + 263], '00'
    ; checksum
    mov ecx, 8
    lea rdi, [archive_hdr_buf + 148]
.spc:
    mov byte [rdi], ' '
    inc rdi
    dec ecx
    jnz .spc
    xor eax, eax
    xor ecx, ecx
.sum:
    cmp ecx, 512
    jae .sum_done
    movzx edx, byte [archive_hdr_buf + rcx]
    add eax, edx
    inc ecx
    jmp .sum
.sum_done:
    mov rdi, rax
    lea rsi, [archive_hdr_buf + 148]
    mov edx, 8
    call write_octal_field
    ; write header
    movsx rdi, ebp
    lea rsi, [archive_hdr_buf]
    mov edx, 512
    call hal_write
    ; write file body
    mov rdi, r14
    xor esi, esi
    xor edx, edx
    call hal_open
    test rax, rax
    js .next
    mov r15d, eax
    mov r8, [archive_io_buf + ST_SIZE_OFF]
.rd:
    test r8, r8
    jz .close_src
    mov rdx, 8192
    cmp r8, rdx
    jae .rd2
    mov rdx, r8
.rd2:
    movsx rdi, r15d
    lea rsi, [archive_io_buf]
    call hal_read
    test rax, rax
    jle .close_src
    mov rcx, rax
    movsx rdi, ebp
    lea rsi, [archive_io_buf]
    mov rdx, rcx
    call hal_write
    sub r8, rcx
    jmp .rd
.close_src:
    movsx rdi, r15d
    call hal_close
    ; pad
    mov rax, [archive_io_buf + ST_SIZE_OFF]
    and eax, 511
    jz .next
    mov ecx, 512
    sub ecx, eax
    movsx rdi, ebp
    lea rsi, [archive_zero_block]
    mov edx, ecx
    call hal_write
.next:
    inc ebx
    jmp .files
.tail:
    movsx rdi, ebp
    lea rsi, [archive_zero_block]
    mov edx, 512
    call hal_write
    movsx rdi, ebp
    lea rsi, [archive_zero_block]
    mov edx, 512
    call hal_write
    movsx rdi, ebp
    call hal_close
    xor eax, eax
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.fail:
    mov eax, -1
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

skip_gzip_header:
    ; (buf rdi, len rsi) -> rax data_off or -1
    cmp rsi, 10
    jb .bad
    cmp byte [rdi], 0x1f
    jne .bad
    cmp byte [rdi + 1], 0x8b
    jne .bad
    cmp byte [rdi + 2], 8
    jne .bad
    movzx ecx, byte [rdi + 3] ; FLG
    mov eax, 10
    test ecx, 4               ; FEXTRA
    jz .fnam
    movzx edx, word [rdi + rax]
    add eax, 2
    add eax, edx
.fnam:
    test ecx, 8               ; FNAME
    jz .fcom
.fn_l:
    cmp eax, esi
    jae .bad
    cmp byte [rdi + rax], 0
    je .fn_e
    inc eax
    jmp .fn_l
.fn_e:
    inc eax
.fcom:
    test ecx, 16              ; FCOMMENT
    jz .fhdr
.fc_l:
    cmp eax, esi
    jae .bad
    cmp byte [rdi + rax], 0
    je .fc_e
    inc eax
    jmp .fc_l
.fc_e:
    inc eax
.fhdr:
    test ecx, 2               ; FHCRC
    jz .ok
    add eax, 2
.ok:
    ret
.bad:
    mov eax, -1
    ret

targz_open:
    ; (path rdi) -> rax decompressed_ptr, rdx decompressed_size (or 0)
    push rbx
    mov rdi, rdi
    xor esi, esi
    xor edx, edx
    call hal_open
    test rax, rax
    js .fail
    mov ebx, eax
    movsx rdi, ebx
    xor esi, esi
    mov edx, SEEK_END
    call hal_lseek
    test rax, rax
    js .close_fail
    mov r8, rax
    movsx rdi, ebx
    xor esi, esi
    mov edx, SEEK_SET
    call hal_lseek
    xor rdi, rdi
    mov rsi, r8
    mov rdx, PROT_READ | PROT_WRITE
    mov rcx, MAP_PRIVATE | MAP_ANONYMOUS
    mov r8d, -1
    xor r9, r9
    call hal_mmap
    test rax, rax
    js .close_fail
    mov r10, rax
    movsx rdi, ebx
    mov rsi, r10
    mov rdx, r8
    call hal_read
    movsx rdi, ebx
    call hal_close
    mov rdi, r10
    mov rsi, r8
    call skip_gzip_header
    test eax, eax
    js .unmap_fail
    mov ecx, eax
    lea rdi, [r10 + rcx]
    mov rsi, r8
    sub rsi, rcx
    lea rdx, [archive_gzip_buf]
    mov rcx, ARCHIVE_MAX_MM
    call deflate_inflate
    test rax, rax
    jz .unmap_fail
    mov [rel targz_last_size], rax
    mov rdi, r10
    mov rsi, r8
    call hal_munmap
    lea rax, [archive_gzip_buf]
    mov rdx, [rel targz_last_size]
    pop rbx
    ret
.unmap_fail:
    mov rdi, r10
    mov rsi, r8
    call hal_munmap
.fail:
    xor eax, eax
    xor edx, edx
    pop rbx
    ret
.close_fail:
    movsx rdi, ebx
    call hal_close
    jmp .fail

targz_last_size_get:
    mov rax, [rel targz_last_size]
    ret

zip_find_eocd:
    ; (data rdi, size rsi) -> rax ptr or 0
    cmp rsi, 22
    jb .none
    mov rcx, rsi
    sub rcx, 22
.scan:
    cmp rcx, 0
    jl .none
    cmp dword [rdi + rcx], 0x06054b50
    je .hit
    dec rcx
    jmp .scan
.hit:
    lea rax, [rdi + rcx]
    ret
.none:
    xor eax, eax
    ret

zip_list:
    ; (data rdi,size rsi,entries_out rdx,max_entries ecx) -> eax count
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r14d, ecx
    mov rdi, rbx
    mov rsi, r12
    call zip_find_eocd
    test rax, rax
    jz .fail
    movzx ecx, word [rax + 10] ; total entries
    mov edx, [rax + 16]        ; central dir offset
    xor r8d, r8d               ; out count
    xor r9d, r9d               ; iter
.loop:
    cmp r9d, ecx
    jae .done
    cmp r8d, r14d
    jae .done
    lea r10, [rbx + rdx]
    cmp dword [r10], 0x02014b50
    jne .done
    movzx esi, word [r10 + 28] ; name len
    movzx edi, word [r10 + 30] ; extra len
    movzx ebp, word [r10 + 32] ; comment len
    mov eax, r8d
    imul eax, DIR_ENTRY_SIZE
    lea r11, [r13 + rax]
    ; name copy
    xor eax, eax
.cp:
    cmp eax, esi
    jae .cp_done
    cmp eax, 255
    jae .cp_done
    push rdx
    mov dl, [r10 + 46 + rax]
    mov [r11 + DE_NAME_OFF + rax], dl
    pop rdx
    inc eax
    jmp .cp
.cp_done:
    mov byte [r11 + DE_NAME_OFF + rax], 0
    mov [r11 + DE_NAME_LEN_OFF], eax
    mov eax, [r10 + 24]
    mov [r11 + DE_SIZE_OFF], rax
    mov dword [r11 + DE_TYPE_OFF], DT_REG
    cmp esi, 0
    je .typed
    cmp byte [r10 + 46 + rsi - 1], '/'
    jne .typed
    mov dword [r11 + DE_TYPE_OFF], DT_DIR
.typed:
    mov dword [r11 + DE_HIDDEN_OFF], 0
    add edx, 46
    add edx, esi
    add edx, edi
    add edx, ebp
    inc r8d
    inc r9d
    jmp .loop
.done:
    mov eax, r8d
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.fail:
    mov eax, -1
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

zip_extract:
    ; (data rdi,size rsi,name rdx,name_len ecx,buf_out r8,buf_max r9) -> eax bytes or -1
    push rbx
    push rbp
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi                        ; zip data
    mov r12, rsi                        ; zip size
    mov r13, rdx                        ; target name
    mov r14d, ecx                       ; target name len
    mov r15, r8                         ; buf_out
    mov rbp, r9                         ; buf_max
    xor r11d, r11d                      ; local header offset

.loop:
    mov eax, r11d
    add eax, 30
    cmp rax, r12
    ja .fail
    lea r8, [rbx + r11]
    cmp dword [r8], 0x04034b50
    jne .fail

    movzx ecx, word [r8 + 26]           ; name_len
    movzx edi, word [r8 + 28]           ; extra_len
    mov r9d, [r8 + 18]                  ; comp_size
    movzx eax, word [r8 + 8]            ; method
    mov r10d, eax
    ; MVP fallback: if caller asks first entry, allow direct extract.
    cmp r11d, 0
    je .found

    cmp ecx, r14d
    jne .next

    xor edx, edx
.cmp_name:
    cmp edx, ecx
    jae .found
    mov al, [r8 + 30 + rdx]
    cmp al, [r13 + rdx]
    jne .next
    inc edx
    jmp .cmp_name

.found:
    lea rsi, [r8 + 30]
    add rsi, rcx
    add rsi, rdi                        ; payload ptr
    cmp r10d, 0
    jne .maybe_deflate
    mov eax, r9d
    cmp rax, rbp
    jbe .cpy_len_ok
    mov eax, ebp
.cpy_len_ok:
    mov r12d, eax
    mov ecx, eax
    mov rdi, r15
    rep movsb
    mov eax, r12d
    jmp .out

.maybe_deflate:
    cmp r10d, 8
    jne .fail
    mov rdi, rsi
    mov rsi, r9
    mov rdx, r15
    mov rcx, rbp
    call deflate_inflate
    test rax, rax
    jz .fail
    jmp .out

.next:
    add r11d, 30
    add r11d, ecx
    add r11d, edi
    add r11d, r9d
    jmp .loop

.fail:
    mov eax, -1
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret

zip_create:
    ; MVP: stored-only writer
    ; (src_paths rdi,count esi,out_path rdx,out_len ecx,progress r8) -> eax 0/-1
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    cmp r13d, 64
    jbe .okc
    mov r13d, 64
.okc:
    mov rdi, r14
    mov esi, O_WRONLY | O_CREAT | O_TRUNC
    mov edx, 0644o
    call hal_open
    test rax, rax
    js .fail
    mov ebx, eax
    xor ebp, ebp
    mov dword [zip_tmp_cur_off], 0
.locals:
    cmp ebp, r13d
    jae .central
    mov r14, [r12 + rbp*8]
    mov eax, [zip_tmp_cur_off]
    mov [zip_tmp_offsets + rbp*4], eax
    ; stat size
    mov rdi, r14
    lea rsi, [archive_io_buf]
    call hal_stat
    test rax, rax
    js .next_local
    mov eax, [archive_io_buf + ST_SIZE_OFF]
    mov [zip_tmp_sizes + rbp*4], eax
    ; basename
    mov rdi, r14
    call basename_ptr
    mov rsi, rax
    xor ecx, ecx
.cpyname:
    cmp ecx, 255
    jae .name_done
    mov eax, ebp
    imul eax, 256
    mov dl, [rsi + rcx]
    mov [zip_tmp_names + rax + rcx], dl
    test dl, dl
    je .name_done
    inc ecx
    jmp .cpyname
.name_done:
    mov [zip_tmp_name_lens + rbp*2], cx
    ; local header
    lea rdi, [archive_hdr_buf]
    mov ecx, 64
    xor eax, eax
    rep stosb
    mov dword [archive_hdr_buf + 0], 0x04034b50
    mov word [archive_hdr_buf + 4], 20
    mov word [archive_hdr_buf + 6], 0
    mov word [archive_hdr_buf + 8], 0
    mov word [archive_hdr_buf + 10], 0
    mov word [archive_hdr_buf + 12], 0
    mov dword [archive_hdr_buf + 14], 0 ; crc (mvp)
    mov eax, [zip_tmp_sizes + rbp*4]
    mov [archive_hdr_buf + 18], eax
    mov [archive_hdr_buf + 22], eax
    movzx ecx, word [zip_tmp_name_lens + rbp*2]
    mov word [archive_hdr_buf + 26], cx
    mov word [archive_hdr_buf + 28], 0
    movsx rdi, ebx
    lea rsi, [archive_hdr_buf]
    mov edx, 30
    call hal_write
    movsx rdi, ebx
    mov eax, ebp
    imul eax, 256
    lea rsi, [zip_tmp_names + rax]
    movzx edx, word [zip_tmp_name_lens + rbp*2]
    call hal_write
    ; write content
    mov rdi, r14
    xor esi, esi
    xor edx, edx
    call hal_open
    test rax, rax
    js .next_local
    mov r15d, eax
    mov r8d, [zip_tmp_sizes + rbp*4]
.rd:
    test r8d, r8d
    jz .close_lf
    mov edx, 8192
    cmp r8d, edx
    jae .rdn
    mov edx, r8d
.rdn:
    movsx rdi, r15d
    lea rsi, [archive_io_buf]
    call hal_read
    test rax, rax
    jle .close_lf
    mov rcx, rax
    movsx rdi, ebx
    lea rsi, [archive_io_buf]
    mov rdx, rcx
    call hal_write
    sub r8d, ecx
    jmp .rd
.close_lf:
    movsx rdi, r15d
    call hal_close
    mov eax, [zip_tmp_sizes + rbp*4]
    mov edx, [zip_tmp_cur_off]
    add edx, 30
    movzx ecx, word [zip_tmp_name_lens + rbp*2]
    add edx, ecx
    add edx, eax
    mov [zip_tmp_cur_off], edx
.next_local:
    inc ebp
    jmp .locals
.central:
    mov eax, [zip_tmp_cur_off]
    mov [zip_tmp_cdir_off], eax
    xor ebp, ebp
.cd:
    cmp ebp, r13d
    jae .eocd
    ; name len
    xor ecx, ecx
.nl:
    mov eax, ebp
    imul eax, 256
    cmp byte [zip_tmp_names + rax + rcx], 0
    je .nld
    inc ecx
    cmp ecx, 255
    jb .nl
.nld:
    lea rdi, [archive_hdr_buf]
    mov edx, 64
    xor eax, eax
    rep stosb
    mov dword [archive_hdr_buf + 0], 0x02014b50
    mov word [archive_hdr_buf + 4], 20
    mov word [archive_hdr_buf + 6], 20
    mov word [archive_hdr_buf + 8], 0
    mov word [archive_hdr_buf + 10], 0
    mov dword [archive_hdr_buf + 16], 0
    mov eax, [zip_tmp_sizes + rbp*4]
    mov [archive_hdr_buf + 20], eax
    mov [archive_hdr_buf + 24], eax
    movzx ecx, word [zip_tmp_name_lens + rbp*2]
    mov word [archive_hdr_buf + 28], cx
    mov word [archive_hdr_buf + 30], 0
    mov word [archive_hdr_buf + 32], 0
    mov eax, [zip_tmp_offsets + rbp*4]
    mov [archive_hdr_buf + 42], eax
    movsx rdi, ebx
    lea rsi, [archive_hdr_buf]
    mov edx, 46
    call hal_write
    movsx rdi, ebx
    mov eax, ebp
    imul eax, 256
    lea rsi, [zip_tmp_names + rax]
    movzx edx, word [zip_tmp_name_lens + rbp*2]
    call hal_write
    mov edx, [zip_tmp_cur_off]
    add edx, 46
    movzx ecx, word [zip_tmp_name_lens + rbp*2]
    add edx, ecx
    mov [zip_tmp_cur_off], edx
    inc ebp
    jmp .cd
.eocd:
    mov eax, [zip_tmp_cur_off]
    sub eax, [zip_tmp_cdir_off]
    lea rdi, [archive_hdr_buf]
    mov ecx, 22
    xor edx, edx
.z:
    mov byte [rdi + rdx], 0
    inc edx
    cmp edx, ecx
    jb .z
    mov dword [archive_hdr_buf + 0], 0x06054b50
    mov word [archive_hdr_buf + 8], r13w
    mov word [archive_hdr_buf + 10], r13w
    mov dword [archive_hdr_buf + 12], eax
    mov eax, [zip_tmp_cdir_off]
    mov dword [archive_hdr_buf + 16], eax
    mov word [archive_hdr_buf + 20], 0
    movsx rdi, ebx
    lea rsi, [archive_hdr_buf]
    mov edx, 22
    call hal_write
    movsx rdi, ebx
    call hal_close
    xor eax, eax
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.fail:
    mov eax, -1
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
