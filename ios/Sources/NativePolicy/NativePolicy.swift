import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum BridgeError: Error { case denied, invalid, tooLarge, transport }

public enum NativePolicy {
    public static func trustedDocument(_ url: URL?, entry: URL, mainFrame: Bool) -> Bool {
        guard mainFrame, let url, url.isFileURL, url.host == nil || url.host == "", url.query == nil else { return false }
        return url.standardizedFileURL.path == entry.standardizedFileURL.path
    }
    public static func cloudMode(_ storedMode: Any?) -> Bool { storedMode as? String == "cloud" }
    public static func cameraPurpose(_ purpose: String) -> Bool { ["expiry", "barcode"].contains(purpose) }
    public static let limit = 20 * 1024 * 1024
    public static func exportName(_ name: String) -> Bool {
        guard name.utf8.count <= 120, let dot = name.lastIndex(of:"."),
              ["json", "csv"].contains(String(name[name.index(after:dot)...])) else { return false }
        let base = name[..<dot]
        return !base.isEmpty && base.unicodeScalars.allSatisfy { CharacterSet(charactersIn:"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_").contains($0) }
    }
    public static func response(status: Int, headers: [String:String], data: Data, error: Error?) throws -> [String:Any] {
        if error != nil { throw BridgeError.transport }
        guard (100...599).contains(status), data.count <= limit else { throw BridgeError.tooLarge }
        let safe = headers.filter { !["set-cookie", "set-cookie2"].contains($0.key.lowercased()) }
        guard safe.count <= 128, safe.reduce(0, { $0 + $1.key.utf8.count + $1.value.utf8.count }) <= 65536 else { throw BridgeError.tooLarge }
        return ["status":status, "headers":safe, "body":data.base64EncodedString()]
    }
    public static func decode(_ text: String, limit: Int = limit) throws -> Data {
        guard text.utf8.count <= ((limit + 2) / 3) * 4 else { throw BridgeError.tooLarge }
        guard let data = Data(base64Encoded:text), data.count <= limit else { throw BridgeError.invalid }
        return data
    }
    public static func request(_ payload: [String: Any], cloud: Bool) throws -> URLRequest {
        guard cloud, let text = payload["url"] as? String, allowedURL(text), let url = URL(string:text) else { throw BridgeError.denied }
        guard let method = payload["method"] as? String,
              ["GET", "HEAD", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"].contains(method),
              let headers = payload["headers"] as? [String:String], headers.count <= 32 else { throw BridgeError.invalid }
        let allowed: Set<String> = ["authorization", "apikey", "content-type", "accept", "prefer", "range", "range-unit", "x-client-info", "x-supabase-api-version", "x-upsert", "cache-control", "if-match", "if-none-match", "content-profile", "accept-profile"]
        var request = URLRequest(url:url, cachePolicy:.reloadIgnoringLocalCacheData, timeoutInterval:45)
        request.httpMethod = method
        for (name, value) in headers {
            guard allowed.contains(name.lowercased()), value.utf8.count <= 8192,
                  !value.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }) else { throw BridgeError.denied }
            request.setValue(value, forHTTPHeaderField:name)
        }
        if let body = payload["body"] as? String {
            guard method != "GET", method != "HEAD" else { throw BridgeError.invalid }
            request.httpBody = try decode(body)
        } else if let body = payload["body"], !(body is NSNull) { throw BridgeError.invalid }
        request.httpShouldHandleCookies = false
        return request
    }
    public static func allowedURL(_ text: String) -> Bool {
        guard text.utf8.count <= 8192, !text.contains("\\"),
              let c = URLComponents(string: text), c.scheme == "https",
              c.host == "viupqrjyszvvcpnxrmsq.supabase.co",
              c.user == nil, c.password == nil, c.fragment == nil,
              c.port == nil || c.port == 443 else { return false }
        let path = c.percentEncodedPath
        guard !path.contains("%"), !path.contains("//"),
              !path.split(separator: "/").contains(where: { $0 == "." || $0 == ".." }) else { return false }
        return ["/auth/v1/", "/rest/v1/", "/storage/v1/", "/functions/v1/"].contains { path.hasPrefix($0) }
    }
}
