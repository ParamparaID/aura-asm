; theme.asm — builtin themes + minimal .auratheme parser
%include "src/hal/linux_x86_64/defs.inc"
%include "src/gui/theme.inc"

extern hal_open
extern hal_close
extern hal_read
extern font_load
extern font_destroy

section .rodata
    font_default_path   db "fonts/LiberationMono-Regular.ttf", 0
    font_default_len    equ $ - font_default_path

    nm_dark             db "dark", 0
    nm_light            db "light", 0
    nm_nord             db "nord", 0
    nm_gruvbox          db "gruvbox", 0
    nm_tokyo            db "tokyo-night", 0

    k_bg                db "bg", 0
    k_fg                db "fg", 0
    k_accent            db "accent", 0
    k_border_w          db "border_width", 0
    k_corner            db "corner_radius", 0
    k_main              db "main", 0
    k_spring            db "spring_stiffness", 0
    k_spring_len        equ 16

    preset_dark:
        dd 0xFF7AA2F7, 0xFF1A1B26, 0xFF24283B, 0xFFC0CAF5, 0xFF565F89
        dd 0xFF3B4261, 0xFFF7768E, 0xFF9ECE6A, 0xFFE0AF68, 0xFFC0CAF5
    preset_light:
        dd 0xFF0066CC, 0xFFF5F5F5, 0xFFFFFFFF, 0xFF1A1A1A, 0xFF666666
        dd 0xFFCCCCCC, 0xFFCC0000, 0xFF008800, 0xFFCC8800, 0xFF1A1A1A
    preset_nord:
        dd 0xFF88C0D0, 0xFF2E3440, 0xFF3B4252, 0xFFECEFF4, 0xFFD8DEE9
        dd 0xFF4C566A, 0xFFBF616A, 0xFFA3BE8C, 0xFFEBCB8B, 0xFFECEFF4
    preset_gruvbox:
        dd 0xFF83A598, 0xFF282828, 0xFF3C3836, 0xFFEBDBB2, 0xFF928374
        dd 0xFF504945, 0xFFFB4934, 0xFFB8BB26, 0xFFFABD2F, 0xFFEBDBB2
    preset_tokyo:
        dd 0xFF7AA2F7, 0xFF1A1B26, 0xFF24283B, 0xFFC0CAF5, 0xFF565F89
        dd 0xFF3B4261, 0xFFF7768E, 0xFF9ECE6A, 0xFFE0AF68, 0xFFC0CAF5

    builtin_sizes:
        dd 13, 11, 2, 12, 4, 0
        dd 13, 11, 2, 10, 4, 0
        dd 13, 11, 2, 8, 4, 0
        dd 13, 11, 2, 8, 4, 0
        dd 13, 11, 2, 12, 4, 6
    builtin_anim:
        dd 19660800, 25, 200
        dd 19660800, 28, 180
        dd 19660800, 24, 220
        dd 19660800, 26, 200
        dd 19660800, 25, 200

section .bss
    theme_active        resb THEME_STRUCT_SIZE
    theme_parse_buf     resb 65536
    parse_file_len      resq 1
    th_section          resd 1

section .text
global theme_load
global theme_load_builtin
global theme_get_color
global theme_destroy

; rdi=user, rsi=ref, edx=len -> eax=1 match
theme_memeq:
    xor eax, eax
    test edx, edx
    jz .yes
    mov ecx, edx
    repe cmpsb
    jne .no
.yes:
    mov eax, 1
    ret
.no:
    xor eax, eax
    ret

; rdi=hex chars, esi=len
theme_parse_hex:
    push rbx
    push r12
    xor r12d, r12d
    xor ecx, ecx
.loop:
    cmp ecx, esi
    jae .done
    movzx eax, byte [rdi + rcx]
    inc ecx
    cmp al, '0'
    jb .done
    cmp al, '9'
    jbe .dig
    or al, 0x20
    cmp al, 'a'
    jb .done
    cmp al, 'f'
    ja .done
    sub al, 'a' - 10
    jmp .sh
.dig:
    sub al, '0'
.sh:
    movzx ebx, al
    shl r12d, 4
    or r12d, ebx
    jmp .loop
.done:
    cmp esi, 8
    jb .a6
    mov eax, r12d
    jmp .out
.a6:
    or r12d, 0xFF000000
    mov eax, r12d
.out:
    pop r12
    pop rbx
    ret

; rbx=theme*, rsi=preset 40 bytes, edx=idx 0..4
theme_apply_preset:
    mov r10, rbx
    mov eax, [rsi + 0]
    mov [r10 + T_ACCENT_OFF], eax
    mov eax, [rsi + 4]
    mov [r10 + T_BG_OFF], eax
    mov eax, [rsi + 8]
    mov [r10 + T_SURFACE_OFF], eax
    mov eax, [rsi + 12]
    mov [r10 + T_FG_OFF], eax
    mov eax, [rsi + 16]
    mov [r10 + T_TEXT_SECONDARY_OFF], eax
    mov eax, [rsi + 20]
    mov [r10 + T_BORDER_COLOR_OFF], eax
    mov eax, [rsi + 24]
    mov [r10 + T_ERROR_OFF], eax
    mov eax, [rsi + 28]
    mov [r10 + T_SUCCESS_OFF], eax
    mov eax, [rsi + 32]
    mov [r10 + T_WARNING_OFF], eax
    mov eax, [rsi + 36]
    mov [r10 + T_TEXT_PRIMARY_OFF], eax
    movsxd r11, edx
    imul r11, 24
    lea rdi, [rel builtin_sizes]
    add rdi, r11
    mov eax, [rdi + 0]
    mov [r10 + T_FONT_MAIN_SIZE_OFF], eax
    mov eax, [rdi + 4]
    mov [r10 + T_FONT_UI_SIZE_OFF], eax
    mov eax, [rdi + 8]
    mov [r10 + T_BORDER_WIDTH_OFF], eax
    mov eax, [rdi + 12]
    mov [r10 + T_CORNER_RADIUS_OFF], eax
    mov eax, [rdi + 16]
    mov [r10 + T_GAP_OFF], eax
    mov eax, [rdi + 20]
    mov [r10 + T_BLUR_RADIUS_OFF], eax
    movsxd r11, edx
    imul r11, 12
    lea rdi, [rel builtin_anim]
    add rdi, r11
    mov eax, [rdi + 0]
    mov [r10 + T_SPRING_STIFF_OFF], eax
    mov eax, [rdi + 4]
    mov [r10 + T_SPRING_DAMP_OFF], eax
    mov eax, [rdi + 8]
    mov [r10 + T_TRANSITION_MS_OFF], eax
    ret

; theme_load_builtin(name, len) -> rax theme* or 0
theme_load_builtin:
    push rbx
    push r12
    push r13
    mov r12, rdi
    mov r13d, esi

    lea rdi, [rel theme_active]
    mov ecx, THEME_STRUCT_SIZE / 4
    xor eax, eax
    rep stosd

    xor ebx, ebx
    cmp r13d, 4
    jne .chk_light
    mov rdi, r12
    lea rsi, [rel nm_dark]
    mov edx, 4
    call theme_memeq
    test eax, eax
    jz .chk_light
    lea rsi, [rel preset_dark]
    jmp .have_idx
.chk_light:
    cmp r13d, 5
    jne .chk_nord
    mov rdi, r12
    lea rsi, [rel nm_light]
    mov edx, 5
    call theme_memeq
    test eax, eax
    jz .chk_nord
    lea rsi, [rel preset_light]
    mov ebx, 1
    jmp .have_idx
.chk_nord:
    cmp r13d, 4
    jne .chk_gru
    mov rdi, r12
    lea rsi, [rel nm_nord]
    mov edx, 4
    call theme_memeq
    test eax, eax
    jz .chk_gru
    lea rsi, [rel preset_nord]
    mov ebx, 2
    jmp .have_idx
.chk_gru:
    cmp r13d, 8
    jne .chk_tok
    mov rdi, r12
    lea rsi, [rel nm_gruvbox]
    mov edx, 8
    call theme_memeq
    test eax, eax
    jz .chk_tok
    lea rsi, [rel preset_gruvbox]
    mov ebx, 3
    jmp .have_idx
.chk_tok:
    cmp r13d, 11
    jne .fail
    mov rdi, r12
    lea rsi, [rel nm_tokyo]
    mov edx, 11
    call theme_memeq
    test eax, eax
    jz .fail
    lea rsi, [rel preset_tokyo]
    mov ebx, 4
.have_idx:
    lea rcx, [rel theme_active]
    mov rdx, rbx
    mov rbx, rcx
    call theme_apply_preset
    lea rdi, [rel font_default_path]
    mov esi, font_default_len
    dec esi
    call font_load
    test rax, rax
    jz .fail
    mov rcx, rax
    lea rbx, [rel theme_active]
    mov [rbx + T_FONT_MAIN_OFF], rcx
    mov [rbx + T_FONT_UI_OFF], rcx
    mov dword [rbx + T_LOADED_OFF], 1
    lea rax, [rel theme_active]
    jmp .out
.fail:
    xor eax, eax
.out:
    pop r13
    pop r12
    pop rbx
    ret

theme_destroy:
    test rdi, rdi
    jz .ret
    push rbx
    mov rbx, rdi
    mov rdi, [rbx + T_FONT_MAIN_OFF]
    test rdi, rdi
    jz .u1
    call font_destroy
.u1:
    mov rdi, [rbx + T_FONT_UI_OFF]
    cmp rdi, [rbx + T_FONT_MAIN_OFF]
    je .clr
    test rdi, rdi
    jz .clr
    call font_destroy
.clr:
    mov rdi, rbx
    mov ecx, THEME_STRUCT_SIZE / 4
    xor eax, eax
    rep stosd
    pop rbx
.ret:
    ret

; theme_get_color(theme, name, len) -> eax
theme_get_color:
    xor eax, eax
    test rdi, rdi
    jz .ret
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12, rsi
    mov r13d, edx
    cmp r13d, 2
    jne .tfg
    mov rdi, r12
    lea rsi, [rel k_bg]
    mov edx, 2
    call theme_memeq
    test eax, eax
    jnz .bg
.tfg:
    cmp r13d, 2
    jne .tac
    mov rdi, r12
    lea rsi, [rel k_fg]
    mov edx, 2
    call theme_memeq
    test eax, eax
    jnz .fg
.tac:
    cmp r13d, 6
    jne .no
    mov rdi, r12
    lea rsi, [rel k_accent]
    mov edx, 6
    call theme_memeq
    test eax, eax
    jnz .ac
.no:
    xor eax, eax
    jmp .out
.bg:
    mov eax, [rbx + T_BG_OFF]
    jmp .out
.fg:
    mov eax, [rbx + T_FG_OFF]
    jmp .out
.ac:
    mov eax, [rbx + T_ACCENT_OFF]
.out:
    pop r13
    pop r12
    pop rbx
.ret:
    ret

; ---------- file load + line parser ----------
; rdi=path, esi=len
theme_load:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi

    lea rdi, [rel theme_active]
    mov ecx, THEME_STRUCT_SIZE / 4
    xor eax, eax
    rep stosd
    mov dword [rel th_section], THSEC_NONE

    mov rdi, r12
    mov esi, O_RDONLY
    xor edx, edx
    call hal_open
    cmp rax, 0
    jl .fail
    mov r15, rax
    xor ebx, ebx
.rd:
    cmp rbx, 65500
    jae .rdone
    mov rdi, r15
    lea rsi, [rel theme_parse_buf + rbx]
    mov edx, 4096
    call hal_read
    cmp rax, 0
    jle .rdone
    add rbx, rax
    jmp .rd
.rdone:
    mov rdi, r15
    call hal_close
    mov [rel parse_file_len], rbx
    xor r14, r14
.lp:
    mov rax, [rel parse_file_len]
    cmp r14, rax
    jge .after
    lea rdi, [rel theme_parse_buf + r14]
    mov rsi, rax
    sub rsi, r14
    call theme_one_line
    add r14, rax
    jmp .lp
.after:
    cmp qword [rel theme_active + T_FONT_MAIN_OFF], 0
    jne .font_ok
    lea rdi, [rel font_default_path]
    mov esi, font_default_len
    dec esi
    call font_load
    test rax, rax
    jz .fail
    mov [rel theme_active + T_FONT_MAIN_OFF], rax
    mov [rel theme_active + T_FONT_UI_OFF], rax
    mov dword [rel theme_active + T_FONT_MAIN_SIZE_OFF], 13
    mov dword [rel theme_active + T_FONT_UI_SIZE_OFF], 11
.font_ok:
    mov dword [rel theme_active + T_LOADED_OFF], 1
    lea rax, [rel theme_active]
    jmp .out
.fail:
    xor eax, eax
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; rdi=line start, rsi=max bytes left -> rax consumed
theme_one_line:
    push rbx
    push r12
    push r13
    xor r12d, r12d
.len:
    cmp r12, rsi
    jge .eof
    movzx eax, byte [rdi + r12]
    inc r12
    cmp al, 10
    je .got
    cmp al, 13
    je .got
    jmp .len
.eof:
    mov rax, r12
    jmp .done
.got:
    mov r13, r12
    mov rcx, r13
    dec rcx
    jle .empty
    movzx eax, byte [rdi]
    cmp al, '#'
    je .skip
    cmp al, '['
    je .sec
    jmp .kv
.skip:
    mov rax, r13
    jmp .done
.empty:
    mov rax, r13
    jmp .done
.sec:
    cmp byte [rdi + 1], 'c'
    jne .sw
    mov dword [rel th_section], THSEC_COLORS
    jmp .skip
.sw:
    cmp byte [rdi + 1], 'w'
    jne .sf
    mov dword [rel th_section], THSEC_WINDOW
    jmp .skip
.sf:
    cmp byte [rdi + 1], 'f'
    jne .sa
    mov dword [rel th_section], THSEC_FONTS
    jmp .skip
.sa:
    cmp byte [rdi + 1], 'a'
    jne .skip
    mov dword [rel th_section], THSEC_ANIMATION
    jmp .skip
.kv:
    xor ebx, ebx
.feq:
    cmp rbx, rcx
    jge .skip
    cmp byte [rdi + rbx], '='
    je .eq
    inc rbx
    jmp .feq
.eq:
    mov rdx, rbx
.ttrim:
    cmp rdx, 0
    jle .eqgo
    cmp byte [rdi + rdx - 1], ' '
    jne .eqgo
    dec rdx
    jmp .ttrim
.eqgo:
    lea r8, [rdi + rbx + 1]
    mov r9, rcx
    call theme_apply_kv
    jmp .skip
.done:
    pop r13
    pop r12
    pop rbx
    ret

; rdi=key0, rdx=keylen, r8=val0, r9=content len (key+val+sep within line, no trailing nl)
theme_apply_kv:
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdi
    mov r12d, edx
    mov r13, r8
    mov r14, r9
    mov eax, [rel th_section]
    cmp eax, THSEC_COLORS
    je .col
    cmp eax, THSEC_WINDOW
    je .win
    cmp eax, THSEC_FONTS
    je .fnt
    cmp eax, THSEC_ANIMATION
    je .anim
    jmp .ret
.col:
    mov rdi, rbx
    lea rsi, [rel k_bg]
    mov edx, 2
    cmp r12d, 2
    jne .cf
    call theme_memeq
    test eax, eax
    jz .cf
    mov rdi, r13
    call theme_strip_hash
    mov rdi, rax
    mov esi, edx
    call theme_parse_hex
    mov [rel theme_active + T_BG_OFF], eax
    jmp .ret
.cf:
    mov rdi, rbx
    lea rsi, [rel k_fg]
    mov edx, 2
    cmp r12d, 2
    jne .ca
    call theme_memeq
    test eax, eax
    jz .ca
    mov rdi, r13
    call theme_strip_hash
    mov rdi, rax
    mov esi, edx
    call theme_parse_hex
    mov [rel theme_active + T_FG_OFF], eax
    jmp .ret
.ca:
    mov rdi, rbx
    lea rsi, [rel k_accent]
    mov edx, 6
    cmp r12d, 6
    jne .ret
    call theme_memeq
    test eax, eax
    jz .ret
    mov rdi, r13
    call theme_strip_hash
    mov rdi, rax
    mov esi, edx
    call theme_parse_hex
    mov [rel theme_active + T_ACCENT_OFF], eax
    jmp .ret
.win:
    mov rdi, rbx
    lea rsi, [rel k_border_w]
    mov edx, 12
    cmp r12d, 12
    jne .wc
    call theme_memeq
    test eax, eax
    jz .wc
    mov rdi, r13
    call theme_parse_dec
    mov [rel theme_active + T_BORDER_WIDTH_OFF], eax
    jmp .ret
.wc:
    mov rdi, rbx
    lea rsi, [rel k_corner]
    mov edx, 13
    cmp r12d, 13
    jne .ret
    call theme_memeq
    test eax, eax
    jz .ret
    mov rdi, r13
    call theme_parse_dec
    mov [rel theme_active + T_CORNER_RADIUS_OFF], eax
    jmp .ret
.fnt:
    mov rdi, rbx
    lea rsi, [rel k_main]
    mov edx, 4
    cmp r12d, 4
    jne .ret
    call theme_memeq
    test eax, eax
    jz .ret
    mov rdi, r13
    mov rsi, rbx
    add rsi, r14
    sub rsi, r13
    call theme_parse_main_font
    jmp .ret
.anim:
    mov rdi, rbx
    lea rsi, [rel k_spring]
    mov edx, k_spring_len
    cmp r12d, edx
    jne .ret
    call theme_memeq
    test eax, eax
    jz .ret
    mov rdi, r13
    call theme_parse_dec
    imul eax, 65536
    mov [rel theme_active + T_SPRING_STIFF_OFF], eax
.ret:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; rdi=val ptr -> rax ptr after #, edx len hex digits
theme_strip_hash:
    xor ecx, ecx
.ws:
    cmp byte [rdi + rcx], ' '
    jne .h
    inc rcx
    jmp .ws
.h:
    lea rax, [rdi + rcx]
    cmp byte [rax], '#'
    jne .bad
    inc rax
    mov rdx, rax
.lp:
    movzx esi, byte [rdx]
    test sil, sil
    jz .bad
    cmp sil, ' '
    je .ok
    cmp sil, 10
    je .ok
    cmp sil, 13
    je .ok
    inc rdx
    jmp .lp
.ok:
    sub rdx, rax
    mov edx, edx
    ret
.bad:
    xor edx, edx
    xor eax, eax
    ret

; rdi=val
theme_parse_dec:
    xor ecx, ecx
.ws:
    cmp byte [rdi + rcx], ' '
    jne .d
    inc rcx
    jmp .ws
.d:
    lea rdi, [rdi + rcx]
    xor eax, eax
    xor ecx, ecx
.lp:
    movzx edx, byte [rdi + rcx]
    cmp dl, '0'
    jb .done
    cmp dl, '9'
    ja .done
    sub dl, '0'
    imul eax, 10
    movzx edx, dl
    add eax, edx
    inc ecx
    jmp .lp
.done:
    ret

; rdi=val start, rsi=max bytes in val region
theme_parse_main_font:
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdi
    mov r14d, esi
    xor ecx, ecx
.lws:
    cmp ecx, r14d
    jge .bad
    movzx eax, byte [rbx + rcx]
    cmp al, ' '
    jne .lwd
    inc ecx
    jmp .lws
.lwd:
    lea rbx, [rbx + rcx]
    sub r14d, ecx
    jle .bad
    xor r12d, r12d
.sp:
    cmp r12d, r14d
    jge .bad
    movzx eax, byte [rbx + r12]
    cmp al, ' '
    je .gotsp
    cmp al, 10
    je .bad
    cmp al, 13
    je .bad
    inc r12d
    jmp .sp
.gotsp:
    mov byte [rbx + r12], 0
    lea rdi, [rbx + r12 + 1]
    call theme_parse_dec
    mov r13d, eax
    mov rdi, rbx
    mov esi, r12d
    call font_load
    test rax, rax
    jz .bad
    mov [rel theme_active + T_FONT_MAIN_OFF], rax
    mov [rel theme_active + T_FONT_UI_OFF], rax
    mov [rel theme_active + T_FONT_MAIN_SIZE_OFF], r13d
    mov [rel theme_active + T_FONT_UI_SIZE_OFF], r13d
.bad:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
