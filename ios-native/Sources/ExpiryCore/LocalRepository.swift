import Foundation

public struct TrackerSnapshot: Codable, Sendable {
    public var version: Int
    public var items: [ExpiryItem]
    public var settings: TrackerSettings

    public init(version: Int = 1, items: [ExpiryItem] = [], settings: TrackerSettings = TrackerSettings()) {
        self.version = version
        self.items = items
        self.settings = settings
    }
}

public enum LocalRepositoryError: Error, Equatable, Sendable {
    case invalidItem(UUID, field: String)
    case unsupportedVersion(Int)
    case duplicateID(UUID)
    case invalidSettings
    case backupTooLarge
}

/// Synchronous local storage. Callers must serialize access (normally on MainActor).
public final class LocalRepository {
    public static let maximumBackupBytes = 20 * 1024 * 1024
    public static let maximumPhotoBytes = 5 * 1024 * 1024

    private let directory: URL
    private var file: URL { directory.appendingPathComponent("tracker.json") }

    public init(directory: URL) throws {
        self.directory = directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        #if os(iOS)
        // Excluding the containing directory excludes the complete local store tree.
        // Apply metadata before any commit so metadata failures cannot replace old data.
        var protectedDirectory = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try protectedDirectory.setResourceValues(values)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                                              ofItemAtPath: directory.path)
        #endif
    }

    public func load() throws -> TrackerSnapshot {
        guard FileManager.default.fileExists(atPath: file.path) else { return TrackerSnapshot() }
        let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
        if let bytes = attributes[.size] as? NSNumber, bytes.int64Value > Int64(Self.maximumBackupBytes) {
            throw LocalRepositoryError.backupTooLarge
        }
        return try importBackup(Data(contentsOf: file))
    }

    public func save(_ snapshot: TrackerSnapshot) throws {
        // A valid new value must not silently erase a corrupt existing store.
        _ = try load()
        let data = try exportBackup(snapshot)
        #if os(iOS)
        try data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: file, options: .atomic)
        #endif
    }

    public func exportBackup(_ snapshot: TrackerSnapshot) throws -> Data {
        try validate(snapshot)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .deferredToDate
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(snapshot)
        guard data.count <= Self.maximumBackupBytes else { throw LocalRepositoryError.backupTooLarge }
        return data
    }

    /// Decode and validate without changing storage; call save explicitly to commit.
    public func importBackup(_ data: Data) throws -> TrackerSnapshot {
        guard data.count <= Self.maximumBackupBytes else { throw LocalRepositoryError.backupTooLarge }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        let snapshot = try decoder.decode(TrackerSnapshot.self, from: data)
        _ = try exportBackup(snapshot)
        return snapshot
    }

    private func validate(_ snapshot: TrackerSnapshot) throws {
        guard snapshot.version == 1 else { throw LocalRepositoryError.unsupportedVersion(snapshot.version) }
        guard snapshot.settings.criticalDays >= 0,
              snapshot.settings.criticalDays <= snapshot.settings.soonDays,
              snapshot.settings.soonDays <= 3650 else { throw LocalRepositoryError.invalidSettings }
        var ids = Set<UUID>()
        let calendar = Calendar(identifier: .gregorian)
        for item in snapshot.items {
            guard ids.insert(item.id).inserted else { throw LocalRepositoryError.duplicateID(item.id) }
            guard !item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  item.name.count <= 200 else { throw LocalRepositoryError.invalidItem(item.id, field: "name") }
            guard !item.category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  item.category.count <= 100 else { throw LocalRepositoryError.invalidItem(item.id, field: "category") }
            guard (1...999_999).contains(item.quantity) else { throw LocalRepositoryError.invalidItem(item.id, field: "quantity") }
            guard (item.photo?.count ?? 0) <= Self.maximumPhotoBytes else {
                throw LocalRepositoryError.invalidItem(item.id, field: "photo")
            }
            #if canImport(ImageIO)
            if let photo = item.photo, PhotoPolicy.validatedSource(photo) == nil {
                throw LocalRepositoryError.invalidItem(item.id, field: "photo")
            }
            #endif
            guard ExpiryItem.expiryDate(item.expiry, calendar: calendar) != nil else {
                throw LocalRepositoryError.invalidItem(item.id, field: "expiry")
            }
        }
    }
}
