; platform_defs.inc — pick Linux vs Windows HAL constants for portable .asm
%ifndef AURA_PLATFORM_DEFS_INC
%define AURA_PLATFORM_DEFS_INC

%ifdef AURA_WIN64
%include "src/hal/win_x86_64/defs.inc"
%else
%include "src/hal/linux_x86_64/defs.inc"
%endif

%endif
