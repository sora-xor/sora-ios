// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause
import Foundation
import RobinHood
import SSFUtils
import XCTest
@testable import SoraPassport

@MainActor
final class DemeterStorageReadTests: XCTestCase {
    private func runtime() throws -> RuntimeCoderFactory {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let snapshot = try RuntimeSnapshotFactory.makeOwnTypesSnapshot(chainId: PIIndexerClient.soraMainnetGenesis, runtimeMetadataItem: SoraPassport.RuntimeMetadataItem(chain: PIIndexerClient.soraMainnetGenesis, version: 133, txVersion: 131, metadata: Data(contentsOf: root.appendingPathComponent("Fixtures/Modernization/sora2-metadata-spec133.scale")), resolver: nil), ownTypes: Data(contentsOf: root.appendingPathComponent("SoraPassport/Resources/runtime-sora.json")), dataHasher: .twox256)
        return RuntimeCoderFactory(catalog: snapshot.typeRegistryCatalog, specVersion: 133, txVersion: 131, metadata: snapshot.metadata)
    }
    private func coderOperation() throws -> BaseOperation<RuntimeCoderFactoryProtocol> { let op = BaseOperation<RuntimeCoderFactoryProtocol>(); op.result = .success(try runtime()); return op }
    private func run<T>(_ wrapper: CompoundOperationWrapper<T>) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            wrapper.targetOperation.completionBlock = { do { continuation.resume(returning: try XCTUnwrap(wrapper.targetOperation.result).get()) } catch { continuation.resume(throwing: error) } }
            OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: false)
        }
    }
    private func key(_ path: StorageCodingPath, bytes: [Data]) throws -> Data {
        let coder = try runtime(); let entry = try XCTUnwrap(coder.metadata.getStorageMetadata(in: path.moduleName, storageName: path.itemName))
        guard case let .nMap(nmap) = entry.type else { throw DemeterReadFailure.fixture }
        return try StorageKeyFactory().createStorageKey(moduleName: path.moduleName, storageName: path.itemName, keys: bytes, hashers: nmap.hashers)
    }
    private func isolated() throws {
        // The application host does not start its network registry under XCTest.
        // Refuse a contaminated host before executing any operation.
        XCTAssertNil(ChainRegistryFacade.sharedRegistry.getConnection(for: Chain.sora.genesisHash()))
        guard ChainRegistryFacade.sharedRegistry.getConnection(for: Chain.sora.genesisHash()) == nil else { throw DemeterReadFailure.fixture }
    }
    func testPoolReadUsesTheInjectedEngineAndBothMetadataHashers() async throws {
        try isolated(); let engine = DemeterReadEngine(); let factory = DemeterFarmingOperationFactory(engine: engine)
        let pool = WalletAssetId.val.rawValue, reward = WalletAssetId.pswap.rawValue
        let expected = try key(.demeterFarmingPools, bytes: [Data(hexStringSSF: pool), Data(hexStringSSF: reward)])
        let wrapper = try factory.poolsOperation(poolAssetId: pool, rewardAssetId: reward, runtimeOperation: coderOperation())
        let result = try await run(wrapper)
        XCTAssertTrue(result.isEmpty); XCTAssertEqual(engine.keys, [expected.toHex(includePrefix: true)])
    }
    func testUserFarmReadUsesTheInjectedEngineAndExactAccountKey() async throws {
        try isolated(); let engine = DemeterReadEngine(); let factory = DemeterFarmingOperationFactory(engine: engine); let id = Data(repeating: 9, count: 32)
        let expected = try key(.demeterFarmingUserInfo, bytes: [id]); let wrapper = try factory.userInfo(accountId: id, runtimeOperation: coderOperation())
        let result = try await run(wrapper); XCTAssertTrue(result.isEmpty); XCTAssertEqual(engine.keys, [expected.toHex(includePrefix: true)])
    }
    func testTokenInfoReadUsesTheInjectedEngineAndExactAssetKey() async throws {
        try isolated(); let engine = DemeterReadEngine(); engine.returnMissing = true
        let factory = DemeterFarmingOperationFactory(engine: engine), asset = WalletAssetId.val.rawValue
        let expected = try key(.demeterFarmingTokenInfo, bytes: [Data(hexStringSSF: asset)])
        let wrapper = try factory.tokenInfos(assetId: asset, runtimeOperation: coderOperation())
        let result = try await run(wrapper); XCTAssertNil(result); XCTAssertEqual(engine.keys, [expected.toHex(includePrefix: true)])
    }
    func testPoolEnumerationUsesItsPalletPrefixAndBoundedPageSize() async throws {
        let engine = DemeterReadEngine(); let op = try DemeterFarmingOperationFactory(engine: engine).poolsKeysPagedOperation()
        let result = try await run(CompoundOperationWrapper(targetOperation: op)); XCTAssertEqual(result, [])
        XCTAssertEqual(engine.methods, [SoraPassport.RPCMethod.getStorageKeysPaged]); XCTAssertEqual(engine.parameters.first?.first as? String, try StorageKeyFactory().createStorageKey(moduleName: "DemeterFarmingPlatform", storageName: "Pools").toHex(includePrefix: true)); XCTAssertEqual(engine.parameters.first?[1] as? Int, 100)
    }
    func testTokenEnumerationUsesItsOwnPalletPrefixAndBoundedPageSize() async throws {
        let engine = DemeterReadEngine(); let op = try DemeterFarmingOperationFactory(engine: engine).tokenInfosKeysPagedOperation()
        let result = try await run(CompoundOperationWrapper(targetOperation: op)); XCTAssertEqual(result, [])
        XCTAssertEqual(engine.methods, [SoraPassport.RPCMethod.getStorageKeysPaged]); XCTAssertEqual(engine.parameters.first?.first as? String, try StorageKeyFactory().createStorageKey(moduleName: "DemeterFarmingPlatform", storageName: "TokenInfos").toHex(includePrefix: true)); XCTAssertEqual(engine.parameters.first?[1] as? Int, 100)
    }
    func testMetadataFailureNeverQueriesStorage() async throws {
        try isolated(); let engine = DemeterReadEngine(); let op = BaseOperation<RuntimeCoderFactoryProtocol>(); op.result = .failure(DemeterReadFailure.fixture)
        let wrapper = try DemeterFarmingOperationFactory(engine: engine).userInfo(accountId: Data(repeating: 9, count: 32), runtimeOperation: op)
        do { _ = try await run(wrapper); XCTFail("Expected the metadata failure") } catch { XCTAssertTrue(error is DemeterReadFailure) }
        XCTAssertTrue(engine.keys.isEmpty)
    }
}
private enum DemeterReadFailure: Error { case fixture }
private final class DemeterReadEngine: JSONRPCEngine {
    var url: URL?; var pendingEngineRequests: [JSONRPCRequest] { [] }
    var keys: [String] = [], methods: [String] = [], parameters: [[Any]] = []; var returnMissing = false
    func callMethod<P: Codable, T: Decodable>(_ method: String, params: P?, options: JSONRPCOptions, completion closure: ((Result<T, Error>) -> Void)?) throws -> UInt16 {
        let data = try JSONEncoder().encode(params); let params = try JSONSerialization.jsonObject(with: data) as? [Any] ?? []; parameters.append(params); methods.append(method)
        let bytes: Data
        if method == SoraPassport.RPCMethod.getStorageKeysPaged { bytes = Data("[]".utf8) }
        else {
            let queried = params.first as? [String] ?? []; keys += queried
            let changes: [[Any]] = queried.map { [$0, returnMissing ? NSNull() : "0x00"] }
            bytes = try JSONSerialization.data(withJSONObject: [["block": "0x" + String(repeating: "01", count: 32), "changes": changes]])
        }
        let value = try JSONDecoder().decode(T.self, from: bytes)
        DispatchQueue.global().async { closure?(.success(value)) }; return 1
    }
    func subscribe<P: Codable, T: Decodable>(_ method: String, params: P?, updateClosure: @escaping (T) -> Void, failureClosure: @escaping (Error, Bool) -> Void) throws -> UInt16 { XCTFail("Unexpected subscription"); throw DemeterReadFailure.fixture }
    func cancelForIdentifier(_ identifier: UInt16) {}; func generateRequestId() -> UInt16 { 1 }; func addSubscription(_ subscription: JSONRPCSubscribing) {}; func connectIfNeeded() {}; func disconnectIfNeeded() {}; func unsubsribe(_ identifier: UInt16) throws {}
}
