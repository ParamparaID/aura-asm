# Aura Shell — Phase 1: TODO

> Продолжение TODO из Phase 0 (37/37 ✅).
> `[x]` = выполнено, `[ ]` = ожидает.

---

## STEP 10: Токенизатор и лексер
- [x] `src/shell/lexer.asm` — токенизация входной строки
- [x] Типы токенов: WORD, PIPE, REDIRECT_IN, REDIRECT_OUT, REDIRECT_APPEND, AND, OR, SEMICOLON, AMPERSAND, LPAREN, RPAREN, LBRACE, RBRACE, VARIABLE, ASSIGNMENT, NEWLINE, EOF, ERROR
- [x] Обработка кавычек: `"hello world"` как один токен, `'literal $var'` без раскрытия
- [x] Обработка escape: `\ ` (пробел), `\"`, `\\`, `\n`
- [x] Переменные: `$VAR`, `${VAR}` помечаются как `TOK_VARIABLE` (без раскрытия на этапе лексера)
- [x] `tests/unit/test_lexer.asm` — тесты типов токенов и сложных команд
- [x] Все тесты проходят

## STEP 11: Парсер и AST
- [x] `src/shell/parser.asm` — построение AST из потока токенов
- [x] Узлы AST: CommandNode, PipelineNode, ListNode (&&, ||, ;)
- [x] CommandNode: имя команды + массив аргументов + редиректы + assignments + background
- [x] PipelineNode: цепочка CommandNode через pipe
- [x] ListNode: последовательность pipeline с операторами (&&, ||, ;)
- [x] Аллокация AST через arena (быстрый сброс после выполнения)
- [x] `tests/unit/test_parser.asm` — тесты парсинга сложных команд и ошибок
- [x] Все тесты проходят

## STEP 12: Выполнение команд (fork/exec)
- [x] `src/hal/linux_x86_64/process.asm` — обёртки fork, execve, waitpid, dup2, pipe, access, getcwd, chdir, getenv_raw
- [x] `src/shell/executor.asm` — обход AST и выполнение
- [x] Поиск команды в PATH (разбор `$PATH`, проверка `access(X_OK)`)
- [x] Выполнение внешних программ: fork → execve
- [x] Ожидание завершения: waitpid, получение exit code
- [x] Передача переменных окружения в execve
- [x] `tests/unit/test_executor.asm` — тесты: /bin/echo, /bin/ls, несуществующая команда, PATH, cd, exit code
- [x] Все тесты проходят

## STEP 13: Пайпы и редиректы
- [x] `src/shell/pipeline.asm` — выполнение пайплайнов (цепочка fork + pipe + dup2)
- [x] Редирект ввода: `< file`
- [x] Редирект вывода: `> file` (создание/перезапись)
- [x] Редирект добавления: `>> file`
- [x] Комбинация: `cmd < in.txt | cmd2 > out.txt`
- [x] Условное выполнение: `&&` (если предыдущий exit 0), `||` (если exit != 0)
- [x] `;` — последовательное выполнение
- [x] `tests/unit/test_pipeline.asm` — тесты пайплайнов и редиректов
- [x] Все тесты проходят

## STEP 14: Встроенные команды, переменные, алиасы, история
- [x] `src/shell/builtins.asm` — встроенные команды (MVP: `echo`, `cd`, `exit`, `true`, `false`, `export`, `set`, `unset`, `alias`, `unalias`, `history`, `help`)
- [x] `src/shell/variables.asm` — хранилище переменных, `vars_set/get/unset/export/build_envp/expand`
- [x] `src/shell/alias.asm` — хранилище алиасов, `alias_set/get/unset/list/expand`
- [x] `src/shell/history.asm` — кольцевой буфер истории, up/down, search (MVP), save/load (stub)
- [ ] Автодополнение: Tab → дополнение команд и путей
- [ ] Обновление REPL для полной интеграции всех компонентов
- [x] `tests/unit/test_builtins.asm` — тесты встроенных команд и хранилищ
- [x] Все тесты проходят

## STEP 15: Job Control
- [ ] `src/shell/jobs.asm` — таблица активных задач (job table)
- [ ] Фоновый запуск: `command &`
- [ ] Команды: `jobs`, `fg %N`, `bg %N`, `wait`
- [ ] Обработка сигналов: SIGCHLD (уведомление о завершении), SIGTSTP (Ctrl+Z → suspend)
- [ ] `src/hal/linux_x86_64/signals.asm` — sigaction, signal handling
- [ ] Уведомление пользователя о завершении фоновых задач
- [ ] `tests/unit/test_jobs.asm` — тесты job control
- [ ] Финальный интеграционный тест: сложный pipeline с job control
- [ ] Все тесты проходят

---

**Прогресс Phase 1: 34/35 задач выполнено (97%)**
