"""Compile repository Lua and test production ESP against mocked services."""
import argparse
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument('--luau-dir', type=Path, required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
for source in root.glob('*.lua'):
    subprocess.run([str(args.luau_dir / 'luau-compile.exe'), '--null', str(source)], check=True)
harness = (root / 'tests/ESP.spec.luau').read_text(encoding='utf-8')
module = (root / 'ESPSystem.lua').read_text(encoding='utf-8-sig')
with tempfile.TemporaryDirectory(prefix='.diq-esp-tests-', dir=root / 'tests') as temp:
    test = Path(temp) / 'esp.luau'
    test.write_text(harness.replace('-- INSERT_MODULE', module), encoding='utf-8')
    subprocess.run([str(args.luau_dir / 'luau.exe'), str(test)], check=True)
