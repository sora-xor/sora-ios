// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0
import Combine
import Foundation
import IrohaCrypto
import RobinHood
import SSFUtils
import XCTest

@testable import SoraPassport

@MainActor
final class DemeterServiceFlowTests: XCTestCase {
  private let xor = WalletAssetId.xor.rawValue, val = WalletAssetId.val.rawValue,
    pswap = WalletAssetId.pswap.rawValue
  private static let coder: Result<RuntimeCoderFactory, Error> = Result {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let snapshot = try RuntimeSnapshotFactory.makeOwnTypesSnapshot(
      chainId: PIIndexerClient.soraMainnetGenesis,
      runtimeMetadataItem: SoraPassport.RuntimeMetadataItem(
        chain: PIIndexerClient.soraMainnetGenesis, version: 133, txVersion: 131,
        metadata: Data(
          contentsOf: root.appendingPathComponent(
            "Fixtures/Modernization/sora2-metadata-spec133.scale")), resolver: nil),
      ownTypes: Data(
        contentsOf: root.appendingPathComponent("SoraPassport/Resources/runtime-sora.json")),
      dataHasher: .twox256)
    return RuntimeCoderFactory(
      catalog: snapshot.typeRegistryCatalog, specVersion: 133, txVersion: 131,
      metadata: snapshot.metadata)
  }
  private func fixture(prices: [String: String] = [:]) throws -> DemeterFlowFixture {
    try DemeterFlowFixture(coder: Self.coder.get(), prices: prices)
  }
  private func fails<T>(
    _ body: () async throws -> T, file: StaticString = #filePath, line: UInt = #line
  ) async {
    do {
      _ = try await body()
      XCTFail("Expected unavailable data to propagate", file: file, line: line)
    } catch {}
  }
  func testPoolRowsDecodeExactStakeRewardAndDepositFeeValues() async throws {
    let f = try fixture()
    try f.setPools([f.pool()])
    let rows = try await f.service.getPools(poolAssetId: val, rewardAssetId: pswap)
    let row = try XCTUnwrap(rows.first)
    XCTAssertEqual(rows.count, 1)
    XCTAssertEqual(row.baseAssetId, xor)
    XCTAssertEqual(row.poolAssetId, val)
    XCTAssertEqual(row.rewardAssetId, pswap)
    XCTAssertEqual(row.depositFee, Decimal(string: "0.01"))
    XCTAssertEqual(row.totalTokensInPool, 5)
    XCTAssertEqual(row.rewards, 2)
    XCTAssertEqual(row.rewardsToBeDistributed, 3)
  }
  func testRuntimePoolMultiplierIsAnIntegerWeight() async throws {
    let f = try fixture()
    try f.setPools([f.pool()])
    let rows = try await f.service.getPools(poolAssetId: val, rewardAssetId: pswap)
    XCTAssertEqual(rows.first?.multiplier, 2)
  }
  func testRemovedAndSingleSidedPoolsAreNotOfferedAsFarms() async throws {
    let f = try fixture()
    try f.setPools([f.pool(), f.pool(isFarm: false), f.pool(removed: true)])
    let rows = try await f.service.getPools(poolAssetId: val, rewardAssetId: pswap)
    XCTAssertEqual(rows.count, 1)
  }
  func testPoolStorageFailureDoesNotLookLikeAnEmptyFarmList() async throws {
    let f = try fixture()
    f.engine.failure = DemeterFlowFailure.offline
    await fails { try await f.service.getPools(poolAssetId: val, rewardAssetId: pswap) }
  }
  func testMalformedPoolScaleDataIsReported() async throws {
    let f = try fixture()
    f.engine.storage[f.poolKey] = "0x01"
    await fails { try await f.service.getPools(poolAssetId: val, rewardAssetId: pswap) }
  }
  func testMissingRuntimeMakesPoolDataUnavailable() async throws {
    let f = try fixture()
    f.runtimeAvailable = false
    await fails { try await f.service.getPools(poolAssetId: val, rewardAssetId: pswap) }
  }
  func testPoolKeyReadReturnsTheExactRuntimeKeys() async throws {
    let f = try fixture()
    f.engine.pages[f.poolPrefix] = [f.poolKey]
    let keys = try await f.service.getPoolKeys()
    XCTAssertEqual(keys, [f.poolKey])
  }
  func testPoolKeyReadPropagatesRPCFailure() async throws {
    let f = try fixture()
    f.engine.failure = DemeterFlowFailure.offline
    await fails { try await f.service.getPoolKeys() }
  }
  func testTokenKeyReadReturnsTheExactRuntimeKeys() async throws {
    let f = try fixture()
    f.engine.pages[f.tokenPrefix] = [f.tokenKey]
    let keys = try await f.service.getTokenInfosKeys()
    XCTAssertEqual(keys, [f.tokenKey])
  }
  func testTokenKeyReadPropagatesRPCFailure() async throws {
    let f = try fixture()
    f.engine.failure = DemeterFlowFailure.offline
    await fails { try await f.service.getTokenInfosKeys() }
  }
  func testRewardTokenAmountsPreserveAllEighteenDecimalPlaces() async throws {
    let f = try fixture()
    try f.setToken()
    let fetched = try await f.service.getRewardTokenInfos(with: pswap)
    let value = try XCTUnwrap(fetched)
    XCTAssertEqual(value.assetId, pswap)
    XCTAssertEqual(value.tokenPerBlock, Decimal(string: "0.000000000000000001"))
    XCTAssertEqual(value.farmsAllocation, Decimal(string: "0.6"))
    XCTAssertEqual(value.stakingAllocation, Decimal(string: "0.4"))
  }
  func testRewardTokenMultiplierIsAnIntegerWeight() async throws {
    let f = try fixture()
    try f.setToken()
    let value = try await f.service.getRewardTokenInfos(with: pswap)
    XCTAssertEqual(value?.farmsTotalMultiplier, 4)
    XCTAssertEqual(value?.stakingTotalMultiplier, 5)
  }
  func testAbsentTokenStorageReturnsNil() async throws {
    let f = try fixture()
    let value = try await f.service.getRewardTokenInfos(with: pswap)
    XCTAssertNil(value)
  }
  func testTokenStorageFailureIsNotAnAbsentToken() async throws {
    let f = try fixture()
    f.engine.failure = DemeterFlowFailure.offline
    await fails { try await f.service.getRewardTokenInfos(with: pswap) }
  }
  func testMalformedTokenScaleDataIsReported() async throws {
    let f = try fixture()
    f.engine.storage[f.tokenKey] = "0x01"
    await fails { try await f.service.getRewardTokenInfos(with: pswap) }
  }
  func testUserFarmRowsFilterBothAssetsAndExcludeSingleSidedPositions() async throws {
    let f = try fixture()
    try f.setUsers([f.user(), f.user(base: val), f.user(pool: pswap), f.user(isFarm: false)])
    let rows = try await f.service.loadUserFarmInfos(
      baseAssetId: xor, targetAssetId: val, accountId: f.account)
    XCTAssertEqual(rows.count, 1)
    XCTAssertEqual(rows.first?.id, "\(xor)-\(val)-\(pswap)")
    XCTAssertEqual(rows.first?.pooledTokens, Decimal(string: "1.000000000000000001"))
    XCTAssertEqual(rows.first?.rewards, 2)
  }
  func testUserFarmDataRequiresAnAccount() async throws {
    let f = try fixture()
    await fails {
      try await f.service.loadUserFarmInfos(baseAssetId: xor, targetAssetId: val, accountId: Data())
    }
    XCTAssertTrue(f.engine.queries.isEmpty)
  }
  func testUserFarmDataRequiresBothAssets() async throws {
    let f = try fixture()
    await fails {
      try await f.service.loadUserFarmInfos(
        baseAssetId: nil, targetAssetId: val, accountId: f.account)
    }
    XCTAssertTrue(f.engine.queries.isEmpty)
  }
  func testUserFarmRPCFailureRemainsUnavailable() async throws {
    let f = try fixture()
    f.engine.failure = DemeterFlowFailure.offline
    await fails {
      try await f.service.loadUserFarmInfos(
        baseAssetId: xor, targetAssetId: val, accountId: f.account)
    }
  }
  func testMalformedUserFarmDataIsReported() async throws {
    let f = try fixture()
    f.engine.storage[f.userKey] = "0x01"
    await fails {
      try await f.service.loadUserFarmInfos(
        baseAssetId: xor, targetAssetId: val, accountId: f.account)
    }
  }
  func testMissingRuntimeCannotInventAnEmptyUserPosition() async throws {
    let f = try fixture()
    f.runtimeAvailable = false
    await fails {
      try await f.service.loadUserFarmInfos(
        baseAssetId: xor, targetAssetId: val, accountId: f.account)
    }
  }
  func testFarmDetailsCalculateExactTVLAndAPRFromTheLivePool() async throws {
    let f = try fixture(prices: [val: "3", pswap: "4"])
    try f.setPools([f.pool()])
    try f.setToken(tokenPerBlock: "1000000000000000000")
    let rows = try await f.service.getFarmDetails(
      baseAssetId: xor, poolAssetId: val, rewardAssetId: pswap)
    let farm = try XCTUnwrap(rows.first)
    XCTAssertEqual(farm.tvl, 600)
    XCTAssertEqual(farm.apr, 10512)
    XCTAssertEqual(farm.depositFee, 1)
    XCTAssertTrue(farm.tvlIsKnown)
    XCTAssertTrue(farm.aprIsKnown)
  }
  func testFarmDetailsUsesTheSameStableIdentityAsTheCatalog() async throws {
    let f = try fixture(prices: [val: "3", pswap: "4"])
    try f.setPools([f.pool()])
    try f.setToken()
    let rows = try await f.service.getFarmDetails(
      baseAssetId: xor, poolAssetId: val, rewardAssetId: pswap)
    XCTAssertEqual(rows.first?.id, "\(xor)-\(val)-\(pswap)")
  }
  func testUnpricedFarmDoesNotClaimKnownYield() async throws {
    let f = try fixture()
    try f.setPools([f.pool()])
    try f.setToken()
    let rows = try await f.service.getFarmDetails(
      baseAssetId: xor, poolAssetId: val, rewardAssetId: pswap)
    XCTAssertFalse(try XCTUnwrap(rows.first).tvlIsKnown)
    XCTAssertFalse(try XCTUnwrap(rows.first).aprIsKnown)
  }
  func testMissingRewardPriceLeavesOnlyTVLKnown() async throws {
    let f = try fixture(prices: [val: "3"])
    try f.setPools([f.pool()])
    try f.setToken()
    let fetched = try await f.service.getFarmDetails(
      baseAssetId: xor, poolAssetId: val, rewardAssetId: pswap)
    let farm = try XCTUnwrap(fetched.first)
    XCTAssertTrue(farm.tvlIsKnown)
    XCTAssertFalse(farm.aprIsKnown)
  }
  func testMissingPoolStateDoesNotClaimKnownTVLOrYield() async throws {
    let f = try fixture(prices: [val: "3", pswap: "4"])
    f.pools.pool = nil
    try f.setPools([f.pool()])
    try f.setToken()
    let fetched = try await f.service.getFarmDetails(
      baseAssetId: xor, poolAssetId: val, rewardAssetId: pswap)
    let farm = try XCTUnwrap(fetched.first)
    XCTAssertFalse(farm.tvlIsKnown)
    XCTAssertFalse(farm.aprIsKnown)
  }
  func testZeroIssuanceDoesNotProduceNaNOrKnownYield() async throws {
    let f = try fixture(prices: [val: "3", pswap: "4"])
    f.pools.pool?.totalIssuances = 0
    try f.setPools([f.pool()])
    try f.setToken()
    let fetched = try await f.service.getFarmDetails(
      baseAssetId: xor, poolAssetId: val, rewardAssetId: pswap)
    let farm = try XCTUnwrap(fetched.first)
    XCTAssertFalse(farm.tvl.isNaN)
    XCTAssertFalse(farm.apr.isNaN)
    XCTAssertFalse(farm.aprIsKnown)
  }
  func testFarmDetailsRejectFailedRuntimeReads() async throws {
    let f = try fixture()
    f.engine.failure = DemeterFlowFailure.offline
    await fails {
      try await f.service.getFarmDetails(baseAssetId: xor, poolAssetId: val, rewardAssetId: pswap)
    }
  }
  func testCatalogUsesActualKeysAndCachesOnlySuccessfulFarms() async throws {
    let f = try fixture(prices: [val: "3", pswap: "4"])
    try f.populate()
    let first = try await f.service.getAllFarms()
    XCTAssertEqual(first.count, 1)
    let count = f.engine.queries.count
    let second = try await f.service.getAllFarms()
    XCTAssertEqual(second.first?.id, first.first?.id)
    XCTAssertEqual(f.engine.queries.count, count)
    XCTAssertNotNil(f.service.getFarm(with: "\(xor)-\(val)-\(pswap)"))
    XCTAssertNil(f.service.getFarm(with: "missing"))
  }
  func testCatalogFailureDoesNotCacheAnInventedEmptySuccess() async throws {
    let f = try fixture()
    f.engine.failure = DemeterFlowFailure.offline
    await fails { try await f.service.getAllFarms() }
    f.engine.failure = nil
    try f.populate()
    let rows = try await f.service.getAllFarms()
    XCTAssertEqual(rows.count, 1)
  }
  func testCancelledCatalogDoesNotStartRPCReads() async throws {
    let f = try fixture()
    let task = Task {
      withUnsafeCurrentTask { $0?.cancel() }
      return try await f.service.getAllFarms()
    }
    do {
      _ = try await task.value
      XCTFail("Expected cancellation")
    } catch { XCTAssertTrue(error is CancellationError) }
    XCTAssertTrue(f.engine.queries.isEmpty)
  }
  func testCancelledUserPositionDoesNotStartRPCReads() async throws {
    let f = try fixture()
    let task = Task {
      withUnsafeCurrentTask { $0?.cancel() }
      return try await f.service.loadUserFarmInfos(
        baseAssetId: xor, targetAssetId: val, accountId: f.account)
    }
    do {
      _ = try await task.value
      XCTFail("Expected cancellation")
    } catch { XCTAssertTrue(error is CancellationError) }
    XCTAssertTrue(f.engine.queries.isEmpty)
  }
  func testMissingRewardEmissionDoesNotClaimKnownAPR() async throws {
    let f = try fixture(prices: [val: "3", pswap: "4"])
    try f.setPools([f.pool()])
    let rows = try await f.service.getFarmDetails(
      baseAssetId: xor, poolAssetId: val, rewardAssetId: pswap)
    XCTAssertTrue(try XCTUnwrap(rows.first).tvlIsKnown)
    XCTAssertFalse(try XCTUnwrap(rows.first).aprIsKnown)
  }
  func testNegativePriceDoesNotClaimKnownTVL() async throws {
    let f = try fixture(prices: [val: "-3", pswap: "4"])
    try f.setPools([f.pool()])
    try f.setToken()
    let rows = try await f.service.getFarmDetails(
      baseAssetId: xor, poolAssetId: val, rewardAssetId: pswap)
    XCTAssertFalse(try XCTUnwrap(rows.first).tvlIsKnown)
    XCTAssertFalse(try XCTUnwrap(rows.first).aprIsKnown)
  }

}

private enum DemeterFlowFailure: Error { case offline }
@MainActor
private final class DemeterFlowFixture {
  let coder: RuntimeCoderFactory
  let engine = DemeterFlowEngine()
  let account = Data(repeating: 3, count: 32)
  let pools = DemeterFlowPools()
  let poolPrefix: String, tokenPrefix: String, poolKey: String, tokenKey: String, userKey: String
  var runtimeAvailable = true
  lazy var service: DemeterFarmingService = DemeterFarmingService(
    operationFactory: DemeterFarmingOperationFactory(engine: engine),
    fiatService: FiatService(assets: { [prices] in
      try prices.map {
        PIAsset(id: $0.key, priceUSD: try PIQuantity($0.value), liquidity: nil, priceChangeDay: nil)
      }
    }), assetManager: DemeterFlowAssets(),
    runtimeOperation: { [weak self] in
      guard let self, self.runtimeAvailable else { return nil }
      let op = BaseOperation<RuntimeCoderFactoryProtocol>()
      op.result = .success(self.coder)
      return op
    })
  let prices: [String: String]
  init(coder: RuntimeCoderFactory, prices: [String: String]) throws {
    self.coder = coder
    self.prices = prices
    func key(_ path: StorageCodingPath, _ bytes: [Data]) throws -> String {
      let entry = try XCTUnwrap(
        coder.metadata.getStorageMetadata(in: path.moduleName, storageName: path.itemName))
      guard case .nMap(let map) = entry.type else { throw DemeterFlowFailure.offline }
      return try StorageKeyFactory().createStorageKey(
        moduleName: path.moduleName, storageName: path.itemName, keys: bytes, hashers: map.hashers
      ).toHex(includePrefix: true)
    }
    poolPrefix = try StorageKeyFactory().createStorageKey(
      moduleName: "DemeterFarmingPlatform", storageName: "Pools"
    ).toHex(includePrefix: true)
    tokenPrefix = try StorageKeyFactory().createStorageKey(
      moduleName: "DemeterFarmingPlatform", storageName: "TokenInfos"
    ).toHex(includePrefix: true)
    poolKey = try key(
      .demeterFarmingPools,
      [
        Data(hexStringSSF: WalletAssetId.val.rawValue),
        Data(hexStringSSF: WalletAssetId.pswap.rawValue),
      ])
    tokenKey = try key(.demeterFarmingTokenInfo, [Data(hexStringSSF: WalletAssetId.pswap.rawValue)])
    userKey = try key(.demeterFarmingUserInfo, [account])
    service.poolsService = pools
  }
  func encode(_ value: Any, at path: StorageCodingPath) throws -> String {
    let entry = try XCTUnwrap(
      coder.metadata.getStorageMetadata(in: path.moduleName, storageName: path.itemName))
    let type = try entry.type.typeName(using: coder.metadata.schemaResolver)
    let data = try JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed])
    let json = try JSONDecoder().decode(JSON.self, from: data)
    let encoder = coder.createEncoder()
    try encoder.append(json, ofType: type)
    return try encoder.encode().toHex(includePrefix: true)
  }
  func fields(_ dictionary: [String: Any]) -> [String: Any] {
    var result = dictionary
    for (key, value) in dictionary {
      let snake = key.reduce("") {
        $0 + ($1.isUppercase ? "_" + String($1).lowercased() : String($1))
      }
      result[snake] = value
    }
    return result
  }
  func pool(isFarm: Bool = true, removed: Bool = false) -> [String: Any] {
    fields([
      "multiplier": "2", "depositFee": "10000000000000000", "isCore": true, "isFarm": isFarm,
      "totalTokensInPool": "5000000000000000000", "rewards": "2000000000000000000",
      "rewardsToBeDistributed": "3000000000000000000", "rewardPerToken": "0", "isRemoved": removed,
      "baseAsset": ["code": Array(try! Data(hexStringSSF: WalletAssetId.xor.rawValue)).map(String.init)],
    ])
  }
  func user(
    base: String = WalletAssetId.xor.rawValue, pool: String = WalletAssetId.val.rawValue,
    isFarm: Bool = true
  ) -> [String: Any] {
    fields([
      "baseAsset": ["code": Array(try! Data(hexStringSSF: base)).map(String.init)], "poolAsset": ["code": Array(try! Data(hexStringSSF: pool)).map(String.init)],
      "rewardAsset": ["code": Array(try! Data(hexStringSSF: WalletAssetId.pswap.rawValue)).map(String.init)], "isFarm": isFarm,
      "pooledTokens": "1000000000000000001", "rewards": "2000000000000000000", "rewardPerTokenPaid": "0",
    ])
  }
  func setPools(_ rows: [[String: Any]]) throws {
    engine.storage[poolKey] = try encode(rows, at: .demeterFarmingPools)
  }
  func setUsers(_ rows: [[String: Any]]) throws {
    engine.storage[userKey] = try encode(rows, at: .demeterFarmingUserInfo)
  }
  func setToken(tokenPerBlock: String = "1") throws {
    let value = fields([
      "farmsTotalMultiplier": "4", "stakingTotalMultiplier": "5", "tokenPerBlock": tokenPerBlock,
      "farmsAllocation": "600000000000000000", "stakingAllocation": "400000000000000000",
      "teamAllocation": "0", "teamAccount": Array(repeating: "1", count: 32),
    ])
    engine.storage[tokenKey] = try encode(value, at: .demeterFarmingTokenInfo)
  }
  func populate() throws {
    try setPools([pool()])
    try setToken()
    engine.pages[poolPrefix] = [poolKey]
    engine.pages[tokenPrefix] = [tokenKey]
  }
}
private final class DemeterFlowEngine: JSONRPCEngine {
  var url: URL?
  var pendingEngineRequests: [JSONRPCRequest] { [] }
  var storage: [String: String] = [:], pages: [String: [String]] = [:]
  var failure: Error?
  private let lock = NSLock()
  private var records: [[Any]] = []
  var queries: [[Any]] {
    lock.lock()
    defer { lock.unlock() }
    return records
  }
  func callMethod<P: Codable, T: Decodable>(
    _ method: String, params: P?, options: JSONRPCOptions,
    completion closure: ((Result<T, Error>) -> Void)?
  ) throws -> UInt16 {
    let parameters =
      try JSONSerialization.jsonObject(with: JSONEncoder().encode(params)) as? [Any] ?? []
    lock.lock()
    records.append(parameters)
    lock.unlock()
    if let failure {
      DispatchQueue.global().async { closure?(.failure(failure)) }
      return 1
    }
    let value: Any
    if method == SoraPassport.RPCMethod.getStorageKeysPaged {
      value = pages[parameters.first as? String ?? ""] ?? []
    } else {
      let keys = parameters.first as? [String] ?? []
      value = [
        [
          "block": "0x" + String(repeating: "01", count: 32),
          "changes": keys.map { [$0, storage[$0] as Any? ?? NSNull()] },
        ]
      ]
    }
    let data = try JSONSerialization.data(withJSONObject: value)
    let decoded = try JSONDecoder().decode(T.self, from: data)
    DispatchQueue.global().async { closure?(.success(decoded)) }
    return 1
  }
  func subscribe<P: Codable, T: Decodable>(
    _ method: String, params: P?, updateClosure: @escaping (T) -> Void,
    failureClosure: @escaping (Error, Bool) -> Void
  ) throws -> UInt16 {
    XCTFail("Unexpected subscription")
    throw DemeterFlowFailure.offline
  }
  func cancelForIdentifier(_ identifier: UInt16) {}
  func generateRequestId() -> UInt16 { 1 }
  func addSubscription(_ subscription: JSONRPCSubscribing) {}
  func connectIfNeeded() {}
  func disconnectIfNeeded() {}
  func unsubsribe(_ identifier: UInt16) throws {}
}
private final class DemeterFlowPools: PoolsServiceInputProtocol {
  var pool: PoolInfo? = PoolInfo(
    baseAssetId: WalletAssetId.xor.rawValue, targetAssetId: WalletAssetId.val.rawValue,
    poolId: "pool", accountId: "fixture", totalIssuances: 10, baseAssetReserves: 100,
    targetAssetReserves: 200)
  func loadPairState(baseAssetId: String, targetAssetId: String) async throws -> PoolNetworkState {
    .init(isPresented: true, isEnabled: true)
  }
  func loadPool(by baseAssetId: String, targetAssetId: String) async -> PoolInfo? { pool }
  func getPool(by baseAssetId: String, targetAssetId: String) async -> PoolInfo? { pool }
  func getPool(by id: String) -> PoolInfo? { pool }
  func getAccountPools() -> [PoolInfo] { pool.map { [$0] } ?? [] }
  func loadAccountPools() {}
  func updatePools(_ pools: [PoolInfo]) {}
  func loadPools(currentAsset: AssetInfo) -> [PoolInfo] { getAccountPools() }
  func loadTargetPools(for baseAssetId: String) -> [PoolInfo] { getAccountPools() }
  func appendDelegate(delegate: PoolsServiceOutput) {}
}
private final class DemeterFlowAssets: AssetManagerProtocol {
  static var networkAssets: [AssetInfo] = []
  let assets = [(WalletAssetId.xor, "XOR"), (.val, "VAL"), (.pswap, "PSWAP")].map {
    AssetInfo(
      id: $0.0.rawValue, symbol: $0.1, chainId: "", precision: 18, icon: nil, displayName: $0.1,
      visible: true)
  }
  func assetInfo(for identifier: String) -> AssetInfo? {
    assets.first { $0.identifier == identifier }
  }
  func getAssetList() -> [AssetInfo]? { assets }
  func updateAssetList(_ list: [AssetInfo]) {}
  func saveAssetList(_ list: [AssetInfo]) {}
  func sortedAssets(_ list: [WalletAsset], onlyVisible: Bool) -> [WalletAsset] { list }
  func visibleCount() -> UInt { UInt(assets.count) }
  func setup(for accountSettings: SelectedWalletSettings) {}
}

@MainActor
final class UserFarmsSubscriptionCoverageTests: XCTestCase {
    private static let coder: Result<RuntimeCoderFactory, Error> = Result {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let snapshot = try RuntimeSnapshotFactory.makeOwnTypesSnapshot(chainId: PIIndexerClient.soraMainnetGenesis,
            runtimeMetadataItem: SoraPassport.RuntimeMetadataItem(chain: PIIndexerClient.soraMainnetGenesis, version: 133, txVersion: 131,
                metadata: Data(contentsOf: root.appendingPathComponent("Fixtures/Modernization/sora2-metadata-spec133.scale")), resolver: nil),
            ownTypes: Data(contentsOf: root.appendingPathComponent("SoraPassport/Resources/runtime-sora.json")), dataHasher: .twox256)
        return RuntimeCoderFactory(catalog: snapshot.typeRegistryCatalog, specVersion: 133, txVersion: 131, metadata: snapshot.metadata)
    }
    private var fixtures = [UserFarmSubscriptionFixture]()
    override func tearDown() { fixtures.forEach { $0.close() }; fixtures = []; super.tearDown() }
    private func make() throws -> UserFarmSubscriptionFixture {
        let f = try UserFarmSubscriptionFixture(coder: Self.coder.get()); fixtures.append(f); return f
    }
    private func wait(_ predicate: () -> Bool) async {
        for _ in 0..<200 { if predicate() { return }; try? await Task.sleep(nanoseconds: 10_000_000) }; XCTAssertTrue(predicate())
    }
    private func listen(_ f: UserFarmSubscriptionFixture) async {
        let stream = await f.subject!.userFarms
        f.token = stream.receive(on: DispatchQueue.main).sink { [weak f] in f?.snapshots.append($0) }
    }
    func testNoSelectedAccountDoesNotOpenAStorageSubscription() async throws {
        let f = try make(); f.account = nil
        try await f.subscribe(); XCTAssertTrue(f.engine.params.isEmpty); XCTAssertEqual(f.connectionReads, 0)
    }
    func testMalformedSelectedAddressDoesNotOpenAStorageSubscription() async throws {
        let f = try make(); let account = try XCTUnwrap(f.account)
        f.account = AccountItem(address: "invalid address", cryptoType: account.cryptoType, networkType: account.networkType,
                               username: account.username, publicKeyData: account.publicKeyData, settings: account.settings,
                               order: account.order, isSelected: account.isSelected)
        try await f.subscribe(); XCTAssertTrue(f.engine.params.isEmpty); XCTAssertEqual(f.connectionReads, 0)
    }
    func testSubscriptionUsesTheExactSelectedAccountStorageKey() async throws {
        let f = try make(); try await f.subscribe()
        let expected = try StorageKeyFactory().demeterFarmingUserInfo(identifier: f.storage.account).toHex(includePrefix: true)
        XCTAssertEqual(f.engine.methods, [SoraPassport.RPCMethod.storageSubscribe]); XCTAssertEqual(f.engine.params, [[[expected]]])
    }
    func testUnavailableConnectionReturnsAnErrorInsteadOfAFakeSubscription() async throws {
        let f = try make(); f.connectionAvailable = false
        do { try await f.subscribe(); XCTFail("Expected unavailable connection") }
        catch { guard case ChainRegistryError.connectionUnavailable = error else { return XCTFail("Unexpected error: \(error)") } }
        f.subject = nil; XCTAssertTrue(f.engine.cancelled.isEmpty)
    }
    func testFailedSubscribePreservesTheTransportErrorWithoutRecordingAnId() async throws {
        let f = try make(); f.engine.failure = DemeterFlowFailure.offline
        do { try await f.subscribe(); XCTFail("Expected transport failure") }
        catch { XCTAssertTrue(error is DemeterFlowFailure) }
        f.subject = nil; XCTAssertTrue(f.engine.cancelled.isEmpty)
    }
    func testReleaseCancelsOnTheConnectionThatCreatedTheSubscription() async throws {
        let f = try make(); try await f.subscribe(); let original = f.engine
        let replacement = UserFarmSubscriptionEngine(); f.engine = replacement; f.subject = nil
        await wait { original.cancelled == [1] }
        XCTAssertTrue(replacement.cancelled.isEmpty)
    }
    func testSubscriptionsOnDifferentConnectionsAreEachCancelledOnce() async throws {
        let f = try make(); try await f.subscribe(); let first = f.engine
        let second = UserFarmSubscriptionEngine(); f.engine = second; try await f.subscribe()
        f.subject = nil; await wait { first.cancelled == [1] && second.cancelled == [1] }
    }
    func testRuntimeDecodingPreservesExactPooledAndRewardAmounts() async throws {
        let f = try make(); await listen(f); try await f.subscribe()
        try f.emit([f.storage.user()]); await wait { f.snapshots.count == 1 }
        let farm = try XCTUnwrap(f.snapshots.first?.first)
        XCTAssertEqual(farm.baseAssetId, WalletAssetId.xor.rawValue); XCTAssertEqual(farm.poolAssetId, WalletAssetId.val.rawValue)
        XCTAssertEqual(farm.rewardAssetId, WalletAssetId.pswap.rawValue); XCTAssertTrue(farm.isFarm)
        XCTAssertEqual(farm.pooledTokens, Decimal(string: "1.000000000000000001")); XCTAssertEqual(farm.rewards, 2)
        XCTAssertEqual(farm.id, "\(WalletAssetId.xor.rawValue)-\(WalletAssetId.val.rawValue)-\(WalletAssetId.pswap.rawValue)")
    }
    func testOnlyTheRequestedBasePoolPairAndFarmRowsArePublished() async throws {
        let f = try make(); await listen(f); try await f.subscribe()
        try f.emit([f.storage.user(), f.storage.user(base: WalletAssetId.val.rawValue), f.storage.user(pool: WalletAssetId.pswap.rawValue), f.storage.user(isFarm: false)])
        await wait { f.snapshots.count == 1 }; XCTAssertEqual(f.snapshots[0].count, 1)
        XCTAssertEqual(f.snapshots[0][0].poolAssetId, WalletAssetId.val.rawValue)
    }
    func testAnEmptyOnChainFarmListPublishesAnEmptySnapshot() async throws {
        let f = try make(); await listen(f); try await f.subscribe(); try f.emit([])
        await wait { f.snapshots.count == 1 }; XCTAssertTrue(f.snapshots[0].isEmpty)
    }
    func testAbsentStorageValueDecodesTheRuntimeFallback() async throws {
        let f = try make(); await listen(f); try await f.subscribe(); try f.engine.emit(value: nil)
        await wait { f.snapshots.count == 1 }; XCTAssertTrue(f.snapshots[0].isEmpty)
    }
    func testAnUpdateWithoutChangesPublishesNoInventedFarms() async throws {
        let f = try make(); await listen(f); try await f.subscribe(); try f.engine.emit(changes: [])
        await wait { f.snapshots.count == 1 }; XCTAssertTrue(f.snapshots[0].isEmpty)
    }
    func testMissingRuntimeCannotCrashOrPublishAnInventedSnapshot() async throws {
        let f = try make(); f.runtimeAvailable = false; await listen(f); try await f.subscribe(); try f.emit([f.storage.user()])
        await wait { f.runtimeReads == 1 }; try? await Task.sleep(nanoseconds: 50_000_000); XCTAssertTrue(f.snapshots.isEmpty)
        f.runtimeAvailable = true; try f.emit([f.storage.user()]); await wait { f.snapshots.count == 1 }
    }
    func testRuntimeFactoryFailureCanRecoverOnTheNextValidUpdate() async throws {
        let f = try make(); f.runtimeFailure = DemeterFlowFailure.offline; await listen(f); try await f.subscribe(); try f.emit([f.storage.user()])
        await wait { f.runtimeReads == 1 }; try? await Task.sleep(nanoseconds: 50_000_000); XCTAssertTrue(f.snapshots.isEmpty)
        f.runtimeFailure = nil; try f.emit([f.storage.user()]); await wait { f.snapshots.count == 1 }
    }
    func testMalformedScaleCannotReplaceTheLastValidFarmSnapshot() async throws {
        let f = try make(); await listen(f); try await f.subscribe(); try f.emit([f.storage.user()]); await wait { f.snapshots.count == 1 }
        try f.engine.emit(value: "0xffff"); await wait { f.runtimeReads == 2 }; try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(f.snapshots.count, 1); XCTAssertEqual(f.snapshots[0].count, 1)
        try f.emit([]); await wait { f.snapshots.count == 2 }; XCTAssertTrue(f.snapshots[1].isEmpty)
    }
    func testTransportFailureDoesNotInventAnEmptyPortfolioAndNextUpdateStillWorks() async throws {
        let f = try make(); await listen(f); try await f.subscribe(); f.engine.failures[1]?(DemeterFlowFailure.offline, false)
        XCTAssertTrue(f.snapshots.isEmpty); try f.emit([f.storage.user()]); await wait { f.snapshots.count == 1 }
    }
}

@MainActor
private final class UserFarmSubscriptionFixture {
    let storage: DemeterFlowFixture
    var engine = UserFarmSubscriptionEngine()
    var account: AccountItem?
    var subject: UserFarmsService?
    var token: AnyCancellable?
    var snapshots = [[UserFarm]]()
    var runtimeAvailable = true, connectionAvailable = true
    var runtimeFailure: Error?
    var runtimeReads = 0, connectionReads = 0
    init(coder: RuntimeCoderFactory) throws {
        storage = try DemeterFlowFixture(coder: coder, prices: [:])
        let address = try SS58AddressFactory().address(fromAccountId: storage.account, type: 69)
        account = AccountItem(address: address, cryptoType: .sr25519, networkType: 69, username: "Public farm fixture", publicKeyData: storage.account,
                              settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: 0, isSelected: true)
        subject = UserFarmsService(selectedAccount: { [weak self] in self?.account }, connection: { [weak self] in
            guard let self else { return nil }; self.connectionReads += 1
            return self.connectionAvailable ? self.engine : nil
        }, runtimeOperation: { [weak self] in
            guard let self else { return nil }; self.runtimeReads += 1; guard self.runtimeAvailable else { return nil }
            let op = BaseOperation<RuntimeCoderFactoryProtocol>()
            if let failure = self.runtimeFailure { op.result = .failure(failure) } else { op.result = .success(self.storage.coder) }
            return op
        })
    }
    func subscribe() async throws { try await subject!.subscribeUserFarms(to: WalletAssetId.xor.rawValue, targetAssetId: WalletAssetId.val.rawValue) }
    func emit(_ rows: [[String: Any]]) throws { try engine.emit(value: storage.encode(rows, at: .demeterFarmingUserInfo)) }
    func close() { token = nil; subject = nil }
}
private final class UserFarmSubscriptionEngine: JSONRPCEngine {
    var url: URL?
    var pendingEngineRequests: [JSONRPCRequest] { [] }
    var methods = [String](), params = [[[String]]](), cancelled = [UInt16]()
    var callbacks = [UInt16: (Data) throws -> Void](), failures = [UInt16: (Error, Bool) -> Void]()
    var failure: Error?
    func callMethod<P: Codable, T: Decodable>(_ method: String, params: P?, options: JSONRPCOptions, completion closure: ((Result<T, Error>) -> Void)?) throws -> UInt16 {
        XCTFail("Unexpected RPC instead of storage subscription"); throw DemeterFlowFailure.offline
    }
    func subscribe<P: Codable, T: Decodable>(_ method: String, params: P?, updateClosure: @escaping (T) -> Void, failureClosure: @escaping (Error, Bool) -> Void) throws -> UInt16 {
        if let failure { throw failure }; methods.append(method)
        self.params.append(try JSONDecoder().decode([[String]].self, from: JSONEncoder().encode(params)))
        let id = UInt16(methods.count); callbacks[id] = { try updateClosure(JSONDecoder().decode(T.self, from: $0)) }; failures[id] = failureClosure
        return id
    }
    func emit(value: String?) throws { try emit(changes: [[params[0][0][0], value ?? NSNull()]]) }
    func emit(changes: [[Any]]) throws {
        let data = try JSONSerialization.data(withJSONObject: ["jsonrpc": "2.0", "method": "state_storage", "params": ["subscription": "1", "result": ["block": "0x00", "changes": changes]]])
        try callbacks[1]?(data)
    }
    func cancelForIdentifier(_ identifier: UInt16) { cancelled.append(identifier) }
    func generateRequestId() -> UInt16 { 1 }
    func addSubscription(_ subscription: JSONRPCSubscribing) {}
    func reconnect(url: URL) {}
    func connectIfNeeded() {}
    func disconnectIfNeeded() {}
    func unsubsribe(_ subscriptionId: UInt16) throws { cancelForIdentifier(subscriptionId) }
}
