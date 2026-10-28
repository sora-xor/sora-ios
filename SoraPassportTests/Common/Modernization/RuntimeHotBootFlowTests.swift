// SPDX-License-Identifier: BSD-4-Clause
import Foundation
import RobinHood
import SSFUtils
import XCTest
@testable import SoraPassport

final class RuntimeHotBootFlowTests: XCTestCase {
    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    private static func read(_ path: String) throws -> Data { try Data(contentsOf: root.appendingPathComponent(path)) }
    private func make(chain: String = PIIndexerClient.soraMainnetGenesis, itemChain: String? = nil, version: UInt32 = 133, transactionVersion: UInt32 = 131, metadata: Data? = nil, own: Data? = nil, common: Data? = nil) throws -> (RuntimeHotBootSnapshotFactory, HotFiles) {
        let files = HotFiles(); files.data = try own ?? Self.read("SoraPassport/Resources/runtime-sora.json")
        let item = try SoraPassport.RuntimeMetadataItem(chain: itemChain ?? chain, version: version, txVersion: transactionVersion, metadata: metadata ?? Self.read("Fixtures/Modernization/sora2-metadata-spec133.scale"), resolver: nil)
        return (try RuntimeHotBootSnapshotFactory(chainId: chain, runtimeItem: item, commonTypes: common ?? Self.read("SoraPassport/Resources/runtime-default.json"), filesOperationFactory: files), files)
    }
    private func run<T>(_ wrapper: CompoundOperationWrapper<T>) async throws -> T {
        let done = expectation(description: "cached runtime construction")
        wrapper.targetOperation.completionBlock = { done.fulfill() }
        let queue = OperationQueue(); wrapper.allOperations.forEach { queue.addOperation($0) }
        await fulfillment(of: [done], timeout: 4)
        return try XCTUnwrap(wrapper.targetOperation.result).get()
    }
    private func snapshot(_ factory: RuntimeHotBootSnapshotFactory, usage: SoraPassport.ChainModel.TypesUsage = .onlyOwn) async throws -> RuntimeSnapshot {
        let value = try await run(factory.createRuntimeSnapshotWrapper(for: usage, dataHasher: .twox256)); return try XCTUnwrap(value)
    }
    private func rejects(_ factory: RuntimeHotBootSnapshotFactory, usage: SoraPassport.ChainModel.TypesUsage = .onlyOwn) async {
        do { _ = try await snapshot(factory, usage: usage); XCTFail("Unadmitted cached runtime was accepted") } catch { }
    }
    func testReviewedOwnTypesBuildAnExactRuntimeSnapshot() async throws {
        let (f, files) = try make(); let s = try await snapshot(f)
        XCTAssertEqual(s.specVersion, 133); XCTAssertEqual(s.txVersion, 131); XCTAssertNil(s.localCommonHash)
        XCTAssertEqual(s.localChainHash, try StorageHasher.twox256.hash(data: XCTUnwrap(files.data)).toHex())
        let identity = try Sora2RuntimeIdentity.declared(by: s.metadata); XCTAssertEqual(identity.specVersion, 133); XCTAssertEqual(identity.transactionVersion, 131)
        XCTAssertEqual(files.chainRequests, [PIIndexerClient.soraMainnetGenesis]); XCTAssertEqual(files.commonRequests, 0)
    }
    func testReviewedRuntimeCannotSwitchToCommonOnlyTypes() async throws { let (f, files) = try make(); await rejects(f, usage: .onlyCommon); XCTAssertTrue(files.chainRequests.isEmpty) }
    func testReviewedRuntimeCannotMixCommonAndOwnTypes() async throws { let (f, _) = try make(); await rejects(f, usage: .both) }
    func testReviewedRuntimeRejectsMetadataFromAnotherChain() async throws { let (f, _) = try make(itemChain: String(repeating: "ab", count: 32)); await rejects(f) }
    func testReviewedRuntimeRejectsWrongSpecVersion() async throws { let (f, _) = try make(version: 134); await rejects(f) }
    func testReviewedRuntimeRejectsWrongTransactionVersion() async throws { let (f, _) = try make(transactionVersion: 130); await rejects(f) }
    func testReviewedRuntimeRejectsBelowFloorVersion() async throws { let (f, _) = try make(version: 129); await rejects(f) }
    func testReviewedRuntimeRejectsEmptyMetadata() async throws { let (f, _) = try make(metadata: Data()); await rejects(f) }
    func testReviewedRuntimeRejectsTruncatedMetadata() async throws { let (f, _) = try make(metadata: Data([0x6d, 0x65, 0x74, 0x61, 14])); await rejects(f) }
    func testReviewedRuntimeRejectsTrailingMetadataBytes() async throws {
        let data = try Self.read("Fixtures/Modernization/sora2-metadata-spec133.scale") + Data([0])
        let (f, _) = try make(metadata: data); await rejects(f)
    }
    func testReviewedRuntimeRejectsModifiedOwnTypesEvenWhenJSONIsValid() async throws {
        let data = try Self.read("SoraPassport/Resources/runtime-sora.json") + Data([0x20]); let (f, _) = try make(own: data); await rejects(f)
    }
    func testMissingOwnTypesCannotProduceASnapshot() async throws { let (f, files) = try make(); files.data = nil; await rejects(f) }
    func testReadFailureIsPropagatedWithoutBuildingASnapshot() async throws {
        let (f, files) = try make(); files.failure = HotFailure.unavailable
        do { _ = try await snapshot(f); XCTFail("Expected cache failure") } catch { XCTAssertTrue(error is HotFailure) }
    }
    func testReleasedFactoryDoesNotReturnAPartialSnapshot() async throws {
        var f: RuntimeHotBootSnapshotFactory? = try make().0; let wrapper = f!.createRuntimeSnapshotWrapper(for: .onlyOwn, dataHasher: .twox256); f = nil
        do { _ = try await run(wrapper); XCTFail("Expected released factory failure") } catch { XCTAssertTrue(error is RuntimeHotBootSnapshotFactoryError) }
    }
    func testGenericChainSupportsCommonOnlyRegistryWithoutReadingOwnTypes() async throws {
        let (f, files) = try make(chain: "generic-fixture"); let s = try await snapshot(f, usage: .onlyCommon)
        XCTAssertEqual(s.localCommonHash, try StorageHasher.twox256.hash(data: Self.read("SoraPassport/Resources/runtime-default.json")).toHex()); XCTAssertNil(s.localChainHash); XCTAssertTrue(files.chainRequests.isEmpty)
    }
    func testGenericChainSupportsMixedRegistryWithBothHashes() async throws {
        let (f, files) = try make(chain: "generic-fixture"); let s = try await snapshot(f, usage: .both)
        XCTAssertNotNil(s.localCommonHash); XCTAssertEqual(s.localChainHash, try StorageHasher.twox256.hash(data: XCTUnwrap(files.data)).toHex()); XCTAssertEqual(s.specVersion, 133)
    }
    func testGenericChainRejectsMissingMixedRegistry() async throws { let (f, files) = try make(chain: "generic-fixture"); files.data = nil; await rejects(f, usage: .both) }
    func testGenericChainRejectsMalformedCommonRegistry() async throws { let (f, _) = try make(chain: "generic-fixture", common: Data("not-json".utf8)); await rejects(f, usage: .onlyCommon) }
    func testGenericChainRejectsMalformedOwnRegistry() async throws { let (f, _) = try make(chain: "generic-fixture", own: Data("not-json".utf8)); await rejects(f) }
    func testMetadataItemSerializationPreservesExactBlobAndVersions() throws {
        let original = try SoraPassport.RuntimeMetadataItem(chain: "generic-fixture", version: 133, txVersion: 131, metadata: Self.read("Fixtures/Modernization/sora2-metadata-spec133.scale"), resolver: nil)
        let data = try JSONEncoder().encode(original); let restored = try JSONDecoder().decode(SoraPassport.RuntimeMetadataItem.self, from: data)
        XCTAssertEqual(restored, original); XCTAssertEqual(restored.identifier, "generic-fixture")
    }
}
private enum HotFailure: Error { case unavailable }
private final class HotFiles: RuntimeFilesOperationFactoryProtocol {
    var data: Data?, failure: Error?, chainRequests = [String](), commonRequests = 0
    func fetchCommonTypesOperation() -> CompoundOperationWrapper<Data?> { commonRequests += 1; return .init(targetOperation: ClosureOperation { self.data }) }
    func fetchChainTypesOperation(for chainId: SoraPassport.ChainModel.Id) -> CompoundOperationWrapper<Data?> { chainRequests.append(chainId); if let failure { return .init(targetOperation: ClosureOperation { throw failure }) }; return .init(targetOperation: ClosureOperation { self.data }) }
    func saveCommonTypesOperation(data closure: @escaping () throws -> Data) -> CompoundOperationWrapper<Void> { XCTFail("Hot boot must not mutate cache"); return .init(targetOperation: ClosureOperation { () }) }
    func saveChainTypesOperation(for chainId: SoraPassport.ChainModel.Id, data closure: @escaping () throws -> Data) -> CompoundOperationWrapper<Void> { XCTFail("Hot boot must not mutate cache"); return .init(targetOperation: ClosureOperation { () }) }
}
