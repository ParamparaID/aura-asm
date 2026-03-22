; layout.inc — Flex-like layout params and flex container metadata

; LayoutParams (48 bytes, aligned)
%define LP_DIRECTION_OFF          0
%define LP_WRAP_OFF               4
%define LP_JUSTIFY_OFF            8
%define LP_ALIGN_OFF              12
%define LP_FLEX_GROW_OFF          16
%define LP_FLEX_SHRINK_OFF        20
%define LP_MARGIN_T_OFF           24
%define LP_MARGIN_R_OFF           28
%define LP_MARGIN_B_OFF           32
%define LP_MARGIN_L_OFF           36
%define LP_GAP_OFF                40
%define LP_STRUCT_SIZE            48

%define LAYOUT_ROW                0
%define LAYOUT_COLUMN             1

%define LAYOUT_WRAP_NONE          0
%define LAYOUT_WRAP_WRAP          1

%define JUSTIFY_START             0
%define JUSTIFY_CENTER            1
%define JUSTIFY_END               2
%define JUSTIFY_BETWEEN           3
%define JUSTIFY_AROUND            4

%define ALIGN_START               0
%define ALIGN_CENTER              1
%define ALIGN_END                 2
%define ALIGN_STRETCH             3

; Responsive breakpoints (viewport width px)
%define BREAKPOINT_PHONE          600
%define BREAKPOINT_TABLET         1200

%define FORM_PHONE                0
%define FORM_TABLET               1
%define FORM_DESKTOP              2

; FlexContainerData (follows active LayoutParams at offset 0)
%define FCD_LAYOUT_OFF            0
%define FCD_PAD_TOP_OFF           48
%define FCD_PAD_RIGHT_OFF         52
%define FCD_PAD_BOTTOM_OFF        56
%define FCD_PAD_LEFT_OFF          60
%define FCD_LP_PHONE_OFF          64
%define FCD_LP_TABLET_OFF         72
%define FCD_LP_DESKTOP_OFF        80
%define FCD_STRUCT_SIZE           88
