#!/usr/bin/env python
"""Verify metadata, arm64 Mach-O, and byte-exact allowlisted bundle resources."""
from pathlib import Path
import hashlib
import json
import plistlib
import struct
import re
from html.parser import HTMLParser
from urllib.parse import unquote, urlsplit


# Tokenize rather than matching source text: comments and quoted examples are
# not dependencies. Only literal module specifiers can be checked statically.
_JS_TOKEN = re.compile(
    r'(?P<comment>//[^\n]*|/\*[\s\S]*?\*/)'
    r'|(?P<string>"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\')'
    r'|(?P<template>`(?:\\.|[^`\\])*`)'
    r'|(?P<word>[A-Za-z_$][\w$]*)|(?P<punct>[^\s])'
)


def module_references(text):
    tokens = [(m.lastgroup, m.group()) for m in _JS_TOKEN.finditer(text)
              if m.lastgroup != "comment"]
    for i, (kind, value) in enumerate(tokens):
        if kind != "word" or value not in {"import", "export"}:
            continue
        if i and tokens[i - 1][1] in {".", "?."}:
            continue
        tail = tokens[i + 1:]
        if value == "import" and tail:
            if tail[0][0] == "string":
                yield tail[0][1][1:-1]
                continue
            if tail[0][1] == "(":
                if len(tail) > 2 and tail[2][1] in {")", ","} and (
                        tail[1][0] == "string" or
                        (tail[1][0] == "template" and "${" not in tail[1][1])):
                    yield tail[1][1][1:-1]
                continue
            if tail[0][1] == ".":
                continue
        for j, token in enumerate(tail):
            if token[1] == ";":
                break
            if token == ("word", "from"):
                if j + 1 < len(tail) and tail[j + 1][0] == "string":
                    yield tail[j + 1][1][1:-1]
                break


class HTMLReferences(HTMLParser):
    def __init__(self):
        super().__init__()
        self.references = []
        self.scripts = []
        self.in_script = False

    def handle_starttag(self, tag, attrs):
        self.references.extend(value for key, value in attrs
                               if key in {"src", "href"} and value)
        self.in_script = tag == "script"

    def handle_endtag(self, tag):
        if tag == "script":
            self.in_script = False

    def handle_data(self, data):
        if self.in_script:
            self.scripts.append(data)


def verify_web_dependencies(web: Path):
    """Reject missing/escaping local HTML references and JS module imports.

    Inspect every shipped JS/HTML file, including modules loaded on demand;
    non-literal runtime URLs are intentionally outside this static check.
    """
    web = Path(web).resolve()
    assert (web / "index.html").is_file(), "missing web entry: index.html"

    def check(owner, reference):
        reference = reference.strip()
        if not reference or reference.startswith("#"):
            return
        url = urlsplit(reference)
        if url.scheme or url.netloc or reference.startswith("//"):
            return
        path = unquote(url.path)
        if not path:
            return
        assert "\\" not in path and "\x00" not in path, f"unsafe dependency: {reference} in {owner.name}"
        target = (web / path.lstrip("/") if path.startswith("/") else owner.parent / path).resolve()
        assert target.is_relative_to(web), f"dependency escapes Web: {reference} in {owner.name}"
        assert target.is_file(), f"missing dependency: {reference} in {owner.relative_to(web)}"

    for owner in sorted(web.rglob("*")):
        assert not owner.is_symlink(), f"symlink web resource: {owner}"
        if not owner.is_file():
            continue
        if owner.suffix.lower() in {".js", ".mjs"}:
            for reference in module_references(owner.read_text(encoding="utf-8")):
                check(owner, reference)
        elif owner.suffix.lower() == ".html":
            parser = HTMLReferences()
            parser.feed(owner.read_text(encoding="utf-8"))
            for reference in parser.references:
                check(owner, reference)
            for script in parser.scripts:
                for reference in module_references(script):
                    check(owner, reference)


def verify(root: Path):
    app = root / "ios/xtool/ExpiryTracker.app"
    info = plistlib.loads((app / "Info.plist").read_bytes())
    assert info["CFBundleIdentifier"] == "com.ahasan.expirytracker", "bundle identifier mismatch"
    assert info["CFBundleDisplayName"] == "Expiry Tracker", "display name mismatch"
    expected = plistlib.loads((root / "ios/Support/Info.plist").read_bytes())
    for key in ("CFBundleShortVersionString", "CFBundleVersion", "NSCameraUsageDescription", "NSPhotoLibraryUsageDescription"):
        assert info[key] == expected[key], f"metadata mismatch: {key}"
    executable = app / info["CFBundleExecutable"]
    header = executable.read_bytes()[:32]
    magic, cpu = struct.unpack("<II", header[:8])
    assert magic == 0xFEEDFACF and cpu == 0x0100000C, "not an arm64 Mach-O executable"
    source = root / "ios/Sources/ExpiryTracker/Resources/Web"
    bundled = app / "ExpiryTracker_ExpiryTracker.bundle/Web"
    assert (bundled / "index.html").is_file(), "missing bundled entry; preparation/build incomplete"
    verify_web_dependencies(source)
    verify_web_dependencies(bundled)
    sources = {p.relative_to(source).as_posix(): p for p in source.rglob("*") if p.is_file()}
    bundles = {p.relative_to(bundled).as_posix(): p for p in bundled.rglob("*") if p.is_file()}
    assert sources.keys() == bundles.keys(), "bundle asset inventory mismatch"
    hashes = {}
    for name, path in sources.items():
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        assert digest == hashlib.sha256(bundles[name].read_bytes()).hexdigest(), f"resource byte mismatch: {name}"
        canonical = root / "mobile-web" / name
        assert digest == hashlib.sha256(canonical.read_bytes()).hexdigest(), f"stale canonical web resource: {name}"
        hashes[name] = digest
    result = {"bundle":str(app), "identifier":info["CFBundleIdentifier"], "version":info["CFBundleShortVersionString"], "build":info["CFBundleVersion"], "architecture":"arm64", "executableBytes":executable.stat().st_size, "webAssets":hashes, "scope":"bundle verification only; signing/install/runtime not checked"}
    print(json.dumps(result, indent=2))
    return result


if __name__ == "__main__":
    verify(Path(__file__).resolve().parents[1])
