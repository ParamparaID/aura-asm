# Aura Shell ✨

Next-generation operating environment in pure assembly with a touch-first interface.

![License](https://img.shields.io/badge/license-AGPL--3.0-blue)
![Language](https://img.shields.io/badge/language-Assembly-orange)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20Windows-lightgrey)
![Phase](https://img.shields.io/badge/phase-Phase%200%20--%20Foundation-yellow)

## What is Aura Shell?

Aura Shell is an ambitious operating environment that combines a shell, compositor, file manager, and plugin
system into one cohesive product. It is designed as a unified workspace where command-line workflows and modern
touch-oriented UI patterns live side by side.

Unlike most systems that rely on high-level runtimes, Aura Shell is built in 100% NASM assembly. There is no libc,
no language runtime, and no hidden abstraction layers between core code and the OS interface. This keeps the stack
lean, explicit, and performance-focused.

The project includes its own software rasterizer, a Wayland compositor path, and a modular core architecture that
supports resilient multi-threaded services. It is built to run close to the metal while still offering a modern user
experience.

Aura Shell targets developers, sysadmins, and systems enthusiasts who care about performance, control, and learning
from a transparent low-level codebase.

## Philosophy

**Touch-First, Mouse-Compatible.** Aura Shell starts from gesture ergonomics, thumb reach, and direct manipulation.
Mouse and keyboard are first-class inputs, but they complement the design rather than define it.

**Hub-and-Spoke Navigation.** A central Hub provides launch and context, while each module runs as its own focused
space. Movement between spaces is spatial and gesture-driven, not menu-heavy.

**Physics-Based Interactions.** Motion is intentional and readable: inertia, spring dynamics, and snap behavior make
UI feedback predictable and natural.

For the full design document, see [`docs/ui-philosophy.md`](docs/ui-philosophy.md).

## Architecture Overview

```text
┌─────────────────────────────────────────────────────┐
│                   Aura Shell Binary                 │
├──────────┬───────────┬──────────┬───────────────────┤
│  Shell   │   GUI     │  File    │   Plugin          │
│  Engine  │ Compositor│ Manager  │   Host            │
├──────────┴───────────┴──────────┴───────────────────┤
│                Core Services Layer                  │
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌──────────┐      │
│  │ Memory │ │ Thread │ │  IPC   │ │  Event   │      │
│  │ Alloc  │ │ Pool   │ │  Bus   │ │  Loop    │      │
│  └────────┘ └────────┘ └────────┘ └──────────┘      │
│  ┌────────────┐ ┌──────────────┐                    │
│  │ Gesture    │ │ Input        │                    │
│  │ Recognizer │ │ Abstraction  │                    │
│  └────────────┘ └──────────────┘                    │
├─────────────────────────────────────────────────────┤
│           HAL (Hardware Abstraction Layer)          │
│  ┌─────────────┐         ┌─────────────┐            │
│  │ Linux HAL   │         │ Windows HAL │            │
│  │ (syscall)   │         │ (Win32 API) │            │
│  └─────────────┘         └─────────────┘            │
└─────────────────────────────────────────────────────┘
```

- `Shell Engine` - Command parsing, execution, job control, and scripting integration.
- `GUI Compositor` - Rendering pipeline, window composition, themes, and gesture interaction.
- `File Manager` - Multi-mode navigation, file operations, VFS, and archive workflows.
- `Plugin Host` - ABI-based extension system for commands, UI widgets, VFS, and integrations.
- `Core Services` - Memory, threads, IPC, event loop, gesture recognition, and unified input.
- `HAL` - Platform-specific syscall/API wrappers isolated from module logic.

## Features

### 🚧 In Progress (Phase 0)

- HAL (Linux x86_64 syscall abstraction)
- Memory allocator (arena + slab)
- AuraCanvas foundations
- Wayland client bootstrap
- Minimal REPL

### 📋 Planned (Phase 1-2)

- Shell Engine with parser, execution, and job control
- GUI toolkit with touch-first widgets and layout engine
- Theme system with `.auratheme` support

### 🔮 Future (Phase 3+)

- Full Wayland compositor and window manager
- Integrated File Manager (AuraFM)
- Plugin Host + marketplace workflow
- AuraScript AOT pipeline
- Windows and ARM support

## Quick Start

```bash
# Prerequisites (Linux x86_64 + Wayland session)
# - nasm
# - ld (binutils)
# - make

git clone https://github.com/OWNER/aura-shell.git
cd aura-shell

# Build
make

# Run
./aura-shell
```

## Project Structure

```text
aura-shell/
├── src/        # Assembly source code (hal, core, shell, canvas, gui, fm, plugins, aurascript)
├── docs/       # Public architecture and design documents
├── themes/     # Built-in .auratheme files
├── plugins/    # Official plugin projects
└── tests/      # Unit, integration, and UI test suites
```

## Roadmap

| Phase | Focus | Status |
|---|---|---|
| Phase 0 | Foundation: HAL, memory, event loop, canvas base, Wayland client, REPL | 🚧 In Progress |
| Phase 1 | Shell Engine: parser, built-ins, pipelines, history, job control | 📋 Planned |
| Phase 2 | Rasterizer + widgets: gestures, physics, themes, adaptive layout | 📋 Planned |
| Phase 3 | Compositor: windows, workspaces, Hub-and-Spoke spaces, touch routing | 📋 Planned |
| Phase 4 | File Manager: dual/single pane, VFS, archives, SSH/SFTP | 📋 Planned |
| Phase 5 | Extensibility: Plugin Host, AuraScript AOT, package tooling | 📋 Planned |
| Phase 6 | Cross-platform: Windows HAL and ARM support | 📋 Planned |

## Contributing

We welcome contributions of all kinds - from fixing typos to implementing entire subsystems. See
[`CONTRIBUTING.md`](CONTRIBUTING.md) to get started.

## Community

- Use [GitHub Discussions](https://github.com/OWNER/aura-shell/discussions) for questions, architecture ideas, and
  design proposals.
- Use the [Issue Tracker](https://github.com/OWNER/aura-shell/issues) for bug reports and feature requests.
- Aura Shell is in an early stage, which makes this the perfect time to influence architecture decisions.

## License

Aura Shell is licensed under [`AGPL-3.0`](LICENSE). You can use, study, and modify the project freely. Commercial
distribution and licensing scenarios may require a separate commercial agreement.

## Acknowledgments

- Midnight Commander
- Sway and Hyprland
- Far Manager
- iPadOS gesture design
- TempleOS (for the bare-metal spirit)

Built with 💜 and `mov rax, 1`.
