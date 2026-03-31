# Aura Shell UI Philosophy

This document describes intended UX direction. Not all principles are fully implemented yet.

For implementation status, see [`docs/development-status.md`](development-status.md).

## Product Direction

Aura Shell aims to merge:

- terminal productivity,
- file-centric workflows,
- modern direct-manipulation UI patterns.

The long-term model is touch-first but keyboard/mouse-complete.

## Core Interaction Principles

1. **Directness:** interact with content, not deep modal stacks.
2. **Parity:** each primary workflow has keyboard fallback.
3. **Consistency:** navigation and selection rules should feel the same across modules.
4. **Legibility:** text and focus states must remain stable under resizing and long names.
5. **Performance:** smooth interaction without hidden heavyweight runtime dependencies.

## Current Practical Priority

In the current phase, practical FM usability and text correctness are higher priority than advanced motion/gesture polish.

That means:

- stable panel navigation,
- correct directory transitions,
- robust text rendering for mixed character sets,
- predictable highlight/focus behavior.

## Future UX Concepts (Planned)

Planned and partially prototyped concepts include:

- Hub-and-spoke module navigation,
- gesture-driven context actions,
- adaptive layouts for desktop/tablet/mobile classes,
- richer animation and spatial transitions.

These remain valid directionally but should be treated as roadmap, not guaranteed implemented behavior.

## Accessibility Direction

- Keep core workflows keyboard-operable.
- Preserve color contrast in themes.
- Keep selection/focus states explicit.
- Avoid relying on motion alone to communicate state.

## TODO (UI)

- Define explicit text rendering acceptance criteria (including Unicode and truncation rules).
- Define FM interaction contract (keys, panel focus, entry actions) in one concise spec.
- Add visual regression fixtures for FM row rendering and highlight geometry.
- Document user-visible differences between stable and experimental rendering paths.
