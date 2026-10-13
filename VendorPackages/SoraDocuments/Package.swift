// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SoraDocuments",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "SoraDocuments", targets: ["SoraDocuments"])
    ],
    targets: [
        .target(
            name: "SoraDocuments",
            path: "SoraDocuments/Classes"
        )
    ]
)
