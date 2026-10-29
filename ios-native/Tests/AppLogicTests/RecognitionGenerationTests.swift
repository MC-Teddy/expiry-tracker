import XCTest
@testable import ExpiryTracker

final class RecognitionGenerationTests: XCTestCase {
    func testDelayedOldCompletionCannotPublishOrClearNewBusyState() async throws {
        var generation = RecognitionGeneration()
        let old = generation.begin()
        let delayed = Task {
            try await Task.sleep(nanoseconds: 10_000_000)
            return old
        }
        let latest = generation.begin()
        var visible = "new photo"
        let stale = try await delayed.value
        if generation.finish(stale) { visible = "old result or failure" }
        XCTAssertEqual(visible, "new photo")
        XCTAssertTrue(generation.isBusy)
        XCTAssertTrue(generation.finish(latest))
        XCTAssertFalse(generation.isBusy)
        XCTAssertFalse(generation.finish(latest), "Completion is one-shot")
    }

    func testRemovalInvalidatesBothSuccessAndFailureAndClearsBusy() {
        var generation = RecognitionGeneration()
        let removed = generation.begin()
        generation.invalidate()
        XCTAssertFalse(generation.isBusy)
        XCTAssertFalse(generation.finish(removed))
        let replacement = generation.begin()
        XCTAssertFalse(generation.finish(removed))
        XCTAssertTrue(generation.isBusy)
        XCTAssertTrue(generation.finish(replacement))
    }
}
