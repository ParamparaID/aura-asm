; workspaces.inc — Module Spaces / Hub / Overview layouts
%ifndef AURA_WORKSPACES_INC
%define AURA_WORKSPACES_INC

%define WORKSPACE_MAX_COUNT          10
%define WORKSPACE_MAX_SURFACES       64

; Workspace
%define WS_ID_OFF                    0
%define WS_NAME_OFF                  4
%define WS_NAME_LEN_OFF              36
%define WS_SURFACES_OFF              40
%define WS_SURFACE_COUNT_OFF         552
%define WS_ACTIVE_OFF                556
%define WS_TILING_ROOT_OFF           560
%define WS_STRUCT_SIZE               568

; WorkspaceManager
%define WSM_WORKSPACES_OFF           0
%define WSM_COUNT_OFF                (WSM_WORKSPACES_OFF + WS_STRUCT_SIZE * WORKSPACE_MAX_COUNT)
%define WSM_ACTIVE_IDX_OFF           (WSM_COUNT_OFF + 4)
%define WSM_PREV_IDX_OFF             (WSM_ACTIVE_IDX_OFF + 4)
%define WSM_TRANSITION_OFF           (WSM_PREV_IDX_OFF + 4) ; Spring(28)
%define WSM_TRANSITIONING_OFF        (WSM_TRANSITION_OFF + 28)
%define WSM_HUB_MODE_OFF             (WSM_TRANSITIONING_OFF + 4)
%define WSM_OVERVIEW_MODE_OFF        (WSM_HUB_MODE_OFF + 4)
%define WSM_STRUCT_SIZE              (WSM_OVERVIEW_MODE_OFF + 4)

; Hub
%define HUB_WIDGETS_OFF              0
%define HUB_WIDGET_COUNT_OFF         256
%define HUB_SCROLL_Y_OFF             260
%define HUB_CANVAS_HEIGHT_OFF        264
%define HUB_ACTIVE_OFF               268
%define HUB_STRUCT_SIZE              272

; Overview item metadata
%define OV_THUMB_X_OFF               0
%define OV_THUMB_Y_OFF               4
%define OV_THUMB_W_OFF               8
%define OV_THUMB_H_OFF               12
%define OV_THUMB_SCALE_OFF           16
%define OV_THUMB_SURFACE_OFF         24
%define OV_THUMB_STRIDE              32

%define OV_MAX_THUMBS                64

; Shared transition directions
%define TR_DIR_LEFT                  0
%define TR_DIR_RIGHT                 1
%define TR_DIR_UP                    2
%define TR_DIR_DOWN                  3

%endif
