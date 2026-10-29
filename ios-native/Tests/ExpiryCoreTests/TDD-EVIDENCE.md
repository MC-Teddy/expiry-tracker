# ExpiryCore — executed incremental TDD evidence

## Environment and command

Implemented on Windows with WSL Swift **6.4**, targeting x86_64 Linux. No network or package dependencies were used. From the repository root:

```sh
python ios-native/Tests/ExpiryCoreTests/run_direct.py
```

The runner builds the Foundation-only production module with `swiftc -swift-version 6 -warnings-as-errors`, generates XCTest discovery in Hermes scratch storage, compiles the tests, and actually executes XCTest. Build artifacts and test temporary directories are removed afterward. It does not need Package.swift or change files owned by the package/UI agent.

`verification.log` contains the complete latest executed suite output. The table below records observed RED/GREEN cycles from the actual tool executions, not invented output. Clock times are copied from XCTest output on 2026-10-15.

## Incremental tracer bullets

| Slice | Observed RED | Observed GREEN |
| --- | --- | --- |
| Calendar days/status around the spring DST transition | Source module did not exist; runner exited 1 before production was written | 20:16:55: 1 test, 0 failures |
| Offline CRUD and restart | Compiler reported missing `LocalRepository` and `TrackerSnapshot` | 20:17:28: 2 tests, 0 failures |
| Backup/photo roundtrip and stable JSON dates | Compiler reported missing `exportBackup`/`importBackup` | 20:18:05: 3 tests, 0 failures |
| Item validation before persistence/import | 20:18:30: 4 tests, 51 assertion failures; invalid values were accepted and replaced old bytes | 20:18:58: 4 tests, 0 failures |
| Schema version, duplicate IDs, settings | 20:19:15: 5 tests, 14 assertion failures | 20:19:37: 5 tests, 0 failures |
| 5 MiB photos and complete 20 MiB JSON limit | 20:20:00: 6 tests, 7 assertion failures | 20:20:43: 6 tests, 0 failures |
| Never silently overwrite a corrupt existing file | 20:21:07: 7 tests, 4 assertion failures; save replaced corrupt files | 20:21:22: 7 tests, 0 failures |
| Exact fractional Date roundtrip | Additional real filesystem characterization tests exposed equality failures at 20:22:10. A deterministic precision regression then failed twice at 20:22:41 | 20:23:01: 11 tests, 1 iOS-only skip, 0 failures |
| Gregorian ISO date under Buddhist user calendar | 20:23:24: 12 tests, 1 skip, 2 assertion failures (`-198317` rather than `1` day) | 20:23:38: 12 tests, 1 skip, 0 failures |
| Imported compact JSON must also fit after canonical serialization | 20:24:09: 13 tests, 1 skip, 1 assertion failure | 20:24:23: 13 tests, 1 skip, 0 failures |

The malformed-import and read-only-directory write-failure tests characterize the already implemented decoder/atomic-write path. Their first run uncovered Date precision loss rather than a write atomicity failure. Earlier executions used Linux's temporary filesystem: directory permissions genuinely made the write fail under the WSL non-root user (uid 1000), and assertions verified identical old bytes and readable old records afterward (including the passing 20:23:01, 20:23:38, 20:24:23, and 20:25:11 runs).

The runner was then tightened to put **all** build and test temporary data inside the configured Hermes scratch directory, which is a Windows NTFS/DrvFS mount. A real rerun at 20:26:20 exposed that this mount ignores POSIX directory mode changes: save succeeded because the fixture was not actually read-only. The test now checks that its read-only precondition is real, otherwise explicitly skips. It does not pretend that an unenforced permission change is a write failure. Latest scratch-confined verification therefore has two platform/environment skips: iOS protection and POSIX directory-permission failure. Run the same XCTest suite on APFS or ext4 to re-exercise the latter; it was already executed successfully on ext4 during development.

## Date encoding correction discovered by testing

The initial milliseconds-since-1970 codec lost submillisecond precision through reference-epoch conversion. The deterministic regression demonstrated `800000001.9876543` becoming `800000001.9876542`, and `-1e-7` becoming `-1.1920928955078125e-7` in Date's native reference interval.

Version 1 now explicitly uses Foundation `.deferredToDate` for both encoder and decoder: JSON numbers are **seconds since 2001-01-01 00:00:00 UTC**. Sorted JSON keys make repeated exports deterministic. The earlier wire-format assertion was deliberately updated to this documented format; the equality tests were not weakened. Dates remain exact across restart/export/import, including fractional values. This is a new native backup format, not a promise of web-backup compatibility.

## API and integration notes

The requested public model/repository signatures are unchanged. Model fields are mutable public `var`s for native editing. `TrackerSnapshot` additionally has a public initializer:

```swift
public init(version: Int = 1, items: [ExpiryItem] = [], settings: TrackerSettings = TrackerSettings())
```

Additional public API:

- `LocalRepository.maximumBackupBytes = 20 * 1024 * 1024`
- `LocalRepository.maximumPhotoBytes = 5 * 1024 * 1024`
- `LocalRepositoryError: Error, Equatable, Sendable` with `invalidItem(UUID, field: String)`, `unsupportedVersion(Int)`, `duplicateID(UUID)`, `invalidSettings`, and `backupTooLarge` cases. Native Foundation I/O/decoding errors also propagate.

`LocalRepository` is synchronous, not ObservableObject, not Sendable; the caller serializes access on MainActor. It stores `tracker.json` in the supplied dedicated directory. Missing storage returns an empty version-1 snapshot. Invalid/corrupt existing storage throws from load and save. Save validates the existing store before replacing it and uses Foundation atomic writing. There is no swallowed error or fallback reset.

`importBackup` only decodes/validates and returns the proposed snapshot: it never changes disk or an in-memory caller snapshot. To commit, first obtain the returned value, then `try repository.save(candidate)`, and only then publish the candidate in the UI. Export is also side-effect-free. The 20 MiB ceiling includes JSON/base64 overhead and applies both to incoming bytes and reserialized content. Files are size-checked before reading. Photos are inline base64, not external paths.

Validation: name non-whitespace and at most 200 characters; category non-whitespace and at most 100 characters (free-form, not a hardcoded category list); quantity 1...999999; exactly formatted, real Gregorian yyyy-MM-dd expiry; photo at most 5 MiB; version exactly 1; unique UUIDs; settings `0 <= criticalDays <= soonDays <= 3650`. Notes and barcodes are covered by the complete backup byte ceiling, without arbitrary field truncation. Validation rejects values rather than modifying them.

Date-only expiry strings are always Gregorian, in the supplied calendar's timezone. Remaining days use calendar start-of-day/day components, never fixed 86400-second division. Invalid unsaved model dates return `Int.min` and `.expired` conservatively; repository persistence rejects those dates.

## Honest platform limitation

`testIOSStorageProtectionAndBackupExclusion` is present but explicitly skipped on Linux. The iOS-conditional implementation sets directory backup exclusion before writing and protects the directory/files with complete-until-first-user-authentication Data Protection. The containing directory's exclusion covers its local-store tree. Protection is part of the atomic file write, not a fallible post-commit update.

An installed local `darwin` Swift SDK was subsequently discovered with `swift sdk list` and read-only `swift sdk configure --show-configuration darwin arm64-apple-ios`. The complete production core, including its iOS branches, was successfully typechecked for **arm64-apple-ios17.0** with Swift 6 and warnings-as-errors against the installed **iPhoneOS27.1.sdk**. Actual tool output:

```text
iOS arm64 typecheck exit: 0
```

The check used `swiftc -swift-version 6 -warnings-as-errors -typecheck -module-name ExpiryCore -target arm64-apple-ios17.0`, the SDK's `-sdk`/`-resource-dir`, and a scratch-only module cache. No download or package build was needed.

**No iOS device/simulator runtime was available, so an iOS RED/GREEN runtime cycle or verification of these filesystem attributes was not possible.** The iOS branch is typechecked, not falsely represented as a Linux runtime pass. The package/UI owner should run the conditional XCTest on an Apple runtime.

For SwiftPM, the package owner should exclude `run_direct.py`, `TDD-EVIDENCE.md`, and `verification.log` from the test target to avoid unhandled-file warnings. No Package.swift or UI file was edited here.
