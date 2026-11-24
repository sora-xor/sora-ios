// SPDX-License-Identifier: Apache-2.0
import BigInt
import Foundation
import SoraFoundation
import IrohaCrypto
import RobinHood
import SSFUtils
import XCTest

@testable import SoraPassport

private enum StorageSourceError: Error { case offline }

/// Real in-memory Core Data stores exercise filtering and provider reuse without network access.
final class StorageFactoryBoundaryTests: XCTestCase {
    private func run<T>(_ operation: BaseOperation<T>) async throws -> T {
        let completed = expectation(description: "repository operation")
        operation.completionBlock = { completed.fulfill() }
        let queue = OperationQueue(); queue.addOperation(operation)
        await fulfillment(of: [completed], timeout: 3)
        return try XCTUnwrap(operation.result).get()
    }
    private func fetch<T>(_ provider: StreamableProvider<T>) async throws -> [T] {
        let completed = expectation(description: "provider read")
        var result: Result<[T], Error>?
        _ = provider.fetch(offset: 0, count: 100, synchronized: true) { result = $0; completed.fulfill() }
        await fulfillment(of: [completed], timeout: 3)
        return try XCTUnwrap(result).get()
    }
    func testStorageProviderReturnsOnlyItsExactKey() async throws {
        let facade = SubstrateStorageTestFacade()
        let repository: CoreDataRepository<ChainStorageItem, CDChainStorageItem> = facade.createRepository()
        _ = try await run(repository.saveOperation({ [ChainStorageItem(identifier: "wanted", data: Data([7])), ChainStorageItem(identifier: "other", data: Data([9]))] }, { [] }))
        let factory = SubstrateDataProviderFactory(facade: facade, operationManager: OperationManager())
        let values = try await fetch(factory.createStorageProvider(for: "wanted"))
        XCTAssertEqual(values.map(\.identifier), ["wanted"]); XCTAssertEqual(values.first?.data, Data([7]))
        let absent = try await fetch(factory.createStorageProvider(for: "missing")); XCTAssertTrue(absent.isEmpty)
    }
    func testRuntimeMetadataProviderCannotReturnAnotherChainsSnapshot() async throws {
        let facade = SubstrateStorageTestFacade()
        let repository: CoreDataRepository<SoraPassport.RuntimeMetadataItem, CDRuntimeMetadataItem> = facade.createRepository()
        let expected = SoraPassport.RuntimeMetadataItem(chain: Chain.sora.genesisHash(), version: 133, txVersion: 131, metadata: Data([1,2,3]), resolver: nil)
        let other = SoraPassport.RuntimeMetadataItem(chain: "another-chain", version: 9, txVersion: 7, metadata: Data([9]), resolver: nil)
        _ = try await run(repository.saveOperation({ [expected, other] }, { [] }))
        let factory = SubstrateDataProviderFactory(facade: facade, operationManager: OperationManager())
        let values = try await fetch(factory.createRuntimeMetadataItemProvider(for: .sora))
        XCTAssertEqual(values.map(\.chain), [expected.chain]); XCTAssertEqual(values.first?.version, 133); XCTAssertEqual(values.first?.metadata, expected.metadata)
    }
}

final class RuntimeHotBootBoundaryTests: XCTestCase {
    private func chain(_ id: String) -> SoraPassport.ChainModel {
        SoraPassport.ChainModel(chainId: id, name: id, nodes: [], addressPrefix: 69, types: nil, icon: nil, iosMinAppVersion: nil)
    }
    private func metadata(_ id: String, version: UInt32 = 133) -> SoraPassport.RuntimeMetadataItem {
        SoraPassport.RuntimeMetadataItem(chain: id, version: version, txVersion: 131, metadata: Data([1,2,3]), resolver: nil)
    }
    private func boot(chains: [SoraPassport.ChainModel], metadata: [SoraPassport.RuntimeMetadataItem], common: Data? = Data([4,5]), failure: Bool = false) async throws -> HotBootPoolRecorder {
        let chainsRepository = InMemoryDataProviderRepository<SoraPassport.ChainModel>()
        let runtimeRepository = InMemoryDataProviderRepository<SoraPassport.RuntimeMetadataItem>()
        let saves = [chainsRepository.saveOperation({ chains }, { [] }), runtimeRepository.saveOperation({ metadata }, { [] })]
        saves.forEach { $0.start() }; for save in saves { try XCTUnwrap(save.result).get() }
        let queue = OperationQueue(), pool = HotBootPoolRecorder(), files = HotBootFiles(common: common, failure: failure)
        let builder = SnapshotHotBootBuilder(runtimeProviderPool: pool, chainRepository: AnyDataProviderRepository(chainsRepository), filesOperationFactory: files, runtimeItemRepository: AnyDataProviderRepository(runtimeRepository), operationQueue: queue, logger: Logger.shared)
        let expectedRecords = common == nil || failure ? 0 : chains.filter { chain in metadata.contains { $0.chain == chain.chainId } }.count
        var waits = [XCTestExpectation]()
        if expectedRecords > 0 {
            let recorded = expectation(description: "hot runtimes published")
            recorded.expectedFulfillmentCount = expectedRecords
            pool.onRecord = { recorded.fulfill() }
            waits.append(recorded)
        }
        builder.startHotBoot()
        let completed = expectation(description: "hot boot operations completed")
        queue.addBarrierBlock { completed.fulfill() }
        waits.append(completed)
        await fulfillment(of: waits, timeout: 5)
        withExtendedLifetime(builder) {}
        return pool
    }
    func testCachedRuntimeAndCommonTypesAreBoundToTheirMatchingChain() async throws {
        let pool = try await boot(chains: [chain("one"), chain("two")], metadata: [metadata("two", version: 17), metadata("one")])
        XCTAssertEqual(Set(pool.records.map { $0.0 }), ["one", "two"])
        XCTAssertTrue(pool.records.allSatisfy { $0.0 == $0.1.chain && $0.2 == Data([4,5]) })
        XCTAssertEqual(pool.records.first { $0.0 == "two" }?.1.version, 17)
    }
    func testMissingRuntimeLeavesOnlyThatChainForNormalStartup() async throws {
        let pool = try await boot(chains: [chain("one"), chain("two")], metadata: [metadata("two"), metadata("unconfigured")])
        XCTAssertEqual(pool.records.map { $0.0 }, ["two"])
    }
    func testMissingCommonTypesCannotPublishAPartialHotSnapshot() async throws {
        let pool = try await boot(chains: [chain("one")], metadata: [metadata("one")], common: nil)
        XCTAssertTrue(pool.records.isEmpty)
    }
    func testFailedCommonTypesReadCannotPublishACachedRuntime() async throws {
        let pool = try await boot(chains: [chain("one")], metadata: [metadata("one")], failure: true)
        XCTAssertTrue(pool.records.isEmpty)
    }
    func testUnconfiguredRuntimeCacheDoesNotCreateInventedChains() async throws {
        let pool = try await boot(chains: [], metadata: [metadata("one")])
        XCTAssertTrue(pool.records.isEmpty)
    }
}
private final class HotBootFiles: RuntimeFilesOperationFactoryProtocol {
    let common: Data?; let failure: Bool
    init(common: Data?, failure: Bool) { self.common = common; self.failure = failure }
    func fetchCommonTypesOperation() -> CompoundOperationWrapper<Data?> {
        CompoundOperationWrapper(targetOperation: ClosureOperation { if self.failure { throw StorageSourceError.offline }; return self.common })
    }
    func fetchChainTypesOperation(for chainId: String) -> CompoundOperationWrapper<Data?> { XCTFail("Unexpected chain read"); return CompoundOperationWrapper(targetOperation: ClosureOperation { nil }) }
    func saveCommonTypesOperation(data closure: @escaping () throws -> Data) -> CompoundOperationWrapper<Void> { XCTFail("Hot boot must not write files"); return CompoundOperationWrapper(targetOperation: ClosureOperation {}) }
    func saveChainTypesOperation(for chainId: String, data closure: @escaping () throws -> Data) -> CompoundOperationWrapper<Void> { XCTFail("Hot boot must not write files"); return CompoundOperationWrapper(targetOperation: ClosureOperation {}) }
}
private final class HotBootPoolRecorder: RuntimeProviderPoolProtocol {
    var onRecord: (() -> Void)?
    var records: [(String, SoraPassport.RuntimeMetadataItem, Data)] = []
    func setupRuntimeProvider(for chain: SoraPassport.ChainModel) -> RuntimeProviderProtocol { XCTFail("Unexpected cold startup"); return HotBootRuntime(chainId: chain.chainId) }
    func setupHotRuntimeProvider(for chain: SoraPassport.ChainModel, runtimeItem: SoraPassport.RuntimeMetadataItem, commonTypes: Data) -> RuntimeProviderProtocol {
        records.append((chain.chainId, runtimeItem, commonTypes)); onRecord?(); return HotBootRuntime(chainId: chain.chainId)
    }
    func destroyRuntimeProvider(for chainId: String) { XCTFail("Unexpected destruction") }
    func getRuntimeProvider(for chainId: String) -> RuntimeProviderProtocol? { nil }
}
private final class HotBootRuntime: RuntimeProviderProtocol {
    let chainId: String; var snapshot: RuntimeSnapshot? { nil }
    init(chainId: String) { self.chainId = chainId }
    func setup() {}; func setupHot() {}; func replaceTypesUsage(_ usage: SoraPassport.ChainModel.TypesUsage) {}; func cleanup() {}
    func fetchCoderFactoryOperation(with timeout: TimeInterval, closure: SoraPassport.RuntimeMetadataClosure?) -> BaseOperation<RuntimeCoderFactoryProtocol> { ClosureOperation { throw StorageSourceError.offline } }
}

final class AssetManagerOrderingBoundaryTests: XCTestCase {
    private let xor = WalletAssetId.xor.rawValue, val = WalletAssetId.val.rawValue
    private func asset(_ id: String, symbol: String, visible: Bool = true) -> AssetInfo {
        AssetInfo(id: id, symbol: symbol, chainId: "", precision: 18, icon: nil, displayName: symbol, visible: visible)
    }
    private func wallet(_ id: String, symbol: String) -> WalletAsset {
        WalletAsset(identifier: id, name: LocalizableResource { _ in symbol }, symbol: symbol, precision: 18)
    }
    private func manager() -> AssetManager {
        let storage = SubstrateStorageTestFacade(), queue = OperationQueue()
        let repository = ChainRepositoryFactory(storageFacade: storage).createRepository()
        let observable = CoreDataContextObservable(service: storage.databaseService, mapper: repository.dataMapper, predicate: { _ in true })
        observable.start { XCTAssertNil($0) }
        let provider = StreamableProvider(source: AnyStreamableSource(SoraPassport.EmptyStreamableSource<ChainModel>()),
            repository: AnyDataProviderRepository(repository), observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: OperationManager(operationQueue: queue))
        let assets: CoreDataRepository<AssetInfo, CDAssetInfo> = storage.createRepository()
        let result = AssetManager(storage: AnyDataProviderRepository(assets), chainProvider: provider, chainId: "public-chain",
            operationManager: OperationManager(operationQueue: queue), eventCenter: EventCenter())
        result.setup(for: SelectedWalletSettings(storageFacade: UserDataStorageTestFacade(), operationQueue: queue))
        return result
    }
    func testUnknownAssetLookupDoesNotFabricateMetadata() {
        let m = manager(); XCTAssertNil(m.assetInfo(for: "unknown")); XCTAssertEqual(m.visibleCount(), 1)
        m.saveAssetList([asset(xor, symbol: "XOR")]); XCTAssertEqual(m.assetInfo(for: xor)?.symbol, "XOR"); XCTAssertNil(m.assetInfo(for: val))
    }
    func testSavedOrderIsUsedInsteadOfAlphabeticSymbolOrder() {
        let m = manager(); m.saveAssetList([asset(xor, symbol: "XOR"), asset(val, symbol: "VAL")])
        let values = [wallet(val, symbol: "VAL"), wallet(xor, symbol: "XOR")]
        XCTAssertEqual(m.sortedAssets(values, onlyVisible: false).map(\.identifier), [xor, val]); XCTAssertEqual(m.visibleCount(), 2)
    }
    func testUnorderedAssetsUseStableAlphabeticalFallback() {
        let m = manager(); let values = [wallet("z", symbol: "ZZZ"), wallet("a", symbol: "AAA")]
        XCTAssertEqual(m.sortedAssets(values).map(\.identifier), ["a", "z"])
    }
    func testHiddenTokensAreFilteredButTheFeeAssetAlwaysRemainsAvailable() {
        let m = manager(); m.saveAssetList([asset(xor, symbol: "XOR", visible: false), asset(val, symbol: "VAL", visible: false)])
        XCTAssertEqual(m.sortedAssets([wallet(xor, symbol: "XOR"), wallet(val, symbol: "VAL")], onlyVisible: true).map(\.identifier), [xor])
        XCTAssertEqual(m.visibleCount(), 1)
    }
    func testVisibleFeeBalanceAddsTheCapitalReloadMarker() {
        let m = manager(); m.saveAssetList([asset(xor, symbol: "XOR"), asset(val, symbol: "VAL")])
        let ordered = m.sortedAssets([wallet(val, symbol: "VAL"), wallet(xor, symbol: "XOR")], onlyVisible: true)
        XCTAssertEqual(ordered.map(\.identifier), [xor, val, WalletAsset.dummyAsset.identifier])
    }
    func testTokensMissingMetadataRemainVisibleRatherThanDisappearing() {
        let m = manager(); XCTAssertEqual(m.sortedAssets([wallet("unknown", symbol: "NEW")], onlyVisible: true).map(\.identifier), ["unknown"])
    }
    func testDefaultAssetArrangementPrioritizesBuiltInsAndHidesUnselectedCustomTokens() {
        let values = [asset("custom-z", symbol: "ZZZ"), asset(val, symbol: "VAL"), asset("custom-a", symbol: "AAA"), asset(xor, symbol: "XOR")]
        let arranged = AssetManager.arrangedAssets(values, settings: nil)
        XCTAssertEqual(arranged.map(\.identifier), [xor, val, "custom-a", "custom-z"])
        XCTAssertEqual(arranged.map(\.visible), [true, true, false, false])
    }
    func testSavingAReorderedListKeepsTheUnavailableTokensSavedPositionOnlyOnce() {
        let previous = AccountSettings(visibleAssetIds: ["missing", xor, "missing"], orderedAssetIds: ["missing", "missing", xor, val])
        let selection = AssetManager.savedSelection(for: [asset(val, symbol: "VAL"), asset(xor, symbol: "XOR", visible: false)], keeping: previous)
        XCTAssertEqual(selection.ordered, ["missing", val, xor]); XCTAssertEqual(selection.visible, [val, "missing"])
    }
}

final class CommonTypesRetryLifecycleTests: XCTestCase {
    private let bytes = Data("{\"types\":{\"Balance\":\"u128\"}}".utf8)
    private struct Fixture {
        let service: CommonTypesSyncService, files: TypesRetryFiles, fetch: TypesRetryFetch,
            events: TypesRetryEvents, retry: TypesRetryStrategy, queue: OperationQueue
    }
    private func make(_ results: [Result<Data, Error>], delay: TimeInterval? = nil, reviewed: Bool = false) -> Fixture {
        let files = TypesRetryFiles(), fetch = TypesRetryFetch(results), events = TypesRetryEvents(), retry = TypesRetryStrategy(delay), queue = OperationQueue()
        let service = CommonTypesSyncService(url: URL(string: "https://fixture.invalid/types.json"), filesOperationFactory: files,
            dataOperationFactory: fetch, eventCenter: events, operationQueue: queue, retryStrategy: retry, usesReviewedSoraBundle: reviewed)
        return Fixture(service: service, files: files, fetch: fetch, events: events, retry: retry, queue: queue)
    }
    private func waitFor(_ description: String, _ condition: @escaping () -> Bool) async {
        for _ in 0..<200 { if condition() { return }; try? await Task.sleep(nanoseconds: 5_000_000) }
        XCTAssertTrue(condition(), description)
    }
    func testSuccessfulRemoteTypesAreSavedBeforeTheirHashIsPublished() async throws {
        let f = make([.success(bytes)]); f.service.syncUp()
        await waitFor("hash published") { f.events.hashes.count == 1 }
        XCTAssertEqual(f.files.saved, [bytes]); XCTAssertEqual(f.events.hashes, [try StorageHasher.twox256.hash(data: bytes).toHex()])
        XCTAssertEqual(f.fetch.urls.map(\.absoluteString), ["https://fixture.invalid/types.json"])
        XCTAssertEqual(f.service.retryAttempt, 0); XCTAssertFalse(f.service.isSyncing)
    }
    func testDuplicateSyncDuringAQueuedPassDoesNotEnqueueAnotherFetch() async {
        let f = make([.success(bytes)]); f.queue.isSuspended = true
        f.service.syncUp(); f.service.syncUp(); XCTAssertTrue(f.service.isSyncing); XCTAssertEqual(f.fetch.urls.count, 1)
        f.queue.isSuspended = false; await waitFor("one completed pass") { f.events.hashes.count == 1 }
        XCTAssertEqual(f.files.saved.count, 1)
    }
    func testFetchFailureDoesNotSaveOrPublishAndRequestsFirstRetry() async {
        let f = make([.failure(TypesRetryFailure.offline)]); f.service.syncUp()
        await waitFor("retry requested") { f.retry.attempts.count == 1 }
        XCTAssertEqual(f.retry.attempts, [1]); XCTAssertTrue(f.files.saved.isEmpty); XCTAssertTrue(f.events.hashes.isEmpty)
        XCTAssertFalse(f.service.isSyncing); XCTAssertEqual(f.service.retryAttempt, 1)
    }
    func testSaveFailureDoesNotPublishAHashForUnpersistedTypes() async {
        let f = make([.success(bytes)]); f.files.failSave = true; f.service.syncUp()
        await waitFor("save failure retry") { f.retry.attempts.count == 1 }
        XCTAssertTrue(f.events.hashes.isEmpty); XCTAssertTrue(f.files.saved.isEmpty); XCTAssertEqual(f.service.retryAttempt, 1)
    }
    func testManualRetryCancelsTheScheduledBackoffAndResetsAttemptsOnSuccess() async {
        let f = make([.failure(TypesRetryFailure.offline), .success(bytes)], delay: 3600); f.service.syncUp()
        await waitFor("scheduled retry") { f.retry.attempts.count == 1 }
        f.service.syncUp(); await waitFor("manual recovery") { f.events.hashes.count == 1 }
        XCTAssertEqual(f.fetch.urls.count, 2); XCTAssertEqual(f.service.retryAttempt, 0); XCTAssertEqual(f.files.saved, [bytes])
    }
    func testScheduledRetryPerformsAnotherFetchAndPublishesOnlySuccess() async {
        let f = make([.failure(TypesRetryFailure.offline), .success(bytes)], delay: 0.02); f.service.syncUp()
        await waitFor("scheduled recovery") { f.events.hashes.count == 1 }
        XCTAssertEqual(f.fetch.urls.count, 2); XCTAssertEqual(f.retry.attempts, [1]); XCTAssertEqual(f.service.retryAttempt, 0)
    }
    func testRepeatedFailuresIncrementRetryAttemptWithoutPublishing() async {
        let f = make([.failure(TypesRetryFailure.offline), .failure(TypesRetryFailure.offline)]); f.service.syncUp()
        await waitFor("first retry") { f.retry.attempts.count == 1 }; f.service.syncUp()
        await waitFor("second retry") { f.retry.attempts.count == 2 }
        XCTAssertEqual(f.retry.attempts, [1, 2]); XCTAssertEqual(f.service.retryAttempt, 2); XCTAssertTrue(f.events.hashes.isEmpty)
    }
    func testReviewedBundleBypassesRemoteFetchAndPublishesItsValidatedHash() async throws {
        let f = make([], reviewed: true); f.service.syncUp()
        await waitFor("reviewed bundle saved") { f.events.hashes.count == 1 }
        let reviewed = try ReviewedSoraRuntimeSnapshotAdmission.loadReviewedCommonTypes()
        XCTAssertEqual(f.files.saved, [reviewed]); XCTAssertTrue(f.fetch.urls.isEmpty)
        XCTAssertEqual(f.events.hashes, [try StorageHasher.twox256.hash(data: reviewed).toHex()])
    }
}
private enum TypesRetryFailure: Error { case offline }
private final class TypesRetryFetch: DataOperationFactoryProtocol {
    private let lock = NSLock(); private var results: [Result<Data, Error>], storedURLs: [URL] = []
    var urls: [URL] { lock.lock(); defer { lock.unlock() }; return storedURLs }
    init(_ results: [Result<Data, Error>]) { self.results = results }
    func fetchData(from url: URL) -> BaseOperation<Data> {
        lock.lock(); storedURLs.append(url); let result = results.isEmpty ? .failure(TypesRetryFailure.offline) : results.removeFirst(); lock.unlock()
        return ClosureOperation { try result.get() }
    }
}
private final class TypesRetryFiles: RuntimeFilesOperationFactoryProtocol {
    private let lock = NSLock(); private var values: [Data] = []
    var failSave = false
    var saved: [Data] { lock.lock(); defer { lock.unlock() }; return values }
    func saveCommonTypesOperation(data closure: @escaping () throws -> Data) -> CompoundOperationWrapper<Void> {
        CompoundOperationWrapper(targetOperation: ClosureOperation {
            let data = try closure(); if self.failSave { throw TypesRetryFailure.offline }
            self.lock.lock(); self.values.append(data); self.lock.unlock()
        })
    }
    func fetchCommonTypesOperation() -> CompoundOperationWrapper<Data?> { XCTFail("Unexpected cache read"); return CompoundOperationWrapper(targetOperation: ClosureOperation { nil }) }
    func fetchChainTypesOperation(for chainId: String) -> CompoundOperationWrapper<Data?> { XCTFail("Unexpected chain read"); return CompoundOperationWrapper(targetOperation: ClosureOperation { nil }) }
    func saveChainTypesOperation(for chainId: String, data closure: @escaping () throws -> Data) -> CompoundOperationWrapper<Void> { XCTFail("Unexpected chain write"); return CompoundOperationWrapper(targetOperation: ClosureOperation {}) }
}
private final class TypesRetryStrategy: SoraPassport.ReconnectionStrategyProtocol {
    private let lock = NSLock(); private var values: [Int] = []; let delay: TimeInterval?
    var attempts: [Int] { lock.lock(); defer { lock.unlock() }; return values }
    init(_ delay: TimeInterval?) { self.delay = delay }
    func reconnectAfter(attempt: Int) -> TimeInterval? { lock.lock(); defer { lock.unlock() }; values.append(attempt); return delay }
}
private final class TypesRetryEvents: EventCenterProtocol {
    private let lock = NSLock(); private var values: [String] = []
    var hashes: [String] { lock.lock(); defer { lock.unlock() }; return values }
    func notify(with event: EventProtocol) { if let event = event as? RuntimeCommonTypesSyncCompleted { lock.lock(); values.append(event.fileHash); lock.unlock() } }
    func notify(with event: EventProtocol, completionOnMain: @escaping () -> Void) { notify(with: event); DispatchQueue.main.async(execute: completionOnMain) }
    func add(observer: EventVisitorProtocol, dispatchIn queue: DispatchQueue?) {}
    func remove(observer: EventVisitorProtocol) {}
}
