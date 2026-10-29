import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("verify_ios", Path(__file__).with_name("verify-ios.py"))
assert spec and spec.loader
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class WebDependencyTests(unittest.TestCase):
    def check(self, files):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for name, text in files.items():
                target = root / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text(text, encoding="utf-8")
            module.verify_web_dependencies(root)

    def test_missing_transitive_module_is_rejected(self):
        with self.assertRaisesRegex(AssertionError, "missing.*network.mjs"):
            self.check({"index.html": '<script type="module" src="boot.mjs"></script>',
                        "boot.mjs": "import './js/session.mjs';",
                        "js/session.mjs": "export {fetch} from '../network.mjs';"})

    def test_literal_dynamic_import_is_rejected(self):
        for statement in ("import('./missing.mjs')", 'import("./missing.mjs")', "import(`./missing.mjs`)"):
            with self.subTest(statement=statement):
                with self.assertRaisesRegex(AssertionError, "missing.*missing.mjs"):
                    self.check({"index.html": '<script src="boot.mjs"></script>', "boot.mjs": statement})

    def test_nonliteral_dynamic_imports_are_not_guessed(self):
        self.check({"index.html": '<script src="boot.mjs"></script>',
                    "boot.mjs": "const name = 'x'; import('./' + name); import(`./${name}`);"})

    def test_missing_html_src_and_href_are_rejected(self):
        for html in ('<img src="missing.png">', '<link href="missing.css" rel="stylesheet">',
                     '<script type="module">import "./missing.mjs";</script>'):
            with self.subTest(html=html):
                with self.assertRaisesRegex(AssertionError, "missing dependency"):
                    self.check({"index.html": html})

    def test_normalized_closure_and_nonlocal_references(self):
        self.check({
            "index.html": '<script type="module" src="./js/boot.mjs?v=1#boot"></script>'
                          '<link href="/css/main.css"><a href="#anchor">x</a>'
                          '<img src="data:image/png;base64,x"><a href="mailto:a@example.com">mail</a>'
                          '<script src="https://example.com/lib.js"></script><img src="//example.com/x">',
            "css/main.css": "",
            "js/boot.mjs": "import {x} from '../network.mjs'; export * from './session.mjs';"
                           "import('../network.mjs?dynamic=1'); import('./session.mjs');"
                           "// import './fake.mjs';\nconst example = \"import './fake.mjs'\";",
            "js/session.mjs": "export {x} from '../network.mjs';",
            "network.mjs": "export const x = 1;"})

    def test_escaping_paths_are_rejected(self):
        for path in ("../outside.js", "%2e%2e/outside.js", "js/../../outside.js", "js%5c..%5coutside.js"):
            with self.subTest(path=path):
                with self.assertRaisesRegex(AssertionError, "escapes Web|unsafe dependency"):
                    self.check({"index.html": f'<script src="{path}"></script>'})


if __name__ == "__main__":
    unittest.main()
