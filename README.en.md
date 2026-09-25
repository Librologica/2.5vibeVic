# 2.5vibeVic 1.0.0

A standalone native VIC-20 2.5D pipeline derived from the qualified 3Dvibe64
raycast-stock experiment. It is not the complete 3Dvibe64 polygon engine and
does not require or modify a 3Dvibe64 installation.

## Target and graphics

VIC-20, documented 6502 instructions, VIC-I, **24 KB expansion in blocks 1/2/3**,
PAL or NTSC detected at startup. No acceleration or external processing.
The unexpanded VIC-20 is **not supported**.

| Build selection | Logical image | Walls | Floor |
|---|---:|---|---|
| `mono` | 128×96, 1 bit/pixel | white and a balanced static 75% white pattern | black/white checker |
| `multicolor` | 64×96, 2 bits/pixel | solid cyan/light cyan | black/blue checker |

Both modes occupy the same 128×96 physical VIC-dot viewport, using 16×12
character cells. The glyph data is rewritten as a framebuffer, not a fixed
library of block shapes. Multicolor trades horizontal detail for four colors;
only its floor is dithered. The mode is chosen at build time, not by a runtime key.

## Included

- Real grid DDA: 32 perspective rays, 60° field of view, 512 yaw directions.
- Guarded edge refinement within one continuous wall surface.
- Single-level 32×32 binary map, uniform wall height, fixed camera height.
- Fractional movement, collision sliding and 50 Hz logical simulation.
- Two screen/charset buffers; only complete views are published in the border.
- One gallery environment, automatic and interactive demos in both graphics modes:
  **four PRGs, their complete generated assembly, map data and JSON sources**.
- Portable host builder, numerical reference, regression scripts, memory and assembly guides.

The gallery tour lasts 100.32 logical seconds and loops without teleporting.
Interactive controls: **W/S** forward/backward, **A/D** turn; reset to exit.
Joystick input exists, but has not been physically qualified. No on-screen text
or FPS overlay is provided; the complete-frame counter is available in RAM.

## Build

Install Python 3.10+ and 64tass, then from this directory:

```text
python -B build.py --graphics mono --run auto --out ../vic-mono-auto
python -B build.py --graphics multicolor --run interactive --out ../vic-color-interactive
```

Outputs must be new directories outside the SDK. `TASS64_EXE` can override the
assembler found in PATH. No Python dependencies are needed for ordinary builds.
See [Quick start](QUICKSTART.en.md), [scene format](docs/SCENE.en.md),
[pipeline](docs/PIPELINE.en.md), [memory](docs/MEMORY.en.md),
[assembly guide](docs/ASSEMBLY-GUIDE.en.md) and [tests](TESTING.en.md).

## Scope and measured results

No textures, polygon meshes, dynamic lighting, variable wall heights, lintelled
doors, stacked floors, ramps or look-up/down. Passages are full-height gaps in
the map. Wall contrast depends on wall orientation, not a movable light.

Gallery automatic path, xvic 3.10 stock, 20 emulated seconds after 2 seconds
warm-up, two repetitions: mono **8.15 FPS PAL / 7.40 NTSC**, multicolor
**8.45 PAL / 7.65 NTSC**. These are window averages, not a minimum frame rate
or a claim about every map. See [qualification](docs/QUALIFICATION.en.md).
**Real hardware has not been tested.** PAL/NTSC emulation is qualified separately.

## License

Copyright © 2026 librologica.digital. Code, scene data and generated demos:
PolyForm Noncommercial 1.0.0. Documentation: CC BY-NC 4.0. Commercial use requires
a separate license. External tools and ROMs are not distributed. See
[LICENSE](LICENSE), [documentation terms](LICENSE-DOCUMENTATION.md), [NOTICE](NOTICE.md).
