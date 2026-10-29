# Mobile web bundle

Bundle `index.html`, `app.js`, `boot.mjs`, `native.js`, `network.mjs`, `session.mjs`, `storage.mjs`, `transfer.mjs`, `config.js`, `assets/` and `vendor/`. `integration.js` is the adapter source used by the test-side regeneration script, not a second runtime script. See BRIDGE.md for the native contract including AVFoundation camera.

- Existing dashboard, manual entry, list, search/sort, edit, photos, settings, themes and flat Archivo design are retained from the website.
- First launch requires an explicit storage choice. Local mode has no login, never creates a Supabase client, never loads the vendor SDK, and uses IndexedDB for records, photos and settings. Only the small storage-mode selection lives in localStorage.
- Local and each signed-in cloud account use immutable, isolated IndexedDB scopes and in-memory caches. Mode changes wait for active saves/settings/photo writes and reload. Account identity changes hide the app and reload rather than retargeting a live cache.
- CSP blocks external assets, browser networking, workers and frames. Cloud requests are routed through the native allowlisted request action, not WebKit fetch. No barcode network lookup, cloud OCR, Tesseract, service worker or browser getUserMedia remains in the generated bundle.
- Native camera opens only after Capture/Retake or Scan Barcode. Native expiry JPEG is rendered into the existing preview/canvas, thumbnailed, and sent to native Apple Vision through the worker-compatible warmOCR(). Camera cancellation clears prior staged details and leaves manual entry available.
- JSON version 1 backups include records, original local photos and settings. Local export is a single IndexedDB snapshot; import validates the whole document before an atomic replacement transaction. Size limit: 20 MiB (20,971,520 UTF-8 bytes, inclusive) / 50,000 items, shared with native export via `transfer.mjs`. Import checks file size before reading and serialized byte size before replacement; export checks Blob.size before base64 encoding. Naturally grown datasets/photos can still exceed the transfer ceiling: this first release reports an explicit error rather than exporting a partial backup; reduce the dataset/photos before retrying. Invalid/aborted import retains the existing dataset. Cloud export downloads available photos and fails rather than silently omitting transport failures.
- Item spreadsheet export is actual UTF-8 CSV (`.csv`, BOM, CRLF rows, quoted/escaped cells), with formula-triggering text neutralized by an apostrophe. Numeric day counts remain numeric. UI says CSV; no XLSX is sent to the bridge.
- Imports are LOCAL ONLY. No automatic cloud/local copying, merging, or cloud import. A cloud backup can explicitly replace local data. To avoid an unsafe partially uploaded cloud import, local-to-cloud migration is not implemented.
- Local photos are originals, not disposable cache; Clear Cloud Photo Cache refuses to delete them. Cloud caches are scoped to the current account.

## Cloud blocker

The actual website has a placeholder anon key, not a usable credential. `config.js` intentionally has an empty publicKey and cloud mode gives a configuration error before loading the SDK. Supply the existing project's real public anon/publishable key there; never a secret/service-role key. Nothing was provisioned, deployed, or committed. Authenticated cloud login/CRUD/storage has NOT been verified without that key.

## Regeneration and verification

From `tests/mobile-web/` run `npm ci` then `npm run verify` (Python command is `python` on this host). Build copies the original screens into the NEW mobile directory, inserts the mobile adapter, and parses away superseded website functions. It never writes root index.html. Runtime does not require Node/npm/Python. Assets include local Archivo with OFL and pinned Supabase JS 2.95.3 with MIT license, downloaded from Google Fonts/Supabase upstream and jsDelivr.

The browser test uses installed Microsoft Edge via Playwright, a localhost-only static server, real browser IndexedDB, and explicitly simulated native bridge replies. It is not a physical-device/AVFoundation/Apple Vision test. Parent/native integration must verify WKWebView module loading and persistence, actual camera permissions/cancel/torch/barcode/OCR, share-sheet output, and configured authenticated sync on iPhone.
