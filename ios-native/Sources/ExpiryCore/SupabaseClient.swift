import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct SyncHTTPRequest: Equatable, Sendable {
    public var method: String
    public var url: URL
    public var headers: [String: String]
    public var body: Data?

    public init(method: String, url: URL, headers: [String: String] = [:], body: Data? = nil) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
    }
}

public struct SyncHTTPResponse: Equatable, Sendable {
    public var status: Int
    public var headers: [String: String]
    public var body: Data

    public init(status: Int, headers: [String: String] = [:], body: Data) {
        self.status = status
        self.headers = headers
        self.body = body
    }
}

public protocol SyncTransport: AnyObject {
    func send(_ request: SyncHTTPRequest) async throws -> SyncHTTPResponse
}

public struct ItemWrite: Equatable, Sendable {
    public var record: CloudItemRecord
    public var rejectedColumns: Set<String>

    public init(record: CloudItemRecord, rejectedColumns: Set<String>) {
        self.record = record
        self.rejectedColumns = rejectedColumns
    }
}

public final class SupabaseClient: @unchecked Sendable {
    public let config: SupabaseConfig
    private let transport: SyncTransport

    public init(config: SupabaseConfig = .production, transport: SyncTransport) {
        self.config = config
        self.transport = transport
    }

    public func signIn(email: String, password: String, now: Date = Date()) async throws -> AuthSession {
        let body = try json(["email": email, "password": password])
        let response = try await perform(SyncHTTPRequest(
            method: "POST",
            url: endpoint("/auth/v1/token", query: ["grant_type": "password"]),
            headers: headers(session: nil, json: true),
            body: body
        ))
        let data = try requireOK(response, credentials: true)
        return try CloudCodec.decodeSession(data, fallbackEmail: email, now: now)
    }

    public func refresh(_ session: AuthSession, now: Date = Date()) async throws -> AuthSession {
        let body = try json(["refresh_token": session.refreshToken])
        let response = try await perform(SyncHTTPRequest(
            method: "POST",
            url: endpoint("/auth/v1/token", query: ["grant_type": "refresh_token"]),
            headers: headers(session: nil, json: true),
            body: body
        ))
        let data = try requireOK(response, credentials: true)
        return try CloudCodec.decodeSession(data, fallbackEmail: session.email, now: now)
    }

    public func signOut(_ session: AuthSession) async throws {
        _ = try await perform(SyncHTTPRequest(
            method: "POST",
            url: endpoint("/auth/v1/logout"),
            headers: headers(session: session, json: true),
            body: try json(["scope": "local"])
        ))
    }

    public func fetchItems(userID: UUID, session: AuthSession) async throws -> [CloudItemRecord] {
        var offset = 0
        let page = 1000
        var records: [CloudItemRecord] = []
        while offset <= 50_000 {
            let response = try await perform(SyncHTTPRequest(
                method: "GET",
                url: endpoint("/rest/v1/items", query: [
                    "select": "*",
                    "user_id": "eq.\(userID.uuidString.lowercased())",
                    "order": "expiry.asc",
                    "limit": String(page),
                    "offset": String(offset)
                ]),
                headers: headers(session: session, json: false)
            ))
            let rows = try CloudCodec.decodeItems(try requireOK(response))
            records.append(contentsOf: rows)
            if rows.count < page { break }
            offset += page
        }
        return records
    }

    public func fetchPhotos(userID: UUID, session: AuthSession) async throws -> [UUID: RemotePhotoSet] {
        var offset = 0
        let page = 1000
        var photos: [UUID: RemotePhotoSet] = [:]
        while offset <= 50_000 {
            let body = try json([
                "prefix": userID.uuidString.lowercased() + "/",
                "limit": page,
                "offset": offset,
                "sortBy": ["column": "name", "order": "asc"]
            ] as [String: Any])
            let response = try await perform(SyncHTTPRequest(
                method: "POST",
                url: endpoint("/storage/v1/object/list/\(config.bucket)"),
                headers: headers(session: session, json: true),
                body: body
            ))
            let data = try requireOK(response)
            let listed = (try? JSONSerialization.jsonObject(with: data) as? [Any])?.count ?? 0
            let pagePhotos = try CloudCodec.decodePhotoList(data, userID: userID)
            for (id, set) in pagePhotos {
                var existing = photos[id] ?? RemotePhotoSet()
                if let primary = set.primaryUpdatedAt { existing.primaryUpdatedAt = primary }
                if let full = set.fullUpdatedAt { existing.fullUpdatedAt = full }
                photos[id] = existing
            }
            if listed < page { break }
            offset += page
        }
        return photos
    }

    public func upsert(item: ExpiryItem, userID: UUID, deviceID: UUID, modifiedAt: Date,
                       exists: Bool, rejected: Set<String>, session: AuthSession) async throws -> ItemWrite {
        var rejected = rejected
        var exists = exists
        for _ in 0..<8 {
            do {
                if exists {
                    let response = try await perform(SyncHTTPRequest(
                        method: "PATCH",
                        url: endpoint("/rest/v1/items", query: [
                            "id": "eq.\(item.id.uuidString.lowercased())",
                            "user_id": "eq.\(userID.uuidString.lowercased())"
                        ]),
                        headers: headers(session: session, json: true, prefer: "return=representation"),
                        body: try CloudCodec.updateBody(item: item, modifiedAt: modifiedAt, rejected: rejected)
                    ))
                    let rows = try CloudCodec.decodeItems(try requireOK(response))
                    if rows.isEmpty {
                        exists = false
                        continue
                    }
                    return ItemWrite(record: rows[0], rejectedColumns: rejected)
                }
                let response = try await perform(SyncHTTPRequest(
                    method: "POST",
                    url: endpoint("/rest/v1/items"),
                    headers: headers(session: session, json: true, prefer: "return=representation"),
                    body: try CloudCodec.insertBody(item: item, userID: userID, deviceID: deviceID, modifiedAt: modifiedAt, rejected: rejected)
                ))
                let rows = try CloudCodec.decodeItems(try requireOK(response))
                guard let row = rows.first else { throw CloudError.malformed }
                return ItemWrite(record: row, rejectedColumns: rejected)
            } catch CloudError.conflict {
                exists = true
            } catch CloudError.notFound {
                exists = false
            } catch CloudError.rejectedColumn(let column) {
                rejected.insert(column)
            }
        }
        throw CloudError.server(status: 400, message: "The account could not save this item.")
    }

    public func deleteItem(id: UUID, userID: UUID, session: AuthSession) async throws {
        let response = try await perform(SyncHTTPRequest(
            method: "DELETE",
            url: endpoint("/rest/v1/items", query: [
                "id": "eq.\(id.uuidString.lowercased())",
                "user_id": "eq.\(userID.uuidString.lowercased())"
            ]),
            headers: headers(session: session, json: false, prefer: "return=minimal")
        ))
        if response.status == 404 { return }
        _ = try requireOK(response)
    }

    public func uploadPhoto(userID: UUID, itemID: UUID, data: Data, session: AuthSession) async throws {
        let path = CloudPaths.imagePath(userID: userID, itemID: itemID, full: false)
        let response = try await perform(SyncHTTPRequest(
            method: "POST",
            url: endpoint("/storage/v1/object/\(config.bucket)/\(path)"),
            headers: headers(session: session, json: false, extra: [
                "Content-Type": "image/jpeg",
                "x-upsert": "true"
            ]),
            body: data
        ))
        _ = try requireOK(response)
    }

    public func deletePhotos(userID: UUID, itemID: UUID, session: AuthSession) async throws {
        let prefixes = [
            CloudPaths.imagePath(userID: userID, itemID: itemID, full: false),
            CloudPaths.imagePath(userID: userID, itemID: itemID, full: true)
        ]
        let response = try await perform(SyncHTTPRequest(
            method: "DELETE",
            url: endpoint("/storage/v1/object/\(config.bucket)"),
            headers: headers(session: session, json: true),
            body: try json(["prefixes": prefixes])
        ))
        if response.status == 404 { return }
        _ = try requireOK(response)
    }

    public func downloadPhoto(userID: UUID, itemID: UUID, slot: PhotoSlot, session: AuthSession) async throws -> Data {
        let path = CloudPaths.imagePath(userID: userID, itemID: itemID, full: slot == .full)
        let response = try await perform(SyncHTTPRequest(
            method: "GET",
            url: endpoint("/storage/v1/object/\(config.bucket)/\(path)"),
            headers: headers(session: session, json: false)
        ))
        return try requireOK(response)
    }

    private func perform(_ request: SyncHTTPRequest) async throws -> SyncHTTPResponse {
        do {
            return try await transport.send(request)
        } catch let error as CloudError {
            throw error
        } catch {
            throw CloudError.network
        }
    }

    private func requireOK(_ response: SyncHTTPResponse, credentials: Bool = false) throws -> Data {
        if credentials && !(200..<300).contains(response.status) && CloudCodec.isInvalidCredentials(response.body) {
            throw CloudError.invalidCredentials
        }
        if response.status == 401 { throw CloudError.unauthorized }
        if response.status == 404 { throw CloudError.notFound }
        if response.status == 409 { throw CloudError.conflict }
        if !(200..<300).contains(response.status) {
            if let column = CloudCodec.missingColumn(in: response.body) {
                throw CloudError.rejectedColumn(column)
            }
            throw CloudError.server(status: response.status, message: CloudCodec.serverMessage(response.body) ?? "")
        }
        return response.body
    }

    private func headers(session: AuthSession?, json: Bool, prefer: String? = nil, extra: [String: String] = [:]) -> [String: String] {
        var headers = ["apikey": config.anonKey, "Accept": "application/json"]
        if let session { headers["Authorization"] = "Bearer \(session.accessToken)" }
        if json { headers["Content-Type"] = "application/json" }
        if let prefer { headers["Prefer"] = prefer }
        for (name, value) in extra { headers[name] = value }
        return headers
    }

    private func endpoint(_ path: String, query: [String: String] = [:]) -> URL {
        var components = URLComponents(url: config.baseURL, resolvingAgainstBaseURL: false)!
        components.path = path
        if !query.isEmpty {
            components.queryItems = query.keys.sorted().map { URLQueryItem(name: $0, value: query[$0]) }
        }
        return components.url!
    }

    private func json(_ object: Any) throws -> Data {
        guard JSONSerialization.isValidJSONObject(object) else { throw CloudError.malformed }
        return try JSONSerialization.data(withJSONObject: object)
    }
}

#if canImport(Darwin)
public final class URLSessionTransport: NSObject, SyncTransport, URLSessionTaskDelegate, @unchecked Sendable {
    private let host: String
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 45
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()

    public init(host: String) { self.host = host }

    public func send(_ request: SyncHTTPRequest) async throws -> SyncHTTPResponse {
        guard request.url.host == host, request.url.scheme == "https" else { throw CloudError.network }
        var urlRequest = URLRequest(url: request.url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 45)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        urlRequest.httpShouldHandleCookies = false
        for (field, value) in request.headers { urlRequest.setValue(value, forHTTPHeaderField: field) }
        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else { throw CloudError.malformed }
        var headers: [String: String] = [:]
        for (key, value) in http.allHeaderFields {
            if let name = key as? String, let text = value as? String { headers[name] = text }
        }
        return SyncHTTPResponse(status: http.statusCode, headers: headers, body: data)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                           newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        guard request.url?.host == host else {
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }
}

public extension SupabaseClient {
    static func live(config: SupabaseConfig = .production) -> SupabaseClient {
        SupabaseClient(config: config, transport: URLSessionTransport(host: config.host))
    }
}
#endif
