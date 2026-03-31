# Development Status

This file is the canonical "what works / what does not" snapshot for contributors.

## Scope of This Status

- Focus: native runtime behavior and active development tracks.
- Priority: practical contributor orientation over aspirational roadmap language.
- Update rule: when behavior materially changes, update this file in the same PR.

## Confirmed Working Areas

- Core assembly codebase organization and module separation are in place.
- Linux and Windows build-oriented source trees exist.
- File Manager code paths exist for panel model, list loading, navigation, and rendering integration.
- Win32 runtime bootstrapping and baseline drawing paths are implemented.
- The project has active test directories and diagnostics conventions.

## Confirmed Unstable or Incomplete Areas

- Windows Unicode filename rendering is not fully reliable yet.
- Some render-path experiments can regress into white-screen/crash behavior.
- Regression coverage for Win32/FM edge cases is not yet sufficient.
- Documentation was previously fragmented; this is now being consolidated.

## Known High-Risk Technical Areas

1. Win64 ABI call correctness (alignment, shadow space, volatile/non-volatile registers).
2. Encoding boundaries across VFS -> FM -> Win32 text output.
3. Truncation and display logic for long/non-ASCII filenames.
4. Error recovery behavior after failed rendering paths.

## Contributor Playbook

If you pick a bug:

1. Reproduce with a minimal path and concrete expected/actual behavior.
2. Add diagnostics close to data boundaries, not only at UI output.
3. Make a minimal fix and keep fallback behavior stable.
4. Add/update test or manual protocol in PR notes.
5. Update this status file if observable behavior changed.

## Detailed TODO

### Windows Text/Encoding

- Add runtime debug overlay for selected row:
  - rendered string length,
  - first bytes in hex,
  - first UTF-16 units in hex (where applicable).
- Validate bytes at three points:
  - VFS output buffer,
  - FM post-truncation buffer,
  - Win32 draw-call input.
- Keep one known-safe fallback path enabled while iterating on Unicode path.

### FM Behavior

- Add tests for `.` / `..` handling and root-parent behavior.
- Add tests for mixed hidden/system files and sort behavior.
- Verify dual-panel parity after each refactor.
- Tighten row metrics consistency (text baseline vs highlight geometry).

### Process and Tooling

- Standardize crash report template for Windows issues.
- Track "last known good commit" for runtime-critical tracks.
- Add quick regression script for FM open/navigate/enter/backspace flows.
