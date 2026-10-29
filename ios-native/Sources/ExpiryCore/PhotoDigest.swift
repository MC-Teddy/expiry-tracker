import Foundation

/// Stable fingerprint for photo change detection. Not a cryptographic hash.
public enum PhotoDigest {
    public static func fingerprint(_ data: Data) -> String {
        var high: UInt64 = 14695981039346656037
        var low: UInt64 = 0xcbf29ce484222325
        for byte in data {
            high ^= UInt64(byte)
            high &*= 1099511628211
            low ^= UInt64(byte) &+ 0x9e3779b97f4a7c15
            low &*= 0x100000001b3
        }
        high ^= UInt64(data.count)
        high &*= 1099511628211
        return String(format: "%016llx%016llx", high, low)
    }
}
