# CP3D01 — Pallet Town visual pilot

Status: IMPLEMENTED / RUNTIME NOT TESTED
Branch: `experiment/sol-3dworld-hd2d`
Engine target: Gen1Recomp v0.2.32
Parent checkpoint: CP3D00

## Objective

Move the experiment from a generic raised collision map to a recognisable 3DWorld/HD2D scene without introducing a voxel asset dependency or duplicating gameplay state.

## Source authority

The authored Pallet profile is gated by the original map signature:

- map id `PALLET_TOWN`;
- tileset `OVERWORLD`;
- 10×9 source blocks;
- 90-block layout.

The building block groups are audited from `pret/pokered` `maps/PalletTown.blk`. Door positions come from the canonical map object data: Red's house `(5,5)`, Blue's house `(13,5)`, Oak's Lab `(12,11)`.

This information affects presentation only. Warps, collision and scripts remain engine-owned.

## Implemented

- Added `SceneProfiles.lua` with a fail-closed Pallet Town signature.
- Reads map/tileset definitions through public `mod.content.*:get()` registry views; no private `src.*` imports and no `engine_internals` permission.
- Detects the two 2×2-block houses and the 3×2-block laboratory as connected source-block components.
- Converts those components into continuous building silhouettes rather than raising every blocked cell.
- Builds gabled roofs, front/east walls, windows and warp-aligned doors from projected geometry.
- Promotes only the dense outer blocked ring to stylised volumetric vegetation; interior unknown obstacles stay low until their semantics are proven.
- Replaces averaged cell shading with 4×4 per-cell material sampling from `tileDetailRows`. Pixel information is a surface treatment, not 3D cubes.
- Adds smooth camera tracking from the player's interpolated pixel pose, with map-change snap to avoid warp drift.
- Places actors and field FX on the recessed water surface when applicable.
- Keeps pixel-art actor frames, facing, flips and palette resolution owned by Gen1Recomp.
- Exposes renderer statistics including active scene profile, structures and vegetation counts.

## Failure / compatibility behaviour

- If Pallet's dimensions, tileset or block data no longer match the expected source family, the authored profile is not applied.
- If registry reads are unavailable, the renderer continues with the generic semantic `mapOverview()` path.
- If the render pipeline throws, Gen1Recomp's render-pipeline contract retires it and returns to vanilla 2D.
- No save data is written by this renderer.

## Still not validated

- Boot/load through the real v0.2.32 mod loader.
- Windows/OpenGL output.
- Exact painter-order occlusion around all three buildings.
- Camera feel at native movement speed, bicycle speed and scripted movement.
- Field-FX alignment during Fly/fishing/heal/Cut.
- Visual comparison screenshots.
- Performance cost of 4×4 surface material samples.

## Acceptance state

Code checkpoint only. The visual target is **not accepted** until a real runtime capture proves that Pallet Town reads as one coherent scene rather than a projected tilemap.

## Next

CP3D02 will focus on the HD-2D presentation layer after runtime proof:

1. world-only depth haze / restrained DOF through `worldPresent`;
2. water material motion without changing collision;
3. contact shadow refinement;
4. map-connection continuity;
5. cache/material batching based on measured frame cost.
