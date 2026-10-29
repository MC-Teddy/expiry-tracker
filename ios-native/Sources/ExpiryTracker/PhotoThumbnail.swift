#if canImport(UIKit)
import UIKit
import ExpiryCore

@MainActor
enum PhotoThumbnail {
    static func image(_ data: Data, maximumPixelSize: Int = 2048) -> UIImage? {
        guard let thumbnail = PhotoPolicy.thumbnail(data, maximumPixelSize: maximumPixelSize) else { return nil }
        return UIImage(cgImage: thumbnail)
    }
}
#endif
