import XCTest
@testable import ExpiryTracker

final class PrintedDateFormatsTests: XCTestCase {
    func testSellByIsAReviewablePrintedDateAndNotAnAutomaticExpiry() {
        let reading = DateSuggestions.reading(in: "Sell by 2027-12-31")
        XCTAssertEqual(reading.candidates, ["2027-12-31"])
        XCTAssertNil(reading.automaticDate)
        XCTAssertTrue(reading.requiresReview)
    }

    func testShampooPhotoMonthAndYearAreRecognizedWithoutInventingAnAutomaticDay() {
        let reading = DateSuggestions.reading(in: "Batch no.: 15L9JA\nMfg.: 06 / 2025\nExp.: 05 / 2027")
        XCTAssertEqual(reading.months.map(\.yearMonth), ["2027-05"])
        XCTAssertEqual(reading.months.map(\.lastDay), ["2027-05-31"])
        XCTAssertTrue(reading.candidates.isEmpty)
        XCTAssertNil(reading.automaticDate)
    }

    func testDotMatrixPhotoSeparatesPAndEAndRetainsRegionalAmbiguity() {
        let reading = DateSuggestions.reading(in: "P:01/07/2024 #1LU\nE:01/07/2027 14:38")
        XCTAssertEqual(reading.candidates, ["2027-01-07", "2027-07-01"])
        XCTAssertNil(reading.automaticDate)
    }

    func testNumericSeparatorsSpacingSingleDigitsAndTimeSuffixes() {
        for text in ["EXP 2027/12/31", "EXP 31.12.2027", "EXP 12/31/2027", "EXP 31-12-27", "EXP 2027 12 31", "E: 31 12 2027", "EXP20271231", "EXP.2027-12-31", "EXP 31/12/2027.", "EXP 31/12/2027 14:38", "EXP 2027–12–31"] {
            XCTAssertEqual(DateSuggestions.reading(in: text).automaticDate, "2027-12-31", text)
        }
        XCTAssertEqual(DateSuggestions.reading(in: "EXP 2027-1-2").automaticDate, "2027-01-02")
        XCTAssertEqual(DateSuggestions.reading(in: "EXP (YY/MM/DD) 27/12/31").automaticDate, "2027-12-31")
    }

    func testPrintedMonthNamesWithAndWithoutSpacesAndArabicForms() {
        for text in ["EXP31DEC27", "EXP 31-Dec-2027", "USE BEFORE December 31, 2027", "BBE 2027 DEC 31", "EXP 31 ديسمبر 2027", "صالح حتى ٣١ كانون الأول ٢٠٢٧", "EXP ۳۱/۱۲/۲۰۲۷"] {
            XCTAssertEqual(DateSuggestions.reading(in: text).automaticDate, "2027-12-31", text)
        }
        XCTAssertEqual(DateSuggestions.reading(in: "EXP 30 Sept 2027").automaticDate, "2027-09-30")
    }

    func testCommonExpiryHeadingsAndProductionExclusion() {
        for heading in ["EXP", "Expiry date", "Expiration", "Best before", "Best by", "Use by", "Use before", "BB", "BBE", "B.B.E.", "Valid until", "Sell by", "E:"] {
            XCTAssertEqual(DateSuggestions.reading(in: "MFD 2026-12-31\n\(heading) 2027-12-31").candidates, ["2027-12-31"], heading)
        }
        for heading in ["P:", "MFG", "MFD", "Manufactured", "Production", "Packed", "PKD", "تاريخ الإنتاج"] {
            let reading = DateSuggestions.reading(in: "\(heading) 2027-12-31")
            XCTAssertFalse(reading.hasDates, heading)
        }
    }

    func testMonthOnlyFormatsAndLeapYearLastDaysAreReviewOnly() {
        for text in ["EXP 05/2027", "EXP 2027-05", "EXP 05.2027", "EXP 05/27", "BBE MAY27", "EXP May 2027", "EXP0527", "EXP202705", "EXP مايو ٢٠٢٧", "EXP 2027 MAY", "EXP 05 2027", "BBD2027 MAY"] {
            let reading = DateSuggestions.reading(in: text)
            XCTAssertTrue(reading.months.contains { $0.yearMonth == "2027-05" }, text)
            XCTAssertNil(reading.automaticDate, text)
        }
        XCTAssertEqual(DateSuggestions.reading(in: "EXP 02/2028").months.first?.lastDay, "2028-02-29")
        XCTAssertEqual(DateSuggestions.reading(in: "EXP 02/2027").months.first?.lastDay, "2027-02-28")
    }

    func testCompactDatesRequireDateLabelsAndDoNotTurnBatchCodesIntoExpiry() {
        XCTAssertEqual(DateSuggestions.reading(in: "EXP 31052027").automaticDate, "2027-05-31")
        XCTAssertEqual(DateSuggestions.reading(in: "EXP 01072027").candidates, ["2027-01-07", "2027-07-01"])
        XCTAssertNil(DateSuggestions.reading(in: "EXP 311227").automaticDate)
        for text in ["LOT20270531", "LOT 20270531", "20270531", "12M", "24M", "EXP 1448/05/01", "EXP 2027-02-30", "EXP 13/2027", "EXP 2027"] {
            XCTAssertFalse(DateSuggestions.reading(in: text).hasDates, text)
        }
    }

    func testOCRDigitCorrectionsAreLabelBoundAndRequireReview() {
        let reading = DateSuggestions.reading(in: "E: 3I/I2/2O27")
        XCTAssertEqual(reading.candidates, ["2027-12-31"])
        XCTAssertTrue(reading.requiresReview)
        XCTAssertNil(reading.automaticDate)
        XCTAssertFalse(DateSuggestions.reading(in: "3I/I2/2O27").hasDates)
        XCTAssertFalse(DateSuggestions.reading(in: "EXP B/B/BB").hasDates)
    }

    func testSpatialMatchingWorksWhenVisionListsAllLabelsBeforeAllValues() {
        let lines = [
            ProductTextLine(text: "Mfg:", confidence: 0.95, x: 0.1, y: 0.5, width: 0.1, height: 0.025),
            ProductTextLine(text: "Exp:", confidence: 0.95, x: 0.1, y: 0.45, width: 0.1, height: 0.025),
            ProductTextLine(text: "05 / 2027", confidence: 0.95, x: 0.5, y: 0.45, width: 0.2, height: 0.03),
            ProductTextLine(text: "06 / 2025", confidence: 0.95, x: 0.5, y: 0.5, width: 0.2, height: 0.03)
        ]
        XCTAssertEqual(DateSuggestions.reading(lines: lines).months.map(\.yearMonth), ["2027-05"])
        XCTAssertEqual(DateSuggestions.reading(lines: lines.reversed()).months.map(\.yearMonth), ["2027-05"])
    }

    func testUnrelatedLowConfidenceTextDoesNotBlockClearExpiryButDateConfidenceDoes() {
        let expiry = ProductTextLine(text: "E: 31/12/2027", confidence: 0.95, x: 0.2, y: 0.4, width: 0.4, height: 0.02)
        let noise = ProductTextLine(text: "Other label text", confidence: 0.1, x: 0.1, y: 0.8, width: 0.5, height: 0.02)
        XCTAssertEqual(DateSuggestions.reading(lines: [expiry, noise]).automaticDate, "2027-12-31")
        var uncertain = expiry
        uncertain.confidence = 0.4
        XCTAssertNil(DateSuggestions.reading(lines: [uncertain]).automaticDate)
        XCTAssertEqual(DateSuggestions.reading(lines: [uncertain]).candidates, ["2027-12-31"])
    }

    func testStackedLabelsAndConflictingOrDistantLabels() {
        let value = ProductTextLine(text: "31/12/2027", confidence: 0.95, x: 0.4, y: 0.4, width: 0.3, height: 0.03)
        let above = ProductTextLine(text: "EXP", confidence: 0.95, x: 0.4, y: 0.45, width: 0.1, height: 0.03)
        XCTAssertEqual(DateSuggestions.reading(lines: [value, above]).automaticDate, "2027-12-31")
        var distant = above
        distant.y = 0.8
        XCTAssertFalse(DateSuggestions.reading(lines: [value, distant]).hasDates)
        var expiry = above
        expiry.x = 0.1; expiry.y = value.y
        let production = ProductTextLine(text: "MFG", confidence: 0.95, x: expiry.x, y: expiry.y, width: expiry.width, height: expiry.height)
        XCTAssertFalse(DateSuggestions.reading(lines: [value, expiry, production]).hasDates)
    }

    func testMonthSelectionIsExplicitAndInvalidatedWithPhotoRemoval() {
        var state = EditorCaptureState(photo: Data([1]), barcode: "")
        XCTAssertNil(state.completeRecognition(.success("Exp: 05/2027")))
        XCTAssertTrue(state.dateNeedsReview)
        XCTAssertEqual(state.monthSuggestions.count, 1)
        XCTAssertEqual(state.chooseMonth(state.monthSuggestions[0]), "2027-05-31")
        XCTAssertFalse(state.dateNeedsReview)
        XCTAssertEqual(state.selectedMonthExpiry, "2027-05-31")
        state.removePhoto()
        XCTAssertTrue(state.monthSuggestions.isEmpty)
        XCTAssertNil(state.selectedMonthExpiry)
    }

    func testAmbiguousDatesNeedChoiceAndManualDateEntryResolvesReview() {
        var state = EditorCaptureState(photo: nil, barcode: "")
        state.completeRecognition(.success("E:01/07/2027"))
        XCTAssertTrue(state.dateNeedsReview)
        XCTAssertNotNil(state.warning)
        state.clearAutofillFeedback()
        XCTAssertFalse(state.dateNeedsReview)
        XCTAssertNil(state.warning)
    }
}
