# Roadmap

## P0 — Technical validation

- load an independent mod on the official Gen1Recomp release line;
- render a modern shell over one supported native screen;
- preserve keyboard and controller ownership;
- register pointer hit regions and test left click, right click, hover, wheel, and touch;
- persist one theme profile;
- display and move one overlay widget;
- render one external static or animated sprite source;
- prove safe fallback to the native UI;
- document every use of engine internals and its failure mode.

Exit criterion: no production UI work begins until these capabilities are demonstrated or explicitly downgraded.

## P1 — Core and native UI

- shared tokens and components;
- focus and input model;
- adaptive layouts for 16:9, 9:16, and 10:9;
- dialogue and modal framework;
- main menu;
- Party and Pokémon details;
- Bag;
- Pokédex;
- PC;
- Options and UI settings;
- map;
- Link and secondary native screens;
- Classic and modern theme profiles.

## P2 — Battle and companion

- common battle HUD for Classic and 3D/Voxel presentation;
- move details, effectiveness, types, HP, and status popup;
- environmental Classic battle backgrounds;
- quick last Ball and last item actions;
- movable companion widgets;
- overlay editor and saved profiles;
- favorites and registered-item widgets;
- map overlay;
- explicit adapters for Vortex Useful 2 and DramaticShapeVoxelMod.

## P3 — System and gameplay extensions

- three save slots and load UI;
- validated quick-save and quick-load behavior;
- native PC and map access from shortcuts;
- capture destination choice;
- evolution and move learning during battle;
- learned-move storage with persistent PP;
- quest registry and journal.

Each gameplay feature ships independently and remains optional.

## P4 — Compatibility expansion

- versioned third-party adapters;
- public author documentation;
- diagnostics for unsupported screens;
- automated compatibility fixtures;
- migration and recovery tests for additional save data.
