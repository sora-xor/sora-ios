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
            sources: [
                "FireMock/FireMockDataSource.swift",
                "FireMock/FireMockDebug.swift",
                "FireMock/FireMockGenericDataSource.swift",
                "FireMock/FireMockManager.swift",
                "FireMock/FireMockProtocol.swift",
                "FireMock/FireMockResources.swift",
                "FireMock/FireMockSelectionTableViewCell.swift",
                "FireMock/FireMockSelectionTableViewController.swift",
                "FireMock/FireMockTableViewCell.swift",
                "FireMock/FireMockTableViewHeaderCell.swift",
                "FireMock/FireMockViewController.swift",
                "FireMock/FireURLProtocol.swift",
                "FireMock/UIKitExport.swift",
                "FireMock/URLSessionConfigurationExtension.swift",
                "FireMock/Utils.swift"
            ],
            resources: [
                .process("FireMock.xcassets"),
                .process("FireMock/FireMockSelectionTableViewCell.xib"),
                .process("FireMock/FireMockSelectionTableViewController.xib"),
                .process("FireMock/FireMockTableViewCell.xib"),
                .process("FireMock/FireMockTableViewHeaderCell.xib"),
                .process("FireMock/FireMockViewController.xib")
            ]
        )
    ]
)
