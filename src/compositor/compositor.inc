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
%define CC_RESOURCES_OFF           80    ; 64 * qword
%define CC_STRUCT_SIZE             (80 + 64*8)

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

%endif
