# CPHD2D01 — Projected world foundation

Date: 2026-08-28  
Branch: `experiment/chatgpt-sol-hd2d-world`  
Status: **HEADLESS VALIDATED — LIVE RUNTIME / VISUAL VALIDATION PENDING**

## Baseline

- KRS GitHub baseline: `main` at `7e30b244c0cf9b7e5f5d6f31bedccc23dd70e64d` (Candidate.3 merge).
- Engine target verified before implementation: **Gen1Recomp v0.2.32**.
- This experiment is independent from `experiment/sol-3dworld-hd2d` and does not modify its files or history.

## Implemented

- isolated Mod API 2 package: `packages/kanto_rework_hd2d_world`;
- world render pipeline `krs_hd2d_world`;
- `OFF / HD2D / DEPTH / CINEMA` display ladder, hotkey `7`;
- current-map and connected-neighbour terrain capture through the engine's existing `TileRenderer` instances;
- 4-pixel projected horizontal world strips for continuous depth without voxel geometry;
- runtime semantic classification of map cells as `ground / grass / water / solid`;
- shallow relief for solid cells, with top faces re-sampled from the already-rendered terrain source;
- upright player/NPC/ghost billboards through `pose()`, `getPoseGeometry()` and `resolveImage()`;
- contact shadows;
- field-effect bridge through `ctx.drawFx(project, scale)`;
- reusable canvas/quad lifecycle and explicit invalidation;
- safe `nil` return path so Gen1Recomp can fall back to its standard 2D world renderer;
- pure projection/material contract test in `tests/hd2d_projection_contract.lua`;
- official-loader synthetic-world gate in `tests/hd2d_mod_loader_test.lua`;
- branch-scoped GitHub Actions workflow `.github/workflows/chatgpt-hd2d-static.yml`.

## Validation completed

GitHub Actions run `33176243233` on commit `f3dbbb84ad943347441653ccdea97b5fff402bce` completed successfully on both jobs:

1. **Lua 5.1 syntax + pure contracts — PASS**
   - package Lua sources compile with `luac5.1 -p`;
   - both test files compile;
   - manifest parses as JSON;
   - projection/material contracts execute successfully.

2. **Gen1Recomp v0.2.32 loader + synthetic world — PASS**
   - official Gen1Recomp v0.2.32 checkout;
   - package accepted by `src.mods.Loader` with no loader error;
   - `krs_hd2d_world` registered and selectable;
   - clean `nil` fallback without an overworld does not retire the pipeline;
   - synthetic current-map terrain capture executes;
   - connected-neighbour terrain capture executes;
   - projected renderer returns a canvas;
   - `ctx.drawFx` projection bridge executes.

The first loader run exposed only a limitation of Gen1Recomp's headless `love_stub`: its Quad object lacks the real LÖVE `Quad:setViewport` method. The test harness now supplies that missing headless primitive; no production renderer workaround was added for an API that exists in real LÖVE.

## Static architecture checks

- no `require("src.*")` private-engine imports exist in the experiment package;
- source was inspected against the public Gen1Recomp render-pipeline, Map, Player/NPC pose and SpriteRenderer contracts;
- compare against `main` shows this branch only adds experiment package, tests, docs and its dedicated workflow; production KRS files remain untouched.

## Not claimed

The branch has **not yet been validated by a live graphical Gen1Recomp v0.2.32 gameplay run** and no real LÖVE runtime screenshot from this branch has been accepted. Passing headless loader/render contracts proves compatibility and execution of the tested paths; it does not prove the final visual result.

## Known open gaps

- tall-grass foreground occlusion is not yet re-projected over upright billboards; Gen1Recomp's own flat/tilt paths explicitly redraw the cell bottom over actor feet, so this must be reproduced rather than ignored;
- SS Anne departure and other exceptional background-specific animations are not yet bridged;
- semantic relief currently applies to the active map only; connected neighbours are spatially projected but remain on the base plane;
- passability alone can classify some decorative collision cells too broadly as raised terrain;
- depth-of-field, bloom and tilt-shift are intentionally deferred until the geometry itself is accepted.

## Next validation gate

1. Load Gen1Recomp v0.2.32 with only `kanto_rework_hd2d_world` enabled.
2. Pallet Town: stand, walk, turn, enter Oak's Lab, return outside.
3. Cross Pallet Town ↔ Route 1 and verify camera/terrain continuity.
4. Verify player, NPC and follower anchors and palette resolution.
5. Verify water around Pallet/Route 21 under `HD2D` and `DEPTH`.
6. Verify tall-grass foreground occlusion after the dedicated correction lands.
7. Force a renderer failure and confirm safe fallback to normal 2D.
8. Capture like-for-like screenshots from this branch and `experiment/sol-3dworld-hd2d` using the same save position and window size.

## Rollback

Disable or remove `kanto_rework_hd2d_world`. This checkpoint introduces no save schema, gameplay-state, collision, event or script mutation.
