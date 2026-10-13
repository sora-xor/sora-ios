// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SoraUI",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "SoraUI", targets: ["SoraUI"])
    ],
    targets: [
        .target(
            name: "SoraUI",
            path: "SoraUI/Classes"
        )
    ]
)
