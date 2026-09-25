"""2.5vibeVic 1.0.0 public build entry. PolyForm Noncommercial 1.0.0.
Copyright 2026 librologica.digital. No runtime renderer changes at packaging.
"""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'scripts'))
from scene_contract import validate_scene


def external_output(path):
    out = Path(path).resolve()
    if out == ROOT or ROOT in out.parents:
        raise ValueError('--out must be outside the SDK source tree')
    if out.exists():
        raise ValueError('--out must be a new directory; existing output is never overwritten')
    return out


def main():
    parser = argparse.ArgumentParser(description='Build native VIC-20 +24KB demo')
    parser.add_argument('--graphics', choices=['mono', 'multicolor'], required=True)
    parser.add_argument('--run', choices=['auto', 'interactive'], default='interactive')
    parser.add_argument('--scene', type=Path, default=ROOT / 'examples/galleries.json')
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    try:
        out = external_output(args.out)
        scene_path = args.scene.resolve()
        sc = json.loads(scene_path.read_text(encoding='utf-8-sig'))
        validate_scene(sc)
        host = ROOT / 'src' / args.graphics / 'host'
        sys.path.insert(0, str(host))
        spec = importlib.util.spec_from_file_location('vibe_emitter', host / 'build.py')
        emitter = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(emitter)
        emitter.build(args.run, scene_path, out)
        report = json.loads((out / 'build.json').read_text())
        report.update(product='2.5vibeVic', version='1.0.0', graphics=args.graphics,
                      logicalResolution=[128 if args.graphics == 'mono' else 64, 96],
                      expansionKB=24, cpu='6502', rays=32)
        (out / 'build.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
        print('PRG:', out / 'vibe20.prg')
    except (ValueError, KeyError, OSError, RuntimeError) as exc:
        parser.exit(1, f'Build rejected: {exc}\n')


if __name__ == '__main__':
    main()
