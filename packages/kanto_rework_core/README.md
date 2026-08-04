# Kanto Rework Core — P0.0.8

This is a focused runtime-validation build for the official Gen1Recomp line.
It is not the complete Kanto Rework Suite.

## Included in this test

- the V2 **Field Journal** visual direction reconstructed as live Lua vector UI;
- a high-resolution replacement for the released Start menu;
- semantic Start-menu detection that does not depend on `screenId` being present;
- the released `render.zones` → `render.compose` → `render.hud` ownership model;
- the official `input.pointer` middleware introduced by Gen1Recomp issue #807;
- a non-duplicating compatibility bridge for older builds without that hook;
- Field Journal and Graphite themes;
- a movable companion card outside the menu;
- semantic mouse support for native Start, Party, Bag/List, Pokédex, Options,
  boxed menus, Pokémon summary, dialogue boxes, and YES/NO choices;
- overworld left click mapped to native `A` interaction and right click mapped
  to native `B` cancel;
- touch activation for supported native UI regions and overlay dragging;
- a temporary diagnostic badge for runtime evidence.

## Controls

- `F8`: show/hide the companion card;
- `F9`: enable/disable overlay edit mode;
- left click in the overworld: talk, inspect, or interact as `A`;
- left click in menus/dialogue: select, confirm, or advance as `A`;
- right click: cancel/go back as `B`, including dialogue choices;
- mouse wheel: navigate supported lists and choices;
- drag the red overlay header while edit mode is active.

## Pointer behavior

Current Gen1Recomp builds deliver uncaptured mouse and touch lifecycles through
`input.pointer`. Kanto Rework consumes a pointer from press through release,
updates the real native selection, and injects `A` or `B` only on release.
This avoids missed short clicks, duplicated mobile touch/mouse events, and
interference with the virtual touch controls.

The legacy LÖVE callback bridge calls the engine handler first. It falls back
only when no `input.pointer` event was emitted synchronously, so a current build
never receives both the official event and a duplicate compatibility event.

## Pointer safety

- left click outside the native game viewport does not trigger overworld `A`;
- blank space in a known structured menu does not confirm the previous row;
- the companion overlay consumes pointer events so it cannot click through to
  an NPC, object, dialogue, or menu underneath;
- a cancelled touch/mouse lifecycle never activates;
- every activation is routed through `mod.input:tap`, preserving native sounds,
  callbacks, stack changes, validation, and other mod hooks.

## Deliberate limits

- only the Start menu and P0 companion card are visually replaced in this archive;
- Party, Bag, Pokédex, dialogue and battle still use their native visuals;
- the GitHub repository is private, so Gen1Recomp cannot perform unauthenticated
  auto-update checks until releases are mirrored to a public repository.
