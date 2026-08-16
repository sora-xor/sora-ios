// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "JOSESwift",
    platforms: [.iOS(.v10), .macOS(.v10_15)],
    products: [
        // Leave linkage automatic so Xcode can coalesce the package across the
        // app and test targets. It resolves to static linkage in the archive,
        // avoiding the unembedded JOSESwift.framework launch crash.
        .library(name: "JOSESwift", targets: ["JOSESwift"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "JOSESwift",
            path: "JOSESwift",
            swiftSettings: [
                .unsafeFlags(["-enable-library-evolution"])
            ]
        )
    ],
    swiftLanguageVersions: [.v5])
