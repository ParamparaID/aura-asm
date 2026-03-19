# Aura Shell — Phase 0: TODO

> Обновляется автоматически после каждого STEP.
> `[x]` = выполнено, `[ ]` = ожидает выполнения.

---

## STEP 01: HAL — Linux x86_64 syscall абстракция
- [ ] `src/hal/linux_x86_64/syscall.asm` — макросы syscall (read, write, open, close, mmap, munmap, exit, clock_gettime)
- [ ] `src/hal/linux_x86_64/errno.asm` — коды ошибок и обработка
- [ ] `src/hal/linux_x86_64/defs.inc` — константы (номера syscall, флаги O_RDONLY, PROT_READ и т.д.)
- [ ] `tests/unit/test_syscall.asm` — тест: write "Hello Aura" в stdout, проверка возврата
- [ ] `Makefile` — базовая сборка (nasm + ld)
- [ ] Бинарник собирается и выводит "Hello Aura" в терминал

## STEP 02: Memory Allocator (arena + slab)
- [ ] `src/core/memory.asm` — arena allocator (alloc, free, reset)
- [ ] `src/core/memory.asm` — slab allocator (init_slab, slab_alloc, slab_free) для фиксированных размеров
- [ ] `src/hal/linux_x86_64/mmap.asm` — обёртка mmap/munmap для получения страниц от ОС
- [ ] `tests/unit/test_memory.asm` — тесты: выделение, освобождение, переполнение arena, slab stress-test
- [ ] Все тесты проходят, нет утечек (munmap при завершении)

## STEP 03: Thread Pool
- [ ] `src/core/threads.asm` — создание потоков (clone syscall), завершение, join
- [ ] `src/core/threads.asm` — thread pool: init, submit_task, shutdown
- [ ] `src/core/threads.asm` — health monitor: счётчик падений, авто-рестарт
- [ ] `src/core/sync.asm` — примитивы синхронизации: spinlock, futex-based mutex
- [ ] `tests/unit/test_threads.asm` — тесты: запуск 4 потоков, каждый инкрементит счётчик, проверка результата
- [ ] Потоки работают, синхронизация корректна

## STEP 04: Event Loop
- [ ] `src/core/event.asm` — event loop на epoll (create, add, wait, dispatch)
- [ ] `src/core/event.asm` — таймеры (timerfd)
- [ ] `src/core/ipc.asm` — lock-free SPSC очередь (single producer, single consumer)
- [ ] `tests/unit/test_event.asm` — тест: таймер 100ms → callback → запись в pipe → epoll ловит
- [ ] `tests/unit/test_ipc.asm` — тест: producer/consumer через IPC очередь, 10000 сообщений
- [ ] Event loop стабильно работает, таймеры точны ±5ms

## STEP 05: AuraCanvas — базовый растеризатор
- [ ] `src/canvas/rasterizer.asm` — framebuffer: init, clear, put_pixel, fill_rect
- [ ] `src/canvas/rasterizer.asm` — горизонтальные/вертикальные линии
- [ ] `src/canvas/text.asm` — bitmap font 8x16 (встроенная таблица глифов, ASCII)
- [ ] `src/canvas/text.asm` — draw_char, draw_string, курсор (мигающий через таймер)
- [ ] `src/canvas/simd.asm` — SSE2: fill_rect_simd (заливка 16 байт за раз)
- [ ] `tests/unit/test_canvas.asm` — тест: рендеринг в буфер → сравнение с эталоном (массив байт)
- [ ] Framebuffer рендерит текст и прямоугольники корректно

## STEP 06: Wayland Client
- [ ] `src/hal/linux_x86_64/wayland.asm` — подключение к Wayland (wl_display через unix socket)
- [ ] `src/hal/linux_x86_64/wayland.asm` — получение wl_registry, bind: wl_compositor, wl_shm, xdg_wm_base
- [ ] `src/hal/linux_x86_64/wayland.asm` — создание surface, xdg_surface, xdg_toplevel
- [ ] `src/hal/linux_x86_64/wayland.asm` — shared memory buffer (wl_shm) → attach → commit
- [ ] `src/gui/window.asm` — создание окна заданного размера с заголовком "Aura Shell"
- [ ] Окно открывается, отображает содержимое framebuffer (заливка цветом)

## STEP 07: Input Abstraction
- [ ] `src/core/input.asm` — структура InputEvent (type, x, y, key, modifiers, timestamp)
- [ ] `src/hal/linux_x86_64/wayland_input.asm` — обработка wl_keyboard (keymap, key, modifiers)
- [ ] `src/hal/linux_x86_64/wayland_input.asm` — обработка wl_pointer (motion, button, axis)
- [ ] `src/hal/linux_x86_64/wayland_input.asm` — обработка wl_touch (down, up, motion, frame)
- [ ] `src/core/input.asm` — unified event queue: touch, mouse, keyboard → единый InputEvent
- [ ] Все типы ввода преобразуются в InputEvent и попадают в event loop

## STEP 08: Минимальный REPL
- [ ] `src/shell/repl.asm` — основной цикл: отрисовка prompt, приём ввода, отображение текста
- [ ] `src/shell/repl.asm` — обработка клавиш: printable chars, backspace, enter, arrow keys
- [ ] `src/shell/repl.asm` — буфер строки ввода, отображение через AuraCanvas
- [ ] `src/shell/repl.asm` — команда echo (ввод → вывод), команда exit
- [ ] `src/main.asm` — точка входа: init HAL → init memory → init canvas → open window → run REPL
- [ ] Бинарник запускается, окно открывается, курсор мигает, текст вводится и отображается
- [ ] Команда echo работает, exit закрывает окно

---

**Прогресс: 0/37 задач выполнено (0%)**
