# Aura Shell — Phase 2: TODO

> Phase 0: 37/37 ✅ | Phase 1: 35/35 ✅
> `[x]` = выполнено, `[ ]` = ожидает.

---

## STEP 20: TrueType шрифты
- [x] `src/canvas/truetype.asm` — парсер TTF: загрузка шрифта, базовые метрики, mmap + cache arena
- [x] Поддержка cmap lookup: Format 4 (BMP Unicode → glyph ID), с fallback
- [ ] Парсинг глифов: простые контуры (MVP: contour walk + iterative adaptive quadratic flattening, стек до 16 кадров, max depth 14) + compound bbox union (MVP); full compound outline merge pending
- [x] Растеризация глифов: scanline coverage AA (MVP 4x Y oversampling + segment intersections), с fallback на bbox-fill
- [x] Glyph cache: рендерим глиф один раз, сохраняем bitmap в cache arena (glyph_id + size)
- [x] API: `font_load`, `font_draw_string`, `font_measure_string`, `font_destroy`
- [x] `font_measure_string`: сумма advance по глифам + высота из hhea (исправлено: сохранять `len` до `xor edx,edx`; цикл do-while)
- [ ] Kerning: загрузка `kern` в `font_load` временно отключена (`jmp .kern_done`); `font_get_kerning` — заглушка (0) до проверки границ пары относительно длины таблицы (иначе риск SIGSEGV на части шрифтов)
- [x] `tests/unit/test_truetype.asm` — загрузка шрифта, рендеринг, проверка размеров, cache hit
- [x] Все тесты проходят

## STEP 21: PNG декодер
- [x] `src/canvas/png.asm` — парсер PNG: signature, IHDR, PLTE, IDAT (concat), IEND; `interlace != 0` → ошибка
- [x] Распаковка DEFLATE (inflate): Huffman + LZ77; fixed / dynamic / uncompressed blocks; zlib: пропуск 2-байт заголовка, Adler32 не проверяется (MVP)
- [x] Обратная фильтрация: None, Sub, Up, Average, Paeth
- [x] Поддержка: RGB/RGBA/Grayscale/Grayscale+Alpha/Indexed (8 bit), PLTE
- [x] Конвертация в ARGB32 (премультиплицированный альфа для canvas)
- [x] API: `png_load(path, path_len)` → `Image` (+8 от указателя — размер для `munmap`), `png_load_mem`, `png_destroy`
- [x] `canvas_draw_image` — альфа-блендинг (скалярно, округление `*257`); SSE2 из ТЗ — опциональный backlog
- [x] `canvas_draw_image_scaled` — MVP nearest-neighbor; bilinear — backlog
- [x] `tests/unit/test_png.asm` + `tests/data/test_image.png`; смоки DEFLATE (stored + срез IDAT)
- [x] `Makefile`: `canvas_png.o`, `test_png`, включено в `test`

## STEP 22: Продвинутый рендеринг
- [x] `src/canvas/gradient.asm` — линейный градиент (2 цвета, произвольный угол, fixed-point t)
- [x] `src/canvas/gradient.asm` — радиальный градиент (center, radius)
- [x] `src/canvas/rounded.asm` — скруглённые прямоугольники + `canvas_fill_rounded_rect_4` + обводка `canvas_draw_rounded_rect` (MVP углы по кругу; AA на границе — упрощённо)
- [x] `src/canvas/blur.asm` — двухпроходный box blur + `canvas_blur_region` (arena temp); SIMD по ТЗ — backlog
- [ ] `src/canvas/blur.asm` — stackblur / многопроходный box ≈ Gaussian — backlog
- [x] `src/canvas/composite.asm` — src-over + `canvas_fill_rect_alpha` (скалярно; SIMD — backlog)
- [x] `src/canvas/line.asm` — `canvas_draw_line_aa` (DDA + 16.16, не полный Xiaolin Wu) — Wu — backlog
- [x] `src/canvas/clip.asm` — стек clip до 16, пересечение, проверка в примитивах
- [x] `tests/unit/test_rendering.asm` — градиент, rounded, blur, composite, clip + blur_region
- [x] `Makefile`: объекты canvas + `test_rendering`
- [x] `make test`: `test_rendering` ✅; `test_png` ✅ (`png_bpp_from_ct` → `dil`; mmap файла без `MAP_ANONYMOUS`)

## STEP 23: Physics Engine (UI анимации)
- [x] `src/canvas/physics.asm` — spring model (16.16 fp, mass/stiffness/damping, settle threshold)
- [x] `src/canvas/physics.asm` — inertia model (friction, bounds, bounce fp ~0.3)
- [x] `src/canvas/physics.asm` — snap points + `snap_apply` → `spring_set_target`
- [x] `src/canvas/physics.asm` — `anim_scheduler_*` + `hal_clock_gettime`, dt в fp с clamp (жёсткие пружины + явный Эйлер не любят большой dt)
- [x] API: `spring_init` / `spring_set_target` / `spring_update` / `spring_value` / `spring_is_settled`
- [x] API: `inertia_init` / `inertia_fling` / `inertia_update` / `inertia_value` / `inertia_is_settled`
- [x] `tests/unit/test_physics.asm` — spring converge/overshoot, inertia, snap, scheduler (3 пружины 50/80/120)
- [x] `Makefile`: `canvas_physics.o`, `test_physics`, включено в `test`

## STEP 24: Виджеты (core set)
- [x] `src/gui/widget.inc` / `src/gui/widget.asm` — Widget 128 байт, vtable, arena, dirty/focus, `widget_init` / children / render / hit-test / input
- [x] `src/gui/widget.asm` — dispatch: `widget_render`, `widget_handle_input`, `widget_measure`, `widget_layout`, `widget_abs_pos`
- [x] `src/gui/widgets/label.asm` — текстовая метка (TrueType)
- [x] `src/gui/widgets/button.asm` — кнопка с ripple (spring) и touch/mouse
- [x] `src/gui/widgets/text_input.asm` — однострочное поле ввода с курсором
- [x] `src/gui/widgets/text_area.asm` — многострочное поле с инерционной прокруткой
- [x] `src/gui/widgets/list.asm` — прокручиваемый список (инерция, bounce)
- [x] `src/gui/widgets/table.asm` — таблица с сортировкой по колонкам
- [x] `src/gui/widgets/tree.asm` — дерево (expand/collapse)
- [x] `src/gui/widgets/scrollbar.asm` — полоса прокрутки (auto-hide spring)
- [x] `src/gui/widgets/radial_menu.asm` — Context Bloom (open spring, выбор по углу)
- [x] `src/gui/widgets/bottom_sheet.asm` — выдвижная панель снизу (spring snap)
- [x] `src/gui/widgets/tab_bar.asm` — вкладки (индикатор spring)
- [x] `src/gui/widgets/progress_bar.asm` — полоса прогресса (spring к value)
- [x] `src/gui/widgets/dialog.asm` — модальное окно (backdrop spring)
- [x] `src/gui/widgets/status_bar.asm` — строка состояния (лево/право)
- [x] `src/gui/widgets/split_pane.asm` — разделитель панелей (drag split)
- [x] `src/gui/widgets/container.asm` — группировка дочерних виджетов
- [x] `tests/unit/test_widgets.asm` — label, button+callback, list+inertia, hit-test, radial pixel
- [x] Все тесты проходят (`make test`, в т.ч. `test_widgets`)

## STEP 25: Layout Engine
- [ ] `src/gui/layout.asm` — flex-подобный layout (direction: row/column, wrap, align, justify)
- [ ] `src/gui/layout.asm` — measure pass (intrinsic sizes) + layout pass (final positions)
- [ ] `src/gui/layout.asm` — адаптивность: breakpoints (desktop >1200, tablet >600, phone <600)
- [ ] `src/gui/layout.asm` — padding, margin, gap для каждого виджета
- [ ] `src/core/gesture.asm` — Gesture Recognizer: swipe, pinch, long press, multi-finger
- [ ] `src/core/gesture.asm` — gesture state machine: possible → recognized → ended/cancelled
- [ ] `tests/unit/test_layout.asm` — тесты layout для разных viewport размеров
- [ ] `tests/unit/test_gesture.asm` — тесты распознавания жестов по последовательности touch events
- [ ] Все тесты проходят

## STEP 26: Интеграция и темы
- [ ] `src/gui/theme.asm` — парсер .auratheme (текстовый формат → бинарный)
- [ ] `src/gui/theme.asm` — runtime: загрузка темы, доступ к цветам/шрифтам/параметрам
- [ ] 5 встроенных тем: dark, light, nord, gruvbox, tokyo-night (в `themes/`)
- [ ] Интеграция: REPL перевести на TrueType шрифт + виджеты
- [ ] Интеграция: terminal widget (текстовый терминал внутри виджетной системы)
- [ ] Интеграция: glassmorphism для окон (blur background + alpha surface)
- [ ] Визуальный demo: showcase всех виджетов с темой
- [ ] `tests/unit/test_theme.asm` — загрузка темы, проверка значений
- [ ] Финальный интеграционный тест
- [ ] Все тесты проходят

---

**Прогресс Phase 2: ~52/68 задач выполнено (~76%)** (STEP 20–24 MVP закрыты; STEP 22 backlog: SIMD/Wu/Gaussian)
