// swift-tools-version:5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
// SORA vendors only what the app links: the core library and the Drive service
// (Google Drive backups). The other generated services, the service generator
// and the upstream tests were removed on 2026-11-18; see git history for them.
import PackageDescription

let package = Package(
    name: "GoogleAPIClientForREST",
    platforms: [
        .iOS(.v10),
        .macOS(.v10_12),
        .tvOS(.v10),
        .watchOS(.v6)
    ],
    products: [
        // The main library, only thing you need to use your own services.
        .library(
            name: "GoogleAPIClientForRESTCore",
            targets: ["GoogleAPIClientForRESTCore"]
        ),
        .library(
            name: "GoogleAPIClientForREST_Drive",
            targets: ["GoogleAPIClientForREST_Drive"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/google/gtm-session-fetcher.git", exact: "3.5.0"),
    ],
    targets: [
        .target(
            name: "GoogleAPIClientForRESTCore",
            dependencies: [
              .product(name: "GTMSessionFetcherCore", package: "gtm-session-fetcher"),
              .product(name: "GTMSessionFetcherFull", package: "gtm-session-fetcher")
            ],
            path: "Sources/Core",
            resources: [
              .process("Resources/PrivacyInfo.xcprivacy")
            ],
            publicHeadersPath: "Public"
        ),
        .target(
            name: "GoogleAPIClientForREST_Drive",
            dependencies: ["GoogleAPIClientForRESTCore"],
            path: "Sources/GeneratedServices/Drive",
            publicHeadersPath: "Public"
        ),
    ]
)
