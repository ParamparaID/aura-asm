; AuraScript cache (MVP)
section .text
global as_cache_lookup
global as_cache_store
global as_cache_hash_fnv1a

; as_cache_lookup(source_path, source_hash) -> code ptr or 0
as_cache_lookup:
    xor eax, eax
    ret

; as_cache_store(source_path, source_hash, code_buf, code_len) -> 0/-1
as_cache_store:
    xor eax, eax
    ret

; as_cache_hash_fnv1a(data, len) -> hash64
as_cache_hash_fnv1a:
    mov rax, 1469598103934665603
    test rsi, rsi
    jz .ret
    xor rcx, rcx
.loop:
    cmp rcx, rsi
    jae .ret
    movzx rdx, byte [rdi + rcx]
    xor rax, rdx
    imul rax, rax, 1099511628211
    inc rcx
    jmp .loop
.ret:
    ret
