# 1.0.0 release qualification — 2026-09-25

## Result

**PASS in stock VIC-20 emulation, PAL and NTSC, +24 KB.** The four public PRGs
are byte-identical to the already-qualified mono/multicolor gallery programs.
Packaging changed the host entry point, paths, scene/route validation and public
test harness; neither renderer ASM nor generated runtime behavior changed.

Clean public-runner results:

| Check | Result |
|---|---|
| Public contracts / reference rebuilds | 14/14; all four SHA-256 values exact |
| Executed 6502 versus fixed model | 342 poses, 10,944 rays, 684 framebuffer buffers; zero differences |
| Simulation | 8,000 random ticks total; zero differences |
| Edge interpolation | 4,802 height pairs + 20 guards; zero differences |
| Native views | 544 total: 120 + 16 per backend/standard; zero descriptor/framebuffer differences |
| Native visible scanouts | 8 captures, both buffers and standards; zero visible-pixel differences |
| Independent multicolor calibration | PAL and NTSC PASS, all four bit-pair codes |
| Native keyboard matrices | 20 cases total PASS |
| Full automatic route | 100.32 seconds, exact loop closure, no blocked movement, both standards |
| Continuous geometric oracle | maximum non-ambiguous depth error 0.0703125 cell, below fixed 0.2 bound |
| Corner/side ambiguity | 27 cases per backend retained separately in raw numeric reports |
| Physical machine / physical joystick | **NOT TESTED** |

The native-view total excludes input-source snapshots and color calibration
captures. These are deterministic tests at corresponding poses, not just screenshots
of vaguely similar scenes. Old source/reference files were not updated to hide differences.

## Measured automatic-demo performance

xvic 3.10, 24KB mapping, stock CPU/VIC-I, default native palettes, UI absent.
Two runs per cell; each window contains 20 emulated seconds after 2 seconds warm-up.
Warp is used only to accelerate the host. FPS counts newly published complete views.

| Mode | Standard | Views / 20 s | FPS | Mean cycles/view | p95 | Worst |
|---|---|---:|---:|---:|---:|---:|
| Mono | PAL | 163 | 8.15 | 136445 | 155066 | 155071 |
| Mono | NTSC | 148 | 7.40 | 138013 | 152688 | 153216 |
| Multicolor | PAL | 169 | 8.45 | 131470 | 150846 | 155068 |
| Multicolor | NTSC | 153 | 7.65 | 133170 | 152411 | 152953 |

Table uses repeat 1; repeat 2 has identical publication counts, with small NTSC
interrupt-phase differences (multicolor p95 152420). These are path-window means,
not guaranteed minimums or an average over the complete tour. PAL and NTSC use
different native clock rates. Both are stock, not equal-frequency simulations.

PAL mean phase cycles (IRQ excluded from rendering phases):

| Phase | Mono | Multicolor |
|---|---:|---:|
| Geometry | 68709 | 68762 |
| Strip selection + edge setup | 7964 | 6813 |
| Composition + sparse edge correction | 47983 | 45531 |
| Presentation wait | 7081 | 5825 |
| IRQ including simulation | 4611 | 4443 |

Small phase-sum discrepancies versus frame intervals are loop/latch overhead.
Measured mean latched-pose-to-publication latency: about 123 ms mono PAL and
119 ms multicolor PAL. This is not a separately injected user-input latency test.
No optimizations were introduced during SDK packaging.

## Reproduction and limits

See [TESTING](../TESTING.en.md). Qualified tools: Python 3.13.14, 64tass 1.60.3243,
VICE 3.10, py65 1.2.0, Pillow. Raw dumps/traces and original-inventory checks are
kept outside the public SDK. The SDK includes the scripts needed to reproduce them.
`PACKAGE-MANIFEST.json` identifies permanent files, builder/source hashes and demo
hashes; `MANIFEST.sha256` covers every permanent file except itself.

VIC scanouts inspected: mono balanced wall pattern/floor checker and solid cyan
multicolor walls with floor-only checker. No claim of more geometric detail than
32 rays, zero quantization, or real-machine compatibility proven by physical testing.
