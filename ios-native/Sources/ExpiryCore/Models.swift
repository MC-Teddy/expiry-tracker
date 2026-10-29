import Foundation

public struct ExpiryItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var category: String
    public var quantity: Int
    public var expiry: String
    public var notes: String
    public var barcode: String?
    public var photo: Data?
    public var createdAt: Date

    public init(id: UUID = UUID(), name: String, category: String, quantity: Int = 1,
                expiry: String, notes: String = "", barcode: String? = nil,
                photo: Data? = nil, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.category = category
        self.quantity = quantity
        self.expiry = expiry
        self.notes = notes
        self.barcode = barcode
        self.photo = photo
        self.createdAt = createdAt
    }

    public func daysRemaining(now: Date = Date(), calendar: Calendar = .current) -> Int {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        guard let date = Self.expiryDate(expiry, calendar: gregorian) else { return Int.min }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: now),
                                       to: calendar.startOfDay(for: date)).day ?? Int.min
    }

    public func status(settings: TrackerSettings, now: Date = Date(), calendar: Calendar = .current) -> ExpiryStatus {
        let days = daysRemaining(now: now, calendar: calendar)
        if days < 0 { return .expired }
        if days <= settings.criticalDays { return .critical }
        if days <= settings.soonDays { return .soon }
        return .fresh
    }

    static func expiryDate(_ value: String, calendar: Calendar) -> Date? {
        let pieces = value.split(separator: "-", omittingEmptySubsequences: false)
        guard pieces.count == 3, pieces[0].count == 4, pieces[1].count == 2, pieces[2].count == 2,
              value.utf8.allSatisfy({ (48...57).contains($0) || $0 == 45 }),
              let year = Int(pieces[0]), year > 0, let month = Int(pieces[1]), let day = Int(pieces[2]),
              let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { return nil }
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return parts.year == year && parts.month == month && parts.day == day ? date : nil
    }
}

public struct TrackerSettings: Codable, Equatable, Sendable {
    public var soonDays: Int
    public var criticalDays: Int
    public init(soonDays: Int = 14, criticalDays: Int = 3) {
        self.soonDays = soonDays
        self.criticalDays = criticalDays
    }
}

public enum ExpiryStatus: String, Codable, Sendable {
    case expired, critical, soon, fresh
}
