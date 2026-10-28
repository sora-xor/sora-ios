// SPDX-License-Identifier: BSD-4-Clause
import Combine
import Foundation
import XCTest

@testable import SoraPassport

@MainActor
final class PoolValuationLifecycleTests: XCTestCase {
  private var fixtures = [PoolValuationFixture]()
  override func tearDown() {
    fixtures.forEach { $0.fiat.releaseAll() }
    fixtures = []
    super.tearDown()
  }
  private func make() -> PoolValuationFixture {
    let f = PoolValuationFixture()
    fixtures.append(f)
    return f
  }
  private func wait(_ condition: @escaping () -> Bool) async throws {
    for _ in 0..<100 {
      if condition() { return }
      try await Task.sleep(nanoseconds: 10_000_000)
    }
    XCTFail("Pool valuation did not settle")
  }
  private func ready(_ f: PoolValuationFixture, pools: [PoolInfo]? = nil) async throws {
    f.subject.setup(with: pools ?? [f.pool("A")])
    try await wait { f.fiat.count == 1 }
    f.fiat.answer(0, f.prices)
    try await wait { f.subject.poolViewModels.first?.priceLoadFinished == true }
  }
  func testInitialRowsRetainFavoriteOrderWhilePricesLoad() throws {
    let f = make()
    f.subject.setup(with: [f.pool("B"), f.pool("hidden", favorite: false), f.pool("A")])
    XCTAssertEqual(f.subject.poolViewModels.map(\.identifier), ["B", "A"])
  }
  func testInitialRowsDoNotInventAFiatValueBeforePricesArrive() {
    let f = make()
    f.subject.setup(with: [f.pool("A")])
    XCTAssertEqual(f.subject.poolViewModels.first?.fiatText, "")
    XCTAssertFalse(f.subject.poolViewModels.first?.priceLoadFinished ?? true)
  }
  func testPriceResponseUsesBothExactPooledAmounts() async throws {
    let f = make()
    try await ready(f)
    XCTAssertEqual(f.subject.moneyText, "$13")
    XCTAssertEqual(f.subject.poolViewModels.first?.fiatText, "$13")
    XCTAssertFalse(f.subject.priceIsUnavailable)
  }
  func testNonFavoritePoolsDoNotInflateTheVisibleTotal() async throws {
    let f = make()
    try await ready(f, pools: [f.pool("A"), f.pool("hidden", favorite: false, base: 1000)])
    XCTAssertEqual(f.subject.moneyText, "$13")
    XCTAssertEqual(f.subject.poolViewModels.count, 1)
  }
  func testKnownPricesAndNoFavoritePoolsProduceAnEmptyZeroTotal() async throws {
    let f = make()
    f.subject.setup(with: [f.pool("hidden", favorite: false)])
    try await wait { f.fiat.count == 1 }
    f.fiat.answer(0, f.prices)
    try await wait { f.collector.count >= 2 }
    XCTAssertEqual(f.subject.moneyText, "$0")
    XCTAssertTrue(f.subject.poolViewModels.isEmpty)
    XCTAssertFalse(f.subject.priceIsUnavailable)
  }
  func testMissingPoolPriceIsAnUnavailableTotalRatherThanZero() async throws {
    let f = make()
    f.subject.setup(with: [f.pool("A")])
    try await wait { f.fiat.count == 1 }
    f.fiat.answer(0, [f.prices[0]])
    try await wait { f.collector.count >= 2 }
    XCTAssertTrue(f.subject.priceIsUnavailable)
    XCTAssertEqual(f.subject.moneyText, WalletUX.fiatTotalText(0, pricesAvailable: false))
    XCTAssertEqual(f.subject.poolViewModels.first?.fiatText, "")
    XCTAssertTrue(f.subject.poolViewModels.first?.priceLoadFinished == true)
  }
  func testMissingFiatServiceEndsPlaceholdersWithoutInventingPrices() async throws {
    let f = make()
    f.subject.fiatService = nil
    f.subject.setup(with: [f.pool("A")])
    try await wait { f.collector.count >= 2 }
    XCTAssertTrue(f.subject.priceIsUnavailable)
    XCTAssertTrue(f.subject.poolViewModels.first?.priceLoadFinished == true)
  }
  func testEveryPublishedUpdateRunsOnTheMainThread() async throws {
    let f = make()
    try await ready(f)
    XCTAssertTrue(f.collector.mainFlags.allSatisfy { $0 })
  }
  func testBackgroundPoolDeliveryPublishesItsInitialRowsOnTheMainThread() async throws {
    let f = make()
    let pool = f.pool("A")
    let service = f.subject
    DispatchQueue.global().async { service.loaded(pools: [pool]) }
    try await wait { f.fiat.count == 1 }
    f.fiat.answer(0, f.prices)
    try await wait { f.collector.count >= 2 }
    XCTAssertTrue(f.collector.mainFlags.allSatisfy { $0 })
  }
  func testOlderPriceResponseCannotRestoreAnOlderPoolList() async throws {
    let f = make()
    f.subject.setup(with: [f.pool("old")])
    try await wait { f.fiat.count == 1 }
    f.subject.setup(with: [f.pool("new")])
    try await wait { f.fiat.count == 2 }
    f.fiat.answer(1, f.prices)
    try await wait { f.subject.poolViewModels.first?.priceLoadFinished == true }
    f.fiat.answer(0, f.prices)
    try await Task.sleep(nanoseconds: 50_000_000)
    XCTAssertEqual(f.subject.poolViewModels.map(\.identifier), ["new"])
  }
  func testOlderPriceResponseCannotReplaceTheLatestPriceCache() async throws {
    let f = make()
    f.subject.setup(with: [f.pool("A")])
    try await wait { f.fiat.count == 1 }
    f.subject.setup(with: [f.pool("A")])
    try await wait { f.fiat.count == 2 }
    f.fiat.answer(1, f.prices)
    try await wait { f.subject.poolViewModels.first?.priceLoadFinished == true }
    f.fiat.answer(
      0, [PIExactFiatData(id: WalletAssetId.xor.rawValue, priceUsd: try PIQuantity("999"))])
    try await Task.sleep(nanoseconds: 50_000_000)
    XCTAssertEqual(f.subject.fiatData, f.prices)
    XCTAssertEqual(f.subject.moneyText, "$13")
  }
  func testRemovingAPoolWhileAnOlderPriceReadWaitsKeepsItRemoved() async throws {
    let f = make()
    f.subject.setup(with: [f.pool("old")])
    try await wait { f.fiat.count == 1 }
    f.subject.setup(with: [])
    try await wait { f.fiat.count == 2 }
    f.fiat.answer(1, f.prices)
    try await wait { f.collector.count >= 3 }
    f.fiat.answer(0, f.prices)
    try await Task.sleep(nanoseconds: 50_000_000)
    XCTAssertTrue(f.subject.poolViewModels.isEmpty)
    XCTAssertEqual(f.subject.moneyText, "$0")
  }
  func testCachedPricesAllowANewFavoriteListToRenderImmediately() async throws {
    let f = make()
    try await ready(f)
    f.subject.setup(with: [f.pool("B")])
    XCTAssertEqual(f.subject.poolViewModels.map(\.identifier), ["B"])
    XCTAssertEqual(f.subject.poolViewModels.first?.fiatText, "$13")
  }
  func testCachedPricesDoNotLeaveRemovedFavoritesVisibleDuringRefresh() async throws {
    let f = make()
    try await ready(f)
    f.subject.setup(with: [])
    XCTAssertTrue(f.subject.poolViewModels.isEmpty)
    XCTAssertEqual(f.subject.moneyText, "$0")
  }
  func testCachedPricesRevalueChangedPositionsBeforeTheNextPriceResponse() async throws {
    let f = make()
    try await ready(f)
    f.subject.setup(with: [f.pool("A", base: 4)])
    XCTAssertEqual(f.subject.moneyText, "$23")
  }
  func testPriceChangeNotificationRefreshesOnlyTheLatestPoolSnapshot() async throws {
    let f = make()
    try await ready(f)
    f.subject.setup(with: [f.pool("new")])
    try await wait { f.fiat.count == 2 }
    f.fiat.answer(1, f.prices)
    try await wait { f.subject.poolViewModels.first?.identifier == "new" }
    NotificationCenter.default.post(name: PICatalogs.pricesDidChange, object: nil)
    try await wait { f.fiat.count == 3 }
    f.fiat.answer(2, f.prices)
    try await Task.sleep(nanoseconds: 30_000_000)
    XCTAssertEqual(f.subject.poolViewModels.map(\.identifier), ["new"])
  }
  func testRepeatedSetupDoesNotRegisterDuplicatePriceObservers() async throws {
    let f = make()
    try await ready(f)
    f.subject.setup(with: [f.pool("B")])
    try await wait { f.fiat.count == 2 }
    f.fiat.answer(1, f.prices)
    try await Task.sleep(nanoseconds: 30_000_000)
    NotificationCenter.default.post(name: PICatalogs.pricesDidChange, object: nil)
    try await wait { f.fiat.count >= 3 }
    try await Task.sleep(nanoseconds: 30_000_000)
    XCTAssertEqual(f.fiat.count, 3)
  }
  func testReentrantInitialUpdateDoesNotStartAnObsoletePriceRead() async throws {
    let f = make()
    var replaced = false
    f.subject.updateHandler = { [weak f] in
      guard let f else { return }
      f.collector.record()
      if !replaced, f.subject.poolViewModels.first?.identifier == "old" {
        replaced = true
        f.subject.setup(with: [f.pool("new")])
      }
    }
    f.subject.setup(with: [f.pool("old")])
    try await wait { f.fiat.count > 0 }
    try await Task.sleep(nanoseconds: 30_000_000)
    XCTAssertEqual(f.fiat.count, 1, "Only the latest reentrant setup may request prices")
    for id in 0..<f.fiat.count { f.fiat.answer(id, f.prices) }
    try await Task.sleep(nanoseconds: 30_000_000)
    XCTAssertEqual(f.subject.poolViewModels.map(\.identifier), ["new"])
  }
  func testReentrantCachedUpdateCannotOverwriteTheNestedFavoriteSelection() async throws {
    let f = make()
    try await ready(f)
    var replaced = false
    f.subject.updateHandler = { [weak f] in
      guard let f else { return }
      f.collector.record()
      if !replaced, f.subject.poolViewModels.first?.identifier == "old" {
        replaced = true
        f.subject.setup(with: [f.pool("new")])
      }
    }
    f.subject.setup(with: [f.pool("old")])
    XCTAssertEqual(f.subject.poolViewModels.map(\.identifier), ["new"])
    try await wait { f.fiat.count > 1 }
    try await Task.sleep(nanoseconds: 30_000_000)
    XCTAssertEqual(f.fiat.count, 2)
    for id in 1..<f.fiat.count { f.fiat.answer(id, f.prices) }
    try await Task.sleep(nanoseconds: 30_000_000)
    XCTAssertEqual(f.subject.poolViewModels.map(\.identifier), ["new"])
  }
  func testUnknownAssetsAreOmittedWithoutCrashingTheRestOfThePoolList() async throws {
    let f = make()
    let unknown = PoolInfo(
      baseAssetId: "unknown", targetAssetId: WalletAssetId.val.rawValue, poolId: "bad",
      isFavorite: true, accountId: "")
    try await ready(f, pools: [unknown, f.pool("good")])
    XCTAssertEqual(f.subject.poolViewModels.map(\.identifier), ["good"])
  }
}
@MainActor
private final class PoolValuationFixture {
  let fiat = PoolValuationPrices(), assets = PoolValuationAssets(),
    collector = PoolValuationCollector()
  let subject: PoolsItemService
  let prices = [
    PIExactFiatData(id: WalletAssetId.xor.rawValue, priceUsd: try! PIQuantity("5")),
    PIExactFiatData(id: WalletAssetId.val.rawValue, priceUsd: try! PIQuantity("1")),
  ]
  init() {
    subject = PoolsItemService(
      marketCapService: PoolValuationMarket(), fiatService: fiat,
      poolViewModelsFactory: PoolViewModelFactory(
        walletAssets: assets.assets, assetManager: assets, fiatService: fiat))
    subject.updateHandler = { [collector] in collector.record() }
  }
  func pool(_ id: String, favorite: Bool = true, base: Decimal = 2) -> PoolInfo {
    PoolInfo(
      baseAssetId: WalletAssetId.xor.rawValue, targetAssetId: WalletAssetId.val.rawValue,
      poolId: id, isFavorite: favorite, accountId: "public fixture", baseAssetPooledByAccount: base,
      targetAssetPooledByAccount: 3)
  }
}
private final class PoolValuationCollector {
  private let lock = NSLock()
  private var flags = [Bool]()
  var mainFlags: [Bool] {
    lock.lock()
    defer { lock.unlock() }
    return flags
  }
  var count: Int { mainFlags.count }
  func record() {
    lock.lock()
    flags.append(Thread.isMainThread)
    lock.unlock()
  }
}
private actor PoolValuationPrices: FiatServiceProtocol {
  private nonisolated let state = PoolValuationPriceState()
  nonisolated var count: Int { state.count }
  func getFiat() async -> [PIExactFiatData] { await withCheckedContinuation { state.append($0) } }
  nonisolated func answer(_ id: Int, _ values: [PIExactFiatData]) { state.answer(id, values) }
  nonisolated func releaseAll() { state.releaseAll() }
}
private final class PoolValuationPriceState: @unchecked Sendable {
  private let lock = NSLock()
  private var pending = [Int: CheckedContinuation<[PIExactFiatData], Never>](), calls = 0
  private var closed = false
  var count: Int {
    lock.lock()
    defer { lock.unlock() }
    return calls
  }
  func append(_ c: CheckedContinuation<[PIExactFiatData], Never>) {
    lock.lock()
    if closed {
      lock.unlock()
      c.resume(returning: [])
      return
    }
    pending[calls] = c
    calls += 1
    lock.unlock()
  }
  func answer(_ id: Int, _ values: [PIExactFiatData]) {
    lock.lock()
    let c = pending.removeValue(forKey: id)
    lock.unlock()
    c?.resume(returning: values)
  }
  func releaseAll() {
    lock.lock()
    closed = true
    let all = Array(pending.values)
    pending = [:]
    lock.unlock()
    all.forEach { $0.resume(returning: []) }
  }
}
private final class PoolValuationMarket: MarketCapServiceProtocol {
  func getMarketCap(for assets: [String]) async -> Set<MarketCapInfo> { [] }
}
private final class PoolValuationAssets: AssetManagerProtocol {
  static var networkAssets = [AssetInfo]()
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
  func visibleCount() -> UInt { 3 }
  func setup(for accountSettings: SelectedWalletSettings) {}
}
