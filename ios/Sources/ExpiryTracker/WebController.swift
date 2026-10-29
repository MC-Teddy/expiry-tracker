#if canImport(UIKit)
import UIKit
import WebKit
import Vision
import ImageIO
import NativePolicy

@MainActor
final class WebController: UIViewController, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
    private var webView: WKWebView!
    private var entry: URL!
    private var cloud = false
    private var generation = 0
    private var pending = Set<String>()
    private var requests: [String:BoundedRequest] = [:]
    private var ocrBusy = false
    private var dialogCancel: (() -> Void)?
    private weak var camera: CameraController?
    private var networkEpoch = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red:0.965, green:0.957, blue:0.933, alpha:1)
        guard let resources = Bundle.module.url(forResource:"Web", withExtension:nil),
              FileManager.default.fileExists(atPath:resources.appendingPathComponent("index.html").path) else {
            showFatal("Bundled screens are missing. Run tools/prepare-ios.py and rebuild.")
            return
        }
        entry = resources.appendingPathComponent("index.html")
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        config.allowsInlineMediaPlayback = true
        // Do not enable universal file access, mixed content, or private KVC flags.
        config.userContentController.add(self, name:"native")
        webView = WKWebView(frame:.zero, configuration:config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = view.backgroundColor
        webView.scrollView.backgroundColor = view.backgroundColor
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo:view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo:view.trailingAnchor),
            webView.topAnchor.constraint(equalTo:view.safeAreaLayoutGuide.topAnchor),
            webView.bottomAnchor.constraint(equalTo:view.bottomAnchor)
        ])
        // Native deny-by-default subresource firewall, in addition to the web CSP.
        // URLSession bridge is not affected by WebKit content rules.
        let rules = #"[{"trigger":{"url-filter":"^[a-zA-Z][a-zA-Z0-9+.-]*://"},"action":{"type":"block"}},{"trigger":{"url-filter":"^file://"},"action":{"type":"ignore-previous-rules"}}]"#
        WKContentRuleListStore.default().compileContentRuleList(forIdentifier:"expiry-bundled-offline-v1", encodedContentRuleList:rules) { [weak self] list,error in
            Task { @MainActor in
                guard let self else { return }
                guard error == nil, let list else { self.showFatal("Unable to enable the offline security policy."); return }
                self.webView.configuration.userContentController.add(list)
                self.webView.loadFileURL(self.entry, allowingReadAccessTo:resources)
            }
        }
        cleanupOldExports()
    }

    private func showFatal(_ text: String) {
        let label = UILabel(frame:view.bounds.insetBy(dx:24, dy:24))
        label.numberOfLines = 0
        label.text = text
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(label)
    }

    private func trusted(_ frame: WKFrameInfo) -> Bool {
        entry != nil && frame.securityOrigin.protocol == "file" &&
        NativePolicy.trustedDocument(frame.request.url, entry:entry, mainFrame:frame.isMainFrame) &&
        NativePolicy.trustedDocument(webView.url, entry:entry, mainFrame:true)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard trusted(message.frameInfo), let body = message.body as? [String:Any],
              let id = body["id"] as? String, !id.isEmpty, id.utf8.count <= 128,
              let action = body["action"] as? String, !pending.contains(id), pending.count < 32 else { return }
        pending.insert(id)
        let epoch = generation
        switch action {
        case "mode":
            guard let mode = body["mode"] as? String, ["local","cloud"].contains(mode) else { reply(id, epoch, error:"Invalid storage mode"); return }
            if cloud != (mode == "cloud") { networkEpoch += 1 }
            cloud = mode == "cloud"
            if !cloud { requests.values.forEach { $0.cancel() } }
            reply(id, epoch, result:["mode":mode])
        case "request":
            Task { @MainActor [weak self] in
                await self?.requestHTTPS(body, id:id, epoch:epoch)
            }
        case "camera": captureCamera(body, id:id, epoch:epoch)
        case "ocr": recognize(body, id:id, epoch:epoch)
        case "export": export(body, id:id, epoch:epoch)
        default: reply(id, epoch, error:"Unsupported native action")
        }
    }

    private func requestHTTPS(_ body: [String:Any], id: String, epoch: Int) async {
        do {
            guard generation == epoch, pending.contains(id), requests.count < 4,
                  NativePolicy.trustedDocument(webView.url, entry:entry, mainFrame:true) else { throw BridgeError.denied }
            // Storage comes from the trusted main document, never the message
            // payload. Missing/invalid/local values cannot activate networking.
            let stored = try await webView.callAsyncJavaScript(
                "return window.localStorage.getItem('expiry_mobile_mode_v1');",
                arguments:[:], in:nil, contentWorld:.page)
            guard generation == epoch, pending.contains(id),
                  NativePolicy.trustedDocument(webView.url, entry:entry, mainFrame:true) else { return }
            let selected = NativePolicy.cloudMode(stored)
            if cloud != selected { networkEpoch += 1 }
            cloud = selected
            if !cloud { requests.values.forEach { $0.cancel() }; throw BridgeError.denied }
            guard requests.count < 4 else { throw BridgeError.tooLarge }
            let request = try NativePolicy.request(body, cloud:cloud)
            let network = networkEpoch
            requests[id] = BoundedRequest(request:request) { [weak self] result in
                Task { @MainActor in
                    guard let self, self.generation == epoch else { return }
                    self.requests.removeValue(forKey:id)
                    guard self.cloud, self.networkEpoch == network else { self.reply(id, epoch, error:"Network request cancelled by storage mode change"); return }
                    switch result {
                    case .success(let value): self.reply(id, epoch, result:value)
                    case .failure: self.reply(id, epoch, error:"HTTPS request failed or was blocked")
                    }
                }
            }
        } catch { reply(id, epoch, error:"Network disabled in local mode, or request rejected by security policy") }
    }

    private func reply(_ id: String, _ epoch: Int, result: Any? = nil, error: String? = nil) {
        guard generation == epoch, pending.remove(id) != nil else { return }
        Task { @MainActor [weak self] in
            guard let self, self.generation == epoch,
                  NativePolicy.trustedDocument(self.webView.url, entry:self.entry, mainFrame:true) else { return }
            _ = try? await self.webView.callAsyncJavaScript(
                "if (typeof window.nativeReply === 'function') window.nativeReply(id, result, error);",
                arguments:["id":id, "result":result ?? NSNull(), "error":error as Any? ?? NSNull()],
                in:nil, contentWorld:.page)
        }
    }

    private func resetDocument() {
        cloud = false
        networkEpoch += 1
        camera?.cancel()
        generation += 1
        pending.removeAll()
        requests.values.forEach { $0.cancel() }
        requests.removeAll()
        dialogCancel?()
        dialogCancel = nil
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard navigationAction.targetFrame?.isMainFrame == true,
              NativePolicy.trustedDocument(navigationAction.request.url, entry:entry, mainFrame:true) else {
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { resetDocument() }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { resetDocument(); webView.reload() }

    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        // Camera access is exclusively through the explicit native capture UI.
        decisionHandler(.deny)
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let once = OneShot<Void> { completionHandler() }
        guard trusted(frame), presentedViewController == nil else { once.finish(()); return }
        let alert = UIAlertController(title:"Expiry Tracker", message:String(message.prefix(4096)), preferredStyle:.alert)
        alert.addAction(UIAlertAction(title:"OK", style:.default) { [weak self] _ in self?.dialogCancel = nil; once.finish(()) })
        dialogCancel = { once.finish(()) }
        present(alert, animated:true)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let once = OneShot(completionHandler)
        guard trusted(frame), presentedViewController == nil else { once.finish(false); return }
        let alert = UIAlertController(title:"Expiry Tracker", message:String(message.prefix(4096)), preferredStyle:.alert)
        alert.addAction(UIAlertAction(title:"Cancel", style:.cancel) { [weak self] _ in self?.dialogCancel = nil; once.finish(false) })
        alert.addAction(UIAlertAction(title:"OK", style:.default) { [weak self] _ in self?.dialogCancel = nil; once.finish(true) })
        dialogCancel = { once.finish(false) }
        present(alert, animated:true)
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        let once = OneShot(completionHandler)
        guard trusted(frame), presentedViewController == nil else { once.finish(nil); return }
        let alert = UIAlertController(title:"Expiry Tracker", message:String(prompt.prefix(4096)), preferredStyle:.alert)
        alert.addTextField { field in field.text = defaultText; field.autocorrectionType = .no }
        alert.addAction(UIAlertAction(title:"Cancel", style:.cancel) { [weak self] _ in self?.dialogCancel = nil; once.finish(nil) })
        alert.addAction(UIAlertAction(title:"OK", style:.default) { [weak self, weak alert] _ in self?.dialogCancel = nil; once.finish(alert?.textFields?.first?.text) })
        dialogCancel = { once.finish(nil) }
        present(alert, animated:true)
    }

    private func captureCamera(_ body: [String:Any], id: String, epoch: Int) {
        guard presentedViewController == nil, let purpose = body["purpose"] as? String,
              NativePolicy.cameraPurpose(purpose) else { reply(id, epoch, error:"Invalid or unavailable camera action"); return }
        let controller = CameraController(purpose:purpose) { [weak self] result in
            switch result {
            case .success(let value): self?.reply(id, epoch, result:value)
            case .failure(let error): self?.reply(id, epoch, error:error.localizedDescription)
            }
        }
        camera = controller
        present(controller, animated:true)
    }

    private func recognize(_ body: [String:Any], id: String, epoch: Int) {
        do {
            guard !ocrBusy, let image = body["image"] as? String, image.utf8.count <= ((NativePolicy.limit + 2) / 3) * 4 + 64,
                  let comma = image.firstIndex(of:","),
                  ["data:image/png;base64", "data:image/jpeg;base64", "data:image/heic;base64", "data:image/heif;base64", "data:image/webp;base64"].contains(String(image[..<comma])) else { throw BridgeError.invalid }
            let data = try NativePolicy.decode(String(image[image.index(after:comma)...]))
            ocrBusy = true
            DispatchQueue.global(qos:.userInitiated).async { [weak self] in
                let result: Result<String,Error> = Result {
                    try autoreleasepool {
                        guard let source = CGImageSourceCreateWithData(data as CFData,nil),
                              let properties = CGImageSourceCopyPropertiesAtIndex(source,0,nil) as? [CFString:Any],
                              let width = properties[kCGImagePropertyPixelWidth] as? Int,
                              let height = properties[kCGImagePropertyPixelHeight] as? Int,
                              width > 0, height > 0, width <= 30000, height <= 30000, width * height <= 40_000_000,
                              let image = CGImageSourceCreateThumbnailAtIndex(source,0,[kCGImageSourceCreateThumbnailFromImageAlways:true, kCGImageSourceCreateThumbnailWithTransform:true, kCGImageSourceThumbnailMaxPixelSize:4096] as CFDictionary) else { throw BridgeError.invalid }
                        let request = VNRecognizeTextRequest()
                        request.recognitionLevel = .accurate
                        request.usesLanguageCorrection = false
                        request.automaticallyDetectsLanguage = true
                        try VNImageRequestHandler(cgImage:image, options:[:]).perform([request])
                        let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                        return String(lines.joined(separator:"\n").prefix(100000))
                    }
                }
                Task { @MainActor in
                    guard let self else { return }
                    self.ocrBusy = false
                    switch result {
                    case .success(let text): self.reply(id, epoch, result:["text":text])
                    case .failure: self.reply(id, epoch, error:"On-device text recognition failed")
                    }
                }
            }
        } catch { reply(id, epoch, error:"Invalid, oversized, or busy OCR image") }
    }

    private var exportRoot: URL { FileManager.default.temporaryDirectory.appendingPathComponent("ExpiryTrackerExports", isDirectory:true) }

    private func cleanupOldExports() {
        // A previous process may have terminated while a sheet was open.
        try? FileManager.default.removeItem(at:exportRoot)
    }

    private func export(_ body: [String:Any], id: String, epoch: Int) {
        var directory: URL?
        do {
            guard presentedViewController == nil,
                  let name = body["name"] as? String, NativePolicy.exportName(name),
                  let encoded = body["data"] as? String else { throw BridgeError.invalid }
            let data = try NativePolicy.decode(encoded)
            let dir = exportRoot.appendingPathComponent(UUID().uuidString, isDirectory:true)
            directory = dir
            try FileManager.default.createDirectory(at:dir, withIntermediateDirectories:true, attributes:[.protectionKey:FileProtectionType.complete])
            var file = dir.appendingPathComponent(name)
            try data.write(to:file, options:[.atomic, .completeFileProtection])
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try file.setResourceValues(values)
            let sheet = UIActivityViewController(activityItems:[file], applicationActivities:nil)
            if let popover = sheet.popoverPresentationController {
                popover.sourceView = view
                popover.sourceRect = CGRect(x:view.bounds.midX,y:view.bounds.midY,width:1,height:1)
                popover.permittedArrowDirections = []
            }
            sheet.completionWithItemsHandler = { [weak self] _, completed, _, error in
                try? FileManager.default.removeItem(at:dir)
                Task { @MainActor in
                    if error != nil { self?.reply(id, epoch, error:"Export failed") }
                    else { self?.reply(id, epoch, result:["completed":completed]) }
                }
            }
            present(sheet, animated:true)
        } catch {
            if let directory { try? FileManager.default.removeItem(at:directory) }
            reply(id, epoch, error:"Invalid, oversized, or unavailable export")
        }
    }
}
#endif
