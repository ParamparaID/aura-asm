NASM = nasm
LD = ld
NASM_FLAGS = -f elf64 -g -F dwarf
LD_FLAGS = -nostdlib

BUILD_DIR = build
TEST_SYSCALL_BIN = $(BUILD_DIR)/test_syscall
TEST_MEMORY_BIN = $(BUILD_DIR)/test_memory
TEST_THREADS_BIN = $(BUILD_DIR)/test_threads
TEST_EVENT_BIN = $(BUILD_DIR)/test_event
TEST_IPC_BIN = $(BUILD_DIR)/test_ipc
TEST_CANVAS_BIN = $(BUILD_DIR)/test_canvas

HAL_SYSCALL_OBJ = $(BUILD_DIR)/hal_syscall.o
HAL_ERRNO_OBJ = $(BUILD_DIR)/hal_errno.o
CORE_MEMORY_OBJ = $(BUILD_DIR)/core_memory.o
CORE_SYNC_OBJ = $(BUILD_DIR)/core_sync.o
CORE_THREADS_OBJ = $(BUILD_DIR)/core_threads.o
CORE_EVENT_OBJ = $(BUILD_DIR)/core_event.o
CORE_IPC_OBJ = $(BUILD_DIR)/core_ipc.o
CANVAS_RASTERIZER_OBJ = $(BUILD_DIR)/canvas_rasterizer.o
CANVAS_TEXT_OBJ = $(BUILD_DIR)/canvas_text.o
CANVAS_SIMD_OBJ = $(BUILD_DIR)/canvas_simd.o
TEST_SYSCALL_OBJ = $(BUILD_DIR)/test_syscall.o
TEST_MEMORY_OBJ = $(BUILD_DIR)/test_memory.o
TEST_THREADS_OBJ = $(BUILD_DIR)/test_threads.o
TEST_EVENT_OBJ = $(BUILD_DIR)/test_event.o
TEST_IPC_OBJ = $(BUILD_DIR)/test_ipc.o
TEST_CANVAS_OBJ = $(BUILD_DIR)/test_canvas.o

.PHONY: all test clean

# Build main target (for now: test binary)
all: $(TEST_SYSCALL_BIN) $(TEST_MEMORY_BIN) $(TEST_THREADS_BIN) $(TEST_EVENT_BIN) $(TEST_IPC_BIN) $(TEST_CANVAS_BIN)

# Build and run unit tests
test: test_syscall test_memory test_threads test_event test_ipc test_canvas

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

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(HAL_SYSCALL_OBJ): src/hal/linux_x86_64/syscall.asm src/hal/linux_x86_64/defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(HAL_ERRNO_OBJ): src/hal/linux_x86_64/errno.asm | $(BUILD_DIR)
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

$(CANVAS_RASTERIZER_OBJ): src/canvas/rasterizer.asm src/hal/linux_x86_64/defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(CANVAS_TEXT_OBJ): src/canvas/text.asm | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(CANVAS_SIMD_OBJ): src/canvas/simd.asm | $(BUILD_DIR)
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

clean:
	rm -rf $(BUILD_DIR)
