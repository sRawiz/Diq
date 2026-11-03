"""Packaging contracts, isolated from the repository's generated artifacts."""
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import ui_build


class UIBuildTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.addCleanup(self.temp.cleanup)
        self.root_patch = patch.object(ui_build, 'ROOT', self.root)
        self.root_patch.start()
        self.addCleanup(self.root_patch.stop)

    def put(self, name, source):
        path = self.root / 'ui' / (name + '.lua')
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(source, encoding='utf-8')

    def test_missing_dependency(self):
        self.put('init', 'local import = ...\nreturn import("components/Missing")')
        with self.assertRaisesRegex(ValueError, 'missing UI dependency'):
            ui_build.build_ui()

    def test_dependency_cycle(self):
        self.put('init', 'local import = ...\nreturn import("A")')
        self.put('A', 'local import = ...\nreturn import("init")')
        with self.assertRaisesRegex(ValueError, 'Circular UI dependency'):
            ui_build.build_ui()

    def test_deterministic_build_and_stale_detection(self):
        self.put('init', 'return function(options) return { Options = options } end')
        output = ui_build.build_ui()
        self.assertEqual(output, ui_build.build_ui())
        artifact = self.root / 'DiqUILib.lua'
        artifact.write_text(output, encoding='utf-8')
        ui_build.check_ui()
        self.put('init', 'return function(options) return { Updated = true } end')
        with self.assertRaisesRegex(ValueError, 'stale'):
            ui_build.check_ui()
        self.assertEqual(output, artifact.read_text(encoding='utf-8'))

    def test_nested_components_are_included(self):
        self.put('init', 'local import = ...\nreturn import("components/Button")')
        self.put('components/Button', 'return function() return "button" end')
        output = ui_build.build_ui()
        self.assertIn('uiFactories["components/Button"] = function(...)', output)
        self.assertIn('return importUI("init")(...)', output)


if __name__ == '__main__':
    unittest.main()
