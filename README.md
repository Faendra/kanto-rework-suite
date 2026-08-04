# Kanto Rework Suite

Private development repository for a modular rework of Pokémon Gen 1 Recompilation Project.

The project targets the official Gen1Recomp release line and is designed as an independent suite rather than a fork of another UI mod.

## Product vision

Kanto Rework Suite modernizes the complete interface and adds optional quality-of-life systems while preserving the live game states, callbacks, and compatibility fallbacks wherever possible.

Core goals:

- complete adaptive UI for 16:9, 9:16, and 10:9 layouts;
- keyboard, controller, mouse, and touch navigation;
- modern and classic battle presentations;
- richer dialogue with optional speaker names and portraits;
- customizable movable overlay profiles;
- reusable semantic UI adapters for compatible third-party mods;
- optional gameplay modules such as quick actions, save slots, move storage, and quest tracking.

## Planned packages

- `kanto_rework_core` — themes, profiles, layout, input, focus, components, adapters;
- `kanto_rework_ui` — native screen presenters and dialogue system;
- `kanto_rework_companion` — movable overlay and widgets;
- `kanto_rework_battle` — battle presentation and optional battle QoL;
- `kanto_rework_system` — save slots, native map/PC access, shortcuts;
- `kanto_rework_moves` — learned-move library and persistent PP rules;
- `kanto_rework_quests` — quest registry, journal, objectives, and rewards;
- `kanto_rework_compat` — explicit adapters for supported third-party mods.

## Current phase

Technical spike P0: prove the official engine can support the shared input layer, adaptive presenter shell, safe fallback, movable overlay, configuration persistence, and external animated artwork before full production begins.

No gameplay-altering feature is considered validated until the technical spike documents its engine contract and failure mode.
