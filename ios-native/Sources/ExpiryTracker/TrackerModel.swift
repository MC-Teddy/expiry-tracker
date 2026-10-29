#if canImport(SwiftUI)
import SwiftUI
import ExpiryCore

@MainActor
final class TrackerModel: ObservableObject {
    @Published private(set) var snapshot = TrackerSnapshot()
    @Published var errorMessage: String?
    @Published private(set) var ready = false
    @Published private(set) var accountEmail: String?
    @Published private(set) var lastSyncedAt: Date?
    @Published private(set) var pendingChanges = 0
    @Published private(set) var syncing = false
    @Published var syncMessage: String?

    private var repository: LocalRepository?
    private var directory: URL?
    private var ledger = SyncLedger()
    private var ledgerStore: SyncLedgerStore?
    private var session: AuthSession?
    private var generation = 0
    private var syncChain: Task<Void, Never>?
    #if os(iOS)
    private let client = SupabaseClient.live()
    private let sessionStore = KeychainSessionStore()
    private let reachability = ReachabilityMonitor()
    #endif

    var isSignedIn: Bool { session != nil }

    init() { load() }

    func load() {
        do {
            let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let directory = base.appendingPathComponent("NativeExpiryTracker", isDirectory: true)
            let repository = try LocalRepository(directory: directory)
            let loaded = try repository.load()
            self.directory = directory
            self.repository = repository
            let store = SyncLedgerStore(directory: directory)
            if FileManager.default.fileExists(atPath: store.file.path) {
                do {
                    ledger = try store.load()
                    ledgerStore = store
                } catch {
                    ledgerStore = nil
                    syncMessage = "Sync status on this iPhone couldn't be read. Your items are unchanged, and sync is paused until that file can be read."
                }
            } else {
                ledger = SyncLedger()
                try store.save(ledger)
                ledgerStore = store
            }
            snapshot = loaded
            ready = true
            publishSyncStatus()
            #if os(iOS)
            session = sessionStore.load()
            accountEmail = session?.email
            reachability.start { [weak self] in
                Task { @MainActor in self?.scheduleSync() }
            }
            if session != nil { scheduleSync() }
            #endif
        } catch {
            ready = false
            errorMessage = "Your local data could not be opened. Nothing was overwritten. \(ErrorExplanation.message(error))"
        }
    }

    @discardableResult
    func replace(_ proposed: TrackerSnapshot) -> Bool {
        let previous = snapshot.items
        guard commit(proposed) else { return false }
        let now = Date()
        for item in previous where !proposed.items.contains(where: { $0.id == item.id }) {
            ledger.noteDelete(id: item.id, at: now)
        }
        for item in proposed.items {
            let prior = previous.first { $0.id == item.id }
            if prior != item {
                ledger.noteUpsert(previous: prior, item: item, at: now, sessionActive: isSignedIn)
            }
        }
        generation += 1
        persistLedger()
        scheduleSync()
        return true
    }

    func upsert(_ item: ExpiryItem) -> Bool {
        let previous = snapshot.items.first { $0.id == item.id }
        var next = snapshot
        if let index = next.items.firstIndex(where: { $0.id == item.id }) { next.items[index] = item }
        else { next.items.append(item) }
        guard commit(next) else { return false }
        ledger.noteUpsert(previous: previous, item: item, at: Date(), sessionActive: isSignedIn)
        generation += 1
        persistLedger()
        scheduleSync()
        return true
    }

    func delete(_ item: ExpiryItem) -> Bool {
        var next = snapshot
        next.items.removeAll { $0.id == item.id }
        guard commit(next) else { return false }
        ledger.noteDelete(id: item.id, at: Date())
        generation += 1
        persistLedger()
        scheduleSync()
        return true
    }

    func settings(_ settings: TrackerSettings) -> Bool {
        var next = snapshot
        next.settings = settings
        return commit(next)
    }

    func signIn(email: String, password: String) async -> String? {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty, !password.isEmpty else { return CloudMessage.missingCredentials }
        #if os(iOS)
        guard let repository, let directory, ledgerStore != nil else {
            return "Local storage is unavailable. Retry opening your data before signing in."
        }
        do {
            let authenticated = try await client.signIn(email: email, password: password)
            var restoredItems: [ExpiryItem] = []
            var restoredLedger: SyncLedger?
            if let current = ledger.accountUserID, current != authenticated.userID,
               let archived = try AccountArchive.load(root: directory, userID: authenticated.userID) {
                restoredItems = try repository.importBackup(archived.itemsData).items
                restoredLedger = archived.ledger
            }
            let handoff = SignInHandoff.signIn(
                userID: authenticated.userID, items: snapshot.items, ledger: ledger,
                restoredItems: restoredItems, restoredLedger: restoredLedger, at: Date()
            )
            if let parkUser = handoff.parkUserID, let parkLedger = handoff.parkLedger {
                let parked = TrackerSnapshot(version: snapshot.version, items: handoff.parkItems, settings: snapshot.settings)
                try AccountArchive.save(root: directory, userID: parkUser, itemsData: try repository.exportBackup(parked), ledger: parkLedger)
            }
            var next = snapshot
            next.items = handoff.items
            try repository.save(next)
            try SyncLedgerStore(directory: directory).save(handoff.ledger)
            snapshot = next
            ledger = handoff.ledger
            ledgerStore = SyncLedgerStore(directory: directory)
            session = authenticated
            try sessionStore.save(authenticated)
            accountEmail = authenticated.email
            syncMessage = nil
            generation += 1
            publishSyncStatus()
            await syncNow()
            return nil
        } catch let error as CloudError {
            return CloudMessage.signIn(error)
        } catch {
            return "Sign-in failed. Your items on this iPhone were not changed. \(error.localizedDescription)"
        }
        #else
        return "Sign-in is available on iPhone."
        #endif
    }

    func signOut() {
        generation += 1
        #if os(iOS)
        let ending = session
        session = nil
        accountEmail = nil
        syncing = false
        sessionStore.clear()
        if let ending {
            Task { try? await self.client.signOut(ending) }
        }
        #else
        session = nil
        accountEmail = nil
        syncing = false
        #endif
        publishSyncStatus()
    }

    func scheduleSync() {
        #if os(iOS)
        guard session != nil, ledgerStore != nil, ready else { return }
        let previous = syncChain
        let task = Task { @MainActor in
            await previous?.value
            guard !Task.isCancelled else { return }
            await self.runSync(allowRefresh: true)
        }
        syncChain = task
        #endif
    }

    func syncNow() async {
        scheduleSync()
        await syncChain?.value
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

    #if os(iOS)
    private func runSync(allowRefresh: Bool) async {
        guard var session, ledgerStore != nil, let repository else { return }
        let token = generation
        syncing = true
        defer { if generation == token { syncing = false } }
        do {
            if session.needsRefresh {
                session = try await client.refresh(session)
                try sessionStore.save(session)
                guard generation == token else { return }
                self.session = session
                accountEmail = session.email
            }
            guard generation == token, !Task.isCancelled else { return }
            let remote = try await client.fetchItems(userID: session.userID, session: session)
            let photos = try await client.fetchPhotos(userID: session.userID, session: session)
            guard generation == token, !Task.isCancelled else { return }
            let plan = SyncMerger.merge(items: snapshot.items, ledger: ledger, remote: remote, photos: photos, now: Date())
            guard generation == token else { return }
            var next = snapshot
            next.items = plan.items
            try repository.save(next)
            try ledgerStore?.save(plan.ledger)
            guard generation == token else { return }
            snapshot = next
            ledger = plan.ledger
            publishSyncStatus()
            var warning = try await push(session: &session, token: token)
            if warning == nil, !plan.withheld.isEmpty {
                warning = "Some items from your account couldn't be stored on this iPhone. They were left unchanged in your account."
            }
            guard generation == token else { return }
            if let downloadWarning = try await download(plan.downloads, session: session, userID: session.userID, token: token) {
                warning = downloadWarning
            }
            guard generation == token else { return }
            ledger.lastSyncedAt = Date()
            try ledgerStore?.save(ledger)
            lastSyncedAt = ledger.lastSyncedAt
            syncMessage = warning
            publishSyncStatus()
        } catch let error as CloudError where allowRefresh && (error == .unauthorized || error == .invalidCredentials) {
            do {
                let refreshed = try await client.refresh(session)
                try sessionStore.save(refreshed)
                guard generation == token else { return }
                self.session = refreshed
                accountEmail = refreshed.email
                syncing = false
                await runSync(allowRefresh: false)
            } catch {
                endSession(token: token)
            }
        } catch let error as CloudError {
            guard generation == token else { return }
            if error == .unauthorized || error == .invalidCredentials {
                endSession(token: token)
            } else {
                syncMessage = CloudMessage.sync(error)
            }
        } catch let error as LocalRepositoryError {
            guard generation == token else { return }
            syncMessage = "Your account could not be saved on this iPhone. \(ErrorExplanation.message(error))"
        } catch {
            guard generation == token else { return }
            syncMessage = "Sync didn't finish. Your changes are saved on this iPhone."
        }
    }

    private func endSession(token: Int) {
        guard generation == token else { return }
        session = nil
        accountEmail = nil
        sessionStore.clear()
        syncMessage = CloudMessage.sync(.unauthorized)
        publishSyncStatus()
    }

    private func push(session: inout AuthSession, token: Int) async throws -> String? {
        guard let repository else { return nil }
        let userID = session.userID
        let deviceID = ledger.deviceID
        var failure: CloudError?
        for id in ledger.queue.keys.sorted(by: { $0.uuidString < $1.uuidString }) {
            guard generation == token, !Task.isCancelled else { return failure.map(CloudMessage.sync) }
            guard let change = ledger.queue[id] else { continue }
            do {
                if change.action == .delete {
                    try await client.deletePhotos(userID: userID, itemID: id, session: session)
                    try await client.deleteItem(id: id, userID: userID, session: session)
                    guard generation == token else { return nil }
                    ledger.acknowledgeDelete(id: id)
                    try ledgerStore?.save(ledger)
                    continue
                }
                if change.action == .upsert, let item = snapshot.items.first(where: { $0.id == id }) {
                    let written = try await client.upsert(
                        item: item, userID: userID, deviceID: deviceID, modifiedAt: change.modifiedAt,
                        exists: ledger.baselines[id] != nil, rejected: ledger.rejectedColumns, session: session
                    )
                    guard generation == token else { return nil }
                    ledger.rejectedColumns = written.rejectedColumns
                    if let index = snapshot.items.firstIndex(where: { $0.id == id }) {
                        snapshot.items[index].createdAt = written.record.added
                        try repository.save(snapshot)
                    }
                    let current = snapshot.items.first { $0.id == id } ?? item
                    ledger.acknowledgeItemPush(id: id, item: current, server: written.record)
                    try ledgerStore?.save(ledger)
                }
                if ledger.queue[id]?.photo == .upload, let photo = snapshot.items.first(where: { $0.id == id })?.photo {
                    try await client.uploadPhoto(userID: userID, itemID: id, data: photo, session: session)
                    guard generation == token else { return nil }
                    ledger.acknowledgePhotoUpload(id: id, digest: PhotoDigest.fingerprint(photo), remoteUpdatedAt: change.modifiedAt)
                    try ledgerStore?.save(ledger)
                } else if ledger.queue[id]?.photo == .delete {
                    try await client.deletePhotos(userID: userID, itemID: id, session: session)
                    guard generation == token else { return nil }
                    ledger.acknowledgePhotoDelete(id: id)
                    try ledgerStore?.save(ledger)
                }
            } catch let error as CloudError {
                if case .network = error { throw error }
                if case .unauthorized = error { throw error }
                failure = error
            }
        }
        publishSyncStatus()
        return failure.map(CloudMessage.sync)
    }

    private func download(_ downloads: [PhotoDownload], session: AuthSession, userID: UUID, token: Int) async throws -> String? {
        guard let repository else { return nil }
        var warning: String?
        for request in downloads {
            guard generation == token, !Task.isCancelled else { return warning }
            guard let index = snapshot.items.firstIndex(where: { $0.id == request.id }) else { continue }
            do {
                let data = try await client.downloadPhoto(userID: userID, itemID: request.id, slot: request.slot, session: session)
                guard generation == token else { return warning }
                guard data.count <= LocalRepository.maximumPhotoBytes else {
                    ledger.ignorePhoto(id: request.id, remoteUpdatedAt: request.remoteUpdatedAt)
                    try ledgerStore?.save(ledger)
                    warning = "A photo from your account is too large to store on this iPhone."
                    continue
                }
                #if canImport(ImageIO)
                guard PhotoPolicy.validatedSource(data) != nil else {
                    ledger.ignorePhoto(id: request.id, remoteUpdatedAt: request.remoteUpdatedAt)
                    try ledgerStore?.save(ledger)
                    warning = "A photo from your account couldn't be read and was left unchanged."
                    continue
                }
                #endif
                let digest = PhotoDigest.fingerprint(data)
                if snapshot.items[index].photo.map(PhotoDigest.fingerprint) != digest {
                    snapshot.items[index].photo = data
                    try repository.save(snapshot)
                }
                ledger.acknowledgePhotoDownload(id: request.id, digest: digest, slot: request.slot, remoteUpdatedAt: request.remoteUpdatedAt)
                try ledgerStore?.save(ledger)
            } catch let error as CloudError {
                if case .notFound = error { continue }
                if case .network = error { throw error }
                if case .unauthorized = error { throw error }
                ledger.ignorePhoto(id: request.id, remoteUpdatedAt: request.remoteUpdatedAt)
                try ledgerStore?.save(ledger)
                warning = CloudMessage.sync(error)
            }
        }
        return warning
    }
    #endif

    @discardableResult
    private func commit(_ proposed: TrackerSnapshot) -> Bool {
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

    private func persistLedger() {
        guard let ledgerStore else { return }
        do { try ledgerStore.save(ledger) }
        catch { syncMessage = "The change is saved on this iPhone, but the sync queue could not be saved." }
        publishSyncStatus()
    }

    private func publishSyncStatus() {
        lastSyncedAt = ledger.lastSyncedAt
        pendingChanges = ledger.pendingCount
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
