%ifndef AURA_FM_PANEL_INC
%define AURA_FM_PANEL_INC

%include "src/fm/vfs.inc"

%define SORT_NAME                   0
%define SORT_SIZE                   1
%define SORT_DATE                   2
%define SORT_EXT                    3

; Panel public layout
%define P_PATH_OFF                  0
%define P_PATH_LEN_OFF              1024
%define P_ENTRIES_PTR_OFF           1032
%define P_ENTRY_COUNT_OFF           1040
%define P_SELECTED_IDX_OFF          1044
%define P_SCROLL_OFF                1048
%define P_MARKED_PTR_OFF            1056
%define P_MARKED_COUNT_OFF          1064
%define P_SORT_COLUMN_OFF           1068
%define P_SORT_ASC_OFF              1072
%define P_SHOW_HIDDEN_OFF           1076
%define P_FILTER_OFF                1080
%define P_FILTER_LEN_OFF            1144
%define P_VFS_PROVIDER_OFF          1152
%define P_ACTIVE_OFF                1160

; private area used by panel.asm
%define P_PRIV_PAD_OFF              1164
%define P_ENTRIES_BUF_OFF           1168
%define P_MARK_BITS_OFF             (P_ENTRIES_BUF_OFF + (DIR_ENTRY_SIZE * VFS_MAX_DIR_ENTRIES))
%define P_TMP_PATH_OFF              (P_MARK_BITS_OFF + (VFS_MAX_DIR_ENTRIES / 8))
%define PANEL_STRUCT_SIZE           (P_TMP_PATH_OFF + VFS_MAX_PATH)

%define PANEL_MAX_INSTANCES         8

%endif
