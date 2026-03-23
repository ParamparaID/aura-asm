; output.asm — wl_output bind + minimal dispatch
%include "src/compositor/compositor.inc"

extern proto_send_event

section .text
global output_on_bind
global output_dispatch_output

; output_on_bind(client, output_id, width, height)
output_on_bind:
    push rbx
    push r12
    push r13
    sub rsp, 96
    mov rbx, rdi
    mov r12d, edx                      ; width
    mov r13d, ecx                      ; height

    ; wl_output.geometry: x,y,pw,ph,subpixel,make,model,transform
    ; For MVP we report origin + empty make/model.
    lea rdi, [rsp]
    mov ecx, 24
    xor eax, eax
    rep stosd
    mov dword [rsp + 0], 0            ; x
    mov dword [rsp + 4], 0            ; y
    mov dword [rsp + 8], 340          ; physical width mm
    mov dword [rsp + 12], 190         ; physical height mm
    mov dword [rsp + 16], 0           ; subpixel unknown
    mov dword [rsp + 20], 1           ; make len including NUL
    mov dword [rsp + 28], 1           ; model len including NUL
    mov dword [rsp + 36], 0           ; transform normal
    mov rdi, rbx
    ; esi already output_id
    xor edx, edx                      ; geometry opcode
    lea rcx, [rsp]
    mov r8d, 40
    call proto_send_event

    ; wl_output.mode: flags,current width,height,refresh
    mov dword [rsp + 0], 1            ; CURRENT
    mov dword [rsp + 4], r12d
    mov dword [rsp + 8], r13d
    mov dword [rsp + 12], 60000       ; 60Hz
    mov rdi, rbx
    mov edx, 1                        ; mode opcode
    lea rcx, [rsp]
    mov r8d, 16
    call proto_send_event

    ; wl_output.scale(1)
    mov dword [rsp + 0], 1
    mov rdi, rbx
    mov edx, 3
    lea rcx, [rsp]
    mov r8d, 4
    call proto_send_event

    ; wl_output.done()
    mov rdi, rbx
    mov edx, 2
    xor ecx, ecx
    xor r8d, r8d
    call proto_send_event

    add rsp, 96
    pop r13
    pop r12
    pop rbx
    ret

; output_dispatch_output(client, object_id, opcode, payload, payload_len)
; wl_output has no requests in core protocol for our version: ignore safely.
output_dispatch_output:
    ret
