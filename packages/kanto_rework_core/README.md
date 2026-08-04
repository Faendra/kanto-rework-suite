# Kanto Rework Core — P0

This package is an **experimental technical spike**, not a release build.

It validates:

- official mod loading;
- high-resolution replacement of the native Start menu;
- native keyboard/controller ownership;
- mouse and touch hit regions;
- right-click back and wheel navigation;
- 16:9, 9:16, and 10:9 layout classes;
- a movable overlay widget;
- profile persistence through a namespaced configuration file;
- native fallback when the top screen is not the supported Start menu.

## Controls

- `F8`: toggle the P0 overlay;
- `F9`: toggle overlay edit mode;
- left click/tap: select a Start-menu row;
- right click: back;
- mouse wheel: move the Start-menu selection;
- drag the overlay header while edit mode is active.

## Important limitations

- Pointer integration wraps LÖVE callbacks and therefore declares the
  `engine_internals` permission. This is deliberately isolated in
  `core/pointer.lua`.
- The Start-menu canvas is suppressed only while the exact `StartMenu` screen
  is topmost and Safari state is inactive.
- External animated artwork is not part of this first commit; the asset probe
  follows after package boot and input behavior are validated.
- This branch has not yet been exercised inside a local Gen1Recomp checkout.
