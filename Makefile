NASM = nasm
LD = ld
NASM_FLAGS = -f elf64 -g -F dwarf
LD_FLAGS = -nostdlib -e _start
PLATFORM ?= linux_x86_64
# Windows: default NASM at %LOCALAPPDATA%\bin\NASM\nasm.exe (e.g. scoop/local install). Override: NASM_WIN=nasm
ifeq ($(OS),Windows_NT)
ifneq ($(LOCALAPPDATA),)
NASM_WIN ?= $(subst \,/,$(LOCALAPPDATA))/bin/NASM/nasm.exe
endif
endif
NASM_WIN ?= nasm
NASM_WIN_FLAGS = -f win64 -g -F cv8

ifeq ($(PLATFORM),linux_arm64)
ARM_AS = aarch64-linux-gnu-as
ARM_LD = aarch64-linux-gnu-ld
ARM_AS_FLAGS =
ARM_LD_FLAGS = -nostdlib -e _start
ARM_QEMU = qemu-aarch64 -L /usr/aarch64-linux-gnu
else
ARM_AS = aarch64-linux-gnu-as
ARM_LD = aarch64-linux-gnu-ld
ARM_AS_FLAGS =
ARM_LD_FLAGS = -nostdlib -e _start
ARM_QEMU = qemu-aarch64 -L /usr/aarch64-linux-gnu
endif
WAYLAND_STRICT ?= 0

ifeq ($(WAYLAND_STRICT),1)
WAYLAND_STRICT_FLAG = -DSTRICT_WAYLAND=1
else
WAYLAND_STRICT_FLAG =
endif

BUILD_DIR = build
WIN_BUILD_DIR = $(BUILD_DIR)/win_x86_64
ARM_BUILD_DIR = $(BUILD_DIR)/linux_arm64
AURA_SHELL_BIN = aura-shell
AURA_WIDGET_DEMO_BIN = aura-widget-demo
TEST_SYSCALL_BIN = $(BUILD_DIR)/test_syscall
TEST_MEMORY_BIN = $(BUILD_DIR)/test_memory
TEST_THREADS_BIN = $(BUILD_DIR)/test_threads
TEST_EVENT_BIN = $(BUILD_DIR)/test_event
TEST_IPC_BIN = $(BUILD_DIR)/test_ipc
TEST_CANVAS_BIN = $(BUILD_DIR)/test_canvas
TEST_WINDOW_BIN = $(BUILD_DIR)/test_window
TEST_INPUT_BIN = $(BUILD_DIR)/test_input
TEST_LEXER_BIN = $(BUILD_DIR)/test_lexer
TEST_PARSER_BIN = $(BUILD_DIR)/test_parser
TEST_EXECUTOR_BIN = $(BUILD_DIR)/test_executor
TEST_PIPELINE_BIN = $(BUILD_DIR)/test_pipeline
TEST_BUILTINS_BIN = $(BUILD_DIR)/test_builtins
TEST_JOBS_BIN = $(BUILD_DIR)/test_jobs
TEST_TRUETYPE_BIN = $(BUILD_DIR)/test_truetype
TEST_PNG_BIN = $(BUILD_DIR)/test_png
TEST_RENDERING_BIN = $(BUILD_DIR)/test_rendering
TEST_PHYSICS_BIN = $(BUILD_DIR)/test_physics
TEST_WIDGETS_BIN = $(BUILD_DIR)/test_widgets
TEST_LAYOUT_BIN = $(BUILD_DIR)/test_layout
TEST_GESTURE_BIN = $(BUILD_DIR)/test_gesture
TEST_THEME_BIN = $(BUILD_DIR)/test_theme
TEST_COMPOSITOR_BIN = $(BUILD_DIR)/test_compositor_server
TEST_WM_BIN = $(BUILD_DIR)/test_wm
TEST_WORKSPACES_BIN = $(BUILD_DIR)/test_workspaces
TEST_DECORATIONS_BIN = $(BUILD_DIR)/test_decorations
TEST_VFS_BIN = $(BUILD_DIR)/test_vfs
TEST_PANEL_BIN = $(BUILD_DIR)/test_panel
TEST_VIEWER_BIN = $(BUILD_DIR)/test_viewer
TEST_ARCHIVE_BIN = $(BUILD_DIR)/test_archive
TEST_SSH_BIN = $(BUILD_DIR)/test_ssh
TEST_FM_INTEGRATION_BIN = $(BUILD_DIR)/test_fm_integration
TEST_PLUGIN_HOST_BIN = $(BUILD_DIR)/test_plugin_host
TEST_AURASCRIPT_PARSER_BIN = $(BUILD_DIR)/test_aurascript_parser
TEST_AURASCRIPT_CODEGEN_BIN = $(BUILD_DIR)/test_aurascript_codegen
TEST_MARKETPLACE_BIN = $(BUILD_DIR)/test_marketplace
TEST_MACROS_BIN = $(BUILD_DIR)/test_macros
TEST_WIN32_HAL_OBJ = $(WIN_BUILD_DIR)/test_win32_hal.obj
TEST_WIN32_WINDOW_OBJ = $(WIN_BUILD_DIR)/test_win32_window.obj
WIN_ABI_OBJ = $(WIN_BUILD_DIR)/abi.obj
TEST_WIN64_ABI_OBJ = $(WIN_BUILD_DIR)/test_win64_abi.obj
TEST_WIN64_ABI_BIN = $(WIN_BUILD_DIR)/test_win64_abi.exe
TEST_WIN64_HAL_CORE_OBJ = $(WIN_BUILD_DIR)/test_win64_hal_core.obj
TEST_WIN64_HAL_CORE_BIN = $(WIN_BUILD_DIR)/test_win64_hal_core.exe
TEST_WIN64_HAL_FILEIO_OBJ = $(WIN_BUILD_DIR)/test_win64_hal_fileio.obj
TEST_WIN64_HAL_FILEIO_BIN = $(WIN_BUILD_DIR)/test_win64_hal_fileio.exe
TEST_WIN64_HAL_PROCESS_OBJ = $(WIN_BUILD_DIR)/test_win64_hal_process.obj
TEST_WIN64_HAL_PROCESS_BIN = $(WIN_BUILD_DIR)/test_win64_hal_process.exe
TEST_WIN64_WINDOW_OBJ = $(WIN_BUILD_DIR)/test_win64_window.obj
TEST_WIN64_WINDOW_BIN = $(WIN_BUILD_DIR)/test_win64_window.exe
WIN_CORE_INPUT_OBJ = $(WIN_BUILD_DIR)/core_input.obj
WIN_CANVAS_RASTERIZER_OBJ = $(WIN_BUILD_DIR)/canvas_rasterizer.obj
WIN_CANVAS_SIMD_OBJ = $(WIN_BUILD_DIR)/canvas_simd.obj
NASM_WIN_PORTABLE_FLAGS = $(NASM_WIN_FLAGS) -DAURA_WIN64
# Windows PE tests: MSVC link.exe (run from "x64 Native Tools" or after vcvars64.bat), or MinGW.
ifeq ($(OS),Windows_NT)
WIN_PE_LINKER ?= msvc
else
WIN_PE_LINKER := ld
endif
WIN_LD ?= x86_64-w64-mingw32-ld
WIN_LD_FLAGS = -e _start --subsystem console
WIN_LINK = link
WIN_PE_LINK_FLAGS = /NOLOGO /MACHINE:X64 /SUBSYSTEM:CONSOLE /NODEFAULTLIB /ENTRY:_start
WIN_PE_LIBS = kernel32.lib
TEST_ARM64_HAL_BIN = $(ARM_BUILD_DIR)/test_arm64_hal
TEST_ARM64_CANVAS_BIN = $(ARM_BUILD_DIR)/test_arm64_canvas
TEST_ARM64_CODEGEN_BIN = $(ARM_BUILD_DIR)/test_arm64_codegen

HAL_SYSCALL_OBJ = $(BUILD_DIR)/hal_syscall.o
WIN_BOOTSTRAP_OBJ = $(WIN_BUILD_DIR)/bootstrap.obj
WIN_SYSCALL_OBJ = $(WIN_BUILD_DIR)/syscall.obj
WIN_FILEIO_OBJ = $(WIN_BUILD_DIR)/fileio.obj
WIN_MEMORY_OBJ = $(WIN_BUILD_DIR)/memory.obj
WIN_TIME_OBJ = $(WIN_BUILD_DIR)/time.obj
WIN_THREADS_OBJ = $(WIN_BUILD_DIR)/threads.obj
WIN_WINDOW_OBJ = $(WIN_BUILD_DIR)/window.obj
WIN_GDI_OBJ = $(WIN_BUILD_DIR)/gdi.obj
WIN_EXECUTOR_WIN_OBJ = $(WIN_BUILD_DIR)/executor_win.obj
WIN_PROCESS_OBJ = $(WIN_BUILD_DIR)/process.obj
ARM_HAL_SYSCALL_OBJ = $(ARM_BUILD_DIR)/hal_syscall.o
ARM_HAL_SYNC_OBJ = $(ARM_BUILD_DIR)/hal_sync.o
ARM_HAL_THREADS_OBJ = $(ARM_BUILD_DIR)/hal_threads.o
TEST_ARM64_HAL_OBJ = $(ARM_BUILD_DIR)/test_arm64_hal.o
ARM_CANVAS_SIMD_OBJ = $(ARM_BUILD_DIR)/canvas_simd_neon.o
ARM_AS_CODEGEN_OBJ = $(ARM_BUILD_DIR)/as_codegen_arm64.o
TEST_ARM64_CANVAS_OBJ = $(ARM_BUILD_DIR)/test_arm64_canvas.o
TEST_ARM64_CODEGEN_OBJ = $(ARM_BUILD_DIR)/test_arm64_codegen.o
HAL_ERRNO_OBJ = $(BUILD_DIR)/hal_errno.o
HAL_WAYLAND_OBJ = $(BUILD_DIR)/hal_wayland.o
HAL_WAYLAND_INPUT_OBJ = $(BUILD_DIR)/hal_wayland_input.o
HAL_PROCESS_OBJ = $(BUILD_DIR)/hal_process.o
HAL_SIGNALS_OBJ = $(BUILD_DIR)/hal_signals.o
HAL_FS_OBJ = $(BUILD_DIR)/hal_fs.o
CORE_MEMORY_OBJ = $(BUILD_DIR)/core_memory.o
CORE_SYNC_OBJ = $(BUILD_DIR)/core_sync.o
CORE_THREADS_OBJ = $(BUILD_DIR)/core_threads.o
CORE_EVENT_OBJ = $(BUILD_DIR)/core_event.o
CORE_GESTURE_OBJ = $(BUILD_DIR)/core_gesture.o
CORE_IPC_OBJ = $(BUILD_DIR)/core_ipc.o
CORE_INPUT_OBJ = $(BUILD_DIR)/core_input.o
GUI_WINDOW_OBJ = $(BUILD_DIR)/gui_window.o
GUI_WIDGET_OBJ = $(BUILD_DIR)/gui_widget.o
GUI_LAYOUT_OBJ = $(BUILD_DIR)/gui_layout.o
GUI_THEME_OBJ = $(BUILD_DIR)/gui_theme.o
GUI_TERMINAL_OBJ = $(BUILD_DIR)/gui_terminal.o
WIDGET_LABEL_OBJ = $(BUILD_DIR)/widget_label.o
WIDGET_BUTTON_OBJ = $(BUILD_DIR)/widget_button.o
WIDGET_TEXT_INPUT_OBJ = $(BUILD_DIR)/widget_text_input.o
WIDGET_TEXT_AREA_OBJ = $(BUILD_DIR)/widget_text_area.o
WIDGET_LIST_OBJ = $(BUILD_DIR)/widget_list.o
WIDGET_TABLE_OBJ = $(BUILD_DIR)/widget_table.o
WIDGET_TREE_OBJ = $(BUILD_DIR)/widget_tree.o
WIDGET_SCROLLBAR_OBJ = $(BUILD_DIR)/widget_scrollbar.o
WIDGET_RADIAL_OBJ = $(BUILD_DIR)/widget_radial_menu.o
WIDGET_BOTTOM_SHEET_OBJ = $(BUILD_DIR)/widget_bottom_sheet.o
WIDGET_TAB_BAR_OBJ = $(BUILD_DIR)/widget_tab_bar.o
WIDGET_PROGRESS_OBJ = $(BUILD_DIR)/widget_progress_bar.o
WIDGET_DIALOG_OBJ = $(BUILD_DIR)/widget_dialog.o
WIDGET_STATUS_OBJ = $(BUILD_DIR)/widget_status_bar.o
WIDGET_SPLIT_OBJ = $(BUILD_DIR)/widget_split_pane.o
WIDGET_CONTAINER_OBJ = $(BUILD_DIR)/widget_container.o
WIDGET_FILE_PANEL_OBJ = $(BUILD_DIR)/widget_file_panel.o
WIDGET_OBJS = $(WIDGET_LABEL_OBJ) $(WIDGET_BUTTON_OBJ) $(WIDGET_TEXT_INPUT_OBJ) $(WIDGET_TEXT_AREA_OBJ) $(WIDGET_LIST_OBJ) $(WIDGET_TABLE_OBJ) $(WIDGET_TREE_OBJ) $(WIDGET_SCROLLBAR_OBJ) $(WIDGET_RADIAL_OBJ) $(WIDGET_BOTTOM_SHEET_OBJ) $(WIDGET_TAB_BAR_OBJ) $(WIDGET_PROGRESS_OBJ) $(WIDGET_DIALOG_OBJ) $(WIDGET_STATUS_OBJ) $(WIDGET_SPLIT_OBJ) $(WIDGET_CONTAINER_OBJ)
SHELL_REPL_OBJ = $(BUILD_DIR)/shell_repl.o
SHELL_LEXER_OBJ = $(BUILD_DIR)/shell_lexer.o
SHELL_PARSER_OBJ = $(BUILD_DIR)/shell_parser.o
SHELL_EXECUTOR_OBJ = $(BUILD_DIR)/shell_executor.o
SHELL_PIPELINE_OBJ = $(BUILD_DIR)/shell_pipeline.o
SHELL_VARIABLES_OBJ = $(BUILD_DIR)/shell_variables.o
SHELL_ALIAS_OBJ = $(BUILD_DIR)/shell_alias.o
SHELL_HISTORY_OBJ = $(BUILD_DIR)/shell_history.o
SHELL_BUILTINS_OBJ = $(BUILD_DIR)/shell_builtins.o
SHELL_JOBS_OBJ = $(BUILD_DIR)/shell_jobs.o
SHELL_MACROS_OBJ = $(BUILD_DIR)/shell_macros.o
MAIN_OBJ = $(BUILD_DIR)/main.o
DEMO_WIDGETS_OBJ = $(BUILD_DIR)/demo_widgets.o
CANVAS_RASTERIZER_OBJ = $(BUILD_DIR)/canvas_rasterizer.o
CANVAS_TEXT_OBJ = $(BUILD_DIR)/canvas_text.o
CANVAS_SIMD_OBJ = $(BUILD_DIR)/canvas_simd.o
CANVAS_TRUETYPE_OBJ = $(BUILD_DIR)/canvas_truetype.o
CANVAS_PNG_OBJ = $(BUILD_DIR)/canvas_png.o
CANVAS_GRADIENT_OBJ = $(BUILD_DIR)/canvas_gradient.o
CANVAS_ROUNDED_OBJ = $(BUILD_DIR)/canvas_rounded.o
CANVAS_BLUR_OBJ = $(BUILD_DIR)/canvas_blur.o
CANVAS_COMPOSITE_OBJ = $(BUILD_DIR)/canvas_composite.o
CANVAS_LINE_OBJ = $(BUILD_DIR)/canvas_line.o
CANVAS_CLIP_OBJ = $(BUILD_DIR)/canvas_clip.o
CANVAS_PHYSICS_OBJ = $(BUILD_DIR)/canvas_physics.o
TEST_SYSCALL_OBJ = $(BUILD_DIR)/test_syscall.o
TEST_MEMORY_OBJ = $(BUILD_DIR)/test_memory.o
TEST_THREADS_OBJ = $(BUILD_DIR)/test_threads.o
TEST_EVENT_OBJ = $(BUILD_DIR)/test_event.o
TEST_IPC_OBJ = $(BUILD_DIR)/test_ipc.o
TEST_CANVAS_OBJ = $(BUILD_DIR)/test_canvas.o
TEST_WINDOW_OBJ = $(BUILD_DIR)/test_window.o
TEST_INPUT_OBJ = $(BUILD_DIR)/test_input.o
TEST_LEXER_OBJ = $(BUILD_DIR)/test_lexer.o
TEST_PARSER_OBJ = $(BUILD_DIR)/test_parser.o
TEST_EXECUTOR_OBJ = $(BUILD_DIR)/test_executor.o
TEST_PIPELINE_OBJ = $(BUILD_DIR)/test_pipeline.o
TEST_BUILTINS_OBJ = $(BUILD_DIR)/test_builtins.o
TEST_JOBS_OBJ = $(BUILD_DIR)/test_jobs.o
TEST_TRUETYPE_OBJ = $(BUILD_DIR)/test_truetype.o
TEST_PNG_OBJ = $(BUILD_DIR)/test_png.o
TEST_RENDERING_OBJ = $(BUILD_DIR)/test_rendering.o
TEST_PHYSICS_OBJ = $(BUILD_DIR)/test_physics.o
TEST_WIDGETS_OBJ = $(BUILD_DIR)/test_widgets.o
TEST_LAYOUT_OBJ = $(BUILD_DIR)/test_layout.o
TEST_GESTURE_OBJ = $(BUILD_DIR)/test_gesture.o
TEST_THEME_OBJ = $(BUILD_DIR)/test_theme.o
TEST_COMPOSITOR_OBJ = $(BUILD_DIR)/test_compositor_server.o
TEST_WM_OBJ = $(BUILD_DIR)/test_wm.o
TEST_WORKSPACES_OBJ = $(BUILD_DIR)/test_workspaces.o
TEST_DECORATIONS_OBJ = $(BUILD_DIR)/test_decorations.o
TEST_VFS_OBJ = $(BUILD_DIR)/test_vfs.o
TEST_PANEL_OBJ = $(BUILD_DIR)/test_panel.o
COMPOSITOR_SERVER_OBJ = $(BUILD_DIR)/compositor_server.o
COMPOSITOR_PROTOCOL_OBJ = $(BUILD_DIR)/compositor_protocol.o
COMPOSITOR_REGISTRY_OBJ = $(BUILD_DIR)/compositor_registry.o
COMPOSITOR_SURFACE_OBJ = $(BUILD_DIR)/compositor_surface.o
COMPOSITOR_SHM_OBJ = $(BUILD_DIR)/compositor_shm.o
COMPOSITOR_XDG_OBJ = $(BUILD_DIR)/compositor_xdg.o
COMPOSITOR_RENDER_OBJ = $(BUILD_DIR)/compositor_render.o
COMPOSITOR_SEAT_OBJ = $(BUILD_DIR)/compositor_seat.o
COMPOSITOR_KEYBOARD_OBJ = $(BUILD_DIR)/compositor_keyboard.o
COMPOSITOR_POINTER_OBJ = $(BUILD_DIR)/compositor_pointer.o
COMPOSITOR_TOUCH_SERVER_OBJ = $(BUILD_DIR)/compositor_touch_server.o
COMPOSITOR_WM_OBJ = $(BUILD_DIR)/compositor_wm.o
COMPOSITOR_TILING_OBJ = $(BUILD_DIR)/compositor_tiling.o
COMPOSITOR_FLOATING_OBJ = $(BUILD_DIR)/compositor_floating.o
COMPOSITOR_WORKSPACES_OBJ = $(BUILD_DIR)/compositor_workspaces.o
COMPOSITOR_HUB_OBJ = $(BUILD_DIR)/compositor_hub.o
COMPOSITOR_OVERVIEW_OBJ = $(BUILD_DIR)/compositor_overview.o
COMPOSITOR_TRANSITIONS_OBJ = $(BUILD_DIR)/compositor_transitions.o
COMPOSITOR_DECORATIONS_OBJ = $(BUILD_DIR)/compositor_decorations.o
COMPOSITOR_CURSOR_OBJ = $(BUILD_DIR)/compositor_cursor.o
COMPOSITOR_OUTPUT_OBJ = $(BUILD_DIR)/compositor_output.o
HAL_LIBINPUT_OBJ = $(BUILD_DIR)/hal_libinput.o
HAL_DRM_OBJ = $(BUILD_DIR)/hal_drm.o
COMPOSITOR_WM_OBJS = $(COMPOSITOR_WM_OBJ) $(COMPOSITOR_TILING_OBJ) $(COMPOSITOR_FLOATING_OBJ)
COMPOSITOR_SPACES_OBJS = $(COMPOSITOR_WORKSPACES_OBJ) $(COMPOSITOR_HUB_OBJ) $(COMPOSITOR_OVERVIEW_OBJ) $(COMPOSITOR_TRANSITIONS_OBJ)
COMPOSITOR_RENDER_AUX_OBJS = $(COMPOSITOR_DECORATIONS_OBJ)
COMPOSITOR_INPUT_OBJS = $(COMPOSITOR_SEAT_OBJ) $(COMPOSITOR_KEYBOARD_OBJ) $(COMPOSITOR_POINTER_OBJ) $(COMPOSITOR_TOUCH_SERVER_OBJ) $(COMPOSITOR_CURSOR_OBJ) $(COMPOSITOR_OUTPUT_OBJ) $(COMPOSITOR_WM_OBJS)
FM_VFS_OBJ = $(BUILD_DIR)/fm_vfs.o
FM_VFS_LOCAL_OBJ = $(BUILD_DIR)/fm_vfs_local.o
FM_OPERATIONS_OBJ = $(BUILD_DIR)/fm_operations.o
FM_SEARCH_OBJ = $(BUILD_DIR)/fm_search.o
FM_PANEL_OBJ = $(BUILD_DIR)/fm_panel.o
FM_MAIN_OBJ = $(BUILD_DIR)/fm_main.o
FM_STATUS_BAR_OBJ = $(BUILD_DIR)/fm_status_bar.o
FM_VIEWER_OBJ = $(BUILD_DIR)/fm_viewer.o
FM_ARCHIVE_OBJ = $(BUILD_DIR)/fm_archive.o
FM_VFS_ARCHIVE_OBJ = $(BUILD_DIR)/fm_vfs_archive.o
FM_SSH_OBJ = $(BUILD_DIR)/fm_ssh.o
FM_SFTP_OBJ = $(BUILD_DIR)/fm_sftp.o
FM_VFS_SFTP_OBJ = $(BUILD_DIR)/fm_vfs_sftp.o
FM_CORE_OBJS = $(FM_VFS_OBJ) $(FM_VFS_LOCAL_OBJ) $(FM_OPERATIONS_OBJ) $(FM_SEARCH_OBJ) $(FM_PANEL_OBJ) $(FM_ARCHIVE_OBJ) $(FM_VFS_ARCHIVE_OBJ) $(FM_SSH_OBJ) $(FM_SFTP_OBJ) $(FM_VFS_SFTP_OBJ)
FM_UI_OBJS = $(FM_MAIN_OBJ) $(FM_STATUS_BAR_OBJ)
FM_OBJS = $(FM_CORE_OBJS)
PLUGIN_HOST_OBJ = $(BUILD_DIR)/plugin_host.o
PLUGIN_MANIFEST_OBJ = $(BUILD_DIR)/plugin_manifest.o
PLUGIN_API_OBJ = $(BUILD_DIR)/plugin_api.o
PLUGIN_REGISTRY_OBJ = $(BUILD_DIR)/plugin_registry.o
PLUGIN_OBJS = $(PLUGIN_HOST_OBJ) $(PLUGIN_MANIFEST_OBJ) $(PLUGIN_API_OBJ) $(PLUGIN_REGISTRY_OBJ)
TEST_PLUGIN_API_OBJ = $(BUILD_DIR)/test_plugin_api.o
TEST_PLUGIN_API_BIN = $(BUILD_DIR)/test_plugin_api
AS_LEXER_OBJ = $(BUILD_DIR)/as_lexer.o
AS_PARSER_OBJ = $(BUILD_DIR)/as_parser.o
AS_CODEGEN_OBJ = $(BUILD_DIR)/as_codegen_x86_64.o
AS_RUNTIME_OBJ = $(BUILD_DIR)/as_runtime.o
AS_CACHE_OBJ = $(BUILD_DIR)/as_cache.o
AS_OBJS = $(AS_LEXER_OBJ) $(AS_PARSER_OBJ) $(AS_CODEGEN_OBJ) $(AS_RUNTIME_OBJ) $(AS_CACHE_OBJ)
TEST_AURASCRIPT_PARSER_OBJ = $(BUILD_DIR)/test_aurascript_parser.o
TEST_AURASCRIPT_CODEGEN_OBJ = $(BUILD_DIR)/test_aurascript_codegen.o
TEST_MARKETPLACE_OBJ = $(BUILD_DIR)/test_marketplace.o
TEST_MACROS_OBJ = $(BUILD_DIR)/test_macros.o
TEST_PLUGIN_CMD_OBJ = $(BUILD_DIR)/test_plugin_cmd.o
TEST_PLUGIN_CMD_SO = $(BUILD_DIR)/test_plugin_cmd.so
TEST_VIEWER_OBJ = $(BUILD_DIR)/test_viewer.o
TEST_ARCHIVE_OBJ = $(BUILD_DIR)/test_archive.o
TEST_SSH_OBJ = $(BUILD_DIR)/test_ssh.o
TEST_FM_INTEGRATION_OBJ = $(BUILD_DIR)/test_fm_integration.o
TEST_PLUGIN_HOST_OBJ = $(BUILD_DIR)/test_plugin_host.o
TEST_PLUGIN_OBJ = $(BUILD_DIR)/test_plugin.o
TEST_PLUGIN_SO = $(BUILD_DIR)/test_plugin.so
TEST_PLUGIN_BAD_OBJ = $(BUILD_DIR)/test_plugin_bad.o
TEST_PLUGIN_BAD_SO = $(BUILD_DIR)/test_plugin_bad.so
TEST_PLUGIN_CRASH_OBJ = $(BUILD_DIR)/test_plugin_crash.o
TEST_PLUGIN_CRASH_SO = $(BUILD_DIR)/test_plugin_crash.so
TEST_SURFACES_OBJ = $(BUILD_DIR)/test_surfaces.o
TEST_SURFACES_BIN = $(BUILD_DIR)/test_surfaces
TEST_INPUT_ROUTING_OBJ = $(BUILD_DIR)/test_input_routing.o
TEST_INPUT_ROUTING_BIN = $(BUILD_DIR)/test_input_routing
WIDGET_TERMINAL_STUBS_OBJ = $(BUILD_DIR)/widget_terminal_stubs.o

.PHONY: all test run demo clean test_nested_smoke test_nested_smoke_ci win_hal_check win_step60a_check test_win64_abi win_step60b_check test_win64_hal_core win_step60c_check test_win64_hal_fileio win_step60d_check test_win64_hal_process win_step61_check win_step61a_check test_win64_window arm64_hal_check arm64_step63_check test_arm64_hal test_arm64_canvas test_arm64_codegen aura_shell_win

# Windows native shell (MSVC + NASM): produces aura_shell_win.exe in repo root
ifeq ($(OS),Windows_NT)
aura_shell_win:
	cmd /c tools\build_aura_shell_win.cmd
endif

# Final binary
all: $(AURA_SHELL_BIN)

# Build and run unit tests
test: test_syscall test_memory test_threads test_event test_ipc test_canvas test_lexer test_parser test_executor test_pipeline test_builtins test_jobs test_truetype test_png test_rendering test_physics test_widgets test_layout test_gesture test_theme test_compositor_server test_surfaces test_input_routing test_wm test_workspaces test_decorations test_vfs test_panel test_viewer test_archive test_ssh test_fm_integration test_plugin_host test_plugin_api test_aurascript_parser test_aurascript_codegen test_marketplace test_macros

run: $(AURA_SHELL_BIN)
	./$(AURA_SHELL_BIN)

demo: $(AURA_WIDGET_DEMO_BIN)
	./$(AURA_WIDGET_DEMO_BIN)

test_syscall: $(TEST_SYSCALL_BIN)
	./$(TEST_SYSCALL_BIN)

test_memory: $(TEST_MEMORY_BIN)
	./$(TEST_MEMORY_BIN)

test_threads: $(TEST_THREADS_BIN)
	./$(TEST_THREADS_BIN)

test_event: $(TEST_EVENT_BIN)
	./$(TEST_EVENT_BIN)

test_ipc: $(TEST_IPC_BIN)
	./$(TEST_IPC_BIN)

test_canvas: $(TEST_CANVAS_BIN)
	./$(TEST_CANVAS_BIN)

test_window: $(TEST_WINDOW_BIN)
	./$(TEST_WINDOW_BIN)

test_input: $(TEST_INPUT_BIN)
	./$(TEST_INPUT_BIN)

test_lexer: $(TEST_LEXER_BIN)
	./$(TEST_LEXER_BIN)

test_parser: $(TEST_PARSER_BIN)
	./$(TEST_PARSER_BIN)

test_executor: $(TEST_EXECUTOR_BIN)
	./$(TEST_EXECUTOR_BIN)

test_pipeline: $(TEST_PIPELINE_BIN)
	./$(TEST_PIPELINE_BIN)

test_builtins: $(TEST_BUILTINS_BIN)
	./$(TEST_BUILTINS_BIN)

test_jobs: $(TEST_JOBS_BIN)
	./$(TEST_JOBS_BIN)

test_truetype: $(TEST_TRUETYPE_BIN)
	./$(TEST_TRUETYPE_BIN)

test_png: $(TEST_PNG_BIN)
	./$(TEST_PNG_BIN)

test_rendering: $(TEST_RENDERING_BIN)
	./$(TEST_RENDERING_BIN)

test_physics: $(TEST_PHYSICS_BIN)
	./$(TEST_PHYSICS_BIN)

test_widgets: $(TEST_WIDGETS_BIN)
	./$(TEST_WIDGETS_BIN)

test_layout: $(TEST_LAYOUT_BIN)
	./$(TEST_LAYOUT_BIN)

test_gesture: $(TEST_GESTURE_BIN)
	./$(TEST_GESTURE_BIN)

test_theme: $(TEST_THEME_BIN)
	./$(TEST_THEME_BIN)

test_compositor_server: $(TEST_COMPOSITOR_BIN)
	./$(TEST_COMPOSITOR_BIN)

test_surfaces: $(TEST_SURFACES_BIN)
	./$(TEST_SURFACES_BIN)

test_input_routing: $(TEST_INPUT_ROUTING_BIN)
	./$(TEST_INPUT_ROUTING_BIN)

test_wm: $(TEST_WM_BIN)
	./$(TEST_WM_BIN)

test_workspaces: $(TEST_WORKSPACES_BIN)
	./$(TEST_WORKSPACES_BIN)

test_decorations: $(TEST_DECORATIONS_BIN)
	./$(TEST_DECORATIONS_BIN)

test_vfs: $(TEST_VFS_BIN)
	./$(TEST_VFS_BIN)

test_panel: $(TEST_PANEL_BIN)
	./$(TEST_PANEL_BIN)

test_viewer: $(TEST_VIEWER_BIN)
	./$(TEST_VIEWER_BIN)

test_archive: $(TEST_ARCHIVE_BIN)
	./$(TEST_ARCHIVE_BIN)

test_ssh: $(TEST_SSH_BIN)
	./$(TEST_SSH_BIN)

test_fm_integration: $(TEST_FM_INTEGRATION_BIN)
	./$(TEST_FM_INTEGRATION_BIN)

test_plugin_host: $(TEST_PLUGIN_HOST_BIN)
	./$(TEST_PLUGIN_HOST_BIN)

test_plugin_api: $(TEST_PLUGIN_API_BIN)
	./$(TEST_PLUGIN_API_BIN)

test_aurascript_parser: $(TEST_AURASCRIPT_PARSER_BIN)
	./$(TEST_AURASCRIPT_PARSER_BIN)

test_aurascript_codegen: $(TEST_AURASCRIPT_CODEGEN_BIN)
	./$(TEST_AURASCRIPT_CODEGEN_BIN)

test_marketplace: $(TEST_MARKETPLACE_BIN)
	./$(TEST_MARKETPLACE_BIN)

test_macros: $(TEST_MACROS_BIN)
	./$(TEST_MACROS_BIN)

test_nested_smoke: $(AURA_SHELL_BIN)
	bash tools/test_nested_smoke.sh

test_nested_smoke_ci: $(AURA_SHELL_BIN)
	bash tools/test_nested_smoke.sh --ci

test_window_strict:
	$(MAKE) WAYLAND_STRICT=1 test_window -B

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(WIN_BUILD_DIR):
	mkdir -p $(WIN_BUILD_DIR)

$(ARM_BUILD_DIR):
	mkdir -p $(ARM_BUILD_DIR)

win_hal_check: $(WIN_BOOTSTRAP_OBJ) $(WIN_SYSCALL_OBJ) $(WIN_FILEIO_OBJ) $(WIN_PROCESS_OBJ) $(WIN_ABI_OBJ) $(WIN_MEMORY_OBJ) $(WIN_TIME_OBJ) $(WIN_THREADS_OBJ) $(TEST_WIN32_HAL_OBJ)
	@echo "win_x86_64 HAL objects assembled successfully."

win_step60a_check: $(TEST_WIN64_ABI_BIN)
	@echo "STEP 60A: $(TEST_WIN64_ABI_BIN) linked. Run on Windows to verify output."

test_win64_abi: $(TEST_WIN64_ABI_BIN)
	@echo "Run on Windows (or Wine): $(TEST_WIN64_ABI_BIN)"

win_step60b_check: $(TEST_WIN64_HAL_CORE_BIN)
	@echo "STEP 60B: $(TEST_WIN64_HAL_CORE_BIN) linked. Run on Windows to verify output."

test_win64_hal_core: $(TEST_WIN64_HAL_CORE_BIN)
	@echo "Run on Windows (or Wine): $(TEST_WIN64_HAL_CORE_BIN)"

win_step60c_check: $(TEST_WIN64_HAL_FILEIO_BIN)
	@echo "STEP 60C: $(TEST_WIN64_HAL_FILEIO_BIN) linked. Run on Windows to verify output."

test_win64_hal_fileio: $(TEST_WIN64_HAL_FILEIO_BIN)
	@echo "Run on Windows (or Wine): $(TEST_WIN64_HAL_FILEIO_BIN)"

win_step60d_check: $(TEST_WIN64_HAL_PROCESS_BIN)
	@echo "STEP 60D: $(TEST_WIN64_HAL_PROCESS_BIN) linked. Run on Windows to verify output."

test_win64_hal_process: $(TEST_WIN64_HAL_PROCESS_BIN)
	@echo "Run on Windows (or Wine): $(TEST_WIN64_HAL_PROCESS_BIN)"

win_step61_check: $(WIN_BOOTSTRAP_OBJ) $(WIN_SYSCALL_OBJ) $(WIN_FILEIO_OBJ) $(WIN_PROCESS_OBJ) $(WIN_MEMORY_OBJ) $(WIN_TIME_OBJ) $(WIN_THREADS_OBJ) $(WIN_ABI_OBJ) $(WIN_WINDOW_OBJ) $(WIN_GDI_OBJ) $(WIN_EXECUTOR_WIN_OBJ) $(TEST_WIN32_HAL_OBJ) $(TEST_WIN32_WINDOW_OBJ)
	@echo "win_x86_64 STEP61 objects assembled successfully."

win_step61a_check: $(TEST_WIN64_WINDOW_BIN)
	@echo "STEP 61A: $(TEST_WIN64_WINDOW_BIN) linked. Run on Windows to verify red window."

test_win64_window: $(TEST_WIN64_WINDOW_BIN)
	@echo "Run on Windows (or Wine): $(TEST_WIN64_WINDOW_BIN)"

arm64_hal_check: $(ARM_HAL_SYSCALL_OBJ) $(ARM_HAL_SYNC_OBJ) $(ARM_HAL_THREADS_OBJ) $(TEST_ARM64_HAL_OBJ) $(TEST_ARM64_HAL_BIN)
	@echo "linux_arm64 HAL objects assembled successfully."

arm64_step63_check: arm64_hal_check $(ARM_CANVAS_SIMD_OBJ) $(ARM_AS_CODEGEN_OBJ) $(TEST_ARM64_CANVAS_OBJ) $(TEST_ARM64_CODEGEN_OBJ) $(TEST_ARM64_CANVAS_BIN) $(TEST_ARM64_CODEGEN_BIN)
	@echo "linux_arm64 STEP63 objects assembled successfully."

test_arm64_hal: arm64_hal_check
	$(ARM_QEMU) $(TEST_ARM64_HAL_BIN)

test_arm64_canvas: arm64_step63_check
	$(ARM_QEMU) $(TEST_ARM64_CANVAS_BIN)

test_arm64_codegen: arm64_step63_check
	$(ARM_QEMU) $(TEST_ARM64_CODEGEN_BIN)

$(HAL_SYSCALL_OBJ): src/hal/linux_x86_64/syscall.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(HAL_ERRNO_OBJ): src/hal/linux_x86_64/errno.asm | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(HAL_WAYLAND_OBJ): src/hal/linux_x86_64/wayland.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(HAL_WAYLAND_INPUT_OBJ): src/hal/linux_x86_64/wayland_input.asm | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(HAL_PROCESS_OBJ): src/hal/linux_x86_64/process.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(HAL_SIGNALS_OBJ): src/hal/linux_x86_64/signals.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(HAL_FS_OBJ): src/hal/linux_x86_64/fs.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(CORE_MEMORY_OBJ): src/core/memory.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(CORE_SYNC_OBJ): src/core/sync.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(CORE_THREADS_OBJ): src/core/threads.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(CORE_EVENT_OBJ): src/core/event.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(CORE_IPC_OBJ): src/core/ipc.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(CORE_INPUT_OBJ): src/core/input.asm | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(GUI_WINDOW_OBJ): src/gui/window.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $(WAYLAND_STRICT_FLAG) $< -o $@

$(GUI_WIDGET_OBJ): src/gui/widget.asm src/hal/platform_defs.inc src/gui/widget.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(GUI_LAYOUT_OBJ): src/gui/layout.asm src/hal/platform_defs.inc src/gui/widget.inc src/gui/layout.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(GUI_THEME_OBJ): src/gui/theme.asm src/hal/platform_defs.inc src/gui/theme.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(GUI_TERMINAL_OBJ): src/gui/terminal.asm src/hal/platform_defs.inc src/gui/widget.inc src/gui/theme.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(CORE_GESTURE_OBJ): src/core/gesture.asm src/hal/platform_defs.inc src/core/gesture.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(WIDGET_LABEL_OBJ): src/gui/widgets/label.asm src/hal/platform_defs.inc src/gui/widget.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(WIDGET_BUTTON_OBJ): src/gui/widgets/button.asm src/hal/platform_defs.inc src/gui/widget.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(WIDGET_TEXT_INPUT_OBJ): src/gui/widgets/text_input.asm src/hal/platform_defs.inc src/gui/widget.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(WIDGET_TEXT_AREA_OBJ): src/gui/widgets/text_area.asm src/hal/platform_defs.inc src/gui/widget.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(WIDGET_LIST_OBJ): src/gui/widgets/list.asm src/hal/platform_defs.inc src/gui/widget.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(WIDGET_TABLE_OBJ): src/gui/widgets/table.asm src/hal/platform_defs.inc src/gui/widget.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(WIDGET_TREE_OBJ): src/gui/widgets/tree.asm src/hal/platform_defs.inc src/gui/widget.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(WIDGET_SCROLLBAR_OBJ): src/gui/widgets/scrollbar.asm src/hal/platform_defs.inc src/gui/widget.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(WIDGET_RADIAL_OBJ): src/gui/widgets/radial_menu.asm src/hal/platform_defs.inc src/gui/widget.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(WIDGET_BOTTOM_SHEET_OBJ): src/gui/widgets/bottom_sheet.asm src/hal/platform_defs.inc src/gui/widget.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(WIDGET_TAB_BAR_OBJ): src/gui/widgets/tab_bar.asm src/hal/platform_defs.inc src/gui/widget.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(WIDGET_PROGRESS_OBJ): src/gui/widgets/progress_bar.asm src/hal/platform_defs.inc src/gui/widget.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(WIDGET_DIALOG_OBJ): src/gui/widgets/dialog.asm src/hal/platform_defs.inc src/gui/widget.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(WIDGET_STATUS_OBJ): src/gui/widgets/status_bar.asm src/hal/platform_defs.inc src/gui/widget.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(WIDGET_SPLIT_OBJ): src/gui/widgets/split_pane.asm src/hal/platform_defs.inc src/gui/widget.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(WIDGET_CONTAINER_OBJ): src/gui/widgets/container.asm src/hal/platform_defs.inc src/gui/widget.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(WIDGET_FILE_PANEL_OBJ): src/gui/widgets/file_panel.asm src/hal/platform_defs.inc src/gui/widget.inc src/fm/panel.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(SHELL_REPL_OBJ): src/shell/repl.asm | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(SHELL_LEXER_OBJ): src/shell/lexer.asm | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(SHELL_PARSER_OBJ): src/shell/parser.asm | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(SHELL_EXECUTOR_OBJ): src/shell/executor.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(SHELL_PIPELINE_OBJ): src/shell/pipeline.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(SHELL_VARIABLES_OBJ): src/shell/variables.asm | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(SHELL_ALIAS_OBJ): src/shell/alias.asm | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(SHELL_HISTORY_OBJ): src/shell/history.asm | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(SHELL_BUILTINS_OBJ): src/shell/builtins.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(SHELL_JOBS_OBJ): src/shell/jobs.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(SHELL_MACROS_OBJ): src/shell/macros.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(MAIN_OBJ): src/main.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(DEMO_WIDGETS_OBJ): tests/demo_widgets.asm src/hal/platform_defs.inc src/gui/widget.inc src/gui/theme.inc src/core/gesture.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(CANVAS_RASTERIZER_OBJ): src/canvas/rasterizer.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(CANVAS_TEXT_OBJ): src/canvas/text.asm | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(CANVAS_SIMD_OBJ): src/canvas/simd.asm | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(CANVAS_TRUETYPE_OBJ): src/canvas/truetype.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(CANVAS_PNG_OBJ): src/canvas/png.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(CANVAS_GRADIENT_OBJ): src/canvas/gradient.asm | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(CANVAS_ROUNDED_OBJ): src/canvas/rounded.asm | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(CANVAS_BLUR_OBJ): src/canvas/blur.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(CANVAS_COMPOSITE_OBJ): src/canvas/composite.asm | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(CANVAS_LINE_OBJ): src/canvas/line.asm | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(CANVAS_CLIP_OBJ): src/canvas/clip.asm | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(CANVAS_PHYSICS_OBJ): src/canvas/physics.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_SYSCALL_OBJ): tests/unit/test_syscall.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_MEMORY_OBJ): tests/unit/test_memory.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_THREADS_OBJ): tests/unit/test_threads.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_EVENT_OBJ): tests/unit/test_event.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_IPC_OBJ): tests/unit/test_ipc.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_CANVAS_OBJ): tests/unit/test_canvas.asm | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_WINDOW_OBJ): tests/unit/test_window.asm | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_INPUT_OBJ): tests/unit/test_input.asm | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_LEXER_OBJ): tests/unit/test_lexer.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_PARSER_OBJ): tests/unit/test_parser.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_EXECUTOR_OBJ): tests/unit/test_executor.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_PIPELINE_OBJ): tests/unit/test_pipeline.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_BUILTINS_OBJ): tests/unit/test_builtins.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_JOBS_OBJ): tests/unit/test_jobs.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_TRUETYPE_OBJ): tests/unit/test_truetype.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_PNG_OBJ): tests/unit/test_png.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_RENDERING_OBJ): tests/unit/test_rendering.asm | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_PHYSICS_OBJ): tests/unit/test_physics.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_WIDGETS_OBJ): tests/unit/test_widgets.asm src/hal/platform_defs.inc src/gui/widget.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_LAYOUT_OBJ): tests/unit/test_layout.asm src/hal/platform_defs.inc src/gui/widget.inc src/gui/layout.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_GESTURE_OBJ): tests/unit/test_gesture.asm src/hal/platform_defs.inc src/core/gesture.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_THEME_OBJ): tests/unit/test_theme.asm src/hal/platform_defs.inc src/gui/theme.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(COMPOSITOR_SERVER_OBJ): src/compositor/server.asm src/hal/platform_defs.inc src/compositor/compositor.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(COMPOSITOR_PROTOCOL_OBJ): src/compositor/protocol.asm src/hal/platform_defs.inc src/compositor/compositor.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(COMPOSITOR_REGISTRY_OBJ): src/compositor/registry.asm src/hal/platform_defs.inc src/compositor/compositor.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(COMPOSITOR_SURFACE_OBJ): src/compositor/surface.asm src/hal/platform_defs.inc src/compositor/compositor.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(COMPOSITOR_SHM_OBJ): src/compositor/shm.asm src/hal/platform_defs.inc src/compositor/compositor.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(COMPOSITOR_XDG_OBJ): src/compositor/xdg.asm src/hal/platform_defs.inc src/compositor/compositor.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(COMPOSITOR_RENDER_OBJ): src/compositor/compositor_render.asm src/hal/platform_defs.inc src/compositor/compositor.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(COMPOSITOR_SEAT_OBJ): src/compositor/seat.asm src/hal/platform_defs.inc src/compositor/compositor.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(COMPOSITOR_KEYBOARD_OBJ): src/compositor/keyboard.asm src/hal/platform_defs.inc src/compositor/compositor.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(COMPOSITOR_POINTER_OBJ): src/compositor/pointer.asm src/hal/platform_defs.inc src/compositor/compositor.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(COMPOSITOR_TOUCH_SERVER_OBJ): src/compositor/touch_server.asm src/hal/platform_defs.inc src/compositor/compositor.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(COMPOSITOR_WM_OBJ): src/compositor/wm.asm src/compositor/wm.inc src/compositor/compositor.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(COMPOSITOR_TILING_OBJ): src/compositor/tiling.asm src/compositor/wm.inc src/compositor/compositor.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(COMPOSITOR_FLOATING_OBJ): src/compositor/floating.asm src/compositor/wm.inc src/compositor/compositor.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(COMPOSITOR_WORKSPACES_OBJ): src/compositor/workspaces.asm src/compositor/workspaces.inc src/compositor/compositor.inc src/canvas/canvas.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(COMPOSITOR_HUB_OBJ): src/compositor/hub.asm src/compositor/workspaces.inc src/gui/theme.inc src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(COMPOSITOR_OVERVIEW_OBJ): src/compositor/overview.asm src/compositor/workspaces.inc src/compositor/compositor.inc src/compositor/wm.inc src/canvas/canvas.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(COMPOSITOR_TRANSITIONS_OBJ): src/compositor/transitions.asm src/compositor/workspaces.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(COMPOSITOR_DECORATIONS_OBJ): src/compositor/decorations.asm src/compositor/compositor.inc src/compositor/wm.inc src/gui/theme.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(COMPOSITOR_CURSOR_OBJ): src/compositor/cursor.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(COMPOSITOR_OUTPUT_OBJ): src/compositor/output.asm src/compositor/compositor.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(FM_VFS_OBJ): src/fm/vfs.asm src/fm/vfs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(FM_VFS_LOCAL_OBJ): src/fm/vfs_local.asm src/fm/vfs.inc src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(FM_OPERATIONS_OBJ): src/fm/operations.asm src/fm/vfs.inc src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(FM_SEARCH_OBJ): src/fm/search.asm src/fm/vfs.inc src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(FM_PANEL_OBJ): src/fm/panel.asm src/fm/panel.inc src/fm/vfs.inc src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(FM_MAIN_OBJ): src/fm/fm_main.asm src/fm/panel.inc src/gui/widget.inc src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(FM_STATUS_BAR_OBJ): src/fm/fm_status_bar.asm src/fm/panel.inc src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(FM_VIEWER_OBJ): src/fm/viewer.asm src/fm/viewer.inc src/gui/widget.inc src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(FM_ARCHIVE_OBJ): src/fm/archive.asm src/fm/vfs.inc src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(FM_VFS_ARCHIVE_OBJ): src/fm/vfs_archive.asm src/fm/vfs.inc src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(FM_SSH_OBJ): src/fm/ssh.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(FM_SFTP_OBJ): src/fm/sftp.asm src/fm/vfs.inc src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(FM_VFS_SFTP_OBJ): src/fm/vfs_sftp.asm src/fm/vfs.inc src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(PLUGIN_HOST_OBJ): src/plugins/host.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(PLUGIN_MANIFEST_OBJ): src/plugins/manifest.asm | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(PLUGIN_API_OBJ): src/plugins/api.asm src/hal/platform_defs.inc src/fm/vfs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(PLUGIN_REGISTRY_OBJ): src/plugins/registry.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(AS_LEXER_OBJ): src/aurascript/lexer.asm | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(AS_PARSER_OBJ): src/aurascript/parser.asm | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(AS_CODEGEN_OBJ): src/aurascript/codegen_x86_64.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(AS_RUNTIME_OBJ): src/aurascript/runtime.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(AS_CACHE_OBJ): src/aurascript/cache.asm | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(HAL_LIBINPUT_OBJ): src/hal/linux_x86_64/libinput.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(HAL_DRM_OBJ): src/hal/linux_x86_64/drm.asm src/hal/platform_defs.inc src/canvas/canvas.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_COMPOSITOR_OBJ): tests/unit/test_compositor_server.asm src/hal/platform_defs.inc src/compositor/compositor.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_SYSCALL_BIN): $(HAL_SYSCALL_OBJ) $(HAL_ERRNO_OBJ) $(TEST_SYSCALL_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

$(TEST_MEMORY_BIN): $(HAL_SYSCALL_OBJ) $(CORE_MEMORY_OBJ) $(TEST_MEMORY_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

$(TEST_THREADS_BIN): $(HAL_SYSCALL_OBJ) $(CORE_SYNC_OBJ) $(CORE_THREADS_OBJ) $(TEST_THREADS_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

$(TEST_EVENT_BIN): $(HAL_SYSCALL_OBJ) $(CORE_EVENT_OBJ) $(TEST_EVENT_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

$(TEST_IPC_BIN): $(HAL_SYSCALL_OBJ) $(CORE_THREADS_OBJ) $(CORE_IPC_OBJ) $(TEST_IPC_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

$(TEST_CANVAS_BIN): $(HAL_SYSCALL_OBJ) $(CANVAS_RASTERIZER_OBJ) $(CANVAS_TEXT_OBJ) $(CANVAS_SIMD_OBJ) $(TEST_CANVAS_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

$(TEST_WINDOW_BIN): $(HAL_SYSCALL_OBJ) $(HAL_WAYLAND_OBJ) $(HAL_WAYLAND_INPUT_OBJ) $(CORE_INPUT_OBJ) $(GUI_WINDOW_OBJ) $(CANVAS_RASTERIZER_OBJ) $(CANVAS_TEXT_OBJ) $(CANVAS_SIMD_OBJ) $(TEST_WINDOW_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

$(TEST_INPUT_BIN): $(HAL_SYSCALL_OBJ) $(HAL_WAYLAND_OBJ) $(HAL_WAYLAND_INPUT_OBJ) $(CORE_INPUT_OBJ) $(GUI_WINDOW_OBJ) $(CANVAS_RASTERIZER_OBJ) $(CANVAS_TEXT_OBJ) $(CANVAS_SIMD_OBJ) $(TEST_INPUT_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

$(TEST_LEXER_BIN): $(HAL_SYSCALL_OBJ) $(CORE_MEMORY_OBJ) $(SHELL_LEXER_OBJ) $(TEST_LEXER_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

$(TEST_PARSER_BIN): $(HAL_SYSCALL_OBJ) $(CORE_MEMORY_OBJ) $(SHELL_LEXER_OBJ) $(SHELL_PARSER_OBJ) $(TEST_PARSER_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

$(TEST_EXECUTOR_BIN): $(HAL_SYSCALL_OBJ) $(HAL_PROCESS_OBJ) $(HAL_SIGNALS_OBJ) $(HAL_FS_OBJ) $(CORE_MEMORY_OBJ) $(SHELL_LEXER_OBJ) $(SHELL_PARSER_OBJ) $(SHELL_VARIABLES_OBJ) $(SHELL_ALIAS_OBJ) $(SHELL_HISTORY_OBJ) $(SHELL_JOBS_OBJ) $(SHELL_BUILTINS_OBJ) $(SHELL_EXECUTOR_OBJ) $(SHELL_PIPELINE_OBJ) $(PLUGIN_OBJS) $(TEST_EXECUTOR_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

$(TEST_PIPELINE_BIN): $(HAL_SYSCALL_OBJ) $(HAL_PROCESS_OBJ) $(HAL_SIGNALS_OBJ) $(HAL_FS_OBJ) $(CORE_MEMORY_OBJ) $(SHELL_LEXER_OBJ) $(SHELL_PARSER_OBJ) $(SHELL_VARIABLES_OBJ) $(SHELL_ALIAS_OBJ) $(SHELL_HISTORY_OBJ) $(SHELL_JOBS_OBJ) $(SHELL_BUILTINS_OBJ) $(SHELL_EXECUTOR_OBJ) $(SHELL_PIPELINE_OBJ) $(PLUGIN_OBJS) $(TEST_PIPELINE_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

$(TEST_BUILTINS_BIN): $(HAL_SYSCALL_OBJ) $(HAL_PROCESS_OBJ) $(HAL_SIGNALS_OBJ) $(HAL_FS_OBJ) $(CORE_MEMORY_OBJ) $(SHELL_VARIABLES_OBJ) $(SHELL_ALIAS_OBJ) $(SHELL_HISTORY_OBJ) $(SHELL_JOBS_OBJ) $(SHELL_BUILTINS_OBJ) $(PLUGIN_OBJS) $(TEST_BUILTINS_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

$(TEST_JOBS_BIN): $(HAL_SYSCALL_OBJ) $(HAL_PROCESS_OBJ) $(HAL_SIGNALS_OBJ) $(HAL_FS_OBJ) $(CORE_MEMORY_OBJ) $(SHELL_LEXER_OBJ) $(SHELL_PARSER_OBJ) $(SHELL_VARIABLES_OBJ) $(SHELL_ALIAS_OBJ) $(SHELL_HISTORY_OBJ) $(SHELL_JOBS_OBJ) $(SHELL_BUILTINS_OBJ) $(SHELL_EXECUTOR_OBJ) $(SHELL_PIPELINE_OBJ) $(PLUGIN_OBJS) $(TEST_JOBS_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

$(TEST_TRUETYPE_BIN): $(HAL_SYSCALL_OBJ) $(CORE_MEMORY_OBJ) $(CANVAS_RASTERIZER_OBJ) $(CANVAS_SIMD_OBJ) $(CANVAS_TRUETYPE_OBJ) $(TEST_TRUETYPE_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

$(TEST_PNG_BIN): $(HAL_SYSCALL_OBJ) $(CORE_MEMORY_OBJ) $(CANVAS_RASTERIZER_OBJ) $(CANVAS_SIMD_OBJ) $(CANVAS_PNG_OBJ) $(TEST_PNG_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

$(TEST_RENDERING_BIN): $(HAL_SYSCALL_OBJ) $(CORE_MEMORY_OBJ) $(CANVAS_RASTERIZER_OBJ) $(CANVAS_SIMD_OBJ) $(CANVAS_GRADIENT_OBJ) $(CANVAS_ROUNDED_OBJ) $(CANVAS_BLUR_OBJ) $(CANVAS_COMPOSITE_OBJ) $(CANVAS_LINE_OBJ) $(CANVAS_CLIP_OBJ) $(TEST_RENDERING_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

$(TEST_PHYSICS_BIN): $(HAL_SYSCALL_OBJ) $(CANVAS_PHYSICS_OBJ) $(TEST_PHYSICS_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

$(WIDGET_TERMINAL_STUBS_OBJ): tests/unit/widget_terminal_stubs.asm src/gui/widget.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_WIDGETS_BIN): $(HAL_SYSCALL_OBJ) $(CORE_MEMORY_OBJ) $(CANVAS_RASTERIZER_OBJ) $(CANVAS_SIMD_OBJ) $(CANVAS_TRUETYPE_OBJ) $(CANVAS_ROUNDED_OBJ) $(CANVAS_COMPOSITE_OBJ) $(CANVAS_CLIP_OBJ) $(CANVAS_PHYSICS_OBJ) $(GUI_WIDGET_OBJ) $(WIDGET_OBJS) $(WIDGET_TERMINAL_STUBS_OBJ) $(TEST_WIDGETS_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

$(TEST_LAYOUT_BIN): $(HAL_SYSCALL_OBJ) $(CORE_MEMORY_OBJ) $(CANVAS_RASTERIZER_OBJ) $(CANVAS_SIMD_OBJ) $(CANVAS_TRUETYPE_OBJ) $(CANVAS_ROUNDED_OBJ) $(CANVAS_COMPOSITE_OBJ) $(CANVAS_CLIP_OBJ) $(CANVAS_PHYSICS_OBJ) $(GUI_WIDGET_OBJ) $(WIDGET_OBJS) $(WIDGET_TERMINAL_STUBS_OBJ) $(GUI_LAYOUT_OBJ) $(TEST_LAYOUT_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

$(TEST_GESTURE_BIN): $(HAL_SYSCALL_OBJ) $(CORE_GESTURE_OBJ) $(TEST_GESTURE_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

$(TEST_THEME_BIN): $(HAL_SYSCALL_OBJ) $(CORE_MEMORY_OBJ) $(CANVAS_RASTERIZER_OBJ) $(CANVAS_SIMD_OBJ) $(CANVAS_TRUETYPE_OBJ) $(GUI_THEME_OBJ) $(TEST_THEME_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

$(TEST_COMPOSITOR_BIN): $(HAL_SYSCALL_OBJ) $(HAL_ERRNO_OBJ) $(CORE_MEMORY_OBJ) $(CORE_EVENT_OBJ) $(HAL_WAYLAND_OBJ) $(COMPOSITOR_PROTOCOL_OBJ) $(COMPOSITOR_REGISTRY_OBJ) $(COMPOSITOR_SERVER_OBJ) $(COMPOSITOR_SURFACE_OBJ) $(COMPOSITOR_SHM_OBJ) $(COMPOSITOR_XDG_OBJ) $(COMPOSITOR_INPUT_OBJS) $(CANVAS_RASTERIZER_OBJ) $(CANVAS_SIMD_OBJ) $(TEST_COMPOSITOR_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

$(TEST_SURFACES_OBJ): tests/unit/test_surfaces.asm src/hal/platform_defs.inc src/compositor/compositor.inc src/canvas/canvas.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_SURFACES_BIN): $(HAL_SYSCALL_OBJ) $(HAL_ERRNO_OBJ) $(CORE_MEMORY_OBJ) $(CORE_EVENT_OBJ) $(HAL_WAYLAND_OBJ) $(COMPOSITOR_PROTOCOL_OBJ) $(COMPOSITOR_REGISTRY_OBJ) $(COMPOSITOR_SERVER_OBJ) $(COMPOSITOR_SURFACE_OBJ) $(COMPOSITOR_SHM_OBJ) $(COMPOSITOR_XDG_OBJ) $(COMPOSITOR_RENDER_OBJ) $(COMPOSITOR_RENDER_AUX_OBJS) $(COMPOSITOR_INPUT_OBJS) $(CANVAS_RASTERIZER_OBJ) $(CANVAS_TEXT_OBJ) $(CANVAS_SIMD_OBJ) $(TEST_SURFACES_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

$(TEST_INPUT_ROUTING_OBJ): tests/unit/test_input_routing.asm src/hal/platform_defs.inc src/compositor/compositor.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_WM_OBJ): tests/unit/test_wm.asm src/hal/platform_defs.inc src/compositor/compositor.inc src/compositor/wm.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_WORKSPACES_OBJ): tests/unit/test_workspaces.asm src/hal/platform_defs.inc src/compositor/compositor.inc src/compositor/wm.inc src/compositor/workspaces.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_DECORATIONS_OBJ): tests/unit/test_decorations.asm src/hal/platform_defs.inc src/compositor/compositor.inc src/canvas/canvas.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_VFS_OBJ): tests/unit/test_vfs.asm src/hal/platform_defs.inc src/fm/vfs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_PANEL_OBJ): tests/unit/test_panel.asm src/hal/platform_defs.inc src/gui/widget.inc src/fm/panel.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_VIEWER_OBJ): tests/unit/test_viewer.asm src/hal/platform_defs.inc src/gui/widget.inc src/fm/viewer.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_ARCHIVE_OBJ): tests/unit/test_archive.asm src/hal/platform_defs.inc src/fm/vfs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_SSH_OBJ): tests/unit/test_ssh.asm src/hal/platform_defs.inc src/fm/vfs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_FM_INTEGRATION_OBJ): tests/unit/test_fm_integration.asm src/hal/platform_defs.inc src/gui/widget.inc src/fm/panel.inc src/fm/vfs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_PLUGIN_HOST_OBJ): tests/unit/test_plugin_host.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_PLUGIN_OBJ): tests/data/test_plugin.asm | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_PLUGIN_SO): $(TEST_PLUGIN_OBJ)
	$(LD) -shared --hash-style=sysv -o $@ $<

$(TEST_PLUGIN_BAD_OBJ): tests/data/test_plugin_bad.asm | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_PLUGIN_BAD_SO): $(TEST_PLUGIN_BAD_OBJ)
	$(LD) -shared --hash-style=sysv -o $@ $<

$(TEST_PLUGIN_CRASH_OBJ): tests/data/test_plugin_crash.asm | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_PLUGIN_CRASH_SO): $(TEST_PLUGIN_CRASH_OBJ)
	$(LD) -shared --hash-style=sysv -o $@ $<

$(TEST_PLUGIN_API_OBJ): tests/unit/test_plugin_api.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_PLUGIN_CMD_OBJ): tests/data/test_plugin_cmd.asm | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_PLUGIN_CMD_SO): $(TEST_PLUGIN_CMD_OBJ)
	$(LD) -shared --hash-style=sysv -o $@ $<

$(TEST_AURASCRIPT_PARSER_OBJ): tests/unit/test_aurascript_parser.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_AURASCRIPT_CODEGEN_OBJ): tests/unit/test_aurascript_codegen.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_MARKETPLACE_OBJ): tests/unit/test_marketplace.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_MACROS_OBJ): tests/unit/test_macros.asm src/hal/platform_defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(WIN_BOOTSTRAP_OBJ): src/hal/win_x86_64/bootstrap.asm src/hal/win_x86_64/defs.inc | $(WIN_BUILD_DIR)
	$(NASM_WIN) $(NASM_WIN_FLAGS) $< -o $@

$(WIN_SYSCALL_OBJ): src/hal/win_x86_64/syscall.asm src/hal/win_x86_64/defs.inc | $(WIN_BUILD_DIR)
	$(NASM_WIN) $(NASM_WIN_FLAGS) $< -o $@

$(WIN_FILEIO_OBJ): src/hal/win_x86_64/fileio.asm src/hal/win_x86_64/defs.inc | $(WIN_BUILD_DIR)
	$(NASM_WIN) $(NASM_WIN_FLAGS) $< -o $@

$(WIN_MEMORY_OBJ): src/hal/win_x86_64/memory.asm src/hal/win_x86_64/defs.inc | $(WIN_BUILD_DIR)
	$(NASM_WIN) $(NASM_WIN_FLAGS) $< -o $@

$(WIN_TIME_OBJ): src/hal/win_x86_64/time.asm src/hal/win_x86_64/defs.inc | $(WIN_BUILD_DIR)
	$(NASM_WIN) $(NASM_WIN_FLAGS) $< -o $@

$(WIN_THREADS_OBJ): src/hal/win_x86_64/threads.asm src/hal/win_x86_64/defs.inc | $(WIN_BUILD_DIR)
	$(NASM_WIN) $(NASM_WIN_FLAGS) $< -o $@

$(WIN_WINDOW_OBJ): src/hal/win_x86_64/window.asm src/hal/win_x86_64/defs.inc src/canvas/canvas.inc | $(WIN_BUILD_DIR)
	$(NASM_WIN) $(NASM_WIN_FLAGS) $< -o $@

$(WIN_CORE_INPUT_OBJ): src/core/input.asm | $(WIN_BUILD_DIR)
	$(NASM_WIN) $(NASM_WIN_PORTABLE_FLAGS) $< -o $@

$(WIN_CANVAS_RASTERIZER_OBJ): src/canvas/rasterizer.asm src/hal/platform_defs.inc src/canvas/canvas.inc | $(WIN_BUILD_DIR)
	$(NASM_WIN) $(NASM_WIN_PORTABLE_FLAGS) $< -o $@

$(WIN_CANVAS_SIMD_OBJ): src/canvas/simd.asm src/hal/platform_defs.inc src/canvas/canvas.inc | $(WIN_BUILD_DIR)
	$(NASM_WIN) $(NASM_WIN_PORTABLE_FLAGS) $< -o $@

$(WIN_GDI_OBJ): src/hal/win_x86_64/gdi.asm src/hal/win_x86_64/defs.inc | $(WIN_BUILD_DIR)
	$(NASM_WIN) $(NASM_WIN_FLAGS) $< -o $@

$(WIN_EXECUTOR_WIN_OBJ): src/hal/win_x86_64/executor_win.asm src/hal/win_x86_64/defs.inc | $(WIN_BUILD_DIR)
	$(NASM_WIN) $(NASM_WIN_FLAGS) $< -o $@

$(WIN_PROCESS_OBJ): src/hal/win_x86_64/process.asm src/hal/win_x86_64/defs.inc | $(WIN_BUILD_DIR)
	$(NASM_WIN) $(NASM_WIN_FLAGS) $< -o $@

$(TEST_WIN32_HAL_OBJ): tests/unit/test_win32_hal.asm src/hal/win_x86_64/defs.inc | $(WIN_BUILD_DIR)
	$(NASM_WIN) $(NASM_WIN_FLAGS) $< -o $@

$(TEST_WIN32_WINDOW_OBJ): tests/unit/test_win32_window.asm src/hal/win_x86_64/defs.inc src/canvas/canvas.inc | $(WIN_BUILD_DIR)
	$(NASM_WIN) $(NASM_WIN_FLAGS) $< -o $@

$(WIN_ABI_OBJ): src/hal/win_x86_64/abi.asm | $(WIN_BUILD_DIR)
	$(NASM_WIN) $(NASM_WIN_FLAGS) $< -o $@

$(TEST_WIN64_ABI_OBJ): tests/unit/test_win64_abi.asm src/hal/win_x86_64/defs.inc | $(WIN_BUILD_DIR)
	$(NASM_WIN) $(NASM_WIN_FLAGS) $< -o $@

ifeq ($(WIN_PE_LINKER),msvc)
$(TEST_WIN64_ABI_BIN): $(TEST_WIN64_ABI_OBJ) $(WIN_ABI_OBJ) $(WIN_BOOTSTRAP_OBJ)
	$(WIN_LINK) $(WIN_PE_LINK_FLAGS) /OUT:$@ $^ $(WIN_PE_LIBS)
else
$(TEST_WIN64_ABI_BIN): $(TEST_WIN64_ABI_OBJ) $(WIN_ABI_OBJ) $(WIN_BOOTSTRAP_OBJ)
	$(WIN_LD) $(WIN_LD_FLAGS) -o $@ $^
endif

$(TEST_WIN64_HAL_CORE_OBJ): tests/unit/test_win64_hal_core.asm src/hal/win_x86_64/defs.inc | $(WIN_BUILD_DIR)
	$(NASM_WIN) $(NASM_WIN_FLAGS) $< -o $@

ifeq ($(WIN_PE_LINKER),msvc)
$(TEST_WIN64_HAL_CORE_BIN): $(TEST_WIN64_HAL_CORE_OBJ) $(WIN_BOOTSTRAP_OBJ) $(WIN_ABI_OBJ) $(WIN_MEMORY_OBJ) $(WIN_TIME_OBJ) $(WIN_THREADS_OBJ)
	$(WIN_LINK) $(WIN_PE_LINK_FLAGS) /OUT:$@ $^ $(WIN_PE_LIBS)
else
$(TEST_WIN64_HAL_CORE_BIN): $(TEST_WIN64_HAL_CORE_OBJ) $(WIN_BOOTSTRAP_OBJ) $(WIN_ABI_OBJ) $(WIN_MEMORY_OBJ) $(WIN_TIME_OBJ) $(WIN_THREADS_OBJ)
	$(WIN_LD) $(WIN_LD_FLAGS) -o $@ $^
endif

$(TEST_WIN64_HAL_FILEIO_OBJ): tests/unit/test_win64_hal_fileio.asm src/hal/win_x86_64/defs.inc | $(WIN_BUILD_DIR)
	$(NASM_WIN) $(NASM_WIN_FLAGS) $< -o $@

ifeq ($(WIN_PE_LINKER),msvc)
$(TEST_WIN64_HAL_FILEIO_BIN): $(TEST_WIN64_HAL_FILEIO_OBJ) $(WIN_BOOTSTRAP_OBJ) $(WIN_ABI_OBJ) $(WIN_FILEIO_OBJ) $(WIN_SYSCALL_OBJ)
	$(WIN_LINK) $(WIN_PE_LINK_FLAGS) /OUT:$@ $^ $(WIN_PE_LIBS)
else
$(TEST_WIN64_HAL_FILEIO_BIN): $(TEST_WIN64_HAL_FILEIO_OBJ) $(WIN_BOOTSTRAP_OBJ) $(WIN_ABI_OBJ) $(WIN_FILEIO_OBJ) $(WIN_SYSCALL_OBJ)
	$(WIN_LD) $(WIN_LD_FLAGS) -o $@ $^
endif

$(TEST_WIN64_HAL_PROCESS_OBJ): tests/unit/test_win64_hal_process.asm src/hal/win_x86_64/defs.inc | $(WIN_BUILD_DIR)
	$(NASM_WIN) $(NASM_WIN_FLAGS) $< -o $@

$(TEST_WIN64_WINDOW_OBJ): tests/unit/test_win64_window.asm src/hal/win_x86_64/defs.inc src/canvas/canvas.inc | $(WIN_BUILD_DIR)
	$(NASM_WIN) $(NASM_WIN_FLAGS) $< -o $@

ifeq ($(WIN_PE_LINKER),msvc)
$(TEST_WIN64_WINDOW_BIN): $(TEST_WIN64_WINDOW_OBJ) $(WIN_BOOTSTRAP_OBJ) $(WIN_ABI_OBJ) $(WIN_SYSCALL_OBJ) $(WIN_MEMORY_OBJ) $(WIN_TIME_OBJ) $(WIN_THREADS_OBJ) $(WIN_FILEIO_OBJ) $(WIN_WINDOW_OBJ) $(WIN_CORE_INPUT_OBJ) $(WIN_CANVAS_RASTERIZER_OBJ) $(WIN_CANVAS_SIMD_OBJ)
	$(WIN_LINK) $(WIN_PE_LINK_FLAGS) /OUT:$@ $^ $(WIN_PE_LIBS)
else
$(TEST_WIN64_WINDOW_BIN): $(TEST_WIN64_WINDOW_OBJ) $(WIN_BOOTSTRAP_OBJ) $(WIN_ABI_OBJ) $(WIN_SYSCALL_OBJ) $(WIN_MEMORY_OBJ) $(WIN_TIME_OBJ) $(WIN_THREADS_OBJ) $(WIN_FILEIO_OBJ) $(WIN_WINDOW_OBJ) $(WIN_CORE_INPUT_OBJ) $(WIN_CANVAS_RASTERIZER_OBJ) $(WIN_CANVAS_SIMD_OBJ)
	$(WIN_LD) $(WIN_LD_FLAGS) -o $@ $^
endif

ifeq ($(WIN_PE_LINKER),msvc)
$(TEST_WIN64_HAL_PROCESS_BIN): $(TEST_WIN64_HAL_PROCESS_OBJ) $(WIN_BOOTSTRAP_OBJ) $(WIN_ABI_OBJ) $(WIN_FILEIO_OBJ) $(WIN_PROCESS_OBJ)
	$(WIN_LINK) $(WIN_PE_LINK_FLAGS) /OUT:$@ $^ $(WIN_PE_LIBS)
else
$(TEST_WIN64_HAL_PROCESS_BIN): $(TEST_WIN64_HAL_PROCESS_OBJ) $(WIN_BOOTSTRAP_OBJ) $(WIN_ABI_OBJ) $(WIN_FILEIO_OBJ) $(WIN_PROCESS_OBJ)
	$(WIN_LD) $(WIN_LD_FLAGS) -o $@ $^
endif

$(ARM_HAL_SYSCALL_OBJ): src/hal/linux_arm64/syscall.S src/hal/linux_arm64/defs.S | $(ARM_BUILD_DIR)
	$(ARM_AS) $(ARM_AS_FLAGS) $< -o $@

$(ARM_HAL_SYNC_OBJ): src/hal/linux_arm64/sync.S | $(ARM_BUILD_DIR)
	$(ARM_AS) $(ARM_AS_FLAGS) $< -o $@

$(ARM_HAL_THREADS_OBJ): src/hal/linux_arm64/threads.S src/hal/linux_arm64/defs.S | $(ARM_BUILD_DIR)
	$(ARM_AS) $(ARM_AS_FLAGS) $< -o $@

$(TEST_ARM64_HAL_OBJ): tests/unit/test_arm64_hal.S src/hal/linux_arm64/defs.S | $(ARM_BUILD_DIR)
	$(ARM_AS) $(ARM_AS_FLAGS) $< -o $@

$(TEST_ARM64_HAL_BIN): $(ARM_HAL_SYSCALL_OBJ) $(TEST_ARM64_HAL_OBJ)
	$(ARM_LD) $(ARM_LD_FLAGS) -o $@ $^

$(ARM_CANVAS_SIMD_OBJ): src/canvas/simd_neon.S | $(ARM_BUILD_DIR)
	$(ARM_AS) $(ARM_AS_FLAGS) $< -o $@

$(ARM_AS_CODEGEN_OBJ): src/aurascript/codegen_arm64.S src/hal/linux_arm64/defs.S | $(ARM_BUILD_DIR)
	$(ARM_AS) $(ARM_AS_FLAGS) $< -o $@

$(TEST_ARM64_CANVAS_OBJ): tests/unit/test_arm64_canvas.S src/hal/linux_arm64/defs.S | $(ARM_BUILD_DIR)
	$(ARM_AS) $(ARM_AS_FLAGS) $< -o $@

$(TEST_ARM64_CODEGEN_OBJ): tests/unit/test_arm64_codegen.S src/hal/linux_arm64/defs.S | $(ARM_BUILD_DIR)
	$(ARM_AS) $(ARM_AS_FLAGS) $< -o $@

$(TEST_ARM64_CANVAS_BIN): $(ARM_HAL_SYSCALL_OBJ) $(ARM_CANVAS_SIMD_OBJ) $(TEST_ARM64_CANVAS_OBJ)
	$(ARM_LD) $(ARM_LD_FLAGS) -o $@ $^

$(TEST_ARM64_CODEGEN_BIN): $(ARM_HAL_SYSCALL_OBJ) $(ARM_AS_CODEGEN_OBJ) $(TEST_ARM64_CODEGEN_OBJ)
	$(ARM_LD) $(ARM_LD_FLAGS) -o $@ $^

$(TEST_INPUT_ROUTING_BIN): $(HAL_SYSCALL_OBJ) $(HAL_ERRNO_OBJ) $(CORE_MEMORY_OBJ) $(CORE_EVENT_OBJ) $(HAL_WAYLAND_OBJ) $(COMPOSITOR_PROTOCOL_OBJ) $(COMPOSITOR_REGISTRY_OBJ) $(COMPOSITOR_SERVER_OBJ) $(COMPOSITOR_SURFACE_OBJ) $(COMPOSITOR_SHM_OBJ) $(COMPOSITOR_XDG_OBJ) $(COMPOSITOR_INPUT_OBJS) $(CANVAS_RASTERIZER_OBJ) $(CANVAS_SIMD_OBJ) $(TEST_INPUT_ROUTING_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

$(TEST_WM_BIN): $(HAL_SYSCALL_OBJ) $(COMPOSITOR_WM_OBJS) $(TEST_WM_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

$(TEST_WORKSPACES_BIN): $(HAL_SYSCALL_OBJ) $(HAL_ERRNO_OBJ) $(CORE_MEMORY_OBJ) $(CORE_EVENT_OBJ) $(HAL_WAYLAND_OBJ) $(CANVAS_RASTERIZER_OBJ) $(CANVAS_TEXT_OBJ) $(CANVAS_SIMD_OBJ) $(CANVAS_BLUR_OBJ) $(CANVAS_CLIP_OBJ) $(CANVAS_PHYSICS_OBJ) $(COMPOSITOR_PROTOCOL_OBJ) $(COMPOSITOR_REGISTRY_OBJ) $(COMPOSITOR_SERVER_OBJ) $(COMPOSITOR_SURFACE_OBJ) $(COMPOSITOR_SHM_OBJ) $(COMPOSITOR_XDG_OBJ) $(COMPOSITOR_RENDER_OBJ) $(COMPOSITOR_RENDER_AUX_OBJS) $(COMPOSITOR_INPUT_OBJS) $(COMPOSITOR_SPACES_OBJS) $(TEST_WORKSPACES_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

$(TEST_DECORATIONS_BIN): $(HAL_SYSCALL_OBJ) $(HAL_ERRNO_OBJ) $(CORE_MEMORY_OBJ) $(CORE_EVENT_OBJ) $(HAL_WAYLAND_OBJ) $(COMPOSITOR_PROTOCOL_OBJ) $(COMPOSITOR_REGISTRY_OBJ) $(COMPOSITOR_SERVER_OBJ) $(COMPOSITOR_SURFACE_OBJ) $(COMPOSITOR_SHM_OBJ) $(COMPOSITOR_XDG_OBJ) $(COMPOSITOR_RENDER_OBJ) $(COMPOSITOR_RENDER_AUX_OBJS) $(COMPOSITOR_INPUT_OBJS) $(CANVAS_RASTERIZER_OBJ) $(CANVAS_TEXT_OBJ) $(CANVAS_SIMD_OBJ) $(TEST_DECORATIONS_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

$(TEST_VFS_BIN): $(HAL_SYSCALL_OBJ) $(HAL_ERRNO_OBJ) $(HAL_FS_OBJ) $(HAL_PROCESS_OBJ) $(CORE_MEMORY_OBJ) $(CORE_THREADS_OBJ) $(CANVAS_PNG_OBJ) $(FM_CORE_OBJS) $(PLUGIN_API_OBJ) $(TEST_VFS_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

$(TEST_PANEL_BIN): $(HAL_SYSCALL_OBJ) $(HAL_ERRNO_OBJ) $(HAL_FS_OBJ) $(HAL_PROCESS_OBJ) $(CORE_MEMORY_OBJ) $(CORE_EVENT_OBJ) $(CORE_THREADS_OBJ) $(CANVAS_RASTERIZER_OBJ) $(CANVAS_TEXT_OBJ) $(CANVAS_SIMD_OBJ) $(CANVAS_TRUETYPE_OBJ) $(CANVAS_PNG_OBJ) $(CANVAS_ROUNDED_OBJ) $(CANVAS_COMPOSITE_OBJ) $(CANVAS_CLIP_OBJ) $(CANVAS_PHYSICS_OBJ) $(GUI_WIDGET_OBJ) $(WIDGET_OBJS) $(WIDGET_FILE_PANEL_OBJ) $(WIDGET_TERMINAL_STUBS_OBJ) $(FM_CORE_OBJS) $(FM_UI_OBJS) $(FM_VIEWER_OBJ) $(PLUGIN_API_OBJ) $(TEST_PANEL_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

$(TEST_VIEWER_BIN): $(HAL_SYSCALL_OBJ) $(HAL_ERRNO_OBJ) $(HAL_FS_OBJ) $(CORE_MEMORY_OBJ) $(CANVAS_RASTERIZER_OBJ) $(CANVAS_TEXT_OBJ) $(CANVAS_SIMD_OBJ) $(FM_VIEWER_OBJ) $(PLUGIN_API_OBJ) $(TEST_VIEWER_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

$(TEST_ARCHIVE_BIN): $(HAL_SYSCALL_OBJ) $(HAL_ERRNO_OBJ) $(HAL_FS_OBJ) $(HAL_PROCESS_OBJ) $(CORE_MEMORY_OBJ) $(CANVAS_PNG_OBJ) $(FM_VFS_OBJ) $(FM_VFS_LOCAL_OBJ) $(FM_ARCHIVE_OBJ) $(FM_VFS_ARCHIVE_OBJ) $(FM_SSH_OBJ) $(FM_VFS_SFTP_OBJ) $(PLUGIN_API_OBJ) $(TEST_ARCHIVE_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

$(TEST_SSH_BIN): $(HAL_SYSCALL_OBJ) $(HAL_ERRNO_OBJ) $(HAL_FS_OBJ) $(HAL_PROCESS_OBJ) $(CORE_MEMORY_OBJ) $(CANVAS_PNG_OBJ) $(FM_VFS_OBJ) $(FM_VFS_LOCAL_OBJ) $(FM_ARCHIVE_OBJ) $(FM_VFS_ARCHIVE_OBJ) $(FM_SSH_OBJ) $(FM_SFTP_OBJ) $(FM_VFS_SFTP_OBJ) $(PLUGIN_API_OBJ) $(TEST_SSH_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

$(TEST_FM_INTEGRATION_BIN): $(HAL_SYSCALL_OBJ) $(HAL_ERRNO_OBJ) $(HAL_FS_OBJ) $(HAL_PROCESS_OBJ) $(CORE_MEMORY_OBJ) $(CORE_THREADS_OBJ) $(CANVAS_RASTERIZER_OBJ) $(CANVAS_TEXT_OBJ) $(CANVAS_SIMD_OBJ) $(CANVAS_TRUETYPE_OBJ) $(CANVAS_PNG_OBJ) $(CANVAS_ROUNDED_OBJ) $(CANVAS_COMPOSITE_OBJ) $(CANVAS_CLIP_OBJ) $(CANVAS_PHYSICS_OBJ) $(GUI_WIDGET_OBJ) $(WIDGET_OBJS) $(WIDGET_FILE_PANEL_OBJ) $(WIDGET_TERMINAL_STUBS_OBJ) $(FM_CORE_OBJS) $(FM_UI_OBJS) $(FM_VIEWER_OBJ) $(PLUGIN_API_OBJ) $(TEST_FM_INTEGRATION_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

$(TEST_PLUGIN_HOST_BIN): $(HAL_SYSCALL_OBJ) $(HAL_FS_OBJ) $(HAL_PROCESS_OBJ) $(PLUGIN_OBJS) $(TEST_PLUGIN_HOST_OBJ) $(TEST_PLUGIN_SO) $(TEST_PLUGIN_BAD_SO) $(TEST_PLUGIN_CRASH_SO)
	$(LD) $(LD_FLAGS) -o $@ $(HAL_SYSCALL_OBJ) $(HAL_FS_OBJ) $(HAL_PROCESS_OBJ) $(PLUGIN_OBJS) $(TEST_PLUGIN_HOST_OBJ)

$(TEST_PLUGIN_API_BIN): $(HAL_SYSCALL_OBJ) $(HAL_ERRNO_OBJ) $(HAL_FS_OBJ) $(HAL_PROCESS_OBJ) $(HAL_SIGNALS_OBJ) $(CORE_MEMORY_OBJ) $(SHELL_VARIABLES_OBJ) $(SHELL_ALIAS_OBJ) $(SHELL_HISTORY_OBJ) $(SHELL_JOBS_OBJ) $(SHELL_BUILTINS_OBJ) $(PLUGIN_OBJS) $(TEST_PLUGIN_API_OBJ) $(TEST_PLUGIN_CMD_SO) $(TEST_PLUGIN_SO)
	$(LD) $(LD_FLAGS) -o $@ $(HAL_SYSCALL_OBJ) $(HAL_ERRNO_OBJ) $(HAL_FS_OBJ) $(HAL_PROCESS_OBJ) $(HAL_SIGNALS_OBJ) $(CORE_MEMORY_OBJ) $(SHELL_VARIABLES_OBJ) $(SHELL_ALIAS_OBJ) $(SHELL_HISTORY_OBJ) $(SHELL_JOBS_OBJ) $(SHELL_BUILTINS_OBJ) $(PLUGIN_OBJS) $(TEST_PLUGIN_API_OBJ)

$(TEST_AURASCRIPT_PARSER_BIN): $(HAL_SYSCALL_OBJ) $(CORE_MEMORY_OBJ) $(AS_OBJS) $(TEST_AURASCRIPT_PARSER_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

$(TEST_AURASCRIPT_CODEGEN_BIN): $(HAL_SYSCALL_OBJ) $(CORE_MEMORY_OBJ) $(AS_OBJS) $(TEST_AURASCRIPT_CODEGEN_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

$(TEST_MARKETPLACE_BIN): $(HAL_SYSCALL_OBJ) $(PLUGIN_REGISTRY_OBJ) $(TEST_MARKETPLACE_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

$(TEST_MACROS_BIN): $(HAL_SYSCALL_OBJ) $(CORE_MEMORY_OBJ) $(SHELL_MACROS_OBJ) $(TEST_MACROS_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

$(AURA_SHELL_BIN): $(HAL_SYSCALL_OBJ) $(HAL_PROCESS_OBJ) $(HAL_SIGNALS_OBJ) $(HAL_FS_OBJ) $(HAL_WAYLAND_OBJ) $(HAL_WAYLAND_INPUT_OBJ) $(HAL_LIBINPUT_OBJ) $(HAL_DRM_OBJ) $(CORE_MEMORY_OBJ) $(CORE_EVENT_OBJ) $(CORE_INPUT_OBJ) $(CORE_GESTURE_OBJ) $(CORE_THREADS_OBJ) $(GUI_WINDOW_OBJ) $(GUI_WIDGET_OBJ) $(WIDGET_OBJS) $(WIDGET_FILE_PANEL_OBJ) $(GUI_THEME_OBJ) $(GUI_TERMINAL_OBJ) $(GUI_LAYOUT_OBJ) $(SHELL_REPL_OBJ) $(SHELL_LEXER_OBJ) $(SHELL_PARSER_OBJ) $(SHELL_EXECUTOR_OBJ) $(SHELL_PIPELINE_OBJ) $(SHELL_VARIABLES_OBJ) $(SHELL_ALIAS_OBJ) $(SHELL_HISTORY_OBJ) $(SHELL_JOBS_OBJ) $(SHELL_BUILTINS_OBJ) $(PLUGIN_OBJS) $(CANVAS_RASTERIZER_OBJ) $(CANVAS_TEXT_OBJ) $(CANVAS_SIMD_OBJ) $(CANVAS_TRUETYPE_OBJ) $(CANVAS_PNG_OBJ) $(CANVAS_GRADIENT_OBJ) $(CANVAS_ROUNDED_OBJ) $(CANVAS_BLUR_OBJ) $(CANVAS_COMPOSITE_OBJ) $(CANVAS_LINE_OBJ) $(CANVAS_CLIP_OBJ) $(CANVAS_PHYSICS_OBJ) $(COMPOSITOR_PROTOCOL_OBJ) $(COMPOSITOR_REGISTRY_OBJ) $(COMPOSITOR_SERVER_OBJ) $(COMPOSITOR_SURFACE_OBJ) $(COMPOSITOR_SHM_OBJ) $(COMPOSITOR_XDG_OBJ) $(COMPOSITOR_RENDER_OBJ) $(COMPOSITOR_RENDER_AUX_OBJS) $(COMPOSITOR_INPUT_OBJS) $(COMPOSITOR_SPACES_OBJS) $(FM_CORE_OBJS) $(FM_UI_OBJS) $(FM_VIEWER_OBJ) $(MAIN_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

AURA_DEMO_DEPS = $(HAL_SYSCALL_OBJ) $(HAL_PROCESS_OBJ) $(HAL_SIGNALS_OBJ) $(HAL_FS_OBJ) $(HAL_WAYLAND_OBJ) $(HAL_WAYLAND_INPUT_OBJ) $(HAL_LIBINPUT_OBJ) $(HAL_DRM_OBJ) $(CORE_MEMORY_OBJ) $(CORE_EVENT_OBJ) $(CORE_INPUT_OBJ) $(CORE_GESTURE_OBJ) $(GUI_WINDOW_OBJ) $(GUI_WIDGET_OBJ) $(WIDGET_OBJS) $(GUI_THEME_OBJ) $(GUI_TERMINAL_OBJ) $(GUI_LAYOUT_OBJ) $(SHELL_REPL_OBJ) $(SHELL_LEXER_OBJ) $(SHELL_PARSER_OBJ) $(SHELL_EXECUTOR_OBJ) $(SHELL_PIPELINE_OBJ) $(SHELL_VARIABLES_OBJ) $(SHELL_ALIAS_OBJ) $(SHELL_HISTORY_OBJ) $(SHELL_JOBS_OBJ) $(SHELL_BUILTINS_OBJ) $(PLUGIN_OBJS) $(CANVAS_RASTERIZER_OBJ) $(CANVAS_TEXT_OBJ) $(CANVAS_SIMD_OBJ) $(CANVAS_TRUETYPE_OBJ) $(CANVAS_PNG_OBJ) $(CANVAS_GRADIENT_OBJ) $(CANVAS_ROUNDED_OBJ) $(CANVAS_BLUR_OBJ) $(CANVAS_COMPOSITE_OBJ) $(CANVAS_LINE_OBJ) $(CANVAS_CLIP_OBJ) $(CANVAS_PHYSICS_OBJ) $(COMPOSITOR_PROTOCOL_OBJ) $(COMPOSITOR_REGISTRY_OBJ) $(COMPOSITOR_SERVER_OBJ) $(COMPOSITOR_SURFACE_OBJ) $(COMPOSITOR_SHM_OBJ) $(COMPOSITOR_XDG_OBJ) $(COMPOSITOR_RENDER_OBJ) $(COMPOSITOR_RENDER_AUX_OBJS) $(COMPOSITOR_INPUT_OBJS) $(DEMO_WIDGETS_OBJ)

$(AURA_WIDGET_DEMO_BIN): $(AURA_DEMO_DEPS)
	$(LD) $(LD_FLAGS) -o $@ $^

clean:
	rm -rf $(BUILD_DIR) $(AURA_SHELL_BIN) $(AURA_WIDGET_DEMO_BIN)
