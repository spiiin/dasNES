"""Compare the official-opcode portion of nestest against its reference log."""
import argparse
import hashlib
import os
from pathlib import Path
import re
import subprocess
import urllib.request

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--runner', type=Path, required=True)
args = parser.parse_args()
cache = root / 'work' / 'nestest'
cache.mkdir(parents=True, exist_ok=True)
hashes = {
    'nestest.nes': 'f67d55fd6b3cf0bad1cc85f1df0d739c65b53e79cecb7fea8f77ec0eadab0004',
    'nestest.log': '442c4dd5539c7e88b3fd73c7b732a7eadbd22b47c2cd9e58397ef147f64f6f8f',
}
for name in hashes:
    dest = cache / name
    if not dest.exists():
        url = 'https://raw.githubusercontent.com/christopherpow/nes-test-roms/master/other/' + name
        print('Downloading', url)
        data = urllib.request.urlopen(url, timeout=30).read()
        if hashlib.sha256(data).hexdigest() != hashes[name]:
            raise SystemExit(f'Unexpected download checksum: {name}')
        dest.write_bytes(data)
    if hashlib.sha256(dest.read_bytes()).hexdigest() != hashes[name]:
        raise SystemExit(f'Unexpected cached file checksum: {dest}')
env = dict(os.environ, DASNES_ROM=str(cache / 'nestest.nes'))
result = subprocess.run([str(args.runner.resolve()), str(root / 'trace.das'), '--smoke-test'],
                        env=env, capture_output=True, text=True, timeout=60)
if result.returncode:
    raise SystemExit(result.stdout + result.stderr)
actual = [list(map(int, line.split()[1:])) for line in result.stdout.splitlines() if line.startswith('TRACE ')]
expected = (cache / 'nestest.log').read_text().splitlines()
if len(actual) != 5003 or len(expected) < 5003:
    raise SystemExit(f'Wrong trace length: actual={len(actual)}, expected={len(expected)}')
pattern = re.compile(r'([0-9A-F]{4}).*A:([0-9A-F]{2}) X:([0-9A-F]{2}) Y:([0-9A-F]{2}) P:([0-9A-F]{2}) SP:([0-9A-F]{2}).*CYC:(\d+)')
for i, (line, got) in enumerate(zip(expected, actual), 1):
    m = pattern.match(line)
    if not m:
        raise SystemExit(f'Invalid reference line {i}: {line}')
    want = [int(x, 16) for x in m.groups()[:6]] + [int(m[7])]
    if got != want:
        raise SystemExit(f'Mismatch at instruction {i}:\nPC A X Y P SP CYC\nactual   {got}\nexpected {want}')
print('PASS: 5003 nestest states match PC/A/X/Y/P/SP and cycle count exactly.')
