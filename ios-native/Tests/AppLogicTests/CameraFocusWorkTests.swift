import XCTest
@testable import ExpiryTracker

private final class LockedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var stored = false
    var value: Bool {
        lock.lock(); defer { lock.unlock() }
        return stored
    }
    func set() {
        lock.lock(); defer { lock.unlock() }
        stored = true
    }
}

final class CameraFocusWorkTests: XCTestCase {
    func testQueuedWorkIsDiscardedWhenCaptureOrPickerSuspendsFocus() throws {
        let gate = CameraFocusWork()
        let token = try XCTUnwrap(gate.currentToken())
        let queue = DispatchQueue(label: "focus-test")
        let release = DispatchSemaphore(value: 0)
        let applied = LockedFlag()
        queue.async { release.wait() }
        queue.async { gate.performIfCurrent(token) { applied.set() } }
        gate.suspend()
        release.signal()
        queue.sync {}
        XCTAssertFalse(applied.value)
        XCTAssertNil(gate.currentToken())
        let resumed = try XCTUnwrap(gate.resume())
        XCTAssertNotEqual(token, resumed)
        XCTAssertFalse(gate.performIfCurrent(token) { XCTFail("Old work must stay invalid after resume") })
        XCTAssertTrue(gate.performIfCurrent(resumed) { applied.set() })
        XCTAssertTrue(applied.value)
    }

    func testPickerSuspensionStillAllowsSessionPreparationButFinishDoesNot() {
        let gate = CameraFocusWork()
        XCTAssertTrue(gate.canPrepareSession)
        gate.suspend()
        XCTAssertTrue(gate.canPrepareSession, "The picker may open while camera discovery is pending")
        XCTAssertNil(gate.currentToken(), "Preparing is not permission to change focus or start capture")
        gate.finish()
        XCTAssertFalse(gate.canPrepareSession)
    }

    func testFinishingIsTerminalAndRejectsLateSetupOrFocus() throws {
        let gate = CameraFocusWork()
        let token = try XCTUnwrap(gate.currentToken())
        gate.finish()
        gate.finish()
        XCTAssertNil(gate.currentToken())
        XCTAssertNil(gate.resume())
        XCTAssertFalse(gate.performIfCurrent(token) { XCTFail("Finished camera cannot configure focus") })
    }
}
