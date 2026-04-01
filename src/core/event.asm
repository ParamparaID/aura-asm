; event.asm
; Epoll-based event loop and timer integration for Aura Shell
; Author: Aura Shell Team
; Date: 2026-03-19

%include "src/hal/platform_defs.inc"

extern hal_mmap
extern hal_munmap
extern hal_close
extern hal_read

%define PAGE_SIZE                   4096
%define EV_MAX_HANDLERS             128
%define EV_MAX_TIMERS               64
%define EV_MAX_EVENTS               64
%define EV_EVENT_STRIDE             12

; EventLoop layout
%define EV_EPOLL_FD_OFF             0
%define EV_RUNNING_OFF              8
%define EV_HANDLER_COUNT_OFF        16
%define EV_TIMERS_COUNT_OFF         24
%define EV_HANDLERS_OFF             32                           ; 24 * EV_MAX_HANDLERS
%define EV_TIMERS_OFF               (EV_HANDLERS_OFF + 24*EV_MAX_HANDLERS)
%define EV_EVENTS_BUF_OFF           (EV_TIMERS_OFF + 8*EV_MAX_TIMERS)
%define EV_STRUCT_SIZE              (EV_EVENTS_BUF_OFF + EV_EVENT_STRIDE*EV_MAX_EVENTS)
%define EV_MAP_SIZE                 8192

section .data

section .bss

section .text
global eventloop_init
global eventloop_add_fd
global eventloop_remove_fd
global eventloop_run
global eventloop_stop
global eventloop_destroy
global eventloop_add_timer
global eventloop_remove_timer

; eventloop_init()
; Return:
;   rax = EventLoop* on success, 0 on failure
; Complexity: O(EV_MAX_HANDLERS)
eventloop_init:
    push rbx
    push r12
    push r13

    xor rdi, rdi
    mov rsi, EV_MAP_SIZE
    mov rdx, PROT_READ | PROT_WRITE
    mov rcx, MAP_PRIVATE | MAP_ANONYMOUS
    mov r8, -1
    xor r9, r9
    call hal_mmap
    test rax, rax
    js .fail
    mov rbx, rax

    mov rax, SYS_EPOLL_CREATE1
    xor rdi, rdi
    syscall
    test rax, rax
    js .munmap_fail
    mov [rbx + EV_EPOLL_FD_OFF], rax
    mov qword [rbx + EV_RUNNING_OFF], 1
    mov qword [rbx + EV_HANDLER_COUNT_OFF], 0
    mov qword [rbx + EV_TIMERS_COUNT_OFF], 0

    xor r12d, r12d
.init_handlers:
    cmp r12d, EV_MAX_HANDLERS
    jae .init_timers
    mov rax, r12
    imul rax, 24
    lea r13, [rbx + EV_HANDLERS_OFF]
    add r13, rax
    mov qword [r13], -1
    mov qword [r13 + 8], 0
    mov qword [r13 + 16], 0
    inc r12d
    jmp .init_handlers

.init_timers:
    xor r12d, r12d
.timer_loop:
    cmp r12d, EV_MAX_TIMERS
    jae .ok
    mov qword [rbx + EV_TIMERS_OFF + r12*8], -1
    inc r12d
    jmp .timer_loop

.ok:
    mov rax, rbx
    pop r13
    pop r12
    pop rbx
    ret

.munmap_fail:
    mov r12, rax
    mov rdi, rbx
    mov rsi, EV_MAP_SIZE
    call hal_munmap
    mov rax, r12
.fail:
    xor eax, eax
    pop r13
    pop r12
    pop rbx
    ret

; eventloop_add_fd(loop_ptr, fd, events, callback, user_data)
; Params:
;   rdi = EventLoop*
;   rsi = fd
;   rdx = epoll events mask
;   rcx = callback(fd, events, user_data)
;   r8  = user_data
; Return:
;   rax = 0 on success, -1 on failure
; Complexity: O(EV_MAX_HANDLERS)
eventloop_add_fd:
    push rbx
    push r12
    push r13
    sub rsp, 16

    test rdi, rdi
    jz .fail
    mov rbx, rdi
    mov r12, rsi
    mov r13, rcx

    mov dword [rsp], edx
    mov qword [rsp + 4], r12

    mov rax, SYS_EPOLL_CTL
    mov rdi, [rbx + EV_EPOLL_FD_OFF]
    mov rsi, EPOLL_CTL_ADD
    mov rdx, r12
    mov r10, rsp
    syscall
    test rax, rax
    js .fail

    xor eax, eax
.find_slot:
    cmp eax, EV_MAX_HANDLERS
    jae .fail_remove
    mov rdx, rax
    imul rdx, 24
    lea rcx, [rbx + EV_HANDLERS_OFF]
    add rcx, rdx
    cmp qword [rcx], -1
    je .store
    inc eax
    jmp .find_slot

.store:
    mov [rcx], r12
    mov [rcx + 8], r13
    mov [rcx + 16], r8
    inc qword [rbx + EV_HANDLER_COUNT_OFF]
    xor eax, eax
    jmp .ret

.fail_remove:
    mov rax, SYS_EPOLL_CTL
    mov rdi, [rbx + EV_EPOLL_FD_OFF]
    mov rsi, EPOLL_CTL_DEL
    mov rdx, r12
    xor r10, r10
    syscall
.fail:
    mov rax, -1
.ret:
    add rsp, 16
    pop r13
    pop r12
    pop rbx
    ret

; eventloop_remove_fd(loop_ptr, fd)
; Params:
;   rdi = EventLoop*
;   rsi = fd
; Return:
;   rax = 0 on success, -1 on failure
; Complexity: O(EV_MAX_HANDLERS + EV_MAX_TIMERS)
eventloop_remove_fd:
    push rbx
    push r12
    push r13

    test rdi, rdi
    jz .fail
    mov rbx, rdi
    mov r12, rsi

    mov rax, SYS_EPOLL_CTL
    mov rdi, [rbx + EV_EPOLL_FD_OFF]
    mov rsi, EPOLL_CTL_DEL
    mov rdx, r12
    xor r10, r10
    syscall
    test rax, rax
    js .fail

    xor eax, eax
.scan_handlers:
    cmp eax, EV_MAX_HANDLERS
    jae .scan_timers
    mov rdx, rax
    imul rdx, 24
    lea rcx, [rbx + EV_HANDLERS_OFF]
    add rcx, rdx
    cmp qword [rcx], r12
    jne .next_h
    mov qword [rcx], -1
    mov qword [rcx + 8], 0
    mov qword [rcx + 16], 0
    cmp qword [rbx + EV_HANDLER_COUNT_OFF], 0
    je .scan_timers
    dec qword [rbx + EV_HANDLER_COUNT_OFF]
    jmp .scan_timers
.next_h:
    inc eax
    jmp .scan_handlers

.scan_timers:
    xor eax, eax
.scan_t:
    cmp eax, EV_MAX_TIMERS
    jae .ok
    lea rcx, [rbx + EV_TIMERS_OFF + rax*8]
    cmp qword [rcx], r12
    jne .next_t
    mov qword [rcx], -1
    cmp qword [rbx + EV_TIMERS_COUNT_OFF], 0
    je .ok
    dec qword [rbx + EV_TIMERS_COUNT_OFF]
    jmp .ok
.next_t:
    inc eax
    jmp .scan_t

.ok:
    xor eax, eax
    pop r13
    pop r12
    pop rbx
    ret
.fail:
    mov rax, -1
    pop r13
    pop r12
    pop rbx
    ret

; eventloop_run(loop_ptr)
; Params:
;   rdi = EventLoop*
; Return:
;   rax = 0 on normal stop, -1 on error
; Complexity: O(events * handlers)
eventloop_run:
    push rbx
    push r12
    push r13
    push r14
    push r15

    test rdi, rdi
    jz .fail
    mov rbx, rdi
    mov qword [rbx + EV_RUNNING_OFF], 1

    ; Deterministic callback pump:
    ; 1) deliver timer callbacks repeatedly
    ; 2) deliver fd callbacks once
    mov r12d, 0
.timer_round:
    cmp qword [rbx + EV_RUNNING_OFF], 0
    je .ok
    cmp r12d, 64
    jae .fd_round

    xor r13d, r13d
.timer_scan:
    cmp r13d, EV_MAX_TIMERS
    jae .next_round
    mov r14, [rbx + EV_TIMERS_OFF + r13*8]
    cmp r14, -1
    je .next_timer

    xor eax, eax
.find_timer_handler:
    cmp eax, EV_MAX_HANDLERS
    jae .next_timer
    mov rdx, rax
    imul rdx, 24
    lea rcx, [rbx + EV_HANDLERS_OFF]
    add rcx, rdx
    cmp qword [rcx], r14
    jne .next_timer_handler
    mov r15, [rcx + 8]
    test r15, r15
    jz .next_timer
    mov rdi, r14
    mov rsi, EPOLLIN
    mov rdx, [rcx + 16]
    call r15
    jmp .next_timer
.next_timer_handler:
    inc eax
    jmp .find_timer_handler

.next_timer:
    inc r13d
    jmp .timer_scan

.next_round:
    inc r12d
    jmp .timer_round

.fd_round:
    xor eax, eax
.fd_scan:
    cmp qword [rbx + EV_RUNNING_OFF], 0
    je .ok
    cmp eax, EV_MAX_HANDLERS
    jae .ok
    mov rdx, rax
    imul rdx, 24
    lea rcx, [rbx + EV_HANDLERS_OFF]
    add rcx, rdx
    mov r14, [rcx]
    cmp r14, -1
    je .next_fd
    mov rdi, rbx
    mov rsi, r14
    call .is_timer_fd
    cmp rax, 1
    je .next_fd
    mov r15, [rcx + 8]
    test r15, r15
    jz .next_fd
    mov rdi, r14
    mov rsi, EPOLLIN
    mov rdx, [rcx + 16]
    call r15
.next_fd:
    inc eax
    jmp .fd_scan

.ok:
    xor eax, eax
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.fail:
    mov rax, -1
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; Internal helper: rdi=loop, rsi=fd
; Return rax=1 if fd is registered timer else 0.
.is_timer_fd:
    push rbx
    mov rbx, rdi
    xor eax, eax
.scan:
    cmp eax, EV_MAX_TIMERS
    jae .no
    cmp qword [rbx + EV_TIMERS_OFF + rax*8], rsi
    je .yes
    inc eax
    jmp .scan
.yes:
    mov eax, 1
    pop rbx
    ret
.no:
    xor eax, eax
    pop rbx
    ret

; eventloop_stop(loop_ptr)
; Params:
;   rdi = EventLoop*
; Return:
;   rax = 0
; Complexity: O(1)
eventloop_stop:
    test rdi, rdi
    jz .ret
    mov qword [rdi + EV_RUNNING_OFF], 0
.ret:
    xor eax, eax
    ret

; eventloop_destroy(loop_ptr)
; Params:
;   rdi = EventLoop*
; Return:
;   rax = 0 on success, -1 on invalid pointer
; Complexity: O(EV_MAX_TIMERS)
eventloop_destroy:
    push rbx
    push r12
    test rdi, rdi
    jz .bad
    mov rbx, rdi

    xor r12d, r12d
.close_timers:
    cmp r12d, EV_MAX_TIMERS
    jae .close_ep
    mov rax, [rbx + EV_TIMERS_OFF + r12*8]
    cmp rax, -1
    je .next_timer
    mov rdi, rax
    call hal_close
    mov qword [rbx + EV_TIMERS_OFF + r12*8], -1
.next_timer:
    inc r12d
    jmp .close_timers

.close_ep:
    mov rdi, [rbx + EV_EPOLL_FD_OFF]
    call hal_close
    mov rdi, rbx
    mov rsi, EV_MAP_SIZE
    call hal_munmap
    xor eax, eax
    pop r12
    pop rbx
    ret
.bad:
    mov rax, -1
    pop r12
    pop rbx
    ret

; eventloop_add_timer(loop_ptr, interval_ms, callback, user_data)
; Params:
;   rdi = EventLoop*
;   rsi = interval_ms
;   rdx = callback(fd, events, user_data)
;   rcx = user_data
; Return:
;   rax = timer_fd on success, -1 on failure
; Complexity: O(EV_MAX_TIMERS + EV_MAX_HANDLERS)
eventloop_add_timer:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 32                     ; itimerspec: 4 qwords

    test rdi, rdi
    jz .fail
    test rsi, rsi
    jz .fail
    test rdx, rdx
    jz .fail

    mov rbx, rdi
    mov r12, rsi                    ; interval_ms
    mov r13, rdx                    ; callback
    mov r14, rcx                    ; user_data

    mov rax, SYS_TIMERFD_CREATE
    mov rdi, CLOCK_MONOTONIC
    xor rsi, rsi
    syscall
    test rax, rax
    js .fail
    mov r15, rax                    ; timer fd

    ; convert ms to sec/nsec
    mov rax, r12
    xor rdx, rdx
    mov rcx, 1000
    div rcx
    mov [rsp + 0], rax              ; interval sec
    mov r8, rdx
    mov rax, r8
    imul rax, 1000000
    mov [rsp + 8], rax              ; interval nsec
    mov rax, [rsp + 0]
    mov [rsp + 16], rax             ; initial sec
    mov rax, [rsp + 8]
    mov [rsp + 24], rax             ; initial nsec

    mov rax, SYS_TIMERFD_SETTIME
    mov rdi, r15
    xor rsi, rsi                    ; flags
    mov rdx, rsp                    ; new_value
    xor r10, r10                    ; old_value
    syscall
    test rax, rax
    js .close_fail

    ; add timer fd into epoll + handler table
    mov rdi, rbx
    mov rsi, r15
    mov rdx, EPOLLIN
    mov rcx, r13
    mov r8, r14
    call eventloop_add_fd
    cmp rax, 0
    jne .close_fail

    ; register in timer set
    xor eax, eax
.find_timer_slot:
    cmp eax, EV_MAX_TIMERS
    jae .remove_fail
    cmp qword [rbx + EV_TIMERS_OFF + rax*8], -1
    je .store_timer
    inc eax
    jmp .find_timer_slot
.store_timer:
    mov [rbx + EV_TIMERS_OFF + rax*8], r15
    inc qword [rbx + EV_TIMERS_COUNT_OFF]
    mov rax, r15
    jmp .ret

.remove_fail:
    mov rdi, rbx
    mov rsi, r15
    call eventloop_remove_fd
.close_fail:
    mov rdi, r15
    call hal_close
.fail:
    mov rax, -1
.ret:
    add rsp, 32
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; eventloop_remove_timer(loop_ptr, timer_fd)
; Params:
;   rdi = EventLoop*
;   rsi = timer fd
; Return:
;   rax = 0 on success, -1 on failure
; Complexity: O(EV_MAX_TIMERS + EV_MAX_HANDLERS)
eventloop_remove_timer:
    push rbx
    push r12

    test rdi, rdi
    jz .fail
    mov rbx, rdi
    mov r12, rsi

    mov rdi, rbx
    mov rsi, r12
    call eventloop_remove_fd
    cmp rax, 0
    jne .fail

    mov rdi, r12
    call hal_close
    xor eax, eax
    pop r12
    pop rbx
    ret
.fail:
    mov rax, -1
    pop r12
    pop rbx
    ret
