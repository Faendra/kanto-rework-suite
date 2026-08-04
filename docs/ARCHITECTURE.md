# Architecture

## Repository model

Kanto Rework Suite is one repository containing multiple Gen1Recomp mod packages. Packages share one visual language and one core contract but remain installable and testable independently.

## Dependency direction

```text
kanto_rework_core
├── kanto_rework_ui
│   ├── kanto_rework_companion
│   ├── kanto_rework_battle
│   ├── kanto_rework_system
│   ├── kanto_rework_moves
│   └── kanto_rework_quests
└── kanto_rework_compat
```

No optional package may be required by `kanto_rework_core`.

## Core responsibilities

`kanto_rework_core` owns:

- semantic design tokens;
- adaptive layout classes for 16:9, 9:16, and 10:9;
- focus and navigation state;
- keyboard, controller, pointer, and touch abstraction;
- hit-region registration;
- theme and profile persistence;
- shared components;
- adapter registry;
- diagnostics and vanilla fallback.

It must not own battle rules, save-slot behavior, quests, move storage, or other gameplay systems.

## Presenter contract

Presenters read live engine state and render a high-resolution view. They must not call private callbacks directly when the original state can perform the action through normal input.

A presenter exposes a read-only semantic model containing, when applicable:

- `screenId`;
- `layer` (`screen` or `modal`);
- title and subtitle;
- rows, cards, tabs, and details;
- current selection and scroll position;
- available semantic actions;
- interactive hit regions;
- capability flags;
- source references required by adapters.

If a presenter cannot prove that it owns the complete visible UI layer, the native renderer remains visible.

## Pointer model

The official engine does not currently expose a universal semantic pointer API for in-game menus. The first implementation therefore remains isolated behind `core/input/pointer.lua` and must be removable without rewriting presenters.

Pointer actions follow these rules:

- left click selects or confirms;
- right click returns;
- wheel scrolls the hovered scroll region;
- touch uses the same hit regions without hover;
- virtual touch controls retain priority;
- a direct click selects the live state item and then invokes the normal game action rather than bypassing callbacks.

## Persistence

Configuration data is separate from game-save data.

Global configuration may contain:

- theme profiles;
- overlay profiles;
- input mappings;
- accessibility settings;
- enabled widgets.

Gameplay modules own and version their additional per-save data. Every gameplay data format requires migration and recovery rules before release.

## Compatibility policy

Three compatibility levels are defined:

1. **Native** — supported through stable public or documented engine state.
2. **Adapter** — supported through an explicit versioned adapter.
3. **Fallback** — native UI remains active because the screen contract is unknown or unsafe.

Unknown mods are never forcibly restyled by guessing localized labels or private object shapes.
