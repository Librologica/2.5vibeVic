# Native VIC-20 pipeline

## Frame flow

1. Atomically latch the live camera into a separate render pose.
2. Cast 32 rays through the binary map with fixed-point grid DDA.
3. Correct hit distance perpendicular to the camera plane; select wall height and side.
4. Select host-generated vertical strips; refine top/bottom edges only on a shared wall.
5. Compose all 1,536 bytes of the inactive charset and apply sparse edge corrections.
6. Wait for the bottom border, change $9005 and increment the complete-view counter.

The timer IRQ updates the live camera during rendering but never the latched pose,
video pointers or render scratch. No mixed-pose view, alternate-column rendering,
temporal reconstruction or acceleration is used. This is raycasting, not triangle fill.

## Geometry and numeric contract

Map: 32×32, one byte per cell, 0 free and 1 solid. A ray advances to the nearest
next X/Y cell boundary. Exact distance ties choose X first. Axial rays use a $FFFF
reciprocal sentinel for the inactive axis. Additions saturate rather than wrap.
Traversal stops at the first solid cell, at the map boundary, or after 64 steps;
failure is a material-zero descriptor with saturated distance, not an unsafe map read.
The public parser requires a solid map boundary and a collision-safe starting position.

| Quantity | Representation / domain |
|---|---|
| Camera X/Y | unsigned Q8.8 cells; scene position 0..8191, map 0..31 |
| Player collision | square half-width 48/256 cell, tested separately on X and Y |
| Yaw | 9-bit angle 0..511; 0 = +Y; positive rotation toward +X |
| Movement | rounded signed table deltas, maximum 6/256 cell per tick; turn ±2 angle units |
| DDA delta and distance | unsigned 16-bit Q8.8, saturated at 65535 |
| Projection | distance>>4, 1/16-cell bins, 1,024 entries, midpoint sampling |
| Projected top | integer 0..48, bottom boundary 96-top |

For ray c, the host computes `round(atan(((2*c+1)/32-1)*tan(30°))*512/(2*pi))`.
Thus rays use a perspective camera plane, not uniform angular spacing. Direction
reciprocals are rounded on the host. Products use the inherited exact quarter-square
multiply; distance correction uses the precomputed cosine and integer truncation.
The host fixed model matches the executed 6502, while a separate geometric oracle
enumerates grid-plane intersections. Fixed quantization and corner ambiguities are
reported separately; it is not a claim of exact continuous geometry.

Height is host-generated from the horizontal focal length `64/tan(30°)`, wall
half-height 1 cell and the distance-bin midpoint. There are 49 strip heights per side.
Near walls clip symmetrically to the viewport; no texture is being stretched.
Strips beyond the table range use its final entry. Map-scale geometry fits the
useful depth range. The material byte means only solid/free here. No texture U/V,
mesh or dynamic lighting computation is emitted.

## Edge refinement and strips

Each ray stores a wall key `(hitPlane*4)|(side*2)|normalSign` and along-wall cell.
Adjacent rays may interpolate only if both hit, their keys match and their along-wall
cells differ by at most one. This prevents blending different planes or opposite
sides and most opening boundaries; it cannot recover geometry missed by 32 rays.

Mono initially assigns four pixels/ray; interpolation uses weights 1/8, 3/8, 5/8,
7/8 between ray centres. Multicolor assigns two samples/ray and uses 1/4, 3/4.
Top heights are rounded to nearest integer with half ties toward positive infinity;
bottoms mirror them. LUTs cover differences -48..48. Only changed samples enter
the sparse patch queue (maximum 124 mono / 62 multicolor). Exterior endpoint
samples retain the ray result. Vertical occlusion silhouettes remain ray-limited.

Host strips contain ceiling, wall and floor for 96 scanlines. There are 49×2×96
= 9,408 bytes. For each character column the unrolled compositor takes the high
nibble of one strip and the low nibble of the adjacent strip, ORs them and stores
one glyph row byte. It fills both possible draw destinations with separate generated
paths. The sparse correction stage then adjusts only the boundary samples.

## VIC-I representation

16×12 cells use character codes 0..191. A full image is 192×8 = 1,536 charset
bytes. Screen codes remain fixed; charset data is dynamic. Two screen/charset pairs
are published using $9005=$DC/$FE. Color RAM is initialized once. This is a
software framebuffer carried by character graphics, **not a VIC-II bitmap mode**.

Mono uses normal high-resolution characters, Color RAM 1 and $900F=$08. Two
actual colors are black and white. The shaded orientation uses the balanced
8×8 bytes `77 DD 7B EE BB ED B7 DE`: 75% white, two black pixels per row and
column, no horizontally/vertically adjacent black pixels even across tile boundaries.
The floor alternates $AA/$55. Patterns are static, anchored to screen coordinates.

Multicolor uses Color RAM $0B, $900E=$B0 and $900F=$68:

| Code | Register/source | VIC color |
|---|---|---|
| 00 | background | blue 6 |
| 01 | border | black 0 |
| 10 | individual character color | cyan 3 |
| 11 | auxiliary color | light cyan 11 |

Each two-bit sample occupies two physical horizontal dots. Walls use only codes
10/11, without dithering. The floor alternates codes 00/01 ($44/$11 scanlines).
The border-color field and individual color are limited to 0..7; background and
auxiliary fields permit 0..15. The public 1.0.0 palette is fixed. Color appearance
depends on the VIC model/emulator palette; PAL blue can appear violet. VIC-I has
no intermediate neutral gray entries. Auxiliary volume bits are zero.

## Timing, input and publication

Startup measures the raster wrap only after leaving raster zero. VIA2 timer drives
approximately 50 logical ticks/s: PAL 1,108,405 Hz with reload 22,166; NTSC
1,022,727 Hz with reload 20,453. Each tick updates input and performs one bounded
collision-tested movement. Speed is independent of rendering FPS, within timer accuracy.

The native KERNAL IRQ entry saves registers; the custom handler through $0314
restores them and returns without executing the normal KERNAL tick. VIA keyboard
scanning is transposed relative to the original CIA code. W/S/A/D are qualified
using native VICE keyboard matrices. Hardware joystick remains unverified.

Publication waits for $9004≥126 (raster 252 or later). The timer IRQ does not
change VIC pointers. Only after the inactive image is complete is $9005 changed.
There is no artificial FPS limiter beyond safe presentation. At low FPS, pose-to-display
latency includes a full rendering interval. No FPS overlay or textual split is present.

## Provenance and limits

`reference/raycast.asm`, `simulation.asm`, `multiply.asm` retain the original
standalone DDA/simulation source. The emitter removes the old 80-ray UV/texture
output and substitutes VIC-I addressing/input. Native video/IRQ/edge code is in
`asm/runtime.asm` and `edges.asm`. Mono and multicolor sources are deliberately
isolated to preserve their qualified bytes. Generated demo ASM is the authoritative
code actually assembled; unused original UV labels in input templates are not
evidence of texture support in the PRG.

No programmable wall heights, lintels, multilayer visibility, portals, polygon
clipping, dynamic light, textures, sprites, perspective-correct surfaces or audio
playback. No runtime graphics-mode switch. Memory headroom is small; extending
the renderer requires a separate qualification, not merely increasing scene constants.
