%ifndef AURA_FM_VIEWER_INC
%define AURA_FM_VIEWER_INC

%define SYNTAX_NONE                 0
%define SYNTAX_ASM                  1
%define SYNTAX_C                    2
%define SYNTAX_PYTHON               3
%define SYNTAX_SHELL                4
%define SYNTAX_JS                   5

%define VIEWER_MAX_LINES            131072
%define VIEWER_MAX_HITS             4096
%define VIEWER_MAX_INSTANCES        4

; Viewer layout
%define V_FILE_DATA_OFF             0
%define V_FILE_SIZE_OFF             8
%define V_LINES_PTR_OFF             16
%define V_LINE_COUNT_OFF            24
%define V_TOP_LINE_OFF              32
%define V_CURSOR_LINE_OFF           40
%define V_CURSOR_COL_OFF            48
%define V_HEX_MODE_OFF              56
%define V_SEARCH_STR_OFF            60
%define V_SEARCH_LEN_OFF            316
%define V_SEARCH_HITS_PTR_OFF       320
%define V_HIT_COUNT_OFF             328
%define V_CURRENT_HIT_OFF           332
%define V_SYNTAX_TYPE_OFF           336
%define V_SCROLL_Y_OFF              340
%define V_IN_USE_OFF                344
%define V_STRUCT_HEAD_SIZE          352

%endif
