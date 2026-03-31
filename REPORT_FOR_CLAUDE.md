# Aura Shell Handoff Report (for Claude)

Use this report as a direct handoff baseline for next-stage refinement.

## 1) What the project is

Aura Shell is an assembly-first operating environment project that combines:

- shell workflows,
- GUI/compositor paths,
- file manager and VFS,
- extensibility concepts.

The core engineering intent is explicit low-level control with HAL-based platform separation.

## 2) Honest current state

### What is real and usable

- The repository has substantial assembly implementation across core subsystems.
- Native Windows path and FM-related code are implemented and actively debugged.
- Baseline rendering/input paths can run in stable configurations.
- Contributor-facing docs now include status and roadmap formalization.

### What is not solved yet

- Windows Unicode filename rendering remains unresolved in a robust way.
- Some recent changes can regress to crash/white-screen behavior.
- Test coverage is not yet strong enough for rapid safe iteration in this area.

## 3) Critical technical bottleneck

The dominant unresolved problem is encoding/render consistency across:

1. VFS name conversion/output,
2. FM truncation/intermediate buffers,
3. Win32 drawing APIs (`TextOutA` vs `TextOutW`) and ABI-safe invocation.

## 4) Why progress was difficult

- Multiple failures looked like encoding bugs but were partially ABI violations.
- Stability and Unicode correctness often conflicted during fast iteration.
- Missing diagnostics at data boundaries made root-cause isolation slower.

## 5) Recommended next implementation strategy

1. Keep last known stable rendering fallback active.
2. Add lightweight runtime diagnostics for selected FM row:
   - string length,
   - first bytes in hex,
   - UTF-16 units (when converted).
3. Compare diagnostics at VFS output, FM output, draw-call input.
4. Only then re-enable strict Unicode path under feature flag.
5. Add regression fixture with multilingual names and expected render behavior.

## 6) Documentation restructuring completed

The following files now act as formal project docs:

- `README.md`
- `CONTRIBUTING.md`
- `SECURITY.md`
- `docs/architecture.md`
- `docs/ui-philosophy.md`
- `docs/development-status.md`
- `docs/roadmap.md`

The old ad-hoc technical brief can be removed after confirming maintainers accept the new structure.

## 7) Suggested questions for Claude refinement

- Propose a minimal diagnostic protocol that isolates encoding vs ABI faults with high confidence.
- Review Win64 call boundaries for likely hidden ABI violations.
- Suggest a conservative Unicode rollout plan with rollback checkpoints.
- Propose a compact automated test strategy for FM rendering regressions on Windows.
