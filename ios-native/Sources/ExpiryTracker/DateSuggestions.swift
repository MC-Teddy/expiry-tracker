import Foundation

public enum DayCodec {
    public static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }
    public static func formatter() -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = calendar
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        f.isLenient = false
        return f
    }
    public static func string(_ date: Date) -> String { formatter().string(from: date) }
    public static func date(_ text: String) -> Date? {
        let f = formatter()
        guard let day = f.date(from: text), f.string(from: day) == text else { return nil }
        return day
    }
}

public enum DateSuggestions {
    public struct MonthCandidate: Equatable, Hashable, Identifiable, Sendable {
        public let yearMonth: String
        public let lastDay: String
        public var id: String { yearMonth }
    }
    public struct Reading: Equatable, Sendable {
        public var candidates: [String] = []
        public var months: [MonthCandidate] = []
        public var requiresReview = false
        public var automaticDate: String? { !requiresReview && months.isEmpty && candidates.count == 1 ? candidates.first : nil }
        var hasDates: Bool { !candidates.isEmpty || !months.isEmpty }
    }
    private enum Kind { case expiry, production, unknown, mixed }
    private struct Token {
        let range: NSRange
        var dates: [String] = []
        var months: [MonthCandidate] = []
        var needsLabel = false
        var corrected = false
        var reviewOnly = false
    }
    private struct Entry {
        let kind: Kind
        let token: Token
    }
    private static let expiryPattern = #"\b(?:exp(?:iry|iration|ires)?|expiration\s*date|best\s*(?:before|by)|use\s*(?:by|before)|bb(?:e|d)?|b[./]b(?:[./]e)?|valid\s*(?:until|till)|sell\s*by)\b|(?<!\p{L})E\s*:|انتهاء|صلاحية|صالح حتى|يفضل استخدامه قبل"#
    private static let productionPattern = #"\b(?:mfg|mfd|manufactur(?:ed|ing)|production|prod|packed|pkd|date\s*of\s*manufacture)\b|(?<!\p{L})P\s*:|إنتاج|انتاج|تصنيع|تعبئة"#
    private static let aliases = [
        ["January", "Jan", "يناير", "كانون الثاني"], ["February", "Feb", "فبراير", "شباط"],
        ["March", "Mar", "مارس", "آذار", "اذار"], ["April", "Apr", "أبريل", "ابريل", "نيسان"],
        ["May", "مايو", "أيار", "ايار"], ["June", "Jun", "يونيو", "يونيه", "حزيران"],
        ["July", "Jul", "يوليو", "يوليه", "تموز"], ["August", "Aug", "أغسطس", "اغسطس", "آب"],
        ["September", "Sept", "Sep", "سبتمبر", "أيلول", "ايلول"], ["October", "Oct", "أكتوبر", "اكتوبر", "تشرين الأول", "تشرين الاول"],
        ["November", "Nov", "نوفمبر", "تشرين الثاني"], ["December", "Dec", "ديسمبر", "كانون الأول", "كانون الاول"]
    ]
    private static let monthPattern: String = {
        aliases.flatMap { $0 }.sorted { $0.count > $1.count }.map {
            NSRegularExpression.escapedPattern(for: $0).replacingOccurrences(of: " ", with: #"\s+"#)
        }.joined(separator: "|")
    }()
    private static func monthNumber(_ name: String) -> Int {
        let name = name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return (aliases.firstIndex { $0.contains { $0.caseInsensitiveCompare(name) == .orderedSame } } ?? -1) + 1
    }
    private static func contains(_ pattern: String, _ text: String) -> Bool {
        text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
    private static func kind(_ context: String) -> Kind {
        let expiry = contains(expiryPattern, context) || contains(#"^\s*E[.:]?\s*$"#, context)
        let production = contains(productionPattern, context) || contains(#"^\s*P[.:]?\s*$"#, context)
        if expiry && production { return .mixed }
        return expiry ? .expiry : (production ? .production : .unknown)
    }
    private static func normalized(_ text: String) -> String {
        text.map { character in
            if let digit = character.wholeNumberValue, (0...9).contains(digit) { return String(digit) }
            if "‐‑–—−".contains(character) { return "-" }
            return String(character)
        }.joined().replacingOccurrences(of: "\u{200f}", with: "").replacingOccurrences(of: "\u{200e}", with: "")
            .replacingOccurrences(of: #"(?i)\b(EXP(?:IRY)?|BBE|BBD|BB|MFG|MFD|E|P)[.:]?\s*(?=[0-9])"#, with: "$1: ", options: .regularExpression)
    }
    private static func integer(_ text: String) -> Int {
        let substitutions: [Character: Character] = ["O": "0", "o": "0", "I": "1", "l": "1", "S": "5", "B": "8"]
        return Int(String(text.map { substitutions[$0] ?? $0 })) ?? -1
    }
    private static func year(_ text: String) -> Int { text.count == 2 ? 2000 + integer(text) : integer(text) }
    private static func day(_ y: Int, _ m: Int, _ d: Int) -> String? {
        guard (1900...2199).contains(y) else { return nil }
        let iso = String(format: "%04d-%02d-%02d", y, m, d)
        return DayCodec.date(iso) == nil ? nil : iso
    }
    private static func month(_ y: Int, _ m: Int) -> MonthCandidate? {
        guard let first = day(y, m, 1), let date = DayCodec.date(first),
              let days = DayCodec.calendar.range(of: .day, in: .month, for: date),
              let last = day(y, m, days.count) else { return nil }
        return MonthCandidate(yearMonth: String(first.prefix(7)), lastDay: last)
    }

    private static func tokens(_ text: String) -> [Token] {
        let source = text as NSString
        var found: [Token] = []
        func scan(_ pattern: String, _ parse: (NSTextCheckingResult, (Int) -> String) -> Token) {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return }
            for match in regex.matches(in: text, range: NSRange(location: 0, length: source.length)) {
                guard !found.contains(where: { NSIntersectionRange($0.range, match.range).length > 0 }) else { continue }
                let token = parse(match, { source.substring(with: match.range(at: $0)) })
                found.append(token) // Reserve invalid full dates too; never reinterpret a fragment as month/year.
            }
        }
        let start = #"(?<![\p{L}\p{N}/.\-])"#
        let end = #"(?![\p{L}\p{N}]|[/\-]\s*\d|\.\s*\d)"#
        let digits = #"[0-9OoIlSB]"#
        scan(start + "(" + digits + #"{1,4})\s*[-/.]\s*("# + digits + #"{1,2})\s*[-/.]\s*("# + digits + "{1,4})" + end) { match, value in
            let a = value(1), b = value(2), c = value(3)
            var parts: [(Int, Int, Int)] = []
            if a.count == 4 || contains(#"\bYY\s*[/.-]\s*MM\s*[/.-]\s*DD\b"#, text) { parts = [(year(a), integer(b), integer(c))] }
            else if c.count == 4 || c.count == 2 { parts = [(year(c), integer(b), integer(a)), (year(c), integer(a), integer(b))] }
            let corrected = [a, b, c].contains { Int($0) == nil }
            if [a, b, c].joined().rangeOfCharacter(from: .decimalDigits) == nil { parts = [] }
            return Token(range: match.range, dates: parts.compactMap { day($0.0, $0.1, $0.2) }, needsLabel: corrected, corrected: corrected)
        }
        scan(start + #"(\d{4}|\d{1,2})\s+(\d{1,2})\s+(\d{4}|\d{1,2})"# + end) { match, value in
            let parts = value(1).count == 4 ? [(integer(value(1)), integer(value(2)), integer(value(3)))] : [(year(value(3)), integer(value(2)), integer(value(1))), (year(value(3)), integer(value(1)), integer(value(2)))]
            return Token(range: match.range, dates: parts.compactMap { day($0.0, $0.1, $0.2) }, needsLabel: true)
        }
        let months = "(" + monthPattern + ")"
        scan(start + #"(\d{4})[\s./\-]*"# + months + #"[\s,./\-]*(\d{1,2})"# + end) { match, value in
            Token(range: match.range, dates: [day(integer(value(1)), monthNumber(value(2)), integer(value(3)))].compactMap { $0 })
        }
        scan(start + #"(\d{1,2})[\s./\-]*"# + months + #"[\s,./\-]*(\d{4}|\d{2})"# + end) { match, value in
            Token(range: match.range, dates: [day(year(value(3)), monthNumber(value(2)), integer(value(1)))].compactMap { $0 })
        }
        scan(start + months + #"[\s./\-]+(\d{1,2})[\s,./\-]+(\d{4}|\d{2})"# + end) { match, value in
            Token(range: match.range, dates: [day(year(value(3)), monthNumber(value(1)), integer(value(2)))].compactMap { $0 })
        }
        scan(start + #"(\d{4})[\s/.\-]+(\d{1,2})"# + end) { match, value in
            Token(range: match.range, months: [month(integer(value(1)), integer(value(2)))].compactMap { $0 })
        }
        scan(start + #"(\d{1,2})[\s/.\-]+(\d{4}|\d{2})"# + end) { match, value in
            Token(range: match.range, months: [month(year(value(2)), integer(value(1)))].compactMap { $0 }, needsLabel: value(2).count == 2)
        }
        scan(start + months + #"[\s./\-]*(\d{4}|\d{2})"# + end) { match, value in
            Token(range: match.range, months: [month(year(value(2)), monthNumber(value(1)))].compactMap { $0 }, needsLabel: value(2).count == 2)
        }
        scan(start + #"(\d{4})[\s./\-]*"# + months + end) { match, value in
            Token(range: match.range, months: [month(integer(value(1)), monthNumber(value(2)))].compactMap { $0 })
        }
        scan(start + #"(\d{8}|\d{6}|\d{4})"# + end) { match, value in
            let raw = value(1)
            func part(_ start: Int, _ count: Int) -> String { String(raw.dropFirst(start).prefix(count)) }
            var dates: [String] = [], partial: [MonthCandidate] = []
            if raw.count == 8 {
                dates = [day(integer(part(0, 4)), integer(part(4, 2)), integer(part(6, 2))), day(integer(part(4, 4)), integer(part(2, 2)), integer(part(0, 2))), day(integer(part(4, 4)), integer(part(0, 2)), integer(part(2, 2)))].compactMap { $0 }
            } else if raw.count == 6 {
                dates = [day(year(part(4, 2)), integer(part(2, 2)), integer(part(0, 2))), day(year(part(4, 2)), integer(part(0, 2)), integer(part(2, 2))), day(year(part(0, 2)), integer(part(2, 2)), integer(part(4, 2)))].compactMap { $0 }
                partial = [month(integer(part(0, 4)), integer(part(4, 2))), month(integer(part(2, 4)), integer(part(0, 2)))].compactMap { $0 }
            } else { partial = [month(year(part(2, 2)), integer(part(0, 2)))].compactMap { $0 } }
            return Token(range: match.range, dates: dates, months: partial, needsLabel: true)
        }
        return found.sorted { $0.range.location < $1.range.location }
    }

    private static func entries(_ text: String) -> [Entry] {
        var found: [Entry] = [], previousHeading = ""
        for line in text.components(separatedBy: .newlines) where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            let source = line as NSString
            let tokens = tokens(line)
            var end = 0
            for (index, original) in tokens.enumerated() {
                var token = original
                token.reviewOnly = contains(#"\bsell\s*by\b"#, line)
                let prefix = source.substring(with: NSRange(location: end, length: token.range.location - end))
                var label = kind(prefix)
                if label == .unknown && end == 0 && prefix.trimmingCharacters(in: .whitespaces.union(.punctuationCharacters)).isEmpty { label = kind(previousHeading) }
                if label == .unknown && index == tokens.count - 1 { label = kind(source.substring(from: NSMaxRange(token.range))) }
                found.append(Entry(kind: label, token: token))
                end = NSMaxRange(token.range)
            }
            previousHeading = tokens.isEmpty ? line : ""
        }
        return found
    }
    private static func build(_ entries: [Entry], hasExpiry: Bool) -> Reading {
        let eligible = entries.filter { (hasExpiry ? $0.kind == .expiry : $0.kind == .unknown) && (!$0.token.needsLabel || $0.kind == .expiry) }
        return Reading(candidates: Array(Set(eligible.flatMap { $0.token.dates })).sorted(),
                       months: Array(Set(eligible.flatMap { $0.token.months })).sorted { $0.yearMonth < $1.yearMonth },
                       requiresReview: eligible.contains { ($0.token.corrected || $0.token.reviewOnly) && (!$0.token.dates.isEmpty || !$0.token.months.isEmpty) })
    }
    public static func candidates(in text: String) -> [String] { Array(Set(tokens(normalized(text)).flatMap(\.dates))).sorted() }
    static func hasDateExpression(in text: String) -> Bool {
        tokens(normalized(text)).contains { !$0.dates.isEmpty || !$0.months.isEmpty }
    }
    public static func reading(in text: String) -> Reading {
        let text = normalized(text)
        let entries = entries(text)
        return build(entries, hasExpiry: entries.contains { $0.kind == .expiry || $0.kind == .mixed } || contains(expiryPattern, text))
    }

    /// Associate date values with label-only observations on the same printed row,
    /// independent of Vision's observation ordering. Conflicting labels fail closed.
    static func reading(lines: [ProductTextLine]) -> Reading {
        let lines = lines.filter { [$0.x, $0.y, $0.width, $0.height, $0.confidence].allSatisfy(\.isFinite) }
        let labels = lines.filter { tokens(normalized($0.text)).isEmpty && kind($0.text) != .unknown }
        var canonical: [String] = [], lowConfidence: [String] = []
        for line in lines {
            let text = normalized(line.text)
            guard !tokens(text).isEmpty else { continue }
            var label = kind(text)
            var confidence = line.confidence
            if label == .unknown && line.height > 0 {
                let neighbors = labels.compactMap { other -> (ProductTextLine, Double)? in
                    let vertical = abs((line.y + line.height / 2) - (other.y + other.height / 2))
                    let horizontal = max(0, max(line.x, other.x) - min(line.x + line.width, other.x + other.width))
                    guard other.height > 0 else { return nil }
                    let sameRow = vertical <= max(line.height, other.height) * 0.65 && horizontal <= 0.55
                    let overlap = min(line.x + line.width, other.x + other.width) - max(line.x, other.x)
                    let gapAbove = other.y - (line.y + line.height)
                    let above = overlap > 0 && gapAbove >= 0 && gapAbove <= max(line.height, other.height) * 1.8
                    guard sameRow || above else { return nil }
                    return (other, sameRow ? vertical * 4 + horizontal * 0.1 : 0.1 + gapAbove * 4)
                }.sorted { $0.1 < $1.1 }
                if let best = neighbors.first {
                    label = kind(best.0.text)
                    if neighbors.dropFirst().contains(where: { abs($0.1 - best.1) < 0.01 && kind($0.0.text) != label }) { label = .mixed }
                    confidence = min(confidence, best.0.confidence)
                }
            }
            let prefix = label == .expiry ? "EXP " : (label == .production ? "MFG " : (label == .mixed ? "MFG EXP " : ""))
            let value = prefix + text
            canonical.append(value)
            if confidence < 0.65 { lowConfidence.append(value) }
        }
        let text = canonical.joined(separator: "\n")
        let entries = entries(text)
        var result = build(entries, hasExpiry: labels.contains { kind($0.text) == .expiry || kind($0.text) == .mixed } || entries.contains { $0.kind == .expiry || $0.kind == .mixed })
        if lowConfidence.contains(where: { text in
            let value = reading(in: text)
            return !Set(value.candidates).isDisjoint(with: result.candidates) || !Set(value.months).isDisjoint(with: result.months)
        }) { result.requiresReview = true }
        return result
    }
}
