"""Verify every permanent file, manifest scope, metadata and shipped demos."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest().upper()


def main():
    expected = {}
    for line in (ROOT/'MANIFEST.sha256').read_text().splitlines():
        digest, name = line.split('  ', 1)
        assert name not in expected and '\\' not in name
        expected[name] = digest
    actual = {p.relative_to(ROOT).as_posix():sha(p) for p in ROOT.rglob('*') if p.is_file() and p != ROOT/'MANIFEST.sha256'}
    assert actual == expected, f'manifest mismatch: {set(actual)^set(expected)} or modified content'
    package = json.loads((ROOT/'PACKAGE-MANIFEST.json').read_text())
    assert (ROOT/'VERSION').read_text().strip() == package['version'] == '1.0.0'
    assert package['name'] == '2.5vibeVic'
    assert package['permanentFiles'] == len(actual)+1
    assert package['builderSHA256'] == sha(ROOT/'build.py')
    source_lines = ''.join(f'{sha(p)}  {p.relative_to(ROOT).as_posix()}\n' for p in sorted((ROOT/'src').rglob('*')) if p.is_file())
    assert package['sourceTreeSHA256'] == hashlib.sha256(source_lines.encode()).hexdigest().upper()
    refs = json.loads((ROOT/'tests/REFERENCE.json').read_text())
    for key in ('mono-auto','mono-interactive','multicolor-auto','multicolor-interactive'):
        path = 'demos/galleries-'+key+'.prg'
        assert sha(ROOT/path) == refs[key] == package['demos'][path]
    print(f'Package PASS: {len(actual)+1} permanent files; complete manifest; 4 qualified PRGs')


if __name__ == '__main__': main()
