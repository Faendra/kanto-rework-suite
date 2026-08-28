# CP3D00 — 3DWorld / HD2D foundation

Status: IMPLEMENTED / RUNTIME NOT TESTED
Branch: `experiment/sol-3dworld-hd2d`
Parent remote commit: `7e30b244c0cf9b7e5f5d6f31bedccc23dd70e64d`
Parent remote state: Candidate.3-era public `main`, known to be older than recovered Candidate.9.
Engine target audited: Gen1Recomp v0.2.32.

## Completed

- Created an isolated renderer package: `kanto_rework_3dworld_hd2d`.
- Uses Mod API 2 `render_pipelines`; no private-engine imports.
- Uses `mod.world:current()` and `mod.world:mapOverview()` for read-only map state.
- Implements oblique player-centered projection.
- Implements semantic heightfield terrain with side faces only at elevation discontinuities.
- Uses tile-detail luminance to retain some source-map visual rhythm without voxel assets.
- Reuses live player/NPC `pose()`, `getPoseGeometry()` and `resolveImage()` data supplied through the renderer context.
- Interleaves terrain and actor drawables in one depth order.
- Bridges engine field FX through `ctx.drawFx`.
- Returns nil when no playable world snapshot exists so Gen1Recomp can use its vanilla 2D path.
- Requests no `engine_internals` permission.

## Not yet validated

- Actual boot/load under v0.2.32.
- Lua syntax through the engine's mod loader.
- Rendering on Windows/OpenGL.
- Player/NPC occlusion in every map topology.
- Warps and scripted transitions.
- Fishing/Fly/heal field-FX placement under the custom projection.
- Yellow-specific follower edge cases.
- Performance on large maps.

## Known limitation

`mapOverview()` does not semantically label buildings, trees, fences or signs. CP3D00 therefore treats blocked terrain as a raised connected mass. This is deliberate: it proves the renderer pipeline without inventing map semantics. CP3D01 must add an authored classification layer before visual quality can be judged against the final 3DWorld/HD2D goal.

## Rollback

Disable or remove `kanto_rework_3dworld_hd2d`, or set the pipeline to `OFF`. No gameplay/save migration is involved.

## Next checkpoint

CP3D01 — Pallet Town visual pilot:

1. classify exterior Gen 1 tile/block families into terrain, vegetation, architecture and water;
2. replace generic raised masses with continuous authored silhouettes;
3. preserve current pixel sprites as billboards;
4. add camera easing and composition rules;
5. capture comparative screenshots against vanilla 2D.
