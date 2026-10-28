// SPDX-License-Identifier: BSD-4-Clause
import Foundation
import RobinHood
import SSFUtils
import XCTest

@testable import SoraPassport

@MainActor
final class PolkaswapSubscriptionFlowTests: XCTestCase {
  private var fixtures = [SwapSubscriptionFixture]()
  override func tearDown() {
    fixtures.forEach { $0.subject?.stop() }
    fixtures = []
    super.tearDown()
  }
  private func make() -> SwapSubscriptionFixture {
    let f = SwapSubscriptionFixture()
    fixtures.append(f)
    return f
  }
  private func settle() async { try? await Task.sleep(nanoseconds: 35_000_000) }
  private func best(_ a: String, _ b: String, variant: SwapVariant = .desiredOutput) -> (
    quote: SwapValues?, dexId: UInt32
  ) {
    PolkaswapMainInteractor.bestQuote(
      [(SwapValues(amount: a, route: []), 7), (SwapValues(amount: b, route: []), 9)],
      swapVariant: variant)
  }
  func testDesiredOutputIgnoresMalformedCandidateInsteadOfSelectingZero() {
    XCTAssertEqual(best("invalid", "100").dexId, 9)
  }
  func testDesiredOutputIgnoresPartiallyParsedCandidate() {
    XCTAssertEqual(best("1trailing", "100").dexId, 9)
  }
  func testDesiredOutputIgnoresNegativeCandidate() { XCTAssertEqual(best("-1", "100").dexId, 9) }
  func testZeroRequiredInputCannotWinAQuote() { XCTAssertEqual(best("0", "100").dexId, 9) }
  func testDecimalWireAmountCannotWinAQuote() { XCTAssertEqual(best("1.25", "100").dexId, 9) }
  func testExponentWireAmountCannotWinAQuote() { XCTAssertEqual(best("1e1", "100").dexId, 9) }
  func testSignedWireAmountCannotWinAQuote() { XCTAssertEqual(best("+1", "100").dexId, 9) }
  func testWhitespaceWireAmountCannotWinAQuote() { XCTAssertEqual(best(" 1", "100").dexId, 9) }
  func testNoncanonicalLeadingZeroWireAmountCannotWinAQuote() {
    XCTAssertEqual(best("01", "100").dexId, 9)
  }
  func testDesiredInputIgnoresPartiallyParsedLargerCandidate() {
    XCTAssertEqual(best("999trailing", "100", variant: .desiredInput).dexId, 9)
  }
  func testDesiredInputComparesMaxU128AmountsWithoutDecimalRounding() {
    let a = "340282366920938463463374607431768211454"
    let b = "340282366920938463463374607431768211455"
    XCTAssertEqual(best(a, b, variant: .desiredInput).quote?.amount, b)
  }
  func testDesiredOutputComparesMaxU128AmountsWithoutDecimalRounding() {
    let a = "340282366920938463463374607431768211455"
    let b = "340282366920938463463374607431768211454"
    XCTAssertEqual(best(a, b).quote?.amount, b)
  }
  func testAmountAboveRuntimeU128CannotWinDesiredInput() {
    XCTAssertEqual(
      best("340282366920938463463374607431768211456", "100", variant: .desiredInput).dexId, 9)
  }
  func testAllInvalidQuotesProduceNoCandidate() {
    let r = best("invalid", "-2")
    XCTAssertNil(r.quote)
    XCTAssertEqual(r.dexId, 0)
  }
  func testEmptyQuoteSetProducesNoCandidate() {
    let r = PolkaswapMainInteractor.bestQuote([], swapVariant: .desiredInput)
    XCTAssertNil(r.quote)
    XCTAssertEqual(r.dexId, 0)
  }
  func testEqualValidQuotesKeepStableFirstDex() {
    XCTAssertEqual(best("100", "100").dexId, 7)
    XCTAssertEqual(best("100", "100", variant: .desiredInput).dexId, 7)
  }
  func testXYKSubscriptionUsesExactPairStorageKey() throws {
    let f = make()
    f.subject.subscribePoolXYK(assetId1: f.xor, assetId2: f.val)
    XCTAssertEqual(f.engine.methods, [SoraPassport.RPCMethod.storageSubscribe])
    let expected = try StorageKeyFactory().xykPoolKey(
      asset1: Data.sora(hex: f.xor), asset2: Data.sora(hex: f.val)
    ).toHex(includePrefix: true)
    XCTAssertEqual(f.engine.params, [[[expected]]])
    XCTAssertEqual(f.subject.xykPoolSubscriptionIds, [1])
  }
  func testTBCSubscriptionUsesExactAssetStorageKey() throws {
    let f = make()
    f.subject.subscribePoolTBC(assetId: f.val)
    let expected = try StorageKeyFactory().tbcPoolKey(asset: Data.sora(hex: f.val)).toHex(
      includePrefix: true)
    XCTAssertEqual(f.engine.params, [[[expected]]])
    XCTAssertEqual(f.subject.tbcPoolSubscriptionIds, [1])
  }
  func testInvalidXYKAssetCannotStartStorageSubscription() {
    let f = make()
    f.subject.subscribePoolXYK(assetId1: "not-hex", assetId2: f.val)
    XCTAssertTrue(f.engine.methods.isEmpty)
    XCTAssertTrue(f.subject.xykPoolSubscriptionIds.isEmpty)
  }
  func testInvalidTBCAssetCannotStartStorageSubscription() {
    let f = make()
    f.subject.subscribePoolTBC(assetId: "not-hex")
    XCTAssertTrue(f.engine.methods.isEmpty)
  }
  func testFailedSubscriptionDoesNotRecordAFalseIdentifier() {
    let f = make()
    f.engine.fail = true
    f.subject.subscribePoolXYK(assetId1: f.xor, assetId2: f.val)
    XCTAssertTrue(f.subject.xykPoolSubscriptionIds.isEmpty)
  }
  func testXYKUnsubscribeCancelsAllIdsExactlyOnce() {
    let f = make()
    f.subject.subscribePoolXYK(assetId1: f.xor, assetId2: f.val)
    f.subject.subscribePoolXYK(assetId1: f.val, assetId2: f.xor)
    f.subject.unsubscribePoolXYK()
    f.subject.unsubscribePoolXYK()
    XCTAssertEqual(f.engine.cancelled, [1, 2])
    XCTAssertTrue(f.subject.xykPoolSubscriptionIds.isEmpty)
  }
  func testTBCUnsubscribeCancelsAllIdsExactlyOnce() {
    let f = make()
    f.subject.subscribePoolTBC(assetId: f.val)
    f.subject.subscribePoolTBC(assetId: f.xor)
    f.subject.unsubscribePoolTBC()
    f.subject.unsubscribePoolTBC()
    XCTAssertEqual(f.engine.cancelled, [1, 2])
    XCTAssertTrue(f.subject.tbcPoolSubscriptionIds.isEmpty)
  }
  func testStoppingCancelsBothPoolFamilies() {
    let f = make()
    f.subject.setup()
    f.subject.subscribePoolXYK(assetId1: f.xor, assetId2: f.val)
    f.subject.subscribePoolTBC(assetId: f.val)
    f.subject.stop()
    XCTAssertEqual(Set(f.engine.cancelled), [1, 2])
    XCTAssertTrue(f.subject.xykPoolSubscriptionIds.isEmpty)
    XCTAssertTrue(f.subject.tbcPoolSubscriptionIds.isEmpty)
  }
  func testSubscriptionUpdateIsDeliveredOnMainThread() async throws {
    let f = make()
    f.subject.subscribePoolXYK(assetId1: f.xor, assetId2: f.val)
    try f.engine.emit(1)
    await settle()
    XCTAssertEqual(f.presenter.updates, 1)
    XCTAssertTrue(f.presenter.mainThreads.allSatisfy { $0 })
  }
  func testCancelledXYKSubscriptionCannotPublishALateUpdate() async throws {
    let f = make()
    f.subject.subscribePoolXYK(assetId1: f.xor, assetId2: f.val)
    f.subject.unsubscribePoolXYK()
    try f.engine.emit(1)
    await settle()
    XCTAssertEqual(f.presenter.updates, 0)
  }
  func testCancelledTBCSubscriptionCannotPublishALateUpdate() async throws {
    let f = make()
    f.subject.subscribePoolTBC(assetId: f.val)
    f.subject.unsubscribePoolTBC()
    try f.engine.emit(1)
    await settle()
    XCTAssertEqual(f.presenter.updates, 0)
  }
  func testQueuedUpdateCannotPublishAfterStop() async throws {
    let f = make()
    f.subject.setup()
    f.subject.subscribePoolXYK(assetId1: f.xor, assetId2: f.val)
    try f.engine.emit(1)
    f.subject.stop()
    await settle()
    XCTAssertEqual(f.presenter.updates, 0)
  }
  func testOldSubscriptionRemainsInvalidAfterAReplacement() async throws {
    let f = make()
    f.subject.subscribePoolXYK(assetId1: f.xor, assetId2: f.val)
    f.subject.unsubscribePoolXYK()
    f.subject.subscribePoolXYK(assetId1: f.val, assetId2: f.xor)
    try f.engine.emit(1)
    try f.engine.emit(2)
    await settle()
    XCTAssertEqual(f.presenter.updates, 1)
  }
  func testXYKUnsubscribeDoesNotCancelTheIndependentTBCSubscription() async throws {
    let f = make()
    f.subject.subscribePoolXYK(assetId1: f.xor, assetId2: f.val)
    f.subject.subscribePoolTBC(assetId: f.val)
    f.subject.unsubscribePoolXYK()
    try f.engine.emit(2)
    await settle()
    XCTAssertEqual(f.engine.cancelled, [1])
    XCTAssertEqual(f.presenter.updates, 1)
  }
  func testSubscriptionCancellationUsesTheEngineThatCreatedIt() {
    let f = make()
    f.subject.subscribePoolXYK(assetId1: f.xor, assetId2: f.val)
    let fresh = SwapSubscriptionEngine()
    f.subject.polkaswapNetworkFacade = PolkaswapNetworkOperationFactory(engine: fresh)
    f.subject.unsubscribePoolXYK()
    XCTAssertEqual(f.engine.cancelled, [1])
    XCTAssertTrue(fresh.cancelled.isEmpty)
  }
  func testRepeatedSetupDoesNotRegisterDuplicateObservers() {
    let f = make()
    f.subject.setup()
    f.subject.setup()
    XCTAssertEqual(f.events.adds, 1)
  }
  func testStoppedInteractorMayRegisterAgain() {
    let f = make()
    f.subject.setup()
    f.subject.stop()
    f.subject.setup()
    XCTAssertEqual(f.events.adds, 2)
    XCTAssertEqual(f.events.removes, 1)
  }
  func testReleasedInteractorCancelsItsSubscriptions() {
    let f = make()
    f.subject.subscribePoolTBC(assetId: f.val)
    weak var old = f.subject
    f.subject = nil
    XCTAssertNil(old)
    XCTAssertEqual(f.engine.cancelled, [1])
  }
  func testJSONParameterConversionPreservesExactStrings() throws {
    let f = make()
    let encoded = try XCTUnwrap(f.subject.json(from: ["amount": "9007199254740993"]))
    let decoded = try JSONSerialization.jsonObject(with: Data(encoded.utf8)) as? [[String: String]]
    XCTAssertEqual(decoded, [["amount": "9007199254740993"]])
  }
  func testUnsupportedJSONParameterReturnsNoPayload() {
    let f = make()
    XCTAssertNil(f.subject.json(from: Date()))
  }
}
@MainActor private final class SwapSubscriptionFixture {
  let xor = WalletAssetId.xor.rawValue, val = WalletAssetId.val.rawValue,
    engine = SwapSubscriptionEngine(), events = SwapSubscriptionEvents(),
    presenter = SwapSubscriptionPresenter()
  var subject: PolkaswapMainInteractor!
  init() {
    subject = PolkaswapMainInteractor(operationManager: OperationManager(), eventCenter: events)
    subject.polkaswapNetworkFacade = PolkaswapNetworkOperationFactory(engine: engine)
    subject.presenter = presenter
  }
}
private final class SwapSubscriptionPresenter: PolkaswapMainInteractorOutputProtocol {
  var updates = 0, mainThreads = [Bool]()
  func didLoadQuote(_ quote: SwapValues?, dexId: UInt32, params: PolkaswapMainInteractorQuoteParams)
  {}
  func didUpdatePoolSubscription() {
    updates += 1
    mainThreads.append(Thread.isMainThread)
  }
}
private final class SwapSubscriptionEvents: EventCenterProtocol {
  var adds = 0, removes = 0
  func add(observer: EventVisitorProtocol, dispatchIn queue: DispatchQueue?) { adds += 1 }
  func remove(observer: EventVisitorProtocol) { removes += 1 }
  func notify(with event: EventProtocol) {}
  func notify(with event: EventProtocol, completionOnMain: @escaping () -> Void) {
    completionOnMain()
  }
}
private final class SwapSubscriptionEngine: JSONRPCEngine {
  var url: URL? = URL(string: "wss://no-transport.invalid")
  var pendingEngineRequests: [JSONRPCRequest] { [] }
  var methods = [String](), params = [[[String]]](), cancelled = [UInt16](), fail = false
  var callbacks = [UInt16: (Data) throws -> Void]()
  func callMethod<P: Codable, T: Decodable>(
    _ method: String, params: P?, options: JSONRPCOptions,
    completion closure: ((Result<T, Error>) -> Void)?
  ) throws -> UInt16 {
    XCTFail("Unexpected RPC")
    throw SwapSubscriptionFailure.offline
  }
  func subscribe<P: Codable, T: Decodable>(
    _ method: String, params: P?, updateClosure: @escaping (T) -> Void,
    failureClosure: @escaping (Error, Bool) -> Void
  ) throws -> UInt16 {
    if fail { throw SwapSubscriptionFailure.offline }
    methods.append(method)
    self.params.append(
      try JSONDecoder().decode([[String]].self, from: JSONEncoder().encode(params)))
    let id = UInt16(methods.count)
    callbacks[id] = { try updateClosure(JSONDecoder().decode(T.self, from: $0)) }
    return id
  }
  func emit(_ id: UInt16) throws {
    try callbacks[id]?(
      Data(
        #"{"jsonrpc":"2.0","method":"state_storage","params":{"subscription":"1","result":{"block":"0x00","changes":[]}}}"#
          .utf8))
  }
  func cancelForIdentifier(_ identifier: UInt16) { cancelled.append(identifier) }
  func generateRequestId() -> UInt16 { 1 }
  func addSubscription(_ subscription: JSONRPCSubscribing) {}
  func reconnect(url: URL) {}
  func connectIfNeeded() {}
  func disconnectIfNeeded() {}
  func unsubsribe(_ subscriptionId: UInt16) throws { cancelForIdentifier(subscriptionId) }
}
private enum SwapSubscriptionFailure: Error { case offline }
