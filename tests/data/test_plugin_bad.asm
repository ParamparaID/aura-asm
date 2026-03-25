global test_add

section .text
test_add:
    lea eax, [rdi + rsi]
    ret
