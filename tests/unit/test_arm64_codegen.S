.include "src/hal/linux_arm64/defs.S"

.section .text
.global _start
.extern hal_write
.extern hal_exit
.extern as_codegen_init
.extern as_codegen_compile
.extern as_codegen_get_error

_start:
    // Init codegen state.
    mov x0, #0
    bl as_codegen_init
    cbz x0, fail
    mov x19, x0

    // "test" -> 42
    mov x0, x19
    adr x1, fake_ast
    adr x2, name_test
    mov x3, #4
    bl as_codegen_compile
    cbz x0, fail
    mov x20, x0

    // "sum" -> 45
    mov x0, x19
    adr x1, fake_ast
    adr x2, name_sum
    mov x3, #3
    bl as_codegen_compile
    cbz x0, fail
    mov x21, x0

    // Unknown symbol should fail and provide error pointer.
    mov x0, x19
    adr x1, fake_ast
    adr x2, name_unknown
    mov x3, #3
    bl as_codegen_compile
    cbnz x0, fail
    mov x0, x19
    bl as_codegen_get_error
    cbz x0, fail

    mov x0, #STDOUT
    adr x1, msg_pass
    mov x2, #17
    bl hal_write
    mov x0, #0
    bl hal_exit

fail:
    mov x0, #STDERR
    adr x1, msg_fail
    mov x2, #20
    bl hal_write
    mov x0, #1
    bl hal_exit

.section .rodata
name_test:
    .ascii "test"
name_sum:
    .ascii "sum"
name_unknown:
    .ascii "zzz"
msg_pass:
    .ascii "ALL TESTS PASSED\n"
msg_fail:
    .ascii "TEST ARM64 CG FAIL\n"

.section .data
    .balign 8
fake_ast:
    .xword 1
