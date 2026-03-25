# Aura Shell — Phase 5: TODO

> Phase 0–4: ✅

---

## STEP 50: Plugin Host и загрузчик
- [x] `src/plugins/host.asm` — загрузка .so через dlopen-эквивалент (open + mmap + parse ELF + relocate)
- [x] `src/plugins/host.asm` — альтернативный путь: syscall `open` + `mmap` ELF .so, ручной парсинг ELF (Program Headers, Dynamic section, символы, relocations)
- [x] `src/plugins/host.asm` — API: `plugin_load(path)`, `plugin_unload(handle)`, `plugin_get_symbol(handle, name)`
- [x] `src/plugins/host.asm` — lifecycle: init → register hooks → running → shutdown
- [x] `src/plugins/host.asm` — sandboxing MVP: проверка exported символов, crash isolation (per-thread)
- [x] `src/plugins/manifest.asm` — парсер plugin.toml / plugin.ini (name, version, author, hooks, dependencies)
- [x] `tests/unit/test_plugin_host.asm` — загрузка тестового .so, вызов exported функции
- [x] `tests/data/test_plugin.asm` + Makefile для сборки .so
- [x] Все тесты проходят

## STEP 51: Plugin API и хуки
- [ ] `src/plugins/api.asm` — ABI-контракт: таблица функций host→plugin и plugin→host
- [ ] Host→Plugin callbacks: `aura_plugin_init`, `aura_plugin_shutdown`, `aura_plugin_get_info`
- [ ] Plugin→Host API: `aura_register_command(name, callback)`, `aura_register_widget(type_name, vtable)`, `aura_register_vfs(scheme, provider)`, `aura_register_viewer_format(ext, handler)`, `aura_register_archive_format(ext, handler)`, `aura_register_theme(name, theme_data)`
- [ ] Plugin→Host API: `aura_get_theme()`, `aura_get_canvas()`, `aura_log(level, msg)`, `aura_alloc(size)`, `aura_free(ptr)`
- [ ] Категории хуков: commands, widgets, VFS, viewer, archive, themes, gestures, Hub widgets, events
- [ ] Версионирование API: `AURA_API_VERSION`, совместимость проверяется при загрузке
- [ ] Интеграция: builtins ищет зарегистрированные plugin-команды, VFS ищет plugin-провайдеры
- [ ] `tests/unit/test_plugin_api.asm` — plugin регистрирует команду, executor вызывает её
- [ ] Все тесты проходят

## STEP 52: AuraScript — лексер, парсер, AST
- [ ] `src/aurascript/lexer.asm` — токенизация AuraScript: keywords (fn, let, mut, if, else, for, while, match, return, import), literals (int, float, string, bool), operators, delimiters
- [ ] `src/aurascript/parser.asm` — recursive descent парсер → AST
- [ ] AST nodes: FnDecl, LetStmt, IfExpr, ForStmt, WhileStmt, MatchExpr, CallExpr, BinaryExpr, UnaryExpr, AssignExpr, BlockExpr, ReturnStmt, ImportStmt, StringLiteral, IntLiteral, FloatLiteral, BoolLiteral, Identifier, ArrayLiteral, MapLiteral, IndexExpr, FieldExpr
- [ ] Типы: int64, float64, string, bool, array, map
- [ ] `tests/unit/test_aurascript_parser.asm` — парсинг функций, if/else, for, выражений
- [ ] Все тесты проходят

## STEP 53: AuraScript — AOT кодогенератор
- [ ] `src/aurascript/codegen_x86_64.asm` — обход AST → генерация нативного x86_64 машинного кода в буфер
- [ ] Кодогенерация: function prologue/epilogue, local variables (stack), arithmetic (add/sub/mul/div/mod), comparisons, jumps (if/else → cmp+jcc), loops (for/while → jmp), function calls (System V ABI)
- [ ] String operations: concat, length, compare (через runtime helpers)
- [ ] Array/Map operations: через runtime helpers (alloc, get, set, push)
- [ ] Runtime library: `src/aurascript/runtime.asm` — GC-free helpers (string alloc/concat, array ops, map ops, print, type conversions)
- [ ] `src/aurascript/cache.asm` — кэш скомпилированного кода: hash(source) → mmap'd executable buffer. Перекомпиляция при изменении.
- [ ] JIT-режим для REPL: компиляция одного выражения → mmap(PROT_EXEC) → call → print result
- [ ] Интеграция с shell: команда `aura run script.aura`, `aura eval "expr"`, `.aura` файлы executable
- [ ] `tests/unit/test_aurascript_codegen.asm` — компиляция+выполнение: арифметика, if/else, функции, строки
- [ ] Все тесты проходят

## STEP 54: Маркетплейс и макросы
- [ ] `src/plugins/registry.asm` — HTTPS клиент MVP (TCP + TLS handshake или делегирование в curl)
- [ ] `src/plugins/registry.asm` — CLI: `apkg search <query>`, `apkg install <name>`, `apkg update`, `apkg remove <name>`, `apkg list`
- [ ] `src/plugins/registry.asm` — формат пакета: tar.gz с plugin.toml + .so + assets
- [ ] `src/plugins/registry.asm` — верификация: SHA-256 hash check скачанного пакета
- [ ] `src/plugins/registry.asm` — локальный кэш в `~/.aura/plugins/`
- [ ] `src/shell/macros.asm` — запись действий пользователя (keystroke sequence) в макрос
- [ ] `src/shell/macros.asm` — воспроизведение макроса (replay keystrokes)
- [ ] `src/shell/macros.asm` — сохранение/загрузка макросов из файла
- [ ] `tests/unit/test_marketplace.asm` — mock registry, install/remove flow
- [ ] `tests/unit/test_macros.asm` — запись и воспроизведение макроса
- [ ] Все тесты проходят

---

**Прогресс Phase 5: 9/40 задач (23%)**
