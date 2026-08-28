# CPHD2D02 — Semantic diorama

Date: 2026-08-28  
Branch: `experiment/chatgpt-sol-hd2d-world`  
Status: **HEADLESS VALIDATED — LIVE LOVE / VISUAL VALIDATION REQUIRED**

## Intent

Move the parallel ChatGPT HD2D renderer from a projected-map proof toward an actual 3DWorld / HD-2D diorama while keeping the branch data-derived and independent from authored per-map scene profiles.

The visual target remains a Pokemon/Kanto world presented with modern HD-2D depth, atmosphere and readable pixel characters. This checkpoint deliberately rejects voxel geometry and a simple tilted 2D-map treatment.

## Baseline architecture retained

- Gen1Recomp remains the sole gameplay authority.
- The renderer never writes collision, scripts, warps, encounters, save data or entity movement.
- Original/current map rendering remains the material source.
- Player/NPC/follower art remains upright engine-resolved pixel billboards.
- Connected maps use the engine's loaded neighbour maps and offsets.
- Renderer failure or unsupported presentation features degrade to the normal world/fallback path.

## New semantic world interpretation

`MaterialClassifier` now groups blocked cells into connected masses and derives presentation families from runtime evidence:

- `structure` — connected blocked mass adjacent to a real traversal threshold;
- `vegetation` — repeated blocked collision-tile motif in a natural `OVERWORLD` / `FOREST` tileset;
- `boundary` — substantial mass touching the map edge;
- `landmark` / `mass` — dense generic raised terrain;
- `obstacle` — small isolated blocked footprint.

Structure detection wins over vegetation. No `PALLET_TOWN` map id or authored block-id list is required by this classifier.

Vegetation promotion requires both natural tileset context and repeated local tile evidence. The same topology under `CAVERN` is explicitly gated not to become vegetation.

## Continuous geometry

Raised cells from the same mass are merged into horizontal surface/front runs. The renderer therefore uses the cell grid as source evidence rather than exposing every cell as an independent cube.

Connected neighbour maps participate in the same relief pass.

## Architecture cues

A runtime-derived `structure` now receives:

1. continuous raised facade;
2. real warp-derived doorway opening;
3. restrained continuous eave;
4. one continuous contact shadow per visible frontage;
5. a coherent gabled roof when the connected footprint is sufficiently dense.

The roof footprint comes from the mass bounding box. Height and overhang come from the active projection preset. Roof tones come from the current runtime map palette rather than an authored Pallet colour table.

The roof does not alter the gameplay footprint and cannot create a new traversable area.

## Vegetation cues

Runtime-derived `vegetation` receives:

- a darker continuous canopy apron rather than a vertical block wall;
- two shallow crown layers re-sampled from the original/current terrain source;
- continuous contact grounding;
- no per-cell trunk/cube stack.

The intent is a landscape mass that preserves source pixel breakup while reading spatially.

## Water and contact planes

Water is rendered as a continuous recessed plane reusing the engine-rendered water material, with exposed bank geometry only where the body ends toward the camera.

Actors, local water highlights and world FX resolve against the same water contact Z. Ledge hops convert the engine `pose()` hop state into true vertical presentation lift while their shadows stay on the ground contact plane.

## Depth composition

Raised terrain rows and upright actors share one baseline-Y painter order. This allows structures/vegetation in front of an actor to occlude it while near actors remain in front of farther terrain.

Tall-grass foreground redrawing occurs at the actor's painter depth instead of as a global overlay.

## World-only HD-2D atmosphere

The pipeline now implements `worldPresent`, which Gen1Recomp applies before menus/dialogues composite.

The pass is intentionally restrained:

- HD2D: effectively sharp gameplay presentation with very low blur;
- DEPTH: visible near/far separation;
- CINEMA: strongest permitted focus separation;
- far-field haze only;
- low-strength vignette;
- no full-frame UI blur;
- no chromatic aberration;
- no film grain.

The optical focus band follows the projected player ground baseline when complete world context is available. It falls back to the preset focus point if that context is missing.

A corrected, well-defined GLSL `smoothstep` is used for far haze; inverted `smoothstep` bounds are not used.

If shader creation is unavailable or fails, the world canvas is returned unchanged. Atmosphere is optional and cannot retire the geometry renderer by itself.

## Validation

Latest gated code checkpoint before this documentation commit:

`b51fb22bfdabf7fb37cbbab71e57f6a224296dd4` — `test(hd2d): gate roofs shadows and player focus`

GitHub Actions run `33182364581` completed successfully on both jobs:

1. **Lua 5.1 syntax + pure contracts — PASS**
   - package Lua compile check;
   - manifest validation;
   - projection/material contracts;
   - structure/obstacle hierarchy;
   - data-derived vegetation family;
   - CAVERN non-vegetation guard.

2. **Gen1Recomp v0.2.32 loader + synthetic world — PASS**
   - official loader accepts package;
   - world pipeline remains eligible;
   - active + connected-map terrain capture;
   - connected semantic relief;
   - continuous surface runs;
   - warp-derived doorway;
   - continuous architectural eave;
   - layered vegetation canopy;
   - continuous semantic-mass contact shadow;
   - coherent gabled roof;
   - recessed water plane;
   - unified terrain/actor depth composer;
   - water actor contact plane;
   - airborne hop tracking;
   - tall-grass priority;
   - field-FX bridge;
   - no-shader atmosphere bypass;
   - simulated shader fold and uniform contract;
   - player-derived focus band.

The simulated shader test does **not** prove real GLSL compilation or visual quality. It only proves the pipeline/fold/uniform contract under the headless harness.

## Not claimed

This checkpoint does not claim:

- a live graphical LÖVE screenshot has been accepted;
- the generated roofs correctly classify every Kanto building;
- every repeated OVERWORLD/FOREST collision motif is vegetation;
- the shader has been compiled on the user's actual GPU/runtime;
- the current blur/haze strengths are visually final;
- the result already matches the visual quality bar of the intended HD-2D references.

Those require live visual evidence.

## Live validation gate

Use Gen1Recomp v0.2.32 with only this experimental world renderer enabled and capture the same save position at the same window size for:

1. `HD2D`;
2. `DEPTH`;
3. `CINEMA`.

Primary scene: Pallet Town exterior, positioned so at least one building, tree/vegetation mass, path and the southern water/connection region can be assessed.

Validate in motion as well as still frame:

- building silhouette reads as architecture rather than raised tiles;
- roofs do not occlude near actors incorrectly;
- vegetation reads as a continuous landscape mass;
- player remains crisp inside the focus band;
- foreground/background blur remains subordinate to geometry;
- water is visibly lower without looking like a trench;
- Pallet ↔ Route 1 transition has no relief seam;
- tall grass, hops, surf and field FX remain correctly anchored;
- menus/dialogues remain crisp;
- disabling the mode returns to the standard renderer without gameplay-state change.

## Decision after screenshots

Only after like-for-like screenshots should the branch tune camera compression, relief heights, roof pitch, canopy height, haze and blur. Changing those values before live evidence would be visual guesswork.
