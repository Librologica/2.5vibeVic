# Reproducible qualification

Use a clean extracted SDK and a **new external output directory**. The SDK itself
must not change. Python bytecode writes are disabled by the public build/test entry
points; use `-B` for direct commands. Optional dependencies: `pip install -r requirements-tests.txt`.

```text
python -B scripts/verify_package.py
python -B scripts/run_tests.py --out ../vic-host-tests
python -B scripts/run_tests.py --out ../vic-native-tests --native --tour
```

`--graphics mono` or `--graphics multicolor` restricts numerical/native testing;
the public contract still rebuilds all four references. Without `--native` the
native checks are explicitly NOT RUN. `--tour` adds complete-route PAL/NTSC captures.
64tass is required for builds, xvic for native tests. `TASS64_EXE` and `XVIC_EXE`
override PATH tools. Missing dependencies/failing processes cause a nonzero exit,
not a qualification PASS. Native monitor syntax is qualified against VICE 3.10.

The suite runs:

- 14 public contracts: schema, invalid values, source-tree output rejection,
  four exact PRG hashes and generated memory boundaries.
- Per mode: 171 camera poses / 5,472 rays / 342 charset buffers on the actual
  assembled 6502 instructions via py65; 4,000 randomized simulation ticks.
- All 2,401 top-height pairs and 10 discontinuity guards per mode.
- Independent per-sample checks for 98 strips and 63 gallery tour poses;
  map connectivity, collision-free movement and exact 5,016-tick route closure.
- Per mode/native standard: 120 consecutive complete views plus 16 full-tour
  sample views when requested. Compare descriptors, depth, latched pose, screen,
  charset, Color RAM, VIC registers and logical simulation trajectory.
- Four scanouts per mode (both buffers, PAL/NTSC); two independent multicolor
  code-band calibrations. Full visible pixels, not Screen RAM alone.
- Five keyboard states per standard/mode: none, W, S, A, D, using native matrices.

Benchmark: automatic scene, stock VIC-20 +24KB, 2 seconds warm-up followed by
20 seconds, two repetitions per mode/standard. Warp speeds the host test only;
FPS uses complete publications and emulated clocks. Native trace points add no
guest profiler instructions. Duplicate monitor trace/break records are deduplicated.
IRQ accounting includes native entry/exit overhead. Raw traces, dumps, snapshots,
captures and JSON metrics are written exclusively to the external test directory.

Numerical criterion: assembly/fixed model exact; continuous non-corner depth error
must remain below 0.2 cell (observed maximum 0.0703125). Exact grid-corner/side
ambiguities are listed separately, never folded into a hidden tolerance.
Frame and tick counters wrap at 65536; supplied tests finish before that boundary.

On real hardware test separately: correct 24KB mapping and loading, both standards
where available, both graphics modes, continuous tour through its restart,
keyboard/joystick, no tearing and stable floor pattern. Photograph/capture and
record machine/video/expansion details. Emulator PASS does not establish hardware PASS.
