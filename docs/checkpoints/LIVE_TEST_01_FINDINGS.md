# LIVE TEST 01 — Findings

Source: user-provided Pallet Town / Route 1 capture, Gen1Recomp live runtime.

Observed blockers before any second user test:

- natural masses (tree/rock/boundary) still read as generic extrusions;
- opaque dark front faces create black rectangular voids under rows;
- structure roofs span too much collision depth and read as oversized slabs;
- connected-map edge masses can produce tall pillars/triangles at the viewport boundary;
- projection compression leaves excessive exposed backdrop bands in CINEMA.

Action for TEST2:

- stabilize projection framing;
- restrict high side/front faces to architecture;
- render vegetation as upright source-textured canopy edges with no tall pedestal;
- render boundaries/rocks as shallow textured lips, not palette-black walls;
- reduce structural roof depth to a shallow coherent cap;
- preserve gameplay/collision/warp authority unchanged.

Status: correction in progress. Do not request another user test until CI + real-LÖVE synthetic visual gate are green.
