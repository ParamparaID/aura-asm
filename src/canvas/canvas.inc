; canvas.inc — AuraCanvas layout (ARGB32 buffer + clip stack)
; Include after defs.inc where needed.
;
; Pixel words: portable drawing uses 0xAARRGGBB. On Win32, a 32-bpp BI_RGB
; DIB stores bytes B,G,R,A in memory; the same 32-bit value still produces the
; intended color when written through the canvas APIs (no extra swap at present).

%define CV_BUFFER_OFF            0
%define CV_WIDTH_OFF             8
%define CV_HEIGHT_OFF            12
%define CV_STRIDE_OFF            16
%define CV_PAD_OFF               20
%define CV_SIZE_OFF              24
%define CV_CLIP_STACK_OFF        32
%define CV_CLIP_DEPTH_OFF        288
%define CV_CLIP_X_OFF            292
%define CV_CLIP_Y_OFF            296
%define CV_CLIP_W_OFF            300
%define CV_CLIP_H_OFF            304
%define CV_STRUCT_SIZE           312

%define CV_CLIP_MAX_DEPTH        16
%define CV_CLIP_ENTRY_SIZE       16
