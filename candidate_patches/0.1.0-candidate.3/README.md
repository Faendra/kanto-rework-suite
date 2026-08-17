# Kanto Rework Suite 0.1.0-candidate.3

This directory records the exact source delta for the battle **Live Mockup Editor** pass.

## Baseline

Apply against the exact distributed package:

- `Kanto_Rework_Suite-0.1.0-candidate.2.zip`
- SHA-256: `8f6eee647e2c807364698f8a35aa55ce577cee6b963540caf2553b63d69e4431`

## Candidate.3

Distribution version: `0.1.0-candidate.3`

Internal diagnostic versions changed by this pass:

- Kanto Rework UI: `0.8.55`
- Kanto Rework Graphics: `0.3.5`

Other internal module versions remain unchanged.

## What changed

The pass restores direct access to the battle Live Mockup Editor and extends it into a scene-composition editor for:

- Player Pokémon position / scale
- Enemy Pokémon position / scale
- Battle Background framing
- Enemy Pokémon Info Box
- Player Pokémon Info Box
- Battle Action Menu
- Move Selection Menu + move description

It also adds:

- responsive/resizable editor settings
- drag + coarse/fine nudging instead of free numeric typing
- per-element reset/lock
- explicit Save / Discard / scene reset
- dirty-exit protection
- Battle Background spatial metadata
- suggestion-only Pokémon size/placement assistant

The production `BattlePresenter` components remain authoritative; the editor does not create parallel battle HUD/menu implementations.

## Patch

`live-mockup-editor.patch` is a unified source patch generated directly from the exact Candidate.2 baseline to Candidate.3 source.

The full installable Candidate.3 package is intentionally not stored in this source directory because the repository does not currently contain the consolidated Suite's large binary asset tree. Distribution remains a ZIP release artifact.

## Validation

Static/headless validation performed before packaging:

- 130/130 Lua tests: PASS
- Lua syntax: PASS
- 72/72 canonical Battle Backgrounds at 1920x950: PASS
- internal dependency graph: 7 modules / 0 cycles
- Candidate.3 ZIP integrity / CRC: PASS
- `manifest.json` first and unique at ZIP root: PASS

Not validated in this workspace:

- real Gen1Recomp/LÖVE runtime
- OpenGL visual acceptance
- physical controller/touch behavior
- user acceptance

Static validation must not be interpreted as runtime validation.
