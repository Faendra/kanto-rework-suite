# Kanto Rework Suite Changelog

## 0.1.0-candidate.3 — Live Mockup Editor restoration and extension

### Restored
- Restored direct access to the battle Live Mockup Editor from an active KRS battle.
- Preserved the existing Mods utility preview path and the production BattlePresenter renderer pipeline.

### Added
- Live composition controls for Player Pokémon, Enemy Pokémon, Battle Background, Enemy Info Box, Player Info Box, Battle Action Menu, and Move Selection + description.
- Independent Pokémon X/Y, battle-only scale, direct drag, fine/coarse adjustment, reset and lock.
- Aspect-preserving Battle Background zoom/crop plus X/Y framing offsets.
- Resizable responsive settings window with scroll and minimum usable dimensions.
- Numeric values are display-only; editing now uses sliders, drag, nudge/buttons and reset rather than free numeric typing.
- Explicit background spatial metadata and a suggestion-only Pokémon size/placement assistant.
- Explicit Save Changes, Discard Unsaved, per-element reset, scene reset and dirty-exit protection.

### Architecture
- Core remains unchanged.
- Graphics owns background spatial metadata, Pokémon presentation configuration and placement suggestions.
- UI owns editor interaction, composition offsets and production battle UI placement.
- Battle Animations continues to consume live battler bounds/anchors and remains a separate internal module.

### Validation
- 130/130 headless Lua tests passed before release preparation.
- 266/266 Lua syntax checks passed before release preparation.
- 72/72 canonical Battle Backgrounds validated at 1920x950.
- Internal dependency graph: 7 modules, 0 cycles.
- Real Gen1Recomp/OpenGL/controller/user acceptance remains NOT TESTED in this workspace.

### Known limitations
- Placement suggestions are heuristics and still require visual tuning in the real game.
- Unknown/mod-authored backgrounds use neutral spatial metadata until explicitly authored.
- Graphics/UI persistence spans two owner services; rollback is compensating rather than engine-atomic.

## 0.1.0-candidate.2
- Consolidated single-install Kanto Rework Suite Candidate with Battle Animations 0.1.7.
