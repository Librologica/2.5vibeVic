# Quick start

## Run a supplied demo

Use VICE **xvic**, not x64sc. Configure 24 KB expansion: RAM blocks **1, 2 and 3**
at $2000–$7FFF. Leave the 3 KB block and block 5 disabled for the qualified setup.
Select PAL or NTSC. VICE's general RAM reset-pattern page does not select expansion:
use the VIC-20 memory expansion controls, or the command line below.

```text
xvic -default -pal -memory 24k -autostartprgmode 1 demos/galleries-mono-auto.prg
xvic -default -pal -memory 24k -autostartprgmode 1 demos/galleries-multicolor-interactive.prg
```

Replace `-pal` with `-ntsc` as needed. No warp is necessary for normal viewing.
Each PRG handles both video standards. W/S move, A/D turn. Reset to exit.
Automatic and interactive versions start from the same pose.

On hardware, use an expansion mapping the same three 8 KB blocks, load the PRG
to its saved address ($1201) with a binary load, then `RUN` (BASIC `SYS8192`).
Reset/reload if memory mapping was changed. The demo takes over VIA2 timer/IRQ
and the cassette-buffer area; no tape services are available while it runs.
Verify first on your own hardware; this distribution is emulator-qualified only.

## Build and customize

Install Python 3.10+ and 64tass in PATH (qualified: Python 3.13.14, 64tass 1.60.3243).
Alternatively set `TASS64_EXE` to the assembler executable.

```text
python -B build.py --graphics mono --run interactive --out ../build-vic-mono
python -B build.py --graphics multicolor --run auto --scene examples/galleries.json --out ../build-vic-color
```

Open `vibe20.prg` in the output directory. `vibe20.asm`, `map.bin`, `scene.json`,
`labels.txt`, `listing.txt`, `memory.map`, `build.json` and `assembler.log` accompany it.
Existing directories are never overwritten. Build outside the SDK; copy JSON to
your own project to edit a map/route. See [scene contract](docs/SCENE.en.md).

To assemble the shipped complete source directly, copy one `demos/source` folder
to an external working directory and run there:

```text
64tass -a -B --m6502 -o rebuilt.prg vibe20.asm
```

Keep `map.bin` next to the ASM. Compare against the corresponding shipped PRG.
Do not place generated listings or development artifacts inside this release.
