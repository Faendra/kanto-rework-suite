# Kanto Rework Core — P0.0.9

This is a focused runtime-validation build for the official Gen1Recomp line.
It is not the complete Kanto Rework Suite.

## Included in this test

- the V2 **Field Journal** Start-menu presenter and Graphite alternative;
- the official `input.pointer` middleware introduced by Gen1Recomp issue #807;
- a non-duplicating compatibility bridge for older builds;
- semantic mouse and touch support for Start, Party, Bag/List, Pokédex,
  Options, boxed menus, Pokémon summaries, dialogue and YES/NO choices;
- overworld left click as native `A`, and right click as native `B`;
- mouse-wheel navigation in the in-game Gen1Recomp mod manager, including
  mod option pages and confirmation overlays;
- classic and wide battle pointer support for command menus, move selection,
  Mimic selection and battle messages;
- anchored YES/NO coordinate correction for the DYNAMIC UI layout;
- a movable companion card and temporary diagnostics.

## Controls

- `F8`: show/hide the companion card;
- `F9`: enable/disable overlay edit mode;
- left click: interact, select, confirm or advance as native `A`;
- right click: cancel/go back as native `B`;
- mouse wheel: navigate supported lists, the mod manager and battle menus;
- drag the red overlay header while edit mode is active.

## Pointer behavior

Kanto Rework consumes an official pointer lifecycle from press through release,
updates the real native selection, and injects source-safe Game Boy input with
`mod.input:tap`. The virtual touch controls retain first refusal.

The battle adapter reads the actual native UI surface from the renderer. It
supports the classic 160x144 layout and the wide 304x144 layout, including
classic Party/Bag screens centred over a wide battle.

## Pointer safety

- clicks outside the game viewport do not trigger overworld interaction;
- blank space in a known structured menu does not confirm the previous row;
- the companion overlay consumes pointer events and cannot click through;
- cancelled pointer lifecycles never activate;
- native callbacks, sounds, validation, stack transitions and mod hooks remain
  owned by Gen1Recomp.

## Deliberate limits

- only the Start menu and P0 companion card are visually replaced;
- Party, Bag, Pokédex, dialogue and battle still use their native visuals;
- the GitHub repository is private, so Gen1Recomp cannot perform unauthenticated
  auto-update checks until releases are mirrored to a public repository.
