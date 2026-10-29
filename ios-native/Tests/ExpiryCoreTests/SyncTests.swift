import Foundation
import XCTest
@testable import ExpiryCore

final class SyncTests: XCTestCase {
    private let user = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
    private let device = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
    private let created = Date(timeIntervalSince1970: 1_700_000_000)

    private func item(_ name: String, id: UUID = UUID(), category: String = "Dairy", quantity: Int = 1,
                      expiry: String = "2027-01-31", notes: String = "", barcode: String? = nil,
                      photo: Data? = nil, created: Date? = nil) -> ExpiryItem {
        ExpiryItem(id: id, name: name, category: category, quantity: quantity, expiry: expiry,
                   notes: notes, barcode: barcode, photo: photo, createdAt: created ?? self.created)
    }

    private func record(_ item: ExpiryItem, updated: Date? = nil, quantity: ColumnValue<Int> = .absent,
                        notes: ColumnValue<String> = .absent, barcode: ColumnValue<String> = .absent) -> CloudItemRecord {
        CloudItemRecord(id: item.id, name: item.name, category: item.category, expiry: item.expiry, added: item.createdAt,
                        updatedAt: updated, updatedAtPresent: updated != nil, quantity: quantity, notes: notes, barcode: barcode,
                        userID: user, deviceID: device.uuidString.lowercased())
    }

    func testRowMappingMatchesWebColumnsAndKeepsCalendarDates() throws {
        let milk = item("Milk", quantity: 2, notes: "Opened", barcode: "0123")
        let insertedRows = try JSONSerialization.jsonObject(with: CloudCodec.insertBody(
            item: milk, userID: user, deviceID: device, modifiedAt: created.addingTimeInterval(5), rejected: [])) as! [[String: Any]]
        let inserted = try XCTUnwrap(insertedRows.first)
        XCTAssertEqual(inserted["id"] as? String, milk.id.uuidString.lowercased())
        XCTAssertEqual(inserted["name"] as? String, "Milk")
        XCTAssertEqual(inserted["expiry"] as? String, "2027-01-31")
        XCTAssertEqual(inserted["icon"] as? String, "Dairy")
        XCTAssertEqual(inserted["added"] as? String, "2023-11-14T22:13:20.000Z")
        XCTAssertEqual(inserted["user_id"] as? String, user.uuidString.lowercased())
        XCTAssertEqual(inserted["device_id"] as? String, device.uuidString.lowercased())
        XCTAssertEqual(inserted["quantity"] as? Int, 2)
        XCTAssertEqual(inserted["notes"] as? String, "Opened")
        XCTAssertEqual(inserted["barcode"] as? String, "0123")
        XCTAssertNil(inserted["category"])
        XCTAssertNil(inserted["photo"])

        let updated = try JSONSerialization.jsonObject(with: CloudCodec.updateBody(
            item: milk, modifiedAt: created.addingTimeInterval(9), rejected: ["quantity", "notes", "barcode", "updated_at"])) as! [String: Any]
        XCTAssertEqual(Set(updated.keys), ["expiry", "icon", "name"])

        let web = """
        [{"id":"\(milk.id.uuidString.uppercased())","name":"Milk","expiry":"2027-01-31","icon":"Dairy","added":"2023-11-14T22:13:20.123456+00:00","user_id":"\(user.uuidString)","device_id":"\(device.uuidString)"}]
        """.data(using: .utf8)!
        let rows = try CloudCodec.decodeItems(web)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].id, milk.id)
        XCTAssertEqual(rows[0].category, "Dairy")
        XCTAssertEqual(rows[0].expiry, "2027-01-31")
        XCTAssertEqual(rows[0].quantity, ColumnValue<Int>.absent)
        XCTAssertEqual(rows[0].added.timeIntervalSince1970, created.timeIntervalSince1970 + 0.123456, accuracy: 0.000001)
        XCTAssertFalse(rows[0].updatedAtPresent)
    }

    func testTimestampParsingAcceptsSupabaseShapes() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let expected = calendar.date(from: DateComponents(year: 2026, month: 5, day: 2, hour: 15, minute: 4, second: 5))!
        XCTAssertEqual(CloudDate.parse("2026-05-02T15:04:05Z"), expected)
        XCTAssertEqual(CloudDate.parse("2026-05-02T15:04:05+00:00"), expected)
        let fractional = CloudDate.parse("2026-05-02T15:04:05.123456+00:00")
        XCTAssertEqual(fractional?.timeIntervalSince1970 ?? 0, expected.timeIntervalSince1970 + 0.123456, accuracy: 0.000001)
        XCTAssertEqual(CloudDate.parse("1970-01-01T00:00:00.000Z"), Date(timeIntervalSince1970: 0))
        XCTAssertEqual(CloudDate.encode(Date(timeIntervalSince1970: 0)), "1970-01-01T00:00:00.000Z")
        XCTAssertEqual(CloudDate.encode(Date(timeIntervalSince1970: 1.234)), "1970-01-01T00:00:01.234Z")
    }

    func testPhotoPathsMatchTheWebsite() {
        let itemID = UUID(uuidString: "12345678-1234-1234-1234-1234567890ab")!
        XCTAssertEqual(CloudPaths.imagePath(userID: user, itemID: itemID, full: false),
                       "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/12345678-1234-1234-1234-1234567890ab.jpg")
        XCTAssertEqual(CloudPaths.imagePath(userID: user, itemID: itemID, full: true),
                       "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/12345678-1234-1234-1234-1234567890ab_full.jpg")
    }

    func testQueueCoalescesEditsAndDropsUnsyncedDeletes() {
        var ledger = SyncLedger(accountUserID: user, deviceID: device)
        let original = item("Milk")
        ledger.noteUpsert(previous: nil, item: original, at: created, sessionActive: true)
        var edited = original
        edited.name = "Oat milk"
        edited.photo = Data([1, 2, 3])
        ledger.noteUpsert(previous: original, item: edited, at: created.addingTimeInterval(10), sessionActive: true)
        XCTAssertEqual(ledger.queue[original.id]?.action, .upsert)
        XCTAssertEqual(ledger.queue[original.id]?.photo, .upload)
        XCTAssertEqual(ledger.queue[original.id]?.modifiedAt, created.addingTimeInterval(10))

        ledger.noteDelete(id: original.id, at: created.addingTimeInterval(20))
        XCTAssertNil(ledger.queue[original.id], "Deleting an item before its first successful upload cancels the queued create")

        ledger.baselines[original.id] = ItemBaseline(name: original.name, category: original.category, expiry: original.expiry, added: created)
        ledger.noteUpsert(previous: nil, item: original, at: created, sessionActive: true)
        ledger.noteDelete(id: original.id, at: created.addingTimeInterval(20))
        XCTAssertEqual(ledger.queue[original.id]?.action, .delete)
        ledger.acknowledgeDelete(id: original.id)
        XCTAssertNil(ledger.queue[original.id])

        let fresh = item("Bread")
        ledger.noteUpsert(previous: nil, item: fresh, at: created, sessionActive: true)
        ledger.noteDelete(id: fresh.id, at: created.addingTimeInterval(1))
        XCTAssertNil(ledger.queue[fresh.id], "A create that never reached the server is not uploaded just to delete it")

        var signedOut = SyncLedger()
        signedOut.noteUpsert(previous: nil, item: fresh, at: created, sessionActive: false)
        XCTAssertTrue(signedOut.localOnlyIDs.contains(fresh.id))
        XCTAssertTrue(signedOut.queue.isEmpty)
    }

    func testSignInMergesLocalItemsAndAccountSwitchDoesNotMixThem() {
        let local = item("Milk", photo: Data([9]))
        let handoff = SignInHandoff.signIn(userID: user, items: [local], ledger: SyncLedger(deviceID: device), at: created)
        XCTAssertEqual(handoff.items.map(\.name), ["Milk"])
        XCTAssertEqual(handoff.ledger.queue[local.id]?.action, .upsert)
        XCTAssertEqual(handoff.ledger.queue[local.id]?.photo, .upload)
        XCTAssertNil(handoff.parkUserID)

        let remoteOnly = item("Yogurt")
        let merged = SyncMerger.merge(items: handoff.items, ledger: handoff.ledger, remote: [record(remoteOnly)], now: created.addingTimeInterval(30))
        XCTAssertEqual(Set(merged.items.map(\.name)), ["Milk", "Yogurt"])
        XCTAssertEqual(merged.ledger.queue[local.id]?.action, .upsert)
        XCTAssertNil(merged.ledger.queue[remoteOnly.id])
        XCTAssertEqual(merged.ledger.baselines[remoteOnly.id]?.name, "Yogurt")

        var signedOut = merged.ledger
        let offline = item("Honey")
        signedOut.noteUpsert(previous: nil, item: offline, at: created.addingTimeInterval(40), sessionActive: false)
        let other = UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!
        let restored = item("Remote cheese")
        var restoredLedger = SyncLedger(accountUserID: other, deviceID: device)
        restoredLedger.baselines[restored.id] = ItemBaseline(name: restored.name, category: restored.category, expiry: restored.expiry, added: restored.createdAt)
        let switched = SignInHandoff.signIn(userID: other, items: merged.items + [offline], ledger: signedOut,
                                            restoredItems: [restored], restoredLedger: restoredLedger, at: created.addingTimeInterval(50))
        XCTAssertEqual(switched.parkUserID, user)
        XCTAssertTrue(switched.parkItems.contains { $0.name == "Milk" })
        XCTAssertFalse(switched.parkItems.contains { $0.name == "Honey" })
        XCTAssertTrue(switched.items.contains { $0.name == "Honey" })
        XCTAssertTrue(switched.items.contains { $0.name == "Remote cheese" })
        XCTAssertEqual(switched.ledger.queue[offline.id]?.action, .upsert)
        XCTAssertNil(switched.ledger.queue[restored.id])
    }

    func testLastWriteWinsAndPreservesNativeFieldsTheRowDoesNotCarry() {
        let id = UUID()
        var local = item("Milk", id: id, quantity: 4, notes: "Cold")
        var ledger = SyncLedger(accountUserID: user, deviceID: device)
        ledger.baselines[id] = ItemBaseline(name: "Milk", category: "Dairy", expiry: "2027-01-31", added: created)
        local.name = "Skim milk"
        ledger.noteUpsert(previous: item("Milk", id: id), item: local, at: created.addingTimeInterval(10), sessionActive: true)
        var remote = record(item("Whole milk", id: id), updated: created.addingTimeInterval(20))
        remote.name = "Whole milk"
        let remoteWins = SyncMerger.merge(items: [local], ledger: ledger, remote: [remote], now: created.addingTimeInterval(30))
        XCTAssertEqual(remoteWins.items[0].name, "Whole milk")
        XCTAssertEqual(remoteWins.items[0].quantity, 4)
        XCTAssertEqual(remoteWins.items[0].notes, "Cold")
        XCTAssertNil(remoteWins.ledger.queue[id])

        local.name = "Skim milk"
        ledger.queue[id] = QueuedChange(action: .upsert, modifiedAt: created.addingTimeInterval(50), photo: .unchanged)
        remote.updatedAt = created.addingTimeInterval(20)
        let localWins = SyncMerger.merge(items: [local], ledger: ledger, remote: [remote], now: created.addingTimeInterval(60))
        XCTAssertEqual(localWins.items[0].name, "Skim milk")
        XCTAssertEqual(localWins.ledger.queue[id]?.action, .upsert)

        var notesRemote = record(item("Milk", id: id), updated: created.addingTimeInterval(5), notes: .value("Shelf"))
        notesRemote.name = "Milk"
        ledger.baselines[id]?.tracksNotes = true
        ledger.baselines[id]?.notes = "Cold"
        ledger.queue[id] = QueuedChange(action: .upsert, modifiedAt: created.addingTimeInterval(10), photo: .unchanged)
        local.notes = "Fridge"
        local.name = "Milk"
        let notesWin = SyncMerger.merge(items: [local], ledger: ledger, remote: [notesRemote], now: created.addingTimeInterval(15))
        XCTAssertEqual(notesWin.items[0].notes, "Fridge")
        XCTAssertEqual(notesWin.ledger.queue[id]?.action, .upsert)
    }

    func testCleanRemoteEditAppliesAndWebDeleteRemovesOnlyUntouchedItems() {
        let id = UUID()
        let local = item("Milk", id: id)
        var ledger = SyncLedger(accountUserID: user, deviceID: device)
        ledger.baselines[id] = ItemBaseline(name: "Milk", category: "Dairy", expiry: "2027-01-31", added: created)
        var remote = record(local)
        remote.expiry = "2027-02-01"
        let applied = SyncMerger.merge(items: [local], ledger: ledger, remote: [remote], now: created.addingTimeInterval(5))
        XCTAssertEqual(applied.items.map(\.expiry), ["2027-02-01"])
        XCTAssertTrue(applied.ledger.queue.isEmpty)
        XCTAssertEqual(applied.ledger.baselines[id]?.expiry, "2027-02-01")

        let removed = SyncMerger.merge(items: applied.items, ledger: applied.ledger, remote: [], now: created.addingTimeInterval(6))
        XCTAssertTrue(removed.items.isEmpty)
        XCTAssertNil(removed.ledger.baselines[id])

        var edited = applied.ledger
        var changed = applied.items[0]
        changed.name = "Phone edit"
        edited.noteUpsert(previous: applied.items[0], item: changed, at: created.addingTimeInterval(8), sessionActive: true)
        let recreated = SyncMerger.merge(items: [changed], ledger: edited, remote: [], now: created.addingTimeInterval(9))
        XCTAssertEqual(recreated.items.map(\.name), ["Phone edit"])
        XCTAssertEqual(recreated.ledger.queue[id]?.action, .upsert)
    }

    func testDeleteQueueLosesToANewerRemoteWrite() {
        let id = UUID()
        let local = item("Milk", id: id)
        var ledger = SyncLedger(accountUserID: user, deviceID: device)
        ledger.baselines[id] = ItemBaseline(name: "Milk", category: "Dairy", expiry: "2027-01-31", added: created)
        ledger.noteDelete(id: id, at: created.addingTimeInterval(10))
        let older = SyncMerger.merge(items: [local], ledger: ledger, remote: [record(local, updated: created.addingTimeInterval(5))], now: created.addingTimeInterval(12))
        XCTAssertTrue(older.items.isEmpty)
        XCTAssertEqual(older.ledger.queue[id]?.action, .delete)

        let newer = SyncMerger.merge(items: [], ledger: older.ledger, remote: [record(item("Saved on web", id: id), updated: created.addingTimeInterval(20))], now: created.addingTimeInterval(21))
        XCTAssertEqual(newer.items.map(\.name), ["Saved on web"])
        XCTAssertNil(newer.ledger.queue[id])
    }

    func testPhotoUploadDownloadConflictAndRemoteRemoval() {
        let id = UUID()
        let local = item("Milk", id: id, photo: Data("local".utf8))
        var ledger = SyncLedger(accountUserID: user, deviceID: device)
        ledger.baselines[id] = ItemBaseline(name: local.name, category: local.category, expiry: local.expiry, added: created,
                                            photoDigest: PhotoDigest.fingerprint(Data("old".utf8)), photoSlot: .primary,
                                            photoRemoteUpdatedAt: created)
        ledger.noteUpsert(previous: item("Milk", id: id, photo: Data("old".utf8)), item: local, at: created.addingTimeInterval(10), sessionActive: true)
        let upload = SyncMerger.merge(items: [local], ledger: ledger, remote: [record(local)],
                                      photos: [id: RemotePhotoSet(primaryUpdatedAt: created.addingTimeInterval(4))], now: created.addingTimeInterval(12))
        XCTAssertEqual(upload.ledger.queue[id]?.photo, .upload)
        XCTAssertTrue(upload.downloads.isEmpty)

        let remoteNewer = SyncMerger.merge(items: [local], ledger: ledger, remote: [record(local)],
                                           photos: [id: RemotePhotoSet(primaryUpdatedAt: created.addingTimeInterval(30))], now: created.addingTimeInterval(31))
        XCTAssertEqual(remoteNewer.downloads, [PhotoDownload(id: id, slot: .primary, remoteUpdatedAt: created.addingTimeInterval(30))])
        XCTAssertNotEqual(remoteNewer.ledger.queue[id]?.photo, .upload)

        var synced = ledger
        synced.queue.removeAll()
        synced.baselines[id]?.photoDigest = PhotoDigest.fingerprint(Data("local".utf8))
        synced.baselines[id]?.photoRemoteUpdatedAt = created.addingTimeInterval(10)
        let cleared = SyncMerger.merge(items: [local], ledger: synced, remote: [record(local)], photos: [:], now: created.addingTimeInterval(40))
        XCTAssertNil(cleared.items[0].photo)
        XCTAssertNil(cleared.ledger.baselines[id]?.photoDigest)

        var bare = SyncLedger(accountUserID: user, deviceID: device)
        let remoteItem = item("Web", id: id)
        bare.baselines[id] = ItemBaseline(name: remoteItem.name, category: remoteItem.category, expiry: remoteItem.expiry, added: created)
        let fallback = SyncMerger.merge(items: [remoteItem], ledger: bare, remote: [record(remoteItem)],
                                        photos: [id: RemotePhotoSet(fullUpdatedAt: created.addingTimeInterval(3))], now: created.addingTimeInterval(4))
        XCTAssertEqual(fallback.downloads.first?.slot, .full)
    }

    func testInvalidRemoteRowIsWithheldInsteadOfDeletingLocalData() {
        let id = UUID()
        let local = item("Milk", id: id)
        var ledger = SyncLedger(accountUserID: user, deviceID: device)
        ledger.baselines[id] = ItemBaseline(name: "Milk", category: "Dairy", expiry: "2027-01-31", added: created)
        var remote = record(local)
        remote.expiry = "2027-02-31"
        let result = SyncMerger.merge(items: [local], ledger: ledger, remote: [remote], now: created)
        XCTAssertEqual(result.items, [local])
        XCTAssertEqual(result.withheld, [id])
        XCTAssertNotNil(result.ledger.baselines[id])
    }

    func testLedgerRoundTripAndAccountArchive() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        var ledger = SyncLedger(accountUserID: user, deviceID: device, lastSyncedAt: created, rejectedColumns: ["updated_at"])
        let id = UUID()
        ledger.baselines[id] = ItemBaseline(name: "Milk", category: "Dairy", expiry: "2027-01-31", added: created, quantity: 2, tracksQuantity: true)
        ledger.queue[id] = QueuedChange(action: .upsert, modifiedAt: created.addingTimeInterval(3), photo: .upload)
        ledger.localOnlyIDs = [UUID()]
        let store = SyncLedgerStore(directory: directory)
        try store.save(ledger)
        XCTAssertEqual(try SyncLedgerStore(directory: directory).load(), ledger)

        let snapshot = try LocalRepository(directory: directory).exportBackup(TrackerSnapshot(items: [item("Milk", id: id)]))
        try AccountArchive.save(root: directory, userID: user, itemsData: snapshot, ledger: ledger)
        let loaded = try XCTUnwrap(AccountArchive.load(root: directory, userID: user))
        XCTAssertEqual(loaded.ledger, ledger)
        XCTAssertEqual(try LocalRepository(directory: directory).importBackup(loaded.itemsData).items.map(\.name), ["Milk"])
        XCTAssertNil(try AccountArchive.load(root: directory, userID: UUID()))
    }

    func testClientBuildsAuthItemAndStorageRequestsAndRetriesUnknownColumns() async throws {
        let config = SupabaseConfig(baseURL: URL(string: "https://example.test")!, anonKey: "anon-key")
        let transport = ScriptedTransport()
        let client = SupabaseClient(config: config, transport: transport)
        let sessionJSON = """
        {"access_token":"access","refresh_token":"refresh","expires_in":3600,"user":{"id":"\(user.uuidString)","email":"a@b.co"}}
        """.data(using: .utf8)!
        transport.enqueue { request in
            XCTAssertEqual(request.method, "POST")
            XCTAssertEqual(request.url.path, "/auth/v1/token")
            XCTAssertEqual(request.url.query?.contains("grant_type=password"), true)
            XCTAssertEqual(request.headers["apikey"], "anon-key")
            XCTAssertNil(request.headers["Authorization"])
            let body = try! JSONSerialization.jsonObject(with: request.body!) as! [String: String]
            XCTAssertEqual(body["email"], "a@b.co")
            XCTAssertEqual(body["password"], "secret")
            return SyncHTTPResponse(status: 200, body: sessionJSON)
        }
        let session = try await client.signIn(email: "a@b.co", password: "secret", now: created)
        XCTAssertEqual(session.userID, user)
        XCTAssertEqual(session.email, "a@b.co")
        XCTAssertEqual(session.expiresAt, created.addingTimeInterval(3600))

        let milk = item("Milk")
        transport.enqueue { request in
            XCTAssertEqual(request.method, "POST")
            XCTAssertEqual(request.url.path, "/rest/v1/items")
            XCTAssertEqual(request.headers["Authorization"], "Bearer access")
            XCTAssertEqual(request.headers["Prefer"], "return=representation")
            let rows = try! JSONSerialization.jsonObject(with: request.body!) as! [[String: Any]]
            XCTAssertEqual(rows[0]["icon"] as? String, "Dairy")
            XCTAssertNotNil(rows[0]["quantity"])
            return SyncHTTPResponse(status: 400, body: Data("{\"code\":\"PGRST204\",\"message\":\"Could not find the 'quantity' column of 'items' in the schema cache\"}".utf8))
        }
        transport.enqueue { request in
            let rows = try! JSONSerialization.jsonObject(with: request.body!) as! [[String: Any]]
            XCTAssertNil(rows[0]["quantity"])
            XCTAssertNotNil(rows[0]["notes"])
            return SyncHTTPResponse(status: 400, body: Data("{\"message\":\"Could not find the 'notes' column of 'items' in the schema cache\"}".utf8))
        }
        transport.enqueue { request in
            let rows = try! JSONSerialization.jsonObject(with: request.body!) as! [[String: Any]]
            XCTAssertNil(rows[0]["notes"])
            XCTAssertNotNil(rows[0]["barcode"])
            return SyncHTTPResponse(status: 400, body: Data("{\"message\":\"Could not find the 'barcode' column of 'items' in the schema cache\"}".utf8))
        }
        transport.enqueue { request in
            let rows = try! JSONSerialization.jsonObject(with: request.body!) as! [[String: Any]]
            XCTAssertNil(rows[0]["barcode"])
            XCTAssertNotNil(rows[0]["updated_at"])
            return SyncHTTPResponse(status: 400, body: Data("{\"message\":\"Could not find the 'updated_at' column of 'items' in the schema cache\"}".utf8))
        }
        transport.enqueue { request in
            let rows = try! JSONSerialization.jsonObject(with: request.body!) as! [[String: Any]]
            XCTAssertEqual(Set(rows[0].keys), ["added", "device_id", "expiry", "icon", "id", "name", "user_id"])
            let saved = rows[0]
            return SyncHTTPResponse(status: 201, body: try! JSONSerialization.data(withJSONObject: [saved]))
        }
        let written = try await client.upsert(item: milk, userID: user, deviceID: device, modifiedAt: created.addingTimeInterval(2),
                                              exists: false, rejected: [], session: session)
        XCTAssertEqual(written.rejectedColumns, ["quantity", "notes", "barcode", "updated_at"])
        XCTAssertEqual(written.record.name, "Milk")

        transport.enqueue { request in
            XCTAssertEqual(request.method, "POST")
            XCTAssertTrue(request.url.path.contains("/storage/v1/object/item-images/"))
            XCTAssertTrue(request.url.path.hasSuffix(CloudPaths.imagePath(userID: self.user, itemID: milk.id, full: false)))
            XCTAssertEqual(request.headers["x-upsert"], "true")
            XCTAssertEqual(request.headers["Content-Type"], "image/jpeg")
            XCTAssertEqual(request.body, Data([1, 2, 3]))
            return SyncHTTPResponse(status: 200, body: Data("{}".utf8))
        }
        try await client.uploadPhoto(userID: user, itemID: milk.id, data: Data([1, 2, 3]), session: session)

        transport.enqueue { request in
            XCTAssertEqual(request.method, "DELETE")
            let body = try! JSONSerialization.jsonObject(with: request.body!) as! [String: [String]]
            XCTAssertEqual(body["prefixes"], [
                CloudPaths.imagePath(userID: self.user, itemID: milk.id, full: false),
                CloudPaths.imagePath(userID: self.user, itemID: milk.id, full: true)
            ])
            return SyncHTTPResponse(status: 200, body: Data("[]".utf8))
        }
        try await client.deletePhotos(userID: user, itemID: milk.id, session: session)

        let listed = """
        [{"name":"\(milk.id.uuidString.lowercased()).jpg","updated_at":"2023-11-14T22:13:20.000Z"},{"name":"\(milk.id.uuidString.lowercased())_full.jpg","updated_at":"2023-11-14T22:13:21.000Z"}]
        """.data(using: .utf8)!
        XCTAssertEqual(try CloudCodec.decodePhotoList(listed, userID: user)[milk.id],
                       RemotePhotoSet(primaryUpdatedAt: created, fullUpdatedAt: created.addingTimeInterval(1)))

        transport.enqueue { _ in
            SyncHTTPResponse(status: 400, body: Data("{\"error\":\"invalid_grant\",\"error_description\":\"Invalid login credentials\"}".utf8))
        }
        do {
            _ = try await client.signIn(email: "a@b.co", password: "nope")
            XCTFail("Expected invalid credentials")
        } catch let error as CloudError {
            XCTAssertEqual(CloudMessage.signIn(error), "Email or password is incorrect.")
        }
        XCTAssertEqual(CloudMessage.sync(.network), "Changes are saved on this iPhone. They'll sync when you're back online.")
        XCTAssertEqual(CloudMessage.sync(.unauthorized), "Your session expired. Sign in again.")
        XCTAssertEqual(CloudCodec.missingColumn(in: Data("{\"message\":\"Could not find the 'quantity' column of 'items' in the schema cache\"}".utf8)), "quantity")
    }

    func testEmptyIconBecomesOtherWithoutDroppingTheItem() {
        let id = UUID()
        var remote = record(item("Milk", id: id))
        remote.category = "  "
        let result = SyncMerger.merge(items: [], ledger: SyncLedger(accountUserID: user, deviceID: device), remote: [remote], now: created)
        XCTAssertEqual(result.items.map(\.category), ["Other"])
        XCTAssertTrue(result.withheld.isEmpty)
    }
}

private final class ScriptedTransport: SyncTransport {
    private var handlers: [(SyncHTTPRequest) -> SyncHTTPResponse] = []

    func enqueue(_ handler: @escaping (SyncHTTPRequest) -> SyncHTTPResponse) {
        handlers.append(handler)
    }

    func send(_ request: SyncHTTPRequest) async throws -> SyncHTTPResponse {
        guard !handlers.isEmpty else { throw CloudError.network }
        return handlers.removeFirst()(request)
    }
}
