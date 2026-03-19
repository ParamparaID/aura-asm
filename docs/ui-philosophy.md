# Aura Shell UI Philosophy

Aura Shell is designed as a touch-first operating environment that remains fully productive with mouse and keyboard.
This document describes the public design principles that guide interaction, layout, motion, and accessibility.

For system-level architecture context, see [`docs/architecture.md`](architecture.md).

## Touch-First Principles

Aura Shell treats touch as the primary interaction model, not an afterthought. Core UI decisions are driven by:

- **Direct manipulation**: users should act on content directly through gestures.
- **Thumb reachability**: primary actions belong in ergonomic zones, especially lower screen regions.
- **Contextual controls**: controls appear when needed and recede when focus returns to content.
- **Input parity**: every touch-first interaction has keyboard and mouse alternatives.

This approach avoids legacy top-heavy desktop layouts and prioritizes natural movement patterns across desktop, tablet,
and mobile form factors.

## Hub-and-Spoke Navigation

Aura Shell uses a spatial model:

- **Hub**: a personalized home space with living widgets and quick entry points.
- **Spokes (Module Spaces)**: full-screen module environments (shell, file workflows, UI tools, and future modules).

```text
             +--------------------+
             |  Module Space A    |
             |  (Shell workflows) |
             +---------^----------+
                       |
+----------------------+----------------------+
|                Hub (Home)                  |
|  Widgets, status, quick actions, search    |
+---+-------------------+------------------+-+
    |                   |                  |
    v                   v                  v
+-----------+    +-------------+    +---------------+
| Module B  |    | Module C    |    | Module D      |
| GUI tools |    | File flows  |    | Plugins/future|
+-----------+    +-------------+    +---------------+
```

Navigation is intentionally low-friction:

- Tap from Hub to enter a module with a focused fly-in transition.
- Swipe from screen edges for backward/forward movement.
- Use two-finger horizontal gestures to switch module spaces quickly.

## Gesture System

Aura Shell defines a universal gesture layer that works across modules, then allows each module to add contextual
gestures where necessary.

| Gesture | Action | Notes |
|---|---|---|
| Edge swipe left/right | Navigate back/forward | Global navigation |
| Swipe up from bottom edge | Quick actions / command entry | Fast command access |
| Swipe down from top edge | Notification Center | Status and alerts |
| Pinch | Zoom | Canvas, documents, previews |
| Long press | Context Bloom (radial menu) | Context actions near finger |
| Two-finger horizontal swipe | Switch Module Spaces | Spatial task switching |
| Three-finger swipe down | Command Palette | Fast fuzzy search |
| Three-finger swipe up | Overview (module exposé) | Visual module switching |
| Shake (mobile targets) | Undo | Platform-dependent |

Module-specific gestures may extend this set but should never break global expectations.

## Context Bloom (Radial Menu)

Context Bloom is Aura Shell's radial action model:

- Triggered by long press (touch) or right-click (mouse).
- Actions are arranged in arcs around the interaction point.
- Frequently used actions are placed in near-reach sectors.
- Sub-actions can branch radially without opening stacked modal menus.

Design goals:

- minimize pointer travel
- reduce menu hierarchy depth
- keep the user in spatial context

## Adaptive Layout

Aura Shell adapts behavior by form factor:

- **Desktop (>13")**
  - Multi-panel layouts and split views
  - Rich keyboard shortcuts in parallel with gesture support
  - Enhanced workspace density for multitasking
- **Tablet (8-13")**
  - Full-screen modules with gesture-first transitions
  - Slide-over panels and dual-module split workflows
  - Emphasis on thumb zones and direct manipulation
- **Phone (<8")**
  - Single-column primary flow
  - Bottom sheets for secondary detail
  - Aggressive reachability optimization for one-hand operation

## Visual Design

Aura Shell uses a soft, spatial visual language with performance-aware implementation:

- **Glassmorphism with depth**: frosted surfaces, translucent layering, subtle blur, and z-order cues.
- **Fluid typography**: dynamic text scaling by viewport and density.
- **Physics-based motion**: spring, inertia, damping, and snap behavior define transitions and scrolling.
- **Micro-interactions**: tap ripple, drag elasticity, and meaningful transition continuity.
- **Rendering intent**: target smooth interaction while preserving responsiveness in software-rendered paths.

## Accessibility

Accessibility is treated as a first-class requirement:

- Keyboard alternatives for all core gestures
- Screen-reader-friendly semantic structure (where platform APIs allow)
- High-contrast mode support
- Reduced-motion mode for vestibular comfort
- Configurable gesture sensitivity and timing

No essential workflow should be locked behind a single input method.

## Color System

Aura Shell uses an adaptive, layered color model:

- **Primary accent**: module identity and action emphasis
- **Surface / on-surface pairs**: readability across translucent layers
- **Automatic contrast control**: preserve legibility in light and dark environments
- **Theme modes**: dark, light, and system-follow
- **True dark support**: deep-black surfaces for OLED-friendly experiences

Per-module accents help users maintain spatial and functional orientation while switching contexts.

## Design Consistency Rules

To keep interactions coherent across modules:

1. Global gestures must remain stable and discoverable.
2. Any custom gesture must include keyboard and mouse fallback.
3. New motion patterns must map to existing physics primitives.
4. Reach-critical controls should avoid top-only placement.
5. Context Bloom actions should prioritize task-frequency order.
