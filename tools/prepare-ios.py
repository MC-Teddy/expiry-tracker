#!/usr/bin/env python
"""Copy only the audited mobile asset allowlist into SwiftPM resources."""
from pathlib import Path
import shutil
import tempfile

ASSET_DIRS = {"js", "vendor", "css", "assets"}
ASSET_EXTENSIONS = {".js", ".mjs", ".css", ".png", ".jpg", ".jpeg", ".webp", ".svg", ".ico", ".woff", ".woff2", ".ttf", ".otf", ".wasm"}

def prepare(source: Path, destination: Path):
    source, destination = Path(source), Path(destination)
    entry = source / "index.html"
    if source.is_symlink() or not entry.is_file() or entry.is_symlink():
        raise ValueError("mobile-web/index.html must exist and not be a symlink")
    selected = [(entry, Path("index.html"))]
    # Canonical web agent uses these audited entry modules, not a root-tree copy.
    for filename in ("native.js", "storage.mjs", "config.js", "app.js", "app.mjs", "boot.mjs", "network.mjs", "session.mjs", "transfer.mjs", "integration.js", "styles.css"):
        path = source / filename
        if path.is_symlink():
            raise ValueError("symlink entry modules forbidden")
        if path.is_file():
            selected.append((path, Path(filename)))
    for dirname in sorted(ASSET_DIRS):
        directory = source / dirname
        if directory.is_symlink():
            raise ValueError("symlink asset directories forbidden")
        if not directory.exists():
            continue
        for path in sorted(directory.rglob("*")):
            relative = path.relative_to(source)
            if path.is_symlink():
                raise ValueError("symlink assets forbidden")
            if any(part.startswith(".") for part in relative.parts):
                continue
            if path.is_file() and (path.suffix.lower() in ASSET_EXTENSIONS or relative.as_posix() in {"assets/Archivo-OFL.txt", "vendor/supabase-LICENSE"}):
                if not path.resolve().is_relative_to(source.resolve()):
                    raise ValueError("asset escaped source")
                selected.append((path, relative))
    sizes = [path.stat().st_size for path, _ in selected]
    if len(selected) > 2048 or max(sizes) > 20 * 1024 * 1024 or sum(sizes) > 60 * 1024 * 1024:
        raise ValueError("asset size/count budget exceeded")
    destination.parent.mkdir(parents=True, exist_ok=True)
    staging = Path(tempfile.mkdtemp(prefix="web-staging-", dir=destination.parent))
    try:
        for path, relative in selected:
            target = staging / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(path, target)
        if destination.exists():
            shutil.rmtree(destination)
        staging.replace(destination)
    finally:
        if staging.exists():
            shutil.rmtree(staging)
    print(f"Prepared {len(selected)} allowlisted web files ({sum(sizes)} bytes)")

if __name__ == "__main__":
    root = Path(__file__).resolve().parents[1]
    prepare(root / "mobile-web", root / "ios/Sources/ExpiryTracker/Resources/Web")
