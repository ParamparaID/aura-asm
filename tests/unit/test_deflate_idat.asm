; zlib-wrapped IDAT from tests/data/test_image.png — deflate after CMF/FLG must yield 14 bytes
extern deflate_inflate
extern hal_write
extern hal_exit

section .rodata
    msg_ok                  db "DEFLATE_OK", 10
    msg_ok_len              equ $ - msg_ok
    msg_bad                 db "DEFLATE_BAD", 10
    msg_bad_len             equ $ - msg_bad
    zlib_idat:
        db 0x78, 0x01, 0x01, 0x0e, 0x00, 0xf1, 0xff
        db 0x00, 0xff, 0x00, 0x00, 0x00, 0xff, 0x00, 0x00, 0x00
        db 0xff, 0xff, 0xff, 0xff, 0xff
        db 0x1f, 0xee, 0x05, 0xfb
    zlib_idat_len equ $ - zlib_idat

section .bss
    raw_out resb 32

section .text
global _start
_start:
    lea rdi, [rel zlib_idat + 2]
    mov esi, zlib_idat_len - 2
    lea rdx, [rel raw_out]
    mov ecx, 14
    call deflate_inflate
    cmp rax, 14
    jne .bad
    mov rdi, 1
    lea rsi, [rel msg_ok]
    mov rdx, msg_ok_len
    call hal_write
    xor edi, edi
    call hal_exit
.bad:
    mov rdi, 1
    lea rsi, [rel msg_bad]
    mov rdx, msg_bad_len
    call hal_write
    mov edi, 1
    call hal_exit
