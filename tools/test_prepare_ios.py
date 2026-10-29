import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("prepare_ios", Path(__file__).with_name("prepare-ios.py"))
assert spec and spec.loader
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class AssetPreparationTests(unittest.TestCase):
    def test_allowlist_preserves_asset_directories_not_repo_or_credentials(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source, output = root / "mobile-web", root / "bundle"
            for name, data in {"index.html":b"entry", "native.js":b"bridge", "storage.mjs":b"store", "config.js":b"config", "integration.js":b"integration", "boot.mjs":b"boot", "assets/Archivo-OFL.txt":b"license", "vendor/supabase-LICENSE":b"license", "js/app.js":b"app", "vendor/lib.js":b"vendor", "css/main.css":b"css", "assets/photo.png":b"photo", "secrets.json":b"secret", "tests/leak.js":b"test", ".env":b"secret", "vendor/account.json":b"secret", "README.md":b"docs"}.items():
                path = source / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)
            module.prepare(source, output)
            self.assertEqual(sorted(p.relative_to(output).as_posix() for p in output.rglob("*") if p.is_file()), ["assets/Archivo-OFL.txt", "assets/photo.png", "boot.mjs", "config.js", "css/main.css", "index.html", "integration.js", "js/app.js", "native.js", "storage.mjs", "vendor/lib.js", "vendor/supabase-LICENSE"])
            self.assertEqual((output / "assets/photo.png").read_bytes(), b"photo")
            (source / "js/app.js").unlink()
            module.prepare(source, output)
            self.assertFalse((output / "js/app.js").exists())
    def test_boot_dependencies_are_packaged(self):
        with tempfile.TemporaryDirectory() as tmp:
            source, output = Path(tmp) / "source", Path(tmp) / "output"
            source.mkdir()
            for name, text in {"index.html": '<script type="module" src="boot.mjs"></script>',
                               "boot.mjs": "import './network.mjs'; import './session.mjs';",
                               "network.mjs": "export const network = true;",
                               "session.mjs": "export const session = true;"}.items():
                (source / name).write_text(text)
            module.prepare(source, output)
            for name in ("network.mjs", "session.mjs"):
                self.assertTrue((output / name).is_file(), f"missing boot dependency: {name}")

    def test_missing_entry_leaves_existing_output_intact(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source, output = root / "source", root / "output"
            source.mkdir(); output.mkdir(); (output / "keep").write_text("keep")
            with self.assertRaises(ValueError): module.prepare(source, output)
            self.assertTrue((output / "keep").exists())

if __name__ == "__main__": unittest.main()
