// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "JOSESwift",
    platforms: [.iOS(.v10), .macOS(.v10_15)],
    products: [
        // Keep the vendored package statically linked. The app target does not
        // embed this local dynamic product in archives, leaving an unresolved
        // @rpath/JOSESwift.framework dependency at launch.
        .library(name: "JOSESwift", type: .static, targets: ["JOSESwift"])
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
