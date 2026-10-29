#!/usr/bin/env bash
# Run in the existing WSL login shell. Does not sign, install, or touch relays.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
cache="${TMPDIR:-$HOME/.cache}/expiry-tracker-policy"
mkdir -p "$cache"
python3 -B -m unittest discover -s tools -p 'test_*.py' -v
swiftc ios/Sources/NativePolicy/*.swift ios/Tests/NativePolicyTests/main.swift -o "$cache/policy-tests"
"$cache/policy-tests"
python3 -B tools/prepare-ios.py
(cd ios && xtool dev build)
python3 -B tools/verify-ios.py
