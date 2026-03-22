; gesture.inc — Gesture recognizer constants and layout

%define GESTURE_NONE                0
%define GESTURE_TAP                 1
%define GESTURE_LONG_PRESS          2
%define GESTURE_SWIPE_LEFT          3
%define GESTURE_SWIPE_RIGHT         4
%define GESTURE_SWIPE_UP            5
%define GESTURE_SWIPE_DOWN          6
%define GESTURE_PINCH               7
%define GESTURE_PAN                 8
%define GESTURE_TWO_FINGER_SWIPE    9
%define GESTURE_THREE_FINGER_DOWN   10
%define GESTURE_THREE_FINGER_UP     11

%define GESTURE_STATE_IDLE          0
%define GESTURE_STATE_POSSIBLE      1
%define GESTURE_STATE_RECOGNIZED    2
%define GESTURE_STATE_ENDED         3

; Per-touch slot (64 bytes)
%define GT_ID_OFF                   0
%define GT_START_X_OFF              4
%define GT_START_Y_OFF              8
%define GT_CUR_X_OFF                12
%define GT_CUR_Y_OFF                16
%define GT_START_TIME_OFF           24
%define GT_LAST_TIME_OFF            32
%define GT_IN_USE_OFF               40
%define GT_TOUCH_STRIDE             64
%define GT_MAX_TOUCHES              10

%define GR_STATE_OFF                0
%define GR_ACTIVE_TOUCHES_OFF       4
%define GR_TOUCH_DATA_OFF           8
%define GR_START_TIME_OFF           (GR_TOUCH_DATA_OFF + GT_TOUCH_STRIDE * GT_MAX_TOUCHES)
%define GR_LAST_EVENT_TIME_OFF      (GR_START_TIME_OFF + 8)
%define GR_TAP_MAX_DURATION_OFF     (GR_LAST_EVENT_TIME_OFF + 8)
%define GR_LONG_PRESS_DURATION_OFF  (GR_TAP_MAX_DURATION_OFF + 4)
%define GR_SWIPE_MIN_DISTANCE_OFF   (GR_LONG_PRESS_DURATION_OFF + 4)
%define GR_PINCH_MIN_DISTANCE_OFF   (GR_SWIPE_MIN_DISTANCE_OFF + 4)
%define GR_PAN_THRESHOLD_OFF        (GR_PINCH_MIN_DISTANCE_OFF + 4)
%define GR_RECOGNIZED_GESTURE_OFF   (GR_PAN_THRESHOLD_OFF + 4)
%define GR_LONG_FIRED_OFF           (GR_RECOGNIZED_GESTURE_OFF + 4)
%define GR_SWIPE_TRACK_OFF          (GR_LONG_FIRED_OFF + 4)
%define GR_GESTURE_DATA_OFF         (GR_SWIPE_TRACK_OFF + 4)
%define GR_STRUCT_SIZE              (GR_GESTURE_DATA_OFF + 64)

; Gesture data out (64 bytes) — deltas, scale, velocity
%define GD_DELTA_X_OFF              0
%define GD_DELTA_Y_OFF              4
%define GD_SCALE_OFF                8
%define GD_VELOCITY_OFF             12
%define GD_DURATION_MS_OFF          16

; Mirror input.asm for tests / gesture.asm
%define INPUT_EVENT_TYPE_OFF        0
%define INPUT_EVENT_TIMESTAMP_OFF   8
%define INPUT_EVENT_MOUSE_X_OFF     28
%define INPUT_EVENT_MOUSE_Y_OFF     32
%define INPUT_EVENT_TOUCH_ID_OFF    44

%define INPUT_TOUCH_DOWN            4
%define INPUT_TOUCH_UP              5
%define INPUT_TOUCH_MOVE            6
