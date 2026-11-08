// swift-tools-version: 5.9
import PackageDescription

// Indexer and config value types in Swift source (module `sorawallet`). They
// replace the prebuilt Kotlin/Native sorawallet.xcframework, so no closed
// binary is linked. The package keeps its old name so the Xcode project and
// `import sorawallet` stay unchanged.
let package = Package(
    name: "SoraWalletBinary",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "SoraWalletBinary", targets: ["sorawallet"])
    ],
    targets: [
        .target(name: "sorawallet", path: "Sources/sorawallet")
    ]
)
