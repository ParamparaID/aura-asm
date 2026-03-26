; shell macros manager (MVP)
%include "src/hal/linux_x86_64/defs.inc"

extern arena_alloc

section .text
global macro_init
global macro_start_recording
global macro_record_event
global macro_stop_recording
global macro_play
global macro_play_tick
global macro_stop_playing
global macro_save
global macro_load
global macro_list_count
global macro_delete
global macro_dequeue_injected

%define MACRO_MAX_COUNT      64
%define MACRO_NAME_MAX       64
%define MACRO_EVENT_CAP      1024

%define MGR_ARENA_OFF        0
%define MGR_COUNT_OFF        8
%define MGR_RECORDING_OFF    12
%define MGR_CUR_IDX_OFF      16
%define MGR_PLAYING_OFF      20
%define MGR_PLAY_IDX_OFF     24
%define MGR_PLAY_POS_OFF     28
%define MGR_INJ_HEAD_OFF     32
%define MGR_INJ_TAIL_OFF     36
%define MGR_NAMES_OFF        40
%define MGR_COUNTS_OFF       (MGR_NAMES_OFF + MACRO_MAX_COUNT*MACRO_NAME_MAX)
%define MGR_EVENTS_OFF       (MGR_COUNTS_OFF + MACRO_MAX_COUNT*4)
%define MGR_INJECTED_OFF     (MGR_EVENTS_OFF + MACRO_MAX_COUNT*MACRO_EVENT_CAP*8)
%define MGR_SIZE             (MGR_INJECTED_OFF + MACRO_EVENT_CAP*8)

section .bss
    macro_snap_count         resd 1
    macro_snap_names         resb MACRO_MAX_COUNT * MACRO_NAME_MAX
    macro_snap_counts        resd MACRO_MAX_COUNT
    macro_snap_events        resq MACRO_MAX_COUNT * MACRO_EVENT_CAP

section .text

macro_streq:
    ; rdi a, rsi b -> eax 1/0
    xor ecx, ecx
.l:
    mov al, [rdi + rcx]
    cmp al, [rsi + rcx]
    jne .n
    test al, al
    je .y
    inc ecx
    jmp .l
.y:
    mov eax, 1
    ret
.n:
    xor eax, eax
    ret

macro_name_ptr:
    ; (mgr rdi, idx esi) -> rax
    mov eax, esi
    imul eax, MACRO_NAME_MAX
    lea rax, [rdi + MGR_NAMES_OFF + rax]
    ret

macro_count_ptr:
    ; (mgr rdi, idx esi) -> rax
    mov eax, esi
    lea rax, [rdi + MGR_COUNTS_OFF + rax*4]
    ret

macro_events_ptr:
    ; (mgr rdi, idx esi) -> rax
    mov eax, esi
    imul eax, MACRO_EVENT_CAP*8
    lea rax, [rdi + MGR_EVENTS_OFF + rax]
    ret

macro_find_idx:
    ; (mgr rdi, name rsi) -> eax idx/-1
    push rbx
    push r12
    push r13
    mov r13, rdi
    mov r12, rsi
    xor ebx, ebx
.l:
    cmp ebx, [r13 + MGR_COUNT_OFF]
    jae .n
    mov esi, ebx
    mov rdi, r13
    call macro_name_ptr
    mov rdi, rax
    mov rsi, r12
    call macro_streq
    cmp eax, 1
    je .y
    inc ebx
    jmp .l
.y:
    mov eax, ebx
    pop r13
    pop r12
    pop rbx
    ret
.n:
    mov eax, -1
    pop r13
    pop r12
    pop rbx
    ret

macro_init:
    ; (arena rdi) -> mgr* or 0
    push rbx
    mov rbx, rdi
    test rbx, rbx
    jz .f
    mov rdi, rbx
    mov rsi, MGR_SIZE
    call arena_alloc
    test rax, rax
    jz .f
    mov [rax + MGR_ARENA_OFF], rbx
    mov dword [rax + MGR_COUNT_OFF], 0
    mov dword [rax + MGR_RECORDING_OFF], 0
    mov dword [rax + MGR_CUR_IDX_OFF], -1
    mov dword [rax + MGR_PLAYING_OFF], 0
    mov dword [rax + MGR_PLAY_IDX_OFF], -1
    mov dword [rax + MGR_PLAY_POS_OFF], 0
    mov dword [rax + MGR_INJ_HEAD_OFF], 0
    mov dword [rax + MGR_INJ_TAIL_OFF], 0
    pop rbx
    ret
.f:
    xor eax, eax
    pop rbx
    ret

macro_start_recording:
    ; (mgr rdi, name rsi) -> 0/-1
    push rbx
    push r12
    mov rbx, rdi
    mov r12, rsi
    test rbx, rbx
    jz .f
    test r12, r12
    jz .f
    cmp dword [rbx + MGR_RECORDING_OFF], 0
    jne .f
    mov rdi, rbx
    mov rsi, r12
    call macro_find_idx
    cmp eax, -1
    jne .have
    mov eax, [rbx + MGR_COUNT_OFF]
    cmp eax, MACRO_MAX_COUNT
    jae .f
    inc dword [rbx + MGR_COUNT_OFF]
.have:
    mov [rbx + MGR_CUR_IDX_OFF], eax
    mov dword [rbx + MGR_RECORDING_OFF], 1
    ; copy name
    mov esi, eax
    mov rdi, rbx
    call macro_name_ptr
    mov r8, rax
    xor ecx, ecx
.cp:
    cmp ecx, MACRO_NAME_MAX - 1
    jae .term
    mov al, [r12 + rcx]
    test al, al
    je .term
    mov [r8 + rcx], al
    inc ecx
    jmp .cp
.term:
    mov byte [r8 + rcx], 0
    mov esi, [rbx + MGR_CUR_IDX_OFF]
    mov rdi, rbx
    call macro_count_ptr
    mov dword [rax], 0
    xor eax, eax
    pop r12
    pop rbx
    ret
.f:
    mov eax, -1
    pop r12
    pop rbx
    ret

macro_record_event:
    ; (mgr rdi, event_ptr rsi) -> 0/-1
    push rbx
    push r12
    mov rbx, rdi
    mov r12, rsi
    test rbx, rbx
    jz .f
    test r12, r12
    jz .f
    cmp dword [rbx + MGR_RECORDING_OFF], 1
    jne .f
    mov esi, [rbx + MGR_CUR_IDX_OFF]
    cmp esi, 0
    jl .f
    mov rdi, rbx
    call macro_count_ptr
    mov ecx, [rax]
    cmp ecx, MACRO_EVENT_CAP
    jae .f
    mov esi, [rbx + MGR_CUR_IDX_OFF]
    mov rdi, rbx
    call macro_events_ptr
    mov r8, [r12]
    mov [rax + rcx*8], r8
    inc ecx
    mov esi, [rbx + MGR_CUR_IDX_OFF]
    mov rdi, rbx
    call macro_count_ptr
    mov [rax], ecx
    xor eax, eax
    pop r12
    pop rbx
    ret
.f:
    mov eax, -1
    pop r12
    pop rbx
    ret

macro_stop_recording:
    test rdi, rdi
    jz .f
    mov dword [rdi + MGR_RECORDING_OFF], 0
    mov dword [rdi + MGR_CUR_IDX_OFF], -1
    xor eax, eax
    ret
.f:
    mov eax, -1
    ret

macro_play:
    ; (mgr rdi, name rsi) -> 0/-1
    push rbx
    mov rbx, rdi
    test rbx, rbx
    jz .f
    test rsi, rsi
    jz .f
    call macro_find_idx
    cmp eax, -1
    je .f
    mov dword [rbx + MGR_PLAYING_OFF], 1
    mov [rbx + MGR_PLAY_IDX_OFF], eax
    mov dword [rbx + MGR_PLAY_POS_OFF], 0
    xor eax, eax
    pop rbx
    ret
.f:
    mov eax, -1
    pop rbx
    ret

macro_play_tick:
    ; (mgr rdi) -> 1 emitted, 0 no-op, -1 err
    push rbx
    mov rbx, rdi
    test rbx, rbx
    jz .f
    cmp dword [rbx + MGR_PLAYING_OFF], 1
    jne .n
    mov esi, [rbx + MGR_PLAY_IDX_OFF]
    cmp esi, 0
    jl .n
    mov rdi, rbx
    call macro_count_ptr
    mov ecx, [rax]
    mov edx, [rbx + MGR_PLAY_POS_OFF]
    cmp edx, ecx
    jae .stop
    mov esi, [rbx + MGR_PLAY_IDX_OFF]
    mov rdi, rbx
    call macro_events_ptr
    mov r8, [rax + rdx*8]
    mov ecx, [rbx + MGR_INJ_TAIL_OFF]
    cmp ecx, MACRO_EVENT_CAP
    jae .n
    mov [rbx + MGR_INJECTED_OFF + rcx*8], r8
    inc ecx
    mov [rbx + MGR_INJ_TAIL_OFF], ecx
    inc dword [rbx + MGR_PLAY_POS_OFF]
    mov eax, 1
    pop rbx
    ret
.stop:
    mov dword [rbx + MGR_PLAYING_OFF], 0
.n:
    xor eax, eax
    pop rbx
    ret
.f:
    mov eax, -1
    pop rbx
    ret

macro_stop_playing:
    test rdi, rdi
    jz .f
    mov dword [rdi + MGR_PLAYING_OFF], 0
    mov dword [rdi + MGR_PLAY_IDX_OFF], -1
    mov dword [rdi + MGR_PLAY_POS_OFF], 0
    xor eax, eax
    ret
.f:
    mov eax, -1
    ret

macro_dequeue_injected:
    ; (mgr rdi, out rsi[qword]) -> 1/0
    test rdi, rdi
    jz .n
    test rsi, rsi
    jz .n
    mov eax, [rdi + MGR_INJ_HEAD_OFF]
    cmp eax, [rdi + MGR_INJ_TAIL_OFF]
    jae .n
    mov r8, [rdi + MGR_INJECTED_OFF + rax*8]
    mov [rsi], r8
    inc eax
    mov [rdi + MGR_INJ_HEAD_OFF], eax
    mov eax, 1
    ret
.n:
    xor eax, eax
    ret

macro_list_count:
    test rdi, rdi
    jz .n
    mov eax, [rdi + MGR_COUNT_OFF]
    ret
.n:
    xor eax, eax
    ret

macro_delete:
    ; (mgr rdi, name rsi) -> 0/-1
    push rbx
    mov rbx, rdi
    test rbx, rbx
    jz .f
    test rsi, rsi
    jz .f
    mov rdi, rbx
    call macro_find_idx
    cmp eax, -1
    je .f
    dec dword [rbx + MGR_COUNT_OFF]
    xor eax, eax
    pop rbx
    ret
.f:
    mov eax, -1
    pop rbx
    ret

macro_save:
    ; (mgr rdi, path rsi) -> 0/-1
    mov rax, rdi
    test rax, rax
    jz .f
    mov edx, [rax + MGR_COUNT_OFF]
    mov [rel macro_snap_count], edx
    lea rsi, [rax + MGR_NAMES_OFF]
    lea rdi, [rel macro_snap_names]
    mov ecx, (MACRO_MAX_COUNT * MACRO_NAME_MAX)
    rep movsb
    lea rsi, [rax + MGR_COUNTS_OFF]
    lea rdi, [rel macro_snap_counts]
    mov ecx, MACRO_MAX_COUNT
    rep movsd
    lea rsi, [rax + MGR_EVENTS_OFF]
    lea rdi, [rel macro_snap_events]
    mov ecx, MACRO_MAX_COUNT * MACRO_EVENT_CAP
    rep movsq
    xor eax, eax
    ret
.f:
    mov eax, -1
    ret

macro_load:
    ; (mgr rdi, path rsi) -> 0/-1
    push rbx
    mov rbx, rdi
    test rbx, rbx
    jz .f
    mov eax, [rel macro_snap_count]
    cmp eax, MACRO_MAX_COUNT
    jbe .okc
    mov eax, MACRO_MAX_COUNT
.okc:
    mov [rbx + MGR_COUNT_OFF], eax
    lea rsi, [rel macro_snap_names]
    lea rdi, [rbx + MGR_NAMES_OFF]
    mov ecx, (MACRO_MAX_COUNT * MACRO_NAME_MAX)
    rep movsb
    lea rsi, [rel macro_snap_counts]
    lea rdi, [rbx + MGR_COUNTS_OFF]
    mov ecx, MACRO_MAX_COUNT
    rep movsd
    lea rsi, [rel macro_snap_events]
    lea rdi, [rbx + MGR_EVENTS_OFF]
    mov ecx, MACRO_MAX_COUNT * MACRO_EVENT_CAP
    rep movsq
    xor eax, eax
    pop rbx
    ret
.f:
    mov eax, -1
    pop rbx
    ret
