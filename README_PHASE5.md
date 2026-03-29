# Aura Shell — Phase 5: Плагины и AuraScript — Промпты для Cursor AI

## Обзор

Phase 5 делает Aura Shell расширяемой платформой: плагины (.so), AOT-компилируемый язык AuraScript, маркетплейс `apkg`, система макросов. После этой фазы сторонние разработчики могут добавлять команды, виджеты, VFS-провайдеры, форматы архивов и темы.

## Порядок выполнения

```
STEP_50 → STEP_51 → STEP_52 → STEP_53 → STEP_54
Plugin    Plugin    AuraScript AuraScript Marketplace
Host &    API &     Lexer,     AOT        & Macros
Loader    Hooks     Parser,AST Codegen
```
