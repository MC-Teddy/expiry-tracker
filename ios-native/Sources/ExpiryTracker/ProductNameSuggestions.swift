import Foundation

/// Vision coordinates are normalized with the origin at the bottom-left.
struct ProductTextLine: Equatable, Sendable {
    let text: String
    var confidence: Double = 0
    var x: Double = 0
    var y: Double = 0
    var width: Double = 0
    var height: Double = 0
}

enum ProductNameSuggestions {
    struct Reading: Equatable, Sendable {
        var candidates: [String] = []
        var automaticName: String?
    }
    private struct Ranked {
        let line: ProductTextLine
        let name: String
        var score: Double { line.height * (0.5 + line.confidence * 0.5) }
    }
    // Exclude package metadata and nutrition text; never invent an identity from
    // a barcode or infer a product from an unlabelled object.
    private static let metadata = #"\b(?:exp|expiry|expires|expiration|best\s*(?:before|by)|use\s*by|mfg|mfd|manufactured|production|packed|pkd|batch|lot|barcode|ingredients?|nutrition(?:al)?|calories|energy|protein|carbohydrates?|sugars?|sodium|cholesterol|saturated|serving|storage|store|refrigerat\w*|keep|contact|www|https?|tel|phone|customer|distributed|imported|copyright|made\s+in|net\s*(?:weight|wt|volume))\b|انتهاء|صلاحية|إنتاج|انتاج|المكونات|مكونات|القيمة الغذائية|يحفظ|تخزين|سعرات|بروتين|كربوهيدرات|الوزن الصافي"#
    private static let generic = #"^(?:(?:100\s*%\s*)?(?:new|fresh|natural|organic|premium|original|quality|full\s*fat|low\s*fat|fat\s*free|no\s*date|no\s*expiry\s*printed)|جديد|طبيعي|طازج)$"#

    private static func cleaned(_ text: String) -> String {
        text.replacingOccurrences(of: #"[™®©]"#, with: "", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "|•:;")))
    }
    private static func matches(_ pattern: String, _ text: String) -> Bool {
        text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
    private static func eligible(_ text: String) -> Bool {
        let letters = text.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
        guard (3...80).contains(text.count), letters >= 3,
              text.split(separator: " ").count <= 10,
              !matches(metadata, text), !matches(generic, text),
              !DateSuggestions.hasDateExpression(in: text),
              !matches(#"\d\s*[-/.]\s*\d|[@=<>]|\b\d{6,}\b"#, text),
              !matches(#"^(?:net\s*)?\d+(?:[.,]\d+)?\s*(?:kg|g|mg|ml|l|oz|lb|cl|packs?|pcs|litres?|liters?|grams?|kilograms?|millilitres?|milliliters?|جم|كجم|مل|لتر)\.?$"#, text),
              !text.contains("?") else { return false }
        return true
    }

    static func reading(lines: [ProductTextLine]) -> Reading {
        var seen = Set<String>()
        let ranked = lines.enumerated().compactMap { index, line -> (Int, Ranked)? in
            let name = cleaned(line.text)
            guard line.confidence.isFinite, line.height.isFinite, line.width.isFinite,
                  line.x.isFinite, line.y.isFinite, (0...1).contains(line.confidence),
                  (0...1).contains(line.height), (0...1).contains(line.width),
                  (0...1).contains(line.x), (0...1).contains(line.y),
                  eligible(name), seen.insert(name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))).inserted else { return nil }
            return (index, Ranked(line: line, name: name))
        }.sorted { lhs, rhs in lhs.1.score == rhs.1.score ? lhs.0 < rhs.0 : lhs.1.score > rhs.1.score }.map(\.1)
        guard let first = ranked.first else { return Reading() }
        var candidates = [first.name]
        // Offer an adjacent brand + product line as an option. Combining is
        // deliberately review-only: geometry cannot establish brand identity.
        if ranked.count > 1 {
            let second = ranked[1]
            let overlap = min(first.line.x + first.line.width, second.line.x + second.line.width) - max(first.line.x, second.line.x)
            let upper = first.line.y > second.line.y ? first : second
            let lower = first.line.y > second.line.y ? second : first
            let gap = upper.line.y - (lower.line.y + lower.line.height)
            let combined = upper.name + " " + lower.name
            if first.line.height > 0, second.line.height > 0, overlap > 0,
               (-0.01...0.08).contains(gap), combined.count <= 80 {
                candidates.append(combined)
            }
        }
        candidates.append(contentsOf: ranked.dropFirst().map(\.name))
        let dominant = ranked.count == 1 || first.score >= ranked[1].score * 1.6
        let automatic = first.line.confidence >= 0.85 && first.line.height >= 0.035 &&
            first.name.split(separator: " ").count >= 2 && dominant
        return Reading(candidates: Array(candidates.prefix(3)), automaticName: automatic ? first.name : nil)
    }

    static func reading(text: String) -> Reading {
        reading(lines: text.components(separatedBy: .newlines).map { ProductTextLine(text: $0) })
    }
}

/// The production name field owns user edits and scan ownership, independently
/// of the photo. Removing/replacing a photo never erases an accepted draft name.
struct ProductNameDraft {
    private(set) var value: String
    private(set) var revision = 0
    private(set) var isFromPhoto = false

    init(_ value: String) { self.value = value }
    mutating func edit(_ value: String) { self.value = value; revision += 1; isFromPhoto = false }
    mutating func choose(_ value: String) { edit(value); isFromPhoto = true }
    @discardableResult
    mutating func fill(from reading: ProductNameSuggestions.Reading, startedAt revision: Int) -> Bool {
        guard self.revision == revision, value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let name = reading.automaticName else { return false }
        value = name
        isFromPhoto = true
        return true
    }
}
