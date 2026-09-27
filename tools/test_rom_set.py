"""Extract one selected NTSC dump per local archive and run a 60-second replay.

Commercial ROMs and generated artifacts stay in ignored ROM/ and work/ directories.
Uses Windows' bundled tar (libarchive); no ROMs are downloaded.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import wave

CHOICES = [
    ('Contra', 'Contra (U) [!].nes', 2, 'contra'),
    ('Darkwing Duck', 'Darkwing Duck (U) [!].nes', 1, 'darkwing'),
    ('Duck Hunt', 'Duck Hunt (W) [!].nes', 0, 'duckhunt'),
    ('Duck Tales', 'Duck Tales (U) [!].nes', 2, 'ducktales'),
    ('Megaman IV', 'Megaman IV (U) (PRG1) [!].nes', 4, 'megaman'),
    ('Super Mario Bros. 3', 'Super Mario Bros. 3 (U) (PRG1) [!].nes', 4, 'smb3'),
    ('Super Mario Bros.', 'Super Mario Bros. (W) [!].nes', 0, 'smb'),
    ('Teenage Mutant Ninja Turtles III - The Manhattan Project',
     'Teenage Mutant Ninja Turtles III - The Manhattan Project (U) [!].nes', 4, 'tmnt'),
]


def main():
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runner', type=Path, default=root / 'build/aot/dasNES.exe')
    parser.add_argument('--archives', type=Path, default=root / 'ROM')
    parser.add_argument('--extract-only', action='store_true')
    parser.add_argument('--only', choices=[c[3] for c in CHOICES])
    args = parser.parse_args()
    selected = args.archives / 'selected'
    selected.mkdir(parents=True, exist_ok=True)
    out = root / 'work/compatibility'
    out.mkdir(parents=True, exist_ok=True)
    results = []
    for archive, name, mapper, profile in CHOICES:
        if args.only and args.only != profile:
            continue
        target = selected / name
        pattern = name.replace('[', r'\[').replace(']', r'\]')
        data = subprocess.check_output(['tar', '-xOf', str(args.archives / (archive + '.7z')), pattern])
        if data[:4] != b'NES\x1a' or (data[6] >> 4 | data[7] & 240) != mapper:
            raise ValueError(f'Unexpected iNES header: {name}')
        if target.exists() and target.read_bytes() != data:
            raise ValueError(f'Refusing to replace a different ROM: {target}')
        if not target.exists():
            target.write_bytes(data)
        entry = dict(rom=name, mapper=mapper, sha256=hashlib.sha256(data).hexdigest())
        print(f'{name}: mapper {mapper}', flush=True)
        if not args.extract_only:
            starts = {'contra': [360], 'darkwing': [180, 600, 900, 1200, 1800],
                      'megaman': [180, 600, 900, 1200], 'smb3': [180, 600],
                      'tmnt': [180, 600, 900, 1200], 'ducktales': [180],
                      'duckhunt': [180], 'smb': [180]}[profile]
            movement = 3400 if profile == 'darkwing' else 1500 if profile in ('megaman', 'tmnt') else 1000
            inputs = bytearray(3600)
            for frame in range(movement, 3600):
                inputs[frame] = 128 | (1 if frame % 90 < 40 else 0) | (2 if frame % 12 < 6 else 0)
            for start in starts:
                inputs[start:start+2] = bytes([8, 8])
            if profile == 'darkwing':
                for press in range(1830, 3390, 30):
                    inputs[press:press+2] = bytes([1, 1])
            if profile == 'smb3':
                inputs[900:1300] = bytes(400)
                inputs[1000:1040] = bytes([128]) * 40
                inputs[1080:1120] = bytes([16]) * 40
                inputs[1160:1162] = bytes([1, 1])
            input_file = out / (profile + '.inputs')
            input_file.write_bytes(inputs)
            env = dict(os.environ, DASNES_REPLAY_INPUT=str(input_file), DASNES_ROM=str(target), DASNES_REPLAY_PROFILE=profile,
                       DASNES_REPLAY_OUT=str(out / profile), DASNES_ZAPPER='1' if profile == 'duckhunt' else '0')
            replay = subprocess.run([str(args.runner), str(root / 'rom_replay.das'), '--smoke-test'],
                                    env=env, capture_output=True, text=True, timeout=300)
            (out / (profile + '.log')).write_text(replay.stdout + replay.stderr, encoding='utf-8')
            entry.update(returncode=replay.returncode, log=replay.stdout + replay.stderr)
            print(entry['log'], flush=True)
            pcm = out / (profile + '.pcm')
            if pcm.exists():
                with wave.open(str(out / (profile + '.wav')), 'wb') as wav:
                    wav.setparams((1, 2, 48000, 0, 'NONE', 'not compressed'))
                    wav.writeframes(pcm.read_bytes())
        results.append(entry)
    report = out / (('selected' if args.extract_only else 'results') + ('-' + args.only if args.only else '') + '.json')
    report.write_text(json.dumps(results, indent=2), encoding='utf-8')
    if any(row.get('returncode', 0) for row in results):
        raise SystemExit('Some replays failed; see work/compatibility/results.json')


if __name__ == '__main__':
    main()
