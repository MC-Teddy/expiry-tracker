import Foundation
import ExpiryCore

public enum ErrorExplanation {
    public static func message(_ error: Error) -> String {
        guard let error = error as? LocalRepositoryError else {
            if error is DecodingError { return "This is not a supported native Expiry Tracker JSON backup, or the file is incomplete." }
            return error.localizedDescription
        }
        switch error {
        case .invalidItem(_, let field): return "An item has an invalid \(field). Check this field and try again."
        case .unsupportedVersion(let version): return "Backup version \(version) is not supported by this app. No data was changed."
        case .duplicateID: return "This backup contains duplicate item identifiers and cannot be restored safely."
        case .invalidSettings: return "Warning days must be between 0 and 3650, with critical no later than soon."
        case .backupTooLarge: return "Local storage and JSON backups are limited to 20 MB, including photos. Remove unneeded photos or items and try again."
        }
    }
}
