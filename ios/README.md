# Expiry Tracker native iPhone shell

Canonical web source: sibling `../mobile-web/`. The existing website/root files are not copied or modified by these tools. SwiftPM bundles an allowlisted snapshot under `Sources/ExpiryTracker/Resources/Web/` (generated, ignored). The shell requires iOS 17+ and uses a persistent default WebKit data store; iPhone-app data is separate from Safari/PWA data.

## Build and verify (no signing/install)

From the repository root in the existing WSL login shell:

```sh
bash tools/check-ios.sh
```

From Windows Git Bash:

```sh
wsl.exe -e bash -lic 'cd /mnt/c/Users/mr_an/Desktop/Dev/Claude/expiry-tracker; bash tools/check-ios.sh'
```

This runs asset-copy tests, Foundation Swift policy/one-shot tests, prepares canonical web assets, executes `xtool dev build`, and verifies bundle metadata, arm64 Mach-O header, asset inventory and SHA-256 equality against canonical sources. Re-run after the web agent finishes all changes: a simultaneous canonical edit intentionally fails the stale-resource check. No signing, authentication, USB relay modification, deployment, or installation is performed.

Output: `ios/xtool/ExpiryTracker.app`. Identity: `com.ahasan.expirytracker`, version `1.0.0`, build `1`. Keep identity stable to preserve app data on upgrade. Build/source output is ignored. The most recent verification attempt is recorded locally in `ios/verification/build.log`; concurrent canonical edits can make its final freshness check fail even after successful compilation.

## Native capabilities

- Persistent WKWebView loads only bundled `file:` entry with read access restricted to its resource directory. Main-frame caller trust is independently checked; unrelated navigation/iframes and WebKit network subresources are denied. No universal file access or ATS exceptions.
- All JavaScript dialogs, including default-prefilled prompt/cancel and reentrant one-shot completions.
- **AVFoundation camera**, not browser capture: native preview, photo shutter, close, torch, selected-photo picker, explicit permission handling, interface-orientation rotation, and cancellation/teardown on background/interruption. Expiry photos become upright JPEGs, at most 2048px long edge / 5MiB. Barcode preview uses metadata detection; photo/library barcode capture uses Vision and never returns a pretend barcode image.
- On-device Vision OCR accepts bounded PNG/JPEG/HEIC/HEIF/WebP image data URLs.
- HTTPS bridge preserves binary bodies and HTTP error statuses. Exact Supabase host and four endpoint prefixes only; validates methods/headers, disables cookies/credential storage/cache, rejects all redirects and HTTP credential challenges, cancels oversized streams, rejects transport errors even after headers arrived. 20MiB decoded limit, at most four active requests.
- Every native request reads the trusted document's `expiry_mobile_mode_v1` storage key; only exact `cloud` permits network. Local/missing/invalid modes reject before URLSession creation. Navigation and mode changes invalidate in-flight response scopes.
- Native JSON/CSV share-sheet export with strict basename, protected temporary files, excluded-from-backup flag, bounded binary data, cancellation result and cleanup. Native intentionally rejects `.xlsx` and unknown extensions; the web layer must offer real CSV/JSON, not legacy renamed Excel output.

See `BRIDGE.md` for message contracts.

## Verified / pending

Verified with installed xtool 1.22.2 and Swift 6.4: official scratch scaffold unsigned compile, policy tests (50 checks), asset-copy tests (2 cases), actual arm64 Swift camera/WebKit/Vision compilation, final bundled assets and metadata. Official 1.22.2 PackSchema/Packer/DevCommand were inspected before scaffolding.

No phone install has been performed. Phone launch, persistence across termination/upgrades, offline restart, camera permission/capture/orientation/torch/library/barcode, OCR quality, dialogs, export saving/cancellation and isolated-account sync still require runtime acceptance after parent review. The canonical Supabase public key is a placeholder: cloud login/sync remain blocked until a real public anon/publishable key is provided. Never use a secret/service-role key.
