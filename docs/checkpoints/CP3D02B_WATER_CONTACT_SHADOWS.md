# CP3D02B — Water material and contact shadows

Status: IMPLEMENTED / HEADLESS RENDER GATE PASS / RUNTIME VISUAL NOT TESTED
Branch: `experiment/sol-3dworld-hd2d`
Engine target: Gen1Recomp v0.2.32
Parent visual checkpoint: CP3D02A
Related continuity checkpoint: CP3D02C
Implementation commit: `3308770eb5023145ca2e845115eea2a9113820be`
Headless-render test commit: `b20f143662c544dfc00b8221688316cca6f50015`
Implementation CI run: `33173036196`
Headless-render CI run: `33173275154`

## Objective

Strengthen the HD-2D reading of the reconstructed Kanto world with restrained surface motion and contact cues while preserving the branch's anti-voxel rule:

- water remains a continuous surface rather than a grid of animated cubes;
- shadows anchor authored objects to the shared terrain instead of adding per-cell ambient-occlusion blocks;
- the existing `worldPresent` stage remains the only post-process pass;
- Gen1Recomp remains authoritative for map state, gameplay, collision, actors and persistence.

## Implemented

### Restrained connected-water material

`Renderer.lua` now carries a bounded presentation clock (`materialTime`) advanced from the public render-pipeline `update(dt, level)` callback.

Water brightness is modulated by two low-amplitude world-space sine components. The amplitude is intentionally small and follows the existing presentation ladder:

- `HD2D`: 0.020;
- `DEPTH`: 0.028;
- `CINE`: 0.034.

No water vertex or collision height moves. Water remains at the existing presentation height (`z = -0.14`). The effect therefore changes material appearance only.

For the active map, the existing 4×4 material raster per 16 px walk cell remains intact. Water modulation is sampled in shared world coordinates, so the pattern does not restart at every walk-cell boundary.

Direct-neighbor previews do not currently carry `tileDetailRows`. Their water therefore receives a deliberately small 2×2 material raster solely to avoid whole-cell pulsing and to let the world-space motion continue across a direct map seam. This does not reconstruct missing authoritative tile art.

### Actor contact-shadow correction

Actor rendering now separates:

- authoritative surface height under the actor;
- visual lift used while hopping.

The sprite still rises during a hop, but its shadow is projected on the underlying ground/water plane. Shadow opacity falls and footprint spread increases slightly with lift. Water uses a lower shadow base opacity.

This fixes the previous behaviour where the ellipse shadow was projected at the actor's lifted Z and therefore visually rose with the sprite.

### Vegetation contact shadows

Each rendered vegetation group receives one restrained projected ground footprint.

The shadow is:

- slightly offset;
- level-dependent in opacity;
- attached to the shared ground plane;
- drawn once per vegetation presentation object, not once per source map cell.

### Structure contact shadows

Each authored structure receives one projected footprint covering its authored plan and offset slightly toward the visible south/east fringe.

The walls and roof then cover most of this footprint, leaving only a restrained grounding cue. This avoids per-cell AO and avoids turning buildings into stacked voxel masses.

### Diagnostics

Renderer diagnostics now expose two additional counters:

- `waterCells`;
- `shadowCasters`.

These are intended for runtime capture/performance comparison; they are not themselves frame-time measurements.

## GPU/pass architecture

CP3D02B adds **no shader and no additional Canvas/post-process stage**.

Water modulation and contact shadows are generated inside the existing world geometry draw. `Presentation.lua` remains the single optional world-only post-process introduced by CP3D02A.

## Automated validation

### Implementation gate — run `33173036196`

GitHub Actions completed successfully for implementation commit `3308770eb5023145ca2e845115eea2a9113820be`.

Passed jobs:

1. `Lua syntax + manifest`
   - package Lua source compile-check;
   - `manifest.json` JSON validation.
2. `Gen1Recomp v0.2.32 loader`
   - checkout of upstream Gen1Recomp v0.2.32;
   - package loading through the official mod loader;
   - KRS pipeline registration/selection and clean no-overworld fallback gate;
   - loader diagnostic upload.

### Headless renderer gate — run `33173275154`

The loader test was then strengthened in commit `b20f143662c544dfc00b8221688316cca6f50015` so it no longer stops at the no-overworld fallback.

After the package has been loaded through Gen1Recomp's official loader, the test now injects a synthetic read-only rendering snapshot containing:

- a Pallet Town signature with an authored building component;
- edge vegetation;
- active-map water with a 4×4 detail raster;
- a directly connected Route 21-style neighbor;
- neighbor water without `tileDetailRows`, exercising the CP3D02B 2×2 fallback material path.

It calls `Renderer:update()` and a real `Renderer:drawWorld()` under the upstream LOVE headless stub, augmented only with no-op polygon/ellipse primitives. The test requires a returned Canvas and asserts that the following runtime paths were actually exercised:

- cells;
- water cells;
- direct-neighbor cells;
- authored structures;
- vegetation;
- contact-shadow caster accounting;
- material clock advancement.

Both jobs completed successfully:

- `Lua syntax + manifest`: PASS;
- `Gen1Recomp v0.2.32 loader`: PASS, including the synthetic renderer execution.

This is materially stronger than a loader-only check because CP3D02B's renderer code now executes headlessly after official mod loading. It still does **not** rasterize real pixels and therefore does not prove OpenGL rendering, shader compilation, visual quality, gameplay parity or performance on the user's Windows machine.

## Known limitations

1. **Runtime visual output is not tested.** No Windows/OpenGL capture exists yet for this checkpoint.
2. Water is a restrained animated material only. It does not implement reflection, refraction, caustics or geometric waves.
3. The exact shimmer amplitude and temporal frequency have not been tuned from real gameplay captures.
4. Neighbor water uses a synthetic 2×2 material subdivision because CP3D02C neighbor previews intentionally lack the active map's `tileDetailRows` material raster.
5. Structure and vegetation shadow offsets/opacity are technically bounded but have not yet been visually calibrated against Pallet Town, routes, forests and interiors.
6. Contact shadows are presentation cues, not gameplay lighting. They do not infer occlusion from a real light source or shadow map.
7. `waterCells` and `shadowCasters` are draw diagnostics, not GPU timings.
8. No additional GPU pass was added, but the increased polygon count from animated water subdivisions and contact footprints still requires measurement.
9. The headless renderer gate proves code-path execution but not pixel output because the LOVE polygon/ellipse calls are deliberately no-ops in CI.

## Required runtime acceptance tests

### Water

- Pallet Town / Route 21 water edge where applicable;
- at least one larger sea surface;
- Surf movement on water;
- direct connected-map water seam;
- camera motion while water is visible;
- `HD2D`, `DEPTH` and `CINE` levels;
- 720p and 1080p;
- verify no obvious cell-by-cell pulsing or checkerboard shimmer;
- verify water does not appear geometrically displaced.

### Contact shadows

- player standing still;
- player hopping: shadow must remain on the underlying surface;
- player/NPC on water where applicable;
- Pallet houses and Oak's Lab;
- dense vegetation;
- direct-neighbor structures/vegetation near a map seam;
- verify shadows are neither detached nor strong enough to read as black geometry.

### Performance

- capture frame cost before/after CP3D02B on the same scene;
- compare `waterCells` and `shadowCasters` diagnostics with frame time;
- test a water-heavy view at the three renderer levels;
- confirm that `Presentation.lua` remains the only world post-process pass.

## Acceptance state

**Not SAFE for visual release yet.**

The implementation now passes syntax, manifest, official-loader and synthetic headless-render execution gates against Gen1Recomp v0.2.32. Visual acceptance and real frame-cost measurements remain mandatory before CP3D02B can be promoted from code checkpoint to validated rendering checkpoint.

## Next

Do not add reflections, another shader pass or more material complexity yet.

The next priority is a **runtime render qualification pass** of CP3D02A + CP3D02B + CP3D02C together:

1. obtain real Windows/OpenGL captures from representative exterior scenes;
2. verify connected-map continuity and camera rebasing;
3. tune water/shadow strengths only from those captures;
4. measure frame cost;
5. only then decide whether the current surface/material model is sufficient for the intended 3DWorld/HD-2D target or whether a deeper rendering change is justified.
