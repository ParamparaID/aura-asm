# Contributing to Aura Shell

Thank you for helping move Aura Shell forward. The project is promising and real, but still unstable in several areas. This guide is optimized for practical contribution in the current state.

## Start Here

Before opening a PR, read these files:

- [`README.md`](README.md)
- [`docs/development-status.md`](docs/development-status.md)
- [`docs/roadmap.md`](docs/roadmap.md)
- [`docs/architecture.md`](docs/architecture.md)

## Current Priority Tracks

If you want high-impact work, choose one of these:

1. **Windows FM stability and Unicode rendering**
2. **Win64 ABI correctness hardening**
3. **VFS correctness and path/name edge cases**
4. **Automated tests for platform-specific regressions**
5. **Documentation and onboarding quality**

## Ways to Contribute

- Report reproducible bugs (prefer one bug per issue).
- Propose implementation-focused feature requests.
- Submit assembly, tests, tooling, or docs improvements.
- Improve diagnostics and reproducible debug workflows.

## Development Environment

### Linux path

- `nasm`
- `ld` (binutils)
- `make`
- `git`

Run:

```bash
make
make test
```

### Windows path

Windows work commonly uses NASM + MSVC linker toolchain components. If your change is Win32/Win64-specific, include:

- exact OS version,
- toolchain versions,
- full reproduction steps,
- crash offset or trace, if available.

## Assembly Rules That Matter Most

- Follow NASM Intel syntax.
- Document non-trivial routines (params, returns, clobbers).
- Preserve non-volatile registers correctly.
- Keep 16-byte stack alignment before every call.
- Reserve required Win64 shadow space for Windows ABI calls.
- Keep HAL/platform wrappers separated from module logic.

For Windows calling-convention-sensitive files (`src/hal/win_x86_64/*`, parts of `src/fm/*`), correctness beats micro-optimizations.

## Testing Expectations

- Add or update tests when behavior changes.
- Prefer minimal, deterministic tests over broad flaky coverage.
- For FM/VFS fixes, include fixture-driven unit coverage if possible.
- For Windows bug fixes, include a short manual test protocol in the PR.

## Pull Request Checklist

- Scope is focused and reviewable.
- Commit messages are clear and meaningful.
- Documentation is updated for behavior/contract changes.
- New TODOs are added where work is intentionally deferred.
- Test evidence is included (automated and/or manual steps).

Use the PR template in `.github/PULL_REQUEST_TEMPLATE.md`.

## Detailed TODOs for Contributors

### TODO: Windows text rendering stabilization

- Add a runtime diagnostic mode that prints selected entry length and first bytes/UTF-16 units.
- Compare bytes at VFS output, FM truncation buffer, and draw call boundary.
- Build a safe, isolated UTF-8 -> UTF-16 path with strict ABI checks.
- Add regression tests for non-ASCII filenames.

### TODO: FM resilience

- Add guardrails for panel state transitions.
- Expand parent-directory/root-path test coverage.
- Verify behavior on deep paths and very long filenames.

### TODO: Docs and process

- Keep `docs/development-status.md` synchronized with real behavior.
- Keep `docs/roadmap.md` updated as tracks are completed or split.
- Convert ad-hoc debugging notes into stable docs or issue records.

## Communication

- Use issue discussions for implementation detail and trade-offs.
- Keep reports factual and reproducible.
- Mention assumptions explicitly.

## Code of Conduct

By participating, you agree to [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md).
