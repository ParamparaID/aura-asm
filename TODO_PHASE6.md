# Aura Shell — Phase 6: TODO

> Phase 0–5: ✅

---

## STEP 60: Windows HAL — Win32 API
- [x] `src/hal/win_x86_64/defs.inc` — Win32 константы, структуры (HANDLE, DWORD, SECURITY_ATTRIBUTES, STARTUPINFO, PROCESS_INFORMATION, OVERLAPPED, MSG, WNDCLASS, RECT, POINT)
- [x] `src/hal/win_x86_64/syscall.asm` — вызов Win32 API через GetProcAddress/LoadLibrary или прямые вызовы kernel32/ntdll
- [x] Обёртки: `hal_write` (WriteFile/WriteConsole), `hal_read` (ReadFile/ReadConsole), `hal_open` (CreateFileA), `hal_close` (CloseHandle), `hal_mmap` (VirtualAlloc/CreateFileMapping/MapViewOfFile), `hal_munmap` (VirtualFree/UnmapViewOfFile)
- [x] `hal_exit` (ExitProcess), `hal_clock_gettime` (QueryPerformanceCounter), `hal_getenv` (GetEnvironmentVariableA)
- [x] `hal_fork` → CreateProcess (Windows не имеет fork, нужна другая стратегия для executor)
- [x] `hal_pipe` (CreatePipe), `hal_dup2` (SetStdHandle + reassign), `hal_execve` → CreateProcess с cmd line
- [x] `hal_socket/hal_connect/hal_bind/hal_listen/hal_accept` через Winsock2 (WSAStartup + socket/connect/...)
- [x] Threads: `hal_thread_create` (CreateThread), `hal_mutex` (CRITICAL_SECTION или SRWLock), `hal_atomic` (InterlockedXxx)
- [x] Event loop: IOCP (CreateIoCompletionPort) или select/WSAPoll
- [x] `tests/unit/test_win32_hal.asm` — базовые тесты HAL на Windows
- [x] Сборка: nasm -f win64 + link.exe или GoLink

## STEP 61: Windows Compositor и Shell Replacement
- [x] `src/hal/win_x86_64/window.asm` — Win32 окно: RegisterClassEx, CreateWindowEx, message loop (GetMessage/TranslateMessage/DispatchMessage)
- [x] `src/hal/win_x86_64/gdi.asm` — GDI/GDI+ для вывода canvas: CreateDIBSection, BitBlt, StretchDIBits
- [x] Input: WM_KEYDOWN/WM_KEYUP/WM_CHAR, WM_MOUSEMOVE/WM_LBUTTONDOWN, WM_TOUCH/WM_POINTER для мультитач
- [x] Shell replacement: регистрация как альтернативная оболочка (HKCU\Software\Microsoft\Windows NT\CurrentVersion\Winlogon\Shell)
- [x] Window management: EnumWindows, SetWindowPos, ShowWindow для управления чужими окнами
- [x] Субклассинг: SetWindowLongPtr(GWLP_WNDPROC) для декораций
- [x] Интеграция: AuraCanvas → DIBSection → BitBlt для отрисовки
- [x] `tests/unit/test_win32_window.asm` — открытие окна, рендер canvas, обработка ввода

## STEP 62: ARM64 HAL — AArch64 syscalls
- [x] `src/hal/linux_arm64/defs.inc` — ARM64 Linux syscall номера (отличаются от x86_64!)
- [x] `src/hal/linux_arm64/syscall.asm` — макрос syscall через `svc #0` (x8=nr, x0-x5=args, x0=return)
- [x] Все hal_* обёртки: write, read, open, close, mmap, munmap, exit, clock_gettime, fork, execve, waitpid, pipe, dup2, socket, connect, bind, listen, accept, epoll, timerfd, getdents64, stat, и др.
- [x] Threads: clone syscall на ARM64 (аналогично x86_64 но другие регистры)
- [x] Sync: LDXR/STXR для atomic operations (вместо LOCK CMPXCHG), DMB/DSB для barriers
- [x] `tests/unit/test_arm64_hal.asm` — базовые тесты
- [x] Cross-compilation Makefile: `nasm` не поддерживает ARM → использовать GNU `as` (GAS) или `aarch64-linux-gnu-as`

## STEP 63: ARM64 Canvas и NEON оптимизации
- [x] `src/canvas/simd_neon.S` — NEON эквиваленты SSE2 функций: fill_rect, clear, alpha_blend, blur (MVP blur-copy path)
- [x] NEON: 128-bit registers (v0-v31), LD1/ST1 для загрузки 4×ARGB пикселей, SIMD fill/clear loops
- [x] AuraScript codegen: `src/aurascript/codegen_arm64.S` — ARM64 кодогенератор (MVP compile API + AArch64 prologue/epilogue для non-leaf функций)
- [x] Runtime detection: `canvas_has_neon()` (AArch64 mandatory NEON → return 1)
- [x] `tests/unit/test_arm64_canvas.S` и `tests/unit/test_arm64_codegen.S` — ARM64 тесты canvas/codegen под QEMU

## STEP 64: CI/CD, кросс-компиляция и финальная полировка
- [ ] `Makefile` обновлён: `PLATFORM=linux_x86_64 | linux_arm64 | win_x86_64`, автоопределение через uname
- [ ] CI: GitHub Actions workflow для 3 платформ (Linux x86_64 native, Linux ARM64 через QEMU, Windows через cross-compile или runner)
- [ ] Conditional compilation: `%ifdef PLATFORM_LINUX_X86_64` / `%ifdef PLATFORM_WIN_X86_64` / `%ifdef PLATFORM_LINUX_ARM64`
- [ ] Все тесты проходят на всех 3 платформах
- [ ] README обновлён: инструкции сборки для каждой платформы
- [ ] Финальный бинарник: один Makefile, три платформы
- [ ] CHANGELOG.md: полная история изменений от Phase 0 до Phase 6

---

**Прогресс Phase 6: 31/35 задач (89%)**
