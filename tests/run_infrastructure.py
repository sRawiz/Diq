"""Run real infrastructure/features against deterministic engine mocks."""
import argparse
from pathlib import Path
import subprocess
import tempfile
import sys

parser = argparse.ArgumentParser()
parser.add_argument('--luau-dir', type=Path, required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
sources = sorted(root.glob('*.lua'))
for source in sources:
    subprocess.run([str(args.luau_dir / 'luau-compile.exe'), '--null', str(source)], check=True)
factories = 'local factories = {}\n' + '\n'.join(
    f'factories.{source.stem} = function(...)\n{source.read_text(encoding="utf-8-sig")}\nend\n'
    for source in sources
)
with tempfile.TemporaryDirectory(prefix='.diq-build-', dir=root / 'tests') as temp:
    bundle = Path(temp) / 'Diq.lua'
    subprocess.run([sys.executable, str(root / 'tools/build.py'), '--output', str(bundle)], check=True)
    subprocess.run([str(args.luau_dir / 'luau-compile.exe'), '--null', str(bundle)], check=True)
    factories += '\nfactories.Bundle = function(...)\n' + bundle.read_text(encoding='utf-8') + '\nend\n'
for suite in ['Infrastructure', 'UI', 'Loader', 'ControlCenter']:
    spec = root / f'tests/{suite}.spec.luau'
    if not spec.exists():
        continue
    harness = spec.read_text(encoding='utf-8').replace(
        '-- INSERT_MOCKS', (root / 'tests/EngineMock.luau').read_text(encoding='utf-8')
    ).replace('-- INSERT_MODULES', factories)
    with tempfile.TemporaryDirectory(prefix='.diq-infra-tests-', dir=root / 'tests') as temp:
        test = Path(temp) / f'{suite}.luau'
        test.write_text(harness, encoding='utf-8')
        subprocess.run([str(args.luau_dir / 'luau.exe'), str(test)], check=True)
