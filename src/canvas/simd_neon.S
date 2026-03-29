.section .text

.equ CV_BUFFER_OFF, 0
.equ CV_WIDTH_OFF, 8
.equ CV_HEIGHT_OFF, 12
.equ CV_STRIDE_OFF, 16

.global canvas_has_neon
.global canvas_fill_rect_simd
.global canvas_clear_simd
.global canvas_fill_rect_neon
.global canvas_clear_neon
.global canvas_alpha_blend_neon
.global canvas_box_blur_h_neon

// canvas_has_neon() -> 1 on AArch64.
canvas_has_neon:
    mov x0, #1
    ret

// canvas_clear_simd(canvas_ptr, color) -> 0/-1
canvas_clear_simd:
canvas_clear_neon:
    cbz x0, .clear_bad
    mov x8, x0
    mov w5, w1
    mov x1, #0
    mov x2, #0
    ldr w3, [x8, #CV_WIDTH_OFF]
    ldr w4, [x8, #CV_HEIGHT_OFF]
    mov x0, x8
    b canvas_fill_rect_neon
.clear_bad:
    mov x0, #-1
    ret

// canvas_fill_rect_neon(canvas_ptr, x, y, w, h, color)
// x0=canvas, x1=x, x2=y, x3=w, x4=h, x5=color
canvas_fill_rect_simd:
canvas_fill_rect_neon:
    cbz x0, .fr_bad
    cmp x3, #0
    ble .fr_ok
    cmp x4, #0
    ble .fr_ok

    // Clamp start to >=0.
    cmp x1, #0
    csel x9, x1, xzr, ge      // x0_start
    cmp x2, #0
    csel x10, x2, xzr, ge     // y0_start

    // x_end=min(width, x+w), y_end=min(height, y+h)
    ldr w11, [x0, #CV_WIDTH_OFF]
    ldr w12, [x0, #CV_HEIGHT_OFF]
    sxtw x11, w11
    sxtw x12, w12
    add x13, x1, x3
    cmp x13, x11
    csel x13, x13, x11, le
    add x14, x2, x4
    cmp x14, x12
    csel x14, x14, x12, le

    cmp x13, x9
    ble .fr_ok
    cmp x14, x10
    ble .fr_ok

    mov w2, w5
    dup v0.4s, w2
    ldr x15, [x0, #CV_BUFFER_OFF]   // buffer
    ldr w16, [x0, #CV_STRIDE_OFF]
    sxtw x16, w16                    // stride bytes
    sub x17, x13, x9                 // row pixel count
    mov x6, x10                      // y cursor

.fr_row:
    cmp x6, x14
    bge .fr_ok
    mul x7, x6, x16
    add x7, x7, x15
    add x8, x7, x9, lsl #2

    mov x4, x17
    lsr x5, x4, #2                   // groups of 4 pixels
.fr_vec:
    cbz x5, .fr_tail
    st1 {v0.4s}, [x8], #16
    subs x5, x5, #1
    b.ne .fr_vec

.fr_tail:
    and x4, x4, #3
    cbz x4, .fr_next_row
.fr_tail_loop:
    str w2, [x8], #4
    subs x4, x4, #1
    b.ne .fr_tail_loop

.fr_next_row:
    add x6, x6, #1
    b .fr_row

.fr_ok:
    mov x0, #0
    ret
.fr_bad:
    mov x0, #-1
    ret

// canvas_alpha_blend_neon(dst_ptr, src_ptr, count)
// Scalar math MVP with ARM64-friendly operations.
canvas_alpha_blend_neon:
    cbz x0, .ab_bad
    cbz x1, .ab_bad
    cmp x2, #0
    ble .ab_ok

.ab_loop:
    ldr w3, [x1], #4         // src
    ldr w4, [x0]             // dst
    lsr w5, w3, #24          // sa
    mov w6, #255
    sub w6, w6, w5           // inv = 255-sa

    // B channel
    and w7, w3, #0xFF
    and w8, w4, #0xFF
    madd w7, w7, w5, wzr
    madd w8, w8, w6, w7
    mov w9, #255
    udiv w8, w8, w9

    // G channel
    lsr w7, w3, #8
    and w7, w7, #0xFF
    lsr w10, w4, #8
    and w10, w10, #0xFF
    madd w7, w7, w5, wzr
    madd w10, w10, w6, w7
    udiv w10, w10, w9

    // R channel
    lsr w7, w3, #16
    and w7, w7, #0xFF
    lsr w11, w4, #16
    and w11, w11, #0xFF
    madd w7, w7, w5, wzr
    madd w11, w11, w6, w7
    udiv w11, w11, w9

    // Alpha: sa + (da*(255-sa))/255
    lsr w12, w4, #24
    madd w12, w12, w6, wzr
    udiv w12, w12, w9
    add w12, w12, w5
    cmp w12, #255
    csel w12, w12, w9, le

    lsl w10, w10, #8
    orr w8, w8, w10
    lsl w11, w11, #16
    orr w8, w8, w11
    lsl w12, w12, #24
    orr w8, w8, w12
    str w8, [x0], #4

    subs x2, x2, #1
    b.ne .ab_loop

.ab_ok:
    mov x0, #0
    ret
.ab_bad:
    mov x0, #-1
    ret

// canvas_box_blur_h_neon(src, dst, width, height, radius)
// MVP placeholder: copy src->dst, keep API shape stable.
canvas_box_blur_h_neon:
    cbz x0, .bb_bad
    cbz x1, .bb_bad
    cmp x2, #0
    ble .bb_ok
    cmp x3, #0
    ble .bb_ok
    mul x5, x2, x3
    cbz x5, .bb_ok
.bb_loop:
    ldr w6, [x0], #4
    str w6, [x1], #4
    subs x5, x5, #1
    b.ne .bb_loop
.bb_ok:
    mov x0, #0
    ret
.bb_bad:
    mov x0, #-1
    ret
