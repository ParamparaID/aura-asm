# Aura Shell — Phase 0: TODO

> Обновляется автоматически после каждого STEP.
> `[x]` = выполнено, `[ ]` = ожидает выполнения.

---

## STEP 01: HAL — Linux x86_64 syscall абстракция
- [x] `src/hal/linux_x86_64/syscall.asm` — макросы syscall (read, write, open, close, mmap, munmap, exit, clock_gettime)
- [x] `src/hal/linux_x86_64/errno.asm` — коды ошибок и обработка
- [x] `src/hal/linux_x86_64/defs.inc` — константы (номера syscall, флаги O_RDONLY, PROT_READ и т.д.)
- [x] `tests/unit/test_syscall.asm` — тест: write "Hello Aura" в stdout, проверка возврата
- [x] `Makefile` — базовая сборка (nasm + ld)
- [x] Бинарник собирается и выводит "Hello Aura" в терминал

## STEP 02: Memory Allocator (arena + slab)
- [x] `src/core/memory.asm` — arena allocator (alloc, free, reset)
- [x] `src/core/memory.asm` — slab allocator (init_slab, slab_alloc, slab_free) для фиксированных размеров
- [x] `src/hal/linux_x86_64/syscall.asm` — используются обёртки `hal_mmap`/`hal_munmap` для получения страниц от ОС
- [x] `tests/unit/test_memory.asm` — тесты: выделение, освобождение, переполнение arena, slab stress-test
- [x] Все тесты проходят, нет утечек (munmap при завершении)

## STEP 03: Thread Pool
- [x] `src/core/threads.asm` — создание потоков (clone syscall), завершение, join
- [x] `src/core/threads.asm` — thread pool: init, submit_task, shutdown
- [x] `src/core/threads.asm` — health monitor: счётчик падений, авто-рестарт
- [x] `src/core/sync.asm` — примитивы синхронизации: spinlock, futex-based mutex
- [x] `tests/unit/test_threads.asm` — тесты: запуск 4 потоков, каждый инкрементит счётчик, проверка результата
- [x] Потоки работают, синхронизация корректна

## STEP 04: Event Loop
- [x] `src/core/event.asm` — event loop на epoll (create, add, wait, dispatch)
- [x] `src/core/event.asm` — таймеры (timerfd)
- [x] `src/core/ipc.asm` — lock-free SPSC очередь (single producer, single consumer)
- [x] `tests/unit/test_event.asm` — тест: таймер 100ms → callback → запись в pipe → epoll ловит
- [x] `tests/unit/test_ipc.asm` — тест: producer/consumer через IPC очередь, 10000 сообщений
- [x] Event loop стабильно работает, таймеры точны ±5ms

## STEP 05: AuraCanvas — базовый растеризатор
- [x] `src/canvas/rasterizer.asm` — framebuffer: init, clear, put_pixel, fill_rect
- [x] `src/canvas/rasterizer.asm` — горизонтальные/вертикальные линии
- [x] `src/canvas/text.asm` — bitmap font 8x16 (встроенная таблица глифов, ASCII)
- [x] `src/canvas/text.asm` — draw_char, draw_string, курсор (мигающий через таймер)
- [x] `src/canvas/simd.asm` — SSE2: fill_rect_simd (заливка 16 байт за раз)
- [x] `tests/unit/test_canvas.asm` — тест: рендеринг в буфер → сравнение с эталоном (массив байт)
- [x] Framebuffer рендерит текст и прямоугольники корректно

## STEP 06: Wayland Client
- [x] `src/hal/linux_x86_64/wayland.asm` — подключение к Wayland (wl_display через unix socket)
- [x] `src/hal/linux_x86_64/wayland.asm` — получение wl_registry, bind: wl_compositor, wl_shm, xdg_wm_base
- [x] `src/hal/linux_x86_64/wayland.asm` — создание surface, xdg_surface, xdg_toplevel
- [x] `src/hal/linux_x86_64/wayland.asm` — shared memory buffer (wl_shm) → attach → commit
- [x] `src/gui/window.asm` — создание окна заданного размера с заголовком "Aura Shell"
- [x] Окно открывается, отображает содержимое framebuffer (заливка цветом)

## STEP 07: Input Abstraction
- [x] `src/core/input.asm` — структура InputEvent (type, x, y, key, modifiers, timestamp)
- [x] `src/hal/linux_x86_64/wayland_input.asm` — обработка wl_keyboard (keymap, key, modifiers)
- [x] `src/hal/linux_x86_64/wayland_input.asm` — обработка wl_pointer (motion, button, axis)
- [x] `src/hal/linux_x86_64/wayland_input.asm` — обработка wl_touch (down, up, motion, frame)
- [x] `src/core/input.asm` — unified event queue: touch, mouse, keyboard → единый InputEvent
- [x] Все типы ввода преобразуются в InputEvent и попадают в event loop

## STEP 08: Минимальный REPL
- [x] `src/shell/repl.asm` — основной цикл: отрисовка prompt, приём ввода, отображение текста
- [x] `src/shell/repl.asm` — обработка клавиш: printable chars, backspace, enter, arrow keys
- [x] `src/shell/repl.asm` — буфер строки ввода, отображение через AuraCanvas
- [x] `src/shell/repl.asm` — команда echo (ввод → вывод), команда exit
- [x] `src/main.asm` — точка входа: init HAL → init memory → init canvas → open window → run REPL
- [x] Бинарник запускается, окно открывается, курсор мигает, текст вводится и отображается
- [x] Команда echo работает, exit закрывает окно

---

**Прогресс: 37/37 задач выполнено (100%)**
