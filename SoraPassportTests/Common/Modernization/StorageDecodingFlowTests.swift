// SPDX-License-Identifier: Apache-2.0
import BigInt
import Foundation
import RobinHood
import SSFUtils
import XCTest
@testable import SoraPassport

final class StorageDecodingFlowTests: XCTestCase {
    private typealias Value = SoraPassport.StringScaleMapper<BigUInt>
    private static let coder: Result<RuntimeCoderFactory, Swift.Error> = Result {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let snapshot = try RuntimeSnapshotFactory.makeOwnTypesSnapshot(chainId: PIIndexerClient.soraMainnetGenesis,
            runtimeMetadataItem: SoraPassport.RuntimeMetadataItem(chain: PIIndexerClient.soraMainnetGenesis, version: 133, txVersion: 131, metadata: Data(contentsOf: root.appendingPathComponent("Fixtures/Modernization/sora2-metadata-spec133.scale")), resolver: nil),
            ownTypes: Data(contentsOf: root.appendingPathComponent("SoraPassport/Resources/runtime-sora.json")), dataHasher: .twox256)
        return RuntimeCoderFactory(catalog: snapshot.typeRegistryCatalog, specVersion: 133, txVersion: 131, metadata: snapshot.metadata)
    }
    private func bytes(_ value: UInt8) -> Data { Data([value] + Array(repeating: 0, count: 15)) }
    private func run<T>(_ op: BaseOperation<T>) throws -> T { op.start(); return try XCTUnwrap(op.result).get() }
    private func run<T>(_ wrapper: CompoundOperationWrapper<T>) async throws -> T {
        let done = expectation(description: "storage read completed")
        wrapper.targetOperation.completionBlock = { done.fulfill() }
        let queue = OperationQueue(); wrapper.allOperations.forEach { queue.addOperation($0) }
        await fulfillment(of: [done], timeout: 3)
        return try XCTUnwrap(wrapper.targetOperation.result).get()
    }
    func testScalarReadDecodesTheExactRawAmount() throws {
        let op = StorageDecodingOperation<Value>(path: .totalIssuance, data: bytes(17)); op.codingFactory = try Self.coder.get()
        XCTAssertEqual(try run(op).value, 17)
    }
    func testScalarReadRequiresMetadata() { XCTAssertThrowsError(try run(StorageDecodingOperation<Value>(path: .totalIssuance, data: bytes(1)))) }
    func testScalarReadRequiresBytes() throws {
        let op = StorageDecodingOperation<Value>(path: .totalIssuance); op.codingFactory = try Self.coder.get()
        XCTAssertThrowsError(try run(op))
    }
    func testScalarReadRejectsTruncatedStorage() throws {
        let op = StorageDecodingOperation<Value>(path: .totalIssuance, data: Data([1])); op.codingFactory = try Self.coder.get()
        XCTAssertThrowsError(try run(op))
    }
    func testScalarReadRejectsUnconsumedTrailingStorageBytes() throws {
        let op = StorageDecodingOperation<Value>(path: .totalIssuance, data: bytes(17) + Data([1])); op.codingFactory = try Self.coder.get()
        XCTAssertThrowsError(try run(op))
    }
    func testWrongValueShapeIsNotCoercedIntoAnAmount() throws {
        let op = StorageDecodingOperation<[String]>(path: .totalIssuance, data: bytes(17)); op.codingFactory = try Self.coder.get()
        XCTAssertThrowsError(try run(op))
    }
    func testFallbackUsesRuntimeDeclaredDefaultForAbsentStorage() throws {
        let op = StorageFallbackDecodingOperation<Value>(path: .totalIssuance); op.codingFactory = try Self.coder.get()
        XCTAssertEqual(try run(op)?.value, 0)
    }
    func testFallbackRetainsAnExplicitZeroStorageValue() throws {
        let op = StorageFallbackDecodingOperation<Value>(path: .totalIssuance, data: bytes(0)); op.codingFactory = try Self.coder.get()
        XCTAssertEqual(try run(op)?.value, 0)
    }
    func testFallbackOptionalStorageRemainsNil() throws {
        let op = StorageFallbackDecodingOperation<JSON>(path: .activeEra); op.codingFactory = try Self.coder.get()
        XCTAssertNil(try run(op))
    }
    func testFallbackDoesNotUseDefaultForCorruptStorage() throws {
        let op = StorageFallbackDecodingOperation<Value>(path: .totalIssuance, data: Data([1])); op.codingFactory = try Self.coder.get()
        XCTAssertThrowsError(try run(op))
    }
    func testFallbackRejectsTrailingStorageBytes() throws {
        let op = StorageFallbackDecodingOperation<Value>(path: .totalIssuance, data: bytes(1) + Data([0])); op.codingFactory = try Self.coder.get()
        XCTAssertThrowsError(try run(op))
    }
    func testFallbackRequiresRuntimeMetadata() { XCTAssertThrowsError(try run(StorageFallbackDecodingOperation<Value>(path: .totalIssuance))) }
    func testListReadPreservesValueOrder() throws {
        let op = StorageDecodingListOperation<Value>(path: .totalIssuance, dataList: [bytes(3), bytes(1), bytes(2)]); op.codingFactory = try Self.coder.get()
        XCTAssertEqual(try run(op).map(\.value), [3, 1, 2])
    }
    func testEmptyListIsAnAuthoritativeEmptyResult() throws {
        let op = StorageDecodingListOperation<Value>(path: .totalIssuance, dataList: []); op.codingFactory = try Self.coder.get()
        XCTAssertTrue(try run(op).isEmpty)
    }
    func testListReadRequiresInputList() throws {
        let op = StorageDecodingListOperation<Value>(path: .totalIssuance); op.codingFactory = try Self.coder.get()
        XCTAssertThrowsError(try run(op))
    }
    func testListFailsAtomicallyIfOneStorageEntryIsMalformed() throws {
        let op = StorageDecodingListOperation<Value>(path: .totalIssuance, dataList: [bytes(1), Data([2]), bytes(3)]); op.codingFactory = try Self.coder.get()
        XCTAssertThrowsError(try run(op))
    }
    func testListRejectsOneEntryWithTrailingStorageBytes() throws {
        let op = StorageDecodingListOperation<Value>(path: .totalIssuance, dataList: [bytes(1), bytes(2) + Data([0])]); op.codingFactory = try Self.coder.get()
        XCTAssertThrowsError(try run(op))
    }
    func testFallbackListPreservesMissingEntryPositions() throws {
        let op = StorageFallbackDecodingListOperation<Value>(path: .totalIssuance, dataList: [bytes(3), nil, bytes(2)]); op.codingFactory = try Self.coder.get()
        XCTAssertEqual(try run(op).map { $0?.value }, [3, 0, 2])
    }
    func testOptionalFallbackListPreservesNilEntries() throws {
        let op = StorageFallbackDecodingListOperation<JSON>(path: .activeEra, dataList: [nil, nil]); op.codingFactory = try Self.coder.get()
        XCTAssertEqual(try run(op).count, 2)
    }
    func testFallbackListDoesNotHideCorruptionWithDefaults() throws {
        let op = StorageFallbackDecodingListOperation<Value>(path: .totalIssuance, dataList: [nil, Data([1])]); op.codingFactory = try Self.coder.get()
        XCTAssertThrowsError(try run(op))
    }
    func testFallbackListRejectsTrailingStorageBytes() throws {
        let op = StorageFallbackDecodingListOperation<Value>(path: .totalIssuance, dataList: [bytes(1) + Data([0])]); op.codingFactory = try Self.coder.get()
        XCTAssertThrowsError(try run(op))
    }
    func testFallbackListRequiresInputList() throws {
        let op = StorageFallbackDecodingListOperation<Value>(path: .totalIssuance); op.codingFactory = try Self.coder.get()
        XCTAssertThrowsError(try run(op))
    }
    func testConstantReadUsesPinnedRuntimeSS58Prefix() throws {
        let op = PrimitiveConstantOperation<UInt16>(path: .chainPrefix); op.codingFactory = try Self.coder.get()
        XCTAssertEqual(try run(op), 69)
    }
    func testStructuredConstantReadReturnsExactValue() throws {
        let op = StorageConstantOperation<SoraPassport.StringScaleMapper<UInt16>>(path: .chainPrefix); op.codingFactory = try Self.coder.get()
        XCTAssertEqual(try run(op).value, 69)
    }
    func testUnknownConstantPathFails() throws {
        let op = PrimitiveConstantOperation<UInt32>(path: .init(moduleName: "Unknown", constantName: "Unknown")); op.codingFactory = try Self.coder.get()
        XCTAssertThrowsError(try run(op))
    }
    func testConstantReadRequiresMetadata() { XCTAssertThrowsError(try run(PrimitiveConstantOperation<UInt16>(path: .chainPrefix))) }
    func testStructuredConstantRequiresMetadata() { XCTAssertThrowsError(try run(StorageConstantOperation<JSON>(path: .chainPrefix))) }
    func testPrecomputedFailureIsNotOverwrittenByDecoding() throws {
        let op = StorageDecodingOperation<Value>(path: .totalIssuance, data: bytes(1)); op.codingFactory = try Self.coder.get(); op.result = .failure(LocalStorageFailure.offline)
        XCTAssertThrowsError(try run(op)) { XCTAssertTrue($0 is LocalStorageFailure) }
    }
    private func localFixture() throws -> (LocalStorageRequestFactory, InMemoryDataProviderRepository<ChainStorageItem>) {
        let local = try ChainStorageIdFactory(chain: .sora)
        return (LocalStorageRequestFactory(remoteKeyFactory: StorageKeyFactory(), localKeyFactory: local), InMemoryDataProviderRepository<ChainStorageItem>())
    }
    func testLocalReadReturnsTheQueriedKeyRawBytesAndDecodedValue() async throws {
        let (factory, repository) = try localFixture(); let data = bytes(17)
        try run(repository.saveOperation({ [.init(identifier: "fixture", data: data)] }, { [] }))
        let wrapper: CompoundOperationWrapper<LocalStorageResponse<Value>> = factory.queryItems(repository: AnyDataProviderRepository(repository), key: { "fixture" }, factory: { try Self.coder.get() }, params: .init(path: .totalIssuance))
        let result = try await run(wrapper)
        XCTAssertEqual(result.key, "fixture"); XCTAssertEqual(result.data, data); XCTAssertEqual(result.value?.value, 17)
    }
    func testLocalReadEvaluatesItsKeyOnlyOnceAndCannotRelabelAnotherRecord() async throws {
        let (factory, repository) = try localFixture(); let data = bytes(17); var evaluations = 0
        try run(repository.saveOperation({ [.init(identifier: "first", data: data)] }, { [] }))
        let wrapper: CompoundOperationWrapper<LocalStorageResponse<Value>> = factory.queryItems(repository: AnyDataProviderRepository(repository), key: { evaluations += 1; return evaluations == 1 ? "first" : "second" }, factory: { try Self.coder.get() }, params: .init(path: .totalIssuance))
        let result = try await run(wrapper)
        XCTAssertEqual(result.key, "first"); XCTAssertEqual(evaluations, 1); XCTAssertEqual(result.value?.value, 17)
    }
    func testLocalMissingCacheValueRemainsAbsent() async throws {
        let (factory, repository) = try localFixture()
        let wrapper: CompoundOperationWrapper<LocalStorageResponse<Value>> = factory.queryItems(repository: AnyDataProviderRepository(repository), key: { "missing" }, factory: { try Self.coder.get() }, params: .init(path: .totalIssuance))
        let result = try await run(wrapper); XCTAssertNil(result.data); XCTAssertNil(result.value)
    }
    func testLocalReadPropagatesKeyProviderFailure() async throws {
        let (factory, repository) = try localFixture()
        let wrapper: CompoundOperationWrapper<LocalStorageResponse<Value>> = factory.queryItems(repository: AnyDataProviderRepository(repository), key: { throw LocalStorageFailure.offline }, factory: { try Self.coder.get() }, params: .init(path: .totalIssuance))
        do { _ = try await run(wrapper); XCTFail("Expected key failure") } catch { XCTAssertTrue(error is LocalStorageFailure) }
    }
    func testLocalReadPropagatesMetadataProviderFailure() async throws {
        let (factory, repository) = try localFixture()
        let wrapper: CompoundOperationWrapper<LocalStorageResponse<Value>> = factory.queryItems(repository: AnyDataProviderRepository(repository), key: { "fixture" }, factory: { throw LocalStorageFailure.offline }, params: .init(path: .totalIssuance))
        do { _ = try await run(wrapper); XCTFail("Expected metadata failure") } catch { XCTAssertTrue(error is LocalStorageFailure) }
    }
    func testLocalPlainKeyUsesTheChainScopedStorageIdentifier() async throws {
        let (factory, repository) = try localFixture()
        let remote = try StorageKeyFactory().createStorageKey(moduleName: "Balances", storageName: "TotalIssuance")
        let expected = try ChainStorageIdFactory(chain: .sora).createIdentifier(for: remote)
        let wrapper: CompoundOperationWrapper<LocalStorageResponse<Value>> = factory.queryItems(repository: AnyDataProviderRepository(repository), factory: { try Self.coder.get() }, params: .init(path: .totalIssuance))
        let result = try await run(wrapper); XCTAssertEqual(result.key, expected)
    }
    func testLocalSingleMapUsesAccountBoundKey() async throws {
        let (factory, repository) = try localFixture(); let account = Data(repeating: 7, count: 32)
        let remote = try StorageKeyFactory().accountInfoKeyForId(account)
        let expected = try ChainStorageIdFactory(chain: .sora).createIdentifier(for: remote)
        let wrapper: CompoundOperationWrapper<LocalStorageResponse<JSON>> = factory.queryItems(repository: AnyDataProviderRepository(repository), keyParam: { account }, factory: { try Self.coder.get() }, params: .init(path: .account))
        let result = try await run(wrapper); XCTAssertEqual(result.key, expected)
    }
    func testLocalSingleMapValueWrapperRetainsMissingCacheAsNil() async throws {
        let (factory, repository) = try localFixture()
        let wrapper: CompoundOperationWrapper<JSON?> = factory.queryItems(repository: AnyDataProviderRepository(repository), keyParam: { Data(repeating: 7, count: 32) }, factory: { try Self.coder.get() }, params: .init(path: .account))
        let result = try await run(wrapper); XCTAssertNil(result)
    }
    func testLocalSingleMapPropagatesParameterFailure() async throws {
        let (factory, repository) = try localFixture()
        let wrapper: CompoundOperationWrapper<LocalStorageResponse<JSON>> = factory.queryItems(repository: AnyDataProviderRepository(repository), keyParam: { () throws -> Data in throw LocalStorageFailure.offline }, factory: { try Self.coder.get() }, params: .init(path: .account))
        do { _ = try await run(wrapper); XCTFail("Expected parameter failure") } catch { XCTAssertTrue(error is LocalStorageFailure) }
    }
    func testLocalDoubleMapUsesBothAccountAndAssetKeyComponents() async throws {
        let (factory, repository) = try localFixture(); let account = Data(repeating: 7, count: 32)
        let asset = AssetId(wrappedValue: WalletAssetId.val.rawValue)
        let remote = try StorageKeyFactory().accountsKey(account: account, asset: Data(hexStringSSF: WalletAssetId.val.rawValue))
        let expected = try ChainStorageIdFactory(chain: .sora).createIdentifier(for: remote)
        let wrapper: CompoundOperationWrapper<LocalStorageResponse<JSON>> = factory.queryItems(repository: AnyDataProviderRepository(repository), keyParam1: { account }, keyParam2: { asset }, factory: { try Self.coder.get() }, params: .init(path: .tokens))
        let result = try await run(wrapper); XCTAssertEqual(result.key, expected)
    }
    func testLocalDoubleMapValueWrapperPreservesAbsentCacheAsNil() async throws {
        let (factory, repository) = try localFixture()
        let wrapper: CompoundOperationWrapper<JSON?> = factory.queryItems(repository: AnyDataProviderRepository(repository), keyParam1: { Data(repeating: 7, count: 32) }, keyParam2: { AssetId(wrappedValue: WalletAssetId.val.rawValue) }, factory: { try Self.coder.get() }, params: .init(path: .tokens))
        let result = try await run(wrapper); XCTAssertNil(result)
    }
    func testLocalDoubleMapPropagatesFirstParameterFailure() async throws {
        let (factory, repository) = try localFixture()
        let wrapper: CompoundOperationWrapper<LocalStorageResponse<JSON>> = factory.queryItems(repository: AnyDataProviderRepository(repository), keyParam1: { () throws -> Data in throw LocalStorageFailure.offline }, keyParam2: { AssetId(wrappedValue: WalletAssetId.val.rawValue) }, factory: { try Self.coder.get() }, params: .init(path: .tokens))
        do { _ = try await run(wrapper); XCTFail("Expected parameter failure") } catch { XCTAssertTrue(error is LocalStorageFailure) }
    }
    func testLocalDoubleMapPropagatesSecondParameterFailure() async throws {
        let (factory, repository) = try localFixture()
        let wrapper: CompoundOperationWrapper<LocalStorageResponse<JSON>> = factory.queryItems(repository: AnyDataProviderRepository(repository), keyParam1: { Data(repeating: 7, count: 32) }, keyParam2: { () throws -> AssetId in throw LocalStorageFailure.offline }, factory: { try Self.coder.get() }, params: .init(path: .tokens))
        do { _ = try await run(wrapper); XCTFail("Expected parameter failure") } catch { XCTAssertTrue(error is LocalStorageFailure) }
    }
    func testDoubleMapKeyEncoderSupportsModernNMapMetadata() throws {
        let account = Data(repeating: 7, count: 32), asset = AssetId(wrappedValue: WalletAssetId.val.rawValue)
        let op = DoubleMapKeyEncodingOperation<Data, AssetId>(path: .tokens, storageKeyFactory: StorageKeyFactory(), keyParams1: [account], keyParams2: [asset]); op.codingFactory = try Self.coder.get()
        let expected = try StorageKeyFactory().accountsKey(account: account, asset: Data(hexStringSSF: WalletAssetId.val.rawValue))
        XCTAssertEqual(try run(op), [expected])
    }
    func testDoubleMapKeyEncoderPreservesMultipleRowOrdering() throws {
        let a = Data(repeating: 7, count: 32), b = Data(repeating: 8, count: 32)
        let asset = AssetId(wrappedValue: WalletAssetId.val.rawValue)
        let op = DoubleMapKeyEncodingOperation<Data, AssetId>(path: .tokens, storageKeyFactory: StorageKeyFactory(), keyParams1: [b, a], keyParams2: [asset, asset]); op.codingFactory = try Self.coder.get()
        let results = try run(op)
        XCTAssertEqual(results, try [b, a].map { try StorageKeyFactory().accountsKey(account: $0, asset: Data(hexStringSSF: WalletAssetId.val.rawValue)) })
    }
    func testDoubleMapKeyEncoderRejectsMismatchedRowCounts() throws {
        let op = DoubleMapKeyEncodingOperation<Data, AssetId>(path: .tokens, storageKeyFactory: StorageKeyFactory(), keyParams1: [], keyParams2: [AssetId(wrappedValue: WalletAssetId.val.rawValue)]); op.codingFactory = try Self.coder.get()
        XCTAssertThrowsError(try run(op))
    }
    func testDoubleMapKeyEncoderCannotUseASingleKeyStorage() throws {
        let op = DoubleMapKeyEncodingOperation<Data, Data>(path: .account, storageKeyFactory: StorageKeyFactory(), keyParams1: [Data(repeating: 7, count: 32)], keyParams2: [Data(repeating: 8, count: 32)]); op.codingFactory = try Self.coder.get()
        XCTAssertThrowsError(try run(op))
    }

}
private enum LocalStorageFailure: Swift.Error { case offline }

extension StorageDecodingFlowTests {
    private func remoteFactory() -> StorageRequestFactory {
        StorageRequestFactory(remoteFactory: StorageKeyFactory(), operationManager: OperationManager())
    }
    func testRemoteDoubleMapBindsBothKeyPartsAndTheRequestedBlock() async throws {
        let engine = StorageQueryFixtureEngine(), first = Data(repeating: 7, count: 32), second = Data(repeating: 8, count: 32)
        engine.value = Data(repeating: 0, count: 48)
        let asset = AssetId(wrappedValue: WalletAssetId.val.rawValue), block = Data(repeating: 9, count: 32)
        let wrapper: CompoundOperationWrapper<[StorageResponse<JSON>]> = remoteFactory().queryItems(engine: engine,
            keyParams1: { [first, second] }, keyParams2: { [asset, asset] }, factory: { try Self.coder.get() }, storagePath: .tokens, at: block)
        let rows = try await run(wrapper)
        let expected = try [first, second].map { try StorageKeyFactory().accountsKey(account: $0, asset: Data(hexStringSSF: WalletAssetId.val.rawValue)) }
        XCTAssertEqual(rows.map(\.key), expected)
        XCTAssertTrue(rows.allSatisfy { $0.data == engine.value && $0.value != nil })
        XCTAssertEqual(engine.blocks, [block.toHex(includePrefix: true)])
        XCTAssertEqual(engine.pages, [expected.map { $0.toHex(includePrefix: true) }])
    }
    func testRemoteDoubleMapConvenienceUsesLatestBlockWithoutInventingABlockHash() async throws {
        let engine = StorageQueryFixtureEngine(); engine.value = Data(repeating: 0, count: 48)
        let wrapper: CompoundOperationWrapper<[StorageResponse<JSON>]> = remoteFactory().queryItems(engine: engine,
            keyParams1: { [Data(repeating: 7, count: 32)] }, keyParams2: { [AssetId(wrappedValue: WalletAssetId.val.rawValue)] },
            factory: { try Self.coder.get() }, storagePath: .tokens)
        let rows = try await run(wrapper)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(engine.blocks, [nil])
    }
    func testRemoteDoubleMapRejectsFirstKeyFailureBeforeRPC() async {
        let engine = StorageQueryFixtureEngine()
        let wrapper: CompoundOperationWrapper<[StorageResponse<JSON>]> = remoteFactory().queryItems(engine: engine,
            keyParams1: { () throws -> [Data] in throw LocalStorageFailure.offline }, keyParams2: { [AssetId(wrappedValue: WalletAssetId.val.rawValue)] },
            factory: { try Self.coder.get() }, storagePath: .tokens)
        do { _ = try await run(wrapper); XCTFail("Missing key must fail") } catch { XCTAssertTrue(error is LocalStorageFailure) }
        XCTAssertTrue(engine.pages.isEmpty)
    }
    func testRemoteDoubleMapRejectsSecondKeyFailureBeforeRPC() async {
        let engine = StorageQueryFixtureEngine()
        let wrapper: CompoundOperationWrapper<[StorageResponse<JSON>]> = remoteFactory().queryItems(engine: engine,
            keyParams1: { [Data(repeating: 7, count: 32)] }, keyParams2: { () throws -> [AssetId] in throw LocalStorageFailure.offline },
            factory: { try Self.coder.get() }, storagePath: .tokens)
        do { _ = try await run(wrapper); XCTFail("Missing key must fail") } catch { XCTAssertTrue(error is LocalStorageFailure) }
        XCTAssertTrue(engine.pages.isEmpty)
    }
    func testRemoteDoubleMapRejectsRuntimeFailureBeforeRPC() async {
        let engine = StorageQueryFixtureEngine()
        let wrapper: CompoundOperationWrapper<[StorageResponse<JSON>]> = remoteFactory().queryItems(engine: engine,
            keyParams1: { [Data(repeating: 7, count: 32)] }, keyParams2: { [AssetId(wrappedValue: WalletAssetId.val.rawValue)] },
            factory: { throw LocalStorageFailure.offline }, storagePath: .tokens)
        do { _ = try await run(wrapper); XCTFail("Missing runtime must fail") } catch { XCTAssertTrue(error is LocalStorageFailure) }
        XCTAssertTrue(engine.pages.isEmpty)
    }
    func testRemoteDoubleMapRejectsMismatchedParameterCountsBeforeRPC() async {
        let engine = StorageQueryFixtureEngine()
        let wrapper: CompoundOperationWrapper<[StorageResponse<JSON>]> = remoteFactory().queryItems(engine: engine,
            keyParams1: { [Data(repeating: 7, count: 32)] }, keyParams2: { [] as [AssetId] },
            factory: { try Self.coder.get() }, storagePath: .tokens)
        do { _ = try await run(wrapper); XCTFail("Mismatched keys must fail") } catch {}
        XCTAssertTrue(engine.pages.isEmpty)
    }
    func testRemoteStoragePaginatesWithoutLosingRequestedOrder() async throws {
        let engine = StorageQueryFixtureEngine(); engine.value = bytes(17)
        let keys = (0..<1_001).map { Data([UInt8($0 & 255), UInt8($0 >> 8)]) }
        let wrapper: CompoundOperationWrapper<[StorageResponse<Value>]> = remoteFactory().queryItems(engine: engine,
            keys: { keys }, factory: { try Self.coder.get() }, storagePath: .totalIssuance)
        let rows = try await run(wrapper)
        XCTAssertEqual(engine.pages.map(\.count), [1_000, 1]); XCTAssertEqual(rows.map(\.key), keys)
        XCTAssertEqual(rows.compactMap(\.value).map(\.value), Array(repeating: BigUInt(17), count: 1_001))
    }
    func testRemoteStorageFailureCannotBecomeAnEmptySuccessfulRead() async {
        let engine = StorageQueryFixtureEngine(); engine.failure = LocalStorageFailure.offline
        let wrapper: CompoundOperationWrapper<[StorageResponse<Value>]> = remoteFactory().queryItems(engine: engine,
            keys: { [Data([1])] }, factory: { try Self.coder.get() }, storagePath: .totalIssuance)
        do { _ = try await run(wrapper); XCTFail("RPC failure must propagate") } catch { XCTAssertTrue(error is LocalStorageFailure) }
        XCTAssertEqual(engine.pages.count, 1)
    }
}
private final class StorageQueryFixtureEngine: JSONRPCEngine {
    var url: URL? = URL(string: "wss://storage-query.fixture.invalid")
    var pendingEngineRequests: [JSONRPCRequest] { [] }
    var value = Data(), failure: Error?
    private(set) var pages = [[String]](), blocks = [String?]()
    func callMethod<P: Codable, T: Decodable>(_ method: String, params: P?, options: JSONRPCOptions, completion closure: ((Result<T, Error>) -> Void)?) throws -> UInt16 {
        XCTAssertEqual(method, SoraPassport.RPCMethod.queryStorageAt)
        let encoded = try JSONEncoder().encode(params)
        let request = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [Any])
        let keys = try XCTUnwrap(request.first as? [String])
        pages.append(keys); blocks.append(request.count > 1 ? request[1] as? String : nil)
        let result = Result<T, Error> {
            if let failure { throw failure }
            let changes = keys.reversed().map { [$0, value.toHex(includePrefix: true)] }
            let response: [[String: Any]] = [["block": "0x" + String(repeating: "09", count: 32), "changes": changes]]
            return try JSONDecoder.scaleCompatible(snakeCase: false).decode(T.self, from: JSONSerialization.data(withJSONObject: response))
        }
        closure?(result)
        return UInt16(pages.count)
    }
    func subscribe<P: Codable, T: Decodable>(_ method: String, params: P?, updateClosure: @escaping (T) -> Void, failureClosure: @escaping (Error, Bool) -> Void) throws -> UInt16 { XCTFail("Storage queries must not subscribe"); throw LocalStorageFailure.offline }
    func cancelForIdentifier(_ identifier: UInt16) {}
    func generateRequestId() -> UInt16 { 1 }
    func addSubscription(_ subscription: JSONRPCSubscribing) { XCTFail("Storage queries must not subscribe") }
    func connectIfNeeded() {}; func disconnectIfNeeded() {}; func unsubsribe(_ identifier: UInt16) throws {}
}
