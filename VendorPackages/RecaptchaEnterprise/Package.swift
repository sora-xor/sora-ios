// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RecaptchaEnterprise",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "RecaptchaEnterprise", targets: ["RecaptchaEnterprise"])
    ],
    targets: [
        .binaryTarget(
            name: "RecaptchaEnterprise",
            path: "RecaptchaEnterprise.xcframework"
        )
    ]
)
