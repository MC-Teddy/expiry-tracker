import XCTest
@testable import ExpiryTracker

import ExpiryCore

final class AppLogicTests: XCTestCase {
    func testRepositoryErrorsTellUserWhatToFix() {
        XCTAssertEqual(ErrorExplanation.message(LocalRepositoryError.invalidSettings), "Warning days must be between 0 and 3650, with critical no later than soon.")
        XCTAssertEqual(ErrorExplanation.message(LocalRepositoryError.invalidItem(UUID(), field: "name")), "An item has an invalid name. Check this field and try again.")
        XCTAssertTrue(ErrorExplanation.message(LocalRepositoryError.backupTooLarge).contains("20 MB"))
    }
    func testStorageCalendarIsGregorianAndUsesLocalTimeZone() {
        XCTAssertEqual(DayCodec.calendar.identifier, .gregorian)
        XCTAssertEqual(DayCodec.calendar.timeZone, TimeZone.current)
        XCTAssertEqual(DayCodec.string(DayCodec.date("2028-02-29")!), "2028-02-29")
        XCTAssertNil(DayCodec.date("2027-02-29"))
        XCTAssertNil(DayCodec.date("2027-2-01"))
    }
    func testCSVEncodingProducesUTF8RowsWithCRLFAndQuotedFields() {
        let data = CSVExport.encode(rows: [["name", "notes"], ["Crème", "a, b\nnext"]])
        XCTAssertEqual(String(data: data, encoding: .utf8), "\"name\",\"notes\"\r\n\"Crème\",\"a, b\nnext\"\r\n")
    }
    func testCSVQuotesAndNeutralizesSpreadsheetFormulas() {
        XCTAssertEqual(CSVExport.cell("a,\"b\"\nnext"), "\"a,\"\"b\"\"\nnext\"")
        XCTAssertEqual(CSVExport.cell("=SUM(1)"), "\"'=SUM(1)\"")
    }
    func testOCRAllowsRecognitionSpacingAroundDateSeparators() {
        XCTAssertEqual(DateSuggestions.candidates(in: "EXP 2027 - 12 - 31"), ["2027-12-31"])
    }
    func testOCRDatesRejectImpossibleDaysAndOfferBothRegionalInterpretations() {
        XCTAssertEqual(DateSuggestions.candidates(in: "EXP 2027-02-28; bad 2027-02-30; 03/04/2027"), ["2027-02-28", "2027-03-04", "2027-04-03"])
    }
}
