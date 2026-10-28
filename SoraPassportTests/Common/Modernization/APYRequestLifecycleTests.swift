// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause
import Foundation
import IrohaCrypto
import RobinHood
import SSFUtils
import XCTest

@testable import SoraPassport

@MainActor
final class APYRequestLifecycleTests: XCTestCase {
  private var previous: AccountItem?
  private let base = WalletAssetId.xor.rawValue, target = WalletAssetId.val.rawValue
  override func setUpWithError() throws {
    previous = SelectedWalletSettings.shared.currentAccount
    try select(3)
  }
  override func tearDown() {
    SelectedWalletSettings.shared.commitInternalValue(previous)
    super.tearDown()
  }
  private func select(_ byte: UInt8) throws {
    let key = Data(repeating: byte, count: 32)
    let account = AccountItem(
      address: try SS58AddressFactory().address(
        fromAccountId: key, type: SNAddressType(chain: .sora)), cryptoType: .sr25519,
      networkType: 69, username: "APY fixture", publicKeyData: key,
      settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: 0,
      isSelected: true)
    SelectedWalletSettings.shared.commitInternalValue(account)
  }
  private func pool(
    id: String = "pair", base: String? = nil, target: String? = nil, apy: String? = "0.125"
  ) throws -> PIPoolXYK {
    PIPoolXYK(
      id: id, baseAssetId: base, targetAssetId: target, baseAssetReserves: nil,
      targetAssetReserves: nil, priceUSD: nil,
      strategicBonusApy: try apy.map { try PIQuantity($0) }, poolTokenSupply: nil,
      poolTokenPriceUSD: nil, liquidityUSD: nil)
  }
  private func configured(_ values: [PIPoolXYK]) async -> (APYService, APYEngine) {
    let engine = APYEngine()
    let service = APYService(pools: { values })
    await service.setup(factory: PolkaswapNetworkOperationFactory(engine: engine))
    return (service, engine)
  }
  private func wait(_ condition: () -> Bool) async -> Bool {
    for _ in 0..<100 {
      if condition() { return true }
      try? await Task.sleep(nanoseconds: 5_000_000)
    }
    return condition()
  }
  func testPairFieldsReturnTheExactRateWithoutAChainRead() async throws {
    let (s, e) = await configured([try pool(base: base, target: target)])
    let value = await s.getApy(for: base, targetAssetId: target)
    XCTAssertEqual(value, Decimal(string: "0.125"))
    XCTAssertEqual(e.count, 0)
  }
  func testPairIdentifierSupportsTheOlderCatalogShape() async throws {
    let (s, e) = await configured([try pool(id: "\(base)-\(target)")])
    let value = await s.getApy(for: base, targetAssetId: target)
    XCTAssertEqual(value, Decimal(string: "0.125"))
    XCTAssertEqual(e.count, 0)
  }
  func testZeroRateRemainsUnknownInsteadOfInventingYield() async throws {
    let (s, e) = await configured([try pool(base: base, target: target, apy: "0")])
    let value = await s.getApy(for: base, targetAssetId: target)
    XCTAssertNil(value)
    XCTAssertEqual(e.count, 0)
  }
  func testNegativeRateIsNotPresentedAsAnEarnedYield() async throws {
    let (s, _) = await configured([try pool(base: base, target: target, apy: "-1")])
    let value = await s.getApy(for: base, targetAssetId: target)
    XCTAssertNil(value)
  }
  func testMissingRateIsNotReplacedByAnotherPoolsRate() async throws {
    let (s, e) = await configured([
      try pool(base: base, target: target, apy: nil), try pool(id: "unrelated", apy: "99"),
    ])
    let value = await s.getApy(for: base, targetAssetId: target)
    XCTAssertNil(value)
    XCTAssertEqual(e.count, 0)
  }
  func testEmptyCatalogDoesNotQueryUnrelatedRuntimeStorage() async {
    let (s, e) = await configured([])
    let value = await s.getApy(for: base, targetAssetId: target)
    XCTAssertNil(value)
    XCTAssertEqual(e.count, 0)
  }
  func testFailedCatalogReturnsNoRateWithoutAChainRead() async {
    let e = APYEngine()
    let s = APYService(pools: { throw APYFailure.offline })
    await s.setup(factory: PolkaswapNetworkOperationFactory(engine: e))
    let value = await s.getApy(for: base, targetAssetId: target)
    XCTAssertNil(value)
    XCTAssertEqual(e.count, 0)
  }
  func testMissingFactoryDoesNotStartTheCatalogRequest() async {
    let catalog = APYCatalog()
    let s = APYService(pools: { try await catalog.load() })
    let value = await s.getApy(for: base, targetAssetId: target)
    XCTAssertNil(value)
    let count = await catalog.count
    XCTAssertEqual(count, 0)
  }
  func testMissingAccountDoesNotStartTheCatalogRequest() async {
    SelectedWalletSettings.shared.commitInternalValue(nil)
    let catalog = APYCatalog()
    let s = APYService(pools: { try await catalog.load() })
    await s.setup(factory: PolkaswapNetworkOperationFactory(engine: APYEngine()))
    let value = await s.getApy(for: base, targetAssetId: target)
    XCTAssertNil(value)
    let count = await catalog.count
    XCTAssertEqual(count, 0)
  }
  func testEmptyAssetIdentifiersDoNotStartTheCatalogRequest() async {
    let catalog = APYCatalog()
    let s = APYService(pools: { try await catalog.load() })
    await s.setup(factory: PolkaswapNetworkOperationFactory(engine: APYEngine()))
    let one = await s.getApy(for: "", targetAssetId: target)
    let two = await s.getApy(for: base, targetAssetId: "")
    XCTAssertNil(one)
    XCTAssertNil(two)
    let count = await catalog.count
    XCTAssertEqual(count, 0)
  }
  func testLegacyReserveAccountLookupUsesTheCorrectPairAndScaleBytes() async throws {
    let key = Data(repeating: 8, count: 32)
    let address = try SS58AddressFactory().address(
      fromAccountId: key, type: SNAddressType(chain: .sora))
    let (s, e) = await configured([try pool(id: address)])
    e.answer = try JSONEncoder().encode("0x" + key.toHex() + Data(repeating: 9, count: 32).toHex())
    let value = await s.getApy(for: base, targetAssetId: target)
    XCTAssertEqual(value, Decimal(string: "0.125"))
    XCTAssertEqual(e.methods, [SoraPassport.RPCMethod.getStorage])
    XCTAssertEqual(
      e.parameters,
      [
        [
          try StorageKeyFactory().poolPropertiesKey(
            baseAssetId: Data(hexStringSSF: base), targetAssetId: Data(hexStringSSF: target)
          ).toHex(includePrefix: true)
        ]
      ])
  }
  func testMissingReserveAccountDoesNotInventAnApy() async throws {
    let (s, e) = await configured([try pool(id: "legacy")])
    e.answer = Data("null".utf8)
    let value = await s.getApy(for: base, targetAssetId: target)
    XCTAssertNil(value)
    XCTAssertEqual(e.count, 1)
  }
  func testMalformedReserveStorageReturnsNoRate() async throws {
    let (s, e) = await configured([try pool(id: "legacy")])
    e.answer = Data("\"0x01\"".utf8)
    let value = await s.getApy(for: base, targetAssetId: target)
    XCTAssertNil(value)
  }
  func testChainFailureReturnsNoRate() async throws {
    let (s, e) = await configured([try pool(id: "legacy")])
    e.failure = APYFailure.offline
    let value = await s.getApy(for: base, targetAssetId: target)
    XCTAssertNil(value)
  }
  func testInvalidAssetEncodingFailsBeforeTransport() async throws {
    let (s, e) = await configured([try pool(id: "legacy")])
    let value = await s.getApy(for: "not-hex", targetAssetId: target)
    XCTAssertNil(value)
    XCTAssertEqual(e.count, 0)
  }
  func testConcurrentRequestsForTheSameAccountAndPairShareOneFlight() async throws {
    let catalog = APYCatalog()
    let s = APYService(pools: { try await catalog.load() })
    await s.setup(factory: PolkaswapNetworkOperationFactory(engine: APYEngine()))
    let first = Task { await s.getApy(for: base, targetAssetId: target) }
    await catalog.waitForCalls(1)
    let second = Task { await s.getApy(for: base, targetAssetId: target) }
    try? await Task.sleep(nanoseconds: 20_000_000)
    let count = await catalog.count
    XCTAssertEqual(count, 1)
    await catalog.release([try pool(base: base, target: target)])
    let a = await first.value
    let b = await second.value
    XCTAssertEqual(a, Decimal(string: "0.125"))
    XCTAssertEqual(b, a)
  }
  func testCompletedRequestsDoNotPermanentlyCacheAnOldRate() async throws {
    let catalog = APYCatalog()
    let s = APYService(pools: { try await catalog.load() })
    await s.setup(factory: PolkaswapNetworkOperationFactory(engine: APYEngine()))
    let first = Task { await s.getApy(for: base, targetAssetId: target) }
    await catalog.waitForCalls(1)
    await catalog.release([try pool(base: base, target: target, apy: "1")])
    let initial = await first.value
    XCTAssertEqual(initial, 1)
    let second = Task { await s.getApy(for: base, targetAssetId: target) }
    await catalog.waitForCalls(2)
    await catalog.release([try pool(base: base, target: target, apy: "2")])
    let updated = await second.value
    XCTAssertEqual(updated, 2)
  }
  func testSwitchingAccountCannotReuseThePreviousAccountsInFlightRequest() async throws {
    let catalog = APYCatalog()
    let s = APYService(pools: { try await catalog.load() })
    await s.setup(factory: PolkaswapNetworkOperationFactory(engine: APYEngine()))
    let first = Task { await s.getApy(for: base, targetAssetId: target) }
    await catalog.waitForCalls(1)
    try select(4)
    let second = Task { await s.getApy(for: base, targetAssetId: target) }
    await catalog.waitForCalls(2)
    let count = await catalog.count
    XCTAssertEqual(count, 2)
    await catalog.release([try pool(base: base, target: target)])
    _ = await first.value
    _ = await second.value
  }
  func testReplacingFactoryCannotReturnTheCancelledCatalogResult() async throws {
    let catalog = APYCatalog()
    let s = APYService(pools: { try await catalog.load() })
    await s.setup(factory: PolkaswapNetworkOperationFactory(engine: APYEngine()))
    let first = Task { await s.getApy(for: base, targetAssetId: target) }
    await catalog.waitForCalls(1)
    await s.setup(factory: PolkaswapNetworkOperationFactory(engine: APYEngine()))
    await catalog.release([try pool(base: base, target: target)])
    let stale = await first.value
    XCTAssertNil(stale)
  }
  func testReplacingFactoryCancelsAnOutstandingLegacyStorageRead() async throws {
    let (s, e) = await configured([try pool(id: "legacy")])
    e.hold = true
    var finished = false
    var result: Decimal? = 99
    let task = Task {
      result = await s.getApy(for: base, targetAssetId: target)
      finished = true
    }
    let started = await wait { e.count == 1 }
    XCTAssertTrue(started)
    await s.setup(factory: PolkaswapNetworkOperationFactory(engine: APYEngine()))
    let completed = await wait { finished }
    XCTAssertTrue(completed)
    XCTAssertNil(result)
    XCTAssertEqual(e.cancellations, [1])
    e.release()
    _ = await task.value
  }
  func testSettingTheSameFactoryDoesNotCancelSharedWork() async throws {
    let catalog = APYCatalog()
    let s = APYService(pools: { try await catalog.load() })
    let factory = PolkaswapNetworkOperationFactory(engine: APYEngine())
    await s.setup(factory: factory)
    let pending = Task { await s.getApy(for: base, targetAssetId: target) }
    await catalog.waitForCalls(1)
    await s.setup(factory: factory)
    await catalog.release([try pool(base: base, target: target)])
    let value = await pending.value
    XCTAssertEqual(value, Decimal(string: "0.125"))
  }
}
private enum APYFailure: Error { case offline }
private actor APYCatalog {
  private(set) var count = 0
  private var waiters: [CheckedContinuation<[PIPoolXYK], Error>] = []
  func load() async throws -> [PIPoolXYK] {
    count += 1
    return try await withCheckedThrowingContinuation { waiters.append($0) }
  }
  func release(_ rows: [PIPoolXYK]) {
    let pending = waiters
    waiters.removeAll()
    pending.forEach { $0.resume(returning: rows) }
  }
  func waitForCalls(_ minimum: Int) async {
    for _ in 0..<100 {
      if count >= minimum { return }
      try? await Task.sleep(nanoseconds: 5_000_000)
    }
    XCTAssertGreaterThanOrEqual(count, minimum)
  }
}
private final class APYEngine: JSONRPCEngine {
  var url: URL?
  var pendingEngineRequests: [JSONRPCRequest] { [] }
  private let lock = NSLock()
  private var recordedMethods: [String] = [], recordedParameters: [[String]] = [],
    cancelled: [UInt16] = []
  private var held: (() -> Void)?
  var answer = Data("null".utf8), failure: Error?, hold = false
  var count: Int {
    lock.lock()
    defer { lock.unlock() }
    return recordedMethods.count
  }
  var methods: [String] {
    lock.lock()
    defer { lock.unlock() }
    return recordedMethods
  }
  var parameters: [[String]] {
    lock.lock()
    defer { lock.unlock() }
    return recordedParameters
  }
  var cancellations: [UInt16] {
    lock.lock()
    defer { lock.unlock() }
    return cancelled
  }
  func callMethod<P: Codable, T: Decodable>(
    _ method: String, params: P?, options: JSONRPCOptions,
    completion closure: ((Result<T, Error>) -> Void)?
  ) throws -> UInt16 {
    let parameters =
      (try? JSONDecoder().decode([String].self, from: JSONEncoder().encode(params))) ?? []
    lock.lock()
    recordedMethods.append(method)
    recordedParameters.append(parameters)
    let deliver: () -> Void = { [self] in
      if let failure {
        closure?(.failure(failure))
      } else {
        closure?(Result { try JSONDecoder().decode(T.self, from: answer) })
      }
    }
    if hold {
      held = deliver
      lock.unlock()
    } else {
      lock.unlock()
      deliver()
    }
    return 1
  }
  func release() {
    lock.lock()
    let closure = held
    held = nil
    lock.unlock()
    closure?()
  }
  func subscribe<P: Codable, T: Decodable>(
    _ method: String, params: P?, updateClosure: @escaping (T) -> Void,
    failureClosure: @escaping (Error, Bool) -> Void
  ) throws -> UInt16 {
    XCTFail("Unexpected subscription")
    throw APYFailure.offline
  }
  func cancelForIdentifier(_ identifier: UInt16) {
    lock.lock()
    cancelled.append(identifier)
    lock.unlock()
    release()
  }
  func generateRequestId() -> UInt16 { 1 }
  func addSubscription(_ subscription: JSONRPCSubscribing) {}
  func connectIfNeeded() {}
  func disconnectIfNeeded() {}
  func unsubsribe(_ identifier: UInt16) throws {}
}
