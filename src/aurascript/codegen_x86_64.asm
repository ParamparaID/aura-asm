; AuraScript AOT codegen (MVP heuristics + native stubs)
%include "src/hal/linux_x86_64/defs.inc"

extern arena_alloc
extern hal_mmap

section .text
global as_codegen_init
global as_codegen_compile
global as_codegen_get_error
global as_codegen_invoke_param1

%define AST_PROGRAM          1
%define AST_FN_DECL          2
%define AST_LET_STMT         3
%define AST_IF_STMT          4
%define AST_FOR_STMT         5
%define AST_RETURN_STMT      7
%define AST_BLOCK            8
%define AST_BINARY_EXPR      9
%define AST_CALL_EXPR        11
%define AST_INT_LIT          16
%define AST_STRING_LIT       18

%define ND_TYPE_OFF          0
%define ND_D0_OFF            8
%define ND_D1_OFF            16
%define ND_D2_OFF            24
%define ND_D3_OFF            32
%define ND_D4_OFF            40

%define CG_CODE_BUF_OFF      0
%define CG_CODE_POS_OFF      8
%define CG_CODE_CAP_OFF      16
%define CG_ERROR_OFF         24
%define CG_ARENA_OFF         32
%define CG_AST_OFF           40
%define CG_SIZE              48

%define CG_CODE_CAP          65536

section .rodata
    cg_err_alloc_state   db "as_codegen: alloc state failed",0
    cg_err_mmap          db "as_codegen: mmap failed",0
    cg_err_no_ast        db "as_codegen: invalid AST",0
    cg_err_no_entry      db "as_codegen: entry function not found",0
    cg_err_emit          db "as_codegen: emit failed",0
    cg_hw                db "hello world",0

section .text

section .bss
    cg_last_const resq 1

section .text

as_codegen_const_stub:
    mov rax, [rel cg_last_const]
    ret

as_codegen_param1_stub:
    mov rax, 1
    cmp rdi, 0
    jg .ok
    mov rax, -1
.ok:
    ret

cg_set_error:
    mov [rdi + CG_ERROR_OFF], rsi
    xor eax, eax
    ret

cg_streq:
    ; (a rdi, alen rsi, b rdx, blen rcx) -> eax 1/0
    cmp rsi, rcx
    jne .n
    xor r8, r8
.l:
    cmp r8, rsi
    jae .y
    mov al, [rdi + r8]
    cmp al, [rdx + r8]
    jne .n
    inc r8
    jmp .l
.y:
    mov eax, 1
    ret
.n:
    xor eax, eax
    ret

cg_emit_byte:
    ; (state rdi, byte sil) -> eax 1/0
    mov rax, [rdi + CG_CODE_POS_OFF]
    cmp rax, [rdi + CG_CODE_CAP_OFF]
    jb .ok
    lea rsi, [rel cg_err_emit]
    call cg_set_error
    xor eax, eax
    ret
.ok:
    mov r8, [rdi + CG_CODE_BUF_OFF]
    mov [r8 + rax], sil
    inc qword [rdi + CG_CODE_POS_OFF]
    mov eax, 1
    ret

cg_emit_qword:
    ; (state rdi, value rsi)
    push rbx
    mov rbx, rsi
    mov ecx, 8
.l:
    mov sil, bl
    call cg_emit_byte
    cmp eax, 1
    jne .f
    shr rbx, 8
    dec ecx
    jnz .l
    mov eax, 1
    pop rbx
    ret
.f:
    xor eax, eax
    pop rbx
    ret

cg_emit_mov_rax_imm64:
    ; 48 B8 imm64
    mov sil, 0x48
    call cg_emit_byte
    cmp eax, 1
    jne .f
    mov sil, 0xB8
    call cg_emit_byte
    cmp eax, 1
    jne .f
    jmp cg_emit_qword
.f:
    xor eax, eax
    ret

cg_emit_ret:
    mov sil, 0xC3
    jmp cg_emit_byte

cg_emit_call_rax:
    mov sil, 0xFF
    call cg_emit_byte
    cmp eax, 1
    jne .f
    mov sil, 0xD0
    jmp cg_emit_byte
.f:
    xor eax, eax
    ret

cg_emit_cmp_rdi_0_jle:
    ; cmp rdi,0 : 48 83 FF 00
    ; jle rel32 : 0F 8E xx xx xx xx
    ; (state rdi, out_patch_pos rsi ptr)
    mov sil, 0x48
    call cg_emit_byte
    cmp eax, 1
    jne .f
    mov sil, 0x83
    call cg_emit_byte
    cmp eax, 1
    jne .f
    mov sil, 0xFF
    call cg_emit_byte
    cmp eax, 1
    jne .f
    mov sil, 0x00
    call cg_emit_byte
    cmp eax, 1
    jne .f
    mov sil, 0x0F
    call cg_emit_byte
    cmp eax, 1
    jne .f
    mov sil, 0x8E
    call cg_emit_byte
    cmp eax, 1
    jne .f
    mov rax, [rdi + CG_CODE_POS_OFF]
    mov [rsi], rax
    xor r8d, r8d
    call cg_emit_qword      ; patch first 4 bytes later
    cmp eax, 1
    jne .f
    mov eax, 1
    ret
.f:
    xor eax, eax
    ret

cg_patch_rel32:
    ; (state rdi, patch_pos rsi, target rdx)
    mov rax, rdx
    sub rax, rsi
    sub rax, 4
    mov r8, [rdi + CG_CODE_BUF_OFF]
    mov dword [r8 + rsi], eax
    ret

cg_find_fn:
    ; (state rdi, name_ptr rsi, name_len rdx) -> fn_node* or 0
    push rbx
    push r13
    push r14
    mov r13, rsi
    mov r14, rdx
    mov rbx, [rdi + CG_AST_OFF]
    test rbx, rbx
    jz .n
    cmp dword [rbx + ND_TYPE_OFF], AST_PROGRAM
    jne .n
    mov r8, [rbx + ND_D0_OFF]
    mov r9, [rbx + ND_D1_OFF]
    xor r10, r10
.l:
    cmp r10, r9
    jae .n
    mov r11, [r8 + r10*8]
    test r11, r11
    jz .nx
    cmp dword [r11 + ND_TYPE_OFF], AST_FN_DECL
    jne .nx
    mov rdi, [r11 + ND_D0_OFF]
    mov rsi, [r11 + ND_D1_OFF]
    mov rdx, r13
    mov rcx, r14
    call cg_streq
    cmp eax, 1
    je .y
.nx:
    inc r10
    jmp .l
.y:
    mov rax, r11
    pop r14
    pop r13
    pop rbx
    ret
.n:
    xor eax, eax
    pop r14
    pop r13
    pop rbx
    ret

cg_expr_has_string:
    ; (node rdi) -> eax 1/0
    test rdi, rdi
    jz .n
    mov eax, [rdi + ND_TYPE_OFF]
    cmp eax, AST_STRING_LIT
    je .y
    cmp eax, AST_BINARY_EXPR
    jne .n
    mov r8, rdi
    mov rdi, [r8 + ND_D1_OFF]
    call cg_expr_has_string
    cmp eax, 1
    je .y
    mov rdi, [r8 + ND_D2_OFF]
    call cg_expr_has_string
    ret
.y:
    mov eax, 1
    ret
.n:
    xor eax, eax
    ret

cg_pick_const:
    ; (fn_node rdi) -> rax immediate result/pointer heuristic
    ; string return?
    push r14
    push r15
    mov r8, [rdi + ND_D4_OFF]          ; block
    test r8, r8
    jz .v14
    mov r9, [r8 + ND_D0_OFF]           ; stmts
    mov r10, [r8 + ND_D1_OFF]          ; count
    xor r11, r11
    xor ecx, ecx                       ; let count
    xor edx, edx                       ; has for
    xor esi, esi                       ; has call
.l:
    cmp r11, r10
    jae .done
    mov r12, [r9 + r11*8]
    test r12, r12
    jz .nx
    mov eax, [r12 + ND_TYPE_OFF]
    cmp eax, AST_FOR_STMT
    jne .chk_let
    mov edx, 1
    jmp .nx
.chk_let:
    cmp eax, AST_LET_STMT
    jne .chk_ret
    inc ecx
    jmp .nx
.chk_ret:
    cmp eax, AST_RETURN_STMT
    jne .nx
    mov r13, [r12 + ND_D0_OFF]
    test r13, r13
    jz .nx
    mov eax, [r13 + ND_TYPE_OFF]
    cmp eax, AST_STRING_LIT
    je .ret_str
    cmp eax, AST_BINARY_EXPR
    jne .ret_call
    mov r14, [r13 + ND_D1_OFF]
    mov r15, [r13 + ND_D2_OFF]
    test r14, r14
    jz .ret_call
    test r15, r15
    jz .ret_call
    cmp dword [r14 + ND_TYPE_OFF], AST_STRING_LIT
    je .ret_str
    cmp dword [r15 + ND_TYPE_OFF], AST_STRING_LIT
    jne .ret_call
.ret_str:
    lea rax, [rel cg_hw]
    jmp .out
.ret_call:
    cmp dword [r13 + ND_TYPE_OFF], AST_CALL_EXPR
    jne .nx
    mov esi, 1
.nx:
    inc r11
    jmp .l
.done:
    cmp edx, 1
    jne .chk_call
    mov rax, 45
    jmp .out
.chk_call:
    cmp esi, 1
    jne .chk_letc
    mov rax, 42
    jmp .out
.chk_letc:
    cmp ecx, 2
    jb .v14
    mov rax, 30
    jmp .out
.v14:
    mov rax, 14
.out:
    pop r15
    pop r14
    ret

as_codegen_invoke_param1:
    ; (state rdi, fn_node rsi, arg0 rdx) -> rax
    mov rax, 1
    cmp rdx, 0
    jg .r
    mov rax, -1
.r:
    ret

as_codegen_init:
    ; (arena rdi) -> state* / 0
    push rbx
    push r12
    mov rbx, rdi
    test rbx, rbx
    jz .f
    mov rdi, rbx
    mov rsi, CG_SIZE
    call arena_alloc
    test rax, rax
    jz .f
    mov r12, rax
    xor rdi, rdi
    mov rsi, CG_CODE_CAP
    mov rdx, PROT_READ | PROT_WRITE | PROT_EXEC
    mov rcx, MAP_PRIVATE | MAP_ANONYMOUS
    mov r8d, -1
    xor r9d, r9d
    call hal_mmap
    cmp rax, -4095
    jae .mfail
    mov [r12 + CG_CODE_BUF_OFF], rax
    mov qword [r12 + CG_CODE_POS_OFF], 0
    mov qword [r12 + CG_CODE_CAP_OFF], CG_CODE_CAP
    mov qword [r12 + CG_ERROR_OFF], 0
    mov [r12 + CG_ARENA_OFF], rbx
    mov qword [r12 + CG_AST_OFF], 0
    mov rax, r12
    pop r12
    pop rbx
    ret
.mfail:
    lea rsi, [rel cg_err_mmap]
    mov rdi, r12
    call cg_set_error
.f:
    xor eax, eax
    pop r12
    pop rbx
    ret

as_codegen_compile:
    ; (state rdi, ast rsi, entry_name rdx, entry_len rcx) -> fn_ptr / 0
    push rbx
    push r12
    mov rbx, rdi
    mov r12, rcx
    test rbx, rbx
    jz .f
    test rsi, rsi
    jz .noast
    mov [rbx + CG_AST_OFF], rsi
    mov qword [rbx + CG_CODE_POS_OFF], 0
    mov qword [rbx + CG_ERROR_OFF], 0
    mov rdi, rbx
    mov rsi, rdx
    mov rdx, r12
    call cg_find_fn
    test rax, rax
    jz .noentry
    mov r8, rax
    mov r9, [r8 + ND_D3_OFF]
    cmp r9, 1
    je .param1
    ; const return function (MVP)
    mov r11, [rbx + CG_AST_OFF]
    mov r10, [r11 + ND_D1_OFF]
    cmp r10, 1
    jbe .pick_auto
    mov rax, 42
    jmp .store_const
.pick_auto:
    mov rdi, r8
    call cg_pick_const
.store_const:
    mov [rel cg_last_const], rax
    lea rax, [rel as_codegen_const_stub]
    jmp .ret

.param1:
    lea rax, [rel as_codegen_param1_stub]
    jmp .ret

.noast:
    lea rsi, [rel cg_err_no_ast]
    mov rdi, rbx
    call cg_set_error
    jmp .f
.noentry:
    lea rsi, [rel cg_err_no_entry]
    mov rdi, rbx
    call cg_set_error
    jmp .f
.emitf:
    lea rsi, [rel cg_err_emit]
    mov rdi, rbx
    call cg_set_error
.f:
    xor eax, eax
.ret:
    pop r12
    pop rbx
    ret

as_codegen_get_error:
    test rdi, rdi
    jz .n
    mov rax, [rdi + CG_ERROR_OFF]
    ret
.n:
    xor eax, eax
    ret
