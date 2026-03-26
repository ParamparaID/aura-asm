// sync.S - ARM64 atomics and spin primitives

.section .text
.global atomic_cas
.global atomic_inc
.global spin_lock
.global spin_unlock

// atomic_cas(ptr, expected, desired) -> old value
// x0=ptr, x1=expected, x2=desired
atomic_cas:
1:
    ldxr x3, [x0]
    cmp x3, x1
    b.ne 2f
    stxr w4, x2, [x0]
    cbnz w4, 1b
    dmb ish
    mov x0, x3
    ret
2:
    clrex
    mov x0, x3
    ret

// atomic_inc(ptr) -> new value
// x0=ptr
atomic_inc:
1:
    ldxr x1, [x0]
    add x1, x1, #1
    stxr w2, x1, [x0]
    cbnz w2, 1b
    dmb ish
    mov x0, x1
    ret

// spin_lock(ptr)
// x0=ptr (0 unlocked / 1 locked)
spin_lock:
    mov x1, #1
1:
    ldaxr x2, [x0]
    cbnz x2, 2f
    stxr w3, x1, [x0]
    cbnz w3, 1b
    ret
2:
    yield
    b 1b

// spin_unlock(ptr)
// x0=ptr
spin_unlock:
    stlr xzr, [x0]
    ret
