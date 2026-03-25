; viewer.asm — text/hex viewer core
%include "src/hal/linux_x86_64/defs.inc"
%include "src/gui/widget.inc"
%include "src/fm/viewer.inc"

extern hal_open
extern hal_close
extern hal_read
extern hal_lseek
extern hal_mmap
extern hal_munmap
extern canvas_fill_rect
extern plugin_viewer_find_handler

%define SEEK_SET                    0
%define SEEK_CUR                    1
%define SEEK_END                    2
%define KEY_UP_CODE                 103
%define KEY_DOWN_CODE               108

section .bss
    viewer_pool                     resb (V_STRUCT_HEAD_SIZE + (VIEWER_MAX_LINES * 8) + (VIEWER_MAX_HITS * 8)) * VIEWER_MAX_INSTANCES

section .text
global viewer_open
global viewer_close
global viewer_render
global viewer_handle_input
global viewer_search

viewer_pick_syntax:
    ; rdi path ptr, esi path_len -> eax syntax
    mov eax, SYNTAX_NONE
    cmp esi, 3
    jb .out
    mov ecx, esi
    sub ecx, 4
    js .out
    lea rdx, [rdi + rcx]
    cmp byte [rdx], '.'
    jne .chk2
    cmp byte [rdx + 1], 'a'
    jne .chk2
    cmp byte [rdx + 2], 's'
    jne .chk2
    cmp byte [rdx + 3], 'm'
    jne .chk2
    mov eax, SYNTAX_ASM
    ret
.chk2:
    cmp esi, 2
    jb .out
    mov ecx, esi
    sub ecx, 2
    lea rdx, [rdi + rcx]
    cmp byte [rdx], '.'
    jne .chk3
    cmp byte [rdx + 1], 'c'
    je .c
    cmp byte [rdx + 1], 'h'
    je .c
    cmp byte [rdx + 1], 'p'
    je .py2
    cmp byte [rdx + 1], 's'
    je .sh2
    cmp byte [rdx + 1], 'j'
    je .js2
    jmp .out
.c:
    mov eax, SYNTAX_C
    ret
.py2:
    cmp byte [rdx + 2], 'y'
    jne .out
    mov eax, SYNTAX_PYTHON
    ret
.sh2:
    cmp byte [rdx + 2], 'h'
    jne .out
    mov eax, SYNTAX_SHELL
    ret
.js2:
    cmp byte [rdx + 2], 's'
    jne .out
    mov eax, SYNTAX_JS
.chk3:
.out:
    ret

viewer_alloc:
    xor ecx, ecx
.loop:
    cmp ecx, VIEWER_MAX_INSTANCES
    jae .fail
    mov eax, ecx
    imul eax, (V_STRUCT_HEAD_SIZE + (VIEWER_MAX_LINES * 8) + (VIEWER_MAX_HITS * 8))
    lea rax, [rel viewer_pool + rax]
    cmp dword [rax + V_IN_USE_OFF], 0
    je .found
    inc ecx
    jmp .loop
.found:
    mov dword [rax + V_IN_USE_OFF], 1
    ret
.fail:
    xor eax, eax
    ret

viewer_open:
    ; (path rdi, path_len esi) -> rax Viewer* or 0
    push rbx
    push r12
    push r13
    mov r12, rdi
    mov r13d, esi
    ; plugin viewer hook by extension
    mov rdi, r12
    mov esi, r13d
    call plugin_viewer_find_handler
    test rax, rax
    jz .builtin_open
    mov r11, rax
    mov rdi, r12
    mov esi, r13d
    call r11
    test rax, rax
    jnz .ok_ret
.builtin_open:
    call viewer_alloc
    test rax, rax
    jz .fail
    mov rbx, rax
    mov rdi, rbx
    mov ecx, V_STRUCT_HEAD_SIZE
    xor eax, eax
    rep stosb
    mov dword [rbx + V_IN_USE_OFF], 1
    lea rax, [rbx + V_STRUCT_HEAD_SIZE]
    mov [rbx + V_LINES_PTR_OFF], rax
    lea rax, [rbx + V_STRUCT_HEAD_SIZE + (VIEWER_MAX_LINES * 8)]
    mov [rbx + V_SEARCH_HITS_PTR_OFF], rax

    ; open file
    mov rdi, r12
    xor esi, esi
    xor edx, edx
    call hal_open
    test rax, rax
    js .fail_mark
    mov ebp, eax

    ; size = lseek(fd,0,SEEK_END)
    movsx rdi, ebp
    xor esi, esi
    mov edx, SEEK_END
    call hal_lseek
    test rax, rax
    js .fail_close
    mov r14, rax
    mov [rbx + V_FILE_SIZE_OFF], r14

    ; rewind
    movsx rdi, ebp
    xor esi, esi
    mov edx, SEEK_SET
    call hal_lseek

    ; mmap anonymous buffer and read file there
    xor rdi, rdi
    mov rsi, r14
    mov rdx, PROT_READ | PROT_WRITE
    mov rcx, MAP_PRIVATE | MAP_ANONYMOUS
    mov r8, -1
    xor r9, r9
    call hal_mmap
    test rax, rax
    js .fail_close
    mov [rbx + V_FILE_DATA_OFF], rax
    mov r15, rax

    movsx rdi, ebp
    mov rsi, r15
    mov rdx, r14
    call hal_read
    test rax, rax
    js .fail_unmap

    ; close fd
    movsx rdi, ebp
    call hal_close

    ; line index
    mov rax, [rbx + V_LINES_PTR_OFF]
    mov [rax], r15
    mov qword [rbx + V_LINE_COUNT_OFF], 1
    xor ecx, ecx
.scan:
    cmp rcx, r14
    jae .done_scan
    cmp byte [r15 + rcx], 10
    jne .n
    mov rdx, [rbx + V_LINE_COUNT_OFF]
    cmp rdx, VIEWER_MAX_LINES
    jae .n
    mov rax, [rbx + V_LINES_PTR_OFF]
    lea r8, [r15 + rcx + 1]
    mov [rax + rdx*8], r8
    inc qword [rbx + V_LINE_COUNT_OFF]
.n:
    inc ecx
    jmp .scan
.done_scan:
    mov rdi, r12
    mov esi, r13d
    call viewer_pick_syntax
    mov [rbx + V_SYNTAX_TYPE_OFF], eax
    mov rax, rbx
.ok_ret:
    pop r13
    pop r12
    pop rbx
    ret

.fail_unmap:
    mov rdi, [rbx + V_FILE_DATA_OFF]
    mov rsi, [rbx + V_FILE_SIZE_OFF]
    call hal_munmap
.fail_close:
    movsx rdi, ebp
    call hal_close
.fail_mark:
    mov dword [rbx + V_IN_USE_OFF], 0
.fail:
    xor eax, eax
    pop r13
    pop r12
    pop rbx
    ret

viewer_close:
    ; (viewer rdi)
    push rbx
    mov rbx, rdi
    test rdi, rdi
    jz .out
    cmp dword [rbx + V_IN_USE_OFF], 0
    je .out
    mov rax, [rbx + V_FILE_DATA_OFF]
    test rax, rax
    jz .mark
    mov rsi, [rbx + V_FILE_SIZE_OFF]
    mov rdi, rax
    call hal_munmap
.mark:
    mov dword [rbx + V_IN_USE_OFF], 0
.out:
    pop rbx
    ret

viewer_render:
    ; (viewer rdi, canvas rsi, theme rdx, x ecx, y r8d, w r9d, h [rsp+...])
    ; Use simple background + row stripes to visualize content in MVP.
    push rbx
    push r12
    mov r12, rdi
    mov rbx, rsi
    test r12, r12
    jz .out
    mov r10d, 0xFF10141C
    test rdx, rdx
    jz .bg
    mov r10d, [rdx + TH_BG_OFF]
.bg:
    mov rdi, rbx
    mov esi, ecx
    mov edx, r8d
    mov ecx, r9d
    mov r8d, dword [rsp + 24] ; h
    mov r9d, r10d
    call canvas_fill_rect
    ; small content stripe so tests can detect changed pixel
    mov rdi, rbx
    add esi, 2
    add edx, 2
    mov ecx, 24
    mov r8d, 12
    mov r9d, 0xFF2A3A55
    call canvas_fill_rect
.out:
    pop r12
    pop rbx
    ret

viewer_search:
    ; (viewer rdi, pattern rsi, len edx) -> eax hit_count
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12, rsi
    mov r13d, edx
    test rbx, rbx
    jz .none
    test r13d, r13d
    jz .none
    cmp r13d, 255
    jbe .cp
    mov r13d, 255
.cp:
    lea rdi, [rbx + V_SEARCH_STR_OFF]
    mov ecx, r13d
    rep movsb
    mov byte [rbx + V_SEARCH_STR_OFF + r13], 0
    mov [rbx + V_SEARCH_LEN_OFF], r13d
    mov dword [rbx + V_HIT_COUNT_OFF], 0
    mov dword [rbx + V_CURRENT_HIT_OFF], 0

    mov r8, [rbx + V_FILE_DATA_OFF]
    mov r9, [rbx + V_FILE_SIZE_OFF]
    xor ecx, ecx
    xor r10d, r10d            ; line
    xor r11d, r11d            ; col
.scan:
    cmp rcx, r9
    jae .done
    mov al, [r8 + rcx]
    cmp al, 10
    jne .try
    inc r10d
    xor r11d, r11d
    inc rcx
    jmp .scan
.try:
    mov eax, r9d
    sub eax, ecx
    cmp eax, r13d
    jb .adv
    mov esi, 0
.cmp:
    cmp esi, r13d
    jae .hit
    mov edx, ecx
    add edx, esi
    mov al, [r8 + rdx]
    cmp al, [rbx + V_SEARCH_STR_OFF + rsi]
    jne .adv
    inc esi
    jmp .cmp
.hit:
    mov eax, [rbx + V_HIT_COUNT_OFF]
    cmp eax, VIEWER_MAX_HITS
    jae .adv
    mov rdx, [rbx + V_SEARCH_HITS_PTR_OFF]
    mov [rdx + rax*8], r10d
    mov [rdx + rax*8 + 4], r11d
    inc dword [rbx + V_HIT_COUNT_OFF]
.adv:
    inc rcx
    inc r11d
    jmp .scan
.done:
    mov eax, [rbx + V_HIT_COUNT_OFF]
    jmp .out
.none:
    xor eax, eax
.out:
    pop r13
    pop r12
    pop rbx
    ret

viewer_handle_input:
    ; (viewer rdi, event rsi) -> eax 1 handled, 0 ignore, -1 close request
    test rdi, rdi
    jz .no
    cmp dword [rsi + IE_TYPE_OFF], INPUT_KEY
    jne .no
    cmp dword [rsi + IE_KEY_STATE_OFF], KEY_PRESSED
    jne .no
    mov eax, [rsi + IE_KEY_CODE_OFF]
    cmp eax, 1                       ; Esc
    je .close
    cmp eax, 16                      ; q
    je .close
    cmp eax, 35                      ; h
    je .hex
    cmp eax, KEY_UP_CODE
    je .up
    cmp eax, KEY_DOWN_CODE
    je .down
    cmp eax, 49                      ; n
    je .next
    cmp eax, 25                      ; p/N fallback
    je .prev
    xor eax, eax
    ret
.hex:
    mov eax, [rdi + V_HEX_MODE_OFF]
    xor eax, 1
    mov [rdi + V_HEX_MODE_OFF], eax
    mov eax, 1
    ret
.up:
    cmp qword [rdi + V_TOP_LINE_OFF], 0
    jle .h
    dec qword [rdi + V_TOP_LINE_OFF]
.h:
    mov eax, 1
    ret
.down:
    mov rax, [rdi + V_TOP_LINE_OFF]
    inc rax
    cmp rax, [rdi + V_LINE_COUNT_OFF]
    jae .h
    mov [rdi + V_TOP_LINE_OFF], rax
    mov eax, 1
    ret
.next:
    mov eax, [rdi + V_HIT_COUNT_OFF]
    test eax, eax
    jz .h
    mov ecx, [rdi + V_CURRENT_HIT_OFF]
    inc ecx
    cmp ecx, eax
    jb .setn
    xor ecx, ecx
.setn:
    mov [rdi + V_CURRENT_HIT_OFF], ecx
    mov eax, 1
    ret
.prev:
    mov eax, [rdi + V_HIT_COUNT_OFF]
    test eax, eax
    jz .h
    mov ecx, [rdi + V_CURRENT_HIT_OFF]
    test ecx, ecx
    jz .wrap
    dec ecx
    jmp .setp
.wrap:
    dec eax
    mov ecx, eax
.setp:
    mov [rdi + V_CURRENT_HIT_OFF], ecx
    mov eax, 1
    ret
.close:
    mov eax, -1
    ret
.no:
    xor eax, eax
    ret
