NASM = nasm
LD = ld
NASM_FLAGS = -f elf64 -g -F dwarf
LD_FLAGS = -nostdlib

BUILD_DIR = build
TEST_SYSCALL_BIN = $(BUILD_DIR)/test_syscall
TEST_MEMORY_BIN = $(BUILD_DIR)/test_memory

HAL_SYSCALL_OBJ = $(BUILD_DIR)/hal_syscall.o
HAL_ERRNO_OBJ = $(BUILD_DIR)/hal_errno.o
CORE_MEMORY_OBJ = $(BUILD_DIR)/core_memory.o
TEST_SYSCALL_OBJ = $(BUILD_DIR)/test_syscall.o
TEST_MEMORY_OBJ = $(BUILD_DIR)/test_memory.o

.PHONY: all test clean

# Build main target (for now: test binary)
all: $(TEST_SYSCALL_BIN) $(TEST_MEMORY_BIN)

# Build and run unit tests
test: test_syscall test_memory

test_syscall: $(TEST_SYSCALL_BIN)
	./$(TEST_SYSCALL_BIN)

test_memory: $(TEST_MEMORY_BIN)
	./$(TEST_MEMORY_BIN)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(HAL_SYSCALL_OBJ): src/hal/linux_x86_64/syscall.asm src/hal/linux_x86_64/defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(HAL_ERRNO_OBJ): src/hal/linux_x86_64/errno.asm | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(CORE_MEMORY_OBJ): src/core/memory.asm src/hal/linux_x86_64/defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_SYSCALL_OBJ): tests/unit/test_syscall.asm src/hal/linux_x86_64/defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_MEMORY_OBJ): tests/unit/test_memory.asm src/hal/linux_x86_64/defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_SYSCALL_BIN): $(HAL_SYSCALL_OBJ) $(HAL_ERRNO_OBJ) $(TEST_SYSCALL_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

$(TEST_MEMORY_BIN): $(HAL_SYSCALL_OBJ) $(CORE_MEMORY_OBJ) $(TEST_MEMORY_OBJ)
	$(LD) $(LD_FLAGS) -o $@ $^

clean:
	rm -rf $(BUILD_DIR)
