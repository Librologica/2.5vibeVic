"""Gallery route, geometry sharing, and independent pixel/pattern contracts."""
import argparse
import ast
from collections import deque
import json
import os
from pathlib import Path
import sys

sys.dont_write_bytecode = True
SDK = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--graphics', choices=['mono', 'multicolor'], required=True)
cli = p.parse_args()
sys.path.insert(0, str(SDK/'src'/cli.graphics/'host'))
from model import *
from scene_contract import validate_scene
work = Path(os.environ['VIBEVIC_WORK'])
sc = json.loads((work/'artifacts/build/auto/scene.json').read_text())
validate_scene(sc)
assert sc['autoRoute'] == [list(row) for row in ROUTE]
assert sc['initial'] == list(INITIAL)
g = sc['grid']
free = {i for i, v in enumerate(g) if not v}
visited = set()
queue = deque([next(iter(free))])
while queue:
    i = queue.popleft()
    if i in visited: continue
    visited.add(i)
    queue.extend(j for j in (i-1, i+1, i-32, i+32) if j in free and j not in visited)
assert visited == free
pose = tuple(sc['initial'])
trajectory = [pose]
for key, duration in sc['autoRoute']:
    for _ in range(duration):
        angle = (pose[2]+(2 if key&8 else 0)-(2 if key&4 else 0))&511
        intended = (pose[0]+round(6*DIR[angle]['x']), pose[1]+round(6*DIR[angle]['y']), angle)
        pose = simulation(g, pose, key)
        assert pose == intended and clear(g, *pose[:2]), 'gallery route collision'
        trajectory.append(pose)
assert pose == tuple(sc['initial'])

def functions(path):
    return {n.name: ast.dump(n, include_attributes=False) for n in ast.parse(path.read_text()).body if isinstance(n, ast.FunctionDef)}
f0 = functions(SDK/'src/mono/host/model.py')
f1 = functions(SDK/'src/multicolor/host/model.py')
for name in ('fixed', 'geometric', 'hit_face', 'clear', 'simulation', 'scene', 'validate'):
    assert f0[name] == f1[name], name
if cli.graphics == 'mono':
    tile = [[1-((WALL_DITHER[y]>>(7-x))&1) for x in range(8)] for y in range(8)]
    assert all(sum(row) == 2 for row in tile)
    assert all(sum(tile[y][x] for y in range(8)) == 2 for x in range(8))
    assert all(not(tile[y][x] and (tile[y][(x+1)%8] or tile[(y+1)%8][x])) for y in range(8) for x in range(8))
pixels = 0
for top in range(49):
    for side in (0, 1):
        pat = strip(top, side)
        for y in range(96):
            if cli.graphics == 'mono':
                expected = 0 if y < top else (WALL_DITHER[y&7] if side else 255) if y < 96-top else (0xaa if y%2 == 0 else 0x55)
                assert pat[y] == expected
            else:
                for x in range(4):
                    expected = 0 if y < top else (2 if side else 3) if y < 96-top else int((x+y)%2 == 0)
                    assert (pat[y]>>(6-2*x))&3 == expected
for pose in trajectory[::80]:
    fb, rays = framebuffer(g, pose)
    tops = edge_tops(g, pose, rays)
    width = 128 if cli.graphics == 'mono' else 64
    for y in range(96):
        for x, top in enumerate(tops):
            side = rays[x//(4 if cli.graphics == 'mono' else 2)][1]
            if cli.graphics == 'mono':
                actual = (fb[(y//8)*128+(x//8)*8+(y&7)]>>(7-(x&7)))&1
                expected = 0 if y < top else (((WALL_DITHER[y&7]>>(7-(x&7)))&1) if side else 1) if y < 96-top else int((x+y)%2 == 0)
            else:
                actual = (fb[(y//8)*128+(x//4)*8+(y&7)]>>(6-2*(x&3)))&3
                expected = 0 if y < top else (2 if side else 3) if y < 96-top else int((x+y)%2 == 0)
            assert actual == expected
            pixels += 1
report = dict(freeCells=len(free), connected=True, ticks=len(trajectory)-1,
              loopExactClosure=True, blockedMovementTicks=0, stripCases=98, pixelsChecked=pixels)
(work/'artifacts/trajectory.json').write_text(json.dumps(trajectory))
(work/'artifacts/scene-checks.json').write_text(json.dumps(report, indent=2))
print(report, flush=True)
