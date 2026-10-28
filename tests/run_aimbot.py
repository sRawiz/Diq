"""Run mocked behavior tests with official Luau executables (no Studio required)."""
import argparse
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument('--luau-dir', type=Path, required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
compiler = args.luau_dir / 'luau-compile.exe'
for source in root.glob('*.lua'):
    subprocess.run([str(compiler), '--null', str(source)], check=True)
harness = (root / 'tests/Aimbot.spec.luau').read_text(encoding='utf-8-sig')
module = (root / 'AimbotSystem.lua').read_text(encoding='utf-8-sig')
with tempfile.TemporaryDirectory(prefix='diq-aim-tests-') as temp:
    test = Path(temp) / 'aimbot.luau'
    test.write_text(harness.replace('-- INSERT_MODULE', module), encoding='utf-8')
    subprocess.run([str(args.luau_dir / 'luau.exe'), str(test)], check=True)
