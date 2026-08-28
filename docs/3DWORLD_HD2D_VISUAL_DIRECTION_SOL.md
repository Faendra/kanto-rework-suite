# KRS — 3DWorld / HD2D visual direction — Sol branch

Status: ACTIVE DESIGN CONTRACT
Branch: `experiment/sol-3dworld-hd2d`
Target: Gen1Recomp v0.2.32

## 1. Identity

The target is **Kanto spatialised**, not Kanto replaced.

A successful frame should read in this order:

1. Pokémon Red / Kanto;
2. a genuinely spatial world with elevation and occlusion;
3. a modern HD-2D presentation;
4. renderer technology.

If the first impression is "voxel mod", "Octopath clone", "tilt-shift filter" or "generic 3D remake", the branch has missed the target.

## 2. Non-negotiable visual rules

### 2.1 Pixel characters remain authoritative

- Player and NPCs remain engine-resolved pixel sprites.
- No 3D character replacement in this branch.
- No smoothing pass over the whole frame.
- The gameplay focus band must preserve sprite readability.
- Sprite pose, palette and flip remain engine-owned.

### 2.2 World geometry is continuous

- Ground is a surface, not a grid of cubes.
- Water is a recessed surface, not blue blocks.
- Walls appear only at actual height discontinuities.
- Buildings use coherent silhouettes and roofs.
- Vegetation masses may be stylised, but must not expose a Minecraft-like cell stack.

### 2.3 Pixel information becomes material information

The 2D source is not discarded. Tile shading and palette relationships are reused as surface value, material breakup and identification cues.

The source pixel grid may influence a surface without forcing every source cell to become geometry.

### 2.4 Optics are subordinate

World-only post-processing may provide:

- restrained near/far defocus;
- atmospheric separation;
- slight colour shaping;
- low-strength vignette;
- later, restrained bloom only if a measured scene requires it.

It must not provide:

- permanent heavy bokeh;
- strong chromatic aberration;
- film grain over pixel sprites;
- global blur across menus/dialogue;
- an effect stack that hides weak geometry.

## 3. Camera language

The camera is an oblique gameplay camera, not a free cinematic camera.

Three active levels intentionally express different depth strengths:

| Level | Purpose | Camera / depth character |
|---|---|---|
| HD2D | Default playable target | restrained oblique depth, broad focus band |
| DEPTH | Stronger spatial demonstration | taller relief, narrower optical focus |
| CINE | Showcase / screenshot mode | deepest relief and strongest composition |

Gameplay input, collision and trigger coordinates never rotate with this presentation.

Camera easing is allowed; camera lag that changes gameplay readability is not.

## 4. Lighting language

The branch uses **illustrative directional value**, not a physically based lighting stack.

Target hierarchy:

- top surfaces are the clearest value family;
- front/south-facing structure surfaces stay readable;
- east/side faces provide depth separation;
- contact shadows anchor actors and large masses;
- ambient darkness must never swallow Gen 1 palette information.

No normal-map requirement is introduced for source assets.

## 5. Material families

The minimum world material vocabulary is deliberately small:

- grass / soft ground;
- path / hard ground;
- water;
- vegetation;
- building wall;
- roof;
- doorway / opening;
- glass / window accent;
- special gameplay marker when semantically required.

A new material family must solve a readability problem. It must not be added only to increase detail.

## 6. Water target

Water must read as one connected lower plane.

Required qualities:

- recessed relative to walkable land;
- small continuous directional motion or luminance drift;
- no per-cell bobbing;
- no geometry deformation that changes actor/collision semantics;
- no realistic reflection system in the first production pass.

The original water identity remains visible through colour and pixel-derived breakup.

## 7. Buildings

Buildings are the primary proof that this is a 3DWorld renderer rather than an isometric tile filter.

Required qualities:

- one coherent volume per authored structure;
- readable wall / roof separation;
- warp-aligned doors;
- silhouettes derived from map/tileset evidence;
- no invented footprint that can mislead traversal;
- no extrusion of every blocked source cell as an independent tower.

Pallet Town remains the first reference scene because it contains houses, Oak's Lab, vegetation, paths and map-edge transitions in a compact exterior space.

## 8. Vegetation

The current stacked canopy pilot is transitional.

Production direction:

- merge adjacent tree cells into vegetation masses where source semantics support it;
- preserve gaps that matter for traversal;
- use height variation sparingly;
- shadow the base rather than outline every source cell;
- retain enough pixel-derived colour breakup to remain Kanto.

## 9. Shadow policy

Contact shadows solve grounding, not realism.

Priority:

1. actor feet;
2. building bases;
3. vegetation trunks / mass bases;
4. elevated terrain discontinuities.

Shadows should be soft/simple in world space and must not become a second tile grid.

## 10. Anti-slop / anti-overdetail rule

Every visual addition must answer at least one of:

- Does it improve depth reading?
- Does it improve semantic recognition?
- Does it improve movement/navigation readability?
- Does it preserve a source-game cue that would otherwise be lost?

If none apply, remove it.

This explicitly rejects detail added only because the renderer can draw it.

## 11. Performance contract

The default HD2D level is the production target. `DEPTH` and `CINE` may spend more, but the default path must remain bounded.

Before widening beyond the pilot map, measure:

- visible cells;
- surface samples;
- structures;
- vegetation masses;
- actors;
- Canvas reallocations;
- shader passes;
- frame time.

No second world post-process pass is accepted without a measured reason.

## 12. Screenshot acceptance test

A Pallet Town capture is accepted only if all are true:

- Red is immediately readable as a pixel-art character;
- the ground reads as a connected plane;
- houses and Oak's Lab read as coherent buildings;
- trees read as landscape masses rather than cubes;
- water, if visible, reads as a lower connected surface;
- foreground and background depth are legible without making the center soft;
- doors and movement space remain visually consistent with gameplay;
- the screenshot is recognisably Kanto without depending on UI labels;
- disabling the pipeline returns to vanilla without gameplay-state change.

## 13. Scale-up path

1. **CP3D01** — authored Pallet geometry pilot.
2. **CP3D02A** — world-only optical presentation.
3. **CP3D02B** — water + contact-shadow material pass.
4. **CP3D02C** — connection-aware map-edge continuity and cache budget.
5. **CP3D03** — tileset-driven reusable semantic classification beyond Pallet.
6. **CP3D04** — second exterior biome proof, then one interior proof.
7. **CP3D05** — transplant onto Candidate.9-or-newer KRS baseline and integrate settings.

A later checkpoint may change numbering, but not skip the proof gates.
