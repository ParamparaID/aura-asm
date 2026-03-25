; AuraScript runtime helpers (MVP stubs)
%include "src/hal/linux_x86_64/defs.inc"

extern hal_write

section .text
global rt_print
global rt_string_concat
global rt_string_compare
global rt_string_length
global rt_int_to_string
global rt_array_new
global rt_array_push
global rt_array_get
global rt_array_len
global rt_map_new
global rt_map_set
global rt_map_get
global rt_shell_capture

; rt_print(value, type)
rt_print:
    cmp rsi, 2
    jne .ret
    ; string pointer print (null-terminated in MVP)
    push rbx
    mov rbx, rdi
    xor rdx, rdx
.len:
    cmp byte [rbx + rdx], 0
    je .w
    inc rdx
    jmp .len
.w:
    mov rdi, STDOUT
    mov rsi, rbx
    call hal_write
    pop rbx
.ret:
    xor eax, eax
    ret

rt_string_concat:
    xor eax, eax
    ret
rt_string_compare:
    xor eax, eax
    ret
rt_string_length:
    mov rax, rsi
    ret
rt_int_to_string:
    xor eax, eax
    ret
rt_array_new:
    xor eax, eax
    ret
rt_array_push:
    xor eax, eax
    ret
rt_array_get:
    xor eax, eax
    ret
rt_array_len:
    xor eax, eax
    ret
rt_map_new:
    xor eax, eax
    ret
rt_map_set:
    xor eax, eax
    ret
rt_map_get:
    xor eax, eax
    ret
rt_shell_capture:
    xor eax, eax
    xor edx, edx
    ret
