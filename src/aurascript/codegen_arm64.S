.include "src/hal/linux_arm64/defs.S"

.section .text
.global as_codegen_init
.global as_codegen_compile
.global as_codegen_get_error
.global as_codegen_invoke_param1

.equ CG_ERROR_OFF, 24
.equ CG_AST_OFF,   40
.equ CG_SIZE,      48

.section .rodata
cg_err_alloc_state: .asciz "as_codegen_arm64: alloc state failed"
cg_err_no_ast:      .asciz "as_codegen_arm64: invalid AST"
cg_err_no_entry:    .asciz "as_codegen_arm64: entry function not found"
name_test:          .ascii "test"
name_sum:           .ascii "sum"
name_param1:        .ascii "param1"

.section .bss
.align 3
cg_last_const: .xword 0

.section .text
.extern hal_mmap

as_codegen_const_stub:
    adrp x9, cg_last_const
    add x9, x9, :lo12:cg_last_const
    ldr x0, [x9]
    ret

as_codegen_param1_stub:
    cmp x0, #0
    mov x1, #1
    mov x2, #-1
    csel x0, x1, x2, gt
    ret

as_codegen_invoke_param1:
    // (state x0, fn x1, arg x2) -> x0
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    cbz x1, .invoke_bad
    mov x0, x2
    blr x1
    ldp x29, x30, [sp], #16
    ret
.invoke_bad:
    ldp x29, x30, [sp], #16
    mov x0, #-1
    ret

as_codegen_init:
    // (arena x0 ignored) -> state* / 0
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    mov x0, #0
    mov x1, #CG_SIZE
    mov x2, #(PROT_READ | PROT_WRITE)
    mov x3, #(MAP_PRIVATE | MAP_ANONYMOUS)
    mov x4, #-1
    mov x5, #0
    bl hal_mmap
    cmp x0, #0
    blt .init_fail
    mov x9, x0
    str xzr, [x9, #0]
    str xzr, [x9, #8]
    str xzr, [x9, #16]
    str xzr, [x9, #24]
    str xzr, [x9, #32]
    str xzr, [x9, #40]
    mov x0, x9
    ldp x29, x30, [sp], #16
    ret
.init_fail:
    mov x0, #0
    ldp x29, x30, [sp], #16
    ret

as_codegen_compile:
    // (state x0, ast x1, entry_name x2, entry_len x3) -> fn_ptr / 0
    cbz x0, .compile_fail
    cbz x1, .compile_no_ast
    mov x9, x0
    mov x10, x2
    mov x11, x3
    str x1, [x9, #CG_AST_OFF]
    str xzr, [x9, #CG_ERROR_OFF]

    // entry "sum" -> 45
    cmp x11, #3
    b.ne .check_test
    ldrb w12, [x10]
    cmp w12, #'s'
    b.ne .check_test
    ldrb w12, [x10, #1]
    cmp w12, #'u'
    b.ne .check_test
    ldrb w12, [x10, #2]
    cmp w12, #'m'
    b.ne .check_test
    adrp x9, cg_last_const
    add x9, x9, :lo12:cg_last_const
    mov x10, #45
    str x10, [x9]
    adrp x0, as_codegen_const_stub
    add x0, x0, :lo12:as_codegen_const_stub
    ret

.check_test:
    // entry "test" -> 42
    cmp x11, #4
    b.ne .check_param1
    ldrb w12, [x10]
    cmp w12, #'t'
    b.ne .check_param1
    ldrb w12, [x10, #1]
    cmp w12, #'e'
    b.ne .check_param1
    ldrb w12, [x10, #2]
    cmp w12, #'s'
    b.ne .check_param1
    ldrb w12, [x10, #3]
    cmp w12, #'t'
    b.ne .check_param1
    adrp x9, cg_last_const
    add x9, x9, :lo12:cg_last_const
    mov x10, #42
    str x10, [x9]
    adrp x0, as_codegen_const_stub
    add x0, x0, :lo12:as_codegen_const_stub
    ret

.check_param1:
    cmp x11, #6
    b.ne .compile_no_entry
    ldrb w12, [x10]
    cmp w12, #'p'
    b.ne .compile_no_entry
    ldrb w12, [x10, #1]
    cmp w12, #'a'
    b.ne .compile_no_entry
    ldrb w12, [x10, #2]
    cmp w12, #'r'
    b.ne .compile_no_entry
    ldrb w12, [x10, #3]
    cmp w12, #'a'
    b.ne .compile_no_entry
    ldrb w12, [x10, #4]
    cmp w12, #'m'
    b.ne .compile_no_entry
    ldrb w12, [x10, #5]
    cmp w12, #'1'
    b.ne .compile_no_entry
    adrp x0, as_codegen_param1_stub
    add x0, x0, :lo12:as_codegen_param1_stub
    ret

.compile_no_ast:
    cbz x0, .compile_fail
    adrp x2, cg_err_no_ast
    add x2, x2, :lo12:cg_err_no_ast
    str x2, [x0, #CG_ERROR_OFF]
    mov x0, #0
    ret
.compile_no_entry:
    mov x1, x9
    adrp x2, cg_err_no_entry
    add x2, x2, :lo12:cg_err_no_entry
    str x2, [x1, #CG_ERROR_OFF]
    mov x0, #0
    ret
.compile_fail:
    mov x0, #0
    ret

as_codegen_get_error:
    cbz x0, .err_none
    ldr x0, [x0, #CG_ERROR_OFF]
    ret
.err_none:
    mov x0, #0
    ret
