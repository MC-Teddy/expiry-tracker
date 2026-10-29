#if canImport(SwiftUI)
import SwiftUI

@main
struct ExpiryTrackerApp: App {
    var body: some Scene {
        WindowGroup { NativeWebView().ignoresSafeArea(edges: .bottom) }
    }
}

struct NativeWebView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> WebController { WebController() }
    func updateUIViewController(_ controller: WebController, context: Context) {}
}
#endif
