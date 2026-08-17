# P0 Implementation Status

## Branch

`feat/p0-foundations`

## Implemented in the first spike

- API 2 experimental `kanto_rework_core` package;
- official `render.compose`, `render.hud`, `render.zones`, and `input.step`
  hooks;
- conservative native Start-menu detection through `screenId == "StartMenu"`;
- native UI-canvas suppression only for the supported Start menu;
- high-resolution Field Journal / Graphite Start-menu presenter;
- 16:9, 9:16, and 10:9 layout classification;
- mouse hover, left-click activation, right-click back, and wheel navigation;
- touch row activation;
- public `mod.input:tap` for source-safe Game Boy actions;
- movable overlay widget with normalized position persistence;
- F8 overlay toggle and F9 overlay edit mode;
- static package validation and CI Lua parsing.

## Deliberately not claimed as validated

The code has not yet been executed inside a local Gen1Recomp installation.
Therefore the following remain unconfirmed until runtime evidence is attached:

- launcher import and permission prompts;
- exact draw-stack behavior with the released official build;
- touch-control capture priority;
- pointer coexistence with other callback-wrapping mods;
- persistence path behavior on Windows, Android, and other platforms;
- hot-reload cleanup;
- Gen1 Modern UI and Kanto Companion conflict behavior;
- external animated sprite rendering.

## First runtime procedure

1. Build or copy `packages/kanto_rework_core` into the game's `mods` folder.
2. Enable only Kanto Rework Core.
3. Open the Start menu at 1920×1080.
4. Verify keyboard and controller navigation before testing pointer input.
5. Test mouse hover, click, right-click, and wheel.
6. Toggle and move the overlay; restart and verify its position.
7. Repeat at 1080×1920 and 1600×1440.
8. Enable Kanto Companion, then Gen1 Modern UI, one at a time.
9. Record every failure using the template in `docs/TECHNICAL_SPIKE.md`.
