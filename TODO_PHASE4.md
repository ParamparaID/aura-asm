# Aura Shell — Phase 4: TODO

> Phase 0–3: ✅ (120/120)
> `[x]` = выполнено, `[ ]` = ожидает.

---

## STEP 40: VFS и файловые операции
- [x] `src/fm/vfs.asm` — VFS абстракция: vtable (open_dir, read_entry, stat, read_file, write_file, mkdir, rmdir, unlink, rename, copy)
- [x] `src/fm/vfs_local.asm` — Local FS провайдер через syscall (getdents64, stat, open, read, write, mkdir, rmdir, unlink, rename)
- [x] `src/fm/operations.asm` — высокоуровневые операции: copy_file, copy_dir_recursive, move, delete_recursive, calculate_dir_size
- [x] `src/fm/operations.asm` — прогресс-колбэк (для ProgressBar), отмена операции через флаг
- [x] `src/fm/operations.asm` — сравнение директорий (diff: only_left, only_right, different, same)
- [x] `src/fm/search.asm` — поиск файлов: по имени (glob pattern), по содержимому (grep), по дате/размеру
- [x] Все syscall обёртки: getdents64, stat/lstat, rename, symlink, readlink, chmod, chown, utimensat
- [x] `tests/unit/test_vfs.asm` — тесты: readdir, stat, copy, delete, search
- [x] Все тесты проходят

## STEP 41: Panel UI и навигация
- [x] `src/fm/panel.asm` — структура Panel: path, entries, sort_order, selected, scroll, filter
- [x] `src/fm/panel.asm` — загрузка директории через VFS, сортировка (name, size, date, ext), фильтрация
- [x] `src/gui/widgets/file_panel.asm` — виджет файловой панели (использует Table/List виджеты)
- [x] Отображение: иконка типа + имя + размер + дата + permissions
- [x] Двухпанельный режим: SplitPane с двумя file_panel
- [x] Однопанельный режим: один file_panel + breadcrumb навигация
- [x] Навигация: Enter → открыть директорию/файл, Backspace → parent, Tab → переключить панель
- [x] Touch: tap → select, double-tap → open, long press → Context Bloom, swipe → scroll (inertia)
- [x] Drag & Drop между панелями (touch drag файлов)
- [x] Массовый выбор: Shift+click (range), Ctrl+click (toggle), touch long press → selection mode
- [x] Переключение режимов: хоткей или кнопка
- [x] `tests/unit/test_panel.asm` — тесты: загрузка, сортировка, навигация, выделение
- [x] Все тесты проходят

## STEP 42: Просмотрщик и архивация
- [x] `src/fm/viewer.asm` — текстовый просмотрщик: прокрутка, поиск, подсветка синтаксиса (MVP: ключевые слова для .asm/.c/.py/.sh/.js)
- [x] `src/fm/viewer.asm` — hex-режим: 16 байт на строку, ASCII справа
- [x] `src/fm/archive.asm` — tar парсер: чтение заголовков (ustar формат), listing, извлечение
- [x] `src/fm/archive.asm` — tar.gz: gunzip (DEFLATE из PNG-модуля!) → tar парсер
- [x] `src/fm/archive.asm` — zip парсер: чтение central directory, listing, извлечение (DEFLATE)
- [x] `src/fm/archive.asm` — создание tar/tar.gz/zip архивов
- [x] VFS-интеграция: просмотр архива как директории (монтирование в VFS)
- [x] `tests/unit/test_viewer.asm` — тесты просмотрщика
- [x] `tests/unit/test_archive.asm` — тесты: создание tar, чтение, извлечение, zip listing
- [x] Все тесты проходят

## STEP 43: SSH/SFTP клиент
- [x] `src/fm/ssh.asm` — TCP сокет: `tcp_connect` + exec-based SSH transport (`ssh_exec_command`) для рабочего MVP
- [ ] `src/fm/ssh.asm` — нативный SSH transport: version exchange, key exchange, host key, encryption (backlog Phase 5+)
- [ ] `src/fm/ssh.asm` — нативный SSH auth: password authentication в зашифрованном канале (backlog Phase 5+)
- [x] `src/fm/sftp.asm` — SFTP protocol helpers: типы пакетов + `sftp_parse_name` (MVP parsing), API-заглушки для native-path
- [x] `src/fm/vfs_sftp.asm` — SFTP VFS-провайдер (`sftp://user@host:port/path`) через системный `ssh`
- [x] UI: Connect Dialog в `fm_main.asm` (Host/Port/User/Password, Connect/Cancel по клавиатуре, переход в remote path)
- [x] `tests/unit/test_ssh.asm` — тесты TCP connect, ssh exec-path, SFTP parsing, VFS SFTP integration (graceful skip)
- [x] Все тесты проходят

## STEP 44: Интеграция и демо
- [x] Интеграция FM в compositor: FM как Module Space, доступен из Hub (Hub Files card + Super+E request path)
- [x] Интеграция FM в shell: команда `fm` открывает файловый менеджер, `fm /path` — конкретная директория
- [x] Context Bloom для файлов: Copy, Move, Delete, Rename, Properties, Archive, Open With (implemented menu + actions path)
- [x] Quick actions: F3=View, F4=Edit, F5=Copy, F6=Move, F7=Mkdir, F8=Delete (MC-совместимость, MVP)
- [x] Status bar: текущий путь, свободное место, выбрано N файлов (MVP status line + statfs hook)
- [x] Финальный интеграционный тест: навигация, копирование между панелями, просмотр, архивация (`tests/unit/test_fm_integration.asm` smoke)
- [x] Все тесты проходят (targeted: `test_fm_integration`, full binary link)

---

**Прогресс Phase 4: 45/47 задач выполнено (96%)**
