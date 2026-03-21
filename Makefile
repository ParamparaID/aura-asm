NASM = nasm
LD = ld
NASM_FLAGS = -f elf64 -g -F dwarf
LD_FLAGS = -nostdlib
WAYLAND_STRICT ?= 0

ifeq ($(WAYLAND_STRICT),1)
WAYLAND_STRICT_FLAG = -DSTRICT_WAYLAND=1
else
WAYLAND_STRICT_FLAG =
endif

BUILD_DIR = build
AURA_SHELL_BIN = aura-shell
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

HAL_SYSCALL_OBJ = $(BUILD_DIR)/hal_syscall.o
HAL_ERRNO_OBJ = $(BUILD_DIR)/hal_errno.o
HAL_WAYLAND_OBJ = $(BUILD_DIR)/hal_wayland.o
HAL_WAYLAND_INPUT_OBJ = $(BUILD_DIR)/hal_wayland_input.o
HAL_PROCESS_OBJ = $(BUILD_DIR)/hal_process.o
HAL_SIGNALS_OBJ = $(BUILD_DIR)/hal_signals.o
CORE_MEMORY_OBJ = $(BUILD_DIR)/core_memory.o
CORE_SYNC_OBJ = $(BUILD_DIR)/core_sync.o
CORE_THREADS_OBJ = $(BUILD_DIR)/core_threads.o
CORE_EVENT_OBJ = $(BUILD_DIR)/core_event.o
CORE_IPC_OBJ = $(BUILD_DIR)/core_ipc.o
CORE_INPUT_OBJ = $(BUILD_DIR)/core_input.o
GUI_WINDOW_OBJ = $(BUILD_DIR)/gui_window.o
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
MAIN_OBJ = $(BUILD_DIR)/main.o
CANVAS_RASTERIZER_OBJ = $(BUILD_DIR)/canvas_rasterizer.o
CANVAS_TEXT_OBJ = $(BUILD_DIR)/canvas_text.o
CANVAS_SIMD_OBJ = $(BUILD_DIR)/canvas_simd.o
CANVAS_TRUETYPE_OBJ = $(BUILD_DIR)/canvas_truetype.o
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

.PHONY: all test run clean

# Final binary
all: $(AURA_SHELL_BIN)

# Build and run unit tests
test: test_syscall test_memory test_threads test_event test_ipc test_canvas test_lexer test_parser test_executor test_pipeline test_builtins test_jobs test_truetype

run: $(AURA_SHELL_BIN)
	./$(AURA_SHELL_BIN)

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

test_window_strict:
	$(MAKE) WAYLAND_STRICT=1 test_window -B

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(HAL_SYSCALL_OBJ): src/hal/linux_x86_64/syscall.asm src/hal/linux_x86_64/defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(HAL_ERRNO_OBJ): src/hal/linux_x86_64/errno.asm | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(HAL_WAYLAND_OBJ): src/hal/linux_x86_64/wayland.asm src/hal/linux_x86_64/defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(HAL_WAYLAND_INPUT_OBJ): src/hal/linux_x86_64/wayland_input.asm | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(HAL_PROCESS_OBJ): src/hal/linux_x86_64/process.asm src/hal/linux_x86_64/defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(HAL_SIGNALS_OBJ): src/hal/linux_x86_64/signals.asm src/hal/linux_x86_64/defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(CORE_MEMORY_OBJ): src/core/memory.asm src/hal/linux_x86_64/defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(CORE_SYNC_OBJ): src/core/sync.asm src/hal/linux_x86_64/defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(CORE_THREADS_OBJ): src/core/threads.asm src/hal/linux_x86_64/defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(CORE_EVENT_OBJ): src/core/event.asm src/hal/linux_x86_64/defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(CORE_IPC_OBJ): src/core/ipc.asm src/hal/linux_x86_64/defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(CORE_INPUT_OBJ): src/core/input.asm | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(GUI_WINDOW_OBJ): src/gui/window.asm src/hal/linux_x86_64/defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $(WAYLAND_STRICT_FLAG) $< -o $@

$(SHELL_REPL_OBJ): src/shell/repl.asm | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(SHELL_LEXER_OBJ): src/shell/lexer.asm | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(SHELL_PARSER_OBJ): src/shell/parser.asm | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(SHELL_EXECUTOR_OBJ): src/shell/executor.asm src/hal/linux_x86_64/defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(SHELL_PIPELINE_OBJ): src/shell/pipeline.asm src/hal/linux_x86_64/defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(SHELL_VARIABLES_OBJ): src/shell/variables.asm | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(SHELL_ALIAS_OBJ): src/shell/alias.asm | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(SHELL_HISTORY_OBJ): src/shell/history.asm | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(SHELL_BUILTINS_OBJ): src/shell/builtins.asm src/hal/linux_x86_64/defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(SHELL_JOBS_OBJ): src/shell/jobs.asm src/hal/linux_x86_64/defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(MAIN_OBJ): src/main.asm src/hal/linux_x86_64/defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(CANVAS_RASTERIZER_OBJ): src/canvas/rasterizer.asm src/hal/linux_x86_64/defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(CANVAS_TEXT_OBJ): src/canvas/text.asm | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(CANVAS_SIMD_OBJ): src/canvas/simd.asm | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(CANVAS_TRUETYPE_OBJ): src/canvas/truetype.asm src/hal/linux_x86_64/defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_SYSCALL_OBJ): tests/unit/test_syscall.asm src/hal/linux_x86_64/defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_MEMORY_OBJ): tests/unit/test_memory.asm src/hal/linux_x86_64/defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_THREADS_OBJ): tests/unit/test_threads.asm src/hal/linux_x86_64/defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_EVENT_OBJ): tests/unit/test_event.asm src/hal/linux_x86_64/defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_IPC_OBJ): tests/unit/test_ipc.asm src/hal/linux_x86_64/defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_CANVAS_OBJ): tests/unit/test_canvas.asm | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_WINDOW_OBJ): tests/unit/test_window.asm | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_INPUT_OBJ): tests/unit/test_input.asm | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_LEXER_OBJ): tests/unit/test_lexer.asm src/hal/linux_x86_64/defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_PARSER_OBJ): tests/unit/test_parser.asm src/hal/linux_x86_64/defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_EXECUTOR_OBJ): tests/unit/test_executor.asm src/hal/linux_x86_64/defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_PIPELINE_OBJ): tests/unit/test_pipeline.asm src/hal/linux_x86_64/defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_BUILTINS_OBJ): tests/unit/test_builtins.asm src/hal/linux_x86_64/defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_JOBS_OBJ): tests/unit/test_jobs.asm src/hal/linux_x86_64/defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_TRUETYPE_OBJ): tests/unit/test_truetype.asm src/hal/linux_x86_64/defs.inc | $(BUILD_DIR)
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

$(TEST_EXECUTOR_BIN): $(HAL_SYSCALL_OBJ) $(HAL_PROCESS_OBJ) $(HAL_SIGNALS_OBJ) $(CORE_MEMORY_OBJ) $(SHELL_LEXER_OBJ) $(SHELL_PARSER_OBJ) $(SHELL_VARIABLES_OBJ) $(SHELL_ALIAS_OBJ) $(SHELL_HISTORY_OBJ) $(SHELL_JOBS_OBJ) $(SHELL_BUILTINS_OBJ) $(SHELL_EXECUTOR_OBJ) $(SHELL_PIPELINE_OBJ) $(TEST_EXECUTOR_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

$(TEST_PIPELINE_BIN): $(HAL_SYSCALL_OBJ) $(HAL_PROCESS_OBJ) $(HAL_SIGNALS_OBJ) $(CORE_MEMORY_OBJ) $(SHELL_LEXER_OBJ) $(SHELL_PARSER_OBJ) $(SHELL_VARIABLES_OBJ) $(SHELL_ALIAS_OBJ) $(SHELL_HISTORY_OBJ) $(SHELL_JOBS_OBJ) $(SHELL_BUILTINS_OBJ) $(SHELL_EXECUTOR_OBJ) $(SHELL_PIPELINE_OBJ) $(TEST_PIPELINE_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

$(TEST_BUILTINS_BIN): $(HAL_SYSCALL_OBJ) $(HAL_PROCESS_OBJ) $(HAL_SIGNALS_OBJ) $(CORE_MEMORY_OBJ) $(SHELL_VARIABLES_OBJ) $(SHELL_ALIAS_OBJ) $(SHELL_HISTORY_OBJ) $(SHELL_JOBS_OBJ) $(SHELL_BUILTINS_OBJ) $(TEST_BUILTINS_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

$(TEST_JOBS_BIN): $(HAL_SYSCALL_OBJ) $(HAL_PROCESS_OBJ) $(HAL_SIGNALS_OBJ) $(CORE_MEMORY_OBJ) $(SHELL_LEXER_OBJ) $(SHELL_PARSER_OBJ) $(SHELL_VARIABLES_OBJ) $(SHELL_ALIAS_OBJ) $(SHELL_HISTORY_OBJ) $(SHELL_JOBS_OBJ) $(SHELL_BUILTINS_OBJ) $(SHELL_EXECUTOR_OBJ) $(SHELL_PIPELINE_OBJ) $(TEST_JOBS_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

$(TEST_TRUETYPE_BIN): $(HAL_SYSCALL_OBJ) $(CORE_MEMORY_OBJ) $(CANVAS_RASTERIZER_OBJ) $(CANVAS_SIMD_OBJ) $(CANVAS_TRUETYPE_OBJ) $(TEST_TRUETYPE_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

$(AURA_SHELL_BIN): $(HAL_SYSCALL_OBJ) $(HAL_PROCESS_OBJ) $(HAL_SIGNALS_OBJ) $(HAL_WAYLAND_OBJ) $(HAL_WAYLAND_INPUT_OBJ) $(CORE_MEMORY_OBJ) $(CORE_EVENT_OBJ) $(CORE_INPUT_OBJ) $(GUI_WINDOW_OBJ) $(SHELL_REPL_OBJ) $(SHELL_LEXER_OBJ) $(SHELL_PARSER_OBJ) $(SHELL_EXECUTOR_OBJ) $(SHELL_PIPELINE_OBJ) $(SHELL_VARIABLES_OBJ) $(SHELL_ALIAS_OBJ) $(SHELL_HISTORY_OBJ) $(SHELL_JOBS_OBJ) $(SHELL_BUILTINS_OBJ) $(CANVAS_RASTERIZER_OBJ) $(CANVAS_TEXT_OBJ) $(CANVAS_SIMD_OBJ) $(CANVAS_TRUETYPE_OBJ) $(MAIN_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

clean:
	rm -rf $(BUILD_DIR) $(AURA_SHELL_BIN)
