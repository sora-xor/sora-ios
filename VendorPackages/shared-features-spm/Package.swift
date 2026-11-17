// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Modules",
    defaultLocalization: "en",
    platforms: [.iOS(.v14)],
    // SORA links only these products (SoraFoundation, SSFStorageQueryKit and the
    // app's targets). The other SSF* modules, their tests, the mocks basket and
    // the web3-swift, SwiftFormat and SwiftyBeaver requirements they needed were
    // removed on 2026-11-18; see git history.
    products: [
        .library(name: "SSFModels", targets: ["SSFModels"]),
        .library(name: "SSFCrypto", targets: ["SSFCrypto"]),
        .library(name: "SSFUtils", targets: ["SSFUtils"]),
        .library(name: "SSFRuntimeCodingService", targets: ["SSFRuntimeCodingService"]),
        .library(name: "SSFCloudStorage", targets: ["SSFCloudStorage"]),
        .library(name: "IrohaCrypto", targets: ["IrohaCrypto"]),
        .library(name: "keccak", targets: ["keccak"]),
        .library(name: "RobinHood", targets: ["RobinHood"]),
        .library(name: "SoraKeystore", targets: ["SoraKeystore"]),
        .library(name: "SSFSingleValueCache", targets: ["SSFSingleValueCache"])
    ],
    dependencies: [
        .package(url: "https://github.com/Boilertalk/secp256k1.swift.git", exact: "0.1.7"),
        .package(url: "https://github.com/bitmark-inc/tweetnacl-swiftwrap", exact: "1.1.0"),
        .package(url: "https://github.com/ashleymills/Reachability.swift", exact: "5.2.3"),
        .package(path: "../fearless-starscream"),
        .package(path: "../GoogleSignIn-iOS"),
        .package(path: "../google-api-objectivec-client-for-rest"),
        .package(url: "https://github.com/attaswift/BigInt.git", exact: "5.7.0"),
        .package(url: "https://github.com/daisuke-t-jp/xxHash-Swift", exact: "1.1.1")
    ],
    targets: [
        // Crypto primitives built from the vendored sources (see each README.md);
        // they replace prebuilt binaries with the same C API and outputs.
        // Tests/CryptoCompatibility/run.sh checks them against those binaries.
        .target(
            name: "blake2lib",
            exclude: ["README.md", "LICENSE"],
            cSettings: [.headerSearchPath("include/blake2lib")]
        ),
        .target(
            name: "libed25519",
            exclude: ["README.md", "orlp/LICENSE", "iroha/LICENSE", "iroha/ref10/README"],
            cSettings: [.headerSearchPath("iroha/include")]
        ),
        .target(
            name: "sr25519lib",
            exclude: ["README.md", "donna/LICENSE"],
            // The portable constant-time table select, not ed25519-donna's
            // x86-64 inline asm, whose clobber list leaves out xmm15.
            cSettings: [.define("ED25519_NO_INLINE_ASM")]
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
            name: "IrohaCrypto",
            dependencies: [
                .byName(name: "libed25519"),
                .byName(name: "sr25519lib"),
                .byName(name: "blake2lib"),
                .product(name: "secp256k1", package: "secp256k1.swift"),
                "scrypt"
            ],
            publicHeadersPath: "include",
            cSettings: [ .headerSearchPath(".") ]
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
        .target(
            name: "SSFRuntimeCodingService",
            dependencies: [
                "SSFUtils",
                "RobinHood",
                "SSFModels"
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
            name: "SSFSingleValueCache",
            dependencies: ["RobinHood"],
            resources: [.process("CacheDataModel.xcdatamodeld")]
        ),
        .testTarget(
            name: "SSFSingleValueCacheTests",
            dependencies: ["SSFSingleValueCache"]
        ),
        .testTarget(
            name: "SSFCloudStorageTests",
            dependencies: ["SSFCloudStorage"]
        )
    ],
    cLanguageStandard: .gnu11,
    cxxLanguageStandard: .gnucxx14
)
