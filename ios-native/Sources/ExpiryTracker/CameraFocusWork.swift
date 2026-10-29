import Foundation

/// MainActor invalidates pending work immediately; sessionQueue alone writes
/// hardware. The short critical section covers property writes, never acquiring
/// the camera configuration lock or waiting for the capture session.
final class CameraFocusWork: @unchecked Sendable {
    private let lock = NSLock()
    private var token: UUID? = UUID()
    private var finished = false

    var canPrepareSession: Bool {
        lock.lock(); defer { lock.unlock() }
        return !finished
    }

    func currentToken() -> UUID? {
        lock.lock(); defer { lock.unlock() }
        return token
    }

    func suspend() {
        lock.lock(); defer { lock.unlock() }
        token = nil
    }

    @discardableResult func resume() -> UUID? {
        lock.lock(); defer { lock.unlock() }
        guard !finished else { return nil }
        let next = UUID()
        token = next
        return next
    }

    func finish() {
        lock.lock(); defer { lock.unlock() }
        finished = true
        token = nil
    }

    @discardableResult func performIfCurrent(_ request: UUID, _ apply: () -> Void) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard token == request, !finished else { return false }
        apply()
        return true
    }
}
