// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ExpiryTracker",
    platforms: [.iOS(.v17)],
    products: [.library(name:"ExpiryTracker", targets:["ExpiryTracker"])],
    targets: [
        .target(name:"NativePolicy"),
        .target(name:"ExpiryTracker", dependencies:["NativePolicy"], resources:[.copy("Resources/Web")])
    ],
    swiftLanguageModes: [.v5]
)
