NASM = nasm
LD = ld
NASM_FLAGS = -f elf64 -g -F dwarf
LD_FLAGS = -nostdlib

BUILD_DIR = build
TEST_BIN = $(BUILD_DIR)/test_syscall

HAL_SYSCALL_OBJ = $(BUILD_DIR)/hal_syscall.o
HAL_ERRNO_OBJ = $(BUILD_DIR)/hal_errno.o
TEST_SYSCALL_OBJ = $(BUILD_DIR)/test_syscall.o

OBJS = $(HAL_SYSCALL_OBJ) $(HAL_ERRNO_OBJ) $(TEST_SYSCALL_OBJ)

.PHONY: all test clean

# Build main target (for now: test binary)
all: $(TEST_BIN)

# Build and run unit tests
test: $(TEST_BIN)
	./$(TEST_BIN)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(HAL_SYSCALL_OBJ): src/hal/linux_x86_64/syscall.asm src/hal/linux_x86_64/defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(HAL_ERRNO_OBJ): src/hal/linux_x86_64/errno.asm | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_SYSCALL_OBJ): tests/unit/test_syscall.asm src/hal/linux_x86_64/defs.inc | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(TEST_BIN): $(OBJS)
	$(LD) $(LD_FLAGS) -o $@ $(OBJS)

clean:
	rm -rf $(BUILD_DIR)
