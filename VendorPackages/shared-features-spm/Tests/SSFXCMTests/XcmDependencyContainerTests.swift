import SSFModels
import SSFRuntimeCodingService
import SSFUtils
import XCTest

@testable import SSFXCM

final class XcmDependencyContainerTests: XCTestCase {
    var service: XcmDependencyContainer?
    var chainRegistry: ChainRegistryProtocolMock?

    override func setUp() {
        super.setUp()

        let chainRegistry = ChainRegistryProtocolMock()
        chainRegistry.getChainForReturnValue = TestData.chainModel
        chainRegistry.getRuntimeProviderChainIdUsedRuntimePathsRuntimeItemReturnValue = TestData
            .runtimeProvider
        chainRegistry.getSubstrateConnectionForReturnValue = TestData.connectionChain

        self.chainRegistry = chainRegistry

        service = XcmDependencyContainer(
            chainRegistry: chainRegistry,
            fromChainData: TestData.fromChainData
        )
    }

    override func tearDown() {
        super.tearDown()
        chainRegistry = nil
        service = nil
    }

    func testPrepareDeps() async throws {
        // act
        let deps = try await service?.prepareDeps()

        // assert
        XCTAssertNotNil(deps)
        XCTAssertEqual(chainRegistry?.getChainForCallsCount, 1)
        XCTAssertEqual(
            chainRegistry?.getRuntimeProviderChainIdUsedRuntimePathsRuntimeItemCallsCount,
            1
        )
        XCTAssertEqual(chainRegistry?.getSubstrateConnectionForCallsCount, 1)
    }
}

extension XcmDependencyContainerTests {
    enum TestData {
        static let fromChainData = XcmAssembly.FromChainData(
            chainId: "1",
            cryptoType: .ed25519,
            chainMetadata: nil,
            accountId: Data(),
            signingWrapperData: .init(
                publicKeyData: Data(),
                secretKeyData: Data()
            ),
            chainType: .substrate
        )

        static let chainModel = ChainModel(
            rank: 0,
            disabled: false,
            chainId: "0",
            paraId: "1001",
            name: "test1",
            tokens: ChainRemoteTokens(type: .config, whitelist: nil, utilityId: nil, tokens: []),
            xcm: XcmChain(
                xcmVersion: .V3,
                destWeightIsPrimitive: true,
                availableAssets: [.init(
                    id: "0",
                    symbol: "0"
                )],
                availableDestinations: [.init(
                    chainId: "0",
                    bridgeParachainId: "2",
                    assets: [.init(
                        id: "1",
                        symbol: "1"
                    )]
                )]
            ),
            nodes: Set([ChainNodeModel(
                url: XcmConfig.shared.tokenLocationsSourceUrl,
                name: "test1",
                apikey: nil
            )]),
            icon: nil,
            iosMinAppVersion: nil,
            properties: ChainProperties(addressPrefix: "0")
        )

        static let runtimeProvider = RuntimeProvider(
            operationQueue: OperationQueue(),
            usedRuntimePaths: [:],
            chainMetadata: RuntimeMetadataItem(
                chain: "0",
                version: 0,
                txVersion: 0,
                metadata: Data()
            ),
            chainTypes: Data()
        )

        static let connectionChain = WebSocketEngine(
            connectionName: "test",
            url: XcmConfig.shared.chainsSourceUrl
        )
    }
}
