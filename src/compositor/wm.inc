; wm.inc — Window manager constants/state layout
%ifndef AURA_WM_INC
%define AURA_WM_INC

%define WM_MAX_SURFACES             128

%define WM_MODE_TILING              0
%define WM_MODE_FLOATING            1

%define WM_EDGE_NONE                0
%define WM_EDGE_TOP                 1
%define WM_EDGE_BOTTOM              2
%define WM_EDGE_LEFT                3
%define WM_EDGE_RIGHT               4
%define WM_EDGE_TOPLEFT             5
%define WM_EDGE_TOPRIGHT            6
%define WM_EDGE_BOTTOMLEFT          7
%define WM_EDGE_BOTTOMRIGHT         8

%define WM_DIR_LEFT                 0
%define WM_DIR_RIGHT                1
%define WM_DIR_UP                   2
%define WM_DIR_DOWN                 3

; WMState layout
%define WM_SURFACES_OFF             0                         ; dq[128]
%define WM_SURFACE_COUNT_OFF        (WM_SURFACES_OFF + 8*WM_MAX_SURFACES)
%define WM_FOCUS_STACK_OFF          (WM_SURFACE_COUNT_OFF + 4) ; dq[128]
%define WM_FOCUS_COUNT_OFF          (WM_FOCUS_STACK_OFF + 8*WM_MAX_SURFACES)
%define WM_MODE_OFF                 (WM_FOCUS_COUNT_OFF + 4)
%define WM_OUTPUT_X_OFF             (WM_MODE_OFF + 4)
%define WM_OUTPUT_Y_OFF             (WM_OUTPUT_X_OFF + 4)
%define WM_OUTPUT_W_OFF             (WM_OUTPUT_Y_OFF + 4)
%define WM_OUTPUT_H_OFF             (WM_OUTPUT_W_OFF + 4)
%define WM_GAP_OFF                  (WM_OUTPUT_H_OFF + 4)
%define WM_TILING_ROOT_OFF          (WM_GAP_OFF + 4)         ; dq
%define WM_DRAG_SURFACE_OFF         (WM_TILING_ROOT_OFF + 8) ; dq
%define WM_DRAG_OFFSET_X_OFF        (WM_DRAG_SURFACE_OFF + 8)
%define WM_DRAG_OFFSET_Y_OFF        (WM_DRAG_OFFSET_X_OFF + 4)
%define WM_RESIZE_SURFACE_OFF       (WM_DRAG_OFFSET_Y_OFF + 4) ; dq
%define WM_RESIZE_EDGE_OFF          (WM_RESIZE_SURFACE_OFF + 8)
%define WM_STRUCT_SIZE              (WM_RESIZE_EDGE_OFF + 4)

; Tiling node layout
%define TILING_LEAF                 0
%define TILING_SPLIT_H              1
%define TILING_SPLIT_V              2

%define TN_TYPE_OFF                 0
%define TN_SURFACE_OFF              8
%define TN_FIRST_OFF                16
%define TN_SECOND_OFF               24
%define TN_RATIO_OFF                32
%define TN_X_OFF                    36
%define TN_Y_OFF                    40
%define TN_W_OFF                    44
%define TN_H_OFF                    48
%define TN_STRUCT_SIZE              52

%define FP_HALF                     0x00008000
%define FP_ONE                      0x00010000

%endif
