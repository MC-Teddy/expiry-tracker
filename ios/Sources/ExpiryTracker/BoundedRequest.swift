#if canImport(UIKit)
import Foundation
import NativePolicy

/// One ephemeral, cookie-free session per bounded request. All delegate events
/// are serialized on the main queue. No redirect or HTTP credential challenge
/// is ever followed with the caller's authorization headers.
final class BoundedRequest: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private var session: URLSession?
    private var received = Data()
    private var response: HTTPURLResponse?
    private var failure: Error?
    private var completion: ((Result<[String:Any], Error>) -> Void)?

    init(request: URLRequest, completion: @escaping (Result<[String:Any], Error>) -> Void) {
        self.completion = completion
        super.init()
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.urlCredentialStorage = nil
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 45
        config.timeoutIntervalForResource = 60
        config.httpMaximumConnectionsPerHost = 1
        let session = URLSession(configuration:config, delegate:self, delegateQueue:.main)
        self.session = session
        session.dataTask(with:request).resume()
    }

    func cancel() { session?.invalidateAndCancel() }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        failure = BridgeError.denied
        completionHandler(nil)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            completionHandler(.performDefaultHandling, nil)
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let http = response as? HTTPURLResponse,
              let url = http.url, NativePolicy.allowedURL(url.absoluteString),
              response.expectedContentLength <= Int64(NativePolicy.limit) else {
            failure = BridgeError.denied
            completionHandler(.cancel)
            return
        }
        self.response = http
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard data.count <= NativePolicy.limit - received.count else {
            failure = BridgeError.tooLarge
            dataTask.cancel()
            return
        }
        received.append(data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let callback = completion
        completion = nil
        defer { session.finishTasksAndInvalidate(); self.session = nil }
        do {
            if let error = failure ?? error { throw error }
            guard let response else { throw BridgeError.transport }
            var headers: [String:String] = [:]
            for (key,value) in response.allHeaderFields { headers[String(describing:key)] = String(describing:value) }
            let result = try NativePolicy.response(status:response.statusCode, headers:headers, data:received, error:error)
            callback?(.success(result))
        } catch { callback?(.failure(error)) }
    }
}
#endif
