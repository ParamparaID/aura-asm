# Aura Shell Architecture

This document separates **design intent** from **currently implemented reality**.

For interaction principles, see [`docs/ui-philosophy.md`](ui-philosophy.md).  
For day-to-day implementation status, see [`docs/development-status.md`](development-status.md).

## Architecture Goal

Aura Shell is designed as a modular environment in NASM assembly:

- shell workflows,
- GUI/compositor paths,
- file manager and VFS,
- extension points (plugins/scripts),
- platform abstraction through HAL.

## System Shape (Target)

```text
┌───────────────────────────────────────────────────────┐
│                   Aura Shell Binary                   │
├──────────┬───────────┬──────────┬────────────────────┤
│  Shell   │   GUI     │  File    │   Plugin           │
│  Engine  │ Compositor│ Manager  │   Host             │
├──────────┴───────────┴──────────┴────────────────────┤
│                Core Services Layer                   │
│     Memory / Threads / Events / Input / IPC          │
├───────────────────────────────────────────────────────┤
│         HAL (Linux syscalls, Win32 wrappers)         │
└───────────────────────────────────────────────────────┘
```

## What Is Implemented Today

### HAL

- Linux syscall wrappers exist.
- Windows Win32 API wrappers exist and are actively extended.
- Platform-specific logic is mostly isolated in `src/hal/`.

### File Manager

- FM structures, panel model, and navigation paths are implemented.
- VFS directory enumeration and sorting paths exist.
- Ongoing Windows-specific text/path/name correctness fixes are active.

### Rendering/UI

- Software rendering primitives and text overlay paths exist.
- Win32 drawing backend is functional in stable baseline mode.
- Unicode text rendering remains an active risk area on Windows.

## Known Architectural Risks

- ABI fragility in Win64 call sites (alignment/shadow-space/register preservation).
- Divergence between design-level docs and implementation-level status.
- Limited regression coverage for platform-specific assembly behavior.

## Architectural Rules

1. Keep OS-specific operations inside HAL or HAL-adjacent wrappers.
2. Keep call boundaries explicit and ABI-safe.
3. Prefer small routines with clear register contracts.
4. Isolate risky changes behind diagnostics and reversible steps.
5. Update status docs with each meaningful behavior change.

## TODO (Architecture)

- Define canonical module ownership boundaries in docs with concrete file maps.
- Document cross-module contracts (FM <-> VFS, GUI <-> HAL, shell <-> input).
- Add ABI-check checklist to code review process.
- Add architecture-level regression matrix by platform and subsystem.
