// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SCard",
    defaultLocalization: "en",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "SCard", targets: ["SCard"])
    ],
    dependencies: [
        .package(path: "../SoraUIKit"),
        .package(path: "../PayWingsOAuthSDK"),
        .package(path: "../PayWingsKycSDK"),
        .package(path: "../IdensicMobileSDK"),
        .package(path: "../RecaptchaEnterprise"),
        .package(url: "https://github.com/SnapKit/SnapKit.git", exact: "5.7.1"),
        .package(path: "../JOSESwift"),
        .package(url: "https://github.com/google/interop-ios-for-google-sdks.git", "101.0.0" ..< "102.0.0"),
        .package(url: "https://github.com/mac-cain13/R.swift.Library.git", exact: "5.3.0")
    ],
    targets: [
        .target(
            name: "SCard",
            dependencies: [
                "SoraUIKit",
                "SnapKit",
                "PayWingsOAuthSDK",
                "PayWingsKycSDK",
                "IdensicMobileSDK",
                "RecaptchaEnterprise",
                "JOSESwift",
                .product(name: "RecaptchaInterop", package: "interop-ios-for-google-sdks"),
                .product(name: "Rswift", package: "R.swift.Library")
            ],
            path: "SCard",
            resources: [
                .process("Assets"),
                .process("Classes/Localizable")
            ]
        )
    ]
)
