# P0 Technical Spike

## Purpose

Determine which parts of the product vision can be implemented safely on the official Gen1Recomp release line before committing to full production.

## Test matrix

### 1. Mod boot and lifecycle

- package imports through the official launcher;
- manifest compatibility range is enforced;
- enable, disable, and restart behavior is predictable;
- failure produces a readable diagnostic and leaves the game bootable.

### 2. Rendering and fallback

- cache the live game/state required by the presenter;
- render one modern menu shell at high resolution;
- suppress the classic UI only when the complete visible stack is supported;
- preserve the world render;
- immediately fall back when an unknown modal or screen appears.

### 3. Adaptive layout

Validate the same semantic menu model at:

- 1920×1080 (16:9);
- 1080×1920 (9:16);
- 1600×1440 (10:9);
- intermediate window sizes without losing selection or scroll state.

### 4. Input parity

- keyboard and controller continue to drive the original state;
- last active input source updates action glyphs;
- left click selects and confirms;
- right click returns;
- wheel scrolls only an eligible hovered region;
- touch shares hit regions without hover;
- virtual controls keep capture priority;
- pointer use cannot double-activate an action.

### 5. Movable overlay

- render one independent widget;
- enter edit mode;
- drag, snap, lock, and persist its position;
- restore the same profile after restart;
- maintain a safe area in all three layout classes.

### 6. External artwork

- consume one static external sprite;
- consume one animated sprite descriptor or sheet;
- preserve nearest-neighbor scaling and aspect ratio;
- handle a missing asset without breaking text presentation.

### 7. Interoperability

Test alongside:

- Gen1 Modern UI disabled and enabled;
- Kanto Companion disabled and enabled;
- one category Bag mod;
- one animated/voxel presentation mod.

Conflicts must be detected or documented. Silent draw-stack corruption is unacceptable.

## Evidence required

Every test records:

- Gen1Recomp version and commit/tag;
- enabled mod versions;
- operating system;
- resolution and orientation;
- reproduction steps;
- expected result;
- observed result;
- screenshot or log when relevant;
- stability classification: public API, adapter, experimental, or blocked.

## Exit report

The spike ends with a feasibility matrix for:

- complete UI replacement;
- universal mouse/touch navigation;
- external animated sprites;
- Classic/3D battle switching;
- save slots and quick load;
- in-battle evolution and move learning;
- move storage;
- quest persistence;
- third-party UI routing.
