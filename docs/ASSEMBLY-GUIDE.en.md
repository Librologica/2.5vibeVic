# Source and assembly guide

`build.py` is the public entry point. It checks the strict scene contract and
external output location before loading exactly one backend emitter. Host builds
require only Python's standard library and 64tass; runtime is entirely 6502 code.

| Source, under `src/mono` or `src/multicolor` | Role |
|---|---|
| `host/model.py` | fixed reference, independent continuous oracle, projection/direction/strip tables |
| `host/build.py` | assembly specialization, inherited-code adaptation, assembler and size checks |
| `asm/runtime.asm` | boot, native video, VIA timer IRQ, presentation and strip selection |
| `asm/edges.asm` | same-surface guards, interpolation, sparse framebuffer boundary patches |
| `reference/raycast.asm` | original DDA template, adapted before emission |
| `reference/simulation.asm` | fractional motion/collision template, native input substituted |
| `reference/multiply.asm` | exact unsigned quarter-square multiply |
| `host/test_*.py`, `qualify.py`, `vice.py` | CPU and native test implementations, invoked by the public runner |

The two source trees intentionally duplicate small shared pieces rather than
refactor qualified code while packaging. They are not separate public graphics
engines with different world metrics. Public checks prove their geometry/simulation
functions identical. Do not import both bare `model` modules into one Python
process; the build/test runners isolate them in separate processes.

Important generated entry points: `entry`, `detect_standard`, `init_video`,
`irq`, `simulation_tick`, `latch_pose`, `raycast_all`, `select_strips`,
`prepare_edges`, `compose`, `refine_edges`, `presentation_done`.
`labels.txt` and `listing.txt` expose addresses for a particular build.

Generation removes inherited UV products/output, reduces the descriptor count
to 32, emits native direction loads and replaces CIA keyboard/joystick access
with VIA access. `composer()` emits an unrolled 96-row body for each draw buffer.
This generation is deliberate: the reference ASM files are inputs, not standalone
VIC-20 programs to assemble directly. The fully generated demo source is standalone
apart from its adjacent `map.bin`. Assemble it with `64tass -a -B --m6502`.

No undocumented instructions, no SMC, no ROM patches. The PRG uses the native
KERNAL IRQ entry convention, but does not call BASIC while rendering. Instructions
must remain compatible with 6502; enabling 65C02 opcodes is not an optimization option.
The whole engine owns its documented zero page, video buffers and IRQ. This is
a renderer/demo SDK, not a stable re-entrant application ABI or a complete game engine.

To experiment, make a separate source copy. Changes to a renderer/table may
invalidate hashes and numerical/native contracts: do not rewrite frozen expected
hashes merely to hide a difference. A map/route change is intentional scene data,
but still requires collision, bounds, visual and timing checks for that scene.
There is no dependency on an installed C64 SDK. Do not alter other native releases.
