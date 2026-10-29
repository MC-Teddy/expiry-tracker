import Foundation

public enum CSVExport {
    public static func encode(rows: [[String]]) -> Data {
        let lines = rows.map { $0.map(cell).joined(separator: ",") }
        return Data((lines.joined(separator: "\r\n") + "\r\n").utf8)
    }
    public static func cell(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let safe = trimmed.first.map { "=+-@".contains($0) } == true ? "'" + value : value
        return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
