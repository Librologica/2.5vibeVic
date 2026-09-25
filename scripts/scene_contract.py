"""Strict public scene contract. Copyright 2026 librologica.digital."""
FIELDS = {'schema', 'size', 'grid', 'initial', 'wallHeight', 'eyeHeight', 'fov', 'rays', 'autoRoute'}


def validate_scene(s):
    if not isinstance(s, dict):
        raise ValueError('scene must be a JSON object')
    if set(s) != FIELDS:
        raise ValueError(f'scene keys: missing {sorted(FIELDS-set(s))}, unknown {sorted(set(s)-FIELDS)}')
    if s['schema'] != '2.5vibeVic-scene-v1':
        raise ValueError('schema must be 2.5vibeVic-scene-v1')
    if s['size'] != [32, 32] or any(type(v) is not int for v in s['size']):
        raise ValueError('size must be [32,32]')
    g = s['grid']
    if not isinstance(g, list) or len(g) != 1024 or any(type(v) is not int or v not in (0, 1) for v in g):
        raise ValueError('grid must contain exactly 1024 integer 0/1 cells, row-major')
    if any(g[y*32+x] != 1 for y in range(32) for x in range(32) if x in (0, 31) or y in (0, 31)):
        raise ValueError('all map borders must be solid (1)')
    p = s['initial']
    if not isinstance(p, list) or len(p) != 3 or any(type(v) is not int for v in p):
        raise ValueError('initial must be [xQ8.8,yQ8.8,yaw], three integers')
    x, y, a = p
    if not (0 <= a < 512 and 0 <= x < 8192 and 0 <= y < 8192):
        raise ValueError('initial: X/Y must be 0..8191 and yaw 0..511')
    if not all(0 <= xx < 32 and 0 <= yy < 32 and not g[yy*32+xx]
               for xx in ((x-48)>>8, (x+48)>>8) for yy in ((y-48)>>8, (y+48)>>8)):
        raise ValueError('initial position is blocked for collision radius 48/256 cell')
    for key, value in [('wallHeight', 2), ('eyeHeight', 1), ('fov', 60), ('rays', 32)]:
        if type(s[key]) is not int or s[key] != value:
            raise ValueError(f'{key} is fixed at {value} in 1.0.0')
    route = s['autoRoute']
    if not isinstance(route, list) or not 1 <= len(route) <= 32:
        raise ValueError('autoRoute requires 1..32 [keys,ticks] commands')
    for i, item in enumerate(route):
        if not isinstance(item, list) or len(item) != 2 or any(type(v) is not int for v in item):
            raise ValueError(f'autoRoute[{i}] must be two integers')
        key, ticks = item
        if key not in (0, 1, 2, 4, 8, 5, 9, 6, 10):
            raise ValueError(f'autoRoute[{i}]: conflicting or invalid input bits')
        if not 1 <= ticks <= 65535:
            raise ValueError(f'autoRoute[{i}]: duration must be 1..65535 logical ticks')
    return s
