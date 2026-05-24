// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PayWingsKycSDK",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "PayWingsKycSDK", targets: ["PayWingsKycSDK"])
    ],
    targets: [
        .binaryTarget(
            name: "PayWingsKycSDK",
            path: "PayWingsKycSDK.xcframework"
        )
    ]
)
