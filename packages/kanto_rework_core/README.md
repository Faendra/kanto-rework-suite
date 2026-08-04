# Kanto Rework Core — P0.0.4

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
- mouse hover, click, right-click back and wheel navigation;
- touch row activation and overlay dragging;
- a temporary diagnostic badge for runtime evidence.

## Controls

- `F8`: show/hide the companion card;
- `F9`: enable/disable overlay edit mode;
- left click/tap: choose a Start-menu row;
- right click: go back;
- mouse wheel: move selection while the pointer is over the menu;
- drag the red overlay header while edit mode is active.

## Expected first-run behavior

Outside the Start menu, a small companion card appears near the top-left and a
bottom-left badge reads `KRS 0.0.4 • HUD ACTIVE`.

Opening the Start menu initially may show the native and modern menu together for
one frame. From the next frame onward, only the Field Journal interface should
remain while the world continues rendering behind it.

## Deliberate limits

- only the Start menu and P0 companion card are replaced in this archive;
- Party, Bag, Pokédex, dialogue and battle presenters are not part of this test;
- mouse support wraps the released LÖVE callbacks because official v0.1.68 does
  not yet expose the newer `input.pointer` hook;
- the GitHub repository is private, so Gen1Recomp cannot perform unauthenticated
  auto-update checks until releases are mirrored to a public repository.
