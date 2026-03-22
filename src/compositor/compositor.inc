; compositor.inc — Wayland compositor server layout (Phase 3)
; Include from server/protocol/registry asm.

%ifndef AURA_COMPOSITOR_INC
%define AURA_COMPOSITOR_INC

; --- CompositorServer ---
%define CS_LISTEN_FD_OFF          0
%define CS_SOCKET_PATH_OFF         4    ; 256 bytes (after dd padding)
%define CS_DISPLAY_NAME_OFF        260  ; 4 + 256
%define CS_CLIENTS_OFF             276  ; dq
%define CS_CLIENT_COUNT_OFF        284
%define CS_CLIENT_CAP_OFF          288
%define CS_NEXT_GLOBAL_OFF         292
%define CS_NEXT_SERIAL_OFF         296
%define CS_EVENT_LOOP_OFF          300  ; dq
%define CS_ARENA_OFF               308  ; dq
%define CS_STRUCT_SIZE             316

; --- ClientConnection ---
%define CC_FD_OFF                  0
%define CC_ID_OFF                  4
%define CC_SERVER_OFF              8    ; dq -> CompositorServer*
%define CC_RES_COUNT_OFF           16
%define CC_RES_CAP_OFF             20
%define CC_NEXT_SRV_ID_OFF         24
%define CC_ALIVE_OFF               28
%define CC_RECV_BUF_OFF            32   ; dq
%define CC_RECV_LEN_OFF            40
%define CC_RECV_CAP_OFF            44
%define CC_SEND_BUF_OFF            48   ; dq
%define CC_SEND_LEN_OFF            56
%define CC_SEND_CAP_OFF            60
%define CC_COMPOSITOR_ID_OFF       64
%define CC_SHM_ID_OFF              68
%define CC_SEAT_ID_OFF             72
%define CC_WM_BASE_ID_OFF          76
%define CC_PENDING_FD_OFF          80    ; dd: fd from SCM_RIGHTS for next create_pool, or -1
%define CC_RESOURCES_OFF           84    ; 64 * qword
%define CC_STRUCT_SIZE             (84 + 64*8)

; --- Resource ---
%define RES_ID_OFF                 0
%define RES_TYPE_OFF               4
%define RES_DATA_OFF               8
%define RES_CLIENT_OFF             16
%define RES_STRUCT_SIZE            24

; Resource.type
%define RESOURCE_DISPLAY           1
%define RESOURCE_REGISTRY          2
%define RESOURCE_COMPOSITOR        3
%define RESOURCE_SHM               4
%define RESOURCE_SHM_POOL          5
%define RESOURCE_BUFFER            6
%define RESOURCE_SURFACE           7
%define RESOURCE_XDG_WM_BASE       8
%define RESOURCE_XDG_SURFACE       9
%define RESOURCE_XDG_TOPLEVEL      10
%define RESOURCE_SEAT              11
%define RESOURCE_KEYBOARD          12
%define RESOURCE_POINTER           13
%define RESOURCE_TOUCH             14
%define RESOURCE_CALLBACK          15
%define RESOURCE_OUTPUT            16

%define CLIENT_IO_BUF_CAP          4096
%define CLIENT_MAX_RESOURCES       64
%define SERVER_MAX_CLIENTS         32

; --- ShmPool ---
%define POOL_ID_OFF                0
%define POOL_CLIENT_OFF            8
%define POOL_FD_OFF                16
%define POOL_SIZE_OFF              24
%define POOL_DATA_OFF              32
%define POOL_STRUCT_SIZE           40

; --- Buffer (wl_buffer / SHM) ---
%define BUF_ID_OFF                 0
%define BUF_POOL_OFF               8
%define BUF_OFFSET_OFF             16
%define BUF_WIDTH_OFF              20
%define BUF_HEIGHT_OFF             24
%define BUF_STRIDE_OFF             28
%define BUF_FORMAT_OFF             32
%define BUF_BUSY_OFF               36
%define BUF_PIXELS_OFF             40
%define BUF_STRUCT_SIZE            48

; --- Surface ---
%define SF_ID_OFF                  0
%define SF_CLIENT_OFF              8
%define SF_PENDING_BUF_OFF         16
%define SF_PENDING_X_OFF           24
%define SF_PENDING_Y_OFF           28
%define SF_PENDING_DMG_OFF         32     ; x,y,w,h
%define SF_PENDING_HAS_DMG_OFF     48
%define SF_ATTACH_DIRTY_OFF        52    ; attach() since last commit
%define SF_CURRENT_BUF_OFF         56
%define SF_CURRENT_X_OFF           64
%define SF_CURRENT_Y_OFF           68
%define SF_PREV_BUF_ID_OFF         72     ; for wl_buffer.release after commit
%define SF_SCREEN_X_OFF            76
%define SF_SCREEN_Y_OFF            80
%define SF_WIDTH_OFF               84
%define SF_HEIGHT_OFF              88
%define SF_MAPPED_OFF              92
%define SF_FRAME_CB_OFF            96
%define SF_XDG_SURF_ID_OFF         100
%define SF_XDG_TOP_ID_OFF          104
%define SF_TITLE_OFF               108
%define SF_TITLE_LEN_OFF           236
%define SF_APP_ID_OFF              240    ; resb 64
%define SF_APP_ID_LEN_OFF          304
%define SF_WORKSPACE_OFF           308
%define SF_Z_ORDER_OFF             312
%define SF_FLOATING_OFF            316
%define SF_XDG_CONFIGURED_OFF      320
%define SF_LAST_CFG_SERIAL_OFF     324
%define SF_STRUCT_SIZE             328

%define WL_SHM_FORMAT_ARGB8888     0
%define WL_SHM_FORMAT_XRGB8888     1

%endif
