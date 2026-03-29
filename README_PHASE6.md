# Aura Shell — Phase 6: Windows и ARM — Промпты для Cursor AI

## Обзор

Phase 6 — финальная фаза проекта. Делает Aura Shell кроссплатформенным: порт на Windows x86_64 (Win32 API, shell replacement) и Linux ARM64 (AArch64 syscalls, NEON SIMD). После этой фазы Aura Shell работает на 3 платформах.

## Порядок выполнения

```
STEP_60 → STEP_61 → STEP_62 → STEP_63 → STEP_64
Windows    Windows    ARM64      ARM64     CI/CD &
HAL &      Compositor HAL &      Canvas    Final
Win32 API  & Shell    Syscalls   & NEON    Polish
```

## Ключевой принцип: HAL изоляция

Вся платформозависимость изолирована в `src/hal/`. Модули выше HAL (shell, canvas, gui, fm, plugins, aurascript) не знают о платформе — они вызывают `hal_*` функции. Задача Phase 6: реализовать HAL для Windows и ARM64, а также платформо-специфичные оптимизации (NEON вместо SSE2, Win32 вместо Wayland).
