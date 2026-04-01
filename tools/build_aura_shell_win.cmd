@echo off
setlocal EnableExtensions
cd /d "%~dp0.."

set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE%" (
  echo ERROR: vswhere.exe not found. Install Visual Studio with C++ workload.
  exit /b 1
)
for /f "usebackq delims=" %%I in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VSHOME=%%I"
set "VCVARS=%VSHOME%\VC\Auxiliary\Build\vcvars64.bat"
if not exist "%VCVARS%" (
  echo ERROR: vcvars64.bat not found at "%VCVARS%"
  exit /b 1
)

call "%VCVARS%" || exit /b 1

if not "%~1"=="" (set "NASM=%~1") else (set "NASM=%LOCALAPPDATA%\bin\NASM\nasm.exe")
if not exist "%NASM%" (
  echo ERROR: NASM not found at "%NASM%". Usage: %~nx0 [path\to\nasm.exe]
  exit /b 1
)

if not exist "build\win_x86_64" mkdir "build\win_x86_64"

set "FW=-f win64 -g -F cv8"
set "FP=-f win64 -g -F cv8 -DAURA_WIN64"

echo === Assembling Win HAL ===
"%NASM%" %FW% -o "build\win_x86_64\bootstrap.obj"       "src\hal\win_x86_64\bootstrap.asm"       || goto :fail
"%NASM%" %FW% -o "build\win_x86_64\abi.obj"             "src\hal\win_x86_64\abi.asm"             || goto :fail
"%NASM%" %FW% -o "build\win_x86_64\memory.obj"          "src\hal\win_x86_64\memory.asm"          || goto :fail
"%NASM%" %FW% -o "build\win_x86_64\time.obj"           "src\hal\win_x86_64\time.asm"            || goto :fail
"%NASM%" %FW% -o "build\win_x86_64\threads.obj"        "src\hal\win_x86_64\threads.asm"         || goto :fail
"%NASM%" %FW% -o "build\win_x86_64\syscall.obj"        "src\hal\win_x86_64\syscall.asm"         || goto :fail
"%NASM%" %FW% -o "build\win_x86_64\fileio.obj"         "src\hal\win_x86_64\fileio.asm"          || goto :fail
"%NASM%" %FW% -o "build\win_x86_64\window.obj"         "src\hal\win_x86_64\window.asm"          || goto :fail
"%NASM%" %FW% -o "build\win_x86_64\gdi.obj"            "src\hal\win_x86_64\gdi.asm"             || goto :fail
"%NASM%" %FW% -o "build\win_x86_64\executor_win.obj"   "src\hal\win_x86_64\executor_win.asm"    || goto :fail
"%NASM%" %FW% -o "build\win_x86_64\keymap.obj"         "src\hal\win_x86_64\keymap.asm"          || goto :fail

echo === Assembling portable objects (AURA_WIN64) ===
"%NASM%" %FP% -o "build\win_x86_64\core_memory.obj"     "src\core\memory.asm"     || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\core_input.obj"      "src\core\input.asm"      || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\core_threads.obj"   "src\core\threads.asm"   || goto :fail

"%NASM%" %FP% -o "build\win_x86_64\canvas_rasterizer.obj" "src\canvas\rasterizer.asm" || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\canvas_text.obj"       "src\canvas\text.asm"       || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\canvas_simd.obj"       "src\canvas\simd.asm"       || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\canvas_truetype.obj"   "src\canvas\truetype.asm"   || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\canvas_png.obj"        "src\canvas\png.asm"        || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\canvas_gradient.obj"   "src\canvas\gradient.asm"   || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\canvas_rounded.obj"    "src\canvas\rounded.asm"    || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\canvas_blur.obj"       "src\canvas\blur.asm"       || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\canvas_composite.obj"  "src\canvas\composite.asm"  || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\canvas_line.obj"       "src\canvas\line.asm"       || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\canvas_clip.obj"       "src\canvas\clip.asm"       || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\canvas_physics.obj"    "src\canvas\physics.asm"    || goto :fail

"%NASM%" %FP% -o "build\win_x86_64\gui_widget.obj"        "src\gui\widget.asm"        || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\gui_layout.obj"        "src\gui\layout.asm"        || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\gui_theme.obj"         "src\gui\theme.asm"         || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\gui_terminal.obj"      "src\gui\terminal.asm"      || goto :fail

"%NASM%" %FP% -o "build\win_x86_64\widget_label.obj"         "src\gui\widgets\label.asm"          || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\widget_button.obj"        "src\gui\widgets\button.asm"         || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\widget_text_input.obj"    "src\gui\widgets\text_input.asm"     || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\widget_text_area.obj"     "src\gui\widgets\text_area.asm"      || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\widget_list.obj"          "src\gui\widgets\list.asm"           || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\widget_table.obj"           "src\gui\widgets\table.asm"            || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\widget_tree.obj"           "src\gui\widgets\tree.asm"            || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\widget_scrollbar.obj"     "src\gui\widgets\scrollbar.asm"       || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\widget_radial_menu.obj"   "src\gui\widgets\radial_menu.asm"     || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\widget_bottom_sheet.obj"  "src\gui\widgets\bottom_sheet.asm"    || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\widget_tab_bar.obj"       "src\gui\widgets\tab_bar.asm"         || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\widget_progress_bar.obj"  "src\gui\widgets\progress_bar.asm"    || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\widget_dialog.obj"        "src\gui\widgets\dialog.asm"          || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\widget_status_bar.obj"    "src\gui\widgets\status_bar.asm"      || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\widget_split_pane.obj"    "src\gui\widgets\split_pane.asm"      || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\widget_container.obj"    "src\gui\widgets\container.asm"       || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\widget_file_panel.obj"    "src\gui\widgets\file_panel.asm"      || goto :fail

"%NASM%" %FP% -o "build\win_x86_64\shell_repl.obj"       "src\shell\repl.asm"       || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\shell_lexer.obj"      "src\shell\lexer.asm"      || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\shell_parser.obj"     "src\shell\parser.asm"     || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\shell_executor.obj"   "src\shell\executor.asm"   || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\shell_pipeline.obj"   "src\shell\pipeline.asm"   || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\shell_variables.obj"  "src\shell\variables.asm"  || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\shell_alias.obj"      "src\shell\alias.asm"      || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\shell_history.obj"    "src\shell\history.asm"    || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\shell_jobs.obj"       "src\shell\jobs.asm"       || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\shell_builtins.obj"   "src\shell\builtins.asm"   || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\shell_macros.obj"     "src\shell\macros.asm"     || goto :fail

"%NASM%" %FP% -o "build\win_x86_64\fm_vfs.obj"           "src\fm\vfs.asm"           || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\fm_vfs_local.obj"    "src\fm\vfs_local.asm"    || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\fm_operations.obj"   "src\fm\operations.asm"   || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\fm_search.obj"       "src\fm\search.asm"       || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\fm_panel.obj"        "src\fm\panel.asm"        || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\fm_archive.obj"      "src\fm\archive.asm"      || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\fm_vfs_archive.obj"  "src\fm\vfs_archive.asm"  || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\fm_ssh.obj"          "src\fm\ssh.asm"          || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\fm_sftp.obj"         "src\fm\sftp.asm"         || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\fm_vfs_sftp.obj"     "src\fm\vfs_sftp.asm"     || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\fm_main.obj"         "src\fm\fm_main.asm"      || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\fm_status_bar.obj"   "src\fm\fm_status_bar.asm" || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\fm_viewer.obj"       "src\fm\viewer.asm"       || goto :fail

"%NASM%" %FP% -o "build\win_x86_64\plugin_manifest.obj"  "src\plugins\manifest.asm"  || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\plugin_api.obj"       "src\plugins\api.asm"       || goto :fail
"%NASM%" %FP% -o "build\win_x86_64\plugin_registry.obj"  "src\plugins\registry.asm"  || goto :fail
"%NASM%" %FW% -o "build\win_x86_64\plugin_host_win_stub.obj" "src\plugins\host_win_stub.asm" || goto :fail

"%NASM%" %FW% -o "build\win_x86_64\main_win.obj"         "src\main_win.asm"         || goto :fail

set "LFLAGS=/NOLOGO /MACHINE:X64 /SUBSYSTEM:WINDOWS /NODEFAULTLIB /ENTRY:_start /LARGEADDRESSAWARE:NO"
echo === Linking aura_shell_win.exe ===
link %LFLAGS% /OUT:"aura_shell_win.exe" ^
  "build\win_x86_64\main_win.obj" ^
  "build\win_x86_64\bootstrap.obj" ^
  "build\win_x86_64\abi.obj" ^
  "build\win_x86_64\syscall.obj" ^
  "build\win_x86_64\fileio.obj" ^
  "build\win_x86_64\memory.obj" ^
  "build\win_x86_64\time.obj" ^
  "build\win_x86_64\threads.obj" ^
  "build\win_x86_64\window.obj" ^
  "build\win_x86_64\gdi.obj" ^
  "build\win_x86_64\executor_win.obj" ^
  "build\win_x86_64\keymap.obj" ^
  "build\win_x86_64\core_memory.obj" ^
  "build\win_x86_64\core_input.obj" ^
  "build\win_x86_64\core_threads.obj" ^
  "build\win_x86_64\canvas_rasterizer.obj" ^
  "build\win_x86_64\canvas_text.obj" ^
  "build\win_x86_64\canvas_simd.obj" ^
  "build\win_x86_64\canvas_truetype.obj" ^
  "build\win_x86_64\canvas_png.obj" ^
  "build\win_x86_64\canvas_gradient.obj" ^
  "build\win_x86_64\canvas_rounded.obj" ^
  "build\win_x86_64\canvas_blur.obj" ^
  "build\win_x86_64\canvas_composite.obj" ^
  "build\win_x86_64\canvas_line.obj" ^
  "build\win_x86_64\canvas_clip.obj" ^
  "build\win_x86_64\canvas_physics.obj" ^
  "build\win_x86_64\gui_widget.obj" ^
  "build\win_x86_64\gui_layout.obj" ^
  "build\win_x86_64\gui_theme.obj" ^
  "build\win_x86_64\gui_terminal.obj" ^
  "build\win_x86_64\widget_label.obj" ^
  "build\win_x86_64\widget_button.obj" ^
  "build\win_x86_64\widget_text_input.obj" ^
  "build\win_x86_64\widget_text_area.obj" ^
  "build\win_x86_64\widget_list.obj" ^
  "build\win_x86_64\widget_table.obj" ^
  "build\win_x86_64\widget_tree.obj" ^
  "build\win_x86_64\widget_scrollbar.obj" ^
  "build\win_x86_64\widget_radial_menu.obj" ^
  "build\win_x86_64\widget_bottom_sheet.obj" ^
  "build\win_x86_64\widget_tab_bar.obj" ^
  "build\win_x86_64\widget_progress_bar.obj" ^
  "build\win_x86_64\widget_dialog.obj" ^
  "build\win_x86_64\widget_status_bar.obj" ^
  "build\win_x86_64\widget_split_pane.obj" ^
  "build\win_x86_64\widget_container.obj" ^
  "build\win_x86_64\widget_file_panel.obj" ^
  "build\win_x86_64\shell_repl.obj" ^
  "build\win_x86_64\shell_lexer.obj" ^
  "build\win_x86_64\shell_parser.obj" ^
  "build\win_x86_64\shell_executor.obj" ^
  "build\win_x86_64\shell_pipeline.obj" ^
  "build\win_x86_64\shell_variables.obj" ^
  "build\win_x86_64\shell_alias.obj" ^
  "build\win_x86_64\shell_history.obj" ^
  "build\win_x86_64\shell_jobs.obj" ^
  "build\win_x86_64\shell_builtins.obj" ^
  "build\win_x86_64\shell_macros.obj" ^
  "build\win_x86_64\fm_vfs.obj" ^
  "build\win_x86_64\fm_vfs_local.obj" ^
  "build\win_x86_64\fm_operations.obj" ^
  "build\win_x86_64\fm_search.obj" ^
  "build\win_x86_64\fm_panel.obj" ^
  "build\win_x86_64\fm_archive.obj" ^
  "build\win_x86_64\fm_vfs_archive.obj" ^
  "build\win_x86_64\fm_ssh.obj" ^
  "build\win_x86_64\fm_sftp.obj" ^
  "build\win_x86_64\fm_vfs_sftp.obj" ^
  "build\win_x86_64\fm_main.obj" ^
  "build\win_x86_64\fm_status_bar.obj" ^
  "build\win_x86_64\fm_viewer.obj" ^
  "build\win_x86_64\plugin_manifest.obj" ^
  "build\win_x86_64\plugin_api.obj" ^
  "build\win_x86_64\plugin_registry.obj" ^
  "build\win_x86_64\plugin_host_win_stub.obj" ^
  kernel32.lib user32.lib gdi32.lib ws2_32.lib || goto :fail

echo.
echo OK: aura_shell_win.exe
exit /b 0

:fail
echo BUILD FAILED
exit /b 1
