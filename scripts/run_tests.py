"""Run tests against external clean builds; never write inside the SDK."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys

sys.dont_write_bytecode = True
SDK = Path(__file__).resolve().parents[1]


def run(command, env):
    subprocess.run(command, env=env, cwd=SDK, check=True)


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--out', type=Path, required=True, help='new external directory')
    p.add_argument('--graphics', choices=['all', 'mono', 'multicolor'], default='all')
    p.add_argument('--native', action='store_true', help='VICE PAL/NTSC RAM, scanout, keyboard, 2x20s benchmarks')
    p.add_argument('--tour', action='store_true', help='also test a full 100.32-second automatic tour in VICE')
    a = p.parse_args()
    out = a.out.resolve()
    if out.exists() or out == SDK or SDK in out.parents:
        p.error('--out must be new and outside the SDK')
    out.mkdir(parents=True)
    env = dict(os.environ, PYTHONDONTWRITEBYTECODE='1')
    run([sys.executable, '-B', '-m', 'unittest', 'discover', '-s', str(SDK/'tests'), '-v'], env)
    modes = ['mono', 'multicolor'] if a.graphics == 'all' else [a.graphics]
    for graphics in modes:
        work = out / graphics
        env['VIBEVIC_WORK'] = str(work)
        for mode in ['auto', 'interactive']:
            b = work / 'artifacts/build' / mode
            run([sys.executable, '-B', str(SDK/'build.py'), '--graphics', graphics,
                 '--run', mode, '--out', str(b)], env)
        host = SDK / 'src' / graphics / 'host'
        # Host route and pattern verification also produces the numeric pose list.
        run([sys.executable, '-B', str(SDK/'scripts/check_scene.py'), '--graphics', graphics], env)
        for script in ['test_numeric.py', 'test_edges.py']:
            run([sys.executable, '-B', str(host/script)], env)
        if a.native:
            for script in ['qualify.py', 'test_native_io.py']:
                run([sys.executable, '-B', str(host/script)], env)
        if a.tour:
            run([sys.executable, '-B', str(host/'test_tour.py')], env)
    result = dict(graphics=modes, host='PASS', native='PASS' if a.native else 'NOT RUN',
                  fullTour='PASS' if a.tour else 'NOT RUN', hardware='NOT TESTED')
    (out/'results.json').write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(result))


if __name__ == '__main__':
    main()
