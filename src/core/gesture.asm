; gesture.asm — touch gesture state machine (MVP: tap, long press, swipe, pinch stub)
%include "src/hal/linux_x86_64/defs.inc"
%include "src/core/gesture.inc"

section .text
global gesture_init
global gesture_process_event
global gesture_get_data
global gesture_reset

; gesture_init(recognizer rdi)
gesture_init:
    push rdi
    call gesture_reset
    pop rdi
    mov dword [rdi + GR_TAP_MAX_DURATION_OFF], 300
    mov dword [rdi + GR_LONG_PRESS_DURATION_OFF], 500
    mov dword [rdi + GR_SWIPE_MIN_DISTANCE_OFF], 50
    mov dword [rdi + GR_PINCH_MIN_DISTANCE_OFF], 20
    mov dword [rdi + GR_PAN_THRESHOLD_OFF], 8
    ret

; gesture_reset(recognizer rdi)
gesture_reset:
    push rbx
    mov rbx, rdi
    mov dword [rbx + GR_STATE_OFF], GESTURE_STATE_IDLE
    mov dword [rbx + GR_ACTIVE_TOUCHES_OFF], 0
    mov dword [rbx + GR_RECOGNIZED_GESTURE_OFF], GESTURE_NONE
    mov dword [rbx + GR_LONG_FIRED_OFF], 0
    mov dword [rbx + GR_SWIPE_TRACK_OFF], 0
    xor ecx, ecx
.clr:
    cmp ecx, GT_MAX_TOUCHES
    jae .clrd
    lea rax, [rbx + GR_TOUCH_DATA_OFF]
    imul rdx, rcx, GT_TOUCH_STRIDE
    add rax, rdx
    mov dword [rax + GT_ID_OFF], -1
    mov dword [rax + GT_IN_USE_OFF], 0
    inc ecx
    jmp .clr
.clrd:
    mov qword [rbx + GR_START_TIME_OFF], 0
    mov qword [rbx + GR_LAST_EVENT_TIME_OFF], 0
    pop rbx
    ret

; touch_find_for_id(rbx=recognizer, esi=id) -> rax slot or 0
touch_find_for_id:
    push rcx
    push rdx
    xor ecx, ecx
.tfi:
    cmp ecx, GT_MAX_TOUCHES
    jae .tfi_nf
    lea rax, [rbx + GR_TOUCH_DATA_OFF]
    imul rdx, rcx, GT_TOUCH_STRIDE
    add rax, rdx
    cmp dword [rax + GT_IN_USE_OFF], 0
    je .tfi_nx
    cmp dword [rax + GT_ID_OFF], esi
    je .tfi_done
.tfi_nx:
    inc ecx
    jmp .tfi
.tfi_nf:
    xor eax, eax
.tfi_done:
    pop rdx
    pop rcx
    ret

; touch_alloc_slot(rbx) -> rax free slot or 0
touch_alloc_slot:
    push rcx
    push rdx
    xor ecx, ecx
.tal:
    cmp ecx, GT_MAX_TOUCHES
    jae .tal_full
    lea rax, [rbx + GR_TOUCH_DATA_OFF]
    imul rdx, rcx, GT_TOUCH_STRIDE
    add rax, rdx
    cmp dword [rax + GT_IN_USE_OFF], 0
    je .tal_done
    inc ecx
    jmp .tal
.tal_full:
    xor eax, eax
.tal_done:
    pop rdx
    pop rcx
    ret

; gesture_process_event(recognizer rdi, event rsi) -> eax gesture type (nonzero when newly recognized)
gesture_process_event:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi
    mov r12, rsi
    test rbx, rbx
    jz .none
    test r12, r12
    jz .none
    xor eax, eax
    mov [rbx + GR_RECOGNIZED_GESTURE_OFF], eax

    mov eax, [r12 + INPUT_EVENT_TYPE_OFF]
    cmp eax, INPUT_TOUCH_DOWN
    je .down
    cmp eax, INPUT_TOUCH_MOVE
    je .move
    cmp eax, INPUT_TOUCH_UP
    je .up
    jmp .none

.down:
    call touch_alloc_slot
    test rax, rax
    jz .none
    mov r13, rax
    mov esi, [r12 + INPUT_EVENT_TOUCH_ID_OFF]
    mov [r13 + GT_ID_OFF], esi
    mov dword [r13 + GT_IN_USE_OFF], 1
    mov eax, [r12 + INPUT_EVENT_MOUSE_X_OFF]
    mov [r13 + GT_START_X_OFF], eax
    mov [r13 + GT_CUR_X_OFF], eax
    mov eax, [r12 + INPUT_EVENT_MOUSE_Y_OFF]
    mov [r13 + GT_START_Y_OFF], eax
    mov [r13 + GT_CUR_Y_OFF], eax
    mov rax, [r12 + INPUT_EVENT_TIMESTAMP_OFF]
    mov [r13 + GT_START_TIME_OFF], rax
    mov [r13 + GT_LAST_TIME_OFF], rax
    inc dword [rbx + GR_ACTIVE_TOUCHES_OFF]
    cmp dword [rbx + GR_ACTIVE_TOUCHES_OFF], 1
    jne .down_multi
    mov rax, [r12 + INPUT_EVENT_TIMESTAMP_OFF]
    mov [rbx + GR_START_TIME_OFF], rax
    mov dword [rbx + GR_STATE_OFF], GESTURE_STATE_POSSIBLE
    mov dword [rbx + GR_LONG_FIRED_OFF], 0
    mov dword [rbx + GR_SWIPE_TRACK_OFF], 0
.down_multi:
    jmp .none

.move:
    mov esi, [r12 + INPUT_EVENT_TOUCH_ID_OFF]
    call touch_find_for_id
    test rax, rax
    jz .none
    mov r13, rax
    cmp dword [r13 + GT_IN_USE_OFF], 0
    je .none
    mov eax, [r12 + INPUT_EVENT_MOUSE_X_OFF]
    mov [r13 + GT_CUR_X_OFF], eax
    mov eax, [r12 + INPUT_EVENT_MOUSE_Y_OFF]
    mov [r13 + GT_CUR_Y_OFF], eax
    mov rax, [r12 + INPUT_EVENT_TIMESTAMP_OFF]
    mov [r13 + GT_LAST_TIME_OFF], rax
    mov [rbx + GR_LAST_EVENT_TIME_OFF], rax

    ; Multi-touch shortcuts for Phase 3 navigation gestures.
    cmp dword [rbx + GR_ACTIVE_TOUCHES_OFF], 2
    je .move_two
    cmp dword [rbx + GR_ACTIVE_TOUCHES_OFF], 3
    je .move_three

    cmp dword [rbx + GR_ACTIVE_TOUCHES_OFF], 1
    jne .none
    mov eax, [r13 + GT_CUR_X_OFF]
    sub eax, [r13 + GT_START_X_OFF]
    mov r14d, eax
    mov eax, r14d
    cdqe
    mov rdi, rax
    neg rax
    cmovs rax, rdi
    mov edi, eax
    mov eax, [r13 + GT_CUR_Y_OFF]
    sub eax, [r13 + GT_START_Y_OFF]
    mov r15d, eax
    mov eax, r15d
    cdqe
    mov rdi, rax
    neg rax
    cmovs rax, rdi
    cmp edi, eax
    cmovb edi, eax
    mov eax, edi

    cmp dword [rbx + GR_SWIPE_TRACK_OFF], 0
    jne .movedone
    cmp eax, [rbx + GR_SWIPE_MIN_DISTANCE_OFF]
    jl .check_long
    mov dword [rbx + GR_SWIPE_TRACK_OFF], 1
    jmp .movedone
.check_long:
    cmp dword [rbx + GR_LONG_FIRED_OFF], 0
    jne .movedone
    mov rax, [r12 + INPUT_EVENT_TIMESTAMP_OFF]
    sub rax, [r13 + GT_START_TIME_OFF]
    cmp eax, 0
    jl .movedone
    cmp eax, [rbx + GR_LONG_PRESS_DURATION_OFF]
    jl .movedone
    cmp edi, 8
    jg .movedone
    mov dword [rbx + GR_LONG_FIRED_OFF], 1
    mov dword [rbx + GR_RECOGNIZED_GESTURE_OFF], GESTURE_LONG_PRESS
    mov dword [rbx + GR_STATE_OFF], GESTURE_STATE_RECOGNIZED
    mov eax, GESTURE_LONG_PRESS
    jmp .ret
.movedone:
    jmp .none

.move_two:
    mov eax, [r13 + GT_CUR_X_OFF]
    sub eax, [r13 + GT_START_X_OFF]
    mov r14d, eax
    mov eax, r14d
    cdqe
    mov rdi, rax
    neg rax
    cmovs rax, rdi
    cmp eax, [rbx + GR_SWIPE_MIN_DISTANCE_OFF]
    jl .none
    mov dword [rbx + GR_RECOGNIZED_GESTURE_OFF], GESTURE_TWO_FINGER_SWIPE
    lea rdi, [rbx + GR_GESTURE_DATA_OFF]
    mov [rdi + GD_DELTA_X_OFF], r14d
    mov dword [rdi + GD_DELTA_Y_OFF], 0
    mov dword [rdi + GD_DURATION_MS_OFF], 0
    mov eax, GESTURE_TWO_FINGER_SWIPE
    jmp .ret

.move_three:
    mov eax, [r13 + GT_CUR_Y_OFF]
    sub eax, [r13 + GT_START_Y_OFF]
    mov r15d, eax
    mov eax, r15d
    cdqe
    mov rdi, rax
    neg rax
    cmovs rax, rdi
    cmp eax, [rbx + GR_SWIPE_MIN_DISTANCE_OFF]
    jl .none
    lea rdi, [rbx + GR_GESTURE_DATA_OFF]
    mov dword [rdi + GD_DELTA_X_OFF], 0
    mov [rdi + GD_DELTA_Y_OFF], r15d
    mov dword [rdi + GD_DURATION_MS_OFF], 0
    cmp r15d, 0
    jg .three_down
    mov dword [rbx + GR_RECOGNIZED_GESTURE_OFF], GESTURE_THREE_FINGER_UP
    mov eax, GESTURE_THREE_FINGER_UP
    jmp .ret
.three_down:
    mov dword [rbx + GR_RECOGNIZED_GESTURE_OFF], GESTURE_THREE_FINGER_DOWN
    mov eax, GESTURE_THREE_FINGER_DOWN
    jmp .ret

.up:
    mov esi, [r12 + INPUT_EVENT_TOUCH_ID_OFF]
    call touch_find_for_id
    test rax, rax
    jz .none
    mov r13, rax
    cmp dword [r13 + GT_IN_USE_OFF], 0
    je .none

    mov eax, [r12 + INPUT_EVENT_MOUSE_X_OFF]
    mov [r13 + GT_CUR_X_OFF], eax
    mov eax, [r12 + INPUT_EVENT_MOUSE_Y_OFF]
    mov [r13 + GT_CUR_Y_OFF], eax

    mov eax, [r13 + GT_CUR_X_OFF]
    sub eax, [r13 + GT_START_X_OFF]
    mov r14d, eax
    mov eax, [r13 + GT_CUR_Y_OFF]
    sub eax, [r13 + GT_START_Y_OFF]
    mov r15d, eax

    mov eax, r14d
    cdqe
    mov rcx, rax
    neg rax
    cmovs rax, rcx
    mov edi, eax

    mov eax, r15d
    cdqe
    mov rcx, rax
    neg rax
    cmovs rax, rcx
    cmp edi, eax
    cmovb edi, eax
    mov r8d, edi

    mov rax, [r12 + INPUT_EVENT_TIMESTAMP_OFF]
    sub rax, [r13 + GT_START_TIME_OFF]
    mov rcx, rax

    mov dword [r13 + GT_IN_USE_OFF], 0
    mov dword [r13 + GT_ID_OFF], -1
    dec dword [rbx + GR_ACTIVE_TOUCHES_OFF]

    cmp dword [rbx + GR_ACTIVE_TOUCHES_OFF], 0
    jne .up_multi
    mov dword [rbx + GR_STATE_OFF], GESTURE_STATE_IDLE

    cmp rcx, 0
    jl .none
    mov eax, ecx
    cmp eax, [rbx + GR_TAP_MAX_DURATION_OFF]
    ja .try_swipe_up
    cmp r8d, [rbx + GR_SWIPE_MIN_DISTANCE_OFF]
    jae .try_swipe_up
    mov dword [rbx + GR_RECOGNIZED_GESTURE_OFF], GESTURE_TAP
    mov eax, GESTURE_TAP
    jmp .fill_data_tap

.try_swipe_up:
    mov eax, r14d
    cdqe
    mov rdx, rax
    neg rax
    cmovs rax, rdx
    mov edi, eax
    mov eax, r15d
    cdqe
    mov rdx, rax
    neg rax
    cmovs rax, rdx
    cmp edi, eax
    jl .vert_sw
    cmp r14d, 0
    jg .sr
    cmp r14d, 0
    jl .sl
    jmp .vert_sw
.vert_sw:
    cmp r15d, 0
    jg .su
    jmp .sdo
.sl:
    mov dword [rbx + GR_RECOGNIZED_GESTURE_OFF], GESTURE_SWIPE_LEFT
    mov eax, GESTURE_SWIPE_LEFT
    jmp .fill_swipe
.sr:
    mov dword [rbx + GR_RECOGNIZED_GESTURE_OFF], GESTURE_SWIPE_RIGHT
    mov eax, GESTURE_SWIPE_RIGHT
    jmp .fill_swipe
.su:
    mov dword [rbx + GR_RECOGNIZED_GESTURE_OFF], GESTURE_SWIPE_UP
    mov eax, GESTURE_SWIPE_UP
    jmp .fill_swipe
.sdo:
.sd:
    mov dword [rbx + GR_RECOGNIZED_GESTURE_OFF], GESTURE_SWIPE_DOWN
    mov eax, GESTURE_SWIPE_DOWN
    jmp .fill_swipe

.fill_data_tap:
    lea rdi, [rbx + GR_GESTURE_DATA_OFF]
    mov dword [rdi + GD_DELTA_X_OFF], r14d
    mov dword [rdi + GD_DELTA_Y_OFF], r15d
    mov dword [rdi + GD_VELOCITY_OFF], 0
    mov dword [rdi + GD_DURATION_MS_OFF], ecx
    jmp .ret

.fill_swipe:
    lea rdi, [rbx + GR_GESTURE_DATA_OFF]
    mov [rdi + GD_DELTA_X_OFF], r14d
    mov [rdi + GD_DELTA_Y_OFF], r15d
    cmp rcx, 0
    je .v0
    mov eax, r8d
    xor edx, edx
    div ecx
    mov [rdi + GD_VELOCITY_OFF], eax
    jmp .vd
.v0:
    mov dword [rdi + GD_VELOCITY_OFF], 0
.vd:
    mov [rdi + GD_DURATION_MS_OFF], ecx
    mov eax, [rbx + GR_RECOGNIZED_GESTURE_OFF]
    jmp .ret

.up_multi:
    jmp .none

.none:
    xor eax, eax
.ret:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; gesture_get_data(recognizer rdi, out rsi)
gesture_get_data:
    test rdi, rdi
    jz .gd_done
    test rsi, rsi
    jz .gd_done
    lea rax, [rdi + GR_GESTURE_DATA_OFF]
    mov rcx, 8
.gd:
    mov rdx, [rax]
    mov [rsi], rdx
    add rax, 8
    add rsi, 8
    dec rcx
    jnz .gd
.gd_done:
    ret
