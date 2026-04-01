# Aura ASM — engineering report

## STEP 60A — Win64 ABI harness (2026-04-01)

### Delivered

- **`src/hal/win_x86_64/abi.asm`** — `win64_call_0` … `win64_call_5` and `win64_call_7`: SysV-style arguments (`rdi`…`r9`) are shuffled to Microsoft x64, 32-byte shadow space is reserved, the stack is 16-byte aligned at the `call`, and the function pointer in `rdi` is saved in the frame so `rdi` is restored (callee-saved on Win64).
- **`tests/unit/test_win64_abi.asm`** — Gate test: contiguous resolved pointers from `win32_WriteFile`, `WriteFile` / `VirtualAlloc` / `VirtualFree` / `QueryPerformanceCounter` / `GetCommandLineA` / `ExitProcess` through the adapters, and callee-saved `rbx`, `rdi`, `rsi`, `r12`–`r15` after a `WriteFile` call.
- **`Makefile`** — Targets `test_win64_abi`, `win_step60a_check`; `win_hal_check` now also builds `abi.obj`. Link with `WIN_LD` (default `x86_64-w64-mingw32-ld`) and `WIN_LD_FLAGS` (`-e _start --subsystem console`).

### Bootstrap changes (`src/hal/win_x86_64/bootstrap.asm`)

- Resolved **`GetCommandLineA`** (`win32_GetCommandLineA`).
- **`stdout_handle`** (`stdout_handle`): filled with `GetStdHandle(STD_OUTPUT_HANDLE)` during `bootstrap_init` (after DLL resolution).

The full PEB/hash/bootstrap table used by the shell and window code is **unchanged** aside from these additions; STEP 60A does not replace that resolver.

### How to verify

With NASM and a PE-capable GNU `ld` on `PATH`:

```text
make test_win64_abi
```

Run **`build/win_x86_64/test_win64_abi.exe`** on Windows (or Wine). Success line: **`ALL TESTS PASSED`**.

**Windows (Visual Studio):** from **x64 Native Tools Command Prompt for VS** (or after `vcvars64.bat`), run `make test_win64_abi`. If NASM is at `%LOCALAPPDATA%\bin\NASM\nasm.exe`, the Makefile picks it up automatically; otherwise set `NASM_WIN` or add NASM to `PATH`. The Makefile defaults to **`WIN_PE_LINKER=msvc`** on `Windows_NT` and invokes Microsoft **`link.exe`** with `/NODEFAULTLIB` and `kernel32.lib`. For MinGW instead, run `make WIN_PE_LINKER=ld`.

If `nasm` or the chosen linker is missing, install them or set `NASM_WIN` / `WIN_LD` / `WIN_PE_LINKER` to match your toolchain.

### Notes

- `win64_call_7` epilogue uses `add rsp, 72` / `pop rdi` / `pop rbp` so the stack stays balanced after the `push rdi` save slot.
- Override **`WIN_LD`** for MSVC `link.exe` users who prefer a different link step; the object files are standard `win64` NASM output.

## STEP 60B — HAL core on Win64 (memory, time, threads) (2026-04-01)

### Delivered

- **`src/hal/win_x86_64/memory.asm`** — `hal_mmap` / `hal_munmap` / `hal_mprotect` using only `win64_call_3` / `win64_call_4` into `VirtualAlloc`, `VirtualFree`, `VirtualProtect`.
- **`src/hal/win_x86_64/time.asm`** — `hal_clock_gettime` via `QueryPerformanceCounter` / `QueryPerformanceFrequency` and `win64_call_1`, same timespec math as the previous in-syscall implementation.
- **`src/hal/win_x86_64/threads.asm`** — `hal_thread_create` / `hal_thread_join` (`CreateThread`, `WaitForSingleObject`, `CloseHandle` via adapters), mutex as **`CRITICAL_SECTION`** (`InitializeCriticalSection`, `EnterCriticalSection`, `LeaveCriticalSection`, `DeleteCriticalSection`), `hal_atomic_inc` / **`hal_atomic_dec`** / **`hal_atomic_cas`** with `lock`ed x86-64 instructions.
- **`src/hal/win_x86_64/abi.asm`** — added **`win64_call_6`** for six-register Win32 APIs (used by `CreateThread`).
- **`src/hal/win_x86_64/bootstrap.asm`** — resolves the four critical-section APIs; **`win_bootstrap_ensure`** lives here so core HAL objects link without pulling in all of `syscall.asm`.
- **`tests/unit/test_win64_hal_core.asm`** — gate: 64 KiB `hal_mmap`, pattern check, `hal_munmap`, `hal_clock_gettime` nonzero seconds, worker thread + `hal_atomic_inc`.
- **`Makefile`** — `memory.obj`, `time.obj`, `threads.obj`; targets **`test_win64_hal_core`**, **`win_step60b_check`**; `win_hal_check` / `win_step61_check` assemble the new objects.

### Integration

- Implementations were **removed** from `syscall.asm` for mmap/munmap/mprotect, clock, threads, mutex, and atomics; those symbols are now supplied by the new translation units. Link **`memory.obj`**, **`time.obj`**, and **`threads.obj`** together with **`syscall.obj`** for a full Windows shell build.
- **`tests/unit/test_win32_hal.asm`** — `mutex_obj` resized to **`CRITICAL_SECTION_SIZE`** (40 bytes).

### How to verify

Same as STEP 60A: **x64 Native Tools** (or `vcvars64.bat`) + **`nasm` in PATH**, then:

```text
make test_win64_hal_core
```

Run **`build/win_x86_64/test_win64_hal_core.exe`**. Success line: **`ALL TESTS PASSED`**.

### Notes

- `hal_mprotect` is a real `VirtualProtect` mapping from Linux-style `PROT_*` flags (no longer a no-op stub).
- Other `syscall.asm` routines still use raw `call` to resolved Win32 pointers with manual shadow space; migrating them to `win64_call_*` is follow-up work outside STEP 60B.
