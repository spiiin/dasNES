"""Create a Pages artifact from an explicit list of public build outputs."""
import argparse
from pathlib import Path
import shutil

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source', type=Path, default=Path('build/web/site'))
parser.add_argument('--output', type=Path, default=Path('build/pages'))
args = parser.parse_args()
names = {'index.html', 'style.css', 'app.js', 'dasnes_web.js',
         'dasnes_web.wasm', 'dasnes_web.data'}
for name in names:
    path = args.source / name
    if not path.is_file() or path.is_symlink() or path.stat().st_size == 0:
        parser.error(f'Missing, empty or symlinked build output: {path}')
if args.output.exists() and any(args.output.iterdir()):
    parser.error(f'Output must be empty to avoid publishing stale files: {args.output}')
args.output.mkdir(parents=True, exist_ok=True)
for name in sorted(names):
    shutil.copyfile(args.source / name, args.output / name)
(args.output / '.nojekyll').touch()
print(f'Pages artifact: {args.output} ({sum(p.stat().st_size for p in args.output.iterdir()):,} bytes)')
