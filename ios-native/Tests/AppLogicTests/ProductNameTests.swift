import XCTest
@testable import ExpiryTracker

final class ProductNameTests: XCTestCase {
    private func line(_ text: String, height: Double = 0.08, confidence: Double = 0.98, y: Double = 0.6) -> ProductTextLine {
        ProductTextLine(text: text, confidence: confidence, x: 0.1, y: y, width: 0.7, height: height)
    }

    func testProminentNameCanFillAnEmptyDraft() {
        let reading = ProductNameSuggestions.reading(lines: [line("ACME", height: 0.03, y: 0.8), line("Fresh Whole Milk"), line("1 L"), line("EXP 2027-12-31")])
        XCTAssertEqual(reading.automaticName, "Fresh Whole Milk")
        var draft = ProductNameDraft("")
        XCTAssertTrue(draft.fill(from: reading, startedAt: draft.revision))
        XCTAssertEqual(draft.value, "Fresh Whole Milk")
        XCTAssertTrue(draft.isFromPhoto)
    }

    func testBrandAndProductAreSuggestedWithoutPretendingGeometryEstablishesIdentity() {
        let reading = ProductNameSuggestions.reading(lines: [line("ACME", height: 0.04, y: 0.71), line("Fresh Whole Milk", height: 0.08, y: 0.6)])
        XCTAssertEqual(reading.candidates, ["Fresh Whole Milk", "ACME Fresh Whole Milk", "ACME"])
        XCTAssertEqual(reading.automaticName, "Fresh Whole Milk")
    }

    func testMetadataMeasurementsDatesAndNutritionAreNotNames() {
        for text in ["EXP 2027-12-31", "31 DEC 2027", "MFG 01/01/27", "Nutrition facts", "Ingredients: milk", "Protein 3g", "Keep refrigerated", "Batch ABC123", "500 ml", "1 litre", "NET 500 ml", "www.example.com", "100% natural", "Sodium 10mg", "انتهاء الصلاحية", "الوزن الصافي ٥٠٠ جم"] {
            XCTAssertTrue(ProductNameSuggestions.reading(lines: [line(text)]).candidates.isEmpty, text)
        }
    }

    func testAmbiguousLowConfidenceTinyAndSingleWordLabelsRequireAChoice() {
        for lines in [[line("Whole Milk"), line("Chocolate Milk")], [line("Whole Milk", confidence: 0.5)], [line("Whole Milk", height: 0.01)], [line("ALMARAI")]] {
            let reading = ProductNameSuggestions.reading(lines: lines)
            XCTAssertFalse(reading.candidates.isEmpty)
            XCTAssertNil(reading.automaticName)
        }
    }

    func testArabicUnicodeDeduplicationAndPlainTextFallback() {
        let reading = ProductNameSuggestions.reading(text: "  حليب   طازج  \nحليب طازج\nFresh Milk®\nFRESH MILK\n1 L")
        XCTAssertEqual(reading.candidates, ["حليب طازج", "Fresh Milk"])
        XCTAssertNil(reading.automaticName, "Plain text has no geometry/confidence, so it is suggestion-only")
        XCTAssertEqual(ProductNameSuggestions.reading(lines: [line("حليب طازج")]).automaticName, "حليب طازج")
    }

    func testInvalidGeometryAndUnreadableTextAreIgnored() {
        let lines = [line("Whole Milk", height: .nan), line("Whole Milk", confidence: .infinity), line("W?o?le Milk"), ProductTextLine(text: "Whole Milk", confidence: 1, x: -1, y: 0.5, width: 0.5, height: 0.1)]
        XCTAssertTrue(ProductNameSuggestions.reading(lines: lines).candidates.isEmpty)
    }

    func testExistingNamesAndEditsDuringRecognitionAreNeverOverwritten() {
        let reading = ProductNameSuggestions.reading(lines: [line("Whole Milk")])
        var existing = ProductNameDraft("My product")
        XCTAssertFalse(existing.fill(from: reading, startedAt: 0))
        XCTAssertEqual(existing.value, "My product")
        var edited = ProductNameDraft("")
        let startedAt = edited.revision
        edited.edit("Hand typed")
        edited.edit("")
        XCTAssertFalse(edited.fill(from: reading, startedAt: startedAt), "Clearing a manual edit is still an edit")
        edited.choose("Chosen product")
        XCTAssertEqual(edited.value, "Chosen product")
        XCTAssertTrue(edited.isFromPhoto)
        edited.edit("My revised product")
        XCTAssertFalse(edited.isFromPhoto)
    }

    func testProductScanDoesNotWarnAboutMissingDateAndStillExtractsDatesIfPresent() {
        var state = EditorCaptureState(photo: nil, barcode: "draft")
        state.beginCamera(purpose: .product)
        state.receive(.success(.photo(Data([1]))))
        XCTAssertEqual(state.cameraDidDismiss(), Data([1]))
        XCTAssertNil(state.completeRecognition(.success("Fresh Whole Milk"), productLines: [line("Fresh Whole Milk")]))
        XCTAssertNil(state.warning)
        XCTAssertEqual(state.productNames.automaticName, "Fresh Whole Milk")
        XCTAssertEqual(state.completeRecognition(.success("Fresh Whole Milk\nEXP 2027-12-31"), productLines: [line("Fresh Whole Milk"), line("EXP 2027-12-31")]), "2027-12-31")
        XCTAssertEqual(state.barcode, "draft")
        state.removePhoto()
        XCTAssertTrue(state.productNames.candidates.isEmpty)
        XCTAssertNil(state.productNames.automaticName)
    }

    func testUnreadableProductAndFailureKeepManualEntryAvailableAndClearOldSuggestions() {
        var state = EditorCaptureState(photo: nil, barcode: "")
        state.beginCamera(purpose: .product)
        state.receive(.success(.photo(Data([1]))))
        _ = state.cameraDidDismiss()
        state.completeRecognition(.success("500 ml"))
        XCTAssertNotNil(state.warning)
        XCTAssertNil(state.errorMessage)
        state.completeRecognition(.success("Whole Milk"))
        XCTAssertFalse(state.productNames.candidates.isEmpty)
        state.completeRecognition(.failure(CameraFailure.capture))
        XCTAssertTrue(state.productNames.candidates.isEmpty)
        XCTAssertNotNil(state.errorMessage)
        XCTAssertEqual(state.photo, Data([1]))
    }

    func testLateRecognitionCannotPublishNamesForRemovedOrReplacedPhoto() {
        var state = EditorCaptureState(photo: Data([1]), barcode: "")
        var generation = RecognitionGeneration()
        let old = generation.begin()
        state.removePhoto()
        generation.invalidate()
        if generation.finish(old) { state.completeRecognition(.success("Old product name")) }
        XCTAssertTrue(state.productNames.candidates.isEmpty)
        let latest = generation.begin()
        XCTAssertFalse(generation.finish(old))
        XCTAssertTrue(generation.isBusy)
        XCTAssertTrue(generation.finish(latest))
    }
}
