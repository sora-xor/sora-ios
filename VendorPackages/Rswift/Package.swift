// swift-tools-version:5.0
import PackageDescription

let package = Package(
  name: "rswift",
  platforms: [
    .macOS(.v10_11)
  ],
  products: [
    .executable(name: "rswift", targets: ["rswift"])
  ],
  dependencies: [
    // Keep the tools-version 5.0 build phase compatible while retaining exact pins.
    .package(url: "https://github.com/kylef/Commander.git", .exact("0.9.2")),
    .package(url: "https://github.com/tomlokhorst/XcodeEdit", .exact("2.8.0"))
  ],
  targets: [
    .target(name: "rswift", dependencies: ["RswiftCore"]),
    .target(name: "RswiftCore", dependencies: ["Commander", "XcodeEdit"]),
    .testTarget(name: "RswiftCoreTests", dependencies: ["RswiftCore"]),
  ]
)
