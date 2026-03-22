; shm.asm — wl_shm / wl_shm_pool / wl_buffer (Phase 3)
%include "src/hal/linux_x86_64/defs.inc"
%include "src/compositor/compositor.inc"

extern arena_alloc
extern client_resource_add
extern client_resource_find
extern hal_mmap
extern hal_munmap
extern hal_close
extern proto_send_event

section .text
global shm_dispatch_shm
global shm_dispatch_shm_pool
global shm_buffer_release_for_client

; shm_buffer_release_for_client(client, buffer_object_id)
shm_buffer_release_for_client:
    push rbx
    mov rbx, rdi
    mov esi, esi
    mov rdi, rbx
    xor edx, edx                 ; opcode 0 = release
    xor ecx, ecx                 ; no args
    xor r8, r8
    call proto_send_event
    pop rbx
    ret

; shm_dispatch_shm(client, object_id, opcode, payload, payload_len)
shm_dispatch_shm:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi
    mov r12d, edx                ; opcode
    mov r13, rcx                 ; payload
    mov r14d, r8d                ; payload_len

    cmp r12d, 0                  ; create_pool
    jne .out
    cmp r14d, 8
    jb .out

    mov r15d, dword [rbx + CC_PENDING_FD_OFF]
    mov dword [rbx + CC_PENDING_FD_OFF], -1
    cmp r15d, 0
    jl .out

    mov r12d, dword [r13 + 0]    ; new pool id
    mov r14d, dword [r13 + 4]    ; pool size
    test r14d, r14d
    jz .bad_fd

    xor rdi, rdi
    movsxd rsi, r14d
    mov rdx, PROT_READ
    mov rcx, MAP_SHARED
    mov r8d, r15d
    xor r9, r9
    call hal_mmap
    test rax, rax
    js .bad_fd
    push r12
    mov r12, rax                 ; mapped ptr

    mov rdi, [rbx + CC_SERVER_OFF]
    mov rdi, [rdi + CS_ARENA_OFF]
    mov rsi, POOL_STRUCT_SIZE
    call arena_alloc
    test rax, rax
    jz .unmap_fail
    mov r13, rax
    mov rdi, r13
    mov ecx, POOL_STRUCT_SIZE / 4
    xor eax, eax
    rep stosd

    pop rax                      ; new pool id
    mov dword [r13 + POOL_ID_OFF], eax
    mov qword [r13 + POOL_CLIENT_OFF], rbx
    mov dword [r13 + POOL_FD_OFF], r15d
    mov qword [r13 + POOL_SIZE_OFF], r14
    mov qword [r13 + POOL_DATA_OFF], r12

    mov rdi, rbx
    mov esi, dword [r13 + POOL_ID_OFF]
    mov edx, RESOURCE_SHM_POOL
    mov rcx, r13
    call client_resource_add
    jmp .out

.unmap_fail:
    mov rdi, r12
    movsxd rsi, r14d
    call hal_munmap
.bad_fd:
    movsx rdi, r15d
    cmp rdi, 0
    jl .out
    call hal_close
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; shm_dispatch_shm_pool(client, object_id, opcode, payload, payload_len)
shm_dispatch_shm_pool:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi
    mov r12d, esi                ; pool object id
    mov r13d, edx                ; opcode
    mov r14, rcx                 ; payload
    mov r15d, r8d                ; payload len

    mov rdi, rbx
    mov esi, r12d
    call client_resource_find
    test rax, rax
    jz .out
    cmp dword [rax + RES_TYPE_OFF], RESOURCE_SHM_POOL
    jne .out
    mov r12, [rax + RES_DATA_OFF]    ; ShmPool* — keep in r12

    cmp r13d, 0
    je .create_buffer
    cmp r13d, 2
    je .resize
    jmp .out

.create_buffer:
    cmp r15d, 24
    jb .out

    mov r13d, dword [r14 + 0]    ; new buffer id
    mov ecx, dword [r14 + 4]     ; offset
    mov esi, dword [r14 + 8]     ; width (must survive mul — mul clobbers rdx)
    mov r8d, dword [r14 + 12]    ; height
    mov r9d, dword [r14 + 16]    ; stride
    mov r10d, dword [r14 + 20]   ; format

    mov rax, r8
    mul r9
    test rdx, rdx
    jnz .out
    add rax, rcx
    jc .out
    cmp rax, [r12 + POOL_SIZE_OFF]
    ja .out

    push r10
    push r9
    push r8
    push rsi
    push rcx
    mov rdi, [rbx + CC_SERVER_OFF]
    mov rdi, [rdi + CS_ARENA_OFF]
    mov rsi, BUF_STRUCT_SIZE
    call arena_alloc
    test rax, rax
    jz .pop5_out
    mov r15, rax
    push rdi
    mov rdi, r15
    mov ecx, BUF_STRUCT_SIZE / 4
    xor eax, eax
    rep stosd
    pop rdi
    pop rcx
    pop rdx
    pop r8
    pop r9
    pop r10

    mov dword [r15 + BUF_ID_OFF], r13d
    mov qword [r15 + BUF_POOL_OFF], r12
    mov dword [r15 + BUF_OFFSET_OFF], ecx
    mov dword [r15 + BUF_WIDTH_OFF], edx
    mov dword [r15 + BUF_HEIGHT_OFF], r8d
    mov dword [r15 + BUF_STRIDE_OFF], r9d
    mov dword [r15 + BUF_FORMAT_OFF], r10d
    mov dword [r15 + BUF_BUSY_OFF], 0

    mov rsi, [r12 + POOL_DATA_OFF]
    movsxd rdi, ecx
    add rsi, rdi
    mov qword [r15 + BUF_PIXELS_OFF], rsi

    mov rdi, rbx
    mov esi, dword [r15 + BUF_ID_OFF]
    mov edx, RESOURCE_BUFFER
    mov rcx, r15
    call client_resource_add
    jmp .out

.pop5_out:
    add rsp, 40
    jmp .out

.resize:
    cmp r15d, 4
    jb .out
    mov eax, dword [r14 + 0]
    mov r13d, eax
    test r13d, r13d
    jz .out

    mov rdi, [r12 + POOL_DATA_OFF]
    test rdi, rdi
    jz .only_map
    mov rsi, [r12 + POOL_SIZE_OFF]
    call hal_munmap
    mov qword [r12 + POOL_DATA_OFF], 0
.only_map:
    xor rdi, rdi
    movsxd rsi, r13d
    mov rdx, PROT_READ
    mov rcx, MAP_SHARED
    mov r8d, dword [r12 + POOL_FD_OFF]
    xor r9, r9
    call hal_mmap
    test rax, rax
    js .out
    mov qword [r12 + POOL_DATA_OFF], rax
    mov qword [r12 + POOL_SIZE_OFF], r13

.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
