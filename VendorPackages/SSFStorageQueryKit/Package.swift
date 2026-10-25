// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SSFStorageQueryKit",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "SSFStorageQueryKitFixed", targets: ["SSFStorageQueryKitFixed"])
    ],
    dependencies: [
        .package(path: "../shared-features-spm")
    ],
    targets: [
        .target(
            name: "SSFStorageQueryKitFixed",
            dependencies: [
                .product(name: "RobinHood", package: "shared-features-spm"),
                .product(name: "SSFModels", package: "shared-features-spm"),
                .product(name: "SSFRuntimeCodingService", package: "shared-features-spm"),
                .product(name: "SSFUtils", package: "shared-features-spm")
            ],
            path: "Sources/SSFStorageQueryKit",
            exclude: [
                "Classes/.gitkeep",
                "LICENSE",
                "README.md"
            ]
        )
    ]
)
