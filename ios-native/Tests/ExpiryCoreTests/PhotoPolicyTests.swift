import Foundation
import XCTest
@testable import ExpiryCore

final class PhotoPolicyTests: XCTestCase {
    func testAppleImageHeadersAndRepositoryEntryPoints() throws {
        #if canImport(ImageIO)
        // Complete grayscale PNGs with valid CRCs and zlib payloads (1×1 and 8192×1).
        let valid = try XCTUnwrap(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVR4nGNoAAAAggCBd81ytgAAAABJRU5ErkJggg=="))
        XCTAssertNotNil(PhotoPolicy.validatedSource(valid))
        let thumbnail = try XCTUnwrap(PhotoPolicy.thumbnail(valid, maximumPixelSize: 1))
        XCTAssertEqual(thumbnail.width, 1)
        XCTAssertEqual(thumbnail.height, 1)
        let wide = try XCTUnwrap(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAEAAAAAABCAAAAAB7SjSgAAAAG0lEQVR4nO3BAQkAAAACoKY3vR+hpgAAAEDfDdBqAHmgk8B8AAAAAElFTkSuQmCC"))
        XCTAssertNotNil(PhotoPolicy.validatedSource(wide))
        let bounded = try XCTUnwrap(PhotoPolicy.thumbnail(wide, maximumPixelSize: 8192))
        XCTAssertEqual(bounded.width, 2048, "Caller cannot raise the screen thumbnail ceiling")
        XCTAssertLessThanOrEqual(bounded.height, 2048)
        XCTAssertNil(PhotoPolicy.thumbnail(wide, maximumPixelSize: 0))
        let oversizedHeader = try XCTUnwrap(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAIAAAAAABCAAAAABTIH+8AAAAH0lEQVR4nO3BAQkAAAACoKY3vR2BmgIAAAAAAAAAfTchWgDx9SEdIAAAAABJRU5ErkJggg=="))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try LocalRepository(directory: directory)
        let good = TrackerSnapshot(items: [ExpiryItem(name: "Photo", category: "Food", expiry: "2027-01-01", photo: valid)])
        try repository.save(good)
        let file = directory.appendingPathComponent("tracker.json")
        let original = try Data(contentsOf: file)
        for bad in [Data(), Data([0, 1, 2]), Data(valid.prefix(12)), oversizedHeader] {
            XCTAssertNil(PhotoPolicy.validatedSource(bad))
            XCTAssertNil(PhotoPolicy.thumbnail(bad))
            let snapshot = TrackerSnapshot(items: [ExpiryItem(name: "Photo", category: "Food", expiry: "2027-01-01", photo: bad)])
            XCTAssertThrowsError(try repository.save(snapshot))
            XCTAssertEqual(try Data(contentsOf: file), original)
            let encoded = try JSONEncoder().encode(snapshot)
            XCTAssertThrowsError(try repository.importBackup(encoded))
            try encoded.write(to: file)
            XCTAssertThrowsError(try repository.load())
            XCTAssertThrowsError(try repository.save(good), "A malformed stored photo cannot be silently overwritten")
            try original.write(to: file)
        }
        #else
        throw XCTSkip("Requires Apple ImageIO; metadata bounds still run on Linux")
        #endif
    }

    func testMetadataDimensionsRejectCompressedBombsAndMalformedValues() {
        XCTAssertTrue(PhotoPolicy.validDimensions(width: 4096, height: 3906))
        XCTAssertTrue(PhotoPolicy.validDimensions(width: 4000, height: 4000))
        for (width, height) in [(4097.0, 1.0), (4096, 3907), (1, 4097), (0, 1), (-1, 2), (1.5, 2), (.infinity, 2), (.nan, 2), (Double.greatestFiniteMagnitude, 2)] {
            XCTAssertFalse(PhotoPolicy.validDimensions(width: width, height: height), "Accepted \(width) × \(height)")
        }
    }
}
