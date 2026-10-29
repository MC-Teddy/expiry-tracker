"""Compile/test without signing, installing, launching, or changing tools.
Run with Windows Python: python ios-native/verification/verify.py
Uses the existing Ubuntu/Swiftly/xtool installation.
"""
from pathlib import Path
import json
import hashlib
import os
import plistlib
import re
import shlex
import struct
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "verification"

def run(name, command):
    if os.name == "nt":
        path = "/mnt/" + ROOT.drive[0].lower() + ROOT.as_posix()[2:]
        args = ["wsl.exe", "-d", "Ubuntu", "--exec", "bash", "-lic", "cd " + shlex.quote(path) + " && " + command]
    else:
        args = ["bash", "-lic", "cd " + shlex.quote(str(ROOT)) + " && " + command]
    result = subprocess.run(args, capture_output=True, text=True, encoding="utf-8", errors="replace")
    (OUT / (name + ".log")).write_text(result.stdout + result.stderr, encoding="utf-8")
    print(name + ": exit " + str(result.returncode))
    print("\n".join((result.stdout + result.stderr).splitlines()[-12:]))
    if result.returncode:
        raise SystemExit(result.returncode)
    return result.stdout + result.stderr

wiring = subprocess.run([sys.executable, str(OUT / "review_regressions.py")], capture_output=True, text=True)
(OUT / "review-wiring-green.log").write_text(wiring.stdout + wiring.stderr, encoding="utf-8")
print("review wiring: exit " + str(wiring.returncode))
if wiring.returncode:
    print(wiring.stdout + wiring.stderr)
    raise SystemExit(wiring.returncode)
tests = run("tests", "swift test")
build = run("build", "xtool dev build")
app = ROOT / "xtool" / "ExpiryTracker.app"
info = plistlib.loads((app / "Info.plist").read_bytes())
assert info["CFBundleIdentifier"] == "com.ahasan.expirytracker", info
assert info["CFBundleShortVersionString"] == "1.2.0", info
assert str(info["CFBundleVersion"]) == "12", info
exe = app / info["CFBundleExecutable"]
data = exe.read_bytes()
magic, cpu, subtype, kind, count, size, flags, reserved = struct.unpack_from("<8I", data)
assert magic == 0xFEEDFACF and cpu == 0x0100000C and kind == 2, "Expected executable arm64 Mach-O"
offset = 32
libraries = []
for _ in range(count):
    command, length = struct.unpack_from("<2I", data, offset)
    assert length >= 8
    if command & 0x7FFFFFFF in (0xC, 0x18, 0x1F, 0x23):
        name_offset = struct.unpack_from("<I", data, offset + 8)[0]
        libraries.append(data[offset + name_offset:offset + length].split(b"\0")[0].decode())
    offset += length
assert not any("webkit" in lib.lower() for lib in libraries), libraries
for file in (ROOT / "Sources").rglob("*.swift"):
    text = file.read_text(encoding="utf-8")
    assert not re.search(r"WebKit|WKWebView|JavaScript", text, re.I), str(file)
    for match in re.findall(r"https?://[^\s\"']+", text):
        assert "viupqrjyszvvcpnxrmsq.supabase.co" in match, (str(file), match)
web_resources = [str(file.relative_to(app)) for file in app.rglob("*") if file.suffix.lower() in (".html", ".js", ".mjs", ".css")]
assert not web_resources, web_resources
assert (app / "AppIcon.png").is_file()
summary = {
    "identity": {key: info[key] for key in ("CFBundleIdentifier", "CFBundleShortVersionString", "CFBundleVersion", "CFBundleExecutable")},
    "executable": {"format": "Mach-O 64-bit", "architecture": "arm64", "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()},
    "linkedLibraries": libraries,
    "webResources": web_resources,
    "sourceNetworkOrWebKitReferences": [],
    "testsExitCode": 0,
    "testCasesStarted": len(re.findall(r"Test Case '[^']+' started", tests)),
    "testCasesPassed": len(re.findall(r"Test Case '[^']+' passed", tests)),
    "testCasesSkipped": len(re.findall(r"Test Case '[^']+' skipped", tests)),
    "testWarnings": [line for line in tests.splitlines() if "warning:" in line],
    "unsignedBuildExitCode": 0,
    "buildWarnings": [line for line in build.splitlines() if "warning:" in line],
    "installed": False,
    "launched": False,
    "runtimeVerified": False,
}
(OUT / "artifact.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
assert not summary["testWarnings"], summary["testWarnings"]
assert not summary["buildWarnings"], summary["buildWarnings"]
print(json.dumps(summary, indent=2))
