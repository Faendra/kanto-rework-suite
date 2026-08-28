# CPHD2D01 — Projected world foundation

Date: 2026-08-28  
Branch: `experiment/chatgpt-sol-hd2d-world`  
Status: **CODED — RUNTIME VALIDATION PENDING**

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
- pure projection/material contract test in `tests/hd2d_projection_contract.lua`.

## Static validation completed

- `manifest.json` parsed successfully as JSON in the local audit environment;
- no `require("src.*")` private-engine imports exist in the experiment package;
- source was inspected against the public Gen1Recomp render-pipeline, Map, Player/NPC pose and SpriteRenderer contracts.

## Not claimed

The branch has **not yet been validated by a live Gen1Recomp v0.2.32 gameplay run** and no runtime screenshot from this branch has been accepted. The Lua contract test was authored but was not executable in the local audit environment because no Lua/LuaJIT interpreter was installed there.

## Known open gaps

- tall-grass foreground occlusion is not yet re-projected over upright billboards;
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
6. Record the tall-grass foreground gap explicitly if still present.
7. Force a renderer failure and confirm safe fallback to normal 2D.
8. Capture like-for-like screenshots from this branch and `experiment/sol-3dworld-hd2d` using the same save position and window size.

## Rollback

Disable or remove `kanto_rework_hd2d_world`. This checkpoint introduces no save schema, gameplay-state, collision, event or script mutation.
