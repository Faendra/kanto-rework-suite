# BUILDING-01 — Building-first foundation

## Scope

BUILDING-01 is intentionally limited to Pallet Town and Red's house. It does not attempt global terrain, ledges, trees, water, interiors, shaders, bloom, depth of field, weather, or Kanto-wide structure inference.

## Authoritative semantic anchor

Gen1Recomp v0.2.32 identifies Pallet Town as `PALLET_TOWN`. Its generated-data smoke test fixes the map at 20×18 gameplay cells and confirms the warp at cell `(5,5)` targets `REDS_HOUSE_1F`. The Pokemon Red map object source independently places the Red-house warp at `(5,5)`. The Pallet block map places the left house in a 2×2-block footprint, yielding gameplay cells `x=4..7, y=2..5`.

The renderer therefore recognizes BUILDING-01 only when both conditions are true:

1. `map.id == "PALLET_TOWN"`;
2. `map:warpAtCell(5,5).def.destMap == "REDS_HOUSE_1F"`.

No collision flood-fill, pixel-color classifier, ledge propagation, or inferred terrain elevation participates in building identity.

## Scene contract

`SemanticSceneBuilder` produces semantic scene objects. `PalletRedHouse` owns an authored architectural profile: footprint, wall height, pitched roof, ridge, thickness, overhang, door location, contact footprint, and material-source regions. `AtlasSource` copies runtime Gen1Recomp atlas tiles into cached canvases. Those pixels are material inputs only; they do not define geometry.

`BuildingRenderer` projects explicit 3D faces with `SceneProjection`, draws a contact shadow, depth-sorts the complete building against actors, and preserves Gen1Recomp actor pose/sprite rendering. It does not write to gameplay state.

## Performance contract

Semantic scene construction is cached by map identity, dimensions, and runtime atlas identity. Ground cell textures and building region textures are cached canvases. No `newImageData()` path exists. The draw path traverses the prepared scene, projects faces, and issues draws.

## Reused historical foundations

- Runtime atlas access pattern from `AtlasSource.lua`.
- Perspective camera mathematics from `SceneProjection.lua`.
- Actor pose/sprite projection contract from the historical `SceneRenderer.lua`.
- `render_pipelines` registration contract from the historical package.

## Explicitly rejected historical layers

`SceneStyle`, `LivePolish`, `DioramaPolish`, `NaturalForms`, `NaturalScale`, `AtlasWorld`, `SceneContinuity`, `TerrainRemaster`, `LedgeTopology`, and `LedgeHopSmoothing` are not dependencies of the building-first package.

## Validation state

A green static or synthetic gate is not a visual pass. BUILDING-01 may be called visually passed only after inspecting a real rendered capture and confirming readable architectural volume, Pokemon Red identity, roof thickness/overhang, coherent side faces, door placement, contact, actor occlusion, and perspective without bloom/DOF masking.
