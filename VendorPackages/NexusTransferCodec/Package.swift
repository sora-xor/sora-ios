// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "NexusTransferCodec", platforms: [.iOS(.v16), .macOS(.v12)], products: [.library(name: "NexusTransferCodec", targets: ["NexusTransferCodec"])], targets: [.target(name: "NexusTransferCodec"), .testTarget(name: "NexusTransferCodecTests", dependencies: ["NexusTransferCodec"], resources: [.copy("transfer.json"), .copy("faucet-prepared.json")])])
