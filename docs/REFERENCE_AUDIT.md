# Reference Audit — P0

## Scope

This document records technical evidence extracted from the user-supplied
`kanto_companion-2.7.0.zip` and `assets.zip`. The archives are reference inputs;
their content is not committed to this repository.

## Kanto Companion 2.7.0

### Confirmed capabilities

The supplied package demonstrates that the official game process can support:

- an in-game read-only companion overlay;
- Bag ⇄ PC item management;
- Party ⇄ Box drag-and-drop;
- controller, mouse, and touch input in custom screens;
- a free-moving controller cursor;
- battle matchup information and catch odds;
- responsive percentage-based touch regions;
- live reading of save, party, encounter, box, item, and battle data.

### Architecture findings

- Manifest: API 2, `content` profile, `QOL` category.
- Permission: `engine_internals`.
- Implementation: one `main.lua`, 2,505 lines and approximately 127 KB.
- Input is integrated by wrapping global LÖVE callbacks such as
  `love.mousepressed`, `love.touchpressed`, and `love.gamepadpressed`.
- The package directly requires private `src.*` modules for battle, items,
  Pokémon, boxes, stats, and catching.
- It does not use the newer public `mod.input` façade or `render.hud` hook.

### Decision

Kanto Companion is valid proof that the desired interactions are possible, but
its monolithic and internal-heavy structure is not adopted. Kanto Rework Suite
will:

1. isolate every engine-internal dependency behind an adapter;
2. prefer public hooks and `mod.input` when present;
3. use shared semantic components rather than screen-specific duplicated code;
4. preserve native fallback when an adapter cannot prove compatibility;
5. keep overlay, item management, and box management as separate modules.

### Licensing status

The supplied archive contains no standalone license file. No source code from
it will be copied into Kanto Rework Suite unless the right to do so is confirmed.
Behavioral ideas and observed engine seams may be independently reimplemented.

## Sprite archive

### Inventory

- 1,838 files total.
- 1,819 PNG files.
- 19 README/contract files.
- All supplied assets are under `assets/battle/`.

### Major sets

- static back sprites for Gen 1–5;
- animated back atlases for Gen 3 and Gen 5;
- static opponent/trainer front art for Gen 1–3;
- animated front atlases for Gen 2–5;
- single-frame Gen 1 front compatibility art;
- static and five-pose player/trainer back art.

Most complete species directories contain 151 PNG files plus one README.

### Rendering contracts

- Static species art is ordinary PNG data.
- Animated art uses horizontal or atlas-based equal cells with shared metadata.
- Nearest-neighbour filtering and aspect-fit rendering are required.
- Missing or malformed art must fall back to the active ROM sprite.
- Authored player back art faces right and must not be mirrored.
- Animated player introductions use five equal-width horizontal frames.

### Naming exceptions

The archive explicitly standardizes these filenames:

- `mr-mime.png`;
- `farfetchd.png`;
- `nidoran-f.png`;
- `nidoran-m.png`.

### Distribution restriction

The supplied README files state that generated/downloaded artwork is ignored by
Git and is not covered by the associated mod's MIT license. The assets will
therefore remain local design/test inputs unless the user confirms appropriate
distribution rights.

## Immediate P0 implications

- The external-art adapter must support both static images and equal-cell
  atlases.
- Metadata must be separate from image loading.
- The UI must never assume a fixed sprite generation, logical size, or frame
  count.
- Missing art is a normal fallback state, not an error screen.
- The first runtime test should use one static 56×56 or 64×64 PNG and one
  horizontal animated atlas from the supplied archive.
