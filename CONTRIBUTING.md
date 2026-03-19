# Contributing to Aura Shell

## Welcome

Thank you for your interest in Aura Shell.

The project is still in an early phase, and that is exactly why contributions matter so much right now. If you join
at this stage, your ideas and code can directly shape architecture, module boundaries, and long-term developer
experience.

## Ways to Contribute

- 🐛 **Report bugs** - Open a bug report in [GitHub Issues](https://github.com/OWNER/aura-shell/issues).
- 💡 **Suggest features** - Start a discussion in
  [GitHub Discussions](https://github.com/OWNER/aura-shell/discussions).
- 📝 **Improve documentation** - Update `docs/`, `README.md`, or code comments.
- 🧪 **Write tests** - Add test coverage in `tests/unit/` and `tests/integration/`.
- 🔧 **Write code** - Implement asm modules, improve existing features, or fix defects.
- 🎨 **Design themes** - Create `.auratheme` files for the visual system.
- 🔌 **Create plugins** - Plugin development opens after Phase 5 milestones.

## Development Setup

### System requirements

- Linux x86_64
- Wayland compositor (for example: Sway, GNOME, KDE)

### Tooling

- `nasm >= 2.15`
- `binutils` (`ld`)
- `make`
- `git`

Optional but strongly recommended:

- `gdb` for debugging
- `strace` for syscall tracing
- `weston` as a reference/test Wayland compositor

### Setup steps

```bash
git clone https://github.com/<your-username>/aura-shell.git
cd aura-shell
make
make test
```

## Code Style Guide

- Use NASM syntax (Intel style).
- Start every file with a header comment including file name, purpose, author, and date.
- Mark all public functions with `global` and include parameter/return documentation.
- Use snake_case naming: `module_function_name`.
  - Examples: `canvas_fill_rect`, `hal_write`, `ring_push`.
- Document register usage before each function.
- Keep sections cleanly separated:
  - `.text` for executable code
  - `.data` for initialized data
  - `.rodata` for constants
  - `.bss` for uninitialized data
- Use 4 spaces for instruction indentation (no tabs). Labels should have no indentation.
- Keep line length at or below 100 characters.
- Write comments in English.

Example of a well-documented function:

```nasm
; canvas_fill_rect - Fill a rectangle with a solid color
;
; Parameters:
;   rdi - pointer to Canvas struct
;   esi - x coordinate (top-left)
;   edx - y coordinate (top-left)
;   ecx - width
;   r8d - height
;   r9d - color (ARGB32)
;
; Returns:
;   None
;
; Clobbers:
;   rax, rcx, rdx, r10, r11
global canvas_fill_rect
canvas_fill_rect:
    push rbp
    mov rbp, rsp
    ; ... implementation ...
    pop rbp
    ret
```

## Commit Messages

Use Conventional Commits:

```text
type(scope): short description

Longer description if needed.
```

### Types

`feat`, `fix`, `docs`, `test`, `refactor`, `style`, `build`

### Scopes

`hal`, `core`, `shell`, `canvas`, `gui`, `fm`, `plugins`, `aurascript`

### Examples

- `feat(hal): add clock_gettime syscall wrapper`
- `fix(canvas): clipping overflow in fill_rect`
- `test(core): add stress test for slab allocator`
- `docs: update roadmap in README`

## Pull Request Process

1. Fork the repository.
2. Create a feature branch from `main`: `git checkout -b feat/my-feature`.
3. Write code and tests.
4. Ensure `make test` passes.
5. Commit with a valid Conventional Commit message.
6. Open a PR and explain what changed, why it changed, and how to test it.
7. A maintainer reviews the PR.
8. After approval, the PR is squash-merged into `main`.

## Architecture Decision Records

Major architecture decisions are discussed in GitHub Discussions under the **Architecture** category before
implementation. This includes decisions like introducing new modules, changing ABI contracts, or adding new syscall
strategies.

## Testing

- Every new `.asm` module should include corresponding tests.
- Unit test naming convention: `tests/unit/test_<module>.asm`.
- Run `make test` before opening a PR.
- GUI changes should include screenshot-style rendering tests (buffer render + reference comparison) when applicable.

## Code of Conduct

Please read [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) before contributing.
