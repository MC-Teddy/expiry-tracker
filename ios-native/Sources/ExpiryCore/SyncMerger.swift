import Foundation

public struct MergeResult: Equatable, Sendable {
    public var items: [ExpiryItem]
    public var ledger: SyncLedger
    public var downloads: [PhotoDownload]
    public var withheld: [UUID]
}

/// Last-write-wins merge of the on-device inventory and one account's `items` rows.
public enum SyncMerger {
    public static func merge(items: [ExpiryItem], ledger: SyncLedger, remote: [CloudItemRecord],
                             photos: [UUID: RemotePhotoSet] = [:], now: Date) -> MergeResult {
        var ledger = ledger
        let accepted = CloudSchema.accepted(rejected: ledger.rejectedColumns)
        var remoteByID: [UUID: CloudItemRecord] = [:]
        for record in remote { remoteByID[record.id] = record }
        let localByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        var ids = Set(localByID.keys)
        ids.formUnion(remoteByID.keys)
        ids.formUnion(ledger.queue.keys)
        ids.formUnion(ledger.baselines.keys)

        var merged: [UUID: ExpiryItem] = [:]
        var downloads: [PhotoDownload] = []
        var withheld: [UUID] = []
        let calendar = Calendar(identifier: .gregorian)

        for id in ids.sorted(by: { $0.uuidString < $1.uuidString }) {
            var queued = ledger.queue[id]
            let remote = remoteByID[id]
            let local = localByID[id]

            if queued?.action == .delete {
                if let remote, remote.writeTime > queued!.modifiedAt {
                    ledger.queue.removeValue(forKey: id)
                    queued = nil
                } else if remote == nil {
                    ledger.queue.removeValue(forKey: id)
                    ledger.baselines.removeValue(forKey: id)
                    continue
                } else {
                    continue
                }
            }

            guard let remote else {
                guard let local else {
                    ledger.queue.removeValue(forKey: id)
                    ledger.baselines.removeValue(forKey: id)
                    continue
                }
                if ledger.localOnlyIDs.contains(id), ledger.baselines[id] == nil, queued == nil {
                    merged[id] = local
                    continue
                }
                let dirty = queued?.action == .upsert || (ledger.baselines[id] != nil && drifted(local, ledger.baselines[id]!, accepted: accepted))
                if ledger.baselines[id] != nil, !dirty, queued?.photo != .upload, queued?.action != .upsert {
                    ledger.baselines.removeValue(forKey: id)
                    ledger.queue.removeValue(forKey: id)
                    continue
                }
                merged[id] = local
                ensureUpsert(id: id, item: local, at: queued?.modifiedAt ?? local.createdAt, ledger: &ledger)
                resolvePhoto(id: id, item: &merged[id]!, remote: nil, localWriteTime: ledger.queue[id]?.modifiedAt ?? local.createdAt,
                             now: now, ledger: &ledger, downloads: &downloads)
                continue
            }

            guard var item = local else {
                guard var adopted = makeItem(remote: remote, base: local) else {
                    withheld.append(id)
                    continue
                }
                adopted.createdAt = remote.added
                if !valid(adopted, calendar: calendar) {
                    withheld.append(id)
                    continue
                }
                writeBaseline(id: id, item: adopted, remote: remote, accepted: accepted, ledger: &ledger)
                ledger.queue.removeValue(forKey: id)
                resolvePhoto(id: id, item: &adopted, remote: photos[id], localWriteTime: remote.writeTime,
                             now: now, ledger: &ledger, downloads: &downloads)
                merged[id] = adopted
                continue
            }

            if ledger.localOnlyIDs.contains(id), ledger.baselines[id] == nil, queued == nil {
                merged[id] = item
                continue
            }

            let base = ledger.baselines[id]
            let dirty = queued?.action == .upsert || (base != nil && drifted(item, base!, accepted: accepted))
            let localTime = queued?.action == .upsert ? queued!.modifiedAt : now
            let remoteTime = remote.writeTime
            item.name = pick(item.name, remote.name, base?.name, dirty: dirty, localTime: localTime, remoteTime: remoteTime)
            item.category = pick(item.category, CloudSchema.normalizedCategory(remote.category), base?.category,
                                 dirty: dirty, localTime: localTime, remoteTime: remoteTime)
            item.expiry = pick(item.expiry, remote.expiry, base?.expiry, dirty: dirty, localTime: localTime, remoteTime: remoteTime)
            item.createdAt = remote.added
            if accepted.contains("quantity"), case .value(let raw) = remote.quantity, (1...999_999).contains(raw) {
                let baseQuantity = base?.tracksQuantity == true ? base?.quantity : nil
                let compare = dirty && (base == nil || base?.tracksQuantity == true)
                item.quantity = pick(item.quantity, raw, baseQuantity, dirty: compare, localTime: localTime, remoteTime: remoteTime)
            }
            if accepted.contains("notes") {
                switch remote.notes {
                case .value(let raw):
                    let baseNotes = base?.tracksNotes == true ? base?.notes : nil
                    let compare = dirty && (base == nil || base?.tracksNotes == true)
                    item.notes = pick(item.notes, raw, baseNotes, dirty: compare, localTime: localTime, remoteTime: remoteTime)
                case .null:
                    let baseNotes = base?.tracksNotes == true ? base?.notes : nil
                    if base?.tracksNotes == true {
                        item.notes = pick(item.notes, "", baseNotes, dirty: dirty, localTime: localTime, remoteTime: remoteTime)
                    }
                case .absent:
                    break
                }
            }
            if accepted.contains("barcode") {
                switch remote.barcode {
                case .value(let raw):
                    let remoteCode = raw.isEmpty ? nil : raw
                    let baseCode = base?.tracksBarcode == true ? base?.barcode : nil
                    let compare = dirty && (base == nil || base?.tracksBarcode == true)
                    item.barcode = pick(item.barcode, remoteCode, baseCode, dirty: compare, localTime: localTime, remoteTime: remoteTime)
                case .null:
                    if base?.tracksBarcode == true {
                        item.barcode = pick(item.barcode, nil, base?.barcode, dirty: dirty, localTime: localTime, remoteTime: remoteTime)
                    }
                case .absent:
                    break
                }
            }

            guard valid(item, calendar: calendar) else {
                withheld.append(id)
                if let local, valid(local, calendar: calendar) { merged[id] = local }
                continue
            }

            var needsPush = item.name != remote.name
                || item.category != CloudSchema.normalizedCategory(remote.category)
                || item.expiry != remote.expiry
            if accepted.contains("quantity") {
                switch remote.quantity {
                case .absent: break
                case .null: if item.quantity != 1 { needsPush = true }
                case .value(let raw): if (1...999_999).contains(raw), item.quantity != raw { needsPush = true }
                }
            }
            if accepted.contains("notes") {
                switch remote.notes {
                case .absent: break
                case .null: if !item.notes.isEmpty { needsPush = true }
                case .value(let raw): if item.notes != raw { needsPush = true }
                }
            }
            if accepted.contains("barcode") {
                switch remote.barcode {
                case .absent: break
                case .null: if item.barcode != nil { needsPush = true }
                case .value(let raw):
                    let remoteCode = raw.isEmpty ? nil : raw
                    if item.barcode != remoteCode { needsPush = true }
                }
            }

            if needsPush {
                var change = ledger.queue[id] ?? QueuedChange(action: .upsert, modifiedAt: localTime, photo: .unchanged)
                change.action = .upsert
                if ledger.queue[id] == nil { change.modifiedAt = localTime }
                ledger.queue[id] = change
            } else if var change = ledger.queue[id], change.action == .upsert {
                if change.photo == .unchanged {
                    ledger.queue.removeValue(forKey: id)
                } else {
                    change.action = .photo
                    ledger.queue[id] = change
                }
                writeBaseline(id: id, item: item, remote: remote, accepted: accepted, ledger: &ledger)
            } else if ledger.queue[id]?.action != .photo || ledger.queue[id]?.photo == .unchanged {
                writeBaseline(id: id, item: item, remote: remote, accepted: accepted, ledger: &ledger)
            } else {
                writeBaseline(id: id, item: item, remote: remote, accepted: accepted, ledger: &ledger)
            }

            let writeTime = ledger.queue[id]?.modifiedAt ?? item.createdAt
            resolvePhoto(id: id, item: &item, remote: photos[id], localWriteTime: writeTime, now: now, ledger: &ledger, downloads: &downloads)
            merged[id] = item
        }

        var output: [ExpiryItem] = []
        var seen = Set<UUID>()
        for item in items {
            if let updated = merged[item.id] {
                output.append(updated)
                seen.insert(item.id)
            }
        }
        let extras = merged.keys.filter { !seen.contains($0) }.sorted {
            let left = merged[$0]!
            let right = merged[$1]!
            return left.expiry == right.expiry ? left.name < right.name : left.expiry < right.expiry
        }
        for id in extras { output.append(merged[id]!) }
        downloads.sort { $0.id.uuidString < $1.id.uuidString }
        withheld.sort { $0.uuidString < $1.uuidString }
        return MergeResult(items: output, ledger: ledger, downloads: downloads, withheld: withheld)
    }

    private static func ensureUpsert(id: UUID, item: ExpiryItem, at: Date, ledger: inout SyncLedger) {
        var change = ledger.queue[id] ?? QueuedChange(action: .upsert, modifiedAt: at, photo: item.photo == nil ? .unchanged : .upload)
        change.action = .upsert
        if ledger.queue[id] == nil {
            change.modifiedAt = at
            change.photo = item.photo == nil ? .unchanged : .upload
        }
        ledger.queue[id] = change
    }

    private static func drifted(_ item: ExpiryItem, _ base: ItemBaseline, accepted: Set<String>) -> Bool {
        if item.name != base.name || item.category != base.category || item.expiry != base.expiry { return true }
        if accepted.contains("quantity"), base.tracksQuantity, base.quantity != item.quantity { return true }
        if accepted.contains("notes"), base.tracksNotes, base.notes != item.notes { return true }
        if accepted.contains("barcode"), base.tracksBarcode, base.barcode != item.barcode { return true }
        return false
    }

    private static func pick<T: Equatable>(_ local: T, _ remote: T, _ base: T?, dirty: Bool, localTime: Date, remoteTime: Date) -> T {
        let localChanged: Bool
        let remoteChanged: Bool
        if let base {
            localChanged = dirty && local != base
            remoteChanged = remote != base
        } else {
            localChanged = true
            remoteChanged = true
        }
        switch (localChanged, remoteChanged) {
        case (true, true): return remoteTime > localTime ? remote : local
        case (false, true): return remote
        case (true, false): return local
        case (false, false): return local
        }
    }

    private static func writeBaseline(id: UUID, item: ExpiryItem, remote: CloudItemRecord, accepted: Set<String>, ledger: inout SyncLedger) {
        var base = ledger.baselines[id] ?? ItemBaseline(name: item.name, category: item.category, expiry: item.expiry, added: remote.added)
        base.name = item.name
        base.category = item.category
        base.expiry = item.expiry
        base.added = remote.added
        base.remoteUpdatedAt = remote.writeTime
        if accepted.contains("quantity") {
            switch remote.quantity {
            case .absent:
                base.tracksQuantity = false
            case .null, .value:
                base.tracksQuantity = true
                base.quantity = item.quantity
            }
        }
        if accepted.contains("notes") {
            switch remote.notes {
            case .absent:
                base.tracksNotes = false
            case .null, .value:
                base.tracksNotes = true
                base.notes = item.notes
            }
        }
        if accepted.contains("barcode") {
            switch remote.barcode {
            case .absent:
                base.tracksBarcode = false
            case .null, .value:
                base.tracksBarcode = true
                base.barcode = item.barcode
            }
        }
        ledger.baselines[id] = base
    }

    private static func makeItem(remote: CloudItemRecord, base: ExpiryItem?) -> ExpiryItem? {
        let category = CloudSchema.normalizedCategory(remote.category)
        var quantity = base?.quantity ?? 1
        if case .value(let raw) = remote.quantity, (1...999_999).contains(raw) { quantity = raw }
        var notes = base?.notes ?? ""
        if case .value(let raw) = remote.notes { notes = raw }
        var barcode = base?.barcode
        switch remote.barcode {
        case .value(let raw): barcode = raw.isEmpty ? nil : raw
        case .null: barcode = nil
        case .absent: break
        }
        return ExpiryItem(id: remote.id, name: remote.name, category: category, quantity: quantity,
                          expiry: remote.expiry, notes: notes, barcode: barcode, photo: base?.photo, createdAt: remote.added)
    }

    private static func valid(_ item: ExpiryItem, calendar: Calendar) -> Bool {
        let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let category = item.category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, item.name.count <= 200, !category.isEmpty, item.category.count <= 100 else { return false }
        guard (1...999_999).contains(item.quantity) else { return false }
        guard (item.photo?.count ?? 0) <= LocalRepository.maximumPhotoBytes else { return false }
        return ExpiryItem.expiryDate(item.expiry, calendar: calendar) != nil
    }

    private static func resolvePhoto(id: UUID, item: inout ExpiryItem, remote: RemotePhotoSet?, localWriteTime: Date,
                                    now: Date, ledger: inout SyncLedger, downloads: inout [PhotoDownload]) {
        let remote = remote ?? RemotePhotoSet()
        let queued = ledger.queue[id]?.photo ?? .unchanged
        let queueTime = ledger.queue[id]?.modifiedAt ?? localWriteTime
        let base = ledger.baselines[id]
        let digest = item.photo.map(PhotoDigest.fingerprint)

        if queued == .upload {
            if let newest = remote.newestUpdatedAt, newest > queueTime {
                setPhoto(id: id, .unchanged, at: queueTime, ledger: &ledger)
                scheduleDownload(id: id, remote: remote, base: ledger.baselines[id], downloads: &downloads)
            } else {
                setPhoto(id: id, .upload, at: queueTime, ledger: &ledger)
            }
            return
        }
        if queued == .delete {
            if let newest = remote.newestUpdatedAt, newest > queueTime {
                setPhoto(id: id, .unchanged, at: queueTime, ledger: &ledger)
                scheduleDownload(id: id, remote: remote, base: ledger.baselines[id], downloads: &downloads)
            } else {
                setPhoto(id: id, .delete, at: queueTime, ledger: &ledger)
                item.photo = nil
            }
            return
        }
        if let stamp = remote.displayUpdatedAt, remote.displaySlot != nil {
            if base?.ignoredPhotoUpdatedAt == stamp { return }
            if let synced = base?.photoRemoteUpdatedAt, stamp <= synced, digest == base?.photoDigest { return }
            if base?.photoDigest == nil {
                if item.photo == nil {
                    scheduleDownload(id: id, remote: remote, base: base, downloads: &downloads)
                } else if stamp > localWriteTime {
                    scheduleDownload(id: id, remote: remote, base: base, downloads: &downloads)
                } else {
                    setPhoto(id: id, .upload, at: localWriteTime, ledger: &ledger)
                }
                return
            }
            if digest != base?.photoDigest {
                setPhoto(id: id, .upload, at: now, ledger: &ledger)
                return
            }
            if stamp > (base?.photoRemoteUpdatedAt ?? .distantPast) {
                scheduleDownload(id: id, remote: remote, base: base, downloads: &downloads)
            }
            return
        }
        if let synced = base?.photoDigest, digest == synced {
            item.photo = nil
            if var cleared = ledger.baselines[id] {
                cleared.photoDigest = nil
                cleared.photoSlot = nil
                cleared.photoRemoteUpdatedAt = nil
                ledger.baselines[id] = cleared
            }
            return
        }
        if item.photo != nil {
            setPhoto(id: id, .upload, at: localWriteTime, ledger: &ledger)
        }
    }

    private static func scheduleDownload(id: UUID, remote: RemotePhotoSet, base: ItemBaseline?, downloads: inout [PhotoDownload]) {
        guard let slot = remote.displaySlot, let stamp = remote.displayUpdatedAt, base?.ignoredPhotoUpdatedAt != stamp else { return }
        downloads.append(PhotoDownload(id: id, slot: slot, remoteUpdatedAt: stamp))
    }

    private static func setPhoto(id: UUID, _ photo: QueuedChange.Photo, at: Date, ledger: inout SyncLedger) {
        if photo == .unchanged {
            guard var change = ledger.queue[id] else { return }
            change.photo = .unchanged
            if change.action == .photo {
                ledger.queue.removeValue(forKey: id)
            } else {
                ledger.queue[id] = change
            }
            return
        }
        var change = ledger.queue[id] ?? QueuedChange(action: .photo, modifiedAt: at, photo: photo)
        if ledger.queue[id] == nil { change.modifiedAt = at }
        change.photo = photo
        ledger.queue[id] = change
    }
}
