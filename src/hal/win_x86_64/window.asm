; window.asm - Win32 window backend (GDI + message input bridge)
%include "src/hal/win_x86_64/defs.inc"
%include "src/canvas/canvas.inc"

extern bootstrap_init
extern input_push_event

extern win32_VirtualAlloc
extern win32_VirtualFree
extern win32_GetModuleHandleA
extern win32_LoadCursorA
extern win32_RegisterClassExA
extern win32_CreateWindowExA
extern win32_DefWindowProcA
extern win32_DestroyWindow
extern win32_ShowWindow
extern win32_UpdateWindow
extern win32_PeekMessageA
extern win32_TranslateMessage
extern win32_DispatchMessageA
extern win32_PostQuitMessage
extern win32_GetDC
extern win32_ReleaseDC
extern win32_GetSystemMetrics
extern win32_RegisterTouchWindow
extern win32_RegisterHotKey
extern win32_EnumWindows
extern win32_SetWindowPos
extern win32_SetWindowLongPtrA
extern win32_GetTickCount64
extern win32_SendMessageA

extern win32_CreateCompatibleDC
extern win32_CreateDIBSection
extern win32_SelectObject
extern win32_BitBlt
extern win32_DeleteObject
extern win32_DeleteDC
extern win32_SetBkMode
extern win32_SetTextColor
extern win32_TextOutA
extern win32_TextOutW
extern win32_MultiByteToWideChar

section .data
    win_class_name               db "AuraShellClass",0
    win_class_registered         dd 0
    win_shell_replacement_mode   dd 0
    win_default_title            db "Aura Shell",0

section .bss
    win_single_ctx               resq 1
    win_expected_hwnd            resq 1
    win_cached_hdc               resq 1
    win_tmp_msg                  resb MSG_SIZE
    win_tmp_event                resb 64

; Window object
%define W_HWND_OFF               0
%define W_MEMDC_OFF              8
%define W_HBITMAP_OFF            16
%define W_DIB_PTR_OFF            24
%define W_WIDTH_OFF              32
%define W_HEIGHT_OFF             36
%define W_SHOULD_CLOSE_OFF       40
%define W_PAD_OFF                44
%define W_CANVAS_OFF             48
%define W_STRUCT_SIZE            (W_CANVAS_OFF + CV_STRUCT_SIZE)

; InputEvent offsets/types mirror src/core/input.asm
%define IE_TYPE_OFF              0
%define IE_TS_OFF                8
%define IE_KEY_CODE_OFF          16
%define IE_KEY_STATE_OFF         20
%define IE_MODS_OFF              24
%define IE_MOUSE_X_OFF           28
%define IE_MOUSE_Y_OFF           32
%define IE_SCROLL_DX_OFF         36
%define IE_SCROLL_DY_OFF         40
%define IE_TOUCH_ID_OFF          44
%define INPUT_KEY                1
%define INPUT_MOUSE_MOVE         2
%define INPUT_MOUSE_BUTTON       3
%define INPUT_TOUCH_DOWN         4
%define INPUT_TOUCH_UP           5
%define INPUT_TOUCH_MOVE         6
%define INPUT_SCROLL             7
%define KEY_RELEASED             0
%define KEY_PRESSED              1
%define MOUSE_LEFT               0x110
%define MOUSE_RIGHT              0x111
%define MB_ERR_INVALID_CHARS     0x00000008

section .text
global window_create
global window_create_win32
global window_present
global window_present_win32
global window_get_canvas
global window_process_events
global window_should_close
global window_destroy
global aura_wnd_proc
global window_set_shell_replacement_mode
global window_register_shell_hotkey
global window_enum_windows
global window_send_test_keydown
global window_manage_hwnd
global window_subclass_hwnd
global window_draw_text_overlay

win_push_event:
    ; rdi=event_type, rsi=key/button, rdx=state, rcx=x, r8=y, r9=scroll_y
    push rdi
    push rsi
    push rbx
    lea rbx, [rel win_tmp_event]
    ; zero 64 bytes
    xor eax, eax
    mov [rbx + 0], rax
    mov [rbx + 8], rax
    mov [rbx + 16], rax
    mov [rbx + 24], rax
    mov [rbx + 32], rax
    mov [rbx + 40], rax
    mov [rbx + 48], rax
    mov [rbx + 56], rax

    mov dword [rbx + IE_TYPE_OFF], edi
    mov dword [rbx + IE_KEY_CODE_OFF], esi
    mov dword [rbx + IE_KEY_STATE_OFF], edx
    mov dword [rbx + IE_MOUSE_X_OFF], ecx
    mov dword [rbx + IE_MOUSE_Y_OFF], r8d
    mov dword [rbx + IE_SCROLL_DY_OFF], r9d

    mov rax, [rel win32_GetTickCount64]
    test rax, rax
    jz .push
    sub rsp, 32
    call rax
    add rsp, 32
    mov [rbx + IE_TS_OFF], rax
.push:
    mov rdi, rbx
    call input_push_event
    pop rbx
    pop rsi
    pop rdi
    ret

window_set_shell_replacement_mode:
    ; (enable)
    mov dword [rel win_shell_replacement_mode], edi
    ret

window_register_shell_hotkey:
    ; (id, mods, vk) -> 1/0
    mov r10d, edx
    mov rax, [rel win_single_ctx]
    test rax, rax
    jz .fail
    mov rcx, [rax + W_HWND_OFF]
    mov edx, edi
    mov r8d, esi
    mov r9d, r10d
    sub rsp, 40
    mov rax, [rel win32_RegisterHotKey]
    test rax, rax
    jz .err
    call rax
    add rsp, 40
    ret
.err:
    add rsp, 40
.fail:
    xor eax, eax
    ret

window_enum_windows:
    ; (callback_ptr) -> 1/0
    mov rcx, rdi
    xor edx, edx
    sub rsp, 40
    mov rax, [rel win32_EnumWindows]
    test rax, rax
    jz .fail
    call rax
    add rsp, 40
    ret
.fail:
    add rsp, 40
    xor eax, eax
    ret

aura_wnd_proc:
    ; Win64 callback: rcx=hWnd, rdx=uMsg, r8=wParam, r9=lParam
    push rbp
    push r14
    push r15
    push rdi
    push rsi
    push rbx
    push r12
    push r13
    sub rsp, 8
    mov rbx, rcx
    mov r12, rdx
    mov r13, r8

    cmp edx, WM_CLOSE
    je .wm_close
    cmp edx, WM_DESTROY
    je .wm_destroy
    cmp edx, WM_KEYDOWN
    je .wm_key_down
    cmp edx, WM_KEYUP
    je .wm_key_up
    cmp edx, WM_CHAR
    je .wm_char
    cmp edx, WM_MOUSEMOVE
    je .wm_mouse_move
    cmp edx, WM_LBUTTONDOWN
    je .wm_lbtn_dn
    cmp edx, WM_LBUTTONUP
    je .wm_lbtn_up
    cmp edx, WM_RBUTTONDOWN
    je .wm_rbtn_dn
    cmp edx, WM_RBUTTONUP
    je .wm_rbtn_up
    cmp edx, WM_MOUSEWHEEL
    je .wm_wheel
    cmp edx, WM_POINTERDOWN
    je .wm_ptr_down
    cmp edx, WM_POINTERUP
    je .wm_ptr_up
    cmp edx, WM_POINTERUPDATE
    je .wm_ptr_move
    cmp edx, WM_SIZE
    je .wm_size
    jmp .def

.wm_close:
    mov rax, [rel win_single_ctx]
    test rax, rax
    jz .ret0
    mov dword [rax + W_SHOULD_CLOSE_OFF], 1
    mov rcx, rbx
    sub rsp, 32
    mov rax, [rel win32_DestroyWindow]
    call rax
    add rsp, 32
    jmp .ret0

.wm_destroy:
    xor ecx, ecx
    sub rsp, 32
    mov rax, [rel win32_PostQuitMessage]
    call rax
    add rsp, 32
    jmp .ret0

.wm_key_down:
    mov rdi, INPUT_KEY
    mov rsi, r13
    cmp r13d, 0x09                    ; VK_TAB
    jne .wm_key_down_push
    mov esi, 0x27                     ; route Tab as VK_RIGHT for FM toggle
.wm_key_down_push:
    mov rdx, KEY_PRESSED
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call win_push_event
    jmp .ret0

.wm_key_up:
    mov rdi, INPUT_KEY
    mov rsi, r13
    mov rdx, KEY_RELEASED
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call win_push_event
    jmp .ret0

.wm_char:
    mov rdi, INPUT_KEY
    mov rsi, r13
    cmp r13d, 0x09                    ; '\t'
    jne .wm_char_push
    mov esi, 0x27                     ; keep same behavior as WM_KEYDOWN
.wm_char_push:
    mov rdx, KEY_PRESSED
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call win_push_event
    jmp .ret0

.wm_mouse_move:
    mov rdi, INPUT_MOUSE_MOVE
    xor esi, esi
    xor edx, edx
    mov ecx, r9d
    and ecx, 0xFFFF
    mov r8d, r9d
    shr r8d, 16
    xor r9d, r9d
    call win_push_event
    jmp .ret0

.wm_lbtn_dn:
    mov rdi, INPUT_MOUSE_BUTTON
    mov esi, MOUSE_LEFT
    mov edx, KEY_PRESSED
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call win_push_event
    jmp .ret0

.wm_lbtn_up:
    mov rdi, INPUT_MOUSE_BUTTON
    mov esi, MOUSE_LEFT
    mov edx, KEY_RELEASED
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call win_push_event
    jmp .ret0

.wm_rbtn_dn:
    mov rdi, INPUT_MOUSE_BUTTON
    mov esi, MOUSE_RIGHT
    mov edx, KEY_PRESSED
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call win_push_event
    jmp .ret0

.wm_rbtn_up:
    mov rdi, INPUT_MOUSE_BUTTON
    mov esi, MOUSE_RIGHT
    mov edx, KEY_RELEASED
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call win_push_event
    jmp .ret0

.wm_wheel:
    mov rdi, INPUT_SCROLL
    xor esi, esi
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    mov r9d, r13d
    sar r9d, 16
    call win_push_event
    jmp .ret0

.wm_ptr_down:
    mov rdi, INPUT_TOUCH_DOWN
    mov rsi, r13
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call win_push_event
    jmp .ret0

.wm_ptr_up:
    mov rdi, INPUT_TOUCH_UP
    mov rsi, r13
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call win_push_event
    jmp .ret0

.wm_ptr_move:
    mov rdi, INPUT_TOUCH_MOVE
    mov rsi, r13
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call win_push_event
    jmp .ret0

.wm_size:
    mov rax, [rel win_single_ctx]
    test rax, rax
    jz .ret0
    mov rsi, rax
    mov ecx, r9d
    and ecx, 0xFFFF
    mov r8d, r9d
    shr r8d, 16
    mov [rsi + W_WIDTH_OFF], ecx
    mov [rsi + W_HEIGHT_OFF], r8d
    test ecx, ecx
    jz .ret0
    test r8d, r8d
    jz .ret0

    ; Recreate DIB surface to match new client size.
    sub rsp, 224
    lea rdi, [rsp + 64]
    mov ecx, 80
    xor eax, eax
    rep stosb
    mov eax, [rsi + W_WIDTH_OFF]
    mov dword [rsp + 64 + 0], BITMAPINFOHEADER_SIZE
    mov dword [rsp + 64 + 4], eax
    mov eax, [rsi + W_HEIGHT_OFF]
    neg eax
    mov dword [rsp + 64 + 8], eax      ; top-down
    mov word [rsp + 64 + 12], 1
    mov word [rsp + 64 + 14], 32
    mov dword [rsp + 64 + 16], BI_RGB
    mov qword [rsp + 32], 0            ; hSection
    mov qword [rsp + 40], 0            ; offset
    mov qword [rsp + 48], 0            ; temp bits ptr
    mov qword [rsp + 56], 0            ; temp hbitmap
    mov rcx, [rsi + W_MEMDC_OFF]
    lea rdx, [rsp + 64]
    mov r8d, DIB_RGB_COLORS
    lea r9, [rsp + 48]
    mov rax, [rel win32_CreateDIBSection]
    call rax
    test rax, rax
    jz .wm_size_done

    ; Select new bitmap into memory DC.
    mov [rsp + 56], rax
    mov rcx, [rsi + W_MEMDC_OFF]
    mov rdx, [rsp + 56]
    mov rax, [rel win32_SelectObject]
    call rax

    ; Delete previous bitmap after replacement.
    mov rcx, [rsi + W_HBITMAP_OFF]
    test rcx, rcx
    jz .wm_size_store
    mov rax, [rel win32_DeleteObject]
    call rax

.wm_size_store:
    mov rax, [rsp + 56]
    mov [rsi + W_HBITMAP_OFF], rax
    mov rax, [rsp + 48]
    mov [rsi + W_DIB_PTR_OFF], rax
    mov [rsi + W_CANVAS_OFF + CV_BUFFER_OFF], rax
    mov eax, [rsi + W_WIDTH_OFF]
    mov [rsi + W_CANVAS_OFF + CV_WIDTH_OFF], eax
    mov eax, [rsi + W_HEIGHT_OFF]
    mov [rsi + W_CANVAS_OFF + CV_HEIGHT_OFF], eax
    mov eax, [rsi + W_WIDTH_OFF]
    shl eax, 2
    mov [rsi + W_CANVAS_OFF + CV_STRIDE_OFF], eax
    mov eax, [rsi + W_WIDTH_OFF]
    imul eax, [rsi + W_HEIGHT_OFF]
    shl eax, 2
    mov [rsi + W_CANVAS_OFF + CV_SIZE_OFF], rax
    mov dword [rsi + W_CANVAS_OFF + CV_CLIP_DEPTH_OFF], 0
    mov dword [rsi + W_CANVAS_OFF + CV_CLIP_X_OFF], 0
    mov dword [rsi + W_CANVAS_OFF + CV_CLIP_Y_OFF], 0
    mov eax, [rsi + W_WIDTH_OFF]
    mov [rsi + W_CANVAS_OFF + CV_CLIP_W_OFF], eax
    mov eax, [rsi + W_HEIGHT_OFF]
    mov [rsi + W_CANVAS_OFF + CV_CLIP_H_OFF], eax

.wm_size_done:
    add rsp, 224
    jmp .ret0

.def:
    ; DefWindowProcA(hWnd, msg, wParam, lParam)
    mov rcx, rbx
    mov rdx, r12
    mov r8, r13
    ; r9 unchanged as lParam from entry
    sub rsp, 32
    mov rax, [rel win32_DefWindowProcA]
    call rax
    add rsp, 32
    jmp .out

.ret0:
    xor eax, eax
.out:
    add rsp, 8
    pop r13
    pop r12
    pop rbx
    pop rsi
    pop rdi
    pop r15
    pop r14
    pop rbp
    ret

window_create_win32:
    ; (width rdi, height rsi, title rdx) -> Window* or 0
    push rdi
    push rsi
    push rbx
    push r12
    push r13
    push r14
    mov r12d, edi
    mov r13d, esi
    mov r14, rdx

    ; bootstrap is expected to be initialized by caller/tests.

    ; shell replacement mode: fullscreen popup
    cmp dword [rel win_shell_replacement_mode], 0
    je .size_ok
    mov rax, [rel win32_GetSystemMetrics]
    test rax, rax
    jz .size_ok
    mov ecx, SM_CXSCREEN
    sub rsp, 40
    call rax
    add rsp, 40
    mov r12d, eax
    mov rax, [rel win32_GetSystemMetrics]
    mov ecx, SM_CYSCREEN
    sub rsp, 40
    call rax
    add rsp, 40
    mov r13d, eax
.size_ok:

    ; allocate Window object
    mov rcx, 0
    mov rdx, W_STRUCT_SIZE
    mov r8d, MEM_COMMIT | MEM_RESERVE
    mov r9d, PAGE_READWRITE
    sub rsp, 40
    mov rax, [rel win32_VirtualAlloc]
    call rax
    add rsp, 40
    test rax, rax
    jz .fail
    mov rbx, rax

    ; register class once
    cmp dword [rel win_class_registered], 1
    je .class_done
    sub rsp, 160
    lea rdi, [rsp + 32]
    mov ecx, WNDCLASSEXA_SIZE
    xor eax, eax
    rep stosb
    mov dword [rsp + 32 + 0], WNDCLASSEXA_SIZE
    mov dword [rsp + 32 + 4], CS_HREDRAW | CS_VREDRAW
    lea rax, [rel aura_wnd_proc]
.wc_use_def:
    mov [rsp + 32 + 8], rax
    xor ecx, ecx
    sub rsp, 40
    mov rax, [rel win32_GetModuleHandleA]
    call rax
    add rsp, 40
    mov [rsp + 32 + 24], rax
    xor rcx, rcx
    mov edx, IDC_ARROW
    sub rsp, 40
    mov rax, [rel win32_LoadCursorA]
    call rax
    add rsp, 40
    mov [rsp + 32 + 40], rax
    lea rax, [rel win_class_name]
    mov [rsp + 32 + 64], rax
    lea rcx, [rsp + 32]
    sub rsp, 40
    mov rax, [rel win32_RegisterClassExA]
    call rax
    add rsp, 40
    add rsp, 160
    mov dword [rel win_class_registered], 1
.class_done:

    test r14, r14
    jnz .have_title
    lea r14, [rel win_default_title]
.have_title:
    ; CreateWindowExA(...)
    sub rsp, 104
    mov dword [rsp + 32], CW_USEDEFAULT
    mov dword [rsp + 40], CW_USEDEFAULT
    mov dword [rsp + 48], r12d
    mov dword [rsp + 56], r13d
    mov qword [rsp + 64], 0
    mov qword [rsp + 72], 0
    xor rax, rax
    mov [rsp + 80], rax
    mov [rsp + 88], rax
    xor ecx, ecx
    lea rdx, [rel win_class_name]
    mov r8, r14
    mov r9d, WS_VISIBLE | WS_OVERLAPPEDWINDOW
    cmp dword [rel win_shell_replacement_mode], 0
    je .cw_call
    mov ecx, WS_EX_TOOLWINDOW
    mov r9d, WS_VISIBLE | WS_POPUP
.cw_call:
    mov rax, [rel win32_CreateWindowExA]
    call rax
    add rsp, 104
    test rax, rax
    jz .free_fail
    mov [rbx + W_HWND_OFF], rax
    mov [rel win_expected_hwnd], rax
    xor rax, rax
    mov [rel win_cached_hdc], rax

    ; memDC = CreateCompatibleDC(NULL)
    xor ecx, ecx
    sub rsp, 40
    mov rax, [rel win32_CreateCompatibleDC]
    call rax
    add rsp, 40
    test rax, rax
    jz .free_fail
    mov [rbx + W_MEMDC_OFF], rax

    ; CreateDIBSection(memDC, &bmi, DIB_RGB_COLORS, &bits, 0, 0)
    ; Keep stack args at [rsp+32]/[rsp+40], place BITMAPINFO after that.
    sub rsp, 216
    lea rdi, [rsp + 64]
    mov ecx, 80
    xor eax, eax
    rep stosb
    mov dword [rsp + 64 + 0], BITMAPINFOHEADER_SIZE
    mov dword [rsp + 64 + 4], r12d
    mov eax, r13d
    neg eax
    mov dword [rsp + 64 + 8], eax      ; top-down
    mov word [rsp + 64 + 12], 1
    mov word [rsp + 64 + 14], 32
    mov dword [rsp + 64 + 16], BI_RGB

    mov qword [rsp + 32], 0            ; arg5 hSection
    mov qword [rsp + 40], 0            ; arg6 offset
    mov rcx, [rbx + W_MEMDC_OFF]
    lea rdx, [rsp + 64]
    mov r8d, DIB_RGB_COLORS
    lea r9, [rbx + W_DIB_PTR_OFF]
    mov rax, [rel win32_CreateDIBSection]
    call rax
    add rsp, 216
    test rax, rax
    jz .free_fail
    mov [rbx + W_HBITMAP_OFF], rax

    ; SelectObject(memDC, hBitmap)
    mov rcx, [rbx + W_MEMDC_OFF]
    mov rdx, [rbx + W_HBITMAP_OFF]
    sub rsp, 40
    mov rax, [rel win32_SelectObject]
    call rax
    add rsp, 40

    ; initialize canvas view (BGRA on Win32 DIB)
    mov [rbx + W_WIDTH_OFF], r12d
    mov [rbx + W_HEIGHT_OFF], r13d
    mov dword [rbx + W_SHOULD_CLOSE_OFF], 0
    mov rax, [rbx + W_DIB_PTR_OFF]
    mov [rbx + W_CANVAS_OFF + CV_BUFFER_OFF], rax
    mov [rbx + W_CANVAS_OFF + CV_WIDTH_OFF], r12d
    mov [rbx + W_CANVAS_OFF + CV_HEIGHT_OFF], r13d
    mov eax, r12d
    shl eax, 2
    mov [rbx + W_CANVAS_OFF + CV_STRIDE_OFF], eax
    mov eax, r12d
    imul eax, r13d
    shl eax, 2
    mov [rbx + W_CANVAS_OFF + CV_SIZE_OFF], rax
    mov dword [rbx + W_CANVAS_OFF + CV_CLIP_DEPTH_OFF], 0
    mov dword [rbx + W_CANVAS_OFF + CV_CLIP_X_OFF], 0
    mov dword [rbx + W_CANVAS_OFF + CV_CLIP_Y_OFF], 0
    mov [rbx + W_CANVAS_OFF + CV_CLIP_W_OFF], r12d
    mov [rbx + W_CANVAS_OFF + CV_CLIP_H_OFF], r13d

    mov [rel win_single_ctx], rbx

    ; show/update + best-effort touch registration
    mov rcx, [rbx + W_HWND_OFF]
    mov edx, SW_SHOW
    sub rsp, 40
    mov rax, [rel win32_ShowWindow]
    call rax
    add rsp, 40
    mov rcx, [rbx + W_HWND_OFF]
    sub rsp, 40
    mov rax, [rel win32_UpdateWindow]
    call rax
    add rsp, 40
    mov rax, [rel win32_RegisterTouchWindow]
    test rax, rax
    jz .ok
    mov rcx, [rbx + W_HWND_OFF]
    xor edx, edx
    sub rsp, 40
    call rax
    add rsp, 40
.ok:
    mov rax, rbx
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rsi
    pop rdi
    ret

.free_fail:
    ; cleanup partially-created Win32 resources and fail.
    mov rax, [rbx + W_HBITMAP_OFF]
    test rax, rax
    jz .ff_skip_obj
    mov rcx, rax
    sub rsp, 32
    mov rax, [rel win32_DeleteObject]
    call rax
    add rsp, 32
.ff_skip_obj:
    mov rax, [rbx + W_MEMDC_OFF]
    test rax, rax
    jz .ff_skip_dc
    mov rcx, rax
    sub rsp, 32
    mov rax, [rel win32_DeleteDC]
    call rax
    add rsp, 32
.ff_skip_dc:
    mov rax, [rbx + W_HWND_OFF]
    test rax, rax
    jz .ff_skip_hwnd
    mov rcx, rax
    sub rsp, 32
    mov rax, [rel win32_DestroyWindow]
    call rax
    add rsp, 32
.ff_skip_hwnd:
    mov rcx, rbx
    xor edx, edx
    mov r8d, MEM_RELEASE
    sub rsp, 32
    mov rax, [rel win32_VirtualFree]
    call rax
    add rsp, 32
.fail:
    xor eax, eax
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rsi
    pop rdi
    ret

window_create:
    jmp window_create_win32

window_present_win32:
    ; (Window*) -> 0/-1
    push rdi
    push rsi
    push rbx
    push r12
    test rdi, rdi
    jz .fail
    mov rbx, rdi
    cmp qword [rbx + W_HWND_OFF], 0
    je .fail
    mov rcx, [rbx + W_HWND_OFF]
    sub rsp, 40
    mov rax, [rel win32_GetDC]
    call rax
    add rsp, 40
    test rax, rax
    jz .fail
    mov r12, rax
    sub rsp, 88
    mov eax, [rbx + W_HEIGHT_OFF]
    mov dword [rsp + 32], eax                  ; cy
    mov rax, [rbx + W_MEMDC_OFF]
    mov [rsp + 40], rax                        ; hdcSrc
    mov qword [rsp + 48], 0                    ; xSrc
    mov qword [rsp + 56], 0                    ; ySrc
    mov qword [rsp + 64], SRCCOPY              ; rop
    mov rcx, r12
    xor edx, edx
    xor r8d, r8d
    mov r9d, [rbx + W_WIDTH_OFF]
    mov rax, [rel win32_BitBlt]
    call rax
    add rsp, 88
    mov rcx, [rbx + W_HWND_OFF]
    mov rdx, r12
    sub rsp, 40
    mov rax, [rel win32_ReleaseDC]
    call rax
    add rsp, 40
    xor eax, eax
    pop r12
    pop rbx
    pop rsi
    pop rdi
    ret
.fail:
    mov eax, -1
    pop r12
    pop rbx
    pop rsi
    pop rdi
    ret

window_present:
    jmp window_present_win32

window_draw_text_overlay:
    ; (x rdi, y rsi, utf8_text rdx, len ecx, color r8d) -> eax 0/-1
    push rbx
    push r12
    push r13
    push r14
    push r15
    test rdx, rdx
    jz .txt_fail
    test ecx, ecx
    jle .txt_fail
    mov ebx, edi                        ; x
    mov r12d, esi                       ; y
    mov r14, rdx                        ; text ptr (non-volatile)
    mov r15d, ecx                       ; len (non-volatile)
    mov r10d, r8d                       ; color (saved for next call)
    mov rax, [rel win_single_ctx]
    test rax, rax
    jz .txt_fail
    mov r13, [rax + W_MEMDC_OFF]          ; keep HDC across calls
    test r13, r13
    jz .txt_fail

    ; SetBkMode(hdc, TRANSPARENT)
    mov rcx, r13
    mov rdx, 1
    mov rax, [rel win32_SetBkMode]
    test rax, rax
    jz .txt_fail
    sub rsp, 40
    call rax
    add rsp, 40

    ; SetTextColor(hdc, color)
    mov rcx, r13
    mov rax, [rel win32_SetTextColor]
    test rax, rax
    jz .txt_fail
    mov edx, r10d
    sub rsp, 40
    call rax
    add rsp, 40

    ; Stable path: draw with TextOutA (ANSI bytes).
    mov rcx, r13
    mov rax, [rel win32_TextOutA]
    test rax, rax
    jz .txt_fail
    mov rdx, rbx
    mov r8, r12
    mov r9, r14
    sub rsp, 48
    mov dword [rsp + 32], r15d
    call rax
    add rsp, 48
    xor eax, eax
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.txt_fail:
    mov eax, -1
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

window_get_canvas:
    test rdi, rdi
    jz .fail
    lea rax, [rdi + W_CANVAS_OFF]
    ret
.fail:
    xor eax, eax
    ret

window_process_events:
    ; (Window*) -> 0/-1
    push rdi
    push rsi
    push r12
    test rdi, rdi
    jz .fail
    mov r12, rdi
    cmp qword [r12 + W_HWND_OFF], 0
    je .fail
.loop:
    sub rsp, 48
    lea rcx, [rel win_tmp_msg]
    xor rdx, rdx
    xor r8d, r8d
    xor r9d, r9d
    mov qword [rsp + 32], PM_REMOVE
    mov rax, [rel win32_PeekMessageA]
    call rax
    add rsp, 48
    test eax, eax
    jz .out
    cmp dword [rel win_tmp_msg + 8], WM_QUIT
    jne .dispatch
    mov dword [r12 + W_SHOULD_CLOSE_OFF], 1
.dispatch:
    ; Some Win configurations swallow Tab during translation/dispatch.
    ; Inject explicit FM-switch key event before default dispatch.
    cmp dword [rel win_tmp_msg + 8], WM_KEYDOWN
    je .tab_check
    cmp dword [rel win_tmp_msg + 8], 0x0104      ; WM_SYSKEYDOWN
    jne .dispatch_default
.tab_check:
    cmp dword [rel win_tmp_msg + 16], 0x09       ; VK_TAB
    jne .dispatch_default
    mov rdi, INPUT_KEY
    mov esi, 0x27                                ; VK_RIGHT fallback
    mov rdx, KEY_PRESSED
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call win_push_event
    jmp .loop
.dispatch_default:
    lea rcx, [rel win_tmp_msg]
    sub rsp, 32
    mov rax, [rel win32_TranslateMessage]
    call rax
    add rsp, 32
    lea rcx, [rel win_tmp_msg]
    sub rsp, 32
    mov rax, [rel win32_DispatchMessageA]
    call rax
    add rsp, 32
    jmp .loop
.out:
    xor eax, eax
    pop r12
    pop rsi
    pop rdi
    ret
.fail:
    mov eax, -1
    pop r12
    pop rsi
    pop rdi
    ret

window_should_close:
    test rdi, rdi
    jz .yes
    mov eax, [rdi + W_SHOULD_CLOSE_OFF]
    test eax, eax
    setne al
    movzx eax, al
    ret
.yes:
    mov eax, 1
    ret

window_destroy:
    ; (Window*) -> 0/-1
    push rdi
    push rsi
    push rbx
    test rdi, rdi
    jz .fail
    mov rbx, rdi
    mov rax, [rel win_cached_hdc]
    test rax, rax
    jz .skip_hdc_rel
    mov rcx, [rbx + W_HWND_OFF]
    test rcx, rcx
    jz .skip_hdc_rel
    mov rdx, rax
    sub rsp, 40
    mov rax, [rel win32_ReleaseDC]
    call rax
    add rsp, 40
    xor rax, rax
    mov [rel win_cached_hdc], rax
.skip_hdc_rel:

    mov rax, [rbx + W_HBITMAP_OFF]
    test rax, rax
    jz .skip_obj
    mov rcx, rax
    sub rsp, 32
    mov rax, [rel win32_DeleteObject]
    call rax
    add rsp, 32
.skip_obj:
    mov rax, [rbx + W_MEMDC_OFF]
    test rax, rax
    jz .skip_dc
    mov rcx, rax
    sub rsp, 32
    mov rax, [rel win32_DeleteDC]
    call rax
    add rsp, 32
.skip_dc:
    mov rax, [rbx + W_HWND_OFF]
    test rax, rax
    jz .skip_hwnd
    mov rcx, rax
    sub rsp, 32
    mov rax, [rel win32_DestroyWindow]
    call rax
    add rsp, 32
.skip_hwnd:
    mov rcx, rbx
    xor edx, edx
    mov r8d, MEM_RELEASE
    sub rsp, 32
    mov rax, [rel win32_VirtualFree]
    call rax
    add rsp, 32
    xor eax, eax
    pop rbx
    pop rsi
    pop rdi
    ret
.fail:
    mov eax, -1
    pop rbx
    pop rsi
    pop rdi
    ret

window_send_test_keydown:
    ; (Window*, vk) -> SendMessageA result
    test rdi, rdi
    jz .fail
    mov r10, rdi
    mov r11d, esi
    cmp qword [r10 + W_HWND_OFF], 0
    je .fail
    mov rcx, [r10 + W_HWND_OFF]
    mov edx, WM_KEYDOWN
    mov r8d, r11d
    xor r9d, r9d
    sub rsp, 40
    mov rax, [rel win32_SendMessageA]
    test rax, rax
    jz .err
    call rax
    add rsp, 40
    ret
.err:
    add rsp, 40
    mov rax, -1
    ret
.fail:
    mov rax, -1
    ret

window_manage_hwnd:
    ; (hwnd, x, y, w, h, show_flag) -> 1/0
    ; SysV: rdi, rsi, rdx, rcx, r8, r9
    push rbx
    push r12
    push r13
    push r14
    mov r10, rdi                      ; hwnd
    mov r11d, esi                     ; x
    mov ebx, edx                      ; y
    mov r12d, ecx                     ; w
    mov r13d, r8d                     ; h
    mov r14d, r9d                     ; show
    sub rsp, 88
    mov dword [rsp + 32], r13d        ; cy
    mov qword [rsp + 40], 0           ; hWndInsertAfter
    mov qword [rsp + 48], 0x0040      ; SWP_SHOWWINDOW
    mov rcx, r10
    mov edx, r11d
    mov r8d, ebx
    mov r9d, r12d
    mov rax, [rel win32_SetWindowPos]
    test rax, rax
    jz .fail
    call rax
    test eax, eax
    jz .fail
    mov rcx, r10
    mov edx, r14d
    mov rax, [rel win32_ShowWindow]
    call rax
    mov eax, 1
    add rsp, 88
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.fail:
    add rsp, 88
    xor eax, eax
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

window_subclass_hwnd:
    ; (hwnd) -> previous wndproc or 0
    mov rcx, rdi
    mov edx, GWLP_WNDPROC
    lea r8, [rel aura_wnd_proc]
    sub rsp, 40
    mov rax, [rel win32_SetWindowLongPtrA]
    test rax, rax
    jz .fail
    call rax
    add rsp, 40
    ret
.fail:
    add rsp, 40
    xor eax, eax
    ret
