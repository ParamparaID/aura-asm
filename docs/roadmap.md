# Roadmap

This roadmap is organized by implementation tracks, not marketing phases.

## Track A: Runtime Stability

### Goal

Keep native builds predictable and crash-resistant while active development continues.

### TODO

- Add platform-specific smoke test matrix (Linux/Windows).
- Maintain an explicit "stable fallback path" for risky rendering code.
- Add routine ABI audit checklist to PR review.
- Document rollback procedure for unstable experiments.

## Track B: File Manager and VFS Correctness

### Goal

Make FM behavior deterministic and trustworthy for real directories.

### TODO

- Lock down path normalization rules across platforms.
- Validate entry metadata and type classification edge cases.
- Add tests for very long names and non-ASCII names.
- Add tests for navigation transitions (`Enter`, parent, root guardrails).

## Track C: Windows Text Rendering

### Goal

Render mixed-language filenames correctly without regressions.

### TODO

- Instrument VFS -> FM -> draw pipeline with opt-in diagnostics.
- Define exact acceptance criteria for encoding behavior.
- Keep `TextOutA` baseline stable while validating `TextOutW` path.
- Add reproducible test fixture with representative multilingual names.

## Track D: Developer Experience

### Goal

Reduce contributor ramp-up time and prevent accidental regressions.

### TODO

- Keep docs synchronized with code reality.
- Improve bug templates with required reproduction fields.
- Add "first issue" labels for isolated, low-risk tasks.
- Add architecture contract notes where register/ABI assumptions are implicit.

## Track E: Long-Term Product Features

### Goal

Continue toward the full Aura Shell vision once stability foundations are solid.

### TODO

- Continue shell workflow improvements and command ergonomics.
- Expand GUI/compositor capabilities incrementally.
- Grow plugin and scripting contracts with compatibility guarantees.
- Revisit touch-first advanced interactions after FM text stability work.
