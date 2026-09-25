import copy
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SDK = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SDK/'scripts'))
from scene_contract import validate_scene


class Contract(unittest.TestCase):
    def setUp(self):
        self.s = json.loads((SDK/'examples/galleries.json').read_text())

    def reject(self, key, value):
        self.s[key] = value
        with self.assertRaises(ValueError): validate_scene(self.s)

    def test_valid(self): validate_scene(self.s)
    def test_schema(self): self.reject('schema', 'unknown')
    def test_dimensions(self): self.reject('size', [16, 16])
    def test_grid_length(self): self.reject('grid', [1]*1023)
    def test_grid_bool(self):
        self.s['grid'][0] = True
        with self.assertRaises(ValueError): validate_scene(self.s)
    def test_border(self):
        self.s['grid'][0] = 0
        with self.assertRaises(ValueError): validate_scene(self.s)
    def test_start_wall(self): self.reject('initial', [256, 256, 0])
    def test_start_range(self): self.reject('initial', [1408, 1664, 512])
    def test_camera_type(self): self.reject('initial', [1408.0, 1664, 0])
    def test_fixed_fields(self):
        for key in ['fov', 'rays', 'wallHeight', 'eyeHeight']:
            with self.subTest(key=key):
                s = copy.deepcopy(self.s); s[key] += 1
                with self.assertRaises(ValueError): validate_scene(s)
    def test_unknown(self): self.reject('texture', {})
    def test_route(self):
        for route in [[], [[1, 0]], [[1, 65536]], [[3, 10]], [[12, 10]], [[True, 20]], [[1, 10]]*33]:
            with self.subTest(route=route): self.reject('autoRoute', route)
    def test_all_prgs_match_qualified(self):
        refs = json.loads((SDK/'tests/REFERENCE.json').read_text())
        with tempfile.TemporaryDirectory(prefix='vibevic-contract-') as tmp:
            for mode in ['mono', 'multicolor']:
                for run in ['auto', 'interactive']:
                    key = mode+'-'+run; out = Path(tmp)/key
                    result = subprocess.run([sys.executable, '-B', str(SDK/'build.py'), '--graphics', mode,
                        '--run', run, '--out', str(out)], capture_output=True, text=True)
                    self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
                    data = (out/'vibe20.prg').read_bytes()
                    self.assertEqual(hashlib.sha256(data).hexdigest().upper(), refs[key])
                    self.assertEqual(len(data), 28161)
                    self.assertEqual(data[:2], b'\x01\x12')
                    report = json.loads((out/'build.json').read_text())
                    self.assertGreater(report['freeCode'], 0)
                    lab = {l.split()[2].lstrip('.'):int(l.split()[1],16) for l in (out/'labels.txt').read_text().splitlines() if l.startswith('al ')}
                    self.assertLessEqual(lab['low_end'], 0x3a00)
                    self.assertLessEqual(lab['tables_end'], 0x7000)
                    self.assertLessEqual(lab['directions_end'], 0x7c00)
                    self.assertEqual(lab['data_end'], 0x8000)
                    self.assertLessEqual(lab['pixel_top']+128, 0x3c00)
    def test_reject_source_output(self):
        result = subprocess.run([sys.executable, '-B', str(SDK/'build.py'), '--graphics', 'mono',
            '--out', str(SDK/'forbidden-build')], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((SDK/'forbidden-build').exists())


if __name__ == '__main__': unittest.main()
