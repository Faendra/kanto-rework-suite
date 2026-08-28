# CP3D02A — World-only HD-2D presentation

Status: IMPLEMENTED / RUNTIME NOT TESTED
Branch: `experiment/sol-3dworld-hd2d`
Engine target: Gen1Recomp v0.2.32
Parent checkpoint: CP3D01

## Objective

Add the optical separation associated with a modern HD-2D presentation without touching KRS UI, dialogue, gameplay state or the geometry renderer itself.

This pass is deliberately **not described as true depth-buffer DOF**. Gen1Recomp's public `worldPresent(canvas, ctx)` contract receives the completed world Canvas, not a semantic depth texture. The implementation therefore uses a restrained screen-space focus band, atmospheric separation and edge treatment over the world image only.

## Implemented

- Added `sol3d/Presentation.lua` as an independent post-process module.
- Wired the module through the public `render_pipelines.worldPresent` callback.
- Keeps menus/dialogue/UI crisp because the pass runs before UI composition.
- Three presentation strengths follow the existing renderer ladder:
  - `HD2D`: subtle optical separation;
  - `DEPTH`: stronger foreground/background defocus;
  - `CINE`: strongest but still restrained focus treatment.
- Uses a small 9-tap screen-space blur whose radius grows outside the focus band.
- Adds mild far-field atmospheric haze, restrained saturation/contrast shaping and a low-strength vignette.
- Keeps pixel art sharpest around the gameplay focus band instead of globally smoothing the image.
- Allocates one reusable output Canvas and recompiles/reallocates only after invalidation or size change.
- Shader compilation/allocation failure falls back locally to the unprocessed 3DWorld Canvas instead of retiring the geometry pipeline.
- No private `src.*` imports, no `engine_internals`, no save writes.

## Engine-contract verification

Gen1Recomp v0.2.32 explicitly defines `worldPresent(canvas, ctx)` as the world-only post-process stage after a custom world pass and before UI composition. The engine accepts only Canvas returns and preserves the previous Canvas when a pass returns an invalid value.

The shader uses the same LOVE shader contract already used by Gen1Recomp v0.2.32 (`love.graphics.newShader`, `vec4 effect(...)`, `Texel(...)`).

## Files

- `packages/kanto_rework_3dworld_hd2d/sol3d/Presentation.lua`
- `packages/kanto_rework_3dworld_hd2d/main.lua`

## Still not validated

- Actual shader compilation on the Windows/OpenGL v0.2.32 build.
- Visual strength at 720p, 1080p and higher resolutions.
- Whether the current fixed vertical focus band tracks the perceived actor plane well enough at all three projection levels.
- GPU cost on integrated graphics and low-power handheld targets.
- Interaction with user-selected full-frame ShaderFX presets.
- Screenshot comparison against vanilla, CP3D01 and the competing Work/Codex branch.

## Acceptance state

Code checkpoint only. **Not SAFE until runtime capture and frame-cost measurements exist.**

## Next

CP3D02B:

1. animated but restrained water material that remains presentation-only;
2. structure/vegetation/actor contact-shadow refinement;
3. avoid adding a second post-process pass unless measurements justify it;
4. preserve the anti-voxel rule: water and shadows must reinforce surfaces, not individual cell cubes.
