// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SoraWalletBinary",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "SoraWalletBinary", targets: ["SoraWalletBinary"])
    ],
    targets: [
        .binaryTarget(name: "SoraWalletBinary", path: "Binaries/sorawallet.xcframework")
    ]
)
