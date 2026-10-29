import XCTest
@testable import ExpiryTracker

final class EditorCaptureStateTests: XCTestCase {
    func testReplacementClearsOldFeedbackOnlyAfterDismissAndRemovalKeepsBarcode() {
        var state = EditorCaptureState(photo: Data([1]), barcode: "draft")
        state.completeRecognition(.success("No date"))
        state.beginCamera()
        state.receive(.success(.photo(Data([2]))))
        XCTAssertNotNil(state.warning)
        XCTAssertEqual(state.cameraDidDismiss(), Data([2]))
        XCTAssertNil(state.warning)
        XCTAssertEqual(state.recognizedText, "")
        state.completeRecognition(.success("2027-12-31"))
        XCTAssertEqual(state.suggestions, ["2027-12-31"])
        state.removePhoto()
        XCTAssertNil(state.photo)
        XCTAssertTrue(state.suggestions.isEmpty)
        XCTAssertEqual(state.recognizedText, "")
        XCTAssertEqual(state.barcode, "draft")
    }

    func testOCRFailureKeepsDraftAndAlertUntilAcknowledged() {
        var state = EditorCaptureState(photo: Data([1]), barcode: "draft")
        state.completeRecognition(.failure(CameraFailure.capture))
        XCTAssertNotNil(state.errorMessage)
        XCTAssertEqual(state.photo, Data([1]))
        XCTAssertEqual(state.barcode, "draft")
        XCTAssertNil(state.warning)
        state.beginCamera()
        state.receive(.failure(CameraFailure.cancelled))
        XCTAssertNil(state.cameraDidDismiss())
        XCTAssertNotNil(state.errorMessage, "Cancellation is not alert acknowledgement")
        state.errorMessage = nil // The explicit OK action.
        XCTAssertNil(state.errorMessage)
        XCTAssertEqual(state.photo, Data([1]))
    }

    func testCameraErrorIsStagedAndDoesNotReplaceDraft() {
        var state = EditorCaptureState(photo: Data([1]), barcode: "draft")
        state.beginCamera()
        state.receive(.failure(CameraFailure.capture))
        XCTAssertNil(state.errorMessage)
        XCTAssertNil(state.cameraDidDismiss())
        XCTAssertNotNil(state.errorMessage)
        XCTAssertEqual(state.photo, Data([1]))
        XCTAssertEqual(state.barcode, "draft")
    }

    func testCancellationAndDuplicateResultCannotReplaceDraft() {
        var state = EditorCaptureState(photo: Data([1]), barcode: "draft")
        state.beginCamera()
        state.receive(.failure(CameraFailure.cancelled))
        state.receive(.success(.photo(Data([2]))))
        XCTAssertNil(state.cameraDidDismiss())
        XCTAssertNil(state.errorMessage)
        XCTAssertEqual(state.photo, Data([1]))
        XCTAssertEqual(state.barcode, "draft")
    }

    func testNoDateIsPersistentInlineWarningAndRetainsPhotoDraft() {
        let photo = Data([7])
        var state = EditorCaptureState(photo: photo, barcode: "draft")
        state.completeRecognition(.success("No expiry printed"))
        XCTAssertNotNil(state.warning)
        XCTAssertNil(state.errorMessage, "No date is not a blocking alert")
        XCTAssertEqual(state.photo, photo)
        XCTAssertEqual(state.barcode, "draft")
        XCTAssertEqual(state.recognizedText, "No expiry printed")
        XCTAssertTrue(state.suggestions.isEmpty)
        state.beginCamera()
        state.receive(.failure(CameraFailure.cancelled))
        XCTAssertNil(state.cameraDidDismiss())
        XCTAssertNotNil(state.warning, "Cancelling another scan must not clear manual-entry guidance")
        XCTAssertEqual(state.photo, photo)
    }

    func testPhotoIsStagedUntilCoverDismissesAndConsumedOnce() {
        let original = Data([1]), replacement = Data([2])
        var state = EditorCaptureState(photo: original, barcode: "draft code")
        state.beginCamera()
        state.receive(.success(.photo(replacement)))
        XCTAssertFalse(state.isPresented)
        XCTAssertEqual(state.photo, original, "Draft stays untouched while cover closes")
        XCTAssertNil(state.errorMessage)
        XCTAssertEqual(state.cameraDidDismiss(), replacement)
        XCTAssertEqual(state.photo, replacement)
        XCTAssertEqual(state.barcode, "draft code")
        XCTAssertNil(state.cameraDidDismiss(), "Dismiss callback consumes capture once")
        XCTAssertEqual(state.photo, replacement)
    }
}
