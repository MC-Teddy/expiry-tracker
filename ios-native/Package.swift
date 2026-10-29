// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ExpiryTracker",
    platforms: [.iOS(.v17)],
    products: [.library(name: "ExpiryTracker", targets: ["ExpiryTracker"])],
    targets: [
        .target(name: "ExpiryCore"),
        .target(name: "ExpiryTracker", dependencies: ["ExpiryCore"]),
        .testTarget(name: "ExpiryCoreTests", dependencies: ["ExpiryCore"], exclude: ["run_direct.py", "TDD-EVIDENCE.md", "verification.log"]),
        .testTarget(name: "AppLogicTests", dependencies: ["ExpiryTracker", "ExpiryCore"])
    ],
    swiftLanguageModes: [.v5]
)
