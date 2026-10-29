#if canImport(SwiftUI)
import SwiftUI
import ExpiryCore

@MainActor
final class TrackerModel: ObservableObject {
    @Published private(set) var snapshot = TrackerSnapshot()
    @Published var errorMessage: String?
    @Published private(set) var ready = false
    private var repository: LocalRepository?

    init() { load() }
    func load() {
        do {
            let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let repository = try LocalRepository(directory: base.appendingPathComponent("NativeExpiryTracker", isDirectory: true))
            let loaded = try repository.load()
            self.repository = repository
            snapshot = loaded
            ready = true
        } catch {
            ready = false
            errorMessage = "Your local data could not be opened. Nothing was overwritten. \(ErrorExplanation.message(error))"
        }
    }
    @discardableResult
    func replace(_ proposed: TrackerSnapshot) -> Bool {
        guard let repository, ready else {
            errorMessage = "Local storage is unavailable. Retry opening your data before making changes."
            return false
        }
        do {
            try repository.save(proposed)
            snapshot = proposed
            return true
        } catch {
            errorMessage = "The change was not saved. Your previous data is unchanged. \(ErrorExplanation.message(error))"
            return false
        }
    }
    func upsert(_ item: ExpiryItem) -> Bool {
        var next = snapshot
        if let index = next.items.firstIndex(where: { $0.id == item.id }) { next.items[index] = item }
        else { next.items.append(item) }
        return replace(next)
    }
    func delete(_ item: ExpiryItem) -> Bool {
        var next = snapshot
        next.items.removeAll { $0.id == item.id }
        return replace(next)
    }
    func settings(_ settings: TrackerSettings) -> Bool {
        var next = snapshot
        next.settings = settings
        return replace(next)
    }
    func validatedBackup(_ url: URL) throws -> TrackerSnapshot {
        guard let repository, ready else { throw CocoaError(.fileReadNoPermission) }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= LocalRepository.maximumBackupBytes else { throw LocalRepositoryError.backupTooLarge }
        return try repository.importBackup(Data(contentsOf: url, options: .mappedIfSafe))
    }
    func export(csv: Bool) throws -> URL {
        guard let repository, ready else { throw CocoaError(.fileReadNoPermission) }
        let data: Data
        if csv {
            let header = ["id", "name", "category", "quantity", "expiry", "notes", "barcode", "createdAt"]
            let rows = snapshot.items.map { item in
                [item.id.uuidString, item.name, item.category, String(item.quantity), item.expiry, item.notes, item.barcode ?? "", ISO8601DateFormatter().string(from: item.createdAt)]
            }
            data = CSVExport.encode(rows: [header] + rows)
        } else { data = try repository.exportBackup(snapshot) }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Exports", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(csv ? "ExpiryTracker.csv" : "ExpiryTracker-backup.json")
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }
}

@main
struct ExpiryTrackerApp: App {
    @StateObject private var model = TrackerModel()
    var body: some Scene {
        WindowGroup {
            TrackerHome().environmentObject(model).tint(.trackerAccent)
                .alert("Unable to complete action", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
                    Button("OK") { model.errorMessage = nil }
                } message: { Text(model.errorMessage ?? "") }
        }
    }
}
#endif
