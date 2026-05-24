// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PayWingsOAuthSDK",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "PayWingsOAuthSDK", targets: ["PayWingsOAuthSDK"])
    ],
    targets: [
        .binaryTarget(
            name: "PayWingsOAuthSDK",
            path: "PayWingsOAuthSDK.xcframework"
        )
    ]
)
