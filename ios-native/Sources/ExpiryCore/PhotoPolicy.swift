import Foundation
#if canImport(ImageIO)
import ImageIO
#endif

/// Shared metadata-only bounds; never multiply untrusted integer dimensions.
public enum PhotoPolicy {
    public static let maximumEdge = 4096
    public static let maximumPixels = 16_000_000

    public static func validDimensions(width: Double, height: Double) -> Bool {
        width.isFinite && height.isFinite && width > 0 && height > 0 &&
        width.rounded(.down) == width && height.rounded(.down) == height &&
        width <= Double(maximumEdge) && height <= Double(maximumEdge) &&
        width * height <= Double(maximumPixels)
    }

    #if canImport(ImageIO)
    /// Inspect container/header metadata only, with decoded-image caching disabled.
    /// Linux intentionally has no permissive runtime replacement for this API.
    public static func validatedSource(_ data: Data) -> CGImageSource? {
        guard !data.isEmpty, data.count <= LocalRepository.maximumPhotoBytes,
              let source = CGImageSourceCreateWithData(data as CFData,
                  [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetStatus(source) == .statusComplete,
              CGImageSourceGetCount(source) == 1,
              CGImageSourceGetStatusAtIndex(source, 0) == .statusComplete,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0,
                  [kCGImageSourceShouldCache: false] as CFDictionary) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber,
              validDimensions(width: width.doubleValue, height: height.doubleValue) else { return nil }
        return source
    }

    /// Decode only a bounded, upright thumbnail, never UIImage(data:) or a full image.
    public static func thumbnail(_ data: Data, maximumPixelSize: Int = 2048) -> CGImage? {
        guard maximumPixelSize > 0, let source = validatedSource(data) else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: min(maximumPixelSize, 2048),
            kCGImageSourceShouldCacheImmediately: true
        ] as CFDictionary)
    }
    #endif
}
