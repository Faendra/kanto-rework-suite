# CP3D02C — Direct map-connection continuity

Status: IMPLEMENTED / LUA 5.1 STATIC GATE PASS / RUNTIME NOT TESTED
Branch: `experiment/sol-3dworld-hd2d`
Engine target: Gen1Recomp v0.2.32
Parent visual checkpoint: CP3D02A

## Objective

Prevent exterior Gen 1 map seams from revealing empty renderer space or forcing an obvious camera reframe, while keeping Gen1Recomp as the only owner of map loading, collision, scripts, NPCs, encounters and persistence.

This checkpoint deliberately handles **direct one-hop map connections only**. It does not instantiate a second runtime Map and does not attempt to reproduce Gen1Recomp's full multi-hop neighbor system.

## Engine evidence

Gen1Recomp v0.2.32 already treats connected maps as a shared spatial neighborhood in its native overworld renderer. Its connection placement uses authored map connection offsets expressed in 32 px blocks.

For the KRS renderer the same placement relationship is reconstructed from public content definitions and converted to 16 px walk-cell coordinates:

- north: `x += offset * 2`, destination above the active map;
- south: `x += offset * 2`, destination below the active map;
- west: destination left, `y += offset * 2`;
- east: destination right, `y += offset * 2`.

No engine-private module is imported by the mod.

## Implemented

### NeighborScenes

Added `sol3d/NeighborScenes.lua`.

For each direct `mapDef.connections` entry it:

- reads the destination map definition through `mod.content.maps:get()`;
- reads its tileset definition through `mod.content.tilesets:get()`;
- reconstructs a read-only semantic walk-cell overview from block/tile data;
- classifies walkable, water/shore, warp and blocked cells;
- computes the destination offset in the active map's coordinate frame;
- returns a presentation-only descriptor.

It does **not** create runtime collision, scripts, objects, encounters, NPCs or save state.

### WorldAdapter

`WorldAdapter:snapshot()` now carries the direct neighbor preview descriptors alongside the authoritative active `mapOverview()`.

The active map remains authoritative. Neighbor data is a visual preview only.

### Shared renderer depth space

`Renderer.lua` now composes the active map and direct neighbors into one world coordinate system before depth sorting.

Consequences:

- cells from both sides of a seam can occupy one projection;
- east/south side-face tests can sample across the seam instead of creating a false cliff at the map boundary;
- a Pallet Town authored profile can still be used if Pallet is currently a neighboring scene;
- all scene cells, structures, vegetation and active-map actors share the same painter-depth order;
- only live active-map player/NPC instances are rendered as actors; neighbor NPC ghosts are intentionally not invented;
- field-FX projection uses the same connected surface lookup.

Renderer diagnostics now include `neighborMaps` and `neighborCells`.

### CameraContinuity

Added `sol3d/CameraContinuity.lua`.

When the active map id changes:

- if the previous map appears as a direct neighbor of the new active map, the existing camera point is translated by that neighbor offset before the new root is rendered;
- the new player pose immediately becomes the camera target and normal easing continues;
- if no direct connection proves a common coordinate frame, the helper does nothing and Renderer retains its normal map-change snap.

Therefore door warps, Fly, teleport and unrelated scripted warps are not falsely treated as seamless geography.

## Static validation

A branch-local GitHub Actions gate was added at `.github/workflows/sol3d-static.yml`.

Run `33169370917` completed successfully against commit `97f6aab8c31708d16e626a2e46a24371db40911a`.

Validated by that run:

- checkout succeeded;
- Lua 5.1 installed successfully;
- every `.lua` file under `packages/kanto_rework_3dworld_hd2d` passed `luac5.1 -p`;
- `manifest.json` passed `python3 -m json.tool`.

This is a syntax/integrity gate only. It does not validate LOVE shader compilation, Mod API runtime behaviour, OpenGL output, gameplay parity or visual quality.

## Known limitations

1. **Runtime not tested.** Static source/API inspection and `luac5.1 -p` do not prove Windows/OpenGL behaviour.
2. Neighbor previews are one hop only; the native engine may render farther neighbors in wide/zoomed views.
3. Neighbor previews use semantic block/tile reconstruction and do not currently have the active map's `tileDetailRows` material raster.
4. Dynamic block mutations on a non-active neighboring map are not guaranteed to be reflected until that map becomes active. The preview must therefore never be treated as gameplay authority.
5. Neighbor NPCs are omitted rather than reconstructed from internal state.
6. Camera rebasing across a connection is mathematically implemented but still requires real captures in both directions for every connection orientation.
7. Overlapping or unusual mod-authored connection graphs require runtime validation; direct active scene data wins lookup order when coordinate rectangles overlap.

## Acceptance tests still required

- Pallet Town ↔ Route 1 seam, both directions;
- Pallet Town ↔ Route 21 seam where applicable to the current game state;
- at least one east/west exterior connection;
- actor halfway through the crossing animation;
- water crossing/surf seam;
- field FX near a seam;
- HD2D / DEPTH / CINE levels;
- 720p and 1080p;
- verify no false side wall at matching-height seams;
- verify no camera jump after the coordinate root changes;
- verify a door warp still snaps normally;
- measure neighbor-cell render cost.

## Acceptance state

**Not SAFE.** Syntax and manifest integrity pass automatically, and the implementation is structurally consistent with the v0.2.32 connection model, but actual engine execution and screenshots are still required.

## Next

CP3D02B remains the next visual-material checkpoint:

- connected water treatment;
- contact shadows for structures and vegetation;
- preserve a single world post-process pass;
- measure before adding any additional GPU pass.
