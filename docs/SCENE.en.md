# Scene and world metrics

The complete valid example is [galleries.json](../examples/galleries.json).
No image files or texture importers are involved. The root must contain exactly:

| Field | Contract |
|---|---|
| `schema` | `"2.5vibeVic-scene-v1"` |
| `size` | `[32,32]` |
| `grid` | 1,024 integers 0 or 1, flat row-major array `y*32+x`; all border cells 1 |
| `initial` | `[xQ8.8,yQ8.8,yaw]`; three integers, X/Y 0..8191, yaw 0..511 |
| `wallHeight` | integer 2 cells, fixed in this release |
| `eyeHeight` | integer 1 cell, fixed |
| `fov` | integer 60 degrees, fixed |
| `rays` | integer 32, fixed |
| `autoRoute` | 1..32 commands `[keys,ticks]`; duration 1..65535 at 50 ticks/s |

`keys`: 0 idle, 1 forward, 2 backward, 4 left, 8 right; combinations 5/9/6/10
move and turn simultaneously. Conflicting forward/back or left/right inputs are
rejected. The route loops. It is required even for interactive builds (unused
for automatic input there), so both builds share one source contract. Repeated
motion still obeys collisions; the builder does not promise a user route is
collision-free or closes exactly. The supplied gallery route is tested for both.

Camera X/Y in cells = stored value/256. Yaw 0 looks +Y, 128 +X, 256 -Y, 384 -X.
Grid row zero is the first row in the JSON; no implicit metric scaling or legacy
3D camera conversion applies. Example `[1408,1664,0]` means (5.5,6.5), facing +Y.
The starting square of half-width 48/256 must be clear. All walls share height 2;
the camera remains at height 1. A doorway is only a full-height map gap, not a lintel.

Copy the example outside the SDK, edit cells and route, and supply `--scene`.
Unknown fields, booleans pretending to be integers, invalid dimensions/materials,
blocked starts and out-of-range commands are rejected. There is no silent
precision/ray-count reduction. 64tass also rejects overlap with the fixed memory
layout. Up to 32 route commands is a deliberate public budget, not a promise
that arbitrary new rendering code fits in RAM. Palette is selected by graphics
backend and is not a scene field in 1.0.0.
