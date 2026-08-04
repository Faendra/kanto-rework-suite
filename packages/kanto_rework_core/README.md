# Kanto Rework Core — P0.0.7

This is a focused runtime-validation build for the official Gen1Recomp release.
It is not the complete Kanto Rework Suite.

## Included in this test

- the V2 **Field Journal** visual direction reconstructed as live Lua vector UI;
- a high-resolution replacement for the released Start menu;
- semantic Start-menu detection that does not depend on `screenId` being present;
- the released `render.zones` → `render.compose` → `render.hud` ownership model;
- safe fallback: the native menu stays visible until the replacement has drawn successfully;
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

## Pointer safety

- clicks outside the native game viewport do not trigger overworld actions;
- the companion overlay consumes pointer events so it cannot click through to
  an NPC, object, dialogue, or menu underneath;
- every activation is routed through `mod.input:tap`, preserving the native
  screen's own sounds, callbacks, stack changes, and mod hooks.

## Deliberate limits

- only the Start menu and P0 companion card are visually replaced in this archive;
- Party, Bag, Pokédex, dialogue and battle still use their native visuals;
- mouse support wraps the released LÖVE callbacks because official v0.1.69 does
  not expose a universal public `input.pointer` hook;
- the GitHub repository is private, so Gen1Recomp cannot perform unauthenticated
  auto-update checks until releases are mirrored to a public repository.
