// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FireMock",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "FireMock", targets: ["FireMock"])
    ],
    targets: [
        .target(
            name: "FireMock",
            path: ".",
            sources: ["FireMock"],
            resources: [
                .process("FireMock.xcassets")
            ]
        )
    ]
)
