import Foundation

/// Main-thread confined; consumes callback before invocation to prevent re-entry.
public final class OneShot<Value> {
    private var callback: ((Value) -> Void)?
    public init(_ callback: @escaping (Value) -> Void) { self.callback = callback }
    public func finish(_ value: Value) {
        let pending = callback
        callback = nil
        pending?(value)
    }
}
