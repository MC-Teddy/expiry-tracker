import Foundation
import XCTest
@testable import ExpiryCore

final class ExpiryCoreTests: XCTestCase {
    func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    func testCRUDSurvivesRepositoryRestart() throws {
        let directory = try temporaryDirectory()
        let repository = try LocalRepository(directory: directory)
        XCTAssertTrue(try repository.load().items.isEmpty)
        var snapshot = TrackerSnapshot(items: [], settings: TrackerSettings(soonDays: 20, criticalDays: 5))
        let item = ExpiryItem(name: "Milk", category: "Dairy", expiry: "2028-02-29", createdAt: Date(timeIntervalSince1970: 1234.5))
        snapshot.items.append(item)
        try repository.save(snapshot)
        XCTAssertEqual(try LocalRepository(directory: directory).load().items, [item])
        snapshot.items[0].quantity = 3
        snapshot.items[0].notes = "Opened"
        try repository.save(snapshot)
        let restarted = try LocalRepository(directory: directory).load()
        XCTAssertEqual(restarted.items, snapshot.items)
        XCTAssertEqual(restarted.settings, snapshot.settings)
        snapshot.items.removeAll()
        try repository.save(snapshot)
        XCTAssertTrue(try LocalRepository(directory: directory).load().items.isEmpty)
    }

    func testBackupRoundTripsPhotoAndStableDatesWithoutWriting() throws {
        let repository = try LocalRepository(directory: temporaryDirectory())
        #if canImport(ImageIO)
        let photo = try XCTUnwrap(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVR4nGNoAAAAggCBd81ytgAAAABJRU5ErkJggg=="))
        #else
        let photo = Data([0, 1, 127, 128, 255])
        #endif
        let item = ExpiryItem(name: "Milk", category: "Dairy", expiry: "2028-02-29", barcode: "00123", photo: photo, createdAt: Date(timeIntervalSince1970: 1234.5))
        let snapshot = TrackerSnapshot(items: [item])
        let data = try repository.exportBackup(snapshot)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let items = try XCTUnwrap(json["items"] as? [[String: Any]])
        XCTAssertEqual(items[0]["createdAt"] as? Double, item.createdAt.timeIntervalSinceReferenceDate)
        XCTAssertEqual(items[0]["photo"] as? String, photo.base64EncodedString())
        let restored = try repository.importBackup(data)
        XCTAssertEqual(restored.items, [item])
        XCTAssertEqual(restored.settings, snapshot.settings)
        XCTAssertEqual(try repository.exportBackup(snapshot), data)
        XCTAssertTrue(try repository.load().items.isEmpty, "Import validates only; caller explicitly saves")
    }

    func testInvalidItemsAreRejectedBeforeSaveOrImport() throws {
        let directory = try temporaryDirectory()
        let repository = try LocalRepository(directory: directory)
        let good = ExpiryItem(name: "Milk", category: "Dairy", expiry: "2028-02-29")
        try repository.save(TrackerSnapshot(items: [good]))
        let file = directory.appendingPathComponent("tracker.json")
        let original = try Data(contentsOf: file)
        var invalid: [ExpiryItem] = []
        for name in ["", "  \n", String(repeating: "n", count: 201)] {
            var item = good; item.name = name; invalid.append(item)
        }
        for category in ["", " \t", String(repeating: "c", count: 101)] {
            var item = good; item.category = category; invalid.append(item)
        }
        for quantity in [0, -1, 1_000_000] {
            var item = good; item.quantity = quantity; invalid.append(item)
        }
        for expiry in ["2027-02-29", "2028-02-30", "2026-13-01", "2026-00-01", "2026-01-00", "2026-1-01", "0000-01-01", "2026-01-01junk"] {
            var item = good; item.expiry = expiry; invalid.append(item)
        }
        for item in invalid {
            let snapshot = TrackerSnapshot(items: [item])
            XCTAssertThrowsError(try repository.save(snapshot), "Accepted invalid item: \(item)")
            let encoded = try JSONEncoder().encode(snapshot)
            XCTAssertThrowsError(try repository.importBackup(encoded))
            XCTAssertEqual(try Data(contentsOf: file), original)
        }
        var boundary = good
        boundary.name = String(repeating: "n", count: 200)
        boundary.category = String(repeating: "c", count: 100)
        boundary.quantity = 999_999
        XCTAssertNoThrow(try repository.exportBackup(TrackerSnapshot(items: [boundary])))
    }

    func testSnapshotEnvelopeRejectsUnsupportedVersionDuplicateIDsAndBadSettings() throws {
        let repository = try LocalRepository(directory: temporaryDirectory())
        let item = ExpiryItem(name: "Bread", category: "Food", expiry: "2026-12-01")
        let invalid = [
            TrackerSnapshot(version: 0), TrackerSnapshot(version: 2),
            TrackerSnapshot(items: [item, item]),
            TrackerSnapshot(settings: TrackerSettings(soonDays: -1)),
            TrackerSnapshot(settings: TrackerSettings(criticalDays: -1)),
            TrackerSnapshot(settings: TrackerSettings(soonDays: 2, criticalDays: 3)),
            TrackerSnapshot(settings: TrackerSettings(soonDays: 3651))
        ]
        for snapshot in invalid {
            XCTAssertThrowsError(try repository.exportBackup(snapshot))
            XCTAssertThrowsError(try repository.importBackup(JSONEncoder().encode(snapshot)))
        }
        XCTAssertNoThrow(try repository.exportBackup(TrackerSnapshot(settings: TrackerSettings(soonDays: 0, criticalDays: 0))))
        XCTAssertNoThrow(try repository.exportBackup(TrackerSnapshot(settings: TrackerSettings(soonDays: 3650, criticalDays: 3650))))
    }

    func testPhotoAndSerializedBackupByteLimits() throws {
        let directory = try temporaryDirectory()
        let repository = try LocalRepository(directory: directory)
        let base = ExpiryItem(name: "Photo", category: "Food", expiry: "2027-01-01")
        try repository.save(TrackerSnapshot(items: [base]))
        let original = try Data(contentsOf: directory.appendingPathComponent("tracker.json"))
        var item = base
        item.photo = Data(repeating: 7, count: 5 * 1024 * 1024)
        #if canImport(ImageIO)
        // Size alone is insufficient on Apple: these are not valid image headers.
        XCTAssertThrowsError(try repository.exportBackup(TrackerSnapshot(items: [item])))
        #else
        XCTAssertNoThrow(try repository.exportBackup(TrackerSnapshot(items: [item])))
        #endif
        item.photo!.append(7)
        let largePhoto = TrackerSnapshot(items: [item])
        XCTAssertThrowsError(try repository.save(largePhoto))
        XCTAssertThrowsError(try repository.importBackup(JSONEncoder().encode(largePhoto)))
        var items: [ExpiryItem] = []
        for _ in 0..<4 {
            var copy = base; copy.id = UUID(); copy.photo = Data(repeating: 7, count: 4 * 1024 * 1024)
            items.append(copy)
        }
        XCTAssertThrowsError(try repository.exportBackup(TrackerSnapshot(items: items)))
        XCTAssertThrowsError(try repository.save(TrackerSnapshot(items: items)))
        var padded = try repository.exportBackup(TrackerSnapshot())
        padded.append(Data(repeating: 32, count: 20 * 1024 * 1024 - padded.count))
        XCTAssertNoThrow(try repository.importBackup(padded))
        padded.append(32)
        XCTAssertThrowsError(try repository.importBackup(padded))
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("tracker.json")), original)
        try padded.write(to: directory.appendingPathComponent("tracker.json"))
        XCTAssertThrowsError(try repository.load())
    }

    func testCorruptedExistingFileCannotBeSilentlyReplaced() throws {
        let directory = try temporaryDirectory()
        let file = directory.appendingPathComponent("tracker.json")
        let corruptions = [Data("not JSON".utf8), Data("{\"version\":1}".utf8)]
        for bytes in corruptions {
            try bytes.write(to: file)
            let repository = try LocalRepository(directory: directory)
            XCTAssertThrowsError(try repository.load())
            XCTAssertThrowsError(try repository.save(TrackerSnapshot()))
            XCTAssertEqual(try Data(contentsOf: file), bytes)
        }
    }

    func testWriteFailurePreservesPreviousBytes() throws {
        let directory = try temporaryDirectory()
        let repository = try LocalRepository(directory: directory)
        let item = ExpiryItem(name: "Bread", category: "Food", expiry: "2026-12-01")
        try repository.save(TrackerSnapshot(items: [item]))
        let file = directory.appendingPathComponent("tracker.json")
        let original = try Data(contentsOf: file)
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: directory.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path) }
        guard !FileManager.default.isWritableFile(atPath: directory.path) else {
            throw XCTSkip("Filesystem does not enforce POSIX directory permissions; run this test on APFS or Linux ext4")
        }
        XCTAssertThrowsError(try repository.save(TrackerSnapshot()))
        XCTAssertEqual(try Data(contentsOf: file), original)
        XCTAssertEqual(try repository.load().items, [item])
    }

    func testMalformedImportPreservesExistingSnapshot() throws {
        let directory = try temporaryDirectory()
        let repository = try LocalRepository(directory: directory)
        let item = ExpiryItem(name: "Bread", category: "Food", expiry: "2026-12-01")
        try repository.save(TrackerSnapshot(items: [item]))
        let file = directory.appendingPathComponent("tracker.json")
        let original = try Data(contentsOf: file)
        for data in [Data(), Data("null".utf8), Data("{}".utf8), Data("{\"version\":1,\"items\":[],\"settings\":{}}".utf8)] {
            XCTAssertThrowsError(try repository.importBackup(data))
            XCTAssertEqual(try Data(contentsOf: file), original)
        }
        XCTAssertEqual(try repository.load().items, [item])
    }

    func testIOSStorageProtectionAndBackupExclusion() throws {
        #if os(iOS)
        let directory = try temporaryDirectory()
        let repository = try LocalRepository(directory: directory)
        try repository.save(TrackerSnapshot())
        XCTAssertEqual(try directory.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
        let file = directory.appendingPathComponent("tracker.json")
        let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
        XCTAssertEqual(attributes[.protectionKey] as? FileProtectionType, .completeUntilFirstUserAuthentication)
        #else
        throw XCTSkip("Requires an iOS simulator or device; Linux cannot verify Data Protection")
        #endif
    }

    func testBackupPreservesSubmillisecondDatePrecision() throws {
        let repository = try LocalRepository(directory: temporaryDirectory())
        for interval in [800_000_000.1234567, 800_000_001.9876543, -0.0000001] {
            let date = Date(timeIntervalSinceReferenceDate: interval)
            let item = ExpiryItem(name: "Bread", category: "Food", expiry: "2026-12-01", createdAt: date)
            let data = try repository.exportBackup(TrackerSnapshot(items: [item]))
            let restored = try repository.importBackup(data)
            XCTAssertEqual(restored.items[0].createdAt.timeIntervalSinceReferenceDate, interval)
        }
    }

    func testISOExpiryRemainsGregorianForNonGregorianUserCalendar() throws {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 3 * 3600))
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = gregorian.timeZone
        let now = try XCTUnwrap(gregorian.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 23)))
        let item = ExpiryItem(name: "Rice", category: "Food", expiry: "2026-10-16")
        XCTAssertEqual(item.daysRemaining(now: now, calendar: buddhist), 1)
        XCTAssertEqual(item.status(settings: TrackerSettings(soonDays: 0, criticalDays: 0), now: now, calendar: buddhist), .fresh)
        let invalid = ExpiryItem(name: "Bad", category: "Food", expiry: "2026-02-30")
        XCTAssertEqual(invalid.daysRemaining(now: now, calendar: gregorian), Int.min)
        XCTAssertEqual(invalid.status(settings: TrackerSettings(), now: now, calendar: gregorian), .expired)
    }

    func testImportAlsoEnforcesCanonicalSerializedSize() throws {
        let repository = try LocalRepository(directory: temporaryDirectory())
        let raw = "{\"version\":1,\"settings\":{\"soonDays\":14,\"criticalDays\":3},\"items\":[{\"id\":\"00000000-0000-0000-0000-000000000001\",\"name\":\"Bread\",\"category\":\"Food\",\"quantity\":1,\"expiry\":\"2026-12-01\",\"notes\":\"" + String(repeating: "/", count: 11 * 1024 * 1024) + "\",\"createdAt\":0}]}"
        XCTAssertLessThan(Data(raw.utf8).count, LocalRepository.maximumBackupBytes)
        XCTAssertThrowsError(try repository.importBackup(Data(raw.utf8)))
    }

    func testCalendarDayAndStatusBoundaries() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 23)))
        let settings = TrackerSettings()
        let cases: [(String, Int, ExpiryStatus)] = [
            ("2026-03-06", -1, .expired), ("2026-03-07", 0, .critical),
            ("2026-03-10", 3, .critical), ("2026-03-11", 4, .soon),
            ("2026-03-21", 14, .soon), ("2026-03-22", 15, .fresh)
        ]
        for (expiry, days, status) in cases {
            let item = ExpiryItem(name: "Milk", category: "Dairy", expiry: expiry)
            XCTAssertEqual(item.daysRemaining(now: now, calendar: calendar), days)
            XCTAssertEqual(item.status(settings: settings, now: now, calendar: calendar), status)
        }
    }
}
