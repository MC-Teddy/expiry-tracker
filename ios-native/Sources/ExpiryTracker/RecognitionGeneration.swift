import Foundation

/// A selected photo owns one completion. UI callers serialize on MainActor.
struct RecognitionGeneration {
    private var pending: UUID?
    var isBusy: Bool { pending != nil }

    mutating func begin() -> UUID {
        let token = UUID()
        pending = token
        return token
    }

    mutating func invalidate() { pending = nil }

    /// Consume before publishing success OR failure; stale work cannot clear busy.
    mutating func finish(_ token: UUID) -> Bool {
        guard pending == token else { return false }
        pending = nil
        return true
    }
}
