// threads.S - ARM64 thread creation helpers via clone
.include "src/hal/linux_arm64/defs.S"

.section .text

.macro SYSCALL nr
    mov x8, #\nr
    svc #0
.endm

.global thread_create
.global thread_join

// thread_create(func_ptr, arg_ptr, stack_size)
// x0=fn, x1=arg, x2=stack_size
// return: x0=tid (>0 parent), x0=0 child (never returns after fn), x0<0 on error
thread_create:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]

    mov x19, x0                       // fn
    mov x20, x1                       // arg
    mov x21, x2                       // stack size
    cbnz x21, 1f
    mov x21, #65536
1:
    // mmap stack: mmap(NULL, size, RW, PRIVATE|ANON, -1, 0)
    mov x0, #0
    mov x1, x21
    mov x2, #(PROT_READ | PROT_WRITE)
    mov x3, #(MAP_PRIVATE | MAP_ANONYMOUS)
    mov x4, #-1
    mov x5, #0
    SYSCALL SYS_MMAP
    cmp x0, #0
    blt .err
    mov x22, x0                       // stack base

    // child stack grows down; pass top pointer
    add x1, x22, x21

    // clone(flags, child_stack, parent_tid, child_tid, tls)
    ldr x0, =0x10F11                  // CLONE_VM|FS|FILES|SIGHAND|THREAD|SIGCHLD
    mov x2, #0
    mov x3, #0
    mov x4, #0
    SYSCALL SYS_CLONE
    cbz x0, .child
    // parent: x0 already tid / error
    b .out

.child:
    mov x0, x20
    blr x19                           // fn(arg)
    mov x0, #0
    SYSCALL SYS_EXIT
1:
    b 1b

.err:
    mov x0, #-1
.out:
    ldp x19, x20, [sp, #16]
    ldp x21, x22, [sp, #32]
    ldp x29, x30, [sp], #64
    ret

// thread_join(tid, status_ptr) -> wait4
// x0=tid, x1=status_ptr
thread_join:
    mov x2, #0
    mov x3, #0
    SYSCALL SYS_WAIT4
    ret
