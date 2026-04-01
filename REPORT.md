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

If `nasm` or `x86_64-w64-mingw32-ld` is missing, install them or set `NASM_WIN` / `WIN_LD` in the environment to match your toolchain.

### Notes

- `win64_call_7` epilogue uses `add rsp, 72` / `pop rdi` / `pop rbp` so the stack stays balanced after the `push rdi` save slot.
- Override **`WIN_LD`** for MSVC `link.exe` users who prefer a different link step; the object files are standard `win64` NASM output.
