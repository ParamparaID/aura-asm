# Aura Shell — Phase 0: REPORT

> Этот файл дополняется после каждого STEP.
> Отправляйте его на ревью после каждого шага.

---

<!-- 
После каждого STEP AI должен добавить секцию по шаблону:

## STEP XX: [Название] — [Дата]

### Что сделано
- Список созданных/изменённых файлов

### Результаты тестов
- Какие тесты прошли / не прошли

### Проблемы и решения
- Описание проблем, если были, и как решены

### Метрики
- Размер бинарника
- Количество строк asm-кода

### Статус
✅ Завершён / ⚠️ Частично / ❌ Заблокирован

-->

## STEP 01: HAL — Linux x86_64 — 2026-03-19

### Что сделано
- Создан `src/hal/linux_x86_64/defs.inc` с syscall-константами, флагами `open/mmap/epoll/clock/clone` и `STDIN/STDOUT/STDERR`.
- Создан `src/hal/linux_x86_64/syscall.asm` с макросом `syscall_6` и обёртками `hal_write`, `hal_read`, `hal_open`, `hal_close`, `hal_mmap`, `hal_munmap`, `hal_exit`, `hal_clock_gettime`.
- Создан `src/hal/linux_x86_64/errno.asm` с `hal_is_error`, `hal_errno` и errno-константами.
- Создан `tests/unit/test_syscall.asm` (проверки `write`, `clock_gettime`, `mmap/munmap`, read/write в отображённую память).
- Добавлен `Makefile` с целями `all`, `test`, `clean` (nasm + ld, без libc).
- Обновлён чеклист `TODO.md` по STEP 01.

### Результаты тестов
- `test_syscall`: PASSED (`make clean && make test`, вывод: `Hello Aura`, `ALL TESTS PASSED`).

### Проблемы и решения
- Проблема: в Windows PATH отсутствует `make`, поэтому запуск из PowerShell невозможен напрямую.
- Решение: установка toolchain в WSL (`nasm`, `binutils`, `make`) и запуск сборки/тестов в Linux-окружении.

### Метрики
- Размер бинарника `test_syscall`: 11912 байт.
- Строки кода (создано в STEP 01): 380 (`.asm` + `.inc`).

### Статус
✅ Завершён
