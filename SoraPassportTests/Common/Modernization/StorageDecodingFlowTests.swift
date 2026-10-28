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
