// SPDX-License-Identifier: Apache-2.0
import BigInt
import Foundation
import IrohaCrypto
import RobinHood
import SSFUtils
import SoraFoundation
import XCTest

@testable import SoraPassport

@MainActor
final class WalletFacadeBalanceFlowTests: XCTestCase {
  private var queues = [OperationQueue]()
  override func tearDown() {
    queues.forEach { $0.cancelAllOperations() }
    queues.removeAll()
    super.tearDown()
  }
  private func run<T>(_ wrapper: CompoundOperationWrapper<T>) async throws -> T {
    let queue = OperationQueue()
    queues.append(queue)
    let done = expectation(description: "balance operations complete")
    wrapper.targetOperation.completionBlock = { done.fulfill() }
    wrapper.allOperations.forEach { queue.addOperation($0) }
    await fulfillment(of: [done], timeout: 2)
    return try XCTUnwrap(wrapper.targetOperation.result).get()
  }
  private func read(
    _ f: FacadeBalanceFixture, _ ids: [String]? = nil, mark: Bool = false, visible: Bool = true
  ) async throws -> [BalanceData] {
    try await run(
      f.facade.fetchBalanceOperation(ids ?? [f.val], onlyVisible: visible, markingUnavailable: mark)
    ) ?? []
  }
  private func equal<T: Equatable>(
    _ a: T, _ b: T, file: StaticString = #filePath, line: UInt = #line
  ) { XCTAssertEqual(a, b, file: file, line: line) }
  func testTokenBalanceUsesItsOwnPrecisionAndLockedAmount() async throws {
    let f = try FacadeBalanceFixture()
    let rows = try await read(f)
    equal(rows.map(\.identifier), [f.val])
    equal((try XCTUnwrap(rows.first)).balance.decimalValue, Decimal(string: "0.8")!)
    let context = BalanceContext(context: (try XCTUnwrap(rows.first)).context ?? [:])
    equal(context.free, 1)
    equal(context.reserved, Decimal(string: "0.3")!)
    equal(context.locked, Decimal(string: "0.2")!)
  }
  func testNativeBalanceUsesRuntime133SystemAccountLayout() async throws {
    let f = try FacadeBalanceFixture()
    let rows = try await read(f, [f.xor])
    equal(rows.count, 1)
    equal((try XCTUnwrap(rows.first)).balance.decimalValue, Decimal(string: "0.8")!)
    equal(
      BalanceContext(context: (try XCTUnwrap(rows.first)).context ?? [:]).reserved,
      Decimal(string: "0.3")!)
  }
  func testNativeValueDoesNotUseTheTokensAccountBalance() async throws {
    let f = try FacadeBalanceFixture()
    f.engine.values[try f.key(f.xor)] = FacadeBalanceFixture.token(999, 0, 0)
    let rows = try await read(f, [f.xor])
    equal((try XCTUnwrap(rows.first)).balance.decimalValue, Decimal(string: "0.8")!)
  }
  func testExplicitNullTokenStorageIsAnAuthoritativeZero() async throws {
    let f = try FacadeBalanceFixture()
    f.engine.values.removeValue(forKey: try f.key(f.val))
    let rows = try await read(f)
    equal((try XCTUnwrap(rows.first)).balance.decimalValue, 0)
    XCTAssertFalse((try XCTUnwrap(rows.first)).isUnavailable)
  }
  func testExplicitNullNativeStorageIsAnAuthoritativeZero() async throws {
    let f = try FacadeBalanceFixture()
    f.engine.native = nil
    let rows = try await read(f, [f.xor])
    equal((try XCTUnwrap(rows.first)).balance.decimalValue, 0)
    XCTAssertFalse((try XCTUnwrap(rows.first)).isUnavailable)
  }
  func testMalformedTokenStorageIsOmittedByDefault() async throws {
    let f = try FacadeBalanceFixture()
    f.engine.values[try f.key(f.val)] = "0xgg"
    equal(try await read(f).count, 0)
  }
  func testMalformedTokenStorageIsMarkedUnavailableWhenRequested() async throws {
    let f = try FacadeBalanceFixture()
    f.engine.values[try f.key(f.val)] = "0xgg"
    let rows = try await read(f, mark: true)
    equal(rows.count, 1)
    XCTAssertTrue((try XCTUnwrap(rows.first)).isUnavailable)
    XCTAssertFalse((try XCTUnwrap(rows.first)).balanceWasNotRead)
  }
  func testMissingTokenResponseIsMarkedNotRead() async throws {
    let f = try FacadeBalanceFixture()
    f.engine.failedKeys.insert(try f.key(f.val))
    let rows = try await read(f, mark: true)
    equal(rows.count, 1)
    XCTAssertTrue((try XCTUnwrap(rows.first)).isUnavailable)
    XCTAssertTrue((try XCTUnwrap(rows.first)).balanceWasNotRead)
  }
  func testEveryTokenIsReadWithOneRequest() async throws {
    let f = try FacadeBalanceFixture()
    let rows = try await read(f, [f.xor, f.val, f.pswap])
    equal(rows.map(\.identifier), [f.xor, f.val, f.pswap])
    // XOR is the account record: exactly one token request, with the two tokens' keys once each.
    equal(f.engine.tokenRequests, [[try f.key(f.val), try f.key(f.pswap)].sorted()])
    // No token is read with a request of its own any more.
    let tokenKeys = Set([try f.key(f.xor), try f.key(f.val), try f.key(f.pswap)])
    XCTAssertTrue(f.engine.storageReads.allSatisfy { !tokenKeys.contains($0) })
  }
  func testThePlaceholderOfAVisibleListIsNotReadFromTheChainAndKeepsItsPlace() async throws {
    let f = try FacadeBalanceFixture()
    // What the real asset manager does for a visible fee asset.
    f.assets.appendsPlaceholder = true
    let rows = try await read(f, [f.xor])
    equal(rows.map(\.identifier), [f.xor, WalletAsset.dummyAsset.identifier])
    equal(rows.last?.balance.decimalValue, 0)
    XCTAssertFalse(try XCTUnwrap(rows.last).isUnavailable)
    XCTAssertTrue(f.engine.tokenRequests.isEmpty)
    // It keeps its place when the tokens beside it cannot be read, too.
    f.engine.tokenFailure = true
    equal(try await read(f, [f.xor, f.val]).map(\.identifier), [f.xor, WalletAsset.dummyAsset.identifier])
  }
  func testOneValueOfTheWrongKindIsThatTokensProblemOnly() async throws {
    let f = try FacadeBalanceFixture()
    let val = try f.key(f.val), pswap = try f.key(f.pswap)
    f.engine.tokenAnswer = { _ in
      [["block": "0x" + String(repeating: "ab", count: 32),
        "changes": [[val, 5], [pswap, FacadeBalanceFixture.token(100, 20, 30)]]]]
    }
    let rows = try await read(f, [f.val, f.pswap], mark: true)
    equal(rows.map(\.identifier), [f.val, f.pswap])
    XCTAssertTrue(rows[0].isUnavailable)
    XCTAssertFalse(rows[0].balanceWasNotRead)
    XCTAssertFalse(rows[1].isUnavailable)
    equal(rows[1].balance.decimalValue, Decimal(string: "0.8")!)
  }
  func testXorAloneSendsNoTokenRequest() async throws {
    let f = try FacadeBalanceFixture()
    _ = try await read(f, [f.xor])
    XCTAssertTrue(f.engine.tokenRequests.isEmpty)
  }
  func testNoAnswerToTheTokenRequestMarksEveryTokenNotRead() async throws {
    let f = try FacadeBalanceFixture()
    f.engine.tokenFailure = true
    let rows = try await read(f, [f.val, f.pswap], mark: true)
    equal(rows.map(\.identifier), [f.val, f.pswap])
    XCTAssertTrue(rows.allSatisfy { $0.isUnavailable && $0.balanceWasNotRead })
    equal(try await read(f, [f.val, f.pswap]).count, 0)
  }
  func testATokenAnswerThatIsNotTheReadAskedForIsUnavailableAndNeverZero() async throws {
    let block = "0x" + String(repeating: "ab", count: 32)
    let answers: [([String]) -> Any] = [
      // A key that was not asked for.
      { keys in [["block": block, "changes": keys.map { [$0, NSNull()] } + [["0x00", NSNull()]]]] },
      // A key twice.
      { keys in [["block": block, "changes": (keys + keys).map { [$0, NSNull()] }]] },
      // Two change sets, or none.
      { keys in [["block": block, "changes": keys.map { [$0, NSNull()] }], ["block": block, "changes": []]] },
      { _ in [] },
    ]
    for answer in answers {
      let f = try FacadeBalanceFixture()
      f.engine.tokenAnswer = answer
      let rows = try await read(f, [f.val, f.pswap], mark: true)
      equal(rows.map(\.identifier), [f.val, f.pswap])
      XCTAssertTrue(rows.allSatisfy { $0.isUnavailable && !$0.balanceWasNotRead })
    }
  }
  func testOneFailedTokenDoesNotEraseAnotherSuccessfulToken() async throws {
    let f = try FacadeBalanceFixture()
    f.engine.failedKeys.insert(try f.key(f.val))
    let rows = try await read(f, [f.val, f.pswap])
    equal(rows.map(\.identifier), [f.pswap])
    equal((try XCTUnwrap(rows.first)).balance.decimalValue, Decimal(string: "0.8")!)
  }
  func testNativeTransportFailureIsAnErrorInsteadOfZero() async throws {
    let f = try FacadeBalanceFixture()
    f.engine.nativeFailure = true
    do {
      _ = try await read(f, [f.xor])
      XCTFail("Expected failed native read")
    } catch {}
  }
  func testRuntimeMetadataFailureIsAnErrorForTheNativeAsset() async throws {
    let f = try FacadeBalanceFixture()
    f.runtime.failure = FacadeBalanceFailure.offline
    do {
      _ = try await read(f, [f.xor])
      XCTFail("Expected failed native decode")
    } catch {}
  }
  func testTokenBalanceRemainsReadableWhenNativeRuntimeMetadataIsUnavailable() async throws {
    let f = try FacadeBalanceFixture()
    f.runtime.failure = FacadeBalanceFailure.offline
    let rows = try await read(f)
    equal((try XCTUnwrap(rows.first)).balance.decimalValue, Decimal(string: "0.8")!)
  }
  func testMalformedNativeStorageCannotBecomeAnEmptyWallet() async throws {
    let f = try FacadeBalanceFixture()
    f.engine.native = "0x0102"
    do {
      _ = try await read(f, [f.xor])
      XCTFail("Expected invalid native storage error")
    } catch {}
  }
  func testMissingNativeStorageChangeCannotBecomeAnEmptyWallet() async throws {
    let f = try FacadeBalanceFixture()
    f.engine.omitNativeChange = true
    do {
      _ = try await read(f, [f.xor])
      XCTFail("An absent storage response is not a confirmed zero")
    } catch {}
  }
  func testEmptyNativeUpdateCannotBecomeAnEmptyWallet() async throws {
    let f = try FacadeBalanceFixture()
    f.engine.emptyNativeUpdate = true
    do {
      _ = try await read(f, [f.xor])
      XCTFail("An empty response is not a confirmed zero")
    } catch {}
  }
  func testRequestPreservesTheAssetManagersDisplayOrder() async throws {
    let f = try FacadeBalanceFixture()
    f.assets.reverse = true
    let rows = try await read(f, [f.val, f.pswap])
    equal(rows.map(\.identifier), [f.pswap, f.val])
    equal(f.assets.visibilityArguments, [true])
  }
  func testIncludingHiddenAssetsIsPassedToTheAssetManager() async throws {
    let f = try FacadeBalanceFixture()
    _ = try await read(f, visible: false)
    equal(f.assets.visibilityArguments, [false])
  }
  func testUnknownAssetRequestDoesNotReadUnrelatedBalances() async throws {
    let f = try FacadeBalanceFixture()
    equal(try await read(f, ["unknown"]).count, 0)
    XCTAssertTrue(f.engine.requests.isEmpty)
  }
  func testEmptyAssetRequestDoesNotReadTheNetwork() async throws {
    let f = try FacadeBalanceFixture()
    equal(try await read(f, []).count, 0)
    XCTAssertTrue(f.engine.requests.isEmpty)
  }
  func testDuplicateRequestedAssetIsReturnedOnlyOnce() async throws {
    let f = try FacadeBalanceFixture()
    let rows = try await read(f, [f.val, f.val])
    equal(rows.map(\.identifier), [f.val])
  }
  func testSyntheticTotalPriceAssetDoesNotTriggerAChainRead() async throws {
    let f = try FacadeBalanceFixture(total: .xor)
    let rows = try await read(f, [f.xor, f.val])
    equal(rows.map(\.identifier), [f.val])
  }
  func testBalanceWaitsForItsStakingContextBeforePublishing() async throws {
    let f = try FacadeBalanceFixture()
    f.engine.delayLedger = true
    let wrapper = f.facade.fetchBalanceOperation([f.xor])
    let queue = OperationQueue()
    queues.append(queue)
    wrapper.allOperations.forEach { queue.addOperation($0) }
    for _ in 0..<100 {
      if f.engine.ledgerPending { break }
      try? await Task.sleep(nanoseconds: 5_000_000)
    }
    try? await Task.sleep(nanoseconds: 30_000_000)
    XCTAssertTrue(f.engine.ledgerPending)
    XCTAssertFalse(
      wrapper.targetOperation.isFinished,
      "The staking fields must belong to the same completed read")
    f.engine.releaseLedger()
    for _ in 0..<100 {
      if wrapper.targetOperation.isFinished { break }
      try? await Task.sleep(nanoseconds: 5_000_000)
    }
    XCTAssertNotNil(wrapper.targetOperation.result)
  }
  func testTokenStorageWithTrailingBytesIsUnavailable() async throws {
    let f = try FacadeBalanceFixture()
    f.engine.values[try f.key(f.val)] = FacadeBalanceFixture.token(100, 20, 30) + "00"
    let rows = try await read(f, mark: true)
    XCTAssertTrue(try XCTUnwrap(rows.first).isUnavailable)
  }
  func testNegativeBalancePrecisionIsUnavailable() async throws {
    let f = try FacadeBalanceFixture(precision: -1)
    let rows = try await read(f, mark: true)
    XCTAssertTrue(try XCTUnwrap(rows.first).isUnavailable)
  }
  func testUnrepresentableNonzeroBalanceIsUnavailableWithoutCrashing() async throws {
    let f = try FacadeBalanceFixture(precision: 255)
    let rows = try await read(f, mark: true)
    XCTAssertTrue(try XCTUnwrap(rows.first).isUnavailable)
  }
  func testZeroBalanceAtHighPrecisionRemainsExactlyZero() async throws {
    let f = try FacadeBalanceFixture(precision: 255)
    f.engine.values[try f.key(f.val)] = FacadeBalanceFixture.token(0, 0, 0)
    let rows = try await read(f, mark: true)
    let row = try XCTUnwrap(rows.first)
    XCTAssertFalse(row.isUnavailable)
    XCTAssertEqual(row.balance.decimalValue, 0)
  }

}
private enum FacadeBalanceFailure: Error { case offline, unexpected }
private final class FacadeBalanceFixture {
  let xor = WalletAssetId.xor.rawValue, val = WalletAssetId.val.rawValue,
    pswap = WalletAssetId.pswap.rawValue, keyData = Data(repeating: 3, count: 32)
  let engine = FacadeBalanceEngine(), assets = FacadeBalanceAssets()
  let runtime: FacadeBalanceRuntime
  let facade: WalletNetworkFacade
  let address: String
  static let coder: Result<RuntimeCoderFactory, Error> = Result {
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
  init(total: WalletAssetId? = nil, precision: Int16 = 2) throws {
    runtime = FacadeBalanceRuntime(coder: try Self.coder.get())
    address = try SS58AddressFactory().addressFromAccountId(
      data: keyData, type: SoraPassport.Chain.sora.addressType())
    let account = WalletAccountSettings(
      accountId: keyData.toHex(),
      assets: [xor, val, pswap].map { id in
        WalletAsset(
          identifier: id, name: LocalizableResource { _ in id }, symbol: id, precision: precision)
      })
    let chain = AnyDataProviderRepository(InMemoryDataProviderRepository<ChainStorageItem>())
    let ids = try ChainStorageIdFactory(chain: .sora)
    let request = StorageRequestFactory(
      remoteFactory: StorageKeyFactory(), operationManager: OperationManager())
    let signer = FacadeBalanceNoSigner()
    let node = WalletNetworkOperationFactory(
      engine: engine, requestFactory: request, runtimeService: runtime, accountSettings: account,
      cryptoType: .sr25519, accountSigner: signer, extrinsicService: FacadeBalanceExtrinsics(),
      dummySigner: signer, chainStorage: chain, localStorageIdFactory: ids)
    facade = WalletNetworkFacade(
      accountSettings: account, nodeOperationFactory: node,
      coingeckoOperationFactory: FacadeBalancePrices(),
      polkaswapNetworkOperationFactory: PolkaswapNetworkOperationFactory(engine: engine),
      chainStorage: chain, localStorageIdFactory: ids,
      txStorage: AnyDataProviderRepository(
        InMemoryDataProviderRepository<TransactionHistoryItem>()),
      contactsOperationFactory: FacadeBalanceContacts(),
      accountsRepository: AnyDataProviderRepository(InMemoryDataProviderRepository<AccountItem>()),
      address: address, networkType: SoraPassport.Chain.sora.addressType(), assetManager: assets,
      totalPriceAssetId: total, runtimeService: runtime, requestFactory: request, engine: engine,
      demeterFarmingService: FacadeBalanceFarms())
    for id in [xor, val, pswap] { engine.values[try key(id)] = Self.token(100, 20, 30) }
    engine.native =
      "0x" + String(repeating: "00", count: 16) + Self.u128(100) + Self.u128(30) + Self.u128(50)
      + Self.u128(0)
    engine.ledgerKey = try StorageKeyFactory().stakingInfoForControllerId(keyData).toHex()
    engine.nativeKey = try StorageKeyFactory().accountInfoKeyForId(keyData).toHex(includePrefix: true)
  }
  func key(_ id: String) throws -> String {
    try StorageKeyFactory().accountsKey(account: keyData, asset: Data.sora(hex: id)).toHex(
      includePrefix: true)
  }
  static func u128(_ value: UInt64) -> String {
    var little = value.littleEndian
    return withUnsafeBytes(of: &little) { Data($0) }.toHex() + String(repeating: "00", count: 8)
  }
  static func token(_ free: UInt64, _ frozen: UInt64, _ reserved: UInt64) -> String {
    "0x" + u128(free) + u128(frozen) + u128(reserved)
  }
}
private final class FacadeBalanceRuntime: SoraPassport.RuntimeCodingServiceProtocol {
  let coder: RuntimeCoderFactoryProtocol
  var failure: Error?
  init(coder: RuntimeCoderFactoryProtocol) { self.coder = coder }
  func fetchCoderFactoryOperation(
    with timeout: TimeInterval, closure: SoraPassport.RuntimeMetadataClosure?
  ) -> BaseOperation<RuntimeCoderFactoryProtocol> {
    ClosureOperation {
      if let failure = self.failure { throw failure }
      return self.coder
    }
  }
}
private final class FacadeBalanceEngine: JSONRPCEngine {
  var url: URL?
  var pendingEngineRequests: [JSONRPCRequest] { [] }
  var values = [String: String](), native: String?, failedKeys = Set<String>(),
    nativeFailure = false, omitNativeChange = false, emptyNativeUpdate = false, delayLedger = false,
    ledgerKey = "", nativeKey = ""
  /// The one request that reads every token: no answer at all, or an answer that is not that read.
  var tokenFailure = false, tokenAnswer: (([String]) -> Any)?
  private let lock = NSLock()
  private var records = [String](), tokenReads = [[String]](), singleReads = [String](),
    ledgerCompletion: (() -> Void)?
  /// The key of each `state_getStorage` request.
  var storageReads: [String] {
    lock.lock()
    defer { lock.unlock() }
    return singleReads
  }
  var requests: [String] {
    lock.lock()
    defer { lock.unlock() }
    return records
  }
  /// The keys of each token storage request.
  var tokenRequests: [[String]] {
    lock.lock()
    defer { lock.unlock() }
    return tokenReads
  }
  var ledgerPending: Bool {
    lock.lock()
    defer { lock.unlock() }
    return ledgerCompletion != nil
  }
  func releaseLedger() {
    lock.lock()
    let callback = ledgerCompletion
    ledgerCompletion = nil
    lock.unlock()
    callback?()
  }
  func callMethod<P: Codable, T: Decodable>(
    _ method: String, params: P?, options: JSONRPCOptions,
    completion closure: ((Result<T, Error>) -> Void)?
  ) throws -> UInt16 {
    let params =
      try JSONSerialization.jsonObject(with: JSONEncoder().encode(params)) as? [Any] ?? []
    lock.lock()
    records.append(method)
    lock.unlock()
    let result = Result<T, Error> {
      let body: Any
      if method == SoraPassport.RPCMethod.queryStorageAt,
        let keys = params.first as? [String], !keys.contains(nativeKey)
      {
        // Every token of the account in one request. A key in `failedKeys` is left out of the
        // answer, as a node that did not read it would.
        lock.lock()
        tokenReads.append(keys)
        lock.unlock()
        if tokenFailure { throw FacadeBalanceFailure.offline }
        let changes: [[Any]] = keys.filter { !failedKeys.contains($0) }.map {
          [$0, values[$0] as Any? ?? NSNull()]
        }
        body =
          tokenAnswer?(keys)
          ?? [["block": "0x" + String(repeating: "ab", count: 32), "changes": changes]]
      } else if method == SoraPassport.RPCMethod.queryStorageAt {
        if nativeFailure { throw FacadeBalanceFailure.offline }
        let keys = try XCTUnwrap(params.first as? [String])
        let changes: [[Any]] =
          omitNativeChange ? [] : keys.map { [$0, native as Any? ?? NSNull()] }
        body =
          emptyNativeUpdate
          ? [] : [["block": "0x" + String(repeating: "ab", count: 32), "changes": changes]]
      } else {
        XCTAssertEqual(method, SoraPassport.RPCMethod.getStorage)
        let key = try XCTUnwrap(params.first as? String)
        lock.lock()
        singleReads.append(key)
        lock.unlock()
        if failedKeys.contains(key) { throw FacadeBalanceFailure.offline }
        body = values[key] as Any? ?? NSNull()
      }
      return try JSONDecoder().decode(
        T.self, from: JSONSerialization.data(withJSONObject: body, options: [.fragmentsAllowed]))
    }
    if delayLedger, params.first as? String == ledgerKey {
      lock.lock()
      ledgerCompletion = { closure?(result) }
      lock.unlock()
    } else {
      DispatchQueue.global().async { closure?(result) }
    }
    return 1
  }
  func subscribe<P: Codable, T: Decodable>(
    _ method: String, params: P?, updateClosure: @escaping (T) -> Void,
    failureClosure: @escaping (Error, Bool) -> Void
  ) throws -> UInt16 { throw FacadeBalanceFailure.unexpected }
  func cancelForIdentifier(_ identifier: UInt16) {}
  func generateRequestId() -> UInt16 { 1 }
  func addSubscription(_ subscription: JSONRPCSubscribing) {}
  func connectIfNeeded() {}
  func disconnectIfNeeded() {}
  func unsubsribe(_ identifier: UInt16) throws {}
}

private final class FacadeBalancePrices: CoingeckoOperationFactoryProtocol {
  var requests = [[String]](), values = [PriceData](), failure: Swift.Error?
  func fetchPriceOperation(for tokenIds: [String]) -> BaseOperation<[PriceData]> {
    requests.append(tokenIds)
    return ClosureOperation {
      if let failure = self.failure { throw failure }
      return self.values
    }
  }
}
private final class FacadeBalanceContacts: WalletContactOperationFactoryProtocol {
  var items = [ContactItem](), failure: Swift.Error?
  func saveByAddressOperation(_ address: String) -> CompoundOperationWrapper<Void> {
    XCTFail("Unexpected contact mutation")
    return .init(targetOperation: ClosureOperation { () })
  }
  func fetchContactsOperation() -> CompoundOperationWrapper<[ContactItem]> {
    .init(
      targetOperation: ClosureOperation {
        if let failure = self.failure { throw failure }
        return self.items
      })
  }
}
private final class FacadeBalanceAssets: AssetManagerProtocol {
  var reverse = false, appendsPlaceholder = false, visibilityArguments = [Bool]()
  static var networkAssets = [AssetInfo]()
  var items = [(WalletAssetId.xor, "XOR"), (.val, "VAL")].map {
    AssetInfo(
      id: $0.0.rawValue, symbol: $0.1, chainId: "", precision: 18, icon: nil, displayName: $0.1,
      visible: true)
  }
  func assetInfo(for identifier: String) -> AssetInfo? {
    items.first { $0.identifier == identifier }
  }
  func getAssetList() -> [AssetInfo]? { items }
  func updateAssetList(_ list: [AssetInfo]) { items = list }
  func saveAssetList(_ list: [AssetInfo]) { items = list }
  func sortedAssets(_ list: [WalletAsset], onlyVisible: Bool) -> [WalletAsset] {
    visibilityArguments.append(onlyVisible)
    let sorted = reverse ? Array(list.reversed()) : list
    return appendsPlaceholder ? sorted + [WalletAsset.dummyAsset] : sorted
  }
  func visibleCount() -> UInt { UInt(items.count) }
  func setup(for accountSettings: SelectedWalletSettings) {}
}
private final class FacadeBalanceFarms: DemeterFarmingServiceProtocol {
  var failure: Swift.Error?, reads = [Data]()
  func getUserFarmInfos(baseAssetId: String?, targetAssetId: String?) async -> [UserFarm] { [] }
  func loadUserFarmInfos(baseAssetId: String?, targetAssetId: String?, accountId: Data) async throws
    -> [UserFarm]
  {
    reads.append(accountId)
    if let failure { throw failure }
    return []
  }
  func getAllFarms() async throws -> [Farm] { [] }
  func getFarm(with id: String) -> Farm? { nil }
  func getFarmDetails(baseAssetId: String, poolAssetId: String, rewardAssetId: String) async throws
    -> [Farm]
  { [] }
  func getSingleSidedXorFarmedPools(completion: @escaping ([UserFarmInfo]) -> Void) {
    completion([])
  }
}
private final class FacadeBalanceExtrinsics: ExtrinsicServiceProtocol {
  var rawFee = "7"
  var failure: Error?
  var builders: [FacadeBalanceBuilder] = []
  var estimateCount = 0
  var prepareCount = 0
  var submitCount = 0
  var preparedSubmitCount = 0
  var cancelAfterPrepare = false
  var prepared: PreparedExtrinsicSubmission?
  let call = FacadeBalanceCall()
  private func record(_ closure: ExtrinsicBuilderClosure) throws {
    let builder = FacadeBalanceBuilder()
    _ = try closure(builder)
    builders.append(builder)
    if let failure { throw failure }
  }
  func estimateFee(
    _ closure: @escaping ExtrinsicBuilderClosure, runningIn queue: DispatchQueue,
    completion: @escaping EstimateFeeClosure
  ) {
    estimateCount += 1
    do {
      try record(closure)
      completion(.success(rawFee))
    } catch { completion(.failure(error)) }
  }
  func prepareAndEstimateFee(
    _ closure: @escaping ExtrinsicBuilderClosure, signer: SigningWrapperProtocol,
    preSigningValidation: @escaping () throws -> Void, runningIn queue: DispatchQueue,
    completion: @escaping (Result<PreparedExtrinsicFeeQualification, Error>) -> Void
  ) -> CancellableCall {
    prepareCount += 1
    do {
      try preSigningValidation()
      try record(closure)
      let bytes = Data([1, 2, 3, 4])
      let result = PreparedExtrinsicSubmission(
        data: bytes, hash: try bytes.blake2b32().toHex(includePrefix: true))
      prepared = result
      if cancelAfterPrepare { withUnsafeCurrentTask { $0?.cancel() } }
      completion(.success(PreparedExtrinsicFeeQualification(prepared: result, rawFee: rawFee)))
    } catch { completion(.failure(error)) }
    return call
  }
  func prepareAndEstimateFee(
    _ closure: @escaping ExtrinsicBuilderClosure, signer: SigningWrapperProtocol,
    lifecycleLease: WalletLifecycleLease?,
    runtimeValidation: ((RuntimeCoderFactoryProtocol) throws -> Void)?,
    finalizedHeadValidation: ((String) throws -> Void)?,
    preSigningValidation: @escaping () throws -> Void,
    runningIn queue: DispatchQueue,
    completion: @escaping (Result<PreparedExtrinsicFeeQualification, Error>) -> Void
  ) -> CancellableCall {
    XCTFail("Unexpected lifecycle preparation")
    completion(.failure(FacadeBalanceFailure.unexpected))
    return call
  }
  func submit(
    _ closure: @escaping ExtrinsicBuilderClosure, signer: SigningWrapperProtocol,
    runningIn queue: DispatchQueue,
    completion: @escaping ExtrinsicSubmitClosure
  ) {
    submitCount += 1
    do {
      try record(closure)
      completion(
        .success("0x" + String(repeating: "0a", count: 32)),
        "0x" + String(repeating: "0a", count: 32), nil)
    } catch { completion(.failure(error), nil, nil) }
  }
  func submit(
    _ closure: @escaping ExtrinsicBuilderClosure, signer: SigningWrapperProtocol,
    lifecycleLease: WalletLifecycleLease?,
    runningIn queue: DispatchQueue, completion: @escaping ExtrinsicSubmitClosure
  ) {
    XCTFail("Unexpected lifecycle submission")
    completion(.failure(FacadeBalanceFailure.unexpected), nil, nil)
  }
  func prepare(
    _ closure: @escaping ExtrinsicBuilderClosure, signer: SigningWrapperProtocol,
    runningIn queue: DispatchQueue,
    completion: @escaping (Result<PreparedExtrinsicSubmission, Error>) -> Void
  ) {
    XCTFail("Unexpected unqualified preparation")
    completion(.failure(FacadeBalanceFailure.unexpected))
  }
  func prepare(
    _ closure: @escaping ExtrinsicBuilderClosure, signer: SigningWrapperProtocol,
    lifecycleLease: WalletLifecycleLease?,
    runtimeValidation: ((RuntimeCoderFactoryProtocol) throws -> Void)?,
    preSigningValidation: (() throws -> Void)?,
    runningIn queue: DispatchQueue,
    completion: @escaping (Result<PreparedExtrinsicSubmission, Error>) -> Void
  ) {
    XCTFail("Unexpected lifecycle preparation")
    completion(.failure(FacadeBalanceFailure.unexpected))
  }
  func submitPrepared(
    _ prepared: PreparedExtrinsicSubmission, retainingTransportWitness: Bool,
    expectedRawFee: String,
    preTransportValidation: @escaping () throws -> Void, runningIn queue: DispatchQueue,
    completion: @escaping (Result<String, Error>) -> Void
  ) -> CancellableCall {
    preparedSubmitCount += 1
    XCTFail("Unexpected transport")
    completion(.failure(FacadeBalanceFailure.unexpected))
    return call
  }
}
private final class FacadeBalanceBuilder: SoraPassport.ExtrinsicBuilderProtocol {
  var calls: [JSON] = []
  var atomicSelections: [Bool] = []
  func with<A: Codable>(address: A) throws -> Self {
    XCTFail("Unexpected address binding")
    return self
  }
  func with(nonce: UInt32) -> Self {
    XCTFail("Unexpected nonce")
    return self
  }
  func with(era: Era, blockHash: String) -> Self {
    XCTFail("Unexpected era")
    return self
  }
  func with(tip: BigUInt) -> Self {
    XCTFail("Unexpected tip")
    return self
  }
  func with(shouldUseAtomicBatch: Bool) -> Self {
    atomicSelections.append(shouldUseAtomicBatch)
    return self
  }
  func adding<T: RuntimeCallable>(call: T) throws -> Self {
    let encoded = try JSONEncoder.scaleCompatible().encode(
      SoraPassport.EncodingContainer(value: call))
    calls.append(
      try JSONDecoder.scaleCompatible(snakeCase: false).decode(
        SoraPassport.JsonContainer.self, from: encoded
      ).value)
    return self
  }
  func adding(rawCall: Data) throws -> Self {
    XCTFail("Unexpected raw call")
    throw FacadeBalanceFailure.unexpected
  }
  func signing(
    by signer: (Data) throws -> Data, of type: SoraPassport.CryptoType,
    using encoder: DynamicScaleEncoding,
    metadata: RuntimeMetadata
  ) throws -> Self {
    XCTFail("Unexpected signing")
    throw FacadeBalanceFailure.unexpected
  }
  func buildExtrinsic(metadata: RuntimeMetadata) throws -> Extrinsic {
    XCTFail("Unexpected extrinsic build")
    throw FacadeBalanceFailure.unexpected
  }
  func build(encodingBy encoder: DynamicScaleEncoding, metadata: RuntimeMetadata) throws -> Data {
    throw FacadeBalanceFailure.unexpected
  }
  func buildSignature(encodingBy encoder: DynamicScaleEncoding, metadata: RuntimeMetadata) throws
    -> Data
  { throw FacadeBalanceFailure.unexpected }
}
private final class FacadeBalanceNoSigner: SigningWrapperProtocol {
  func sign(_ originalData: Data) throws -> IRSignatureProtocol {
    XCTFail("No signing is permitted in these factory tests")
    throw FacadeBalanceFailure.unexpected
  }
}

private final class FacadeBalanceCall: CancellableCall { func cancel() {} }
