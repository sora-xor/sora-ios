import BigInt
import SSFChainRegistry
import SSFNetwork
import SSFRuntimeCodingService
import SSFSigner
import SSFUtils
import XCTest

@testable import SSFXCM

final class CallPathDeterminerTests: XCTestCase {
    var determiner: CallPathDeterminer?
    var chainRegistry: ChainRegistryProtocolMock?

    override func setUp() {
        super.setUp()
        let chainRegistry = ChainRegistryProtocolMock()
        let determiner: CallPathDeterminer = CallPathDeterminerImpl(
            chainRegistry: chainRegistry,
            fromChainData: TestData.fromChainData
        )

        self.chainRegistry = chainRegistry
        self.determiner = determiner
    }

    override func tearDown() {
        super.tearDown()
        chainRegistry = nil
        determiner = nil
    }

    func testCallPathDeterminerInit() {
        // arrange
        let chainRegistry = ChainRegistryProtocolMock()

        // act
        let pathDeterminer = CallPathDeterminerImpl(
            chainRegistry: chainRegistry,
            fromChainData: TestData.fromChainData
        )

        // assert
        XCTAssertNotNil(pathDeterminer)
    }

    func testDetermineCallPath() async throws {
        // act
        let callPath = try await determiner?.determineCallPath(
            from: .relaychain,
            dest: .parachain
        )

        // assert
        XCTAssertEqual(callPath, .xcmPalletLimitedReserveTransferAssets)
    }

    func testDetermineCallPathWithFunctionCall() async throws {
        // arrange
        chainRegistry?
            .getReadySnapshotChainIdUsedRuntimePathsRuntimeItemReturnValue =
            try createRuntimeSnapshot()

        // act
        let callPath = try await determiner?.determineCallPath(
            from: .parachain,
            dest: .parachain
        )

        // assert
        XCTAssertEqual(callPath, .polkadotXcmLimitedReserveTransferAssets)
    }

    func testDetermineCallPathWithDirectionError() async throws {
        // act
        do {
            let callPath = try await determiner?.determineCallPath(
                from: .relaychain,
                dest: .relaychain
            )
        } catch {
            // assert
            XCTAssertEqual(
                error.localizedDescription,
                XcmError.directionNotSupported.localizedDescription
            )
        }
    }

    func testDetermineCallPathWithPalletError() async throws {
        // arrange
        chainRegistry?
            .getReadySnapshotChainIdUsedRuntimePathsRuntimeItemReturnValue =
            try createRuntimeSnapshot(with: "")

        // act
        do {
            let callPath = try await determiner?.determineCallPath(
                from: .soraMainnet,
                dest: .relaychain
            )
        } catch {
            // assert
            XCTAssertEqual(
                error.localizedDescription,
                XcmError.noXcmPallet(chainId: TestData.fromChainData.chainId).localizedDescription
            )
        }
    }
}

extension CallPathDeterminerTests {
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
    }

    private func createRuntimeSnapshot(with moduleName: String = "polkadotXcm") throws
        -> RuntimeSnapshot
    {
        let module = RuntimeMetadataV14.ModuleMetadata(
            name: moduleName,
            storage: nil,
            callsIndex: BigUInt(),
            eventsIndex: BigUInt(),
            constants: [],
            errorsIndex: BigUInt(),
            index: 0
        )

        let extrinsic = RuntimeMetadataV1.ExtrinsicMetadata(version: 0, signedExtensions: [])

        let wrappedMetadata = RuntimeMetadataProtocolMock(
            schema: nil,
            modules: [module],
            extrinsic: extrinsic
        )

        let metadata = try RuntimeMetadata(
            wrapping: wrappedMetadata,
            metaReserved: 0,
            version: 0
        )

        let typeRegistry = TypeRegistryProtocolMock()

        let registry = TypeRegistryCatalog(
            baseRegistry: typeRegistry,
            versionedRegistries: [:],
            runtimeMetadataRegistry: typeRegistry,
            typeResolver: CaseInsensitiveResolver()
        )

        let snapshot = RuntimeSnapshot(
            typeRegistryCatalog: registry,
            specVersion: 0,
            txVersion: 0,
            metadata: metadata
        )

        return snapshot
    }
}
