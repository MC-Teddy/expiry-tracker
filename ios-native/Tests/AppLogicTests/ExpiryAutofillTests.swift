import XCTest
@testable import ExpiryTracker

final class ExpiryAutofillTests: XCTestCase {
    func testClearDateFillsDraftAndKeepsPhotoAndBarcode() {
        var state = EditorCaptureState(photo: Data([1]), barcode: "123")
        XCTAssertEqual(state.completeRecognition(.success("EXP 2027-12-31")), "2027-12-31")
        XCTAssertEqual(state.automaticallyFilledDate, "2027-12-31")
        XCTAssertNil(state.warning)
        XCTAssertEqual(state.photo, Data([1]))
        XCTAssertEqual(state.barcode, "123")
    }

    func testExpiryTakesPriorityOverManufacturingOnSameAndSeparateLines() {
        for text in ["MFG 2026-01-15 EXP 2027-12-31", "MFG 2026-01-15\nEXP 2027-12-31", "MFG\n2026-01-15\nEXP\n2027-12-31"] {
            let reading = DateSuggestions.reading(in: text)
            XCTAssertEqual(reading.candidates, ["2027-12-31"], text)
            XCTAssertEqual(reading.automaticDate, "2027-12-31", text)
        }
    }

    func testProductionDateAndIncompleteOrInvalidExpiryNeverFill() {
        for text in ["MFG 2026-01-15", "Packed 15/01/26", "MFG 2026-01-15\nEXP 12/2027", "EXP 2027-02-30", "EXP 12/2027", "MFG / EXP\n2027-12-31", "LOT2027-12-31", "2027-12-31ABC"] {
            XCTAssertTrue(DateSuggestions.reading(in: text).candidates.isEmpty, text)
        }
    }

    func testAmbiguousDatesStayManualAndDuplicateDatesDoNotAddAmbiguity() {
        var state = EditorCaptureState(photo: nil, barcode: "")
        XCTAssertNil(state.completeRecognition(.success("EXP 03/04/2027")))
        XCTAssertEqual(state.suggestions, ["2027-03-04", "2027-04-03"])
        XCTAssertNotNil(state.warning)
        XCTAssertNil(DateSuggestions.reading(in: "2027-12-31\n2028-12-31").automaticDate)
        XCTAssertEqual(DateSuggestions.reading(in: "EXP 2027-12-31\nEXP 2027-12-31").automaticDate, "2027-12-31")
    }

    func testCommonPrintedFormatsAndArabicDigits() {
        for text in ["Best before 31/12/27", "USE BY 31 DEC 2027", "BBE December 31, 2027", "انتهاء الصلاحية ٣١/١٢/٢٠٢٧", "EXP ۲۰۲۷/۱۲/۳۱", "EXP 2027 - 12 - 31"] {
            XCTAssertEqual(DateSuggestions.reading(in: text).automaticDate, "2027-12-31", text)
        }
        XCTAssertEqual(DateSuggestions.reading(in: "EXP 29 FEB 2028").automaticDate, "2028-02-29")
        XCTAssertNil(DateSuggestions.reading(in: "EXP 29 FEB 2027").automaticDate)
        XCTAssertNil(DateSuggestions.reading(in: "EXP 03/04/27").automaticDate)
    }

    func testLowConfidenceOrManualEditDuringScanKeepsCandidatesWithoutFilling() {
        var state = EditorCaptureState(photo: nil, barcode: "")
        XCTAssertNil(state.completeRecognition(.success("EXP 2027-12-31"), allowAutomaticFill: false))
        XCTAssertEqual(state.suggestions, ["2027-12-31"])
        XCTAssertNil(state.automaticallyFilledDate)
        XCTAssertNotNil(state.warning)
    }

    func testReplacementRemovalAndFailedScanClearAutofillFeedback() {
        var state = EditorCaptureState(photo: Data([1]), barcode: "")
        state.completeRecognition(.success("EXP 2027-12-31"))
        state.clearAutofillFeedback()
        XCTAssertNil(state.automaticallyFilledDate)
        state.completeRecognition(.success("EXP 2027-12-31"))
        state.removePhoto()
        XCTAssertNil(state.automaticallyFilledDate)
        XCTAssertTrue(state.suggestions.isEmpty)
        state.completeRecognition(.success("EXP 2027-12-31"))
        XCTAssertNil(state.completeRecognition(.failure(CameraFailure.capture)))
        XCTAssertNil(state.automaticallyFilledDate)
        XCTAssertTrue(state.suggestions.isEmpty)
        XCTAssertNotNil(state.errorMessage)
    }

    func testStaleRecognitionCannotFillDateOrClearLatestBusyState() {
        var generation = RecognitionGeneration()
        var state = EditorCaptureState(photo: nil, barcode: "")
        let old = generation.begin()
        let latest = generation.begin()
        if generation.finish(old) { state.completeRecognition(.success("EXP 2027-12-31")) }
        XCTAssertNil(state.automaticallyFilledDate)
        XCTAssertTrue(generation.isBusy)
        XCTAssertTrue(generation.finish(latest))
        XCTAssertEqual(state.completeRecognition(.success("EXP 2028-12-31")), "2028-12-31")
    }
}
