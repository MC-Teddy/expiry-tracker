import Foundation

/// Supabase project the website already uses. The anon key is public; it is not a service-role key.
public struct SupabaseConfig: Equatable, Sendable {
    public var baseURL: URL
    public var anonKey: String
    public var bucket: String

    public init(baseURL: URL, anonKey: String, bucket: String = "item-images") {
        self.baseURL = baseURL
        self.anonKey = anonKey
        self.bucket = bucket
    }

    public var host: String { baseURL.host ?? "" }

    public static let production = SupabaseConfig(
        baseURL: URL(string: "https://viupqrjyszvvcpnxrmsq.supabase.co")!,
        anonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZpdXBxcmp5c3p2dmNwbnhybXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkyOTY2ODgsImV4cCI6MjA5NDg3MjY4OH0.-j_X1M4_FBDuax4Gpd3tOHYdgs-fdWN2sPTbhYlG7qk"
    )
}

public enum CloudPaths {
    /// Matches the website: `<user_id>/<item_id>.jpg` and `<user_id>/<item_id>_full.jpg` in `item-images`.
    public static func imagePath(userID: UUID, itemID: UUID, full: Bool) -> String {
        userID.uuidString.lowercased() + "/" + itemID.uuidString.lowercased() + (full ? "_full.jpg" : ".jpg")
    }
}

public enum PhotoSlot: String, Codable, Equatable, Sendable {
    case primary
    case full
}

public struct RemotePhotoSet: Equatable, Sendable {
    public var primaryUpdatedAt: Date?
    public var fullUpdatedAt: Date?

    public init(primaryUpdatedAt: Date? = nil, fullUpdatedAt: Date? = nil) {
        self.primaryUpdatedAt = primaryUpdatedAt
        self.fullUpdatedAt = fullUpdatedAt
    }

    public var displaySlot: PhotoSlot? {
        if primaryUpdatedAt != nil { return .primary }
        if fullUpdatedAt != nil { return .full }
        return nil
    }

    public var displayUpdatedAt: Date? {
        switch displaySlot {
        case .primary: return primaryUpdatedAt
        case .full: return fullUpdatedAt
        case nil: return nil
        }
    }

    public var newestUpdatedAt: Date? {
        switch (primaryUpdatedAt, fullUpdatedAt) {
        case let (left?, right?): return max(left, right)
        case let (left?, nil): return left
        case let (nil, right?): return right
        case (nil, nil): return nil
        }
    }
}

public struct PhotoDownload: Equatable, Sendable {
    public var id: UUID
    public var slot: PhotoSlot
    public var remoteUpdatedAt: Date

    public init(id: UUID, slot: PhotoSlot, remoteUpdatedAt: Date) {
        self.id = id
        self.slot = slot
        self.remoteUpdatedAt = remoteUpdatedAt
    }
}

/// A column omitted from the JSON, present as null, or present with a value.
public enum ColumnValue<T: Equatable & Sendable>: Equatable, Sendable {
    case absent
    case null
    case value(T)
}

public struct CloudItemRecord: Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var category: String
    public var expiry: String
    public var added: Date
    public var updatedAt: Date?
    public var updatedAtPresent: Bool
    public var quantity: ColumnValue<Int>
    public var notes: ColumnValue<String>
    public var barcode: ColumnValue<String>
    public var userID: UUID?
    public var deviceID: String?

    public init(id: UUID, name: String, category: String, expiry: String, added: Date,
                updatedAt: Date? = nil, updatedAtPresent: Bool = false,
                quantity: ColumnValue<Int> = .absent, notes: ColumnValue<String> = .absent,
                barcode: ColumnValue<String> = .absent, userID: UUID? = nil, deviceID: String? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.expiry = expiry
        self.added = added
        self.updatedAt = updatedAt
        self.updatedAtPresent = updatedAtPresent
        self.quantity = quantity
        self.notes = notes
        self.barcode = barcode
        self.userID = userID
        self.deviceID = deviceID
    }

    /// Last-write time. Web edits often leave `added` unchanged and only set `updated_at` when that column exists.
    public var writeTime: Date { updatedAt ?? added }
}

public struct AuthSession: Codable, Equatable, Sendable {
    public var accessToken: String
    public var refreshToken: String
    public var expiresAt: Date
    public var userID: UUID
    public var email: String

    public init(accessToken: String, refreshToken: String, expiresAt: Date, userID: UUID, email: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.userID = userID
        self.email = email
    }

    public var needsRefresh: Bool {
        expiresAt.timeIntervalSinceNow < 60
    }
}

public enum CloudError: Error, Equatable, Sendable {
    case network
    case unauthorized
    case invalidCredentials
    case notFound
    case conflict
    case malformed
    case rejectedColumn(String)
    case server(status: Int, message: String)
}

public enum CloudMessage {
    public static func signIn(_ error: CloudError) -> String {
        switch error {
        case .network:
            return "Network error — check your connection and try again."
        case .invalidCredentials, .unauthorized:
            return "Email or password is incorrect."
        case .malformed:
            return "Sign-in failed. The server sent an unexpected response."
        case .server(_, let message):
            return message.isEmpty ? "Sign-in failed. Try again." : clip(message)
        case .notFound, .conflict, .rejectedColumn:
            return "Sign-in failed. Try again."
        }
    }

    public static func sync(_ error: CloudError) -> String {
        switch error {
        case .network:
            return "Changes are saved on this iPhone. They'll sync when you're back online."
        case .unauthorized, .invalidCredentials:
            return "Your session expired. Sign in again."
        case .malformed:
            return "Sync didn't finish because the server response was unexpected. Your changes are saved on this iPhone."
        case .server(let status, let message):
            if status >= 500 {
                return "The server couldn't complete the sync. Your changes are saved on this iPhone and will be retried."
            }
            return message.isEmpty ? "Sync didn't finish. Your changes are saved on this iPhone." : clip(message)
        case .notFound, .conflict, .rejectedColumn:
            return "Sync didn't finish. Your changes are saved on this iPhone."
        }
    }

    public static let missingCredentials = "Enter your email and password."

    private static func clip(_ message: String) -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 180 { return trimmed }
        return String(trimmed.prefix(177)) + "..."
    }
}

public enum CloudDate {
    public static func encode(_ date: Date) -> String {
        let millis = Int64((date.timeIntervalSince1970 * 1000).rounded())
        var seconds = millis / 1000
        var fraction = millis % 1000
        if fraction < 0 {
            fraction += 1000
            seconds -= 1
        }
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [.withInternetDateTime]
        let stamped = formatter.string(from: Date(timeIntervalSince1970: TimeInterval(seconds)))
        let stem = stamped.hasSuffix("Z") ? String(stamped.dropLast()) : stamped
        return String(format: "%@.%03dZ", stem, Int(fraction))
    }

    public static func parse(_ text: String) -> Date? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var body = trimmed
        var offset = 0
        if body.hasSuffix("Z") {
            body.removeLast()
        } else if let zone = timeZoneSuffix(body) {
            body = String(body.dropLast(zone.characters))
            offset = zone.seconds
        }
        let pieces = body.split(separator: ".", omittingEmptySubsequences: false)
        guard pieces.count <= 2, let clock = pieces.first else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.isLenient = false
        formatter.dateFormat = clock.contains("T") ? "yyyy-MM-dd'T'HH:mm:ss" : "yyyy-MM-dd HH:mm:ss"
        guard let instant = formatter.date(from: String(clock)) else { return nil }
        var extra = 0.0
        if pieces.count == 2 {
            let digits = pieces[1].prefix { $0.isNumber }
            guard !digits.isEmpty, digits.count <= 9, let raw = Double(digits) else { return nil }
            var scale = 1.0
            for _ in 0..<digits.count { scale *= 10 }
            extra = raw / scale
        }
        return instant.addingTimeInterval(extra - TimeInterval(offset))
    }

    private static func timeZoneSuffix(_ text: String) -> (characters: Int, seconds: Int)? {
        guard let index = text.lastIndex(where: { $0 == "+" || $0 == "-" }), index != text.startIndex else { return nil }
        let sign = text[index] == "+" ? 1 : -1
        let raw = text[text.index(after: index)...]
        let parts = raw.split(separator: ":")
        let hours: Int
        let minutes: Int
        if parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]), (0...23).contains(h), (0...59).contains(m) {
            hours = h
            minutes = m
        } else if parts.count == 1, raw.count == 4, let h = Int(raw.prefix(2)), let m = Int(raw.suffix(2)) {
            hours = h
            minutes = m
        } else if parts.count == 1, raw.count == 2, let h = Int(raw) {
            hours = h
            minutes = 0
        } else {
            return nil
        }
        return (1 + raw.count, sign * (hours * 3600 + minutes * 60))
    }
}

public enum CloudSchema {
    public static let optionalColumns: Set<String> = ["quantity", "notes", "barcode", "updated_at"]

    public static func accepted(rejected: Set<String>) -> Set<String> {
        optionalColumns.subtracting(rejected)
    }

    public static func normalizedCategory(_ icon: String) -> String {
        let trimmed = icon.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Other" : trimmed
    }
}

public enum CloudCodec {
    public static func insertBody(item: ExpiryItem, userID: UUID, deviceID: UUID, modifiedAt: Date, rejected: Set<String>) throws -> Data {
        try data([writeObject(item: item, userID: userID, deviceID: deviceID, modifiedAt: modifiedAt, rejected: rejected, includeIdentity: true)])
    }

    public static func updateBody(item: ExpiryItem, modifiedAt: Date, rejected: Set<String>) throws -> Data {
        var object = writeObject(item: item, userID: UUID(), deviceID: UUID(), modifiedAt: modifiedAt, rejected: rejected, includeIdentity: false)
        object.removeValue(forKey: "id")
        object.removeValue(forKey: "user_id")
        object.removeValue(forKey: "device_id")
        object.removeValue(forKey: "added")
        return try data(object)
    }

    public static func decodeItems(_ data: Data) throws -> [CloudItemRecord] {
        let json = try jsonObject(data)
        let rows: [[String: Any]]
        if let array = json as? [[String: Any]] {
            rows = array
        } else if let object = json as? [String: Any] {
            rows = [object]
        } else if json is [Any], (json as? [Any])?.isEmpty == true {
            rows = []
        } else {
            throw CloudError.malformed
        }
        return try rows.map { try decodeItem($0) }
    }

    public static func decodeSession(_ data: Data, fallbackEmail: String, now: Date = Date()) throws -> AuthSession {
        guard let object = try jsonObject(data) as? [String: Any] else { throw CloudError.malformed }
        guard let access = object["access_token"] as? String, !access.isEmpty,
              let refresh = object["refresh_token"] as? String, !refresh.isEmpty,
              let user = object["user"] as? [String: Any],
              let idText = user["id"] as? String, let userID = UUID(uuidString: idText) else {
            throw CloudError.malformed
        }
        let email = (user["email"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? fallbackEmail
        let expires: Date
        if let stamp = object["expires_at"] as? NSNumber {
            expires = Date(timeIntervalSince1970: stamp.doubleValue)
        } else if let seconds = object["expires_in"] as? NSNumber {
            expires = now.addingTimeInterval(seconds.doubleValue)
        } else {
            throw CloudError.malformed
        }
        return AuthSession(accessToken: access, refreshToken: refresh, expiresAt: expires, userID: userID, email: email)
    }

    public static func missingColumn(in data: Data) -> String? {
        guard let object = try? jsonObject(data) as? [String: Any],
              let message = object["message"] as? String else { return nil }
        let needle = "Could not find the '"
        guard let start = message.range(of: needle)?.upperBound,
              let end = message[start...].firstIndex(of: "'") else { return nil }
        let name = String(message[start..<end])
        return name.isEmpty ? nil : name
    }

    public static func isInvalidCredentials(_ data: Data) -> Bool {
        let text = String(data: data, encoding: .utf8)?.lowercased() ?? ""
        return text.contains("invalid_credentials") || text.contains("invalid login") || text.contains("invalid_grant")
    }

    public static func serverMessage(_ data: Data) -> String? {
        guard let object = try? jsonObject(data) as? [String: Any] else { return nil }
        for key in ["msg", "error_description", "message"] {
            if let text = object[key] as? String {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty, trimmed != "invalid_grant" { return trimmed }
            }
        }
        return nil
    }

    public static func decodePhotoList(_ data: Data, userID: UUID) throws -> [UUID: RemotePhotoSet] {
        guard let rows = try jsonObject(data) as? [[String: Any]] else { throw CloudError.malformed }
        var photos: [UUID: RemotePhotoSet] = [:]
        let prefix = userID.uuidString.lowercased() + "/"
        for row in rows {
            guard let name = row["name"] as? String else { continue }
            let file = name.hasPrefix(prefix) ? String(name.dropFirst(prefix.count)) : name
            let full = file.hasSuffix("_full.jpg")
            let stem = full ? String(file.dropLast("_full.jpg".count)) : (file.hasSuffix(".jpg") ? String(file.dropLast(4)) : nil)
            guard let stem, let id = UUID(uuidString: stem),
                  let raw = row["updated_at"] as? String, let updated = CloudDate.parse(raw) else { continue }
            var set = photos[id] ?? RemotePhotoSet()
            if full { set.fullUpdatedAt = updated } else { set.primaryUpdatedAt = updated }
            photos[id] = set
        }
        return photos
    }

    private static func writeObject(item: ExpiryItem, userID: UUID, deviceID: UUID, modifiedAt: Date, rejected: Set<String>, includeIdentity: Bool) -> [String: Any] {
        var object: [String: Any] = [
            "name": item.name,
            "expiry": item.expiry,
            "icon": item.category
        ]
        if includeIdentity {
            object["id"] = item.id.uuidString.lowercased()
            object["user_id"] = userID.uuidString.lowercased()
            object["device_id"] = deviceID.uuidString.lowercased()
            object["added"] = CloudDate.encode(item.createdAt)
        }
        let accepted = CloudSchema.accepted(rejected: rejected)
        if accepted.contains("quantity") { object["quantity"] = item.quantity }
        if accepted.contains("notes") { object["notes"] = item.notes }
        if accepted.contains("barcode") { object["barcode"] = item.barcode ?? NSNull() }
        if accepted.contains("updated_at") { object["updated_at"] = CloudDate.encode(modifiedAt) }
        return object
    }

    private static func decodeItem(_ object: [String: Any]) throws -> CloudItemRecord {
        guard let idText = string(object["id"]), let id = UUID(uuidString: idText) else { throw CloudError.malformed }
        let added = (string(object["added"]).flatMap(CloudDate.parse)) ?? Date(timeIntervalSince1970: 0)
        let updatedPresent = object.keys.contains("updated_at")
        let updated = updatedPresent ? string(object["updated_at"]).flatMap(CloudDate.parse) : nil
        return CloudItemRecord(
            id: id,
            name: string(object["name"]) ?? "",
            category: string(object["icon"]) ?? "",
            expiry: string(object["expiry"]) ?? "",
            added: added,
            updatedAt: updated,
            updatedAtPresent: updatedPresent,
            quantity: integerColumn(object, key: "quantity"),
            notes: stringColumn(object, key: "notes"),
            barcode: stringColumn(object, key: "barcode"),
            userID: string(object["user_id"]).flatMap(UUID.init(uuidString:)),
            deviceID: string(object["device_id"])
        )
    }

    private static func integerColumn(_ object: [String: Any], key: String) -> ColumnValue<Int> {
        guard object.keys.contains(key) else { return .absent }
        if object[key] is NSNull { return .null }
        if let number = object[key] as? NSNumber { return .value(number.intValue) }
        return .null
    }

    private static func stringColumn(_ object: [String: Any], key: String) -> ColumnValue<String> {
        guard object.keys.contains(key) else { return .absent }
        if object[key] is NSNull { return .null }
        if let text = object[key] as? String { return .value(text) }
        return .null
    }

    private static func string(_ value: Any?) -> String? {
        if let text = value as? String { return text }
        if let number = value as? NSNumber { return number.stringValue }
        return nil
    }

    private static func jsonObject(_ data: Data) throws -> Any {
        do {
            return try JSONSerialization.jsonObject(with: data)
        } catch {
            throw CloudError.malformed
        }
    }

    private static func data(_ object: Any) throws -> Data {
        guard JSONSerialization.isValidJSONObject(object) else { throw CloudError.malformed }
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }
}
