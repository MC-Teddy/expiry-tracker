# Expiry Tracker — native iPhone app

A local-first SwiftUI app, not a web wrapper. iOS 17+. Native version **1.2.0 (12)**; bundle identity **com.ahasan.expirytracker**. Signed-in accounts share items and photos with the website through the existing Supabase project. The app still works with no account and with no network.

## What is implemented

- Adaptive grouped surfaces, a semantic system-blue accent, system typography and SF Symbols, with native Inventory and Settings tabs.
- Compact overview counts for Expired, Use first, Expiring soon, and Fresh; tap a count to focus the inventory and tap Clear to reset. No duplicate All statuses picker or category filter rows.
- Search by name, category, notes, or barcode, with expiry-sorted inventory.
- Item detail with photo, expiry, days remaining, quantity, category, notes, and optional barcode.
- Add/edit form with the date picker, expiry scan action, progress, and date suggestions in one grouped card. Product-name scanning stays beside the name field. Optional barcode/notes sit under More details, with unsaved-change confirmation and destructive photo/item removal confirmations.
- AVFoundation camera reused from the existing native camera controller, with typed Swift photo/barcode results (no bridge). Torch, permission fallback, cancellation, background teardown, orientation, bounded image normalization, and Photos picker remain native.
- Apple Vision text recognition uses on-device machine learning off the main thread, with no API key, cloud service, or recognition fees. A single unambiguous expiry date automatically fills the editor's date field; the item is persisted only on Save. Low-confidence recognition and ambiguous dates require selection or manual entry. Numeric year-month-day and regional day/month/year dates, English month names, Arabic-Indic/Persian digits, and recognition spaces around separators are supported. Four-digit years are limited to 1900–2199; two-digit trailing years mean 2000–2099. Missing days (month/year labels) are never invented. Explicit expiry/best-before/use-by wording takes priority over production/packed dates, with English and common Arabic label markers.
- Optional barcode scanning records the code only; there is no network product lookup.
- Scan product name reads the front label using local Vision OCR. Prominent, confident text can fill an untouched empty name; up to three source-text suggestions are offered for selection, including adjacent brand/product lines when appropriate. Existing names and manual edits made during recognition are preserved. This reads visible text, not an internet product database or unlabelled-object identity.
- Gregorian `yyyy-MM-dd` storage, POSIX date formatter, and the device's local time zone; date pickers explicitly use the same Gregorian calendar. Display dates remain localized.
- Local repository-backed inventory/settings. The `@MainActor ObservableObject` publishes changed snapshots **only after a successful disk save**. Failed writes leave displayed data unchanged. Failed opening does not silently replace a corrupt store with an empty inventory.
- Critical/soon thresholds, explicitly saved, with threshold explanations.
- Settings shows account status. Sign in with the same email and password as the website (no sign-up; accounts are created on the web by an admin). The session is kept in the Keychain. Last sync time, pending changes, and **Sync now** are shown. Sign out stops syncing and leaves items on the phone. Warning days stay on the device.
- Native share sheet for complete JSON backups and real quoted UTF-8/CRLF CSV exports. CSV includes item fields, not photos or settings, and escapes spreadsheet-formula values.
- Native JSON file importer: bounded read, decode/validation before confirmation, visible incoming item count, destructive replacement confirmation, then atomic repository save. Cancellation/invalid import do not replace current data. A successful restore shows its item count.
- Clear local-storage, invalid-backup, item-validation, camera, and recognition errors.

## Storage and compatibility

`Library/Application Support/NativeExpiryTracker/tracker.json` holds the native snapshot. Photos are inline backup data. The repository validates schema/version, identifiers, fields, warning thresholds, calendar days, and sizes; it atomically replaces the JSON file. Current limits are **20 MB for the entire serialized store/backup** and **5 MB per photo**. On Apple platforms, every repository load/save/import/export also validates ImageIO container/header metadata without full-image decoding or decoded-image caching: a complete single-image container, positive integral dimensions, **no edge over 4096 pixels**, and **no more than 16,000,000 pixels**. Empty, unrecognized, truncated-header, multi-image, and oversized images are rejected as invalid photos before committing. Header validation is not a full pixel-stream integrity check; unreadable pixel data fails closed during bounded thumbnail creation. Camera/library inputs remain normalized to an upright JPEG at up to 2048 pixels before attachment. All three UI render paths use ImageIO thumbnail decoding capped at **2048 pixels** (inventory rows: **160 pixels**), not `UIImage(data:)` on restored bytes.

Photo recognition uses a one-shot generation token for each new selection; selecting another photo or removing it invalidates old work. Both success and failure must consume the current token before changing text, suggestions, errors, or busy state. A late old OCR completion cannot clear the newer scan's progress or repopulate a removed photo's suggestions.

The repository's iOS branch applies Data Protection and excludes the local directory from automatic backup; this is compiled but its iOS-only runtime test cannot execute on Linux. **Export JSON backups before uninstalling or changing phones.** Share exports are temporary files with iOS Data Protection; backup files contain private notes/photos and should be shared deliberately.

## Account sync

The phone uses the same Supabase project as `index.html`: `https://viupqrjyszvvcpnxrmsq.supabase.co`, the public anon key, the `items` table, and the `item-images` bucket. Requests go through URLSession to the Auth, REST, and Storage HTTP APIs. There is no schema change.

Rows use the website's columns: `id`, `name`, `expiry` (`yyyy-MM-dd`), `icon` (the native category), `added` (creation time, UTC ISO-8601), `user_id`, and `device_id`. Inserts send the phone's item id so both sides share it. Photos use `<user_id>/<item_id>.jpg` (the phone's photo, which the website shows first) and `<user_id>/<item_id>_full.jpg` (the website's package photo). If only the package photo exists, the phone shows that. Replacing a photo uploads the primary file. Removing a photo deletes both files, so a package photo does not reappear as the only picture.

`quantity`, `notes`, and `barcode` are sent when the table accepts them. If PostgREST reports that a column is missing, the phone stops sending it and keeps the value locally; pulling a web row does not erase it. `updated_at` is sent the same way and, when the column exists, is the last-write time. The website does not write `updated_at` itself. Without that column, a web edit still applies when the phone has no pending edit, but if both sides changed the same field the phone edit wins when it is newer than `added`. With `updated_at` (or a database trigger that maintains it), the newer timestamp wins. Adding nullable `quantity`, `notes`, `barcode`, and `updated_at timestamptz` columns would let those fields and web edit times sync; that migration was not applied.

Sync is offline-first. Adds, edits, and deletes are saved in `tracker.json` first, then recorded in `sync-ledger.json` in the same directory. The queue is sent when the network returns, when the app becomes active, and from **Sync now**. A failed send stays queued. The same account's items are merged; local-only items that exist at the first sign-in are uploaded, not discarded. Signing out keeps the on-phone copy. Signing in as a different person parks the previous account on disk and uploads only items created while signed out, so one account's inventory is not copied into another.

The whole store is still limited to 20 MB and each photo to 5 MB. A cloud account larger than that cannot be saved locally; the error is shown and the previous on-phone data is kept. Warning days are not in the `items` table and are not synced. Recognition stays on the device.

On a phone, check: sign in with a website account and confirm the same items appear; add, edit, and delete on each side and run **Sync now**; add a photo on each side; turn on airplane mode, edit, then reconnect and confirm the queued change is sent; sign out and confirm the on-phone list remains; sign in again and confirm a second account does not receive the first account's items.

## Package layout

- `Sources/ExpiryCore/`: Foundation models, status/day calculations, validation, persistence, backup format, and the Supabase row/queue/merge logic exercised on Linux.
- `Sources/ExpiryTracker/`: native SwiftUI screens/model, camera, Vision integration, calendar/date suggestions, CSV export, and user-facing error explanations.
- `Tests/ExpiryCoreTests/`: core tests, including sync queue, merge, and Supabase row mapping, plus original TDD evidence.
- `Tests/AppLogicTests/`: date/OCR suggestion, fixed storage-calendar, CSV, and error-explanation tests.
- `Support/`: plist and opaque 1024px native calendar/checkmark app icon.
- `verification/`: reproducible unsigned-build verifier, test/build logs, TDD RED logs, and inspected artifact metadata.

There is exactly one library product (`ExpiryTracker`), an `ExpiryCore` target, an app target, and XCTest targets. Apple-only files, Keychain, and URLSession are guarded so the same package can run Foundation tests on Linux. There is no bundled HTML/JavaScript/CSS, web runtime, or WebKit dependency. Networking is limited to the Supabase host above.

## Reproduce verification (existing Windows/WSL setup)

From Windows with the existing Ubuntu/Swiftly/xtool installation:

```sh
python ios-native/verification/verify.py
```

Or in the existing Ubuntu login shell:

```sh
cd /mnt/c/Users/mr_an/Desktop/Dev/Claude/expiry-tracker/ios-native
swift test
xtool dev build
```

The verifier does not install, launch, provision, sign, change the SDK, or alter the toolchain. It records real command output, then reads the generated plist, parses Mach-O load commands, checks arm64 executable identity/version, checks the packaged icon, and rejects web source/resources/dependencies.

### Verified gates — October 15, 2026

- Swift **6.4**, xtool **1.22.2**, existing installed Darwin SDK.
- Clean `swift test`: **39 cases started, 37 passed, 2 skipped, zero failures**. Skips: iOS-only Data Protection/backup exclusion and Apple ImageIO actual-image/header/repository/thumbnail runtime checks. Linux runs Foundation policies, camera lens/focus/lifecycle policies, editor dismissal state, and delayed OCR generation regressions. No test/build warnings in the final clean run; the verifier now rejects warnings.
- New review-fix TDD evidence: `verification/photo-policy-red.log` → `photo-policy-green.log`; `recognition-generation-red.log` → `recognition-generation-green.log`. `recognition-delayed-red.log` also records real failed delayed-result/busy/one-shot assertions with the token guard removed. Source-wiring checks failed before integration (`review-wiring-red.log`) and now pass all seven checks (`review-wiring-green.log`); these supplement rather than replace Swift behavior tests.
- Apple tests **cross-compiled**, not executed: `verification/photo-apple-compile.log`. The existing SwiftBuild test-target path produced duplicate output commands; the existing deprecated native build backend compiled the test target successfully (its deprecation warning is recorded). Actual PNG headers cover a valid 1×1 image, accepted 4096×1 thumbnail clamped to 2048, rejected 8192×1 image, malformed/truncated bytes, and load/save/import rejection with original-file preservation. Apple runtime execution still requires a simulator/device.
- Earlier helper TDD evidence remains in `verification/ocr-red.log`, `verification/csv-red.log`, and `Tests/ExpiryCoreTests/`. Final full green run: `verification/tests.log`.
- `xtool dev build`: **success, unsigned**. Bundle: `xtool/ExpiryTracker.app` (ignored build output).
- Generated executable inspected: **64-bit arm64 Mach-O**, not a placeholder; linked SwiftUI/UIKit/AVFoundation/Vision/PhotosUI frameworks.
- Generated plist read back: `com.ahasan.expirytracker`, **1.1.0**, build **6**. Executable SHA-256 and byte count are recorded in `verification/artifact.json`.
- No WebKit linked library, web resources, or source networking/web-runtime references found. Full load-command inventory and metadata: `verification/artifact.json`.
- No installation, launch, provisioning, or toolchain change performed. No commit created.

## Build 5 camera/editor lifecycle fix

Source investigation found two competing owners: the editor cleared its SwiftUI full-screen cover while `CameraController.finish` also dismissed itself using UIKit. This is a confirmed source defect and the leading explanation for the reported return to the dashboard; the exact UIKit/SwiftUI runtime sequence has not been reproduced on an iPhone here.

SwiftUI now owns camera-cover dismissal exclusively. UIKit dismisses only the Photos child, with result delivery deferred until child dismissal completes (including cancellation/interruption during that transition). Camera teardown and result delivery remain one-shot. The Foundation `EditorCaptureState` stages photo/barcode/error/cancel results until `fullScreenCover`'s `onDismiss`, then the editor starts OCR. No-date results are persistent inline manual-entry guidance rather than alerts; actual OCR/camera/save errors require explicit OK. Attached photos and existing form fields remain available for manual date selection and saving. Existing OCR generation guards remain in both completion paths; editor disappearance and photo removal invalidate recognition. No date-parser formats changed.

Six added Foundation tests exercise capture staging/one-shot consumption, cancellation/duplicate callbacks, staged camera errors, no-date guidance, OCR failure/explicit acknowledgement, and photo replacement/removal. They exercise the production helper's photo/barcode draft state, not SwiftUI/UIKit rendering or the physical camera. Source wiring checks supplement those tests. Evidence: `verification/camera-wiring-red.log`, `camera-state-red.log` → `camera-state-green.log`, `camera-warning-red.log` → `camera-warning-green.log`, `camera-error-red.log`, `camera-reset-red.log`, and `camera-alert-red.log`; final green output is `tests.log` and `review-wiring-green.log`. Initial new-API RED runs fail compilation for the missing state/methods; OCR-error RED contains actual failed XCTest assertions, and wiring RED fails against the original production source.

Physical-iPhone regression acceptance: take a product photo with no supported date, confirm the editor (not dashboard) remains visible with photo/name/details intact, manually set the date and save. Repeat with a recognized date, camera Close, Photos cancel/select, forced recognition failure and explicit OK, background/interruption during Photos dismissal, and a barcode scan. Automated tests and unsigned compilation do not establish those runtime outcomes. Build 5's dismissal fix is retained; this build 6 task did not install or launch any app.

## Build 6 automatic product-label focus

The production camera now prefers a rear virtual triple camera, then dual-wide, when continuous autofocus and automatic constituent switching are supported, otherwise the rear wide camera. Virtual framing starts at the **first** switch-over factor, clamped to finite supported bounds, not the last (telephoto) threshold. There is no zoom UI. Default fallback constituent devices are left unchanged; the switching setter is used only when the active switching behavior is not unsupported. This permits system-managed focus-distance fallback on supported hardware, not a claim that the connected phone has macro capability.

Under the camera configuration lock on the serial session queue, the shared production focus policy chooses continuous autofocus or supported single autofocus as a fallback; sets focus range restriction to `.none` when supported; centers supported focus/exposure points; and enables supported continuous exposure. Subject-area notifications recenter and restore the same automatic policy. No focus-lock mode is requested. The readable camera hint says to hold steady and move back a little if blurry; no sharpness detector or “macro enabled” claim is made.

Focus/torch work uses generation-token ownership. Capture and Photos pause invalidate queued work; finish is terminal. Writes recheck ownership after acquiring the device lock. Observers are removed and subject monitoring is disabled on session-queue teardown, including delayed setup. Session preparation can complete while Photos is open without starting preview; Photos cancellation resumes the current generation. The build 5 SwiftUI-owned dismissal and staged editor results remain intact.

Test-first evidence: `focus-build6-framing-red.log` → `focus-build6-framing-green.log`, `focus-build6-fallback-red.log` → `focus-build6-fallback-green.log`, `focus-build6-lifecycle-red.log` → final `tests.log`, and `focus-build6-wiring-red.log` / `focus-build6-active-guard-red.log` → final `review-wiring-green.log` (7 checks). New-API RED logs show compile failures for missing policy APIs, not runtime hardware failures. Seven focus/lens tests and three ownership tests exercise the production helpers; source checks supplement these and the iOS compile, not physical camera verification.

Final clean verification: `swift package clean`, `swift test`, `xtool dev build`, followed by plist/Mach-O/resource checks through `verification/verify.py`. The unsigned artifact is `xtool/ExpiryTracker.app`, version **1.1.0 (6)**. No install, signing, or launch was performed. A bounded `ideviceinfo -k ProductType` returned `ERROR: No device found!` (`verification/focus-build6-device.log`), so the phone's lenses and real close-focus performance remain unverified.

Phone acceptance for build 6: bring a product label from normal distance toward the camera and back in good light; verify automatic sharpness recovery and supported lens transitions without zoom controls. Repeat with a barcode, torch, orientation changes, Photos cancel/select (including opening Photos immediately), capture/Close/background while focus is active, and the build 5 no-date/manual-date save flow. A phone with no focus-capable close-up constituent may still need more distance; do not interpret an unsigned build as proof of macro support.

## Build 7 local expiry-date autofill — October 16, 2026

The Scan expiry date action uses the existing native camera and Photos picker. After the camera cover closes, Apple Vision reads the photo locally. A single eligible calendar date with sufficiently confident OCR fills the expiry field and shows a persistent, accessible “Filled from photo” message. A VoiceOver announcement reads the filled date. Native Form/DatePicker controls, semantic colors, scalable text, and 44-point scan/selection targets follow the Apple design skill's utility-screen guidance.

The parser prefers explicitly labelled expiry dates, excludes production dates, rejects invalid calendar days and incomplete dates, and offers both interpretations for ambiguous regional dates. Clear unlabeled dates can also fill. Two-digit years use the documented 2000–2099 interpretation. Calendar parsing supports Arabic-Indic/Persian digits and common Arabic label markers; actual OCR language and label accuracy depend on Vision and the photo, and have not been verified on an iPhone here.

Starting a replacement scan invalidates old recognition. Manual date edits while OCR runs prevent automatic replacement of that edit; the recognized date remains available for selection. Photo removal clears scan feedback and cancels ownership. Saving remains an explicit action.

`verification/verify.py` passed: **47 tests started, 45 passed, 2 Apple-runtime-only skips, zero failures or compiler warnings**. Eight new behavior tests cover filling, expiry/production context, ambiguity, duplicate dates, printed formats/digits, invalid dates, low-confidence/manual-edit gating, removal/failure feedback, and stale completion ownership. The iOS 17+ arm64 app compiled with the existing Swift/xtool installation as **1.1.0 (7)**; metadata and linked frameworks are recorded in `verification/artifact.json`. These checks do not establish physical-camera OCR accuracy or UI behavior.

At the user's request, `xtool dev run --usb` then provisioned, signed, installed, and verified this update on the connected iPhone with exit 0. xtool's signed bundle identifier is `XTL-S7Q3EFT28Y.com.ahasan.expirytracker`; the original source bundle identifier stays unchanged. A launch attempt with that signed identity resolved the installed `ExpiryTracker` executable but failed with `DebugserverClient.Error.unknown`. Open the app manually; no successful launch or camera OCR runtime verification is claimed. Deployment evidence is summarized in `verification/deployment-build7.json`; `artifact.json` describes the earlier unsigned build verification.

## Build 8 whole-app redesign — October 16, 2026

The native app now uses Inventory/Settings tabs, system-blue interactions, adaptive grouped surfaces, a compact status overview, and clearer item rows. The All statuses and category filter picker rows are removed. Search remains; tapping a status count narrows the inventory and reveals Clear only while selected. Add/edit puts scanning first, separates the expiry field, and keeps barcode/notes under More details. Details has a photo/name/expiry hierarchy and relative expiry text. Settings groups local storage, warning days, and data export/restore, and reads the real bundle version.

The camera screenshot's text rectangles and long hint are replaced with a circular shutter, 48-point symbol controls, a visible label frame, a short hint, Photos, and tips. A material control panel moves beside the preview in landscape; guidance scrolls at large text sizes, and Reduce Transparency uses an opaque surface. Focus, session ownership, image bounds, local OCR, and the staged editor handoff are preserved. Design rationale and device acceptance steps are in `DESIGN.md`.

Final `verification/verify.py` run passed: **47 tests started, 45 passed, 2 Apple-runtime-only skips, zero failures, zero compiler warnings**, plus all seven source-wiring regressions. The arm64 iOS build is **1.1.0 (8)**; `verification/artifact.json` records the final unsigned artifact. These checks do not establish SwiftUI/UIKit layout or camera behavior on a phone.

After the user reconnected the iPhone, `xtool dev run --usb` provisioned, signed, installed, and verified build 8 with exit 0. Launching the existing signed identifier resolved `ExpiryTracker` but returned `DebugserverClient.Error.unknown`; open the app manually. `verification/deployment-build8.json` records the outcome. Physical-device visual and camera acceptance remain pending.

## Build 9 local product-name scanning — October 16, 2026

The editor has a **Scan product name** action beside the name field. Its camera mode uses a taller frame and front-label guidance. Camera and Photos inputs use the same bounded, upright-image pipeline and on-device Vision OCR. Recognized text observations retain confidence and normalized geometry for ranking prominent label lines. Package dates, nutrition/storage/production text, measurements, and duplicate names are filtered. An adjacent brand/product combination is a review-only suggestion. At most three suggestions appear, expanded by default and editable through the name field.

Automatic name filling requires a multiword line, Vision confidence at least 0.85, normalized line height at least 0.035, and a prominence score at least 1.6 times the next eligible line (or no competitor). These are conservative heuristics, not calibrated product-identity probabilities. Suggestions remain available when automatic filling is not justified. `ProductNameDraft` owns revision checks and protects all existing names and manual edits, including an edit subsequently cleared during OCR. Explicitly choosing a suggestion can replace a name. No category, quantity, or other product facts are invented.

The product scan can still detect an expiry date if one is visible; a front-label photo without a date does not show a missing-date warning. Capture purpose is staged until cover dismissal. Photo replacement/removal clears old name suggestions; failed/stale OCR cannot publish names. Accepted draft names survive photo removal. All persistence remains explicit on Save. Real-package OCR accuracy and presentation still require a phone check.

Ten new Swift behavior tests exercise name ranking, brand/product options, metadata filtering, ambiguous/low-confidence labels, Arabic text and deduplication, invalid geometry, edit protection, product-mode date handling, failures, and stale ownership.

`verification/verify.py` passed for build 9: **57 tests started, 55 passed, 2 Apple-runtime-only skips, zero failures, zero compiler warnings**, plus all seven source-wiring regressions. `verification/artifact.json` records the final unsigned arm64 iOS app and its framework/metadata checks. These tests use recognized-text fixtures, not a camera-image corpus; actual name recognition accuracy on packages is not established.

After the user reconnected the phone, `xtool dev run --usb` provisioned, signed, installed, and verified build 9 with exit 0. See `verification/deployment-build9.json`. Automatic launch was not retried; previous builds could not use the device debug service. Open the app manually. Physical product-photo recognition acceptance remains pending.

## Build 10 common printed expiry formats — October 17, 2026

The supplied shampoo month/year label and dot-matrix P/E stamp exposed parser limitations in addition to potential OCR limitations. `DateSuggestions` now supports month/year precision as review-only last-day options, P/E and additional expiry/production headings, compact and spaced date forms, English and Arabic Gregorian month names, Arabic-Indic/Persian digits, and label-bound OCR digit corrections. Separate OCR labels and values are matched by printed geometry, not observation ordering. Relevant date confidence replaces the old all-text confidence gate. Ambiguous/corrected/month-only dates require explicit selection or manual entry before Save; complete unambiguous dates retain automatic filling. See `DATE-FORMATS.md` for exact examples, century conventions, supported scope, and review rules.

The accurate Vision request now accepts smaller text (`minimumTextHeight = 0.005`) and retries once with grayscale/contrast enhancement when the first pass finds no date. This is bounded on-device processing and does not replace Vision with a cloud model. It does not prove improved recognition on the original photos until tested on an iPhone.

Final `verification/verify.py`: **71 tests started, 69 passed, 2 Apple-runtime-only skips, zero failures, zero compiler warnings**, plus seven source-wiring regressions. Fourteen new tests cover the printed examples and broader formats, invalid dates, row/stacked/conflicting label geometry, per-date confidence, explicit month selection, ambiguity, and sell-by review. Test fixtures are manually transcribed text and synthetic geometry, not recorded Vision results from the two HEIC attachments. The final arm64 iOS **1.1.0 (10)** artifact is described in `verification/artifact.json`.

Build 10 was installed over USB on 2026-10-17. xtool completed signing, installation, and device verification with exit code 0; see `verification/deployment-build10.json`. Open the app manually on the iPhone. On-phone testing of the original HEIC photos remains pending.

## Phone acceptance still pending

Build 11 groups expiry entry, scanning, recognition feedback, and suggestions in one card. Product-name scan feedback stays beside the name input; required fields and date review explain disabled Save. Accessibility text sizes stack the date controls. Inventory recovery wording, duplicate category display, Settings spacing, and action indicators were refined. Verification: 69 tests passed, 2 Apple-runtime-only skips, seven wiring checks passed, arm64 iOS compilation passed with no compiler warnings. Build 11 was installed over USB on 2026-10-17 with xtool device verification and exit code 0; see `verification/deployment-build11.json`. Open the app manually. Visual and VoiceOver inspection on the phone remains pending.

Compilation and Foundation tests are not on-phone UI/runtime verification. Before deployment is accepted, verify on a real iPhone:

1. Fresh launch, light/dark appearance, Dynamic Type/VoiceOver, navigation and empty states.
2. Add/edit/delete, quantity/category/notes, cancel/discard, photos, and force-quit/reopen persistence in airplane mode.
3. Date/status boundaries (including midnight and non-Gregorian device settings); dashboard/filter/search refresh.
4. Camera permission allowed/denied, capture, torch, orientation, interruption/background teardown, photo-library cancellation/selection, Vision text/date suggestions, ambiguous-date confirmation, and barcode scans.
5. JSON export through the share sheet; cancel/invalid/oversized import; confirmation; complete replacement including photos/settings; exported-backup re-import.
6. CSV opening in a spreadsheet, Unicode/quoted/newline fields, and neutralized formulas.
7. Locked-device Data Protection and automatic backup exclusion behavior, storage/write failures, and persisted user-visible errors.
8. Same-identity signed-upgrade behavior with the existing app, **without assuming old data is migrated**.

Notifications and product databases are not part of this release. Account sync is the Supabase behavior described above; it is not a migration of an older web backup file, and it has not been exercised on a phone in this environment.
