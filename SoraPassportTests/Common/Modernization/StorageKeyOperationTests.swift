// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause
import Foundation
import RobinHood
import SSFUtils
import XCTest
@testable import SoraPassport

final class StorageKeyOperationTests: XCTestCase {
    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    private let remote = StorageKeyFactory()
    private func factory(_ type: StorageEntryType, path: StorageCodingPath = .account) throws -> RuntimeCoderFactory {
        let root = Self.root
        let bytes = try Data(contentsOf: root.appendingPathComponent("Fixtures/Modernization/sora2-metadata-spec133.scale"))
        let snapshot = try RuntimeSnapshotFactory.makeOwnTypesSnapshot(chainId: PIIndexerClient.soraMainnetGenesis, runtimeMetadataItem: SoraPassport.RuntimeMetadataItem(chain: PIIndexerClient.soraMainnetGenesis, version: 133, txVersion: 131, metadata: bytes, resolver: nil), ownTypes: Data(contentsOf: root.appendingPathComponent("SoraPassport/Resources/runtime-sora.json")), dataHasher: .twox256)
        // Encode a small legacy runtime storage declaration, then load it through the real SCALE decoder.
        let entry = RuntimeMetadataV1.StorageEntryMetadata(name: path.itemName, modifier: .optional, type: type, defaultValue: Data(), documentation: [])
        let module = RuntimeMetadataV1.ModuleMetadata(name: path.moduleName, storage: .init(prefix: path.moduleName, entries: [entry]), calls: nil, events: nil, constants: [], errors: [], index: 0)
        let encoder = ScaleEncoder(); try UInt32(0x6174656d).encode(scaleEncoder: encoder); try UInt8(13).encode(scaleEncoder: encoder); try [module].encode(scaleEncoder: encoder); try RuntimeMetadataV1.ExtrinsicMetadata(version: 4, signedExtensions: []).encode(scaleEncoder: encoder)
        return RuntimeCoderFactory(catalog: snapshot.typeRegistryCatalog, specVersion: 133, txVersion: 131, metadata: try RuntimeMetadata(scaleDecoder: ScaleDecoder(data: encoder.encode())))
    }
    private var map: StorageEntryType { .map(.init(hasher: .identity, key: "u32", value: "u32", unused: false)) }
    private var doubleMap: StorageEntryType { .doubleMap(.init(hasher: .identity, key1: "u32", key2: "u64", value: "u32", key2Hasher: .identity)) }
    private func nmap(_ keys: [String] = ["u32", "u64"], hashers: [StorageHasher] = [.identity, .identity]) -> StorageEntryType { .nMap(.init(keysStrings: keys, hashers: hashers, valueString: "u32")) }
    private func prefix() throws -> Data { try remote.createStorageKey(moduleName: "System", storageName: "Account") }
    private func bytes32(_ value: UInt32) -> Data { withUnsafeBytes(of: value.littleEndian) { Data($0) } }
    private func bytes64(_ value: UInt64) -> Data { withUnsafeBytes(of: value.littleEndian) { Data($0) } }
    private func run<T>(_ operation: BaseOperation<T>) throws -> T { operation.main(); return try XCTUnwrap(operation.result).get() }
    private func single(_ keys: [String]?, type: StorageEntryType? = nil) throws -> MapKeyEncodingOperation<String> { let op = MapKeyEncodingOperation<String>(path: .account, storageKeyFactory: remote, keyParams: keys); op.codingFactory = try factory(type ?? map); return op }
    private func pair(_ first: [String]?, _ second: [String]?, type: StorageEntryType? = nil) throws -> DoubleMapKeyEncodingOperation<String, String> { let op = DoubleMapKeyEncodingOperation<String, String>(path: .account, storageKeyFactory: remote, keyParams1: first, keyParams2: second); op.codingFactory = try factory(type ?? doubleMap); return op }
    private func many(_ first: [String], _ second: [String], type: StorageEntryType? = nil) throws -> NMapKeyEncodingOperation { let op = NMapKeyEncodingOperation(path: .account, storageKeyFactory: remote, keyParams: [first.map { NMapKeyParam(value: $0) }, second.map { NMapKeyParam(value: $0) }]); op.codingFactory = try factory(type ?? nmap()); return op }
    private func assertError<T>(_ op: BaseOperation<T>, _ expected: StorageKeyEncodingOperationError, file: StaticString = #filePath, line: UInt = #line) { XCTAssertThrowsError(try run(op), file: file, line: line) { error in XCTAssertEqual(String(describing: error), String(describing: expected), file: file, line: line) } }

    func testRealDemeterPoolKeyHashesBothDimensionsAsTheRuntimeDeclares() throws {
        let root = Self.root
        let snapshot = try RuntimeSnapshotFactory.makeOwnTypesSnapshot(chainId: PIIndexerClient.soraMainnetGenesis, runtimeMetadataItem: SoraPassport.RuntimeMetadataItem(chain: PIIndexerClient.soraMainnetGenesis, version: 133, txVersion: 131, metadata: Data(contentsOf: root.appendingPathComponent("Fixtures/Modernization/sora2-metadata-spec133.scale")), resolver: nil), ownTypes: Data(contentsOf: root.appendingPathComponent("SoraPassport/Resources/runtime-sora.json")), dataHasher: .twox256)
        let factory = RuntimeCoderFactory(catalog: snapshot.typeRegistryCatalog, specVersion: 133, txVersion: 131, metadata: snapshot.metadata)
        let entry = try XCTUnwrap(factory.metadata.getStorageMetadata(in: "DemeterFarmingPlatform", storageName: "Pools"))
        guard case let .nMap(info) = entry.type else { return XCTFail("Expected the runtime's actual pool tuple key") }
        XCTAssertEqual(info.hashers.count, 2)
        XCTAssertEqual(try info.keys(using: factory.metadata.schemaResolver).count, 2)
        let ids = [WalletAssetId.xor.rawValue, WalletAssetId.val.rawValue]
        let op = NMapKeyEncodingOperation(path: .demeterFarmingPools, storageKeyFactory: remote, keyParams: ids.map { [NMapKeyParam(value: AssetId(wrappedValue: $0))] })
        op.codingFactory = factory
        let raw = try ids.map { try Data(hexStringSSF: $0) }
        let expected = try remote.createStorageKey(moduleName: "DemeterFarmingPlatform", storageName: "Pools", keys: raw, hashers: info.hashers)
        XCTAssertEqual(try run(op), [expected])
    }
    func testNMapRejectsShorterColumnWithoutIndexingPastItsEnd() throws { assertError(try many(["1", "2"], ["3"]), .missingRequiredParams) }
    func testNMapRejectsZeroDimensionsWithoutIndexingTheEmptyInput() throws { let op = NMapKeyEncodingOperation(path: .account, storageKeyFactory: remote, keyParams: []); op.codingFactory = try factory(nmap([], hashers: [])); assertError(op, .incompatibleStorageType) }
    func testNMapRejectsHasherCountThatCannotDescribeItsColumns() throws { assertError(try many(["1"], ["2"], type: nmap(hashers: [.identity, .identity, .identity])), .incompatibleStorageType) }
    func testNMapSingleHasherCoversTheWholeTupleInOrder() throws { XCTAssertEqual(try run(many(["1", "2"], ["300", "400"], type: nmap(hashers: [.identity]))), [try prefix() + bytes32(1) + bytes64(300), try prefix() + bytes32(2) + bytes64(400)]) }
    func testUnkeyedPlainStorageUsesOnlyThePalletAndStoragePrefix() throws { let op = UnkeyedEncodingOperation(path: .account, storageKeyFactory: remote); op.codingFactory = try factory(.plain(.init(stringValue: "u32"))); XCTAssertEqual(try run(op), try prefix()) }
    func testUnkeyedMapSupportsPrefixQueriesWithoutInventingAKey() throws { let op = UnkeyedEncodingOperation(path: .account, storageKeyFactory: remote); op.codingFactory = try factory(map); XCTAssertEqual(try run(op), try prefix()) }
    func testUnkeyedRequiresMetadata() { assertError(UnkeyedEncodingOperation(path: .account, storageKeyFactory: remote), .missingRequiredParams) }
    func testUnkeyedRejectsAnUnknownStoragePath() throws { let op = UnkeyedEncodingOperation(path: .tokens, storageKeyFactory: remote); op.codingFactory = try factory(map); assertError(op, .invalidStoragePath) }
    func testUnkeyedCancellationDoesNotCreateAKey() { let op = UnkeyedEncodingOperation(path: .account, storageKeyFactory: remote); op.cancel(); op.main(); XCTAssertNil(op.result) }
    func testUnkeyedPreservesUpstreamFailure() { let op = UnkeyedEncodingOperation(path: .account, storageKeyFactory: remote); op.result = .failure(StorageTestError.upstream); op.main(); XCTAssertThrowsError(try op.result?.get()) { XCTAssertTrue($0 is StorageTestError) } }
    func testMapEncodesOneExactLittleEndianKey() throws { XCTAssertEqual(try run(single(["16909060"])), [try prefix() + Data([4, 3, 2, 1])]) }
    func testMapBatchProducesOneIndependentKeyPerAccount() throws { XCTAssertEqual(try run(single(["1", "9", "1"])), [try prefix() + bytes32(1), try prefix() + bytes32(9), try prefix() + bytes32(1)]) }
    func testMapEmptyBatchDoesNotQueryTheWholeStoragePrefix() throws { XCTAssertEqual(try run(single([])), []) }
    func testMapMalformedElementFailsTheWholeBatch() throws { XCTAssertThrowsError(try run(single(["1", "not-an-integer", "3"]))) }
    func testMapOverflowIsNotSilentlyEncodedAsAnEmptyKey() throws { XCTAssertThrowsError(try run(single(["4294967296"]))) }
    func testMapRequiresBothTheFactoryAndParameters() throws { assertError(try single(nil), .missingRequiredParams); let op = MapKeyEncodingOperation<String>(path: .account, storageKeyFactory: remote, keyParams: ["1"]); assertError(op, .missingRequiredParams) }
    func testMapRejectsPlainStorage() throws { assertError(try single(["1"], type: .plain(.init(stringValue: "u32"))), .incompatibleStorageType) }
    func testMapRejectsAnUnknownPath() throws { let op = MapKeyEncodingOperation<String>(path: .events, storageKeyFactory: remote, keyParams: ["1"]); op.codingFactory = try factory(map); assertError(op, .invalidStoragePath) }
    func testMapUsesFirstDoubleMapDimensionForPrefixQueries() throws { XCTAssertEqual(try run(single(["2", "3"], type: doubleMap)), [try prefix() + bytes32(2), try prefix() + bytes32(3)]) }
    func testMapUsesFirstNMapDimensionForPrefixQueries() throws { XCTAssertEqual(try run(single(["2", "3"], type: nmap())), [try prefix() + bytes32(2), try prefix() + bytes32(3)]) }
    func testMapRejectsAnNMapWithNoKeysOrHashers() throws { assertError(try single(["1"], type: nmap([], hashers: [])), .missingRequiredParams) }
    func testMapCancellationDoesNotInvokeTheEncoder() throws { let op = try single(["1"]); op.cancel(); op.main(); XCTAssertNil(op.result) }
    func testMapPreservesAnUpstreamResult() throws { let op = try single(["1"]); op.result = .success([Data([7])]); XCTAssertEqual(try run(op), [Data([7])]) }
    func testDoubleMapPairsEachRowRatherThanCrossJoining() throws { XCTAssertEqual(try run(pair(["1", "2"], ["300", "400"])), [try prefix() + bytes32(1) + bytes64(300), try prefix() + bytes32(2) + bytes64(400)]) }
    func testDoubleMapEmptyBatchStaysEmpty() throws { XCTAssertEqual(try run(pair([], [])), []) }
    func testDoubleMapRejectsUnequalColumnLengths() throws { assertError(try pair(["1"], ["2", "3"]), .missingRequiredParams) }
    func testDoubleMapRequiresBothColumns() throws { assertError(try pair(nil, ["2"]), .missingRequiredParams); assertError(try pair(["1"], nil), .missingRequiredParams) }
    func testDoubleMapRejectsAnotherStorageKind() throws { assertError(try pair(["1"], ["2"], type: map), .incompatibleStorageType) }
    func testDoubleMapPropagatesEitherColumnEncodingFailure() throws { XCTAssertThrowsError(try run(pair(["bad"], ["2"]))); XCTAssertThrowsError(try run(pair(["1"], ["bad"]))) }
    func testDoubleMapCancellationKeepsNoResult() throws { let op = try pair(["1"], ["2"]); op.cancel(); op.main(); XCTAssertNil(op.result) }
    func testNMapTransposesColumnsIntoIndependentStorageKeys() throws { XCTAssertEqual(try run(many(["1", "2"], ["300", "400"])), [try prefix() + bytes32(1) + bytes64(300), try prefix() + bytes32(2) + bytes64(400)]) }
    func testNMapEmptyRowsProduceNoKeys() throws { XCTAssertEqual(try run(many([], [])), []) }
    func testNMapRejectsAnExtraValueInsteadOfDroppingIt() throws { assertError(try many(["1"], ["2", "3"]), .missingRequiredParams) }
    func testNMapRejectsMissingDimension() throws { let op = NMapKeyEncodingOperation(path: .account, storageKeyFactory: remote, keyParams: [[NMapKeyParam(value: "1")]]); op.codingFactory = try factory(nmap()); assertError(op, .incompatibleStorageType) }
    func testNMapRequiresAFactoryAndParameters() throws { let op = NMapKeyEncodingOperation(path: .account, storageKeyFactory: remote); assertError(op, .missingRequiredParams); op.codingFactory = try factory(nmap()); assertError(op, .missingRequiredParams) }
    func testNMapRejectsANonNMapStorageEntry() throws { assertError(try many(["1"], ["2"], type: map), .incompatibleStorageType) }
    func testNMapPropagatesMalformedValues() throws { XCTAssertThrowsError(try run(many(["1"], ["bad"]))) }
    func testNMapCancellationDoesNotCreateKeys() throws { let op = try many(["1"], ["2"]); op.cancel(); op.main(); XCTAssertNil(op.result) }
    func testNMapPreservesUpstreamFailure() throws { let op = try many(["1"], ["2"]); op.result = .failure(StorageTestError.upstream); XCTAssertThrowsError(try run(op)) { XCTAssertTrue($0 is StorageTestError) } }
    func testLocalWrapperMapsEveryRemoteKeyAndOrdersItsDependency() throws { let op = try single(["1", "2"]); let wrapper = op.localWrapper(for: StorageTestLocalKeys()); XCTAssertTrue(wrapper.targetOperation.dependencies.contains { $0 === op }); op.main(); wrapper.targetOperation.main(); XCTAssertEqual(try XCTUnwrap(wrapper.targetOperation.result).get(), ["local:" + (try prefix() + bytes32(1)).toHex(), "local:" + (try prefix() + bytes32(2)).toHex()]) }
    func testLocalWrapperPropagatesRemoteEncodingFailure() throws { let op = try pair(["bad"], ["2"]); let wrapper = op.localWrapper(for: StorageTestLocalKeys()); op.main(); wrapper.targetOperation.main(); XCTAssertThrowsError(try XCTUnwrap(wrapper.targetOperation.result).get()) }
}
private enum StorageTestError: Error { case upstream }
private final class StorageTestLocalKeys: ChainStorageIdFactoryProtocol { func createIdentifier(for key: Data) -> String { "local:" + key.toHex() } }
