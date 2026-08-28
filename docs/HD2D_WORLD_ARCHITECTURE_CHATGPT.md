# KRS — HD2D World parallel architecture (ChatGPT Sol)

Branch: `experiment/chatgpt-sol-hd2d-world`

Status: experimental, isolated from production KRS.

Target engine baseline: Gen1Recomp `>=0.2.32 <0.3.0`.

## Goal

Produce a spatial Kanto presentation closer to a modern HD-2D / 3D-world remake while preserving Gen1Recomp as the sole authority for gameplay, collision, scripts, events, warps, encounters, save data and progression.

This branch deliberately does **not** pursue voxel art. The visual model is:

- original/current tiles rendered as a projected ground texture;
- perspective built from horizontal world strips rather than a cube grid;
- shallow semantic relief only where collision says background art is solid;
- connected maps reused from the engine's already-loaded neighbour renderers;
- player/NPC/follower art retained as upright pixel-art billboards;
- world FX delegated back to `ctx.drawFx`;
- KRS/Gen1Recomp UI stays outside the world pipeline and therefore remains crisp 2D;
- any unavailable or failed pipeline returns to the engine's normal 2D renderer.

## Why this differs from the other experimental branch

The competing `experiment/sol-3dworld-hd2d` branch uses authored scene profiles as an important part of its world interpretation. This branch instead tests a **data-derived world**: geometry is inferred at runtime from the loaded Map object (`isWalkableCell`, `isWaterCell`, `isGrassCell`, dimensions and connected-map renderers). The aim is to make an unknown Route, cave or town render spatially without first writing a dedicated profile for it.

Profiles may still be added later for exceptional landmarks, but they must be optional overrides rather than the baseline requirement.

## Pipeline

`krs_hd2d_world` is registered through Gen1Recomp Mod API 2 `render_pipelines`.

Levels:

1. `OFF` — engine renderer only.
2. `HD2D` — projected world strips, semantic relief, upright billboards.
3. `DEPTH` — stronger depth separation and restrained water material lighting.
4. `CINEMA` — strongest approved camera depth; still no gameplay changes.

Hotkey: `7` so this experiment can coexist with the other branch's hotkey `6` during comparison.

## Module boundaries

- `main.lua` — sandbox-safe module loader and render-pipeline registration only.
- `hd2d/Projection.lua` — deterministic world→screen projection and level presets.
- `hd2d/MaterialClassifier.lua` — converts map semantics into `ground / grass / water / solid` without changing collision.
- `hd2d/Renderer.lua` — terrain source capture, projected strip draw, shallow relief, billboards, FX bridge and canvas lifecycle.

No module writes to the save, player position, map blocks, entities, collisions or scripts.

## Rendering sequence

1. Render the current map and `state.neighbors` into an offscreen world-pixel source canvas using their existing `TileRenderer` instances.
2. Project that source as 4-pixel horizontal strips. Each strip gets its own perspective width, producing a continuous depth field without a voxel grid.
3. On the current map only, inspect visible 16-pixel cells. Non-walkable, non-water cells receive shallow vertical relief. Their top is re-sampled from the already-rendered source, preserving animated/replaced tiles and palette packs.
4. Render contact shadows.
5. Render `state.entities` and neighbour `state.ghosts` as upright billboards using the sprite renderer's supported `pose`, `getPoseGeometry` and `resolveImage` contracts.
6. Ask the engine to draw active field effects through `ctx.drawFx(project, scale)`.
7. Return one playfield-resolution canvas to the engine. Menus/dialog UI composite afterward through the normal path.

## Non-negotiable fallback

`Renderer:drawWorld` returns `nil` whenever the required render context is absent. Gen1Recomp then executes its normal flat/tilt path. The engine also retires a render pipeline that throws. A renderer defect must cost only this display mode, never the playthrough.

## Known limits of CPHD2D01

- No real runtime screenshot has yet been produced from this branch.
- Tall-grass foreground occlusion is not yet re-projected over billboards.
- SS Anne departure and other exceptional map-specific background animations are not yet bridged.
- Relief is inferred from passability, so some decorative collision cells will need semantic refinement.
- Connected neighbour terrain is projected, but relief classification currently applies to the active map only.
- No depth-of-field, bloom or tilt-shift post-process is included yet; those are deliberately deferred until geometry is validated.

These are open validation items, not accepted regressions.
