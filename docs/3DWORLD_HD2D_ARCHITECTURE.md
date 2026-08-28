# KRS — 3DWorld / HD2D parallel renderer

Status: experimental parallel branch
Branch: `experiment/sol-3dworld-hd2d`
Engine target: Gen1Recomp `v0.2.32`
Baseline caveat: this Git branch starts from the public remote `main` at Candidate.3. Candidate.9 remains the newer recovered KRS artifact and must be used later as the integration target. Nothing in this branch is allowed to overwrite Candidate.9 or `main`.

## 1. Goal

Build a Kanto overworld that is genuinely spatial while keeping the Gen 1 pixel-art language:

- 3D depth and elevation for terrain and structures;
- original/current overworld sprites as upright billboards;
- camera and composition inspired by modern HD-2D, without reproducing Octopath Traveler, Pokemon Gamma Emerald, or another game's exact look;
- no voxel asset pipeline as the primary representation;
- no rewrite of collision, scripts, encounters, warps, save data, NPC logic or field actions;
- immediate vanilla 2D fallback when the renderer is disabled, unavailable or fails.

The renderer is a presentation layer, not a second game engine.

## 2. Why this route

Gen1Recomp v0.2.32 exposes the public `render_pipelines` registry. A `drawWorld(ctx)` callback may own only the overworld world pass while the engine keeps UI composition, persistence, mode switching and failure isolation. `worldPresent` can later apply world-only post-processing without blurring menus/dialogue.

The same public pipeline context supplies field-FX composition and the current overworld state. `Player:pose`, `NPC:pose`, `SpriteRenderer:getPoseGeometry` and `SpriteRenderer:resolveImage` are designed to let a custom renderer reuse the engine's current sprite frame and palette resolution.

This removes the architectural reason to patch the private Voxel renderer.

## 3. Rendering model

### 3.1 Terrain

The first implementation is a continuous semantic heightfield derived from the read-only `mod.world:mapOverview()` contract:

- walkable cell: ground plane;
- water cell: recessed plane;
- blocked cell: raised mass;
- warp cell: ground plane with no gameplay mutation;
- `tileDetailRows`: four-shade local luminance used only to modulate material value.

Cells are not rendered as independent cubes. Adjacent cells of the same height read as one surface; side faces are emitted only across a height discontinuity. This is the first anti-voxel rule.

Later passes can replace the semantic height estimator with authored map/tileset profiles without changing the renderer contract.

### 3.2 Characters

Characters remain pixel art. They are upright camera-facing billboards textured from the engine's resolved sprite image, using the engine-selected pose and flip. Terrain and actors share one depth sort so foreground raised geometry can occlude actors behind it.

### 3.3 Camera

The pilot camera is an oblique/isometric projection centered on the live player position. Pipeline levels intentionally change presentation rather than gameplay:

- `OFF`: vanilla Gen1Recomp;
- `HD2D`: restrained relief;
- `DEPTH`: stronger terrain separation;
- `CINE`: deeper oblique composition.

A later checkpoint may add camera easing and authored per-map framing.

### 3.4 Field effects

`ctx.drawFx(project, scale)` remains engine-owned. The renderer gives it the same world-to-screen projection used for geometry. Heal effects, emotes, fishing, Fly and other supported field FX therefore do not need to be forked.

## 4. Architecture

```text
Gen1Recomp gameplay/world
        |
        | public API / render pipeline context
        v
WorldAdapter
  - mod.world:current()
  - mod.world:mapOverview()
        |
        v
Projection
  - world/cell -> screen
  - camera framing
        |
        v
Renderer
  - semantic heightfield
  - discontinuity side faces
  - depth-sorted billboards
  - engine field FX
        |
        v
Canvas returned to render_pipelines
        |
        +--> success: KRS 3DWorld image
        +--> nil/error/unavailable: vanilla 2D
```

## 5. Compatibility rules

1. No write to save data for visual state.
2. No `require("src....")` from the mod.
3. No `engine_internals` permission in the manifest.
4. Read gameplay through public `mod.world` APIs.
5. Use only the renderer pipeline context for presentation objects explicitly supplied to pipelines.
6. Keep the package independently removable.
7. Never make KRS Core/UI depend on this renderer.
8. Candidate.9 integration happens by transplant/rebase after the renderer spike is proven, not by pretending the stale GitHub base is current.

## 6. External-reference policy

`kanto-first-person` and `potato_voxel` are reference material only for this branch. No source or asset is copied from either repository. The renderer is implemented independently on Gen1Recomp's public rendering contract.

## 7. Pilot acceptance criteria

CP3D00 foundation:

- package loads on Mod API 2;
- pipeline appears as a display mode;
- OFF path is unchanged;
- `drawWorld` returns a valid window-sized Canvas;
- active map terrain is represented with depth;
- player and active NPC sprites use current engine pose/palette data;
- field FX can be composited through `ctx.drawFx`;
- renderer failure returns to vanilla 2D.

CP3D01 visual pilot:

- Pallet Town chosen as first exterior reference map;
- authored terrain/material classification for grass, path, water, trees and buildings;
- coherent building silhouettes rather than generic blocked-cell plateaus;
- camera easing;
- no visible per-cell cube grid;
- screenshots captured at the three enabled levels.

CP3D02 HD-2D presentation:

- world-only depth haze/DOF prototype through `worldPresent`;
- contact shadows and water treatment;
- map-edge/connection continuity;
- performance budget and cache strategy.

CP3D03 KRS integration:

- transplant onto the actual Candidate.9-or-newer KRS baseline;
- KRS settings/theme integration;
- regression pass with menus, battle transitions, warps and save/load;
- no dependency from core packages back to the renderer.

## 8. Current limitations

CP3D00 is a technical renderer foundation, not the target artwork. `mapOverview()` intentionally exposes semantic terrain and reduced tile shading, so blocked cells cannot yet distinguish a tree from a building. That distinction belongs in CP3D01's authored map/tileset classification layer.

Runtime validation on an actual Gen1Recomp v0.2.32 build is still required before CP3D00 can be marked SAFE.
