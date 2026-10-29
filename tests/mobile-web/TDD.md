# Incremental RED → GREEN evidence

These are observations from actual terminal/browser runs during implementation, not a claim of device or live-cloud verification. Regression acceptance coverage was expanded after the initial feature slices.

1. IndexedDB isolation/persistence test first failed ERR_MODULE_NOT_FOUND for storage.mjs. Implemented scoped Store; rerun 1/1 passed.
2. Versioned/atomic local backup test failed `validateBackup is not a function`. Implemented whole-document validation and one-transaction replacement; rerun 2/2 passed.
3. Native Promise bridge test first failed ENOENT native.js. Implemented request correlation/replies/errors; rerun 1/1 passed.
4. Real Edge browser first failed waiting for missing #choose-local. Implemented bundled original screens and boot/storage integration. Corrected a test selector that matched a hidden dashboard duplicate; local add/reload/list and zero-external-request assertions then passed.
5. Native camera/OCR test failed waiting for #add-form (old browser-camera path). Implemented explicit native camera launch and image/canvas/OCR path; passed. Additional test found saving auto-reopened camera: actual camera count 2 vs expected 1. Removed auto-retake; passed.
6. Bundle policy test failed because inherited website code still contained superseded browser camera/localStorage-photo functions and an obsolete OCR comment. Added AST-based removal of replaced functions and removed obsolete comment; passed.
7. Validation edge-case test failed for legitimate photo item ID ending `_full`; fixed ownership checking and strengthened container/ID/category validation; host tests passed. Aborted import rollback also verified against the actual IndexedDB transaction API (fake-indexeddb on host).
8. In-flight-save mode-switch browser test failed: selected mode became cloud before a delayed local save completed. Added promise tracking across full save/edit/photo operations and drain-before-reload. Same test passed.
9. Transport tests failed ERR_MODULE_NOT_FOUND network.mjs. Implemented native-only project-allowlisted binary transport, HTTP status propagation, 204 handling and abort checks; 3/3 passed.
10. Snapshot concurrency test failed `generation-2` photo vs `generation-1` record. Changed backup to a single readonly transaction spanning records/photos/settings. Same test passed.
11. Camera-cancel test failed with stale product name retained. Clear staged name/date/package/preview before a new native capture; passed. Native barcode purpose dispatch and no-network behavior also exercised.
12. XLSX cancellation test failed waiting for explicit cancelled export status. Awaited native export completion and surfaced cancellation/error in status instead of leaving Preparing or claiming success; passed.
13. Account identity test failed missing session.mjs. Implemented hide/reload observer without retargeting caches, same-user token refresh does not reload; passed.

Final reproducible command: `npm run verify` from tests/mobile-web. Build regenerated mobile assets and pruned 23 replaced website functions. Host result: 11 tests passed, 0 failed. Real Edge browser acceptance passed: no-account first launch, manual add/reload persistence, native capture/OCR dispatch, saved photo inclusion, cancel/manual fallback, native barcode dispatch, XLSX cancellation, JSON export plus malformed/valid import, original-photo protection, lazy cloud configuration failure, mode round-trip, delayed-save switch safety, zero external HTTP requests.

## Reviewed export/backup fixes — incremental evidence

14. Real generated-app CSV regression first failed with actual filename `expiry-tracker-2026-10-15.xlsx` instead of `.csv`. Updated mobile-only regeneration and CSV builder; rerun passed, checking exact decoded UTF-8/BOM/CRLF bytes, embedded quotes/comma/newline/Unicode, formula neutralization, native filename, CSV label and cancellation. It explicitly rejects ZIP/XLSX bytes.
15. Serialized backup size regression first failed with “Missing expected exception” at 20 MiB + 1 byte. Added shared transfer limit and byte-based validation; rerun passed for exact 20 MiB, one byte over, multi-byte Unicode and retained local data on oversized import.
16. Oversized export browser regression first failed because the backup incorrectly reported success. Added Blob.size guard before FileReader/base64; rerun passed for JSON and CSV, with zero encoding calls and zero native messages for oversized payloads.
17. Import pre-read regression first failed with one read instead of zero for a 20 MiB + 1 file. Reused shared transfer guard before file.text(); rerun passed with explicit limit, cleared input and retained data.

Revalidated using `npm run verify`: regenerated bundle, **12 host tests passed / 0 failed**, and real Edge browser acceptance passed including the new CSV-byte and size-limit checks. Native replies remain explicitly simulated; no physical share-sheet verification is claimed. Naturally grown datasets may exceed 20 MiB: export now fails explicitly rather than silently, without a partial backup.

The native bridge in browser acceptance is explicitly simulated. No real Apple Vision, AVFoundation, share sheet, or authenticated Supabase operation was asserted.

Environment issue: Playwright Chromium download/install timed out; installed Microsoft Edge channel worked and is used by the test. Test dependencies stay under this directory/node_modules (ignored). Root index.html was verified byte-equivalent to HEAD after newline normalization; no root website change, commit, or deployment.
