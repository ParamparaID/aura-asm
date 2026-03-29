; truetype.asm
; TrueType loader and glyph rasterization (Phase 2, partial)

%include "src/hal/linux_x86_64/defs.inc"
%include "src/canvas/canvas.inc"

extern hal_open
extern hal_close
extern hal_mmap
extern hal_munmap
extern arena_init
extern arena_alloc
extern arena_destroy

%define SYS_LSEEK                   8
%define SEEK_SET                    0
%define SEEK_END                    2
%define PAGE_SIZE                   4096
%define MAX_TTF_POINTS              4096
%define MAX_TTF_SEGMENTS            16384
%define TT_QUAD_FLAT_EPS            8
%define TT_QUAD_MAX_DEPTH           14
%define TT_QUAD_STACK_FRAMES        16
%define TT_QUAD_FRAME_SIZE          32
%define TT_QUAD_STACK_TOTAL         (TT_QUAD_STACK_FRAMES * TT_QUAD_FRAME_SIZE)
%define PARSE_SIMPLE_STACK          (128 + TT_QUAD_STACK_TOTAL + 4)
%define TT_QUAD_STACK_OFF           128
%define TT_QUAD_NUMFRAMES_OFF       (TT_QUAD_STACK_OFF + TT_QUAD_STACK_TOTAL)

%define TTF_FLAG_X_SHORT            0x02
%define TTF_FLAG_Y_SHORT            0x04
%define TTF_FLAG_REPEAT             0x08
%define TTF_FLAG_X_SAME             0x10
%define TTF_FLAG_Y_SAME             0x20
%define TTF_FLAG_ON_CURVE           0x01

; Font struct
%define F_FILE_DATA_OFF             0
%define F_FILE_SIZE_OFF             8
%define F_NUM_GLYPHS_OFF            16
%define F_UNITS_PER_EM_OFF          18
%define F_INDEX_TO_LOC_OFF          20
%define F_ASCENT_OFF                22
%define F_DESCENT_OFF               24
%define F_LINE_GAP_OFF              26
%define F_PAD0_OFF                  28
%define F_CMAP_OFF                  32
%define F_LOCA_OFF                  36
%define F_GLYF_OFF                  40
%define F_HMTX_OFF                  44
%define F_NUM_HMETRICS_OFF          48
%define F_KERN_OFF                  50
%define F_KERN_NUM_PAIRS_OFF        54
%define F_CACHE_ARENA_OFF           56
%define F_CACHE_HEAD_OFF            64
%define F_CACHE_COUNT_OFF           72
%define F_STRUCT_SIZE               80

; GlyphBitmap
%define G_WIDTH_OFF                 0
%define G_HEIGHT_OFF                4
%define G_BITMAP_OFF                8
%define G_BEARING_X_OFF             16
%define G_BEARING_Y_OFF             20
%define G_ADVANCE_OFF               24
%define G_STRUCT_SIZE               32

; cache entry
%define C_GLYPH_ID_OFF              0
%define C_PIXEL_SIZE_OFF            4
%define C_BITMAP_PTR_OFF            8
%define C_NEXT_OFF                  16
%define C_STRUCT_SIZE               24

section .bss
    ttf_flag_buf                    resb MAX_TTF_POINTS
    ttf_x_buf                       resd MAX_TTF_POINTS
    ttf_y_buf                       resd MAX_TTF_POINTS
    ttf_endpts_buf                  resw 256
    ttf_seg_x0_buf                  resd MAX_TTF_SEGMENTS
    ttf_seg_y0_buf                  resd MAX_TTF_SEGMENTS
    ttf_seg_x1_buf                  resd MAX_TTF_SEGMENTS
    ttf_seg_y1_buf                  resd MAX_TTF_SEGMENTS
    parsed_bbox_xmin                resd 1
    parsed_bbox_ymin                resd 1
    parsed_bbox_xmax                resd 1
    parsed_bbox_ymax                resd 1
    parsed_edge_count               resd 1

section .text
global font_load
global font_destroy
global font_get_glyph_id
global font_get_glyph_metrics
global font_rasterize_glyph
global font_draw_string
global font_measure_string

; ---------- endian ----------
; rdi=ptr -> eax=u16
be16:
    movzx eax, byte [rdi]
    shl eax, 8
    movzx edx, byte [rdi + 1]
    or eax, edx
    ret

; rdi=ptr -> eax=s16
be16s:
    call be16
    movsx eax, ax
    ret

; rdi=ptr -> eax=u32
be32:
    movzx eax, byte [rdi]
    shl eax, 24
    movzx edx, byte [rdi + 1]
    shl edx, 16
    or eax, edx
    movzx edx, byte [rdi + 2]
    shl edx, 8
    or eax, edx
    movzx edx, byte [rdi + 3]
    or eax, edx
    ret

; tt_emit_line_xy(x0, y0, x1, y1)
; rdi=x0, rsi=y0, rdx=x1, rcx=y1
; appends into ttf_seg_* buffers, increments parsed_edge_count
tt_emit_line_xy:
    push rbx
    mov ebx, [parsed_edge_count]
    cmp ebx, MAX_TTF_SEGMENTS
    jae .ret
    mov [ttf_seg_x0_buf + rbx*4], edi
    mov [ttf_seg_y0_buf + rbx*4], esi
    mov [ttf_seg_x1_buf + rbx*4], edx
    mov [ttf_seg_y1_buf + rbx*4], ecx
    inc dword [parsed_edge_count]
.ret:
    pop rbx
    ret

; parse_simple_glyph_bbox(glyph_ptr, glyph_len)
; rdi=glyph ptr, rsi=len bytes
; returns eax=1 on success, 0 on failure
; outputs bbox in parsed_bbox_* (font units)
parse_simple_glyph_bbox:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, PARSE_SIMPLE_STACK

    xor eax, eax
    cmp rsi, 10
    jb .ret

    mov dword [parsed_edge_count], 0

    mov r12, rdi                         ; glyph ptr
    lea r13, [rdi + rsi]                 ; end ptr
    lea r14, [rdi + 10]                  ; ptr after header

    ; numberOfContours
    movzx eax, byte [r12]
    shl eax, 8
    movzx edx, byte [r12 + 1]
    or eax, edx
    movsx eax, ax
    cmp eax, 0
    jl .ret
    cmp eax, 256
    jg .ret
    mov [rsp + 16], eax                  ; numContours
    test eax, eax
    jz .ret

    ; endPtsOfContours (also validate monotonic and store for contour walk)
    mov ecx, eax
    imul ecx, 2
    lea rbx, [r14 + rcx]
    cmp rbx, r13
    ja .ret
    mov dword [rsp + 48], -1             ; prev endpoint
    xor ecx, ecx
.endpt_loop:
    cmp ecx, [rsp + 16]
    jae .endpt_done
    lea rdx, [r14 + rcx*2]
    movzx eax, byte [rdx]
    shl eax, 8
    movzx edx, byte [rdx + 1]
    or eax, edx
    cmp eax, [rsp + 48]
    jle .ret
    cmp eax, MAX_TTF_POINTS - 1
    jg .ret
    mov [rsp + 48], eax
    mov [ttf_endpts_buf + rcx*2], ax
    inc ecx
    jmp .endpt_loop
.endpt_done:

    mov eax, [rsp + 48]
    inc eax
    mov [rsp + 20], eax                  ; numPoints
    cmp eax, 0
    jle .ret
    cmp eax, MAX_TTF_POINTS
    jg .ret

    ; instructions
    cmp rbx, r13
    jae .ret
    movzx eax, byte [rbx]
    shl eax, 8
    movzx ecx, byte [rbx + 1]
    or eax, ecx                          ; instructionLength
    lea r14, [rbx + 2 + rax]
    cmp r14, r13
    ja .ret

    ; flags decode
    xor ecx, ecx                          ; i
.flags_loop:
    cmp ecx, [rsp + 20]
    jae .flags_done
    cmp r14, r13
    jae .ret
    mov al, [r14]
    inc r14
    mov [ttf_flag_buf + rcx], al
    test al, TTF_FLAG_REPEAT
    jz .flag_next
    cmp r14, r13
    jae .ret
    movzx edx, byte [r14]
    inc r14
.rep_loop:
    test edx, edx
    jz .flag_next
    inc ecx
    cmp ecx, [rsp + 20]
    jae .ret
    mov [ttf_flag_buf + rcx], al
    dec edx
    jmp .rep_loop
.flag_next:
    inc ecx
    jmp .flags_loop
.flags_done:

    ; x parse + bbox
    mov dword [rsp + 24], 0              ; curx
    mov dword [rsp + 32], 0x7FFFFFFF     ; xmin
    mov dword [rsp + 36], 0x80000000     ; xmax
    xor ecx, ecx
.x_loop:
    cmp ecx, [rsp + 20]
    jae .x_done
    movzx eax, byte [ttf_flag_buf + rcx]
    test eax, TTF_FLAG_X_SHORT
    jz .x_not_short
    cmp r14, r13
    jae .ret
    movzx edx, byte [r14]
    inc r14
    test eax, TTF_FLAG_X_SAME
    jz .x_short_neg
    add dword [rsp + 24], edx
    jmp .x_bbox
.x_short_neg:
    sub dword [rsp + 24], edx
    jmp .x_bbox
.x_not_short:
    test eax, TTF_FLAG_X_SAME
    jnz .x_bbox
    lea rbx, [r14 + 2]
    cmp rbx, r13
    ja .ret
    movzx edx, byte [r14]
    shl edx, 8
    movzx ebx, byte [r14 + 1]
    or edx, ebx
    movsx edx, dx
    add dword [rsp + 24], edx
    add r14, 2
.x_bbox:
    mov edx, [rsp + 24]
    mov [ttf_x_buf + rcx*4], edx
    cmp edx, [rsp + 32]
    jge .x_chk_max
    mov [rsp + 32], edx
.x_chk_max:
    cmp edx, [rsp + 36]
    jle .x_next
    mov [rsp + 36], edx
.x_next:
    inc ecx
    jmp .x_loop
.x_done:

    ; y parse + bbox
    mov dword [rsp + 28], 0              ; cury
    mov dword [rsp + 40], 0x7FFFFFFF     ; ymin
    mov dword [rsp + 44], 0x80000000     ; ymax
    xor ecx, ecx
.y_loop:
    cmp ecx, [rsp + 20]
    jae .ok
    movzx eax, byte [ttf_flag_buf + rcx]
    test eax, TTF_FLAG_Y_SHORT
    jz .y_not_short
    cmp r14, r13
    jae .ret
    movzx edx, byte [r14]
    inc r14
    test eax, TTF_FLAG_Y_SAME
    jz .y_short_neg
    add dword [rsp + 28], edx
    jmp .y_bbox
.y_short_neg:
    sub dword [rsp + 28], edx
    jmp .y_bbox
.y_not_short:
    test eax, TTF_FLAG_Y_SAME
    jnz .y_bbox
    lea rbx, [r14 + 2]
    cmp rbx, r13
    ja .ret
    movzx edx, byte [r14]
    shl edx, 8
    movzx ebx, byte [r14 + 1]
    or edx, ebx
    movsx edx, dx
    add dword [rsp + 28], edx
    add r14, 2
.y_bbox:
    mov edx, [rsp + 28]
    mov [ttf_y_buf + rcx*4], edx
    cmp edx, [rsp + 40]
    jge .y_chk_max
    mov [rsp + 40], edx
.y_chk_max:
    cmp edx, [rsp + 44]
    jle .y_next
    mov [rsp + 44], edx
.y_next:
    inc ecx
    jmp .y_loop

.ok:
    ; Save bbox before contour walk (rsp+32..44 are reused in point_loop).
    mov eax, [rsp + 32]
    mov [parsed_bbox_xmin], eax
    mov eax, [rsp + 36]
    mov [parsed_bbox_xmax], eax
    mov eax, [rsp + 40]
    mov [parsed_bbox_ymin], eax
    mov eax, [rsp + 44]
    mov [parsed_bbox_ymax], eax

    ; contour walk + recursive (iterative stack) quadratic flattening.
    mov dword [parsed_edge_count], 0
    mov dword [rsp + 0], -1              ; prev contour end
    xor r15d, r15d                       ; contour index
.contour_loop:
    cmp r15d, [rsp + 16]
    jae .contour_done
    movzx eax, word [ttf_endpts_buf + r15*2]
    mov [rsp + 4], eax                   ; contour end
    mov eax, [rsp + 0]
    inc eax
    mov [rsp + 8], eax                   ; contour start
    cmp eax, [rsp + 4]
    jg .ret

    ; first_on?
    mov ecx, [rsp + 8]
    movzx eax, byte [ttf_flag_buf + rcx]
    and eax, TTF_FLAG_ON_CURVE
    mov [rsp + 60], eax                  ; first_on
    cmp eax, 0
    jne .contour_start_on

    ; first point is off-curve: start point is midpoint(last, first)
    mov ecx, [rsp + 4]
    mov eax, [ttf_x_buf + rcx*4]
    mov [rsp + 64], eax                  ; prev_x
    mov eax, [ttf_y_buf + rcx*4]
    mov [rsp + 68], eax                  ; prev_y
    mov ecx, [rsp + 8]
    mov eax, [ttf_x_buf + rcx*4]
    add [rsp + 64], eax
    sar dword [rsp + 64], 1
    mov eax, [ttf_y_buf + rcx*4]
    add [rsp + 68], eax
    sar dword [rsp + 68], 1
    mov eax, [rsp + 8]
    mov [rsp + 72], eax                  ; i = start
    jmp .contour_anchor

.contour_start_on:
    mov ecx, [rsp + 8]
    mov eax, [ttf_x_buf + rcx*4]
    mov [rsp + 64], eax                  ; prev_x
    mov eax, [ttf_y_buf + rcx*4]
    mov [rsp + 68], eax                  ; prev_y
    mov eax, [rsp + 8]
    inc eax
    mov [rsp + 72], eax                  ; i = start + 1

.contour_anchor:
    mov eax, [rsp + 64]
    mov [rsp + 24], eax                  ; anchor_x
    mov eax, [rsp + 68]
    mov [rsp + 28], eax                  ; anchor_y

.point_loop:
    mov ecx, [rsp + 72]
    cmp ecx, [rsp + 4]
    jg .close_contour

    mov eax, [ttf_x_buf + rcx*4]
    mov [rsp + 32], eax                  ; cur_x
    mov eax, [ttf_y_buf + rcx*4]
    mov [rsp + 36], eax                  ; cur_y
    movzx eax, byte [ttf_flag_buf + rcx]
    and eax, TTF_FLAG_ON_CURVE
    mov [rsp + 76], eax                  ; cur_on
    cmp eax, 0
    je .cur_off

    ; on-curve: line prev -> cur
    mov edi, [rsp + 64]
    mov esi, [rsp + 68]
    mov edx, [rsp + 32]
    mov ecx, [rsp + 36]
    call tt_emit_line_xy
    mov eax, [rsp + 32]
    mov [rsp + 64], eax
    mov eax, [rsp + 36]
    mov [rsp + 68], eax
    inc dword [rsp + 72]
    jmp .point_loop

.cur_off:
    ; control point = cur
    mov eax, [rsp + 32]
    mov [rsp + 80], eax                  ; ctrl_x
    mov eax, [rsp + 36]
    mov [rsp + 84], eax                  ; ctrl_y

    ; next index (wrap to contour start)
    mov eax, [rsp + 72]
    inc eax
    cmp eax, [rsp + 4]
    jle .next_idx_ok
    mov eax, [rsp + 8]
.next_idx_ok:
    mov [rsp + 108], eax                 ; next_idx

    mov ecx, eax
    mov eax, [ttf_x_buf + rcx*4]
    mov [rsp + 96], eax                  ; next_x
    mov eax, [ttf_y_buf + rcx*4]
    mov [rsp + 100], eax                 ; next_y
    movzx eax, byte [ttf_flag_buf + rcx]
    and eax, TTF_FLAG_ON_CURVE
    mov [rsp + 104], eax                 ; next_on
    cmp eax, 0
    jne .quad_to_next_on

    ; next is off-curve: implied on-curve midpoint(ctrl, next)
    mov eax, [rsp + 80]
    add eax, [rsp + 96]
    sar eax, 1
    mov [rsp + 96], eax                  ; p2_x (implied)
    mov eax, [rsp + 84]
    add eax, [rsp + 100]
    sar eax, 1
    mov [rsp + 100], eax                 ; p2_y (implied)
    ; consume only current off point
    inc dword [rsp + 72]
    jmp .emit_quad

.quad_to_next_on:
    ; consume both current off and next on point
    mov eax, [rsp + 108]
    inc eax
    mov [rsp + 72], eax

.emit_quad:
    ; Push root quadratic onto explicit stack; iterative subdivide until flat.
    mov dword [rsp + TT_QUAD_NUMFRAMES_OFF], 1
    mov eax, [rsp + 64]
    mov [rsp + TT_QUAD_STACK_OFF + 0], eax
    mov eax, [rsp + 68]
    mov [rsp + TT_QUAD_STACK_OFF + 4], eax
    mov eax, [rsp + 80]
    mov [rsp + TT_QUAD_STACK_OFF + 8], eax
    mov eax, [rsp + 84]
    mov [rsp + TT_QUAD_STACK_OFF + 12], eax
    mov eax, [rsp + 96]
    mov [rsp + TT_QUAD_STACK_OFF + 16], eax
    mov eax, [rsp + 100]
    mov [rsp + TT_QUAD_STACK_OFF + 20], eax
    mov dword [rsp + TT_QUAD_STACK_OFF + 24], 0

.quad_flat_loop:
    mov eax, [rsp + TT_QUAD_NUMFRAMES_OFF]
    test eax, eax
    jz .emit_quad_set_prev
    dec eax
    shl eax, 5
    lea r8, [rsp + TT_QUAD_STACK_OFF + rax]

    ; flatness: |(p0+p2)/2 - p1|
    mov eax, [r8 + 0]
    add eax, [r8 + 16]
    sar eax, 1
    sub eax, [r8 + 8]
    cdq
    xor eax, edx
    sub eax, edx
    mov r10d, eax

    mov eax, [r8 + 4]
    add eax, [r8 + 20]
    sar eax, 1
    sub eax, [r8 + 12]
    cdq
    xor eax, edx
    sub eax, edx
    mov ecx, eax

    mov edx, [r8 + 24]
    cmp edx, TT_QUAD_MAX_DEPTH
    jge .quad_emit_line
    cmp r10d, TT_QUAD_FLAT_EPS
    jg .quad_subdivide
    cmp ecx, TT_QUAD_FLAT_EPS
    jg .quad_subdivide

.quad_emit_line:
    mov edi, [r8 + 0]
    mov esi, [r8 + 4]
    mov edx, [r8 + 16]
    mov ecx, [r8 + 20]
    call tt_emit_line_xy
    dec dword [rsp + TT_QUAD_NUMFRAMES_OFF]
    jmp .quad_flat_loop

.quad_subdivide:
    mov eax, [rsp + TT_QUAD_NUMFRAMES_OFF]
    cmp eax, TT_QUAD_STACK_FRAMES
    jge .quad_emit_line

    ; q0 = mid(p0,p1), q1 = mid(p1,p2), r = mid(q0,q1)
    mov eax, [r8 + 0]
    add eax, [r8 + 8]
    sar eax, 1
    mov [rsp + 48], eax                  ; q0x temp
    mov eax, [r8 + 4]
    add eax, [r8 + 12]
    sar eax, 1
    mov [rsp + 52], eax                  ; q0y
    mov eax, [r8 + 8]
    add eax, [r8 + 16]
    sar eax, 1
    mov [rsp + 56], eax                  ; q1x
    mov eax, [r8 + 12]
    add eax, [r8 + 20]
    sar eax, 1
    mov [rsp + 60], eax                  ; q1y
    mov eax, [rsp + 48]
    add eax, [rsp + 56]
    sar eax, 1
    mov [rsp + 32], eax                  ; rx
    mov eax, [rsp + 52]
    add eax, [rsp + 60]
    sar eax, 1
    mov [rsp + 36], eax                  ; ry

    ; save p2 before left overwrites [r8+16..20]
    mov eax, [r8 + 16]
    mov [rsp + 88], eax
    mov eax, [r8 + 20]
    mov [rsp + 92], eax
    mov eax, [r8 + 24]
    inc eax

    ; left overwrites [r8]: p0, q0, r, depth+1
    mov ecx, [rsp + 48]
    mov [r8 + 8], ecx
    mov ecx, [rsp + 52]
    mov [r8 + 12], ecx
    mov ecx, [rsp + 32]
    mov [r8 + 16], ecx
    mov ecx, [rsp + 36]
    mov [r8 + 20], ecx
    mov [r8 + 24], eax

    ; push right: (r, q1, saved p2, same depth)
    inc dword [rsp + TT_QUAD_NUMFRAMES_OFF]
    mov ecx, [rsp + TT_QUAD_NUMFRAMES_OFF]
    dec ecx
    shl ecx, 5
    lea r9, [rsp + TT_QUAD_STACK_OFF + rcx]
    mov edx, [rsp + 32]
    mov [r9 + 0], edx
    mov edx, [rsp + 36]
    mov [r9 + 4], edx
    mov edx, [rsp + 56]
    mov [r9 + 8], edx
    mov edx, [rsp + 60]
    mov [r9 + 12], edx
    mov edx, [rsp + 88]
    mov [r9 + 16], edx
    mov edx, [rsp + 92]
    mov [r9 + 20], edx
    mov edx, eax
    mov [r9 + 24], edx

    jmp .quad_flat_loop

.emit_quad_set_prev:
    mov eax, [rsp + 96]
    mov [rsp + 64], eax                  ; prev_x = p2_x
    mov eax, [rsp + 100]
    mov [rsp + 68], eax                  ; prev_y = p2_y
    jmp .point_loop

.close_contour:
    ; close with final line to contour anchor
    mov edi, [rsp + 64]
    mov esi, [rsp + 68]
    mov edx, [rsp + 24]
    mov ecx, [rsp + 28]
    call tt_emit_line_xy

.contour_next:
    mov eax, [rsp + 4]
    mov [rsp + 0], eax
    inc r15d
    jmp .contour_loop

.contour_done:
    ; parsed_bbox_* already written at .ok (before contour walk)
    mov eax, 1

.ret:
    add rsp, PARSE_SIMPLE_STACK
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; glyph_fetch_header_bbox(font, glyph_id)
; rdi=font*, esi=glyph id
; returns eax=1 on success, 0 on failure
; writes parsed_bbox_* in font units from glyph header xMin/yMin/xMax/yMax
glyph_fetch_header_bbox:
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 16

    xor eax, eax
    test rdi, rdi
    jz .ret
    mov rbx, rdi

    movzx ecx, word [rbx + F_NUM_GLYPHS_OFF]
    test ecx, ecx
    jz .ret
    cmp esi, ecx
    jb .gid_ok
    xor esi, esi
.gid_ok:

    mov r12, [rbx + F_FILE_DATA_OFF]
    test r12, r12
    jz .ret
    mov r13, [rbx + F_FILE_SIZE_OFF]
    test r13, r13
    jz .ret

    mov eax, [rbx + F_LOCA_OFF]
    lea r14, [r12 + rax]                 ; loca
    mov eax, [rbx + F_GLYF_OFF]
    mov [rsp + 8], eax                   ; glyf off

    ; read loca[glyph], loca[glyph+1]
    movsx eax, word [rbx + F_INDEX_TO_LOC_OFF]
    cmp eax, 1
    je .loc_long

    lea rdi, [r14 + rsi*2]
    call be16
    shl eax, 1
    mov [rsp + 0], eax
    mov edx, esi
    inc edx
    lea rdi, [r14 + rdx*2]
    call be16
    shl eax, 1
    mov [rsp + 4], eax
    jmp .have_loca

.loc_long:
    lea rdi, [r14 + rsi*4]
    call be32
    mov [rsp + 0], eax
    mov edx, esi
    inc edx
    lea rdi, [r14 + rdx*4]
    call be32
    mov [rsp + 4], eax

.have_loca:
    mov eax, [rsp + 0]
    cmp eax, [rsp + 4]
    jae .ret
    mov edx, [rsp + 8]
    add eax, edx
    lea r14, [r12 + rax]                 ; glyph ptr
    lea rdi, [r14 + 10]
    cmp rdi, r12
    jb .ret
    lea rdx, [r12 + r13]
    cmp rdi, rdx
    ja .ret

    lea rdi, [r14 + 2]
    call be16s
    mov [parsed_bbox_xmin], eax
    lea rdi, [r14 + 4]
    call be16s
    mov [parsed_bbox_ymin], eax
    lea rdi, [r14 + 6]
    call be16s
    mov [parsed_bbox_xmax], eax
    lea rdi, [r14 + 8]
    call be16s
    mov [parsed_bbox_ymax], eax
    mov eax, 1

.ret:
    add rsp, 16
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

tt_lseek:
    mov rax, SYS_LSEEK
    syscall
    ret

cache_find:
    mov rax, [rdi + F_CACHE_HEAD_OFF]
.loop:
    test rax, rax
    jz .miss
    cmp dword [rax + C_GLYPH_ID_OFF], esi
    jne .next
    cmp dword [rax + C_PIXEL_SIZE_OFF], edx
    jne .next
    mov rax, [rax + C_BITMAP_PTR_OFF]
    ret
.next:
    mov rax, [rax + C_NEXT_OFF]
    jmp .loop
.miss:
    xor eax, eax
    ret

cache_add:
    push rbx
    sub rsp, 24
    mov rbx, rdi
    mov [rsp + 0], esi
    mov [rsp + 8], edx
    mov [rsp + 16], rcx
    mov rdi, [rbx + F_CACHE_ARENA_OFF]
    mov rsi, C_STRUCT_SIZE
    call arena_alloc
    test rax, rax
    jz .ret
    mov esi, [rsp + 0]
    mov edx, [rsp + 8]
    mov rcx, [rsp + 16]
    mov [rax + C_GLYPH_ID_OFF], esi
    mov [rax + C_PIXEL_SIZE_OFF], edx
    mov [rax + C_BITMAP_PTR_OFF], rcx
    mov rdx, [rbx + F_CACHE_HEAD_OFF]
    mov [rax + C_NEXT_OFF], rdx
    mov [rbx + F_CACHE_HEAD_OFF], rax
    inc qword [rbx + F_CACHE_COUNT_OFF]
.ret:
    add rsp, 24
    pop rbx
    ret

; font_load(path, path_len) -> rax=Font*|0
font_load:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16

    test rdi, rdi
    jz .fail
    mov rbx, rdi

    mov rdi, rbx
    mov rsi, O_RDONLY
    xor rdx, rdx
    call hal_open
    test rax, rax
    js .fail
    mov r12, rax                        ; fd

    mov rdi, r12
    xor rsi, rsi
    mov rdx, SEEK_END
    call tt_lseek
    test rax, rax
    jle .close_fail
    mov r13, rax                        ; file size

    mov rdi, r12
    xor rsi, rsi
    mov rdx, SEEK_SET
    call tt_lseek

    xor rdi, rdi
    mov rsi, r13
    mov rdx, PROT_READ
    mov rcx, MAP_PRIVATE
    mov r8, r12
    xor r9, r9
    call hal_mmap
    test rax, rax
    js .close_fail
    mov r14, rax                        ; file data

    mov rdi, r12
    call hal_close

    xor rdi, rdi
    mov rsi, PAGE_SIZE
    mov rdx, PROT_READ | PROT_WRITE
    mov rcx, MAP_PRIVATE | MAP_ANONYMOUS
    mov r8, -1
    xor r9, r9
    call hal_mmap
    test rax, rax
    js .unmap_file_fail
    mov r15, rax                        ; font ptr

    ; clear
    xor eax, eax
    mov rcx, F_STRUCT_SIZE
.z:
    mov byte [r15 + rcx - 1], al
    dec rcx
    jnz .z

    mov [r15 + F_FILE_DATA_OFF], r14
    mov [r15 + F_FILE_SIZE_OFF], r13

    ; sfnt version
    mov rdi, r14
    call be32
    cmp eax, 0x00010000
    jne .destroy_font_fail

    ; num tables
    lea rdi, [r14 + 4]
    call be16
    test eax, eax
    jz .destroy_font_fail
    mov [rsp + 0], eax                  ; numTables

    ; find table offsets
    xor r8d, r8d
.tloop:
    cmp r8d, [rsp + 0]
    jae .tdone
    mov eax, r8d
    imul eax, 16
    lea rbx, [r14 + 12 + rax]

    mov rdi, rbx
    call be32
    mov [rsp + 8], eax                  ; tag
    lea rdi, [rbx + 8]
    call be32
    mov edx, eax                        ; offset

    mov eax, [rsp + 8]
    cmp eax, 0x68656164                 ; head
    jne .chk_maxp
    mov dword [r15 + 52], edx
    jmp .tnext
.chk_maxp:
    cmp eax, 0x6D617870                 ; maxp
    jne .chk_cmap
    mov dword [r15 + 56], edx
    jmp .tnext
.chk_cmap:
    cmp eax, 0x636D6170                 ; cmap
    jne .chk_loca
    mov [r15 + F_CMAP_OFF], edx
    jmp .tnext
.chk_loca:
    cmp eax, 0x6C6F6361                 ; loca
    jne .chk_glyf
    mov [r15 + F_LOCA_OFF], edx
    jmp .tnext
.chk_glyf:
    cmp eax, 0x676C7966                 ; glyf
    jne .chk_hhea
    mov [r15 + F_GLYF_OFF], edx
    jmp .tnext
.chk_hhea:
    cmp eax, 0x68686561                 ; hhea
    jne .chk_hmtx
    mov dword [r15 + 60], edx
    jmp .tnext
.chk_hmtx:
    cmp eax, 0x686D7478                 ; hmtx
    jne .tnext
    mov [r15 + F_HMTX_OFF], edx

.tnext:
    inc r8d
    jmp .tloop
.tdone:

    ; must-have tables
    mov eax, dword [r15 + 52]
    test eax, eax
    jz .destroy_font_fail
    mov eax, dword [r15 + 56]
    test eax, eax
    jz .destroy_font_fail
    mov eax, [r15 + F_CMAP_OFF]
    test eax, eax
    jz .destroy_font_fail
    mov eax, [r15 + F_LOCA_OFF]
    test eax, eax
    jz .destroy_font_fail
    mov eax, [r15 + F_GLYF_OFF]
    test eax, eax
    jz .destroy_font_fail
    mov eax, dword [r15 + 60]
    test eax, eax
    jz .destroy_font_fail
    mov eax, [r15 + F_HMTX_OFF]
    test eax, eax
    jz .destroy_font_fail

    ; head
    mov eax, dword [r15 + 52]
    lea rbx, [r14 + rax]
    lea rdi, [rbx + 18]
    call be16
    mov [r15 + F_UNITS_PER_EM_OFF], ax
    test ax, ax
    jz .destroy_font_fail
    lea rdi, [rbx + 50]
    call be16s
    mov [r15 + F_INDEX_TO_LOC_OFF], ax

    ; kern (optional): disabled until bounds-checked against table length (TODO)
    jmp .kern_done
    xor r8d, r8d
.kern_loop:
    cmp r8d, [rsp + 0]
    jae .kern_done
    mov eax, r8d
    imul eax, 16
    lea rbx, [r14 + 12 + rax]
    mov rdi, rbx
    call be32
    cmp eax, 0x6B65726E                 ; 'kern'
    jne .kern_next
    lea rdi, [rbx + 8]
    call be32
    mov edx, eax                        ; file offset of kern table
    lea rbx, [r14 + rdx]                ; kern table base in file
    ; kern header 4B; subtable at +4: version(2), length(2), coverage(2), numPairs(2), pairs...
    ; coverage: bit0 horizontal; bits 8-15 = format (0 = pair list)
    lea rdi, [rbx + 8]
    call be16
    mov ecx, eax
    shr eax, 8
    and eax, 0xFF
    cmp eax, 0
    jne .kern_done
    test ecx, 1
    jz .kern_done
    lea rdi, [rbx + 10]
    call be16
    cmp eax, 8192
    ja .kern_done
    mov [r15 + F_KERN_NUM_PAIRS_OFF], ax
    mov [r15 + F_KERN_OFF], edx         ; file offset to kern table; pairs at +12
    jmp .kern_done
.kern_next:
    inc r8d
    jmp .kern_loop
.kern_done:

    ; maxp
    mov eax, dword [r15 + 56]
    lea rbx, [r14 + rax]
    lea rdi, [rbx + 4]
    call be16
    mov [r15 + F_NUM_GLYPHS_OFF], ax
    test ax, ax
    jz .destroy_font_fail

    ; hhea
    mov eax, dword [r15 + 60]
    lea rbx, [r14 + rax]
    lea rdi, [rbx + 4]
    call be16s
    mov [r15 + F_ASCENT_OFF], ax
    lea rdi, [rbx + 6]
    call be16s
    mov [r15 + F_DESCENT_OFF], ax
    lea rdi, [rbx + 8]
    call be16s
    mov [r15 + F_LINE_GAP_OFF], ax
    lea rdi, [rbx + 34]
    call be16
    mov [r15 + F_NUM_HMETRICS_OFF], ax
    test ax, ax
    jz .destroy_font_fail

    ; cache arena
    mov rdi, 4194304
    call arena_init
    test rax, rax
    jz .destroy_font_fail
    mov [r15 + F_CACHE_ARENA_OFF], rax
    mov qword [r15 + F_CACHE_HEAD_OFF], 0
    mov qword [r15 + F_CACHE_COUNT_OFF], 0

    mov rax, r15
    jmp .ret

.destroy_font_fail:
    mov rdi, [r15 + F_CACHE_ARENA_OFF]
    test rdi, rdi
    jz .skip_arena_destroy
    call arena_destroy
.skip_arena_destroy:
    mov rdi, r15
    mov rsi, PAGE_SIZE
    call hal_munmap
.unmap_file_fail:
    mov rdi, r14
    mov rsi, r13
    call hal_munmap
    jmp .fail
.close_fail:
    mov rdi, r12
    call hal_close
.fail:
    xor eax, eax
.ret:
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

font_destroy:
    push rbx
    test rdi, rdi
    jz .ok
    mov rbx, rdi
    mov rdi, [rbx + F_CACHE_ARENA_OFF]
    test rdi, rdi
    jz .no_arena
    call arena_destroy
.no_arena:
    mov rdi, [rbx + F_FILE_DATA_OFF]
    mov rsi, [rbx + F_FILE_SIZE_OFF]
    test rdi, rdi
    jz .no_file
    call hal_munmap
.no_file:
    mov rdi, rbx
    mov rsi, PAGE_SIZE
    call hal_munmap
.ok:
    xor eax, eax
    pop rbx
    ret

; font_get_glyph_id(font, codepoint)
; cmap format 4 with bounds checks
font_get_glyph_id:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16

    xor eax, eax
    test rdi, rdi
    jz .done
    cmp esi, 0xFFFF
    ja .done

    mov rbx, rdi
    mov r13, [rbx + F_FILE_DATA_OFF]     ; base
    mov r14, [rbx + F_FILE_SIZE_OFF]     ; size
    test r13, r13
    jz .done
    test r14, r14
    jz .done

    mov eax, [rbx + F_CMAP_OFF]
    test eax, eax
    jz .done
    mov r12d, eax                         ; cmap offset
    mov eax, r12d
    add eax, 4
    cmp rax, r14
    ja .done
    lea r15, [r13 + r12]                  ; cmap ptr

    lea rdi, [r15 + 2]
    call be16
    mov [rsp + 0], eax                    ; numTables
    test eax, eax
    jz .done

    xor r8d, r8d
    xor r9d, r9d                          ; chosen subtable offset
.enc_loop:
    cmp r8d, [rsp + 0]
    jae .enc_done
    mov eax, r8d
    imul eax, 8
    lea r10, [r15 + 4 + rax]              ; encoding record
    mov eax, r10d
    sub eax, r13d
    add eax, 8
    cmp rax, r14
    ja .done

    mov rdi, r10
    call be16
    mov ecx, eax                          ; platform
    lea rdi, [r10 + 2]
    call be16
    mov edx, eax                          ; encoding
    lea rdi, [r10 + 4]
    call be32
    mov [rsp + 8], eax                    ; subtable offset from cmap

    cmp ecx, 3
    jne .enc_next
    cmp edx, 1
    je .pick
    cmp edx, 10
    jne .enc_next
.pick:
    mov r9d, [rsp + 8]
    jmp .enc_done
.enc_next:
    inc r8d
    jmp .enc_loop
.enc_done:
    test r9d, r9d
    jz .ascii_fallback

    ; subtable bounds
    mov eax, r12d
    add eax, r9d
    cmp rax, r14
    ja .ascii_fallback
    lea r10, [r15 + r9]                   ; subtable ptr
    lea rdi, [r10 + 2]
    call be16
    mov [rsp + 12], eax                   ; length
    test eax, eax
    jz .ascii_fallback
    mov eax, r10d
    sub eax, r13d
    add eax, [rsp + 12]
    cmp rax, r14
    ja .ascii_fallback
    mov r14, r10
    add r14, [rsp + 12]                   ; subtable end ptr

    mov rdi, r10
    call be16
    cmp eax, 4
    jne .ascii_fallback

    lea rdi, [r10 + 6]
    call be16
    shr eax, 1
    test eax, eax
    jz .ascii_fallback
    mov r8d, eax                          ; segCount

    lea r9, [r10 + 14]                    ; endCode
    lea r11, [r9 + r8*2 + 2]              ; startCode
    lea r12, [r11 + r8*2]                 ; idDelta
    lea r13, [r12 + r8*2]                 ; idRangeOffset

    ; ensure last array entry in range
    lea rax, [r13 + r8*2]
    cmp rax, r14
    ja .ascii_fallback

    xor edx, edx                           ; i
.seg_loop:
    cmp edx, r8d
    jae .ascii_fallback

    lea rdi, [r9 + rdx*2]
    call be16
    mov ecx, eax                           ; endCode
    cmp esi, ecx
    ja .next_seg

    lea rdi, [r11 + rdx*2]
    call be16
    mov r15d, eax                          ; startCode
    cmp esi, r15d
    jb .next_seg

    lea rdi, [r12 + rdx*2]
    call be16s
    mov r10d, eax                          ; idDelta

    lea rdi, [r13 + rdx*2]
    call be16
    mov ecx, eax                           ; idRangeOffset
    test ecx, ecx
    jnz .range_case

    mov eax, esi
    add eax, r10d
    and eax, 0xFFFF
    jmp .clamp_gid

.range_case:
    ; addr = &idRangeOffset[i] + idRangeOffset + 2*(cp-start)
    mov eax, esi
    sub eax, r15d
    lea rdi, [r13 + rdx*2]
    add rdi, rcx
    lea rdi, [rdi + rax*2]
    cmp rdi, r14
    jae .ascii_fallback
    lea rax, [rdi + 2]
    cmp rax, r14
    ja .ascii_fallback
    call be16
    test eax, eax
    jz .done
    add eax, r10d
    and eax, 0xFFFF
    jmp .clamp_gid

.next_seg:
    inc edx
    jmp .seg_loop

.clamp_gid:
    movzx ecx, word [rbx + F_NUM_GLYPHS_OFF]
    test ecx, ecx
    jz .done
    cmp eax, ecx
    jb .done
    xor eax, eax
    jmp .done

.ascii_fallback:
    xor eax, eax
    cmp esi, 32
    jb .done
    cmp esi, 126
    ja .done
    mov eax, esi
    sub eax, 31
    movzx ecx, word [rbx + F_NUM_GLYPHS_OFF]
    cmp eax, ecx
    jb .done
    xor eax, eax

.done:
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; font_get_glyph_metrics(font, glyph_id)
; rax=advance (units), rdx=lsb (units)
font_get_glyph_metrics:
    push rbx
    push r12
    push r13
    xor eax, eax
    xor edx, edx

    test rdi, rdi
    jz .ret
    mov rbx, rdi
    mov r12, [rbx + F_FILE_DATA_OFF]
    mov eax, [rbx + F_HMTX_OFF]
    lea r13, [r12 + rax]

    movzx ecx, word [rbx + F_NUM_HMETRICS_OFF]
    test ecx, ecx
    jz .ret

    movzx r8d, word [rbx + F_NUM_GLYPHS_OFF]
    test r8d, r8d
    jz .ret
    cmp esi, r8d
    jb .gid_ok
    mov esi, r8d
    dec esi
.gid_ok:

    cmp esi, ecx
    jb .full
    mov eax, ecx
    dec eax
    lea rdi, [r13 + rax*4]
    call be16
    movzx eax, ax
    mov edx, esi
    sub edx, ecx
    lea r8, [r13 + rcx*4]
    lea rdi, [r8 + rdx*2]
    call be16s
    movsx rdx, ax
    jmp .ret

.full:
    lea rdi, [r13 + rsi*4]
    call be16
    movzx eax, ax
    lea rdi, [r13 + rsi*4 + 2]
    call be16s
    movsx rdx, ax

.ret:
    pop r13
    pop r12
    pop rbx
    ret

; font_get_kerning(font, left_gid, right_gid) -> eax = kerning FUnits (signed), 0 if none
; Stub: kern table load is disabled in font_load until pair bounds are validated.
font_get_kerning:
    xor eax, eax
    ret

; rasterize simple bbox bitmap with soft edge
; rdi=glyphBitmap*, rsi=arena*
rasterize_bbox_bitmap:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 64
    mov rbx, rdi
    mov r12, rsi

    mov eax, [rbx + G_WIDTH_OFF]
    mov ecx, [rbx + G_HEIGHT_OFF]
    test eax, eax
    jle .empty
    test ecx, ecx
    jle .empty
    imul eax, ecx
    mov rdi, r12
    mov rsi, rax
    call arena_alloc
    test rax, rax
    jz .empty
    mov [rbx + G_BITMAP_OFF], rax
    mov r13, rax

    ; clear bitmap buffer
    mov eax, [rbx + G_WIDTH_OFF]
    imul eax, [rbx + G_HEIGHT_OFF]
    mov rcx, rax
    xor eax, eax
.clr:
    test rcx, rcx
    jz .try_scanline
    mov byte [r13 + rcx - 1], al
    dec rcx
    jmp .clr

.try_scanline:
    ; Win-native stabilization: disable experimental scanline rasterizer.
    ; Use stable bbox fallback to avoid AV in segment prep/intersection path.
    jmp .fallback_bbox
    mov eax, [parsed_edge_count]
    test eax, eax
    jz .fallback_bbox
    cmp eax, MAX_TTF_SEGMENTS
    jg .fallback_bbox
    mov [rsp + 0], eax                    ; seg_count

    mov eax, [parsed_bbox_xmin]
    mov [rsp + 4], eax
    mov eax, [parsed_bbox_ymin]
    mov [rsp + 8], eax
    mov eax, [parsed_bbox_xmax]
    mov [rsp + 12], eax
    mov eax, [parsed_bbox_ymax]
    mov [rsp + 16], eax

    mov eax, [rsp + 12]
    sub eax, [rsp + 4]
    mov [rsp + 20], eax                   ; xrange
    mov eax, [rsp + 16]
    sub eax, [rsp + 8]
    mov [rsp + 24], eax                   ; yrange
    cmp dword [rsp + 20], 0
    jle .fallback_bbox
    cmp dword [rsp + 24], 0
    jle .fallback_bbox

    ; transform segments from font units -> pixel 16.16 in-place
    xor r14d, r14d                         ; seg i
.seg_prep_loop:
    cmp r14d, [rsp + 0]
    jae .scan_rows

    ; x0
    mov eax, [ttf_seg_x0_buf + r14*4]
    sub eax, [rsp + 4]
    movsx rax, eax
    movsx rcx, dword [rbx + G_WIDTH_OFF]
    imul rax, rcx
    shl rax, 16
    cqo
    movsx rcx, dword [rsp + 20]
    idiv rcx
    mov [ttf_seg_x0_buf + r14*4], eax

    ; y0 (top-down)
    mov eax, [rsp + 16]
    sub eax, [ttf_seg_y0_buf + r14*4]
    movsx rax, eax
    movsx rcx, dword [rbx + G_HEIGHT_OFF]
    imul rax, rcx
    shl rax, 16
    cqo
    movsx rcx, dword [rsp + 24]
    idiv rcx
    mov [ttf_seg_y0_buf + r14*4], eax

    ; x1
    mov eax, [ttf_seg_x1_buf + r14*4]
    sub eax, [rsp + 4]
    movsx rax, eax
    movsx rcx, dword [rbx + G_WIDTH_OFF]
    imul rax, rcx
    shl rax, 16
    cqo
    movsx rcx, dword [rsp + 20]
    idiv rcx
    mov [ttf_seg_x1_buf + r14*4], eax

    ; y1 (top-down)
    mov eax, [rsp + 16]
    sub eax, [ttf_seg_y1_buf + r14*4]
    movsx rax, eax
    movsx rcx, dword [rbx + G_HEIGHT_OFF]
    imul rax, rcx
    shl rax, 16
    cqo
    movsx rcx, dword [rsp + 24]
    idiv rcx
    mov [ttf_seg_y1_buf + r14*4], eax

    inc r14d
    jmp .seg_prep_loop

.scan_rows:
    xor r14d, r14d                         ; y
.row_loop:
    cmp r14d, [rbx + G_HEIGHT_OFF]
    jae .ok

    mov eax, [rbx + G_WIDTH_OFF]
    imul eax, r14d
    lea r15, [r13 + rax]                   ; row ptr

    mov dword [rsp + 28], 0                ; sub index 0..3
.sub_loop:
    cmp dword [rsp + 28], 4
    jae .next_row

    ; sy16 = (y<<16) + {0x2000,0x6000,0xA000,0xE000}
    mov eax, r14d
    shl eax, 16
    mov ecx, [rsp + 28]
    imul ecx, 0x4000
    add ecx, 0x2000
    add eax, ecx
    mov [rsp + 32], eax                    ; sy16

    mov dword [rsp + 36], 0x7FFFFFFF       ; minx16
    mov dword [rsp + 40], 0x80000000       ; maxx16
    mov dword [rsp + 44], 0                ; hits
    xor ecx, ecx                           ; seg i
.isect_loop:
    cmp ecx, [rsp + 0]
    jae .isect_done

    mov eax, [ttf_seg_y0_buf + rcx*4]
    mov edx, [ttf_seg_y1_buf + rcx*4]
    mov r10d, [ttf_seg_x0_buf + rcx*4]
    mov r11d, [ttf_seg_x1_buf + rcx*4]
    cmp eax, edx
    je .isect_next                         ; horizontal edge
    jl .y_ordered
    xchg eax, edx
    xchg r10d, r11d                        ; (ymin,x_lo) .. (ymax,x_hi)
.y_ordered:
    mov r8d, [rsp + 32]                    ; sy
    cmp r8d, eax
    jl .isect_next
    cmp r8d, edx
    jge .isect_next

    ; x = x_lo + (sy-ymin)*(x_hi-x_lo)/(ymax-ymin); dy in r9d before imul/cqo
    mov r9d, edx
    sub r9d, eax                           ; dy > 0
    mov edi, r8d
    sub edi, eax                             ; sy - ymin
    movsx rax, edi
    mov edi, r11d
    sub edi, r10d
    movsx rdi, edi
    imul rax, rdi
    cqo
    movsx r8, r9d
    idiv r8
    add eax, r10d

    cmp eax, [rsp + 36]
    jge .chk_max
    mov [rsp + 36], eax
.chk_max:
    cmp eax, [rsp + 40]
    jle .isect_hit
    mov [rsp + 40], eax
.isect_hit:
    inc dword [rsp + 44]
.isect_next:
    inc ecx
    jmp .isect_loop

.isect_done:
    cmp dword [rsp + 44], 2
    jl .next_sub

    mov eax, [rsp + 36]
    sar eax, 16                            ; x_start floor
    mov [rsp + 48], eax
    mov eax, [rsp + 40]
    add eax, 0xFFFF
    sar eax, 16
    dec eax                                ; x_end inclusive
    mov [rsp + 52], eax

    cmp dword [rsp + 48], 0
    jge .xs_ok
    mov dword [rsp + 48], 0
.xs_ok:
    mov eax, [rbx + G_WIDTH_OFF]
    dec eax
    cmp [rsp + 52], eax
    jle .xe_ok
    mov [rsp + 52], eax
.xe_ok:
    mov eax, [rsp + 48]
    cmp eax, [rsp + 52]
    jg .next_sub

    mov ecx, eax                           ; x
.fill_span:
    movzx eax, byte [r15 + rcx]
    add eax, 64
    cmp eax, 255
    jle .store_cov
    mov eax, 255
.store_cov:
    mov byte [r15 + rcx], al
    inc ecx
    cmp ecx, [rsp + 52]
    jle .fill_span

.next_sub:
    inc dword [rsp + 28]
    jmp .sub_loop

.next_row:
    inc r14d
    jmp .row_loop

.fallback_bbox:
    ; previous stable bbox fill
    xor r14d, r14d
.fb_row:
    cmp r14d, [rbx + G_HEIGHT_OFF]
    jae .ok
    xor r15d, r15d
.fb_col:
    cmp r15d, [rbx + G_WIDTH_OFF]
    jae .fb_next_row
    mov edx, 255
    cmp r14d, 0
    je .fb_soft
    mov eax, [rbx + G_HEIGHT_OFF]
    dec eax
    cmp r14d, eax
    je .fb_soft
    cmp r15d, 0
    je .fb_soft
    mov eax, [rbx + G_WIDTH_OFF]
    dec eax
    cmp r15d, eax
    je .fb_soft
    jmp .fb_write
.fb_soft:
    mov edx, 160
.fb_write:
    mov eax, [rbx + G_WIDTH_OFF]
    mov ecx, r14d
    imul ecx, eax
    add ecx, r15d
    mov byte [r13 + rcx], dl
    inc r15d
    jmp .fb_col
.fb_next_row:
    inc r14d
    jmp .fb_row
.ok:
    xor eax, eax
    jmp .ret
.empty:
    mov qword [rbx + G_BITMAP_OFF], 0
    xor eax, eax
.ret:
    add rsp, 64
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; font_rasterize_glyph(font, glyph_id, pixel_size) -> GlyphBitmap*
font_rasterize_glyph:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 56

    test rdi, rdi
    jz .fail
    test rdx, rdx
    jle .fail
    mov rbx, rdi                         ; font
    mov r12d, esi                        ; gid
    mov r13d, edx                        ; px
    movzx eax, word [rbx + F_NUM_GLYPHS_OFF]
    test eax, eax
    jz .fail
    cmp r12d, eax
    jb .gid_ok
    xor r12d, r12d
.gid_ok:

    mov rdi, rbx
    mov esi, r12d
    mov edx, r13d
    call cache_find
    test rax, rax
    jnz .ret_ok

    mov rdi, [rbx + F_CACHE_ARENA_OFF]
    mov rsi, G_STRUCT_SIZE
    call arena_alloc
    test rax, rax
    jz .fail
    mov r14, rax

    ; clear GlyphBitmap
    xor eax, eax
    mov rcx, G_STRUCT_SIZE
.z:
    mov byte [r14 + rcx - 1], al
    dec rcx
    jnz .z

    ; advance from hmtx
    mov rdi, rbx
    mov esi, r12d
    call font_get_glyph_metrics
    movsx rax, eax
    imul rax, r13
    cqo
    movsx rcx, word [rbx + F_UNITS_PER_EM_OFF]
    idiv rcx
    mov [r14 + G_ADVANCE_OFF], eax
    cmp dword [r14 + G_ADVANCE_OFF], 1
    jge .adv_ok
    mov dword [r14 + G_ADVANCE_OFF], 1
.adv_ok:

    ; loca/glyf bbox
    mov r15, [rbx + F_FILE_DATA_OFF]
    mov eax, [rbx + F_LOCA_OFF]
    lea r8, [r15 + rax]                  ; loca
    mov eax, [rbx + F_GLYF_OFF]
    lea r9, [r15 + rax]                  ; glyf

    movsx eax, word [rbx + F_INDEX_TO_LOC_OFF]
    cmp eax, 1
    je .loc_long

    lea rdi, [r8 + r12*2]
    call be16
    shl eax, 1
    mov [rsp + 0], eax
    mov eax, r12d
    inc eax
    lea rdi, [r8 + rax*2]
    call be16
    shl eax, 1
    mov [rsp + 4], eax
    jmp .have_loca

.loc_long:
    lea rdi, [r8 + r12*4]
    call be32
    mov [rsp + 0], eax
    mov eax, r12d
    inc eax
    lea rdi, [r8 + rax*4]
    call be32
    mov [rsp + 4], eax

.have_loca:
    mov eax, [rsp + 0]
    cmp eax, [rsp + 4]
    je .cache_empty
    lea r10, [r9 + rax]

    mov rdi, r10
    call be16s
    cmp eax, 0
    jl .compound_try

    lea rdi, [r10 + 2]
    call be16s
    mov [rsp + 8], eax                   ; xMin
    lea rdi, [r10 + 4]
    call be16s
    mov [rsp + 12], eax                  ; yMin
    lea rdi, [r10 + 6]
    call be16s
    mov [rsp + 16], eax                  ; xMax
    lea rdi, [r10 + 8]
    call be16s
    mov [rsp + 20], eax                  ; yMax

    ; parse simple contour points (endPts/flags/x/y) when possible.
    ; if successful, prefer parsed bbox over header bbox.
    mov eax, [rsp + 4]
    sub eax, [rsp + 0]
    cmp eax, 10
    jl .bbox_skip_parse
    mov rdi, r10
    mov esi, eax
    call parse_simple_glyph_bbox
    test eax, eax
    jz .bbox_skip_parse
    mov eax, [parsed_bbox_xmin]
    mov [rsp + 8], eax
    mov eax, [parsed_bbox_ymin]
    mov [rsp + 12], eax
    mov eax, [parsed_bbox_xmax]
    mov [rsp + 16], eax
    mov eax, [parsed_bbox_ymax]
    mov [rsp + 20], eax
    jmp .bbox_ready

.bbox_skip_parse:
    mov dword [parsed_edge_count], 0

.bbox_ready:

    ; scale16 = px*65536 / unitsPerEm
    mov eax, r13d
    shl rax, 16
    cqo
    movsx rcx, word [rbx + F_UNITS_PER_EM_OFF]
    idiv rcx
    mov r11d, eax
    test r11d, r11d
    jle .cache_empty

    ; min floor
    mov eax, [rsp + 8]
    imul eax, r11d
    sar eax, 16
    mov [r14 + G_BEARING_X_OFF], eax

    mov eax, [rsp + 20]                  ; yMax
    imul eax, r11d
    add eax, 0xFFFF
    sar eax, 16
    mov [r14 + G_BEARING_Y_OFF], eax

    ; width = ceil(xMax)-floor(xMin)
    mov eax, [rsp + 16]
    imul eax, r11d
    add eax, 0xFFFF
    sar eax, 16
    sub eax, [r14 + G_BEARING_X_OFF]
    cmp eax, 1
    jge .w_ok
    mov eax, 1
.w_ok:
    mov [r14 + G_WIDTH_OFF], eax

    ; height = ceil(yMax)-floor(yMin)
    mov eax, [rsp + 12]
    imul eax, r11d
    sar eax, 16
    mov edx, [r14 + G_BEARING_Y_OFF]
    sub edx, eax
    cmp edx, 1
    jge .h_ok
    mov edx, 1
.h_ok:
    mov [r14 + G_HEIGHT_OFF], edx

    mov rdi, r14
    mov rsi, [rbx + F_CACHE_ARENA_OFF]
    call rasterize_bbox_bitmap
    jmp .cache_and_ret

.compound_try:
    mov dword [parsed_edge_count], 0
    ; start with header bbox, then try to union simple component bboxes (+xy offsets)
    lea r11, [r10 + 10]                      ; component ptr
    mov eax, [rsp + 4]
    lea r15, [r9 + rax]                      ; glyph end ptr
    xor ecx, ecx                              ; safety loop counter

.compound_loop:
    inc ecx
    cmp ecx, 64
    ja .bbox_ready

    lea rax, [r11 + 4]
    cmp rax, r15
    ja .bbox_ready

    mov rdi, r11
    call be16
    mov [rsp + 24], eax                      ; flags
    lea rdi, [r11 + 2]
    call be16
    mov [rsp + 28], eax                      ; component gid
    add r11, 4

    mov dword [rsp + 32], 0                  ; dx
    mov dword [rsp + 36], 0                  ; dy

    mov eax, [rsp + 24]
    test eax, 0x0001                         ; ARG_1_AND_2_ARE_WORDS
    jz .compound_args_bytes
    lea rdx, [r11 + 4]
    cmp rdx, r15
    ja .bbox_ready
    test eax, 0x0002                         ; ARGS_ARE_XY_VALUES
    jz .compound_advance_words
    mov rdi, r11
    call be16s
    mov [rsp + 32], eax
    lea rdi, [r11 + 2]
    call be16s
    mov [rsp + 36], eax
.compound_advance_words:
    add r11, 4
    jmp .compound_transform

.compound_args_bytes:
    lea rdx, [r11 + 2]
    cmp rdx, r15
    ja .bbox_ready
    test eax, 0x0002                         ; ARGS_ARE_XY_VALUES
    jz .compound_advance_bytes
    movsx edx, byte [r11]
    mov [rsp + 32], edx
    movsx edx, byte [r11 + 1]
    mov [rsp + 36], edx
.compound_advance_bytes:
    add r11, 2

.compound_transform:
    mov eax, [rsp + 24]
    test eax, 0x0008                         ; WE_HAVE_A_SCALE
    jz .compound_no_scale1
    lea rdx, [r11 + 2]
    cmp rdx, r15
    ja .bbox_ready
    add r11, 2
.compound_no_scale1:
    mov eax, [rsp + 24]
    test eax, 0x0040                         ; WE_HAVE_AN_X_AND_Y_SCALE
    jz .compound_no_scale2
    lea rdx, [r11 + 4]
    cmp rdx, r15
    ja .bbox_ready
    add r11, 4
.compound_no_scale2:
    mov eax, [rsp + 24]
    test eax, 0x0080                         ; WE_HAVE_A_TWO_BY_TWO
    jz .compound_union
    lea rdx, [r11 + 8]
    cmp rdx, r15
    ja .bbox_ready
    add r11, 8

.compound_union:
    mov [rsp + 40], r11
    mov rdi, rbx
    mov esi, [rsp + 28]
    call glyph_fetch_header_bbox
    mov r11, [rsp + 40]
    test eax, eax
    jz .compound_next

    mov eax, [parsed_bbox_xmin]
    add eax, [rsp + 32]
    cmp eax, [rsp + 8]
    jge .c_xmin_ok
    mov [rsp + 8], eax
.c_xmin_ok:
    mov eax, [parsed_bbox_ymin]
    add eax, [rsp + 36]
    cmp eax, [rsp + 12]
    jge .c_ymin_ok
    mov [rsp + 12], eax
.c_ymin_ok:
    mov eax, [parsed_bbox_xmax]
    add eax, [rsp + 32]
    cmp eax, [rsp + 16]
    jle .c_xmax_ok
    mov [rsp + 16], eax
.c_xmax_ok:
    mov eax, [parsed_bbox_ymax]
    add eax, [rsp + 36]
    cmp eax, [rsp + 20]
    jle .c_ymax_ok
    mov [rsp + 20], eax
.c_ymax_ok:

.compound_next:
    mov eax, [rsp + 24]
    test eax, 0x0020                         ; MORE_COMPONENTS
    jnz .compound_loop
    jmp .bbox_ready

.cache_empty:
    mov dword [r14 + G_WIDTH_OFF], 0
    mov dword [r14 + G_HEIGHT_OFF], 0
    mov qword [r14 + G_BITMAP_OFF], 0
    mov dword [r14 + G_BEARING_X_OFF], 0
    mov dword [r14 + G_BEARING_Y_OFF], 0

.cache_and_ret:
    mov rdi, rbx
    mov esi, r12d
    mov edx, r13d
    mov rcx, r14
    call cache_add
    mov rax, r14
    jmp .ret

.fail:
    xor eax, eax
    jmp .ret
.ret_ok:
    ; cached rax
.ret:
    add rsp, 56
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; blend dst pixel with source color by alpha
; rdi=dst ptr, esi=color argb, edx=alpha
blend_pixel:
    mov eax, esi
    shr eax, 24
    imul eax, edx
    shr eax, 8
    test eax, eax
    jz .ret
    mov r8d, eax
    mov r9d, 255
    sub r9d, r8d
    mov ecx, [rdi]

    ; B
    mov eax, esi
    and eax, 0xFF
    imul eax, r8d
    mov edx, ecx
    and edx, 0xFF
    imul edx, r9d
    add eax, edx
    shr eax, 8
    mov r10d, eax

    ; G
    mov eax, esi
    shr eax, 8
    and eax, 0xFF
    imul eax, r8d
    mov edx, ecx
    shr edx, 8
    and edx, 0xFF
    imul edx, r9d
    add eax, edx
    shr eax, 8
    shl eax, 8
    or r10d, eax

    ; R
    mov eax, esi
    shr eax, 16
    and eax, 0xFF
    imul eax, r8d
    mov edx, ecx
    shr edx, 16
    and edx, 0xFF
    imul edx, r9d
    add eax, edx
    shr eax, 8
    shl eax, 16
    or r10d, eax

    or r10d, 0xFF000000
    mov [rdi], r10d
.ret:
    ret

; font_draw_string(font, canvas, x, y, str, len, pixel_size, color)
font_draw_string:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 72

    mov rbx, rdi                        ; font
    mov r12, rsi                        ; canvas
    mov r13, rdx                        ; pen x
    mov r14, rcx                        ; baseline y
    mov r15, r8                         ; str
    mov [rsp + 0], r9                   ; len
    mov qword [rsp + 8], 0              ; i
    mov dword [rsp + 16], 0             ; prev_gid (no kerning before first char)
    mov r10, [rbp + 16]                 ; px size
    mov r11, [rbp + 24]                 ; color

    test rbx, rbx
    jz .done
    test r12, r12
    jz .done

.char_loop:
    mov rcx, [rsp + 8]
    cmp rcx, [rsp + 0]
    jae .done

    movzx esi, byte [r15 + rcx]
    mov rdi, rbx
    call font_get_glyph_id
    mov r9d, eax                         ; current_gid
    mov esi, eax
    ; safe MVP draw: one pixel per glyph at baseline
    mov rsi, r13
    mov rdi, r14
    dec rdi
    test rsi, rsi
    js .advance
    test rdi, rdi
    js .advance
    mov ecx, [r12 + CV_WIDTH_OFF]
    cmp rsi, rcx
    jae .advance
    mov ecx, [r12 + CV_HEIGHT_OFF]
    cmp rdi, rcx
    jae .advance
    mov ecx, dword [r12 + CV_CLIP_W_OFF]
    test ecx, ecx
    jz .advance
    cmp esi, dword [r12 + CV_CLIP_X_OFF]
    jl .advance
    cmp edi, dword [r12 + CV_CLIP_Y_OFF]
    jl .advance
    mov ecx, dword [r12 + CV_CLIP_X_OFF]
    add ecx, dword [r12 + CV_CLIP_W_OFF]
    cmp esi, ecx
    jge .advance
    mov ecx, dword [r12 + CV_CLIP_Y_OFF]
    add ecx, dword [r12 + CV_CLIP_H_OFF]
    cmp edi, ecx
    jge .advance
    mov rcx, [r12 + CV_BUFFER_OFF]
    mov r8d, [r12 + CV_STRIDE_OFF]
    mov rax, rdi
    imul rax, r8
    lea rax, [rax + rsi*4]
    add rcx, rax
    mov dword [rcx], r11d

.advance:
    mov rdi, rbx
    call font_get_glyph_metrics
    imul eax, r10d
    cdq
    movsx r8, word [rbx + F_UNITS_PER_EM_OFF]
    idiv r8d
    cmp eax, 1
    jge .adv_ok
    mov eax, 1
.adv_ok:
    add r13, rax
    ; kerning(prev_gid, current_gid) scaled to pixels
    mov rdi, rbx
    mov esi, [rsp + 16]
    mov edx, r9d
    call font_get_kerning
    movsxd rax, eax
    imul rax, r10
    cqo
    movsx rcx, word [rbx + F_UNITS_PER_EM_OFF]
    test rcx, rcx
    jz .k_done
    idiv rcx
    add r13, rax
.k_done:
    mov [rsp + 16], r9d                  ; prev_gid = current_gid

.next_char:
    mov rcx, [rsp + 8]
    inc rcx
    mov [rsp + 8], rcx
    jmp .char_loop

.done:
    mov rax, r13
    add rsp, 72
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; font_measure_string(font, str, len, pixel_size)
; returns rax=width, rdx=height
font_measure_string:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 40                          ; 16-byte aligned for calls

    mov r13, rdx                         ; len (SysV 3rd arg) — before xor clobbers rdx
    mov r14d, ecx                        ; pixel_size (4th arg)

    xor eax, eax
    xor edx, edx
    test rdi, rdi
    jz .m_ret
    mov rbx, rdi
    mov r12, rsi
    movsx ecx, word [rbx + F_UNITS_PER_EM_OFF]
    test ecx, ecx
    jle .m_ret
.m_units_ok:
    mov [rsp + 0], ecx

    xor eax, eax
    mov [rsp + 24], rax                  ; width at +24
    mov dword [rsp + 16], eax            ; prev_gid
    xor r15, r15                         ; i

    test r13, r13
    jz .m_height

.m_loop:
    movzx esi, byte [r12 + r15]
    mov rdi, rbx
    call font_get_glyph_id
    mov r8d, eax                          ; current_gid

    mov rdi, rbx
    mov esi, r8d
    call font_get_glyph_metrics
    imul eax, r14d
    cdq
    idiv dword [rsp + 0]
    cmp eax, 1
    jge .m_adv_ok
    mov eax, 1
.m_adv_ok:
    movsxd rax, eax
    add [rsp + 24], rax                  ; width

    mov rdi, rbx
    mov esi, [rsp + 16]                  ; prev_gid
    mov edx, r8d
    call font_get_kerning
    imul eax, r14d
    cdq
    idiv dword [rsp + 0]
    movsxd rax, eax
    add [rsp + 24], rax                  ; width (kerning)

    mov [rsp + 16], r8d                  ; prev_gid
    inc r15
    cmp r15, r13
    jb .m_loop

.m_height:
    mov eax, [rbx + F_ASCENT_OFF]
    movsx eax, ax
    mov edx, [rbx + F_DESCENT_OFF]
    movsx edx, dx
    sub eax, edx
    cmp eax, 1
    jge .m_scale_h
    mov eax, 1
.m_scale_h:
    imul eax, r14d
    cdq
    idiv dword [rsp + 0]
    movsxd rdx, eax
    mov rax, [rsp + 24]                  ; width (may go negative with kerning)
    test rax, rax
    jns .m_width_ok
    xor eax, eax
.m_width_ok:

.m_ret:
    add rsp, 40
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
