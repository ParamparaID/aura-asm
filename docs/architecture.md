# Aura Shell Architecture

Aura Shell is a modular operating environment implemented in NASM assembly. It combines shell workflows, graphics,
file operations, and extensibility in a single binary while separating responsibilities through thread isolation and a
platform abstraction layer.

For interaction and product design principles, see [`docs/ui-philosophy.md`](ui-philosophy.md).

## System Overview

```text
┌───────────────────────────────────────────────────────┐
│                   Aura Shell Binary                   │
├──────────┬───────────┬──────────┬────────────────────┤
│  Shell   │   GUI     │  File    │   Plugin           │
│  Engine  │ Compositor│ Manager  │   Host             │
├──────────┴───────────┴──────────┴────────────────────┤
│                Core Services Layer                   │
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌──────────┐      │
│  │ Memory │ │ Thread │ │  IPC   │ │  Event   │      │
│  │ Alloc  │ │ Pool   │ │ Bus    │ │  Loop    │      │
│  └────────┘ └────────┘ └────────┘ └──────────┘      │
│  ┌────────────┐ ┌──────────────┐                     │
│  │ Gesture    │ │ Input        │                     │
│  │ Recognizer │ │ Abstraction  │                     │
│  └────────────┘ └──────────────┘                     │
├───────────────────────────────────────────────────────┤
│           HAL (Hardware Abstraction Layer)            │
│  ┌─────────────┐         ┌─────────────┐             │
│  │ Linux HAL   │         │ Windows HAL │             │
│  │ (syscall)   │         │ (Win32 API) │             │
│  └─────────────┘         └─────────────┘             │
└───────────────────────────────────────────────────────┘
```

## Core Services

### Memory Allocator

- Custom arena + slab allocator model
- No dependency on libc `malloc`
- Per-thread memory strategy to reduce lock contention

### Thread Pool

- Thread lifecycle management per module workload
- Health monitoring and restart hooks for faulted workers
- Linux and Windows thread primitives hidden behind HAL

### IPC Bus

- Internal message transport between modules
- Lock-free queue model for predictable throughput
- Supports event fan-out to service consumers

### Event Loop

- Unified loop for input, timers, IPC, and asynchronous I/O
- Linux implementation based on `epoll`
- Windows implementation mapped to native async primitives

### Gesture Recognizer

- Converts raw touch/mouse streams into semantic gestures
- Handles swipe, pinch, long-press, and multi-finger patterns
- Enables module-level context gestures on top of global actions

### Input Abstraction

- Normalizes keyboard, mouse, touch, and trackpad input
- Provides a coherent event model across platforms and modules
- Decouples module logic from hardware/API-specific event formats

## Module Descriptions

### Shell Engine

- Command parsing and execution pipeline
- Built-in command implementation and job control
- Foundation for AuraScript integration and command palette workflows

### GUI Compositor

- Software rasterization pipeline and scene composition
- Window management, spatial transitions, and theme application
- Touch-first interaction model with physics-aware animation

### File Manager

- Dual-pane and single-pane workflows
- VFS-backed operations, archive support, and remote access extensions
- Integrated navigation patterns aligned with Hub-and-Spoke UX

### Plugin Host

- Loads extension modules through a stable ABI contract
- Exposes hook categories for commands, widgets, VFS, and events
- Supports future marketplace and package tooling flows

## HAL Layer

The Hardware Abstraction Layer isolates all platform-specific operations:

- Linux path: direct syscall wrappers
- Windows path: native Win32 API wrappers

Modules depend on HAL interfaces instead of invoking platform APIs directly. This keeps high-level module code
portable and easier to test against consistent contracts.

## Threading Model

Aura Shell uses a **monolithic binary with thread isolation**:

- one deployable artifact
- dedicated threads for major modules and subsystems
- fault containment at the module-thread level

This model balances simplicity of deployment with runtime isolation and recovery behavior.

## Crash Recovery

Aura Shell includes defensive fault handling at module boundaries:

- each module tracks failure frequency over time
- repeated failures beyond threshold can trigger temporary module disablement
- crash events are logged for post-mortem analysis
- recoverable modules can be restarted without taking down the full environment

This allows the system to preserve session continuity and reduce full-process termination risk.

## Architectural Principles

1. **No hidden runtime**: no libc dependency requirement in core architecture.
2. **Platform abstraction first**: OS-specific code remains in HAL.
3. **Composable modules**: shell, GUI, file, and plugins share service contracts.
4. **Low-level performance**: direct control of memory and syscalls.
5. **Resilience over fragility**: thread isolation and restart strategy over all-or-nothing failure.
