// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SoraUIKit",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "SoraUIKit", targets: ["SoraUIKit"])
    ],
    targets: [
        .target(
            name: "SoraUIKit",
            path: "SoraUIKit/SoraUIKit/Sources",
            exclude: ["Scripts"]
        )
    ]
)
