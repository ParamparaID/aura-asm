# Aura Shell

An experimental operating environment written in NASM assembly, combining shell workflows, GUI composition, and file management in one low-level codebase.

## Project Idea

Aura Shell explores a "single environment" model:

- **Shell engine** for command workflows.
- **GUI and compositor** for spatial, touch-first interaction.
- **File manager** with dual/single panel workflows.
- **Plugin and scripting foundations** for extensibility.

The project intentionally avoids libc/runtime dependencies in core paths and keeps platform interaction explicit through a HAL layer.

## Honest Status (Current Reality)

Aura Shell is **active but unstable** in several areas. This repository currently contains valuable working parts and valuable partial work, but it is not yet production-ready.

### What works in practice

- Linux and Windows assembly build paths exist.
- Core project structure is in place (`hal`, `core`, `shell`, `canvas`, `gui`, `fm`, `plugins`, `aurascript`).
- File manager UI and navigation are present and actively iterated.
- Win32 backend launches in some configurations and can render UI/text in baseline mode.
- Existing tests and diagnostics infrastructure are present and useful for targeted iteration.

### What is incomplete or unstable

- Windows text encoding/rendering path is still under investigation (mojibake and regressions during Unicode work).
- Some recent Windows FM iterations can regress into white-screen/crash states.
- Documentation and roadmap history became fragmented across multiple phase files and ad-hoc notes.
- Cross-platform feature parity is not complete.

For a contributor-oriented snapshot, see:

- [`docs/development-status.md`](docs/development-status.md)
- [`docs/roadmap.md`](docs/roadmap.md)
- [`REPORT_FOR_CLAUDE.md`](REPORT_FOR_CLAUDE.md)

## Documentation Index

- **Architecture:** [`docs/architecture.md`](docs/architecture.md)
- **UI principles:** [`docs/ui-philosophy.md`](docs/ui-philosophy.md)
- **Current status:** [`docs/development-status.md`](docs/development-status.md)
- **Roadmap and implementation tracks:** [`docs/roadmap.md`](docs/roadmap.md)
- **Contributing guide:** [`CONTRIBUTING.md`](CONTRIBUTING.md)
- **Security policy:** [`SECURITY.md`](SECURITY.md)
- **Code of conduct:** [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md)

## Repository Layout

```text
src/
  hal/            Platform abstraction (Linux syscall wrappers, Win32 wrappers)
  core/           Memory, events, threading, input and shared services
  shell/          Parsing, builtins, execution and REPL paths
  canvas/         Software rendering, text, image and effects primitives
  gui/            Window/compositor-facing UI and widgets
  fm/             File manager, VFS and operations
  plugins/        Plugin host and API
  aurascript/     Script language implementation scaffolding
docs/             Formal project documentation
tests/            Unit/integration tests and diagnostics
themes/           Theme assets
```

## Build and Run

### Linux (primary development path)

```bash
make
./aura-shell
```

### Windows (native path)

Windows-native binaries are currently built from assembled objects and linked with MSVC toolchain components. Ongoing FM/text stability work is tracked in the roadmap and status docs.

## Contribution Priorities

If you want to help immediately, the highest-value tracks are:

1. **Windows FM text/encoding stability** (clear regressions, high impact).
2. **Rendering-path hardening and ABI checks** (prevent crash regressions).
3. **VFS correctness and name handling** (hidden/unicode/path edge cases).
4. **Test coverage for Win32-specific behavior**.
5. **Documentation quality and traceable implementation status**.

Detailed, file-level TODOs live in:

- [`docs/development-status.md`](docs/development-status.md)
- [`docs/roadmap.md`](docs/roadmap.md)
- [`CONTRIBUTING.md`](CONTRIBUTING.md)

## Safety Note for Contributors

When touching Win32 assembly paths, preserve:

- Win64 calling convention (`rcx`, `rdx`, `r8`, `r9` + stack args),
- 16-byte stack alignment before each `call`,
- correct shadow space allocation,
- non-volatile register preservation.

Many observed runtime crashes in recent work were ABI-related rather than algorithmic.

## License

Aura Shell is licensed under [`AGPL-3.0`](LICENSE).
