// SPDX-License-Identifier: Apache-2.0
import BigInt
import Foundation
import IrohaCrypto
import RobinHood
import SSFModels
import SSFUtils
import SoraFoundation
import SoraKeystore
import XCTest

@testable import SoraPassport

/// Runs the real coordinator through future-qualified local policy plus fresh
/// intercepted PI authority. Runtime reads are real SCALE fixtures; extrinsic
/// signing and submission are recording boundaries and journals are temporary.
@MainActor
final class PolkamarktSubmissionBoundaryTests: XCTestCase {
  private var fixtures = [SubmitFlowFixture]()
  override func tearDown() {
    fixtures.forEach { $0.cleanup() }
    fixtures = []
    super.tearDown()
  }
  private func make(qualified: Bool = true) throws -> SubmitFlowFixture {
    let f = try SubmitFlowFixture(qualified: qualified)
    fixtures.append(f)
    return f
  }
  private func equal<T: Equatable>(
    _ a: T, _ b: T, file: StaticString = #filePath, line: UInt = #line
  ) { XCTAssertEqual(a, b, file: file, line: line) }
  private func fails(
    _ expected: PolkamarktRuntimeError? = nil, _ work: () async throws -> Void,
    file: StaticString = #filePath, line: UInt = #line
  ) async {
    do {
      try await work()
      XCTFail("Unqualified mutation accepted", file: file, line: line)
    } catch {
      if let expected {
        equal(String(describing: error), String(describing: expected), file: file, line: line)
      }
    }
  }
  func testProductionLocalQualificationStillRejectsEvenFreshRemotePermission() async throws {
    let f = try make(qualified: ProductionMutationQualification.polkamarktMutations)
    XCTAssertFalse(ProductionMutationQualification.polkamarktMutations)
    await fails(.mutationsDisabled) { _ = try await f.subject.submitTrade(f.request()) }
    equal(f.extrinsics.prepareCount, 0)
    equal(f.extrinsics.preparedSubmitCount, 0)
  }
  func testRemoteKillSwitchStillRejectsQualifiedLocalFixture() async throws {
    let f = try make()
    f.configEnabled = false
    await fails(.mutationsDisabled) { _ = try await f.subject.submitTrade(f.request()) }
    equal(f.extrinsics.prepareCount, 0)
  }
  func testBuySignsOneExactCallAndPersistsItsHashBeforeTransport() async throws {
    let f = try make()
    let row = try await f.subject.submitTrade(f.request())
    equal(row.state, .submitted)
    equal(row.account, f.account.address)
    equal(row.action, "buy_yes")
    equal(row.marketIds, [42])
    equal(row.extrinsicHash, f.extrinsics.prepared?.hash)
    equal(f.extrinsics.transportRows.first?.state, .signedBeforeTransport)
    equal(f.extrinsics.transportRows.first?.extrinsicHash, row.extrinsicHash)
    equal(f.extrinsics.prepareCount, 1)
    equal(f.extrinsics.preparedSubmitCount, 1)
    equal(f.extrinsics.transported, [Data([1, 2, 3, 4])])
    equal(f.extrinsics.suppliedFee, "7")
    XCTAssertTrue(f.extrinsics.retainingWitness)
    equal(try await f.pending.all(), [row])
    XCTAssertThrowsError(try f.extrinsics.prepared?.consumeForTransport())
    let c = try XCTUnwrap(f.extrinsics.builders.last?.calls.first).plainMap(
      to: RuntimeCall<PolkamarktBuyCall>.self)
    equal(c.args.marketId, 42)
    equal(c.args.collateralIn, 1000)
    equal(c.args.minSharesOut, 2199)
    equal(c.args.outcome, .yes)
  }
  func testSellBuildsExactOutcomeSharesAndReviewedMinimum() async throws {
    let f = try make()
    let row = try await f.subject.submitTrade(f.request(side: .sell))
    equal(row.action, "sell_no")
    equal(row.state, .submitted)
    let c = try XCTUnwrap(f.extrinsics.builders.last?.calls.first).plainMap(
      to: RuntimeCall<PolkamarktSellCall>.self)
    equal(c.args.outcome, .no)
    equal(c.args.sharesIn, 1000)
    equal(c.args.minCollateralOut, 549)
  }
  func testTraderClaimKeepsTheReviewedSingleMarket() async throws {
    let f = try make()
    let authorization = try await f.authorization()
    let row = try await f.subject.submitTraderClaim(authorization)
    equal(row.state, .submitted)
    equal(row.action, PolkamarktRuntimeContract.Call.claimMarket)
    let c = try XCTUnwrap(f.extrinsics.builders.last?.calls.first).plainMap(
      to: RuntimeCall<PolkamarktMarketCall>.self)
    equal(c.args.marketId, 42)
  }
  func testBatchClaimBuildsTheReviewedSortedMarketSet() async throws {
    let f = try make()
    let authorization = try await f.authorization(ids: [1, 2])
    let row = try await f.subject.submitBatchClaim(authorization)
    equal(row.marketIds, [1, 2])
    equal(row.action, PolkamarktRuntimeContract.Call.claimMarkets)
    let c = try XCTUnwrap(f.extrinsics.builders.last?.calls.first).plainMap(
      to: RuntimeCall<PolkamarktBatchClaimCall>.self)
    equal(c.args.marketIds, [1, 2])
  }
  func testCreatorFeeClaimUsesOnlyItsReviewedMarket() async throws {
    let f = try make()
    let authorization = try await f.authorization(creator: true)
    let row = try await f.subject.submitCreatorFeeClaim(authorization)
    equal(row.marketIds, [42])
    equal(row.action, PolkamarktRuntimeContract.Call.claimCreatorFees)
  }
  func testTradeRejectsZeroBeforeReadingRuntimeOrSigning() async throws {
    let f = try make()
    await fails(.invalidAmount) { _ = try await f.subject.submitTrade(f.request(input: 0)) }
    equal(f.extrinsics.prepareCount, 0)
    equal(f.server.methods, [])
  }
  func testChangedMarketCloseBlockRejectsTheTradeReview() async throws {
    let f = try make()
    f.server.market = f.markets["Open400"]
    await fails(.marketUnavailable) { _ = try await f.subject.submitTrade(f.request()) }
    equal(f.extrinsics.prepareCount, 0)
  }
  func testChangedMarketFeeRejectsTheTradeReview() async throws {
    let f = try make()
    f.server.buyOverrides = ["feeAmount": "6"]
    await fails(.staleQuote) { _ = try await f.subject.submitTrade(f.request()) }
    equal(f.extrinsics.prepareCount, 0)
  }
  func testRefreshedOutputBelowMinimumRejectsTheTradeReview() async throws {
    let f = try make()
    f.server.buyOverrides = ["sharesOut": "2198"]
    await fails { _ = try await f.subject.submitTrade(f.request()) }
    equal(f.extrinsics.prepareCount, 0)
  }
  func testWrongOutcomeCannotReuseAnotherOutcomeQuote() async throws {
    let f = try make()
    f.server.buyOverrides = ["outcome": "No"]
    await fails { _ = try await f.subject.submitTrade(f.request()) }
    equal(f.extrinsics.prepareCount, 0)
  }
  func testInsufficientCollateralStopsBeforeSigning() async throws {
    let f = try make()
    f.server.kusd = "999"
    await fails(.insufficientKUSD) { _ = try await f.subject.submitTrade(f.request()) }
    equal(f.extrinsics.prepareCount, 0)
  }
  func testInsufficientSharesStopsBeforeSigning() async throws {
    let f = try make()
    f.server.noShares = "999"
    await fails(.insufficientShares) { _ = try await f.subject.submitTrade(f.request(side: .sell)) }
    equal(f.extrinsics.prepareCount, 0)
  }
  func testNetworkFeeAboveReviewStopsBeforeSigning() async throws {
    let f = try make()
    f.extrinsics.rawFee = "8"
    await fails(.staleQuote) { _ = try await f.subject.submitTrade(f.request()) }
    equal(f.extrinsics.prepareCount, 0)
  }
  func testBalanceChangesAtFinalSigningReadAreRejected() async throws {
    let f = try make()
    f.extrinsics.onFee = { if f.extrinsics.estimateCount == 2 { f.server.kusd = "999" } }
    await fails(.insufficientKUSD) { _ = try await f.subject.submitTrade(f.request()) }
    equal(f.extrinsics.prepareCount, 0)
  }
  func testExactSignedFeeAboveMaximumDiscardsPreparedBytes() async throws {
    let f = try make()
    f.extrinsics.exactFee = "8"
    await fails(.staleQuote) { _ = try await f.subject.submitTrade(f.request()) }
    equal(try await f.pending.all().first?.state, .failedBeforeSubmission)
    equal(f.extrinsics.preparedSubmitCount, 0)
    XCTAssertThrowsError(try f.extrinsics.prepared?.consumeForTransport())
  }
  func testMalformedExactFeeFailsClosedAndDiscardsPreparedBytes() async throws {
    let f = try make()
    f.extrinsics.exactFee = "7trailing"
    await fails { _ = try await f.subject.submitTrade(f.request()) }
    equal(try await f.pending.all().first?.state, .failedBeforeSubmission)
    equal(f.extrinsics.preparedSubmitCount, 0)
    XCTAssertThrowsError(try f.extrinsics.prepared?.consumeForTransport())
  }
  func testMissingXorAfterSigningDiscardsPreparedBytes() async throws {
    let f = try make()
    f.extrinsics.afterPrepare = { f.server.xor = "6" }
    await fails(.insufficientXOR) { _ = try await f.subject.submitTrade(f.request()) }
    equal(try await f.pending.all().first?.state, .failedBeforeSubmission)
    equal(f.extrinsics.preparedSubmitCount, 0)
    XCTAssertThrowsError(try f.extrinsics.prepared?.consumeForTransport())
  }
  func testAccountChangedImmediatelyBeforeSigningCannotBuildTheCall() async throws {
    let f = try make()
    f.extrinsics.beforePrepare = { f.selected = nil }
    await fails(.wrongWalletOrNetwork) { _ = try await f.subject.submitTrade(f.request()) }
    equal(try await f.pending.all().first?.state, .failedBeforeSubmission)
    XCTAssertNil(f.extrinsics.prepared)
  }
  func testRevokedSessionImmediatelyBeforeSigningCannotBuildTheCall() async throws {
    let f = try make()
    f.extrinsics.beforePrepare = { ProductionRemoteCapabilitySession.shared.invalidate() }
    await fails(.mutationsDisabled) { _ = try await f.subject.submitTrade(f.request()) }
    XCTAssertNil(f.extrinsics.prepared)
  }
  func testSigningHeadMismatchRejectsBeforePreparingBytes() async throws {
    let f = try make()
    f.extrinsics.head = "0x" + String(repeating: "cd", count: 32)
    await fails { _ = try await f.subject.submitTrade(f.request()) }
    XCTAssertNil(f.extrinsics.prepared)
  }
  func testInvalidPreparedHashCannotEnterTransport() async throws {
    let f = try make()
    f.extrinsics.invalidPreparedHash = true
    await fails(.invalidTransactionHash) { _ = try await f.subject.submitTrade(f.request()) }
    equal(try await f.pending.all().first?.state, .failedBeforeSubmission)
    equal(f.extrinsics.preparedSubmitCount, 0)
  }
  func testRemoteRevocationAfterSigningWipesBytesBeforeTransport() async throws {
    let f = try make()
    f.extrinsics.afterPrepare = { f.configEnabled = false }
    await fails(.mutationsDisabled) { _ = try await f.subject.submitTrade(f.request()) }
    equal(try await f.pending.all().first?.state, .failedBeforeSubmission)
    equal(f.extrinsics.preparedSubmitCount, 0)
    XCTAssertThrowsError(try f.extrinsics.prepared?.consumeForTransport())
  }
  func testCancellationAfterPreparationCannotEnterTransport() async throws {
    let f = try make()
    f.extrinsics.cancelAfterPrepare = true
    let task = Task { try await f.subject.submitTrade(f.request()) }
    do {
      _ = try await task.value
      XCTFail("Cancelled trade submitted")
    } catch { XCTAssertTrue(error is CancellationError) }
    equal(try await f.pending.all().first?.state, .failedBeforeSubmission)
    equal(f.extrinsics.preparedSubmitCount, 0)
  }
  func testWrongReturnedHashRetainsTheLocalHashAsAmbiguous() async throws {
    let f = try make()
    f.extrinsics.returnedHash = "0x" + String(repeating: "cd", count: 32)
    await fails(.ambiguousSubmission) { _ = try await f.subject.submitTrade(f.request()) }
    let rows = try await f.pending.all()
    let row = try XCTUnwrap(rows.first)
    equal(row.state, .submissionUnknown)
    equal(row.extrinsicHash, f.extrinsics.prepared?.hash)
  }
  func testDefinitePreTransportFailureMarksRetrySafeWithoutSending() async throws {
    let f = try make()
    f.extrinsics.transportFailure = PreparedExtrinsicTransportError.failedBeforeTransport(
      SubmitFlowFailure.offline)
    await fails { _ = try await f.subject.submitTrade(f.request()) }
    equal(try await f.pending.all().first?.state, .failedBeforeSubmission)
    equal(f.extrinsics.transported, [])
  }
  func testUnknownTransportFailureRetainsAmbiguousJournal() async throws {
    let f = try make()
    f.extrinsics.transportFailure = PreparedExtrinsicTransportError.submissionUnknown(
      SubmitFlowFailure.offline)
    await fails(.ambiguousSubmission) { _ = try await f.subject.submitTrade(f.request()) }
    equal(try await f.pending.all().first?.state, .submissionUnknown)
  }
  func testPendingTradePreventsSecondSignatureOnRetry() async throws {
    let f = try make()
    _ = try await f.subject.submitTrade(f.request())
    await fails { _ = try await f.subject.submitTrade(f.request()) }
    equal(f.extrinsics.prepareCount, 1)
  }
  func testStaleClaimAmountIsRejectedBeforeSigning() async throws {
    let f = try make()
    let authorization = try await f.authorization()
    f.server.payout = "11"
    await fails { _ = try await f.subject.submitTraderClaim(authorization) }
    equal(f.extrinsics.prepareCount, 0)
  }
  func testCreatorReviewCannotBeReusedAsTraderPayout() async throws {
    let f = try make()
    let authorization = try await f.authorization(creator: true)
    await fails { _ = try await f.subject.submitTraderClaim(authorization) }
    equal(f.extrinsics.prepareCount, 0)
  }
  func testSingleReviewCannotBecomeBatchClaim() async throws {
    let f = try make()
    let authorization = try await f.authorization()
    await fails { _ = try await f.subject.submitBatchClaim(authorization) }
    equal(f.extrinsics.prepareCount, 0)
  }
}

private enum SubmitFlowFailure: Swift.Error { case offline, unexpected }
@MainActor
private final class SubmitFlowFixture {
  let settings = InMemorySettingsManager(), server = SubmitFlowServer(),
    extrinsics = SubmitFlowExtrinsics()
  let account: AccountItem
  var selected: AccountItem?
  let directory: URL, session: URLSession, engine: Sora2BoundedHTTPJSONRPCEngine,
    runtime: SubmitFlowRuntime
  let markets: [String: String]
  let pending: PolkamarktPendingStore
  let witness: Sora2PendingSubmissionStore
  let piSession: URLSession
  var configEnabled = true
  var configRequests = 0
  var disableConfigAfter = Int.max
  var subject: PolkamarktTransactionCoordinator!
  var context: SubmitFlowContext!
  static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
  static let metadata = try! Data(
    contentsOf: root.appendingPathComponent("Fixtures/Modernization/sora2-metadata-spec130.scale"))
  static let coder: Result<RuntimeCoderFactory, Swift.Error> = Result {
    let snapshot = try RuntimeSnapshotFactory.makeOwnTypesSnapshot(
      chainId: PIIndexerClient.soraMainnetGenesis,
      runtimeMetadataItem: SoraPassport.RuntimeMetadataItem(
        chain: PIIndexerClient.soraMainnetGenesis, version: 130, txVersion: 130, metadata: metadata,
        resolver: nil),
      ownTypes: Data(
        contentsOf: root.appendingPathComponent("SoraPassport/Resources/runtime-sora.json")),
      dataHasher: .twox256)
    return RuntimeCoderFactory(
      catalog: snapshot.typeRegistryCatalog, specVersion: 130, txVersion: 130,
      metadata: snapshot.metadata)
  }
  init(qualified: Bool = true) throws {
    let key = Data(repeating: 3, count: 32)
    account = AccountItem(
      address: try SS58AddressFactory().addressFromAccountId(
        data: key, type: SoraPassport.Chain.sora.addressType()), cryptoType: .sr25519,
      networkType: SoraPassport.Chain.sora.addressType(), username: "Public fixture",
      publicKeyData: key, settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []),
      order: 0, isSelected: false)
    selected = account
    directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let object =
      try JSONSerialization.jsonObject(
        with: Data(
          contentsOf: Self.root.appendingPathComponent(
            "Fixtures/Modernization/polkamarkt-market-storage-v130.json"))) as! [String: Any]
    markets = object["markets"] as! [String: String]
    server.market = markets["Open500"]!
    server.metadataHex = Self.metadata.toHex(includePrefix: true)
    server.owner = account.address
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [SubmitFlowURLProtocol.self]
    session = URLSession(configuration: configuration)
    SubmitFlowURLProtocol.handler = { [server] in try server.response($0) }
    engine = Sora2BoundedHTTPJSONRPCEngine(
      nodeURL: URL(string: "https://polkamarkt.test")!, session: session)
    runtime = SubmitFlowRuntime(coder: try Self.coder.get())
    let accountSettings = WalletAccountSettings(accountId: key.toHex(), assets: [])
    let requestFactory = StorageRequestFactory(
      remoteFactory: StorageKeyFactory(), operationManager: OperationManager())
    let chain = AnyDataProviderRepository(InMemoryDataProviderRepository<ChainStorageItem>())
    let ids = try ChainStorageIdFactory(chain: .sora)
    let signer = SubmitFlowNoSigner()
    let node = WalletNetworkOperationFactory(
      engine: engine, requestFactory: requestFactory, runtimeService: runtime,
      accountSettings: accountSettings, cryptoType: .sr25519, accountSigner: signer,
      extrinsicService: extrinsics, dummySigner: signer, chainStorage: chain,
      localStorageIdFactory: ids)
    let facade = WalletNetworkFacade(
      accountSettings: accountSettings, nodeOperationFactory: node,
      coingeckoOperationFactory: SubmitFlowPrices(),
      polkaswapNetworkOperationFactory: PolkaswapNetworkOperationFactory(engine: engine),
      chainStorage: chain, localStorageIdFactory: ids,
      txStorage: AnyDataProviderRepository(
        InMemoryDataProviderRepository<TransactionHistoryItem>()),
      contactsOperationFactory: SubmitFlowContacts(),
      accountsRepository: AnyDataProviderRepository(InMemoryDataProviderRepository<AccountItem>()),
      address: account.address, networkType: SoraPassport.Chain.sora.addressType(),
      assetManager: SubmitFlowAssets(), totalPriceAssetId: nil, runtimeService: runtime,
      requestFactory: requestFactory, engine: engine, demeterFarmingService: SubmitFlowFarms())
    context = SubmitFlowContext(facade: facade)
    settings.polkamarktEnabled = true
    pending = try PolkamarktPendingStore(baseURL: directory)
    witness = try Sora2PendingSubmissionStore(baseURL: directory)
    piSession = PIStubIndexerProtocol.session()
    let client = PIIndexerClient(
      session: piSession, historyShapeMemory: PIHistoryShapeMemory(),
      cacheDirectory: directory.appendingPathComponent("pi-cache"), retryPause: { _ in })
    subject = PolkamarktTransactionCoordinator(
      walletContext: context, pendingStore: pending, settings: settings, featureClient: client,
      selectedAccount: { [weak self] in self?.selected }, localMutationQualification: qualified)
    extrinsics.journal = pending
    extrinsics.coder = runtime.coder
    extrinsics.head = server.block
    PIStubIndexerProtocol.install { [weak self] request in
      guard let self else { return .init(status: 503, body: "{}") }
      if request.operation == "MobileHealth" {
        return .init(
          body: PIAdvancingIndexer.health(
            indexed: 400, finalized: 401, indexedAt: Int(Date().timeIntervalSince1970) - 1))
      }
      guard request.operation == "MobileConfig" else { return .init(status: 400, body: "{}") }
      self.configRequests += 1
      let enabled = self.configEnabled && self.configRequests <= self.disableConfigAfter
      let bytes = try! PIIndexerFixture.data("mobile-config")
      var envelope = try! JSONSerialization.jsonObject(with: bytes) as! [String: Any]
      var data = envelope["data"] as! [String: Any]
      var config = data["mobileConfig"] as! [String: Any]
      config["polkamarktMutationsAvailable"] = enabled
      data["mobileConfig"] = config
      envelope["data"] = data
      return .init(
        body: String(data: try! JSONSerialization.data(withJSONObject: envelope), encoding: .utf8)!)
    }

  }
  func quote(
    side: PolkamarktSide = .buy, outcome: PolkamarktOutcome = .yes, input: BigUInt = 1000,
    slippage: UInt16 = 100
  ) async throws -> PolkamarktQuoteConfirmation {
    try await subject.quote(
      account: account.address, marketId: 42, outcome: outcome, side: side, input: input,
      slippageBasisPoints: slippage)
  }
  func cleanup() {
    session.invalidateAndCancel()
    piSession.invalidateAndCancel()
    PIStubIndexerProtocol.uninstall()
    ProductionRemoteCapabilitySession.shared.invalidate()
    SubmitFlowURLProtocol.handler = nil
    try? FileManager.default.removeItem(at: directory)
  }
  func request(
    side: PolkamarktSide = .buy, input: BigUInt = 1000, min: BigUInt? = nil, maxFee: BigUInt = 7
  ) -> PolkamarktTradeRequest {
    .init(
      account: account.address, marketId: 42, outcome: side == .buy ? .yes : .no, side: side,
      input: input, minimumOutput: min ?? (side == .buy ? 2199 : 549), confirmedCloseBlock: 500,
      confirmedMarketFee: side == .buy ? 5 : 1, maximumNetworkFee: maxFee)
  }
  func authorization(ids: [UInt32] = [42], creator: Bool = false) async throws
    -> PolkamarktClaimAuthorization
  {
    server.claimStatus = "Resolved"
    server.payout = "12"
    server.creatorFees = "4"
    server.isCreator = creator
    let review = try await subject.authoritativeClaimables(account: account.address, marketIds: ids)
    return .init(
      account: account.address, source: ids.count == 1 ? .selectedDetail : .reviewedPositions,
      reviewedFinalizedBlockHash: review.finalizedBlockHash, claims: review.claims,
      kind: creator ? .creatorFees : .traderPayout)
  }

}
private final class SubmitFlowContext: CommonWalletContextProtocol {
  let facade: WalletNetworkFacade
  init(facade: WalletNetworkFacade) { self.facade = facade }
  var networkOperationFactory: WalletNetworkOperationFactoryProtocol { facade }
  func prepareAccountUpdateCommand() -> WalletCommandProtocol { WalletCommandMock() }
  func prepareLanguageSwitchCommand(with newLanguage: WalletLanguage) -> WalletCommandProtocol {
    WalletCommandMock()
  }
}
private final class SubmitFlowRuntime: SoraPassport.RuntimeCodingServiceProtocol {
  let coder: RuntimeCoderFactoryProtocol
  var failure: Swift.Error?
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
private final class SubmitFlowServer {
  let block = "0x" + String(repeating: "ab", count: 32)
  var owner = "", claimOwner: String?, market: String?, metadataHex = "",
    genesis = PIIndexerClient.soraMainnetGenesis
  var stateId = 42, kusd = "10000", xor = "20000", yesShares = "2000", noShares = "1500",
    claimMissing = false
  var buyOverrides = [String: Any](), sellOverrides = [String: Any]()
  var recoveryEvents: String?
  var claimStatus = "Open", payout = "0", creatorFees = "0", isCreator = false
  private let lock = NSLock()
  private var recorded = [String]()
  var methods: [String] {
    lock.lock()
    defer { lock.unlock() }
    return recorded
  }
  func response(_ request: URLRequest) throws -> Data {
    let body: Data
    if let data = request.httpBody {
      body = data
    } else if let stream = request.httpBodyStream {
      stream.open()
      defer { stream.close() }
      var data = Data()
      var buffer = [UInt8](repeating: 0, count: 8192)
      while stream.hasBytesAvailable {
        let count = stream.read(&buffer, maxLength: buffer.count)
        if count <= 0 { break }
        data.append(buffer, count: count)
      }
      body = data
    } else {
      throw SubmitFlowFailure.unexpected
    }
    let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
    let method = try XCTUnwrap(object["method"] as? String)
    let params = object["params"] as? [Any] ?? []
    lock.lock()
    recorded.append(method)
    lock.unlock()
    let result: Any
    switch method {
    case SoraPassport.RPCMethod.getBlockHash:
      result = (params.first as? Int) == 0 ? genesis : block
    case SoraPassport.RPCMethod.getChainBlock:
      result = ["block": ["header": ["number": "0x190", "parentHash": block, "extrinsicsRoot": block, "stateRoot": block, "digest": ["logs": []]], "extrinsics": ["0x00"]]]
    case SoraPassport.RPCMethod.getRuntimeMetadata: result = metadataHex
    case SoraPassport.RPCMethod.getHead: result = block
    case SoraPassport.RPCMethod.getHeader:
      result = [
        "number": "0x190", "parentHash": block, "extrinsicsRoot": block, "stateRoot": block,
        "digest": ["logs": []],
      ]
    case SoraPassport.RPCMethod.queryStorageAt:
      let keys = try XCTUnwrap(params.first as? [String])
      if let recoveryEvents {
        XCTAssertEqual(keys, [try StorageKeyFactory().key(from: .events).toHex(includePrefix: true)])
        XCTAssertEqual(params.last as? String, block)
        result = [["block": block, "changes": keys.map { [$0, recoveryEvents] }]]
      } else {
        XCTAssertEqual(keys, ["0x7c9df7ef418f869f0ab365233bda527fd8426954fc0e154310293fc43493f5829017d1c733ec2aeaa6fd0230614e397e2a000000"])
        result = [["block": block, "changes": keys.map { [$0, market as Any? ?? NSNull()] }]]
      }
    case PolkamarktRuntimeContract.RPC.marketState:
      result = [
        "marketId": stateId, "mechanism": "DynamicParimutuel", "virtualDepth": "100",
        "realYesShares": "6000", "realNoShares": "4000", "dpmCollateral": "10000",
        "marginalYesPriceBps": 5500, "marginalNoPriceBps": 4500, "impliedYesProbabilityBps": 6000,
        "impliedNoProbabilityBps": 4000,
      ]
    case PolkamarktRuntimeContract.RPC.quoteBuy:
      result = [
        "marketId": 42, "outcome": "Yes", "collateralIn": "1000", "feeAmount": "5",
        "pricingCollateral": "995", "sharesOut": "2222",
      ].merging(buyOverrides) { _, new in new }
    case PolkamarktRuntimeContract.RPC.quoteSell:
      result = [
        "marketId": 42, "outcome": "No", "sharesIn": "1000", "grossCollateralOut": "556",
        "feeAmount": "1", "collateralOut": "555",
      ].merging(sellOverrides) { _, new in new }
    case PolkamarktRuntimeContract.RPC.claimable:
      result =
        claimMissing
        ? NSNull()
        : [
          "marketId": params[1], "account": claimOwner ?? owner, "status": claimStatus,
          "resolutionOutcome": claimStatus == "Resolved" ? "Yes" : NSNull(), "yesShares": yesShares,
          "noShares": noShares, "netCollateralPaid": "900", "traderPayout": payout,
          "claimablePayout": payout, "creatorFees": creatorFees, "isCreator": isCreator,
        ]
    case SoraPassport.RPCMethod.freeBalance:
      result = ["balance": (params[1] as? String) == WalletAssetId.xor.rawValue ? xor : kusd]
    default: throw SubmitFlowFailure.unexpected
    }
    return try JSONSerialization.data(withJSONObject: [
      "jsonrpc": "2.0", "id": object["id"]!, "result": result,
    ])
  }
}
private final class SubmitFlowURLProtocol: URLProtocol {
  static var handler: ((URLRequest) throws -> Data)?
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    do {
      let data = try Self.handler?(request) ?? { throw SubmitFlowFailure.unexpected }()
      let response = HTTPURLResponse(
        url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1",
        headerFields: ["Content-Type": "application/json"])!
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    } catch { client?.urlProtocol(self, didFailWithError: error) }
  }
  override func stopLoading() {}
}

private final class SubmitFlowExtrinsics: ExtrinsicServiceProtocol {
  var rawFee = "7", exactFee = "7", head = ""
  var coder: RuntimeCoderFactoryProtocol!
  var beforePrepare: (() -> Void)?, afterPrepare: (() -> Void)?, beforeTransport: (() -> Void)?
  var transportFailure: Error?, returnedHash: String?, invalidPreparedHash = false
  var suppliedFee: String?, retainingWitness = false, transported = [Data]()
  var journal: PolkamarktPendingStore!
  var transportRows = [PolkamarktPendingMutation]()
  var exactValidationFailure: Error?
  var holdFee = false, heldFee: EstimateFeeClosure?, onFee: (() -> Void)?
  var failure: Error?
  var builders: [SubmitFlowBuilder] = []
  var estimateCount = 0
  var prepareCount = 0
  var submitCount = 0
  var preparedSubmitCount = 0
  var cancelAfterPrepare = false
  var prepared: PreparedExtrinsicSubmission?
  let call = SubmitFlowCall()
  private func record(_ closure: ExtrinsicBuilderClosure) throws {
    let builder = SubmitFlowBuilder()
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
      onFee?()
      if holdFee { heldFee = completion } else { completion(.success(rawFee)) }
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
    prepareCount += 1
    do {
      beforePrepare?()
      try runtimeValidation?(coder)
      try finalizedHeadValidation?(head)
      try preSigningValidation()
      if let exactValidationFailure { throw exactValidationFailure }
      try record(closure)
      let bytes = Data([1, 2, 3, 4])
      let value = PreparedExtrinsicSubmission(
        data: bytes,
        hash: invalidPreparedHash ? "invalid" : try bytes.blake2b32().toHex(includePrefix: true))
      prepared = value
      afterPrepare?()
      if cancelAfterPrepare { withUnsafeCurrentTask { $0?.cancel() } }
      completion(.success(PreparedExtrinsicFeeQualification(prepared: value, rawFee: exactFee)))
    } catch { completion(.failure(error)) }
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
    completion(.failure(SubmitFlowFailure.unexpected), nil, nil)
  }
  func prepare(
    _ closure: @escaping ExtrinsicBuilderClosure, signer: SigningWrapperProtocol,
    runningIn queue: DispatchQueue,
    completion: @escaping (Result<PreparedExtrinsicSubmission, Error>) -> Void
  ) {
    XCTFail("Unexpected unqualified preparation")
    completion(.failure(SubmitFlowFailure.unexpected))
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
    completion(.failure(SubmitFlowFailure.unexpected))
  }
  func submitPrepared(
    _ prepared: PreparedExtrinsicSubmission, retainingTransportWitness: Bool,
    expectedRawFee: String,
    preTransportValidation: @escaping () throws -> Void, runningIn queue: DispatchQueue,
    completion: @escaping (Result<String, Error>) -> Void
  ) -> CancellableCall {
    preparedSubmitCount += 1
    suppliedFee = expectedRawFee
    retainingWitness = retainingTransportWitness
    Task {
      do {
        do {
          beforeTransport?()
          try preTransportValidation()
        } catch { throw PreparedExtrinsicTransportError.failedBeforeTransport(error) }
        transportRows = try await journal.all()
        if let transportFailure,
          case .failedBeforeTransport = transportFailure as? PreparedExtrinsicTransportError
        {
          throw transportFailure
        }
        let payload = try prepared.consumeForTransport()
        transported.append(try Data(hexStringSSF: payload.consumeHexForTransport()))
        payload.discard()
        if let transportFailure { throw transportFailure }
        completion(.success(returnedHash ?? prepared.hash))
      } catch {
        prepared.discard()
        completion(.failure(error))
      }
    }
    return call
  }
}
private final class SubmitFlowBuilder: SoraPassport.ExtrinsicBuilderProtocol {
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
    throw SubmitFlowFailure.unexpected
  }
  func signing(
    by signer: (Data) throws -> Data, of type: SoraPassport.CryptoType,
    using encoder: DynamicScaleEncoding,
    metadata: RuntimeMetadata
  ) throws -> Self {
    XCTFail("Unexpected signing")
    throw SubmitFlowFailure.unexpected
  }
  func buildExtrinsic(metadata: RuntimeMetadata) throws -> Extrinsic {
    XCTFail("Unexpected extrinsic build")
    throw SubmitFlowFailure.unexpected
  }
  func build(encodingBy encoder: DynamicScaleEncoding, metadata: RuntimeMetadata) throws -> Data {
    throw SubmitFlowFailure.unexpected
  }
  func buildSignature(encodingBy encoder: DynamicScaleEncoding, metadata: RuntimeMetadata) throws
    -> Data
  { throw SubmitFlowFailure.unexpected }
}
private final class SubmitFlowNoSigner: SigningWrapperProtocol {
  func sign(_ originalData: Data) throws -> IRSignatureProtocol {
    XCTFail("No signing is permitted in these factory tests")
    throw SubmitFlowFailure.unexpected
  }
}

private final class SubmitFlowCall: CancellableCall { func cancel() {} }

private final class SubmitFlowPrices: CoingeckoOperationFactoryProtocol {
  var requests = [[String]](), values = [SoraPassport.PriceData](), failure: Swift.Error?
  func fetchPriceOperation(for tokenIds: [String]) -> BaseOperation<[SoraPassport.PriceData]> {
    requests.append(tokenIds)
    return ClosureOperation {
      if let failure = self.failure { throw failure }
      return self.values
    }
  }
}
private final class SubmitFlowContacts: WalletContactOperationFactoryProtocol {
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
private final class SubmitFlowAssets: AssetManagerProtocol {
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
  func sortedAssets(_ list: [WalletAsset], onlyVisible: Bool) -> [WalletAsset] { list }
  func visibleCount() -> UInt { UInt(items.count) }
  func setup(for accountSettings: SelectedWalletSettings) {}
}
private final class SubmitFlowFarms: DemeterFarmingServiceProtocol {
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


extension PolkamarktSubmissionBoundaryTests {
  func testCanonicalSuccessEventFinalizesTheExactIndexedTransaction() async throws {
    let f = try make()
    try await f.prepareRecovery(events: [(0, true)])
    let rows = try await f.subject.reconcilePending(account: f.account.address)
    equal(rows.first?.state, .finalized)
    equal(rows.first?.finalizedBlock, 400)
    equal(try await f.pending.all(), rows)
    equal(f.extrinsics.prepareCount, 0)
    equal(f.extrinsics.preparedSubmitCount, 0)
    XCTAssertTrue(f.server.methods.contains(SoraPassport.RPCMethod.queryStorageAt))
  }

  func testCanonicalFailureOverridesAnIndexerSuccessFlag() async throws {
    let f = try make()
    try await f.prepareRecovery(events: [(0, false)])
    let rows = try await f.subject.reconcilePending(account: f.account.address)
    equal(rows.first?.state, .rejected)
    equal(rows.first?.finalizedBlock, 400)
    equal(try await f.pending.all(), rows)
    equal(f.extrinsics.preparedSubmitCount, 0)
  }

  func testEventsForAnotherExtrinsicCannotResolveThePendingTransaction() async throws {
    let f = try make()
    try await f.prepareRecovery(events: [(1, true), (2, false)])
    let rows = try await f.subject.reconcilePending(account: f.account.address)
    equal(rows.first?.state, .submitted)
    XCTAssertNil(rows.first?.finalizedBlock)
  }

  func testConflictingCanonicalEventsKeepTheTransactionUnresolved() async throws {
    let f = try make()
    try await f.prepareRecovery(events: [(0, true), (0, false)])
    equal(try await f.subject.reconcilePending(account: f.account.address).first?.state, .submitted)
    equal(try await f.pending.all().first?.state, .submitted)
  }

  func testDuplicateCanonicalSuccessEventsCannotReleaseAdmission() async throws {
    let f = try make()
    try await f.prepareRecovery(events: [(0, true), (0, true)])
    await fails(.unavailable) { _ = try await f.subject.reconcilePending(account: f.account.address) }
    equal(try await f.pending.all().first?.state, .submitted)
  }

  func testDuplicateCanonicalFailureEventsCannotReleaseAdmission() async throws {
    let f = try make()
    try await f.prepareRecovery(events: [(0, false), (0, false)])
    await fails(.unavailable) { _ = try await f.subject.reconcilePending(account: f.account.address) }
    equal(try await f.pending.all().first?.state, .submitted)
  }

  func testEmptyCanonicalEventsDoNotInventASuccess() async throws {
    let f = try make()
    try await f.prepareRecovery(events: [])
    equal(try await f.subject.reconcilePending(account: f.account.address).first?.state, .submitted)
  }

  func testMalformedCanonicalEventsPreserveThePendingJournal() async throws {
    let f = try make()
    try await f.prepareRecovery(events: [(0, true)])
    f.server.recoveryEvents = "0xff"
    await fails { _ = try await f.subject.reconcilePending(account: f.account.address) }
    equal(try await f.pending.all().first?.state, .submitted)
    equal(f.extrinsics.preparedSubmitCount, 0)
  }

  func testUnavailableRuntimeCannotTrustIndexerSuccessAlone() async throws {
    let f = try make()
    try await f.prepareRecovery(events: [(0, true)])
    f.runtime.failure = SubmitFlowFailure.unexpected
    await fails { _ = try await f.subject.reconcilePending(account: f.account.address) }
    equal(try await f.pending.all().first?.state, .submitted)
    XCTAssertFalse(f.server.methods.contains(SoraPassport.RPCMethod.queryStorageAt))
  }

  func testFinalizedRecoveryIsIdempotentWithoutAnotherNodeRead() async throws {
    let f = try make()
    try await f.prepareRecovery(events: [(0, true)])
    let first = try await f.subject.reconcilePending(account: f.account.address)
    let methods = f.server.methods
    equal(try await f.subject.reconcilePending(account: f.account.address), first)
    equal(f.server.methods, methods)
  }

  func testMarketStatusWireRoundTripUsesAnExplicitEmptyVariantPayload() throws {
    for status in [PolkamarktMarketStatus.open, .locked, .resolved, .cancelled] {
      let encoded = try JSONEncoder().encode(status)
      let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [Any])
      equal(json.first as? String, status.rawValue)
      XCTAssertTrue(json.last is NSNull)
      equal(try JSONDecoder().decode(PolkamarktMarketStatus.self, from: encoded), status)
    }
    for value in [Data("\"Unknown\"".utf8), Data("[\"Unknown\",null]".utf8)] {
      XCTAssertThrowsError(try JSONDecoder().decode(PolkamarktMarketStatus.self, from: value))
    }
  }
}

private extension SubmitFlowFixture {
  func prepareRecovery(events: [(UInt32, Bool)]) async throws {
    let hash = try Data([0]).blake2b32().toHex(includePrefix: false)
    let now = Date(timeIntervalSince1970: 1)
    var row = PolkamarktPendingMutation(id: UUID(), account: account.address, action: "buy_yes",
      marketIds: [42], createdAt: now, updatedAt: now, extrinsicHash: nil, state: .preparing,
      finalizedBlock: nil, errorClass: nil)
    row = try await pending.put(row)
    row.extrinsicHash = hash
    row.state = .signedBeforeTransport
    row = try await pending.put(row)
    row.state = .submitted
    _ = try await pending.put(row)
    // Runtime 130's System events, decoded by the production runtime coder.
    // Each tuple deliberately identifies both the extrinsic index and result.
    var bytes = Data([UInt8(events.count << 2)])
    for (index, succeeded) in events {
      bytes.append(0)
      withUnsafeBytes(of: index.littleEndian) { bytes.append(contentsOf: $0) }
      bytes.append(contentsOf: succeeded ? [0, 0] : [0, 1, 0])
      bytes.append(contentsOf: [0x22, 0x90, 0x75, 0x3e, 0x55, 0x17, 0, 0, 0])
    }
    server.recoveryEvents = bytes.toHex(includePrefix: true)
    let owner = account.address, block = server.block
    PIStubIndexerProtocol.install { request in
      if request.operation == "MobileHealth" {
        return .init(body: PIAdvancingIndexer.health(indexed: 400, finalized: 401,
          indexedAt: Int(Date().timeIntervalSince1970) - 1))
      }
      guard request.operation == "MobileHistory" else { return .init(status: 400, body: "{}") }
      let entry: [String: Any] = ["id": "0x" + hash, "address": owner, "dataFrom": owner,
        "dataTo": "peer", "timestamp": 100, "networkFee": "7", "execution": ["success": true],
        "blockHeight": 400, "blockHash": block]
      let page: [String: Any] = ["nodes": [entry], "pageInfo": ["hasNextPage": false,
        "hasPreviousPage": false, "startCursor": "c1", "endCursor": "c1"], "totalCount": 1]
      return .init(body: String(data: try! JSONSerialization.data(withJSONObject:
        ["data": ["historyElements": page]]), encoding: .utf8)!)
    }
  }
}
