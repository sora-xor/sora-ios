// SPDX-License-Identifier: BSD-4-Clause
import Foundation
import RobinHood
import SSFUtils
import XCTest

@testable import SoraPassport

final class RuntimeSnapshotAssemblyTests: XCTestCase {
  private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
  private static let metadata = try! Data(
    contentsOf: root.appendingPathComponent("Fixtures/Modernization/sora2-metadata-spec133.scale"))
  private static let common = try! Data(
    contentsOf: root.appendingPathComponent("SoraPassport/Resources/runtime-default.json"))
  private static let own = try! Data(
    contentsOf: root.appendingPathComponent("SoraPassport/Resources/runtime-sora.json"))
  private func make(chain: String = "generic-fixture") -> SnapshotAssemblyFixture {
    let f = SnapshotAssemblyFixture(chain: chain)
    f.files.common = Self.common
    f.files.own = Self.own
    f.repository.item = .init(
      chain: chain, version: 133, txVersion: 131, metadata: Self.metadata, resolver: nil)
    return f
  }
  private func run(
    _ f: SnapshotAssemblyFixture, _ usage: ChainModel.TypesUsage, _ hasher: StorageHasher = .twox256
  ) throws -> RuntimeSnapshot {
    let w = f.subject.createRuntimeSnapshotWrapper(for: usage, dataHasher: hasher)
    let q = OperationQueue()
    q.qualityOfService = .userInitiated
    q.addOperations(w.allOperations, waitUntilFinished: true)
    let result = try XCTUnwrap(w.targetOperation.result)
    let snapshot = try result.get()
    return try XCTUnwrap(snapshot)
  }
  func testCommonOnlySnapshotUsesTheCommonHashAndNoChainHash() throws {
    let f = make()
    let s = try run(f, .onlyCommon)
    XCTAssertEqual(s.localCommonHash, try StorageHasher.twox256.hash(data: Self.common).toHex())
    XCTAssertNil(s.localChainHash)
    XCTAssertEqual(f.files.commonReads, 1)
    XCTAssertTrue(f.files.chainReads.isEmpty)
  }
  func testCombinedSnapshotBindsBothActualRegistryContents() throws {
    let f = make()
    let s = try run(f, .both)
    XCTAssertEqual(s.localCommonHash, try StorageHasher.twox256.hash(data: Self.common).toHex())
    XCTAssertEqual(s.localChainHash, try StorageHasher.twox256.hash(data: Self.own).toHex())
    XCTAssertEqual(f.files.chainReads, ["generic-fixture"])
  }
  func testOwnOnlySnapshotDoesNotReadCommonTypes() throws {
    let f = make()
    let s = try run(f, .onlyOwn)
    XCTAssertNil(s.localCommonHash)
    XCTAssertEqual(f.files.commonReads, 0)
    XCTAssertEqual(f.files.chainReads, ["generic-fixture"])
  }
  func testAllUsageModesPreserveMetadataSpecAndTransactionVersions() throws {
    for usage in [ChainModel.TypesUsage.onlyCommon, .onlyOwn, .both] {
      let s = try run(make(), usage)
      XCTAssertEqual(s.specVersion, 133)
      XCTAssertEqual(s.txVersion, 131)
      XCTAssertNotNil(s.metadata.getConstant(in: "System", constantName: "Version"))
    }
  }
  func testRepositoryFetchUsesTheRequestedChainIdentity() throws {
    let f = make()
    _ = try run(f, .both)
    XCTAssertEqual(f.repository.requested, ["generic-fixture"])
  }
  func testRequestedHasherControlsBothSnapshotHashes() throws {
    let f = make()
    let s = try run(f, .both, .blake256)
    XCTAssertEqual(s.localCommonHash, try StorageHasher.blake256.hash(data: Self.common).toHex())
    XCTAssertEqual(s.localChainHash, try StorageHasher.blake256.hash(data: Self.own).toHex())
  }
  func testCommonOnlyMissingTypesFailsInsteadOfBuildingEmptyCatalog() {
    let f = make()
    f.files.common = nil
    XCTAssertThrowsError(try run(f, .onlyCommon))
  }
  func testOwnOnlyMissingTypesFailsInsteadOfFallingBackToCommon() {
    let f = make()
    f.files.own = nil
    XCTAssertThrowsError(try run(f, .onlyOwn))
    XCTAssertEqual(f.files.commonReads, 0)
  }
  func testCombinedMissingCommonTypesFails() {
    let f = make()
    f.files.common = nil
    XCTAssertThrowsError(try run(f, .both))
  }
  func testCombinedMissingChainTypesFails() {
    let f = make()
    f.files.own = nil
    XCTAssertThrowsError(try run(f, .both))
  }
  func testCommonOnlyMissingMetadataFails() {
    let f = make()
    f.repository.item = nil
    XCTAssertThrowsError(try run(f, .onlyCommon))
  }
  func testOwnOnlyMissingMetadataFails() {
    let f = make()
    f.repository.item = nil
    XCTAssertThrowsError(try run(f, .onlyOwn))
  }
  func testCombinedMissingMetadataFails() {
    let f = make()
    f.repository.item = nil
    XCTAssertThrowsError(try run(f, .both))
  }
  func testCommonReadFailureIsPropagated() {
    let f = make()
    f.files.commonError = SnapshotAssemblyFailure.read
    XCTAssertThrowsError(try run(f, .onlyCommon)) { XCTAssertTrue($0 is SnapshotAssemblyFailure) }
  }
  func testChainReadFailureIsPropagated() {
    let f = make()
    f.files.chainError = SnapshotAssemblyFailure.read
    XCTAssertThrowsError(try run(f, .both)) { XCTAssertTrue($0 is SnapshotAssemblyFailure) }
  }
  func testMetadataReadFailureIsPropagatedInEveryMode() {
    for usage in [ChainModel.TypesUsage.onlyCommon, .onlyOwn, .both] {
      let f = make()
      f.repository.error = SnapshotAssemblyFailure.read
      XCTAssertThrowsError(try run(f, usage)) { XCTAssertTrue($0 is SnapshotAssemblyFailure) }
    }
  }
  func testMalformedCommonTypesCannotCreateSnapshot() {
    let f = make()
    f.files.common = Data("not JSON".utf8)
    XCTAssertThrowsError(try run(f, .onlyCommon))
  }
  func testMalformedChainTypesCannotCreateCombinedSnapshot() {
    let f = make()
    f.files.own = Data("not JSON".utf8)
    XCTAssertThrowsError(try run(f, .both))
  }
  func testMalformedMetadataCannotCreateGenericSnapshot() {
    let f = make()
    f.repository.item = .init(
      chain: f.chain, version: 1, txVersion: 1, metadata: Data([0, 1, 2]), resolver: nil)
    XCTAssertThrowsError(try run(f, .onlyCommon))
  }
  func testSoraMainnetRejectsCommonOnlyTypeResolution() {
    XCTAssertThrowsError(try run(make(chain: Chain.sora.genesisHash()), .onlyCommon)) {
      XCTAssertEqual($0 as? RuntimeSnapshotFactoryError, .unreviewedSoraRuntime)
    }
  }
  func testSoraMainnetRejectsMixedTypeResolution() {
    XCTAssertThrowsError(try run(make(chain: Chain.sora.genesisHash()), .both)) {
      XCTAssertEqual($0 as? RuntimeSnapshotFactoryError, .unreviewedSoraRuntime)
    }
  }
  func testSoraMainnetOwnRegistryBuildsThroughTheProductionWrapper() throws {
    let s = try run(make(chain: Chain.sora.genesisHash()), .onlyOwn)
    XCTAssertEqual(s.specVersion, 133)
    XCTAssertNotNil(s.localChainHash)
  }
  func testSoraMainnetRejectsAlteredTypeRegistry() {
    let f = make(chain: Chain.sora.genesisHash())
    f.files.own?.append(0x20)
    XCTAssertThrowsError(try run(f, .onlyOwn))
  }
  func testSoraMainnetRejectsMetadataStoredUnderWrongSpec() {
    let f = make(chain: Chain.sora.genesisHash())
    f.repository.item = .init(
      chain: f.chain, version: 132, txVersion: 131, metadata: Self.metadata, resolver: nil)
    XCTAssertThrowsError(try run(f, .onlyOwn))
  }
  func testSoraMainnetRejectsMetadataStoredUnderWrongTransactionVersion() {
    let f = make(chain: Chain.sora.genesisHash())
    f.repository.item = .init(
      chain: f.chain, version: 133, txVersion: 1, metadata: Self.metadata, resolver: nil)
    XCTAssertThrowsError(try run(f, .onlyOwn))
  }
  func testSoraMainnetRejectsTrailingMetadataBytes() {
    let f = make(chain: Chain.sora.genesisHash())
    f.repository.item = .init(
      chain: f.chain, version: 133, txVersion: 131, metadata: Self.metadata + Data([0]),
      resolver: nil)
    XCTAssertThrowsError(try run(f, .onlyOwn))
  }
  func testSnapshotConstructionIsLazyUntilOperationsExecute() {
    let f = make()
    _ = f.subject.createRuntimeSnapshotWrapper(for: .both, dataHasher: .twox256)
    XCTAssertEqual(f.files.executedReads, 0)
    XCTAssertTrue(f.repository.requested.isEmpty)
  }
  func testSnapshotBuildNeverWritesRegistryOrMetadata() {
    let f = make()
    XCTAssertNoThrow(try run(f, .both))
    XCTAssertEqual(f.files.writes, 0)
    XCTAssertEqual(f.repository.writes, 0)
  }
}
private enum SnapshotAssemblyFailure: Error { case read }
private final class SnapshotAssemblyFixture {
  let chain: String
  let files = SnapshotAssemblyFiles(), repository = SnapshotAssemblyRepository()
  lazy var subject = RuntimeSnapshotFactory(
    chainId: chain, filesOperationFactory: files, repository: AnyDataProviderRepository(repository))
  init(chain: String) { self.chain = chain }
}
private final class SnapshotAssemblyFiles: RuntimeFilesOperationFactoryProtocol {
  private let lock = NSLock()
  private func didRead() {
    lock.lock()
    executedReads += 1
    lock.unlock()
  }
  var common: Data?, own: Data?, commonError: Error?, chainError: Error?
  var commonReads = 0, chainReads = [String](), executedReads = 0, writes = 0
  func fetchCommonTypesOperation() -> CompoundOperationWrapper<Data?> {
    commonReads += 1
    return .init(
      targetOperation: ClosureOperation {
        self.didRead()
        if let e = self.commonError { throw e }
        return self.common
      })
  }
  func fetchChainTypesOperation(for chainId: ChainModel.Id) -> CompoundOperationWrapper<Data?> {
    chainReads.append(chainId)
    return .init(
      targetOperation: ClosureOperation {
        self.didRead()
        if let e = self.chainError { throw e }
        return self.own
      })
  }
  func saveCommonTypesOperation(data closure: @escaping () throws -> Data)
    -> CompoundOperationWrapper<Void>
  {
    .init(
      targetOperation: ClosureOperation {
        self.writes += 1
        XCTFail("unexpected registry write")
      })
  }
  func saveChainTypesOperation(
    for chainId: ChainModel.Id, data closure: @escaping () throws -> Data
  ) -> CompoundOperationWrapper<Void> { saveCommonTypesOperation(data: closure) }
}
private final class SnapshotAssemblyRepository: DataProviderRepositoryProtocol {
  typealias Model = SoraPassport.RuntimeMetadataItem
  var item: Model?, error: Error?, requested = [String](), writes = 0
  func fetchOperation(by id: @escaping () throws -> String, options: RepositoryFetchOptions)
    -> BaseOperation<Model?>
  {
    ClosureOperation {
      self.requested.append(try id())
      if let e = self.error { throw e }
      return self.item
    }
  }
  func fetchAllOperation(with options: RepositoryFetchOptions) -> BaseOperation<[Model]> {
    ClosureOperation { self.item.map { [$0] } ?? [] }
  }
  func fetchOperation(by ids: @escaping () throws -> [String], options: RepositoryFetchOptions)
    -> BaseOperation<[Model]>
  { fetchAllOperation(with: options) }
  func fetchOperation(by request: RepositorySliceRequest, options: RepositoryFetchOptions)
    -> BaseOperation<[Model]>
  { fetchAllOperation(with: options) }
  func fetchCountOperation() -> BaseOperation<Int> { ClosureOperation { self.item == nil ? 0 : 1 } }
  func saveOperation(
    _ updates: @escaping () throws -> [Model], _ deletes: @escaping () throws -> [String]
  ) -> BaseOperation<Void> {
    ClosureOperation {
      self.writes += 1
      XCTFail("unexpected metadata mutation")
    }
  }
  func saveBatchOperation(
    _ updates: @escaping () throws -> [Model], _ deletes: @escaping () throws -> [String]
  ) -> BaseOperation<Void> { saveOperation(updates, deletes) }
  func replaceOperation(_ models: @escaping () throws -> [Model]) -> BaseOperation<Void> {
    saveOperation(models, { [] })
  }
  func deleteAllOperation() -> BaseOperation<Void> { saveOperation({ [] }, { [] }) }
}
