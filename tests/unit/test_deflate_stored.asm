; Minimal stored DEFLATE block: 1 byte 0x42
extern deflate_inflate
extern hal_write
extern hal_exit

section .rodata
    blk:    db 0x01, 0x01, 0x00, 0xFE, 0xFF, 0x42
    blk_len equ $ - blk
    okmsg:  db "STORED_OK", 10
    oklen   equ $ - okmsg
    badmsg: db "STORED_BAD rax=", 0
    nl:     db 10

section .bss
    outb resb 8

section .text
global _start
_start:
    lea rdi, [rel blk]
    mov esi, blk_len
    lea rdx, [rel outb]
    mov ecx, 1
    call deflate_inflate
    cmp rax, 1
    jne .bad
    mov al, [rel outb]
    cmp al, 0x42
    jne .bad
    mov rdi, 1
    lea rsi, [rel okmsg]
    mov rdx, oklen
    call hal_write
    xor edi, edi
    call hal_exit
.bad:
    mov rdi, 1
    lea rsi, [rel badmsg]
    mov rdx, 15
    call hal_write
    xor edi, edi
    call hal_exit
