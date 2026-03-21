; widget.inc — Widget tree base layout (128 bytes, vtable inline)
; Co-render / input: absolute origin passed separately (fn_render gets abs_x, abs_y).

%define TOUCH_TARGET_MIN          44

; Widget offsets
%define W_TYPE_OFF                0
%define W_ID_OFF                  4
%define W_X_OFF                   8
%define W_Y_OFF                   12
%define W_WIDTH_OFF               16
%define W_HEIGHT_OFF              20
%define W_MIN_W_OFF               24
%define W_MIN_H_OFF               28
%define W_PREF_W_OFF              32
%define W_PREF_H_OFF              36
%define W_VISIBLE_OFF             40
%define W_ENABLED_OFF             44
%define W_FOCUSED_OFF             48
%define W_DIRTY_OFF               52
%define W_PARENT_OFF              56
%define W_CHILDREN_OFF            64
%define W_CHILD_COUNT_OFF         72
%define W_CHILD_CAP_OFF           76
%define W_FN_RENDER_OFF           80
%define W_FN_HANDLE_OFF           88
%define W_FN_MEASURE_OFF          96
%define W_FN_LAYOUT_OFF           104
%define W_FN_DESTROY_OFF          112
%define W_DATA_OFF                120
%define WIDGET_STRUCT_SIZE        128

; Note: pad_* / scroll_* from TZ live in type-specific data blocks (ListData, …).

; Widget type ids
%define WIDGET_LABEL              1
%define WIDGET_BUTTON             2
%define WIDGET_TEXT_INPUT         3
%define WIDGET_TEXT_AREA          4
%define WIDGET_LIST               5
%define WIDGET_TABLE              6
%define WIDGET_TREE               7
%define WIDGET_SCROLLBAR          8
%define WIDGET_RADIAL_MENU        9
%define WIDGET_BOTTOM_SHEET       10
%define WIDGET_TAB_BAR            11
%define WIDGET_PROGRESS_BAR       12
%define WIDGET_DIALOG             13
%define WIDGET_STATUS_BAR         14
%define WIDGET_SPLIT_PANE         15
%define WIDGET_CONTAINER          16

; Minimal theme (passed as rdx to render/measure helpers)
%define TH_ACCENT_OFF             0
%define TH_BG_OFF                 4
%define TH_SURFACE_OFF            8
%define TH_FG_OFF                 12
%define TH_MUTED_OFF              16
%define TH_FONT_OFF               24
%define THEME_STRUCT_SIZE         32

; InputEvent (mirror core/input.asm)
%define IE_TYPE_OFF               0
%define IE_KEY_CODE_OFF           16
%define IE_KEY_STATE_OFF          20
%define IE_MOUSE_X_OFF            28
%define IE_MOUSE_Y_OFF            32
%define IE_SCROLL_DY_OFF          40

%define INPUT_KEY                 1
%define INPUT_MOUSE_BUTTON        3
%define INPUT_TOUCH_DOWN          4
%define INPUT_TOUCH_UP            5
%define INPUT_TOUCH_MOVE          6
%define INPUT_SCROLL              7

%define KEY_PRESSED               1
%define KEY_LEFT                  105
%define KEY_RIGHT                 106
%define KEY_HOME                  102
%define KEY_END                   107

%include "src/canvas/canvas.inc"
