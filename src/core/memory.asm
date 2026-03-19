; memory.asm
; Arena and Slab allocators for Aura Shell (Linux x86_64)
; Author: Aura Shell Team
; Date: 2026-03-19

%include "src/hal/linux_x86_64/defs.inc"

extern hal_mmap
extern hal_munmap

%define PAGE_SIZE                   4096
%define MAX_ARENAS                  16
%define MAX_SLABS                   16

; Arena layout (24 bytes)
%define ARENA_BASE_PTR_OFF          0
%define ARENA_SIZE_OFF              8
%define ARENA_OFFSET_OFF            16
%define ARENA_STRUCT_SIZE           24

; Slab layout (48 bytes)
%define SLAB_BASE_PTR_OFF           0
%define SLAB_TOTAL_SIZE_OFF         8
%define SLAB_OBJ_SIZE_OFF           16
%define SLAB_CAPACITY_OFF           24
%define SLAB_FREE_HEAD_OFF          32
%define SLAB_ALLOCATED_OFF          40
%define SLAB_STRUCT_SIZE            48

section .data

section .bss
    arena_pool       resq MAX_ARENAS * (ARENA_STRUCT_SIZE / 8)
    arena_used       resb MAX_ARENAS

    slab_pool        resq MAX_SLABS * (SLAB_STRUCT_SIZE / 8)
    slab_used        resb MAX_SLABS

section .text
global arena_init
global arena_alloc
global arena_reset
global arena_destroy
global slab_init
global slab_alloc
global slab_free
global slab_destroy

; arena_init(size)
; Params:
;   rdi = requested arena size in bytes
; Return:
;   rax = pointer to Arena struct on success, 0 on failure
; Complexity: O(MAX_ARENAS)
arena_init:
    push r12
    test rdi, rdi
    jz .fail

    mov rax, rdi
    add rax, PAGE_SIZE - 1
    jc .fail
    and rax, -PAGE_SIZE
    jz .fail
    mov r12, rax                    ; aligned size

    xor rdi, rdi
    mov rsi, r12
    mov rdx, PROT_READ | PROT_WRITE
    mov rcx, MAP_PRIVATE | MAP_ANONYMOUS
    mov r8, -1
    xor r9, r9
    call hal_mmap
    test rax, rax
    js .fail
    mov r10, rax                    ; mapped base

    xor r8d, r8d
.find_slot:
    cmp r8d, MAX_ARENAS
    jae .no_slot
    movzx eax, byte [arena_used + r8]
    test eax, eax
    jz .slot_found
    inc r8d
    jmp .find_slot

.slot_found:
    mov byte [arena_used + r8], 1
    lea rax, [rel arena_pool]
    imul r9, r8, ARENA_STRUCT_SIZE
    add rax, r9
    mov [rax + ARENA_BASE_PTR_OFF], r10
    mov [rax + ARENA_SIZE_OFF], r12
    mov qword [rax + ARENA_OFFSET_OFF], 0
    pop r12
    ret

.no_slot:
    mov rdi, r10
    mov rsi, r12
    call hal_munmap
.fail:
    xor eax, eax
    pop r12
    ret

; arena_alloc(arena_ptr, size)
; Params:
;   rdi = pointer to Arena struct
;   rsi = requested allocation size in bytes
; Return:
;   rax = pointer to allocated memory, 0 if out of memory/invalid input
; Complexity: O(1)
arena_alloc:
    test rdi, rdi
    jz .fail
    test rsi, rsi
    jz .fail

    mov r8, rsi
    add r8, 7
    jc .fail
    and r8, -8                      ; aligned size

    mov r9, [rdi + ARENA_OFFSET_OFF]
    mov r10, r9
    add r10, r8
    jc .fail
    cmp r10, [rdi + ARENA_SIZE_OFF]
    ja .fail

    mov rax, [rdi + ARENA_BASE_PTR_OFF]
    add rax, r9
    mov [rdi + ARENA_OFFSET_OFF], r10
    ret

.fail:
    xor eax, eax
    ret

; arena_reset(arena_ptr)
; Params:
;   rdi = pointer to Arena struct
; Return:
;   none
; Complexity: O(1)
arena_reset:
    test rdi, rdi
    jz .done
    mov qword [rdi + ARENA_OFFSET_OFF], 0
.done:
    ret

; arena_destroy(arena_ptr)
; Params:
;   rdi = pointer to Arena struct
; Return:
;   rax = 0 on success, negative errno on munmap failure, 0 for null arena
; Complexity: O(MAX_ARENAS)
arena_destroy:
    push rbx
    test rdi, rdi
    jz .null_ok

    mov rbx, rdi                    ; struct ptr
    mov r10, [rbx + ARENA_BASE_PTR_OFF]
    mov r11, [rbx + ARENA_SIZE_OFF]
    test r10, r10
    jz .clear_slot

    mov rdi, r10
    mov rsi, r11
    call hal_munmap
    test rax, rax
    js .ret

.clear_slot:
    mov qword [rbx + ARENA_BASE_PTR_OFF], 0
    mov qword [rbx + ARENA_SIZE_OFF], 0
    mov qword [rbx + ARENA_OFFSET_OFF], 0

    lea r8, [rel arena_pool]
    mov rax, rbx
    sub rax, r8
    xor edx, edx
    mov ecx, ARENA_STRUCT_SIZE
    div rcx
    cmp rax, MAX_ARENAS
    jae .ret
    mov byte [arena_used + rax], 0
.ret:
    pop rbx
    ret

.null_ok:
    xor eax, eax
    pop rbx
    ret

; slab_init(obj_size, count)
; Params:
;   rdi = object size in bytes
;   rsi = number of objects
; Return:
;   rax = pointer to Slab struct on success, 0 on failure
; Complexity: O(count + MAX_SLABS)
slab_init:
    push r12
    push r13
    push r14

    test rsi, rsi
    jz .fail

    mov r13, rsi                    ; count

    mov r12, rdi
    cmp r12, 8
    jae .obj_ok
    mov r12, 8
.obj_ok:
    add r12, 7
    jc .fail
    and r12, -8                     ; aligned obj_size

    mov rax, r12
    mul r13
    test rdx, rdx
    jnz .fail
    test rax, rax
    jz .fail
    add rax, PAGE_SIZE - 1
    jc .fail
    and rax, -PAGE_SIZE
    jz .fail
    mov r14, rax                    ; mmap size

    xor rdi, rdi
    mov rsi, r14
    mov rdx, PROT_READ | PROT_WRITE
    mov rcx, MAP_PRIVATE | MAP_ANONYMOUS
    mov r8, -1
    xor r9, r9
    call hal_mmap
    test rax, rax
    js .fail
    mov r10, rax                    ; mapped base

    ; Initialize free-list in object region.
    xor rcx, rcx
    mov r11, r10
.init_list:
    cmp rcx, r13
    jae .list_done
    mov rax, rcx
    inc rax
    cmp rax, r13
    jae .last_slot
    mov rdx, rax
    imul rdx, r12
    lea rdx, [r10 + rdx]
    mov [r11], rdx
    jmp .next_slot
.last_slot:
    mov qword [r11], 0
.next_slot:
    add r11, r12
    inc rcx
    jmp .init_list
.list_done:

    xor r9d, r9d
.find_slab_slot:
    cmp r9d, MAX_SLABS
    jae .no_slot
    movzx eax, byte [slab_used + r9]
    test eax, eax
    jz .slot_found
    inc r9d
    jmp .find_slab_slot

.slot_found:
    mov byte [slab_used + r9], 1
    lea rax, [rel slab_pool]
    imul rdx, r9, SLAB_STRUCT_SIZE
    add rax, rdx
    mov [rax + SLAB_BASE_PTR_OFF], r10
    mov [rax + SLAB_TOTAL_SIZE_OFF], r14
    mov [rax + SLAB_OBJ_SIZE_OFF], r12
    mov [rax + SLAB_CAPACITY_OFF], r13
    mov [rax + SLAB_FREE_HEAD_OFF], r10
    mov qword [rax + SLAB_ALLOCATED_OFF], 0
    pop r14
    pop r13
    pop r12
    ret

.no_slot:
    mov rdi, r10
    mov rsi, r14
    call hal_munmap
.fail:
    xor eax, eax
    pop r14
    pop r13
    pop r12
    ret

; slab_alloc(slab_ptr)
; Params:
;   rdi = pointer to Slab struct
; Return:
;   rax = pointer to object on success, 0 if slab is full/invalid
; Complexity: O(1)
slab_alloc:
    test rdi, rdi
    jz .fail
    mov rax, [rdi + SLAB_FREE_HEAD_OFF]
    test rax, rax
    jz .fail

    mov rdx, [rax]
    mov [rdi + SLAB_FREE_HEAD_OFF], rdx
    inc qword [rdi + SLAB_ALLOCATED_OFF]
    ret

.fail:
    xor eax, eax
    ret

; slab_free(slab_ptr, obj_ptr)
; Params:
;   rdi = pointer to Slab struct
;   rsi = object pointer to free
; Return:
;   rax = 0 on success, -1 on invalid pointer/slab
; Complexity: O(1)
slab_free:
    test rdi, rdi
    jz .invalid
    test rsi, rsi
    jz .invalid

    mov r8, [rdi + SLAB_BASE_PTR_OFF]
    mov r9, [rdi + SLAB_TOTAL_SIZE_OFF]
    mov r10, r8
    add r10, r9
    jc .invalid

    cmp rsi, r8
    jb .invalid
    cmp rsi, r10
    jae .invalid

    mov rax, rsi
    sub rax, r8
    xor rdx, rdx
    mov rcx, [rdi + SLAB_OBJ_SIZE_OFF]
    div rcx
    test rdx, rdx
    jnz .invalid

    mov rax, [rdi + SLAB_FREE_HEAD_OFF]
    mov [rsi], rax
    mov [rdi + SLAB_FREE_HEAD_OFF], rsi

    cmp qword [rdi + SLAB_ALLOCATED_OFF], 0
    je .ok
    dec qword [rdi + SLAB_ALLOCATED_OFF]
.ok:
    xor eax, eax
    ret

.invalid:
    mov rax, -1
    ret

; slab_destroy(slab_ptr)
; Params:
;   rdi = pointer to Slab struct
; Return:
;   rax = 0 on success, negative errno on munmap failure, 0 for null slab
; Complexity: O(MAX_SLABS)
slab_destroy:
    push rbx
    test rdi, rdi
    jz .null_ok

    mov rbx, rdi
    mov r10, [rbx + SLAB_BASE_PTR_OFF]
    mov r11, [rbx + SLAB_TOTAL_SIZE_OFF]
    test r10, r10
    jz .clear_slot

    mov rdi, r10
    mov rsi, r11
    call hal_munmap
    test rax, rax
    js .ret

.clear_slot:
    mov qword [rbx + SLAB_BASE_PTR_OFF], 0
    mov qword [rbx + SLAB_TOTAL_SIZE_OFF], 0
    mov qword [rbx + SLAB_OBJ_SIZE_OFF], 0
    mov qword [rbx + SLAB_CAPACITY_OFF], 0
    mov qword [rbx + SLAB_FREE_HEAD_OFF], 0
    mov qword [rbx + SLAB_ALLOCATED_OFF], 0

    lea r8, [rel slab_pool]
    mov rax, rbx
    sub rax, r8
    xor edx, edx
    mov ecx, SLAB_STRUCT_SIZE
    div rcx
    cmp rax, MAX_SLABS
    jae .ret
    mov byte [slab_used + rax], 0
.ret:
    pop rbx
    ret

.null_ok:
    xor eax, eax
    pop rbx
    ret
