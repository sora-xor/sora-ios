// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SoraFoundation",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "SoraFoundation", targets: ["SoraFoundation"])
    ],
    dependencies: [
        .package(path: "../shared-features-spm")
    ],
    targets: [
        .target(
            name: "SoraFoundation",
            dependencies: [
                .product(name: "SoraKeystore", package: "shared-features-spm")
            ],
            path: "SoraFoundation/Classes"
        )
    ]
)
