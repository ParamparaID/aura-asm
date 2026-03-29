// test_arm64_hal.S - ARM64 HAL smoke test
.include "src/hal/linux_arm64/defs.S"

.section .text
.global _start
.extern hal_write
.extern hal_mmap
.extern hal_munmap
.extern hal_clock_gettime
.extern hal_exit

_start:
    // Test 1: write
    mov x0, #STDOUT
    adr x1, msg_hello
    mov x2, #11
    bl hal_write
    cmp x0, #11
    b.ne fail

    // Test 2: mmap + memory R/W
    mov x0, #0
    mov x1, #4096
    mov x2, #(PROT_READ | PROT_WRITE)
    mov x3, #(MAP_PRIVATE | MAP_ANONYMOUS)
    mov x4, #-1
    mov x5, #0
    bl hal_mmap
    tbnz x0, #63, fail
    mov x19, x0
    mov w1, #42
    str w1, [x19]
    ldr w2, [x19]
    cmp w2, #42
    b.ne fail
    mov x0, x19
    mov x1, #4096
    bl hal_munmap
    tbnz x0, #63, fail

    // Test 3: clock_gettime
    mov x0, #CLOCK_MONOTONIC
    adr x1, ts_buf
    bl hal_clock_gettime
    tbnz x0, #63, fail
    adr x3, ts_buf
    ldr x4, [x3]
    cmp x4, #0
    b.eq fail

    // PASS
    mov x0, #STDOUT
    adr x1, msg_pass
    mov x2, #17
    bl hal_write
    mov x0, #0
    bl hal_exit

fail:
    mov x0, #STDERR
    adr x1, msg_fail
    mov x2, #17
    bl hal_write
    mov x0, #1
    bl hal_exit

.section .bss
    .balign 8
ts_buf:
    .skip 16

.section .rodata
msg_hello:
    .ascii "Hello Aura\n"
msg_pass:
    .ascii "ALL TESTS PASSED\n"
msg_fail:
    .ascii "TESTS FAILED ARM\n"
