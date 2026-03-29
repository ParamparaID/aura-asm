.include "src/hal/linux_arm64/defs.S"

.equ CV_BUFFER_OFF, 0
.equ CV_WIDTH_OFF, 8
.equ CV_HEIGHT_OFF, 12
.equ CV_STRIDE_OFF, 16
.equ CV_SIZE_OFF, 24

.section .text
.global _start
.extern hal_write
.extern hal_exit
.extern canvas_fill_rect_neon
.extern canvas_clear_neon
.extern canvas_alpha_blend_neon

_start:
    // Init canvas metadata.
    adr x19, canvas_obj
    adr x20, canvas_pixels
    str x20, [x19, #CV_BUFFER_OFF]
    mov w0, #100
    str w0, [x19, #CV_WIDTH_OFF]
    str w0, [x19, #CV_HEIGHT_OFF]
    mov w0, #400
    str w0, [x19, #CV_STRIDE_OFF]
    mov w0, #40000
    str w0, [x19, #CV_SIZE_OFF]

    // Test 1: clear red and check center pixel.
    mov x0, x19
    ldr w1, =0xFFFF0000
    bl canvas_clear_neon
    cmp x0, #0
    b.ne fail
    adr x0, canvas_pixels
    mov x1, #(50 * 100 + 50)
    add x0, x0, x1, lsl #2
    ldr w2, [x0]
    ldr w3, =0xFFFF0000
    cmp w2, w3
    b.ne fail

    // Test 2: fill rect blue and check in/out points.
    mov x0, x19
    mov x1, #10
    mov x2, #10
    mov x3, #50
    mov x4, #50
    ldr w5, =0xFF0000FF
    bl canvas_fill_rect_neon
    cmp x0, #0
    b.ne fail

    // inside point (25,25) must be blue.
    adr x0, canvas_pixels
    mov x1, #(25 * 100 + 25)
    add x0, x0, x1, lsl #2
    ldr w2, [x0]
    ldr w3, =0xFF0000FF
    cmp w2, w3
    b.ne fail

    // outside point (5,5) stays red.
    adr x0, canvas_pixels
    mov x1, #(5 * 100 + 5)
    add x0, x0, x1, lsl #2
    ldr w2, [x0]
    ldr w3, =0xFFFF0000
    cmp w2, w3
    b.ne fail

    // Test 3: alpha blend one pixel.
    adr x6, blend_src
    adr x7, blend_dst
    ldr w8, =0x80FF0000
    ldr w9, =0xFF000000
    str w8, [x6]
    str w9, [x7]
    adr x0, blend_dst
    adr x1, blend_src
    mov x2, #1
    bl canvas_alpha_blend_neon
    cmp x0, #0
    b.ne fail
    adr x0, blend_dst
    ldr w2, [x0]
    ldr w3, =0xFF800000
    cmp w2, w3
    b.ne fail

    mov x0, #STDOUT
    adr x1, msg_pass
    mov x2, #17
    bl hal_write
    mov x0, #0
    bl hal_exit

fail:
    mov x0, #STDERR
    adr x1, msg_fail
    mov x2, #19
    bl hal_write
    mov x0, #1
    bl hal_exit

.section .bss
    .balign 8
canvas_obj:
    .skip 64
canvas_pixels:
    .skip 40000
blend_src:
    .skip 4
blend_dst:
    .skip 4

.section .rodata
msg_pass:
    .ascii "ALL TESTS PASSED\n"
msg_fail:
    .ascii "TEST ARM64 CANVAS FAIL\n"
