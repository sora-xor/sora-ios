// SPDX-License-Identifier: BSD-4-Clause
import BigInt
import Foundation
import IrohaCrypto
import RobinHood
import sorawallet
import SSFUtils
import XCTest
@testable import SoraPassport

@MainActor
final class AccountPoolsServiceFlowTests: XCTestCase {
    private func equal<T: Equatable>(_ a: T, _ b: T, file: StaticString = #filePath, line: UInt = #line) { XCTAssertEqual(a, b, file: file, line: line) }
    private func settle() async { try? await Task.sleep(nanoseconds: 80_000_000) }
    private func load(_ f: PoolServiceFixture) async {
        let done = expectation(description: "pools loaded"); f.output.onLoad = { done.fulfill() }
        f.service.loadAccountPools(); await fulfillment(of: [done], timeout: 3)
        f.output.onLoad = nil; await settle()
    }
    private func saved(_ f: PoolServiceFixture) throws -> [PoolInfo] { let op = f.repository.fetchAllOperation(with: .init()); op.start(); return try XCTUnwrap(op.result).get() }
    func testConstructorHonorsTheProvidedOperationManager() throws {
        let f = try PoolServiceFixture(); XCTAssertTrue((f.service.operationManager as AnyObject) === f.manager)
    }
    func testRemotePoolDetailsReachTheDelegateAndRepository() async throws {
        let f = try PoolServiceFixture(); f.provider.details = [f.details()]; await load(f)
        let pool = try XCTUnwrap(f.service.getAccountPools().first)
        equal(pool.accountId, "public-fixture"); equal(pool.baseAssetId, f.xor); equal(pool.targetAssetId, f.val)
        equal(pool.accountPoolBalance, 5); equal(pool.yourPoolShare, 25); equal(pool.targetAssetPooledByAccount, 100)
        equal(try saved(f).map(\.poolId), [pool.poolId]); equal(f.output.values.last?.map(\.poolId), [pool.poolId])
    }
    func testRemoteFailureCannotErasePreviouslyLoadedPools() async throws {
        let f = try PoolServiceFixture(); f.provider.details = [f.details()]; await load(f)
        let id = try XCTUnwrap(f.service.getAccountPools().first?.poolId)
        f.provider.failure = PoolServiceFailure.offline; f.service.loadAccountPools(); await settle()
        equal(f.service.getAccountPools().map(\.poolId), [id]); equal(try saved(f).map(\.poolId), [id])
        equal(f.output.values.count, 1)
    }
    func testAuthoritativeEmptyResultRemovesExistingPools() async throws {
        let f = try PoolServiceFixture(); f.provider.details = [f.details()]; await load(f)
        f.provider.details = []; await load(f)
        equal(f.service.getAccountPools().count, 0); equal(try saved(f).count, 0)
    }
    func testDifferentWalletsHaveDistinctPersistentPoolIdentities() async throws {
        let first = try PoolServiceFixture(); first.provider.details = [first.details()]; await load(first)
        let second = try PoolServiceFixture(); second.provider.accountSettings = WalletAccountSettings(accountId: "another-wallet", assets: [])
        second.provider.details = [second.details()]; await load(second)
        XCTAssertNotEqual(first.service.getAccountPools().first?.poolId, second.service.getAccountPools().first?.poolId)
    }
    func testDistinctPairsCannotOverwriteEachOtherInStorage() async throws {
        let f = try PoolServiceFixture(); let first = f.details()
        let second = PoolDetails(baseAsset: f.xor, targetAsset: f.pswap, yourPoolShare: 0, baseAssetPooledByAccount: 0, targetAssetPooledByAccount: 0, baseAssetPooledTotal: 1, targetAssetPooledTotal: 2, totalIssuances: 3, baseAssetReserves: 1, targetAssetReserves: 2, accountPoolBalance: 0, farms: [])
        f.provider.details = [first, second]; await load(f)
        equal(Set(f.service.getAccountPools().map(\.poolId)).count, 2); equal(try saved(f).count, 2)
    }
    func testLegacyPoolIdentityMigrationPreservesFavoriteAndRemovesOldRow() async throws {
        let f = try PoolServiceFixture(); let legacy = f.pool("legacy-id", favorite: false)
        f.service.updatePools([legacy]); await settle(); f.provider.details = [f.details()]; await load(f)
        let current = try XCTUnwrap(f.service.getAccountPools().first)
        equal(current.isFavorite, false); XCTAssertNotEqual(current.poolId, "legacy-id"); equal(try saved(f).map(\.poolId), [current.poolId])
    }
    func testLegacyPoolIdentityMigrationPreservesTheUsersOrder() async throws {
        let f = try PoolServiceFixture(); f.service.updatePools([f.pool("second", target: f.pswap), f.pool("first")]); await settle()
        let first = f.details(); let second = PoolDetails(baseAsset: f.xor, targetAsset: f.pswap, yourPoolShare: 0, baseAssetPooledByAccount: 0, targetAssetPooledByAccount: 0, baseAssetPooledTotal: 1, targetAssetPooledTotal: 2, totalIssuances: 3, baseAssetReserves: 1, targetAssetReserves: 2, accountPoolBalance: 0, farms: [])
        f.provider.details = [first, second]; await load(f)
        equal(f.service.getAccountPools().map(\.targetAssetId), [f.pswap, f.val])
    }
    func testPoolIdentityIsStableAcrossRefreshes() async throws {
        let f = try PoolServiceFixture(); f.provider.details = [f.details()]; await load(f)
        let id = f.service.getAccountPools().first?.poolId; await load(f)
        equal(f.service.getAccountPools().first?.poolId, id); equal(try saved(f).count, 1)
    }
    func testRefreshPreservesTheUsersFavoriteChoice() async throws {
        let f = try PoolServiceFixture(); f.provider.details = [f.details()]; await load(f)
        var pool = try XCTUnwrap(f.service.getAccountPools().first); pool.isFavorite = false
        f.service.updatePools([pool]); await settle(); await load(f)
        equal(f.service.getAccountPools().first?.isFavorite, false)
    }
    func testUpdatingFavoriteDoesNotDropTheExactPoolTokenBalance() async throws {
        let f = try PoolServiceFixture(); let pool = f.pool("a", favorite: true)
        f.service.updatePools([pool]); await settle()
        equal(f.service.getAccountPools().first?.accountPoolBalance, 5)
        equal(try saved(f).first?.accountPoolBalance, 5)
    }
    func testReplacingVisibilityPreservesEveryFinancialField() throws {
        let f = try PoolServiceFixture(); let pool = f.pool("a"); var favorite = pool; favorite.isFavorite = true
        let updated = pool.replacingVisible(favorite)
        equal(updated.isFavorite, true); equal(updated.accountPoolBalance, 5); equal(updated.yourPoolShare, 25)
        equal(updated.baseAssetPooledByAccount, 50); equal(updated.targetAssetPooledByAccount, 100)
        equal(updated.totalIssuances, 20); equal(updated.baseAssetReserves, 200); equal(updated.targetAssetReserves, 400)
    }
    func testPoolLookupMatchesIdAndBothAssetSides() async throws {
        let f = try PoolServiceFixture(); f.service.updatePools([f.pool("a")]); await settle()
        equal(f.service.getPool(by: "a")?.poolId, "a"); XCTAssertNil(f.service.getPool(by: "missing"))
        equal(await f.service.getPool(by: f.xor, targetAssetId: f.val)?.poolId, "a"); equal(f.provider.singleRequests.count, 0)
    }
    func testAssetFilteringIncludesTheBaseAndTheTarget() throws {
        let f = try PoolServiceFixture(); f.service.updatePools([f.pool("a"), f.pool("b", base: f.val, target: f.pswap), f.pool("c", base: f.xor, target: f.pswap)])
        equal(f.service.loadPools(currentAsset: f.asset(f.val)).map(\.poolId), ["a", "b"])
        equal(f.service.loadTargetPools(for: f.val).map(\.poolId), ["b"])
    }
    func testFavoritePoolsAreOrderedBeforeOtherPools() throws {
        let f = try PoolServiceFixture(); f.service.updatePools([f.pool("a"), f.pool("b", favorite: true), f.pool("c")])
        equal(f.service.getAccountPools().map(\.poolId), ["b", "a", "c"])
    }
    func testSavedOrderingDoesNotPlaceUnknownPoolsBeforeKnownOnes() throws {
        let f = try PoolServiceFixture(); f.service.updatePools([f.pool("a"), f.pool("b"), f.pool("c")]); f.service.currentOrder = ["b"]
        equal(f.service.getAccountPools().first?.poolId, "b")
    }
    func testDuplicateDelegateRegistrationProducesOneRefreshNotification() async throws {
        let f = try PoolServiceFixture(); f.service.appendDelegate(delegate: f.output); f.provider.details = [f.details()]
        f.service.loadAccountPools(); await settle(); equal(f.output.values.count, 1)
    }
    func testDelegateIsHeldWeakly() throws {
        let f = try PoolServiceFixture(); var delegate: PoolServiceOutput? = PoolServiceOutput(); weak var weakDelegate = delegate
        f.service.appendDelegate(delegate: delegate!); delegate = nil; XCTAssertNil(weakDelegate)
    }
    func testPoolCallbacksArriveOnMainQueue() async throws {
        let f = try PoolServiceFixture(); f.provider.details = [f.details()]; await load(f); XCTAssertTrue(f.output.allMain)
    }
    func testLoadSinglePoolMapsEveryAmountWithoutMutatingThePortfolio() async throws {
        let f = try PoolServiceFixture(); f.provider.details = [f.details()]
        let loaded = await f.service.loadPool(by: f.xor, targetAssetId: f.val)
        let result = try XCTUnwrap(loaded)
        equal(result.baseAssetId, f.xor); equal(result.targetAssetId, f.val); equal(result.accountPoolBalance, 5)
        equal(result.baseAssetPooledTotal, 200); equal(result.targetAssetPooledTotal, 400); equal(result.totalIssuances, 20)
        equal(f.service.getAccountPools().count, 0)
    }
    func testMissingLocalPoolLoadsTheRequestedPair() async throws {
        let f = try PoolServiceFixture(); f.provider.details = [f.details()]
        let result = await f.service.getPool(by: f.xor, targetAssetId: f.val)
        equal(result?.baseAssetId, f.xor); equal(f.provider.singleRequests.map { $0.0 }, [f.xor]); equal(f.provider.singleRequests.map { $0.1 }, [f.val])
    }
    func testFailedSinglePoolReadRemainsUnavailable() async throws {
        let f = try PoolServiceFixture(); f.provider.failure = PoolServiceFailure.offline
        let value = await f.service.loadPool(by: f.xor, targetAssetId: f.val); XCTAssertNil(value)
    }
    func testReservesSubscriptionUsesTheExactPairStorageKey() throws {
        let f = try PoolServiceFixture(); f.service.subscribePoolReserves(baseAsset: f.xor, targetAsset: f.val)
        equal(f.engine.subscriptionKeys, [[try StorageKeyFactory().poolReservesKey(baseAssetId: Data(hexStringSSF: f.xor), targetAssetId: Data(hexStringSSF: f.val)).toHex(includePrefix: true)]])
        equal(f.service.subscriptionIds.count, 1)
    }
    func testRepeatedPairSubscriptionDoesNotRegisterDuplicateListeners() throws {
        let f = try PoolServiceFixture(); f.service.subscribePoolReserves(baseAsset: f.xor, targetAsset: f.val); f.service.subscribePoolReserves(baseAsset: f.xor, targetAsset: f.val)
        equal(f.engine.subscriptionKeys.count, 1)
    }
    func testFirstReserveSnapshotDoesNotTriggerRedundantPortfolioRead() async throws {
        let f = try PoolServiceFixture(); f.service.subscribePoolReserves(baseAsset: f.xor, targetAsset: f.val)
        try f.engine.update(block: "0x01"); await settle(); equal(f.provider.reads, 0)
    }
    func testChangedReserveBlockTriggersPortfolioRead() async throws {
        let f = try PoolServiceFixture(); f.service.subscribePoolReserves(baseAsset: f.xor, targetAsset: f.val)
        try f.engine.update(block: "0x01"); try f.engine.update(block: "0x02"); await settle(); equal(f.provider.reads, 1)
    }
    func testDuplicateReserveBlockDoesNotTriggerDuplicateReads() async throws {
        let f = try PoolServiceFixture(); f.service.subscribePoolReserves(baseAsset: f.xor, targetAsset: f.val)
        try f.engine.update(block: "0x01"); try f.engine.update(block: "0x01"); await settle(); equal(f.provider.reads, 0)
    }
    func testUnsubscribeCancelsAllRegisteredIdentifiersAndClearsSnapshots() throws {
        let f = try PoolServiceFixture(); f.service.subscribePoolReserves(baseAsset: f.xor, targetAsset: f.val); f.service.subscribePoolReserves(baseAsset: f.xor, targetAsset: f.pswap)
        try f.engine.update(block: "0x01"); let ids = f.service.subscriptionIds; f.service.unsubscribePoolsReserves()
        equal(f.engine.cancelled, ids); equal(f.service.subscriptionIds, []); XCTAssertTrue(f.service.subscriptionUpdates.isEmpty)
    }
    func testCallbackFromCancelledSubscriptionCannotReloadThePortfolio() async throws {
        let f = try PoolServiceFixture(); f.service.subscribePoolReserves(baseAsset: f.xor, targetAsset: f.val)
        try f.engine.update(block: "0x01"); f.service.unsubscribePoolsReserves()
        try f.engine.update(block: "0x02"); try f.engine.update(block: "0x03"); await settle(); equal(f.provider.reads, 0)
    }
    func testSubscriptionSetupFailureDoesNotLeaveAnIdentifier() throws {
        let f = try PoolServiceFixture(); f.engine.failSubscribe = true
        f.service.subscribePoolReserves(baseAsset: f.xor, targetAsset: f.val); equal(f.service.subscriptionIds, [])
    }
    func testReleasedServiceCancelsItsLiveSubscriptions() throws {
        let f = try PoolServiceFixture(); f.service.subscribePoolReserves(baseAsset: f.xor, targetAsset: f.val)
        weak var weakService = f.service; let ids = f.service.subscriptionIds; f.service = nil
        XCTAssertNil(weakService); equal(f.engine.cancelled, ids)
    }
    func testMissingSubscriptionEngineDoesNotCrash() throws {
        let f = try PoolServiceFixture(); f.service.polkaswapNetworkFacade = nil
        f.service.subscribePoolReserves(baseAsset: f.xor, targetAsset: f.val)
        f.service.subscribeAccountPool(baseAssetId: f.xor); equal(f.service.subscriptionIds, [])
    }
    func testAccountPoolSubscriptionsAreDeduplicatedPerBaseAsset() throws {
        let f = try PoolServiceFixture(); f.service.subscribeAccountPool(baseAssetId: f.xor); f.service.subscribeAccountPool(baseAssetId: f.xor)
        equal(f.engine.subscriptionKeys.count, 1)
    }
    func testCancelledAccountPoolCallbackDoesNotStartNewSubscriptions() async throws {
        let f = try PoolServiceFixture(); f.service.subscribeAccountPool(baseAssetId: f.xor); f.service.unsubscribePoolsReserves()
        try f.engine.update(block: "0x01"); await settle(); equal(f.service.subscriptionIds, [])
    }
    func testLateRefreshCannotReplaceANewerPortfolioInMemoryOrStorage() async throws {
        let f = try PoolServiceFixture(); let started = expectation(description: "first remote read started")
        let gate = DispatchSemaphore(value: 0); f.provider.gate = gate; f.provider.onStart = { started.fulfill() }
        f.provider.details = [f.details()]; f.service.loadAccountPools(); await fulfillment(of: [started], timeout: 3)
        f.provider.onStart = nil
        var latest = f.details(); latest = PoolDetails(baseAsset: latest.baseAsset, targetAsset: f.pswap, yourPoolShare: 50, baseAssetPooledByAccount: 1, targetAssetPooledByAccount: 2, baseAssetPooledTotal: 2, targetAssetPooledTotal: 4, totalIssuances: 10, baseAssetReserves: 2, targetAssetReserves: 4, accountPoolBalance: 5, farms: [])
        f.provider.details = [latest]; await load(f); gate.signal(); await settle()
        equal(f.service.getAccountPools().map(\.targetAssetId), [f.pswap]); equal(try saved(f).map(\.targetAssetId), [f.pswap])
    }
    func testPairStateCombinesExistingReservesAndEnabledDEX() async throws {
        let f = try PoolServiceFixture(); f.engine.hasReserves = true; f.engine.enabled = true
        let result = try await f.service.loadPairState(baseAssetId: f.xor, targetAssetId: f.val)
        equal(result, PoolNetworkState(isPresented: true, isEnabled: true)); equal(result.liquidityAction, .deposit)
    }
    func testPairStateRequiresRegisterAndInitializeForMissingPair() async throws {
        let f = try PoolServiceFixture(); f.engine.hasReserves = false; f.engine.enabled = false
        let result = try await f.service.loadPairState(baseAssetId: f.xor, targetAssetId: f.val); equal(result.liquidityAction, .registerInitializeAndDeposit)
    }
    func testPairStateInitializesAnEnabledPairWithoutReserves() async throws {
        let f = try PoolServiceFixture(); f.engine.hasReserves = false; f.engine.enabled = true
        let result = try await f.service.loadPairState(baseAssetId: f.xor, targetAssetId: f.val); equal(result.liquidityAction, .initializeAndDeposit)
    }
    func testPairStateRejectsExistingButDisabledPool() async throws {
        let f = try PoolServiceFixture(); f.engine.hasReserves = true; f.engine.enabled = false
        let result = try await f.service.loadPairState(baseAssetId: f.xor, targetAssetId: f.val); equal(result.liquidityAction, .reject)
    }
    func testPairStatePropagatesRPCFailure() async throws {
        let f = try PoolServiceFixture(); f.engine.failRead = true
        do { _ = try await f.service.loadPairState(baseAssetId: f.xor, targetAssetId: f.val); XCTFail("Expected unavailable pair state") } catch {}
    }
}
private enum PoolServiceFailure: Swift.Error { case offline }
@MainActor private final class PoolServiceFixture {
    let xor = WalletAssetId.xor.rawValue, val = WalletAssetId.val.rawValue, pswap = WalletAssetId.pswap.rawValue
    let repository = InMemoryDataProviderRepository<PoolInfo>(), provider = PoolServiceProvider(), engine = PoolServiceEngine(), manager = PoolServiceManager(), output = PoolServiceOutput()
    let suite = "pool-service-tests-" + UUID().uuidString
    var service: AccountPoolsService!
    init() throws {
        let preferences = UserDefaults(suiteName: suite)!; let factory = PolkaswapNetworkOperationFactory(engine: engine)
        service = AccountPoolsService(operationManager: manager, networkFacade: nil, polkaswapNetworkFacade: factory, config: ApplicationConfig.shared, poolRepository: AnyDataProviderRepository(repository), detailsProvider: provider, runtimeService: nil, polkaswapOperationFactory: factory, preferences: preferences, prefetchDex: {}, dexIdProvider: { _ in 0 }, startAutomatically: false)
        service.appendDelegate(delegate: output)
    }
    deinit { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
    func asset(_ id: String) -> AssetInfo { AssetInfo(id: id, symbol: "TEST", chainId: "", precision: 18, icon: nil, displayName: "Fixture", visible: true) }
    func pool(_ id: String, favorite: Bool = false, base: String? = nil, target: String? = nil) -> PoolInfo {
        PoolInfo(baseAssetId: base ?? xor, targetAssetId: target ?? val, poolId: id, isFavorite: favorite, accountId: "public-fixture", yourPoolShare: 25, baseAssetPooledByAccount: 50, targetAssetPooledByAccount: 100, baseAssetPooledTotal: 200, targetAssetPooledTotal: 400, totalIssuances: 20, baseAssetReserves: 200, targetAssetReserves: 400, accountPoolBalance: 5)
    }
    func details() -> PoolDetails { PoolDetails(baseAsset: xor, targetAsset: val, yourPoolShare: 25, baseAssetPooledByAccount: 50, targetAssetPooledByAccount: 100, baseAssetPooledTotal: 200, targetAssetPooledTotal: 400, totalIssuances: 20, baseAssetReserves: 200, targetAssetReserves: 400, accountPoolBalance: 5, farms: []) }
}
private final class PoolServiceProvider: AccountPoolDetailsProviding {
    var address: String { try! SS58AddressFactory().addressFromAccountId(data: Data(repeating: 3, count: 32), type: SoraPassport.Chain.sora.addressType()) }
    var accountSettings: WalletAccountSettingsProtocol = WalletAccountSettings(accountId: "public-fixture", assets: [])
    var details = [PoolDetails](), failure: Swift.Error?, reads = 0, singleRequests = [(String, String)]()
    var gate: DispatchSemaphore?, onStart: (() -> Void)?
    func getAccountPoolsDetails() throws -> CompoundOperationWrapper<[PoolDetails]> {
        reads += 1; let failure = failure, details = details, gate = gate, onStart = onStart; self.gate = nil
        return .init(targetOperation: ClosureOperation { onStart?(); if let gate { _ = gate.wait(timeout: .now() + 3) }; if let failure { throw failure }; return details })
    }
    func getPoolDetails(baseAsset: String, targetAsset: String) async throws -> PoolDetails { singleRequests.append((baseAsset, targetAsset)); if let failure { throw failure }; return try XCTUnwrap(details.first) }
}
private final class PoolServiceOutput: PoolsServiceOutput {
    var values = [[PoolInfo]](), allMain = true, onLoad: (() -> Void)?
    func loaded(pools: [PoolInfo]) { allMain = allMain && Thread.isMainThread; values.append(pools); onLoad?() }
}
private final class PoolServiceManager: OperationManagerProtocol {
    let manager = OperationManager()
    func enqueue(operations: [Operation], in mode: OperationMode) { manager.enqueue(operations: operations, in: mode) }
}
private final class PoolServiceEngine: JSONRPCEngine {
    var url: URL?; var pendingEngineRequests: [JSONRPCRequest] { [] }
    var subscriptionKeys = [[String]](), callbacks = [(Data) throws -> Void](), cancelled = [UInt16](), failSubscribe = false, failRead = false, enabled = false, hasReserves = false
    func callMethod<P: Codable, T: Decodable>(_ method: String, params: P?, options: JSONRPCOptions, completion closure: ((Result<T, Swift.Error>) -> Void)?) throws -> UInt16 {
        let result = Result<T, Swift.Error> {
            if failRead { throw PoolServiceFailure.offline }
            let body: Any = method == SoraPassport.RPCMethod.getStorage ? (hasReserves ? "0x" + String(repeating: "00", count: 32) : NSNull()) : enabled
            return try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: body, options: [.fragmentsAllowed]))
        }
        DispatchQueue.global().async { closure?(result) }; return 1
    }
    func subscribe<P: Codable, T: Decodable>(_ method: String, params: P?, updateClosure: @escaping (T) -> Void, failureClosure: @escaping (Swift.Error, Bool) -> Void) throws -> UInt16 {
        if failSubscribe { throw PoolServiceFailure.offline }
        let keys = try JSONDecoder().decode([[String]].self, from: JSONEncoder().encode(params)); subscriptionKeys.append(keys[0])
        callbacks.append { updateClosure(try JSONDecoder().decode(T.self, from: $0)) }; return UInt16(callbacks.count)
    }
    func update(block: String) throws { let body: [String: Any] = ["jsonrpc": "2.0", "method": "state_storage", "params": ["subscription": "1", "result": ["block": block, "changes": []]]]; try callbacks.first?(JSONSerialization.data(withJSONObject: body)) }
    func cancelForIdentifier(_ identifier: UInt16) { cancelled.append(identifier) }; func generateRequestId() -> UInt16 { 1 }; func addSubscription(_ subscription: JSONRPCSubscribing) {}; func connectIfNeeded() {}; func disconnectIfNeeded() {}; func unsubsribe(_ identifier: UInt16) throws {}
}
