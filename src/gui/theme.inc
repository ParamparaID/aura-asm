; theme.inc — Theme struct (first 32 bytes = widget.inc THEME_STRUCT_SIZE / TH_*)
%define T_ACCENT_OFF            0
%define T_BG_OFF                4
%define T_SURFACE_OFF           8
%define T_FG_OFF                12
%define T_TEXT_SECONDARY_OFF    16
%define T_PAD20_OFF             20
%define T_FONT_MAIN_OFF         24

%define T_FONT_MAIN_SIZE_OFF    32
%define T_FONT_UI_SIZE_OFF      36
%define T_FONT_UI_OFF           40

%define T_BORDER_COLOR_OFF      48
%define T_ERROR_OFF             52
%define T_SUCCESS_OFF           56
%define T_WARNING_OFF           60
%define T_TEXT_PRIMARY_OFF      64

%define T_BORDER_WIDTH_OFF      68
%define T_CORNER_RADIUS_OFF     72
%define T_GAP_OFF               76
%define T_BLUR_RADIUS_OFF       80

%define T_SPRING_STIFF_OFF      84
%define T_SPRING_DAMP_OFF       88
%define T_TRANSITION_MS_OFF     92

%define T_LOADED_OFF            96
%define T_MMAP_PTR_OFF          104
%define T_MMAP_LEN_OFF          112
%define THEME_STRUCT_SIZE       120

%define THSEC_NONE                0
%define THSEC_COLORS              1
%define THSEC_FONTS               2
%define THSEC_WINDOW              3
%define THSEC_ANIMATION           4
