// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Modules",
    defaultLocalization: "en",
    platforms: [.iOS(.v14)],
    products: [
        .library(name: "SSFXCM", targets: ["SSFXCM"]),
        .library(name: "SSFModels", targets: ["SSFModels"]),
        .library(name: "SSFCrypto", targets: ["SSFCrypto"]),
        .library(name: "SSFUtils", targets: ["SSFUtils"]),
        .library(name: "SSFHelpers", targets: ["SSFHelpers"]),
        .library(name: "SSFNetwork", targets: ["SSFNetwork"]),
        .library(name: "SSFChainRegistry", targets: ["SSFChainRegistry"]),
        .library(name: "SSFLogger", targets: ["SSFLogger"]),
        .library(name: "SSFKeyPair", targets: ["SSFKeyPair"]),
        .library(name: "SSFExtrinsicKit", targets: ["SSFExtrinsicKit"]),
        .library(name: "SSFEraKit", targets: ["SSFEraKit"]),
        .library(name: "SSFRuntimeCodingService", targets: ["SSFRuntimeCodingService"]),
        .library(name: "SSFStorageQueryKit", targets: ["SSFStorageQueryKit"]),
        .library(name: "SSFChainConnection", targets: ["SSFChainConnection"]),
        .library(name: "SSFSigner", targets: ["SSFSigner"]),
        .library(name: "SSFCloudStorage", targets: ["SSFCloudStorage"]),
        .library(name: "SSFAccountManagment", targets: ["SSFAccountManagment"]),
        .library(name: "SSFAccountManagmentStorage", targets: ["SSFAccountManagmentStorage"]),
        .library(name: "SSFAssetManagment", targets: ["SSFAssetManagment"]),
        .library(name: "SSFAssetManagmentStorage", targets: ["SSFAssetManagmentStorage"]),
        .library(name: "IrohaCrypto", targets: ["IrohaCrypto"]),
        .library(name: "keccak", targets: ["keccak"]), //TODO: generate xcframework
        .library(name: "RobinHood", targets: ["RobinHood"]), //TODO: get from github
        .library(name: "SoraKeystore", targets: ["SoraKeystore"]), //TODO: get from github
        .library(name: "SSFQRService", targets: ["SSFQRService"]),
        .library(name: "SSFTransferService", targets: ["SSFTransferService"]),
        .library(name: "SSFSingleValueCache", targets: ["SSFSingleValueCache"]),
        .library(name: "SSFPolkaswap", targets: ["SSFPolkaswap"]),
        .library(name: "SSFPools", targets: ["SSFPools"]),
        .library(name: "SSFPoolsStorage", targets: ["SSFPoolsStorage"]),
        .library(name: "SSFIndexers", targets: ["SSFIndexers"]),
        .library(name: "SSFEtherscanIndexer", targets: ["SSFEtherscanIndexer"]),
        .library(name: "SSFGiantsquidIndexer", targets: ["SSFGiantsquidIndexer"]),
        .library(name: "SSFOklinkIndexer", targets: ["SSFOklinkIndexer"]),
        .library(name: "SSFReefIndexer", targets: ["SSFReefIndexer"]),
        .library(name: "SSFSoraSubsquidIndexer", targets: ["SSFSoraSubsquidIndexer"]),
        .library(name: "SSFSubqueryIndexer", targets: ["SSFSubqueryIndexer"]),
        .library(name: "SSFSubsquidIndexer", targets: ["SSFSubsquidIndexer"]),
        .library(name: "SSFZetaIndexer", targets: ["SSFZetaIndexer"]),
        .library(name: "SSFBalances", targets: ["SSFBalances"]),
        .library(name: "SSFBalancesStorage", targets: ["SSFBalancesStorage"]),
        .library(name: "SSFSubstrateBalances", targets: ["SSFSubstrateBalances"]),
        .library(name: "SSFTransactionHistory", targets: ["SSFTransactionHistory"])
    ],
    dependencies: [
        .package(url: "https://github.com/Boilertalk/secp256k1.swift.git", from: "0.1.7"),
        .package(url: "https://github.com/bitmark-inc/tweetnacl-swiftwrap", from: "1.1.0"),
        .package(url: "https://github.com/ashleymills/Reachability.swift", from: "5.0.0"),
        .package(url: "https://github.com/soramitsu/fearless-starscream", from: "4.0.8"),
        .package(path: "../GoogleSignIn-iOS"),
        .package(path: "../google-api-objectivec-client-for-rest"),
        .package(url: "https://github.com/attaswift/BigInt.git", from: "5.3.0"),
        .package(url: "https://github.com/daisuke-t-jp/xxHash-Swift", from: "1.1.1"),
        .package(url: "https://github.com/SwiftyBeaver/SwiftyBeaver.git", .upToNextMajor(from: "2.0.0")),
        .package(url: "https://github.com/nicklockwood/SwiftFormat", from: "0.50.4"),
        .package(url: "https://github.com/soramitsu/web3-swift", exact: "7.7.7")
    ],
    targets: [
        .binaryTarget(name: "blake2lib", path: "Binaries/blake2lib.xcframework"),
        .binaryTarget(name: "libed25519", path: "Binaries/libed25519.xcframework"),
        .binaryTarget(name: "sr25519lib", path: "Binaries/sr25519lib.xcframework"),
        .binaryTarget(
            name: "Sr25519SafeValidator",
            path: "Binaries/Sr25519SafeValidator.xcframework"
        ),
        .binaryTarget(name: "sorawallet", path: "Binaries/sorawallet.xcframework"),
        .binaryTarget(name: "MPQRCoreSDK", path: "Binaries/MPQRCoreSDK.xcframework"),
        .binaryTarget(
            name: "XNetworking",
            url: "https://github.com/soramitsu/x-networking/releases/download/ios-xcframework-1.0.10-rebuild.1/XNetworking-1.0.10.xcframework.zip",
            checksum: "43319ac6f215e95edc215366116264205902a18d480b87aa4a8c40d381a3b61a"
        ),
        .target(
            name: "scrypt",
            sources: [
                "."
            ],
            cSettings: [
                .headerSearchPath("./include"),
            ]
        ),
        .target(name: "RobinHood"),
        .target(name: "keccak"),
        .target(name: "SoraKeystore"),
        .target(
            name: "SSFBalances",
            dependencies: ["SSFUtils", "SSFStorageQueryKit", "SSFModels", "SSFAccountManagment"]
        ),
        .target(
            name: "SSFBalancesStorage",
            dependencies: ["RobinHood", "SSFBalances", "SSFUtils", "SSFAccountManagment"]
        ),
        .target(
            name: "SSFSubstrateBalances",
            dependencies: [
                "SSFStorageQueryKit",
                "SSFUtils",
                "SSFBalances",
                "SSFChainRegistry",
                "SSFModels",
                "SSFChainConnection"
            ]
        ),
        .target(
            name: "SSFHelpers",
            dependencies: [
                "SSFModels",
                "SSFUtils"
            ]
        ),
        .target(
            name: "SSFKeyPair",
            dependencies: [
                "IrohaCrypto",
                "SSFCrypto"
            ]
        ),
        .target(
            name: "SSFTransactionHistory",
            dependencies: [ "XNetworking", "SSFUtils" ]
        ),
        .testTarget(
            name: "SSFKeyPairTests",
            dependencies: [
                "SSFKeyPair",
                "IrohaCrypto",
                "MocksBasket"
            ]
        ),
        .target(
            name: "SSFModels",
            dependencies: [
                "IrohaCrypto",
                "RobinHood",
                .product(name: "BigInt", package: "BigInt")
            ]
        ),
        .target(
            name: "SSFCrypto",
            dependencies: [
                "IrohaCrypto",
                "SSFUtils",
                "SSFModels",
                "keccak"
            ]
        ),
        .target(
            name: "SSFChainConnection",
            dependencies: [
                .product(name: "Web3", package: "web3-swift"),
                "SSFUtils"
            ]
        ),
        .target(
            name: "SSFSigner",
            dependencies: [
                "IrohaCrypto",
                "SSFCrypto" ]
        ),
        .target(
            name: "SSFQRService",
            dependencies: [
                .byName(name: "MPQRCoreSDK"),
                "SSFCrypto",
                "SSFModels"
            ]),
        .testTarget(
            name: "SSFQRServiceTests",
            dependencies: [
                "SSFQRService",
                "MocksBasket"
            ]
        ),
        .target(
            name: "IrohaCrypto",
            dependencies: [
                .byName(name: "libed25519"),
                .byName(name: "sr25519lib"),
                .byName(name: "Sr25519SafeValidator"),
                .byName(name: "blake2lib"),
                .product(name: "secp256k1", package: "secp256k1.swift"),
                "scrypt"
            ],
            publicHeadersPath: "include",
            cSettings: [ .headerSearchPath(".") ],
            linkerSettings: [
                .linkedFramework("sorawallet")
            ]
        ),
        .target(
            name: "SSFCloudStorage",
            dependencies: [
                .product(name: "TweetNacl", package: "tweetnacl-swiftwrap"),
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS", condition: .when(platforms: [.iOS])),
                .product(name: "GoogleAPIClientForREST_Drive", package: "google-api-objectivec-client-for-rest"),
                "SSFUtils",
                "SSFModels",
                "IrohaCrypto"
            ]
        ),
        .testTarget(
            name: "SSFCloudStorageTests",
            dependencies: [
                "SSFCloudStorage",
                "MocksBasket"
            ]
        ),
        .target(
            name: "SSFRuntimeCodingService",
            dependencies: [
                "SSFUtils",
                "RobinHood",
                "SSFModels"
            ]
        ),
        .target(
            name: "SSFAccountManagment",
            dependencies: [
                "RobinHood",
                "IrohaCrypto",
                "SSFCrypto",
                "SSFKeyPair",
                "SSFAccountManagmentStorage",
                "SSFExtrinsicKit"
            ]
        ),
        .testTarget(
            name: "SSFAccountManagmentTests",
            dependencies: [
                "SSFAccountManagment",
                "SSFModels",
                "SSFHelpers",
                "RobinHood",
                "SSFKeyPair",
                "IrohaCrypto",
                "SoraKeystore",
                "MocksBasket"
            ]
        ),
        .target(
            name: "SSFAccountManagmentStorage",
            dependencies: [
                "RobinHood",
                "IrohaCrypto",
                "SoraKeystore",
                "SSFUtils",
                "SSFModels"
            ]
        ),
        .target(
            name: "SSFAssetManagment",
            dependencies: [
                "RobinHood",
                "IrohaCrypto",
                "SoraKeystore",
                "SSFUtils"
            ]
        ),
        .target(
            name: "SSFAssetManagmentStorage",
            dependencies: [
                "RobinHood",
                "IrohaCrypto",
                "SoraKeystore",
                "SSFUtils",
                "SSFModels"
            ]
        ),
        .testTarget(
            name: "SSFAssetManagmentTests",
            dependencies: [
                "SSFAssetManagment",
                "SSFAssetManagmentStorage",
                "SSFUtils",
                "SSFModels",
                "RobinHood",
                "SSFHelpers",
                "MocksBasket"
            ]
        ),
        .target(
            name: "SSFStorageQueryKit",
            dependencies: [
                "SSFRuntimeCodingService",
                "SSFCrypto",
                "SSFChainConnection",
                "SSFUtils",
                "SSFSingleValueCache",
                "SSFChainRegistry"
            ]
        ),
        .testTarget(
            name: "SSFStorageQueryKitTest",
            dependencies: [
                "SSFStorageQueryKit",
                "MocksBasket",
                "SSFModels"
            ]
        ),
        .target(
            name: "SSFEraKit",
            dependencies: [
                "RobinHood",
                "SSFUtils",
                "BigInt",
                "SSFModels",
                "SSFRuntimeCodingService",
                "SSFStorageQueryKit"
            ]
        ),
        .target(
            name: "SSFExtrinsicKit",
            dependencies: [
                "BigInt",
                "RobinHood",
                "SSFUtils",
                "SSFModels",
                "SSFCrypto",
                "SSFEraKit",
                "IrohaCrypto",
                "SSFSigner",
                "SSFRuntimeCodingService"
            ]
        ),
        .target(
            name: "SSFUtils",
            dependencies: [
                .product(name: "xxHash-Swift", package: "xxHash-Swift"),
                .product(name: "TweetNacl", package: "tweetnacl-swiftwrap"),
                .product(name: "Reachability", package: "Reachability.swift"),
                .product(name: "Starscream", package: "fearless-starscream"),
                "SSFModels",
                "IrohaCrypto",
                "RobinHood",
                "BigInt"
            ]
        ),
        .target(
            name: "SSFChainRegistry",
            dependencies: [
                .product(name: "Web3", package: "web3-swift"),
                "SSFUtils",
                "RobinHood",
                "SSFModels",
                "SSFRuntimeCodingService",
                "SSFChainConnection",
                "SSFNetwork",
                "SSFLogger",
                "SSFAssetManagment",
                "SSFAssetManagmentStorage"
            ]
        ),
        .target(name: "SSFNetwork", dependencies: [ "RobinHood" ]),
        .target(name: "SSFLogger", dependencies: [ "SwiftyBeaver" ]),
        .target(
            name: "SSFXCM",
            dependencies: [
                "SSFUtils",
                "IrohaCrypto",
                "RobinHood",
                "SSFModels",
                "SSFSigner",
                "SSFRuntimeCodingService",
                "SSFStorageQueryKit",
                "SSFChainConnection",
                "SSFExtrinsicKit",
                "SSFNetwork",
                "SSFChainRegistry",
                "SSFAssetManagment",
                "SSFAssetManagmentStorage"
            ]
        ),
        .target(
            name: "SSFPolkaswap",
            dependencies: [
                "SSFUtils",
                "SSFChainRegistry",
                "RobinHood",
                "SSFModels",
                "SSFStorageQueryKit",
                "SSFPools",
                "sorawallet",
                "SSFPoolsStorage",
                "SSFExtrinsicKit",
                "SSFSigner",
                "SSFEraKit",
                "SoraKeystore",
                "SwiftyBeaver",
                .product(name: "Reachability", package: "Reachability.swift")
            ]
        ),
        .target(
            name: "SSFPools",
            dependencies: [
                "RobinHood",
                "SSFUtils",
                "SSFStorageQueryKit"
            ]
        ),
        .target(
            name: "SSFPoolsStorage",
            dependencies: [
                "SSFUtils",
                "RobinHood",
                "SSFPools"
            ]
        ),

        //Tests targets
        .testTarget(
            name: "SSFXCMTests",
            dependencies: [
                "SSFXCM"
            ]
        ),
        .target(
            name: "SSFSingleValueCache",
            dependencies: ["RobinHood"],
            resources: [.process("CacheDataModel.xcdatamodeld")]
        ),
        .testTarget(
            name: "SSFSingleValueCacheTests",
            dependencies: ["SSFSingleValueCache"]
        ),
        .target(name: "SSFTransferService", dependencies: [
            .product(name: "Web3", package: "web3-swift"),
            .product(name: "Web3ContractABI", package: "web3-swift"),
            "SSFModels",
            "BigInt",
            "SSFUtils",
            "SSFRuntimeCodingService",
            "SSFExtrinsicKit",
            "SSFChainRegistry",
            "SSFChainConnection",
            "SSFNetwork"
        ]),
        .testTarget(
            name: "SSFTransferServiceTests",
            dependencies: [
                .product(name: "Web3", package: "web3-swift"),
                .product(name: "Web3ContractABI", package: "web3-swift"),
                "SSFTransferService",
                "SSFModels",
                "BigInt",
                "SSFUtils",
                "SSFRuntimeCodingService",
                "SSFExtrinsicKit",
                "SSFChainRegistry",
                "SSFChainConnection",
                "SSFNetwork",
                "SSFHelpers"
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "SSFIndexers",
            dependencies: [
                "SSFModels",
                "RobinHood",
                "SSFUtils",
                "SSFChainRegistry"
            ]
        ),
        .testTarget(
            name: "SSFIndexersTests",
            dependencies: [
                "SSFIndexers",
                "SSFModels",
                "RobinHood",
                "SSFUtils",
                "SSFChainRegistry",
                "MocksBasket",
                "SSFNetwork"
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .target(name: "SSFEtherscanIndexer", dependencies: ["SSFIndexers"]),
        .target(name: "SSFGiantsquidIndexer", dependencies: ["SSFIndexers"]),
        .target(name: "SSFOklinkIndexer", dependencies: ["SSFIndexers"]),
        .target(name: "SSFReefIndexer", dependencies: ["SSFIndexers"]),
        .target(name: "SSFSoraSubsquidIndexer", dependencies: ["SSFIndexers"]),
        .target(name: "SSFSubqueryIndexer", dependencies: ["SSFIndexers"]),
        .target(name: "SSFSubsquidIndexer", dependencies: ["SSFIndexers"]),
        .target(name: "SSFZetaIndexer", dependencies: ["SSFIndexers"])
    ],
    cLanguageStandard: .gnu11,
    cxxLanguageStandard: .gnucxx14
)

func mockDeps() -> [Target.Dependency] {
    let deps: [Target.Dependency] = package.products.map { product in
            .byNameItem(name: product.name, condition: nil)
    }
    return deps
}
let mockBasketTarget: Target = .target(
    name: "MocksBasket",
    dependencies: mockDeps(),
    resources: [
        .process("Resources")
    ]
)

package.targets.append(mockBasketTarget)
