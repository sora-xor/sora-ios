// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "IdensicMobileSDK",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "IdensicMobileSDK", targets: ["IdensicMobileSDK"])
    ],
    targets: [
        .binaryTarget(
            name: "IdensicMobileSDK",
            path: "IdensicMobileSDK.xcframework"
        )
    ]
)
