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
- [ ] `src/fm/viewer.asm` — текстовый просмотрщик: прокрутка, поиск, подсветка синтаксиса (MVP: ключевые слова для .asm/.c/.py/.sh/.js)
- [ ] `src/fm/viewer.asm` — hex-режим: 16 байт на строку, ASCII справа
- [ ] `src/fm/archive.asm` — tar парсер: чтение заголовков (ustar формат), listing, извлечение
- [ ] `src/fm/archive.asm` — tar.gz: gunzip (DEFLATE из PNG-модуля!) → tar парсер
- [ ] `src/fm/archive.asm` — zip парсер: чтение central directory, listing, извлечение (DEFLATE)
- [ ] `src/fm/archive.asm` — создание tar/tar.gz/zip архивов
- [ ] VFS-интеграция: просмотр архива как директории (монтирование в VFS)
- [ ] `tests/unit/test_viewer.asm` — тесты просмотрщика
- [ ] `tests/unit/test_archive.asm` — тесты: создание tar, чтение, извлечение, zip listing
- [ ] Все тесты проходят

## STEP 43: SSH/SFTP клиент
- [ ] `src/fm/ssh.asm` — TCP сокет: connect, send, recv
- [ ] `src/fm/ssh.asm` — SSH transport: version exchange, key exchange (diffie-hellman-group14-sha256 MVP), host key, encryption
- [ ] `src/fm/ssh.asm` — SSH auth: password authentication (encrypted channel)
- [ ] `src/fm/sftp.asm` — SFTP protocol: init, opendir, readdir, stat, open, read, write, close, mkdir, rmdir, remove, rename
- [ ] `src/fm/vfs_sftp.asm` — SFTP провайдер для VFS
- [ ] UI: диалог подключения (host, port, user, password/key), статус подключения
- [ ] `tests/unit/test_ssh.asm` — тесты TCP connect, SSH handshake (mock server)
- [ ] Все тесты проходят

## STEP 44: Интеграция и демо
- [ ] Интеграция FM в compositor: FM как Module Space, доступен из Hub
- [ ] Интеграция FM в shell: команда `fm` открывает файловый менеджер, `fm /path` — конкретная директория
- [ ] Context Bloom для файлов: Copy, Move, Delete, Rename, Properties, Archive, Open With
- [ ] Quick actions: F3=View, F4=Edit, F5=Copy, F6=Move, F7=Mkdir, F8=Delete (MC-совместимость)
- [ ] Status bar: текущий путь, свободное место, выбрано N файлов (XXX MB)
- [ ] Финальный интеграционный тест: навигация, копирование между панелями, просмотр, архивация
- [ ] Все тесты проходят

---

**Прогресс Phase 4: 22/38 задач выполнено (58%)**
