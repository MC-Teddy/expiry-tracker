import Foundation

public struct ItemBaseline: Codable, Equatable, Sendable {
    public var name: String
    public var category: String
    public var expiry: String
    public var added: Date
    public var quantity: Int?
    public var notes: String?
    public var barcode: String?
    public var tracksQuantity: Bool
    public var tracksNotes: Bool
    public var tracksBarcode: Bool
    public var remoteUpdatedAt: Date?
    public var photoDigest: String?
    public var photoSlot: PhotoSlot?
    public var photoRemoteUpdatedAt: Date?
    public var ignoredPhotoUpdatedAt: Date?

    public init(name: String, category: String, expiry: String, added: Date,
                quantity: Int? = nil, notes: String? = nil, barcode: String? = nil,
                tracksQuantity: Bool = false, tracksNotes: Bool = false, tracksBarcode: Bool = false,
                remoteUpdatedAt: Date? = nil, photoDigest: String? = nil, photoSlot: PhotoSlot? = nil,
                photoRemoteUpdatedAt: Date? = nil, ignoredPhotoUpdatedAt: Date? = nil) {
        self.name = name
        self.category = category
        self.expiry = expiry
        self.added = added
        self.quantity = quantity
        self.notes = notes
        self.barcode = barcode
        self.tracksQuantity = tracksQuantity
        self.tracksNotes = tracksNotes
        self.tracksBarcode = tracksBarcode
        self.remoteUpdatedAt = remoteUpdatedAt
        self.photoDigest = photoDigest
        self.photoSlot = photoSlot
        self.photoRemoteUpdatedAt = photoRemoteUpdatedAt
        self.ignoredPhotoUpdatedAt = ignoredPhotoUpdatedAt
    }
}

public struct QueuedChange: Codable, Equatable, Sendable {
    public enum Action: String, Codable, Sendable {
        case upsert
        case photo
        case delete
    }

    public enum Photo: String, Codable, Sendable {
        case unchanged
        case upload
        case delete
    }

    public var action: Action
    public var modifiedAt: Date
    public var photo: Photo

    public init(action: Action, modifiedAt: Date, photo: Photo) {
        self.action = action
        self.modifiedAt = modifiedAt
        self.photo = photo
    }
}

public struct SyncLedger: Equatable, Sendable {
    public var accountUserID: UUID?
    public var deviceID: UUID
    public var lastSyncedAt: Date?
    public var baselines: [UUID: ItemBaseline]
    public var queue: [UUID: QueuedChange]
    public var localOnlyIDs: Set<UUID>
    public var rejectedColumns: Set<String>

    public init(accountUserID: UUID? = nil, deviceID: UUID = UUID(), lastSyncedAt: Date? = nil,
                baselines: [UUID: ItemBaseline] = [:], queue: [UUID: QueuedChange] = [:],
                localOnlyIDs: Set<UUID> = [], rejectedColumns: Set<String> = []) {
        self.accountUserID = accountUserID
        self.deviceID = deviceID
        self.lastSyncedAt = lastSyncedAt
        self.baselines = baselines
        self.queue = queue
        self.localOnlyIDs = localOnlyIDs
        self.rejectedColumns = rejectedColumns
    }

    public var pendingCount: Int { queue.count }

    public mutating func noteUpsert(previous: ExpiryItem?, item: ExpiryItem, at: Date, sessionActive: Bool) {
        let knownAccountItem = baselines[item.id] != nil || queue[item.id] != nil
        if accountUserID == nil || localOnlyIDs.contains(item.id) || (!sessionActive && !knownAccountItem) {
            localOnlyIDs.insert(item.id)
            queue.removeValue(forKey: item.id)
            return
        }
        var change = queue[item.id] ?? QueuedChange(action: .upsert, modifiedAt: at, photo: .unchanged)
        let photoChanged = previous?.photo != item.photo
        if change.action == .delete {
            change = QueuedChange(action: .upsert, modifiedAt: at, photo: item.photo == nil ? .delete : .upload)
        } else {
            change.action = .upsert
            change.modifiedAt = at
            if photoChanged {
                change.photo = item.photo == nil ? .delete : .upload
            }
        }
        queue[item.id] = change
    }

    public mutating func noteDelete(id: UUID, at: Date) {
        // No baseline means the server never received this item, so there is nothing to delete remotely.
        if accountUserID == nil || localOnlyIDs.contains(id) || baselines[id] == nil {
            localOnlyIDs.remove(id)
            queue.removeValue(forKey: id)
            return
        }
        queue[id] = QueuedChange(action: .delete, modifiedAt: at, photo: .delete)
    }

    public mutating func acknowledgeItemPush(id: UUID, item: ExpiryItem, server: CloudItemRecord) {
        var base = baselines[id] ?? ItemBaseline(name: item.name, category: item.category, expiry: item.expiry, added: server.added)
        base.name = item.name
        base.category = item.category
        base.expiry = item.expiry
        base.added = server.added
        base.remoteUpdatedAt = server.updatedAt ?? server.added
        if case .absent = server.quantity {
            base.tracksQuantity = false
        } else {
            base.tracksQuantity = true
            base.quantity = item.quantity
        }
        if case .absent = server.notes {
            base.tracksNotes = false
        } else {
            base.tracksNotes = true
            base.notes = item.notes
        }
        if case .absent = server.barcode {
            base.tracksBarcode = false
        } else {
            base.tracksBarcode = true
            base.barcode = item.barcode
        }
        baselines[id] = base
        guard var change = queue[id] else { return }
        if change.photo == .unchanged {
            queue.removeValue(forKey: id)
        } else {
            change.action = .photo
            queue[id] = change
        }
    }

    public mutating func acknowledgeDelete(id: UUID) {
        baselines.removeValue(forKey: id)
        queue.removeValue(forKey: id)
        localOnlyIDs.remove(id)
    }

    public mutating func acknowledgePhotoUpload(id: UUID, digest: String, remoteUpdatedAt: Date) {
        guard var base = baselines[id] else { return }
        base.photoDigest = digest
        base.photoSlot = .primary
        base.photoRemoteUpdatedAt = remoteUpdatedAt
        base.ignoredPhotoUpdatedAt = nil
        baselines[id] = base
        finishPhoto(id)
    }

    public mutating func acknowledgePhotoDelete(id: UUID) {
        guard var base = baselines[id] else {
            finishPhoto(id)
            return
        }
        base.photoDigest = nil
        base.photoSlot = nil
        base.photoRemoteUpdatedAt = nil
        base.ignoredPhotoUpdatedAt = nil
        baselines[id] = base
        finishPhoto(id)
    }

    public mutating func acknowledgePhotoDownload(id: UUID, digest: String, slot: PhotoSlot, remoteUpdatedAt: Date) {
        guard var base = baselines[id] else { return }
        base.photoDigest = digest
        base.photoSlot = slot
        base.photoRemoteUpdatedAt = remoteUpdatedAt
        base.ignoredPhotoUpdatedAt = nil
        baselines[id] = base
        if queue[id]?.action == .photo {
            queue.removeValue(forKey: id)
        } else if var change = queue[id], change.photo != .delete {
            change.photo = .unchanged
            queue[id] = change
        }
    }

    public mutating func ignorePhoto(id: UUID, remoteUpdatedAt: Date) {
        guard var base = baselines[id] else { return }
        base.ignoredPhotoUpdatedAt = remoteUpdatedAt
        baselines[id] = base
    }

    private mutating func finishPhoto(_ id: UUID) {
        guard var change = queue[id] else { return }
        change.photo = .unchanged
        if change.action == .photo {
            queue.removeValue(forKey: id)
        } else {
            queue[id] = change
        }
    }
}

extension SyncLedger: Codable {
    private enum CodingKeys: String, CodingKey {
        case accountUserID, deviceID, lastSyncedAt, baselines, queue, localOnlyIDs, rejectedColumns
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(accountUserID, forKey: .accountUserID)
        try container.encode(deviceID, forKey: .deviceID)
        try container.encodeIfPresent(lastSyncedAt, forKey: .lastSyncedAt)
        try container.encode(Self.stringKeyed(baselines), forKey: .baselines)
        try container.encode(Self.stringKeyed(queue), forKey: .queue)
        try container.encode(localOnlyIDs, forKey: .localOnlyIDs)
        try container.encode(rejectedColumns, forKey: .rejectedColumns)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accountUserID = try container.decodeIfPresent(UUID.self, forKey: .accountUserID)
        deviceID = try container.decode(UUID.self, forKey: .deviceID)
        lastSyncedAt = try container.decodeIfPresent(Date.self, forKey: .lastSyncedAt)
        baselines = try Self.uuidKeyed(container.decode([String: ItemBaseline].self, forKey: .baselines))
        queue = try Self.uuidKeyed(container.decode([String: QueuedChange].self, forKey: .queue))
        localOnlyIDs = try container.decode(Set<UUID>.self, forKey: .localOnlyIDs)
        rejectedColumns = try container.decode(Set<String>.self, forKey: .rejectedColumns)
    }

    private static func stringKeyed<Value>(_ values: [UUID: Value]) -> [String: Value] {
        Dictionary(uniqueKeysWithValues: values.map { ($0.key.uuidString.lowercased(), $0.value) })
    }

    private static func uuidKeyed<Value>(_ values: [String: Value]) throws -> [UUID: Value] {
        var decoded: [UUID: Value] = [:]
        for (key, value) in values {
            guard let id = UUID(uuidString: key) else {
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid item id \(key)"))
            }
            decoded[id] = value
        }
        return decoded
    }
}

public struct SignInHandoff: Equatable, Sendable {
    public var items: [ExpiryItem]
    public var ledger: SyncLedger
    public var parkUserID: UUID?
    public var parkItems: [ExpiryItem]
    public var parkLedger: SyncLedger?

    public static func signIn(userID: UUID, items: [ExpiryItem], ledger: SyncLedger,
                              restoredItems: [ExpiryItem] = [], restoredLedger: SyncLedger? = nil,
                              at: Date) -> SignInHandoff {
        if ledger.accountUserID == nil || ledger.accountUserID == userID {
            var next = ledger
            next.accountUserID = userID
            for item in items {
                let wasLocal = next.localOnlyIDs.contains(item.id) || next.baselines[item.id] == nil
                next.localOnlyIDs.remove(item.id)
                if next.queue[item.id]?.action == .delete { continue }
                guard wasLocal else { continue }
                if next.queue[item.id] == nil {
                    let photo: QueuedChange.Photo = item.photo == nil ? .unchanged : .upload
                    next.queue[item.id] = QueuedChange(action: .upsert, modifiedAt: item.createdAt, photo: photo)
                } else if item.photo != nil, next.queue[item.id]?.photo == .unchanged {
                    next.queue[item.id]?.photo = .upload
                }
            }
            return SignInHandoff(items: items, ledger: next, parkUserID: nil, parkItems: [], parkLedger: nil)
        }

        let carry = items.filter { ledger.localOnlyIDs.contains($0.id) }
        let stay = items.filter { !ledger.localOnlyIDs.contains($0.id) }
        var parked = ledger
        parked.localOnlyIDs = []
        for item in carry { parked.queue.removeValue(forKey: item.id) }

        var next = restoredLedger ?? SyncLedger(deviceID: ledger.deviceID)
        next.accountUserID = userID
        next.deviceID = ledger.deviceID
        next.rejectedColumns = next.rejectedColumns.union(ledger.rejectedColumns)
        var nextItems = restoredItems
        for item in carry where !nextItems.contains(where: { $0.id == item.id }) {
            nextItems.append(item)
        }
        for item in carry {
            next.localOnlyIDs.remove(item.id)
            next.baselines.removeValue(forKey: item.id)
            next.queue[item.id] = QueuedChange(action: .upsert, modifiedAt: at, photo: item.photo == nil ? .unchanged : .upload)
        }
        return SignInHandoff(items: nextItems, ledger: next, parkUserID: ledger.accountUserID, parkItems: stay, parkLedger: parked)
    }
}

enum LocalFileProtection {
    static func apply(_ url: URL) {
        #if os(iOS)
        var copy = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? copy.setResourceValues(values)
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
        #endif
    }
}

public struct SyncLedgerStore {
    public let file: URL

    public init(directory: URL) {
        file = directory.appendingPathComponent("sync-ledger.json")
    }

    public func load() throws -> SyncLedger {
        guard FileManager.default.fileExists(atPath: file.path) else { return SyncLedger() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return try decoder.decode(SyncLedger.self, from: Data(contentsOf: file))
    }

    public func save(_ ledger: SyncLedger) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(ledger)
        try data.write(to: file, options: .atomic)
        LocalFileProtection.apply(file)
    }
}

public enum AccountArchive {
    public static func save(root: URL, userID: UUID, itemsData: Data, ledger: SyncLedger) throws {
        let folder = directory(root: root, userID: userID)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        LocalFileProtection.apply(folder)
        let snapshot = folder.appendingPathComponent("snapshot.json")
        try itemsData.write(to: snapshot, options: .atomic)
        LocalFileProtection.apply(snapshot)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        let ledgerURL = folder.appendingPathComponent("ledger.json")
        try encoder.encode(ledger).write(to: ledgerURL, options: .atomic)
        LocalFileProtection.apply(ledgerURL)
    }

    public static func load(root: URL, userID: UUID) throws -> (itemsData: Data, ledger: SyncLedger)? {
        let folder = directory(root: root, userID: userID)
        let snapshot = folder.appendingPathComponent("snapshot.json")
        let ledgerURL = folder.appendingPathComponent("ledger.json")
        guard FileManager.default.fileExists(atPath: snapshot.path),
              FileManager.default.fileExists(atPath: ledgerURL.path) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let ledger = try decoder.decode(SyncLedger.self, from: Data(contentsOf: ledgerURL))
        return (try Data(contentsOf: snapshot), ledger)
    }

    public static func directory(root: URL, userID: UUID) -> URL {
        root.appendingPathComponent("accounts", isDirectory: true)
            .appendingPathComponent(userID.uuidString.lowercased(), isDirectory: true)
    }
}
