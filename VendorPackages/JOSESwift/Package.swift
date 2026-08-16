// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "JOSESwift",
    platforms: [.iOS(.v10), .macOS(.v10_15)],
    products: [
        // The app target links this vendored package but does not embed a
        // dynamic JOSESwift framework in archives. Link it statically so the
        // installed app has no unresolved @rpath dependency at launch.
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
