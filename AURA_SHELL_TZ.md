# Техническое задание: Aura Shell

> Версия: 2.0 | Дата: 2026-03-19
> Статус: Черновик для согласования

---

## 1. Общее описание проекта

**Aura Shell** — кроссплатформенная операционная среда нового поколения, объединяющая командный интерпретатор, графический композитор, файловый менеджер и систему плагинов в единый продукт. Написана на 100% NASM-ассемблере для x86_64 и ARM. Включает собственный софтверный растеризатор и Wayland/Win32-композитор.

**Философия интерфейса:** Touch-First, Mouse-Compatible. Интерфейс проектируется для естественных жестов (свайпы, pinch, long press), а не для наследия WIMP-парадигмы. Мышь и клавиатура поддерживаются полноценно, но не являются отправной точкой дизайна.

**Целевая аудитория:** разработчики, системные администраторы, энтузиасты — на любых устройствах от десктопа до планшета.

**Ключевое отличие:** максимальная производительность и минимальное потребление ресурсов за счёт нативного asm-кода без рантайм-зависимостей (no libc, no runtime), в сочетании с современным touch-first интерфейсом.

---

## 2. Технические ограничения и принципы

| Параметр | Решение |
|---|---|
| Язык | NASM (100%, без C/Rust) |
| Платформы | x86_64, ARM (AArch64) |
| ОС | Linux, Windows |
| Графика | Собственный софтверный растеризатор |
| Compositor | Полноценный (Wayland на Linux, Win32 на Windows) |
| Внешние зависимости | Нет (прямые syscall / Win32 API) |
| Лицензия | AGPL-3.0 (свободное использование, коммерческое — платно) |
| Система сборки | Make + кастомные скрипты |

### 2.1 Принципы архитектуры

- **Монолит с потоковой изоляцией.** Единый бинарник, модули работают в отдельных потоках. При падении потока — автоматический перезапуск модуля без краха всей системы.
- **Защита от рекуррентных падений.** Счётчик падений на модуль. После N падений за период T модуль отключается и логирует причину. Пользователь может перезапустить вручную.
- **Прямые системные вызовы.** Linux: `syscall` инструкция. Windows: вызовы через ntdll/kernel32. Никакой libc.
- **Платформенная абстракция.** Слой HAL (Hardware Abstraction Layer) изолирует платформозависимый код. Каждый модуль работает с HAL, а не с ОС напрямую.

---

## 3. Архитектура

```
┌───────────────────────────────────────────────────────┐
│                   Aura Shell Binary                    │
├──────────┬───────────┬──────────┬────────────────────┤
│  Shell   │   GUI     │  File    │   Plugin           │
│  Engine  │ Compositor│ Manager  │   Host             │
├──────────┴───────────┴──────────┴────────────────────┤
│                Core Services Layer                     │
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌──────────┐      │
│  │ Memory │ │ Thread │ │  IPC   │ │  Event   │      │
│  │ Alloc  │ │ Pool   │ │ Bus    │ │  Loop    │      │
│  └────────┘ └────────┘ └────────┘ └──────────┘      │
│  ┌────────────┐ ┌──────────────┐                     │
│  │ Gesture    │ │ Input        │                     │
│  │ Recognizer │ │ Abstraction  │                     │
│  └────────────┘ └──────────────┘                     │
├───────────────────────────────────────────────────────┤
│           HAL (Hardware Abstraction Layer)             │
│  ┌─────────────┐         ┌─────────────┐             │
│  │ Linux HAL   │         │ Windows HAL │             │
│  │ (syscall)   │         │ (Win32 API) │             │
│  └─────────────┘         └─────────────┘             │
└───────────────────────────────────────────────────────┘
```

### 3.1 Модули верхнего уровня

| Модуль | Назначение | Поток |
|---|---|---|
| **Shell Engine** | Парсинг команд, выполнение, скриптовый язык, job control | Основной + дочерние |
| **GUI Compositor** | Растеризация, композиция окон, ввод, жесты, темы | Рендер-поток |
| **File Manager** | Двухпанельный/однопанельный режим, VFS, архивы | Отдельный поток |
| **Plugin Host** | Загрузка .so/.dll, песочница, API-хуки | По потоку на плагин |

### 3.2 Core Services

| Сервис | Описание |
|---|---|
| **Memory Allocator** | Кастомный аллокатор: arena + slab. Без malloc. Пулы памяти per-thread для минимизации блокировок. |
| **Thread Pool** | Управление потоками через clone (Linux) / CreateThread (Windows). Мониторинг здоровья потоков, автоматический restart. |
| **IPC Bus** | Внутренняя шина сообщений между модулями. Lock-free очередь на атомарных операциях. |
| **Event Loop** | Единый цикл событий: ввод (клавиатура, мышь, тач), таймеры, IPC, I/O. epoll (Linux) / IOCP (Windows). |
| **Gesture Recognizer** | Распознавание жестов: swipe, pinch, long press, multi-finger. Преобразование raw touch events в семантические действия. |
| **Input Abstraction** | Унификация touch, мышь, трекпад, клавиатура в единый поток событий. Маппинг жестов на действия. |

---

## 4. Философия интерфейса

### 4.1 Ключевые принципы

- **Touch-First, Mouse-Compatible.** Всё проектируется для пальцев, но работает и с мышью/трекпадом.
- **Thumb Zone Design.** Критические элементы управления — в нижней трети экрана и боковых дугах. Никаких меню в верхней части экрана.
- **Gesture-Driven Navigation.** Основная навигация — жесты, не кнопки. Свайпы, pinch, long press, drag заменяют клики по иконкам.
- **Contextual Surfaces.** UI-элементы появляются когда нужны и исчезают когда не нужны. Нет статических тулбаров.
- **Spatial UI.** Интерфейс имеет глубину. Модули — не вкладки, а пространства, между которыми пользователь перемещается жестами.
- **Physics-Based Interactions.** Все анимации следуют физическим законам (инерция, пружинность, затухание). Haptic feedback где поддерживается.

### 4.2 Навигация: Hub-and-Spoke

**Hub (домашний экран):**
- Персонализированное пространство с living widgets (виджеты с live-данными).
- Свободная компоновка (drag), resize, группировка.
- Вертикальная прокрутка (бесконечный canvas).
- Часто используемые модули — в верхней половине экрана.

**Module Spaces:**
- Каждый модуль — полноэкранное пространство с собственной навигацией.
- Переход из Hub: tap на виджет → fly-in анимация.
- Между модулями: edge swipe (горизонтальный) или двухпальцевый свайп.
- Назад: swipe от левого края.

**Context Bloom (радиальное меню):**
- Long press на любом элементе → вокруг пальца раскрывается pie menu.
- Actions по дугам, наиболее частые — ближе к пальцу.
- Для мыши: правый клик → pie menu вместо выпадающего списка.

**Command Palette:**
- Жест трёх пальцев вниз (touch) или Ctrl+K (keyboard).
- Fuzzy search по модулям, действиям, файлам.

### 4.3 Система жестов

**Универсальные (работают везде):**

| Жест | Действие |
|---|---|
| Swipe Left/Right от края | Навигация назад/вперёд |
| Swipe Up от нижнего края | Command Palette / Quick Actions |
| Swipe Down от верхнего края | Notification Center |
| Pinch | Zoom (галерея, canvas, документы) |
| Long Press | Context Bloom (радиальное меню) |
| Two-finger swipe | Переключение между Module Spaces |
| Three-finger swipe down | Command Palette |
| Three-finger swipe up | Overview (Exposé всех модулей) |
| Shake (mobile) | Undo |

Контекстные жесты определяются per-module.

### 4.4 Адаптивный интерфейс

**Form Factor Detection:**
- Desktop (>13"): multi-panel layout, 2–3 панели рядом. Split view. Клавиатурные шорткаты параллельно с жестами.
- Tablet (8–13"): full-screen modules с gesture navigation. Slide-over panels. Split view для двух модулей.
- Phone (<8"): single-column, bottom sheet для деталей. Thumb-reachable bottom navigation.

### 4.5 Visual Design

- **Glassmorphism + Spatial Depth:** frosted glass panels, blur, subtle shadows, parallax layers. Volumetric, не flat.
- **Fluid Typography:** плавное масштабирование текста в зависимости от viewport.
- **Micro-animations:** ripple при tap, spring при drag, morph при переходах. 60fps minimum.
- **Color System:** adaptive palette (primary accent, surface, on-surface). Auto contrast adjustment. True dark mode (OLED-black), light, system follow. Per-module accent color.
- **Accessibility:** все жесты имеют keyboard и screen reader альтернативы. High contrast mode. Reduced motion mode. Configurable gesture sensitivity.

---

## 5. Модуль: Shell Engine

### 5.1 Командный интерпретатор

- Собственный синтаксис (не POSIX), оптимизированный для скорости парсинга.
- Поддержка: пайпы (`|`), редиректы (`>`, `>>`, `<`), условное выполнение (`&&`, `||`), группировка (`{}`).
- Переменные окружения, алиасы, история команд.
- Автодополнение команд, путей, аргументов.

### 5.2 Встроенные команды MVP

Файловая система: `ls`, `cd`, `cp`, `mv`, `rm`, `mkdir`, `rmdir`, `cat`, `head`, `tail`, `find`, `grep`, `chmod`, `chown`, `ln`, `stat`, `df`, `du`.

Процессы: `ps`, `kill`, `bg`, `fg`, `jobs`, `top`, `exec`.

Системные: `echo`, `env`, `export`, `set`, `unset`, `alias`, `source`, `exit`, `clear`, `history`, `which`, `whoami`, `hostname`, `date`, `uptime`.

Сеть: `ping`, `curl` (базовый HTTP-клиент), `netstat`, `ifconfig`.

### 5.3 Встроенный скриптовый язык (AuraScript)

Лёгкий императивный язык с **AOT-компиляцией** (Ahead-Of-Time) напрямую в нативный машинный код целевой платформы. Никакой виртуальной машины — скрипт компилируется в исполняемые инструкции x86_64/ARM и выполняется процессором напрямую.

**Процесс выполнения:**
```
.aura файл → Лексер → Парсер (AST) → Кодогенератор → Нативный машинный код → Прямое выполнение
```

- **Типы:** int64, float64, string, array, map, bool.
- **Управление:** if/else, for, while, match, функции.
- **Встроенные:** работа с файлами, строками, процессами, сетью.
- **Интеграция:** вызов шелл-команд из скриптов и наоборот.
- **Кэширование:** скомпилированный нативный код кэшируется. Перекомпиляция только при изменении исходника (по хешу файла).
- **JIT-режим (опциональный):** для интерактивного REPL — компиляция по одному выражению в нативный код и немедленное выполнение.

### 5.4 Job Control

- Фоновые процессы (`&`), группы процессов.
- `fg`, `bg`, `jobs`, `wait`.
- Обработка сигналов: SIGINT, SIGTERM, SIGTSTP, SIGCHLD.
- На Windows: эмуляция через Job Objects.

---

## 6. Модуль: GUI Compositor

### 6.1 Софтверный растеризатор (AuraCanvas)

Собственный 2D-растеризатор, написанный на asm. Рендеринг в framebuffer.

**Примитивы MVP:**
- Прямоугольники (заливка, обводка, скругление углов).
- Линии (произвольные, с антиалиасингом).
- Текст (растеризация TrueType/OpenType шрифтов через собственный парсер).
- Изображения (декодирование PNG, BMP; масштабирование, альфа-блендинг).
- Градиенты (линейный, радиальный).
- Клиппинг (прямоугольный).
- Blur (для glassmorphism-эффектов) — box blur с SIMD-оптимизацией.

**Оптимизации:**
- SSE2/AVX2 для пиксельных операций (блиттинг, альфа-блендинг, заливка, blur).
- NEON для ARM.
- Dirty-rect рендеринг: перерисовка только изменившихся областей.

### 6.2 Композитор

**Linux:** Wayland compositor (через libwayland-протокол, реализация на asm).
- Регистрация как Wayland compositor.
- Управление поверхностями (surfaces) сторонних приложений.
- Композиция: наложение окон, Z-порядок, прозрачность.
- Ввод: обработка wl_seat (клавиатура, мышь, тачскрин, тачпад).
- Touch protocol: wl_touch для мультитач-событий.

**Windows:** Win32 shell replacement.
- Регистрация как альтернативная оболочка (explorer replacement).
- Управление окнами через Win32 API (EnumWindows, SetWindowPos, и т.д.).
- Субклассинг чужих окон для декорирования.
- Touch: WM_TOUCH / WM_POINTER для мультитач.

### 6.3 Оконный менеджер

- **Гибридный режим:** тайловый + плавающий. Переключение по хоткею или жесту.
- Тайловый: binary split, master/stack layout.
- Плавающий: перетаскивание (drag), ресайз (pinch или edge-drag), snap-to-edge.
- Виртуальные рабочие столы (workspaces): до 10, переключение по номеру или свайпом.
- **Module Spaces:** каждый модуль — отдельное spatial пространство с fly-in/fly-out переходами.

### 6.4 Система тем (AuraTheme)

Бинарный конфиг-формат. Компилируется из человекочитаемого `.auratheme` файла.

```
# Пример .auratheme
[colors]
bg = #1a1b26
fg = #c0caf5
accent = #7aa2f7
border = #3b4261
surface = #1a1b26cc        # С альфа-каналом для glassmorphism
blur_radius = 16

[fonts]
main = "JetBrains Mono" 13
ui = "Inter" 11

[window]
border_width = 2
corner_radius = 12
gap = 4

[animation]
spring_stiffness = 300
spring_damping = 25
transition_duration = 200
```

Встроенные темы: dark, light, nord, gruvbox, tokyo-night.

### 6.5 Виджеты MVP

| Виджет | Описание |
|---|---|
| Label | Текстовая метка |
| TextInput | Однострочное поле ввода |
| TextArea | Многострочное поле с прокруткой (инерционной) |
| Button | Кнопка с текстом/иконкой, ripple-эффект при tap |
| List | Прокручиваемый список с инерцией и overscroll bounce |
| Table | Таблица с сортировкой по колонкам |
| Tree | Дерево (для файлового менеджера) |
| TabBar | Вкладки (свайп для переключения) |
| ScrollBar | Полоса прокрутки (auto-hide) |
| RadialMenu | Pie menu для Context Bloom |
| StatusBar | Строка состояния (нижняя часть экрана) |
| SplitPane | Разделитель панелей (drag для ресайза) |
| ProgressBar | Полоса прогресса |
| Dialog | Модальное окно с backdrop blur |
| BottomSheet | Выдвижная панель снизу (drag up/down) |
| Widget Card | Living card для Hub (виджеты с live-данными) |

### 6.6 Physics Engine (UI Animations)

Встроенный мини-движок физики для UI-анимаций:

- **Spring model:** масса, жёсткость, затухание. Для drag & drop, overscroll, fly-in.
- **Inertia:** скорость + трение. Для scroll, swipe, fling.
- **Snap points:** позиции «притяжения» (snap-to-grid, snap-to-edge).
- Все параметры настраиваются через тему.

---

## 7. Модуль: File Manager (AuraFM)

### 7.1 Режимы отображения

- **Двухпанельный** (MC/Far-стиль): две панели, операции между ними. Drag файлов между панелями.
- **Однопанельный** (проводник): одна панель с навигацией breadcrumb.
- Переключение режимов по хоткею или жесту.

### 7.2 Файловые операции

- Копирование, перемещение, удаление (с подтверждением через Context Bloom).
- Переименование (одиночное и массовое).
- Создание файлов и директорий.
- Сравнение директорий.
- Поиск по имени, содержимому, дате, размеру.
- Расчёт размера директории (в фоне).

### 7.3 Встроенный просмотрщик (MVP)

- Текстовые файлы: просмотр с подсветкой синтаксиса.
- Hex-режим.
- Остальные форматы (изображения, markdown, PDF) — через плагины.

### 7.4 Архивация (MVP)

- Встроенная поддержка: `.tar`, `.tar.gz`, `.zip`.
- Просмотр содержимого архива как директории.
- Извлечение, создание архивов.
- Дополнительные форматы (7z, rar) — через плагины.

### 7.5 Виртуальная файловая система (VFS)

| Провайдер | Статус |
|---|---|
| Локальная FS | MVP (встроенный) |
| SSH/SFTP | MVP (встроенный) |
| FTP | Плагин |
| Samba/SMB | Плагин |
| WebDAV | Плагин |
| Облака (S3, GCS) | Плагин |

---

## 8. Модуль: Plugin Host

### 8.1 Формат плагинов

- **Shared libraries** (`.so` на Linux, `.dll` на Windows) — для максимальной производительности.
- Плагин экспортирует стандартный набор функций (ABI контракт).
- Загрузка через прямые syscall (open + mmap на Linux, LoadLibrary на Windows).

### 8.2 Plugin API (хуки)

| Категория | Хуки |
|---|---|
| Команды | Регистрация новых шелл-команд |
| Виджеты | Добавление кастомных виджетов в GUI |
| VFS | Регистрация новых провайдеров файловой системы |
| Просмотрщик | Добавление форматов в файловый просмотрщик |
| Архивы | Поддержка новых форматов архивов |
| Сеть | Сетевые протоколы |
| Темы | Дополнительные визуальные темы |
| Жесты | Регистрация контекстных жестов для модулей |
| Hub Widgets | Добавление living cards для домашнего экрана |
| События | Подписка на системные события (файлы, процессы, таймеры) |

### 8.3 Маркетплейс плагинов

- Центральный реестр (HTTPS API).
- CLI-команды: `apkg search`, `apkg install`, `apkg update`, `apkg remove`.
- Верификация плагинов: подпись, хеш-проверка.
- Локальный кеш скачанных плагинов.

---

## 9. Этапы реализации

### Phase 0 — Фундамент (месяцы 1–3)

**Цель:** загружаемый бинарник, который открывает окно и принимает тач/клавиатурный ввод.

- [ ] HAL: абстракция syscall Linux x86_64
- [ ] Memory allocator (arena + slab)
- [ ] Thread pool (создание, завершение, мониторинг)
- [ ] Event loop (epoll, обработка клавиатуры + touch)
- [ ] AuraCanvas: заливка прямоугольника, рендеринг моноширинного текста (bitmap font)
- [ ] Wayland client (не compositor) — открытие окна, получение ввода
- [ ] Input abstraction: унификация touch + mouse + keyboard
- [ ] Минимальный REPL: ввод строки → echo

**Результат:** окно с мигающим курсором, ввод текста, вывод эха. Touch и мышь работают.

### Phase 1 — Shell Engine (месяцы 3–6)

**Цель:** рабочий командный интерпретатор.

- [ ] Парсер команд (токенизация, AST)
- [ ] Выполнение внешних программ (fork/exec на Linux)
- [ ] Пайпы и редиректы
- [ ] Переменные окружения, алиасы
- [ ] Встроенные команды: ls, cd, cp, mv, rm, mkdir, cat, echo, exit
- [ ] История команд + автодополнение
- [ ] Job control: fg, bg, jobs, &

**Результат:** можно использовать как рабочий шелл для базовых задач.

### Phase 2 — Растеризатор и виджеты (месяцы 6–10)

**Цель:** полноценный GUI-тулкит с touch-first взаимодействием.

- [ ] AuraCanvas: линии, градиенты, скругления, альфа-блендинг, blur
- [ ] TrueType парсер и растеризатор шрифтов
- [ ] PNG-декодер
- [ ] SSE2/AVX2 оптимизации для блиттинга и blur
- [ ] Gesture Recognizer: swipe, pinch, long press, multi-finger
- [ ] Physics Engine: spring model, inertia, snap points
- [ ] Виджеты: Label, TextInput, Button, List, Table, Tree, ScrollBar, RadialMenu, BottomSheet
- [ ] Система тем: парсер .auratheme, компиляция в бинарный формат
- [ ] Layout engine: адаптивное расположение (desktop / tablet / phone)

**Результат:** графический интерфейс с touch-first виджетами, инерционной прокруткой, Context Bloom.

### Phase 3 — Compositor (месяцы 10–14)

**Цель:** полноценный оконный менеджер с Hub-and-Spoke навигацией.

- [ ] Wayland compositor: регистрация, управление surfaces
- [ ] Композиция: Z-порядок, прозрачность, blur, dirty-rect
- [ ] Тайловый режим (binary split, master/stack)
- [ ] Плавающий режим (drag, pinch-resize, snap)
- [ ] Виртуальные рабочие столы (Module Spaces)
- [ ] Hub (домашний экран): виджеты, свободная компоновка
- [ ] Fly-in/fly-out анимации переходов между модулями
- [ ] Touch routing: multi-touch события к правильному окну
- [ ] Декорации окон (title bar, кнопки) — в стиле glassmorphism

**Результат:** можно запустить Aura Shell как оконный менеджер. Hub работает. Firefox запускается внутри.

### Phase 4 — File Manager (месяцы 14–17)

**Цель:** двухпанельный файловый менеджер с touch-операциями.

- [ ] VFS абстракция
- [ ] Двухпанельный и однопанельный режимы
- [ ] Файловые операции (copy, move, delete — через drag и Context Bloom)
- [ ] Просмотрщик (текст, hex)
- [ ] Поиск по файлам
- [ ] Архивация: tar, tar.gz, zip
- [ ] SSH/SFTP клиент (встроенный)

**Результат:** полноценная замена MC/Far с touch-навигацией.

### Phase 5 — Плагины и AuraScript (месяцы 17–20)

**Цель:** расширяемость.

- [ ] Plugin Host: загрузка .so/.dll, ABI контракт
- [ ] Plugin API: все категории хуков (включая жесты и Hub widgets)
- [ ] AuraScript: лексер, парсер, AOT-кодогенератор (x86_64 → нативный код)
- [ ] AuraScript: кэширование скомпилированного кода
- [ ] AuraScript: JIT-режим для REPL
- [ ] Маркетплейс: CLI-клиент (`apkg`), HTTPS-клиент, репозиторий
- [ ] Система макросов: запись и воспроизведение действий

**Результат:** сторонние разработчики могут расширять Aura Shell.

### Phase 6 — Windows и ARM (месяцы 20–24)

**Цель:** кроссплатформенность.

- [ ] HAL: Windows (Win32 API через ntdll)
- [ ] Win32 shell replacement (альтернатива explorer.exe)
- [ ] Windows touch: WM_TOUCH / WM_POINTER
- [ ] AuraScript: AOT-кодогенератор для ARM (AArch64)
- [ ] ARM HAL: AArch64 syscall, NEON-оптимизации
- [ ] Кросс-компиляция и CI для всех платформ

**Результат:** Aura Shell работает на Linux x86_64, Linux ARM, Windows x86_64.

---

## 10. Структура репозитория

```
aura-shell/
├── Makefile
├── README.md
├── LICENSE                      # AGPL-3.0
├── docs/
│   ├── architecture.md
│   ├── ui-philosophy.md         # Touch-first design guide
│   ├── gesture-spec.md          # Спецификация жестов
│   ├── plugin-api.md
│   ├── aurascript-spec.md
│   └── theme-format.md
├── src/
│   ├── hal/
│   │   ├── linux_x86_64/        # Linux syscall wrappers
│   │   ├── linux_arm64/         # ARM64 syscall wrappers
│   │   └── win_x86_64/         # Win32 API wrappers
│   ├── core/
│   │   ├── memory.asm           # Allocator
│   │   ├── threads.asm          # Thread pool
│   │   ├── ipc.asm              # Message bus
│   │   ├── event.asm            # Event loop
│   │   ├── gesture.asm          # Gesture recognizer
│   │   └── input.asm            # Input abstraction
│   ├── shell/
│   │   ├── parser.asm           # Command parser
│   │   ├── executor.asm         # Command execution
│   │   ├── builtins.asm         # Built-in commands
│   │   ├── jobs.asm             # Job control
│   │   └── completion.asm       # Autocompletion
│   ├── canvas/
│   │   ├── rasterizer.asm       # 2D rasterizer
│   │   ├── text.asm             # Font rendering
│   │   ├── image.asm            # PNG decoder
│   │   ├── blur.asm             # Gaussian/box blur for glassmorphism
│   │   ├── physics.asm          # Spring, inertia, snap
│   │   └── simd.asm             # SSE2/AVX2/NEON optimizations
│   ├── gui/
│   │   ├── compositor.asm       # Window compositor
│   │   ├── wm.asm               # Window manager (tiling/floating)
│   │   ├── hub.asm              # Hub (home screen)
│   │   ├── widgets/             # Widget implementations
│   │   │   ├── radial_menu.asm  # Context Bloom
│   │   │   ├── bottom_sheet.asm
│   │   │   ├── widget_card.asm  # Living cards
│   │   │   └── ...
│   │   ├── theme.asm            # Theme engine
│   │   └── layout.asm           # Adaptive layout engine
│   ├── fm/
│   │   ├── vfs.asm              # Virtual file system
│   │   ├── panel.asm            # Panel logic
│   │   ├── operations.asm       # File operations
│   │   ├── viewer.asm           # Built-in viewer
│   │   ├── archive.asm          # tar/zip support
│   │   └── ssh.asm              # SSH/SFTP client
│   ├── aurascript/
│   │   ├── lexer.asm            # Tokenizer
│   │   ├── parser.asm           # AST builder
│   │   ├── codegen_x86_64.asm   # AOT code generator (x86_64)
│   │   ├── codegen_arm64.asm    # AOT code generator (ARM64)
│   │   └── cache.asm            # Compiled code cache
│   └── plugins/
│       ├── host.asm             # Plugin loader
│       ├── api.asm              # Plugin API
│       └── registry.asm         # Marketplace client (apkg)
├── themes/
│   ├── dark.auratheme
│   ├── light.auratheme
│   ├── nord.auratheme
│   ├── gruvbox.auratheme
│   └── tokyo-night.auratheme
├── plugins/                     # Official plugins
│   ├── ftp/
│   ├── samba/
│   └── image-viewer/
└── tests/
    ├── unit/
    ├── integration/
    └── ui/
```

---

## 11. Тестирование

| Уровень | Подход | Инструмент |
|---|---|---|
| Юнит-тесты | Каждый .asm модуль имеет тестовый harness. Assert-макросы. | Кастомный тест-фреймворк на asm |
| Интеграционные | Shell: stdin → stdout. GUI: скриптование через IPC. | Bash-скрипты + AuraScript |
| UI-тесты | Скриншот-тесты: рендеринг виджетов в буфер, попиксельное сравнение. | Кастомный фреймворк |
| Gesture-тесты | Эмуляция touch-событий, проверка распознавания жестов. | Кастомный фреймворк |
| Стресс-тесты | Массовые файловые операции, множественные окна, нагрузка на аллокатор. | Кастомные бенчмарки |

---

## 12. Риски и митигации

| Риск | Вероятность | Митигация |
|---|---|---|
| TrueType-парсер на asm — крайне сложная задача | Высокая | Начать с bitmap-шрифтов, TrueType в Phase 2 |
| Wayland compositor на asm — мало референсов | Высокая | Изучить wlroots как референс, минимальный протокол |
| AOT-кодогенератор — сложнее VM на порядок | Высокая | Начать с минимального подмножества языка, расширять итеративно |
| Blur на CPU — тяжёлая операция | Средняя | Box blur вместо Gaussian, агрессивный SIMD, blur только изменившихся областей |
| Touch на Wayland — сложная обработка мультитач | Средняя | Начать с single-touch, мультитач добавить итеративно |
| Один разработчик + огромный скоуп → выгорание | Высокая | Строго следовать фазам. Каждая фаза — рабочий продукт |
| AI (Cursor) плохо генерирует asm | Средняя | AI для архитектуры и алгоритмов, asm писать вручную |
| Windows HAL сильно отличается от Linux | Средняя | Начать только с Linux, Windows — Phase 6 |

---

## 13. Определение успеха по фазам

| Фаза | Готово когда |
|---|---|
| Phase 0 | Окно открывается, текст вводится, touch и мышь работают |
| Phase 1 | `ls | grep .asm > result.txt` работает, фоновые процессы запускаются |
| Phase 2 | Виджеты отрисовываются, инерционная прокрутка, Context Bloom работает |
| Phase 3 | Firefox запускается внутри Aura compositor, Hub работает, модули переключаются жестами |
| Phase 4 | Копирование файла с удалённого сервера по SSH через двухпанельный drag |
| Phase 5 | Плагин устанавливается через `apkg install`, AuraScript компилируется и выполняется нативно |
| Phase 6 | Весь функционал работает на Windows и ARM |

---

## 14. Открытые вопросы

1. **Формат ABI плагинов** — calling convention, версионирование API, обратная совместимость.
2. **Спецификация AuraScript** — полная грамматика, стандартная библиотека, FFI для плагинов.
3. **Протокол маркетплейса** — API сервера, формат пакетов, система подписей.
4. **Стратегия безопасности** — sandboxing плагинов, обработка вредоносных шрифтов/PNG, валидация touch-событий.
5. **Accessibility** — поддержка screen readers через compositor, альтернативы жестам.
6. **Haptic feedback** — интеграция с libinput haptics (Linux), Windows haptics API.

---

*Документ подлежит обновлению по мере прохождения фаз разработки.*
