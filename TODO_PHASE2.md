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
- [ ] `src/canvas/gradient.asm` — линейный градиент (2 цвета, произвольный угол)
- [ ] `src/canvas/gradient.asm` — радиальный градиент (center, radius)
- [ ] `src/canvas/rounded.asm` — прямоугольник со скруглёнными углами (4 независимых радиуса)
- [ ] `src/canvas/blur.asm` — box blur (горизонтальный + вертикальный pass, SIMD-оптимизация)
- [ ] `src/canvas/blur.asm` — stackblur или аппроксимация Gaussian
- [ ] `src/canvas/composite.asm` — альфа-композиция слоёв (Porter-Duff: src-over)
- [ ] `src/canvas/line.asm` — произвольные линии с антиалиасингом (Xiaolin Wu)
- [ ] `src/canvas/clip.asm` — расширенный клиппинг (стек clip regions, вложенность)
- [ ] `tests/unit/test_rendering.asm` — тесты: градиент, blur, rounded rect, compositing
- [ ] Все тесты проходят

## STEP 23: Physics Engine (UI анимации)
- [ ] `src/canvas/physics.asm` — spring model (масса, жёсткость, затухание, target)
- [ ] `src/canvas/physics.asm` — inertia model (velocity, friction, deceleration)
- [ ] `src/canvas/physics.asm` — snap points (позиции притяжения, snap-to-grid)
- [ ] `src/canvas/physics.asm` — animation scheduler (tick-based, 60fps target)
- [ ] API: `spring_create`, `spring_update(dt)`, `spring_value`, `spring_is_settled`
- [ ] API: `inertia_create`, `inertia_fling(velocity)`, `inertia_update(dt)`, `inertia_value`
- [ ] `tests/unit/test_physics.asm` — тесты: spring сходится к target, inertia замедляется до 0
- [ ] Все тесты проходят

## STEP 24: Виджеты (core set)
- [ ] `src/gui/widget.asm` — базовый Widget struct (x, y, w, h, visible, focused, dirty, children)
- [ ] `src/gui/widget.asm` — dispatch: render, handle_input, layout, measure
- [ ] `src/gui/widgets/label.asm` — текстовая метка (TrueType)
- [ ] `src/gui/widgets/button.asm` — кнопка с ripple-эффектом
- [ ] `src/gui/widgets/text_input.asm` — однострочное поле ввода с курсором
- [ ] `src/gui/widgets/text_area.asm` — многострочное поле с инерционной прокруткой
- [ ] `src/gui/widgets/list.asm` — прокручиваемый список с overscroll bounce
- [ ] `src/gui/widgets/table.asm` — таблица с сортировкой по колонкам
- [ ] `src/gui/widgets/tree.asm` — дерево (expand/collapse)
- [ ] `src/gui/widgets/scrollbar.asm` — полоса прокрутки (auto-hide)
- [ ] `src/gui/widgets/radial_menu.asm` — Context Bloom (pie menu)
- [ ] `src/gui/widgets/bottom_sheet.asm` — выдвижная панель снизу
- [ ] `src/gui/widgets/tab_bar.asm` — вкладки с swipe
- [ ] `src/gui/widgets/progress_bar.asm` — полоса прогресса (анимированная)
- [ ] `src/gui/widgets/dialog.asm` — модальное окно с backdrop blur
- [ ] `src/gui/widgets/status_bar.asm` — строка состояния
- [ ] `src/gui/widgets/split_pane.asm` — разделитель панелей
- [ ] `tests/unit/test_widgets.asm` — рендер каждого виджета в буфер, проверка
- [ ] Все тесты проходят

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

**Прогресс Phase 2: 18/48 задач выполнено (37.5%)**
