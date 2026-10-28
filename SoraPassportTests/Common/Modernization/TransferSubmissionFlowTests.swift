// SPDX-License-Identifier: Apache-2.0
import Foundation
import IrohaCrypto
import RobinHood
import SSFUtils
import SoraFoundation
import SoraKeystore
import SoraUIKit
import UIKit
import XCTest

@testable import SoraPassport

@MainActor final class TransferSubmissionFlowTests: XCTestCase {
  private var previous: AccountItem?, fixtures = [SubmissionFlowFixture]()
  override func setUp() {
    super.setUp()
    previous = SelectedWalletSettings.shared.currentAccount
  }
  override func tearDown() async throws {
    for f in fixtures {
      f.model.viewWillDisappear()
      f.resume()
      f.afterPrepare = nil
    }
    try? await Task.sleep(nanoseconds: 30_000_000)
    fixtures = []
    SelectedWalletSettings.shared.commitInternalValue(previous)
    try await super.tearDown()
  }
  private func make(asset: String = WalletAssetId.xor.rawValue, recipient: String? = nil) throws
    -> SubmissionFlowFixture
  {
    let f = try SubmissionFlowFixture(asset: asset, recipient: recipient)
    fixtures.append(f)
    SelectedWalletSettings.shared.commitInternalValue(f.account)
    f.model.viewDidLoad()
    return f
  }
  private func wait(_ condition: () -> Bool) async {
    for _ in 0..<200 {
      if condition() { return }
      try? await Task.sleep(nanoseconds: 5_000_000)
    }
    XCTAssertTrue(condition())
  }
  private func finish(_ f: SubmissionFlowFixture) async {
    f.model.submit()
    await wait { f.route.hidden > 0 }
  }
  func testAffordableSendPreparesAndSubmitsTheExactReviewedIntent() async throws {
    let f = try make()
    await finish(f)
    XCTAssertEqual(f.prepared.count, 1)
    XCTAssertEqual(f.submitted.count, 1)
    XCTAssertEqual(f.prepared.first?.source, f.account.publicKeyData.toHex())
    XCTAssertEqual(f.prepared.first?.destination, Data(repeating: 4, count: 32).toHex())
    XCTAssertEqual(f.submitted.first?.amount.decimalValue, 2)
    XCTAssertEqual(f.submitted.first?.asset, f.xor)
    XCTAssertEqual(f.submitted.first?.fees.first?.value.decimalValue, 1)
  }
  func testSendReadsLiveBalancesTwiceAroundPreparation() async throws {
    let f = try make()
    await finish(f)
    XCTAssertEqual(f.balanceReads.count, 2)
    XCTAssertEqual(f.balanceReads, [[f.xor], [f.xor]])
  }
  func testNonFeeTransferReadsItsAssetAndXorTogether() async throws {
    let f = try make(asset: WalletAssetId.val.rawValue)
    await finish(f)
    XCTAssertEqual(Set(f.balanceReads.first ?? []), Set([f.xor, f.val]))
    XCTAssertEqual(f.submitted.first?.asset, f.val)
  }
  func testSuccessfulTransportOpensPendingActivityWithExactHash() async throws {
    let f = try make()
    await finish(f)
    let tx = try XCTUnwrap(f.route.transactions.first as? TransferTransaction)
    XCTAssertEqual(tx.base.status, .pending)
    XCTAssertEqual(tx.base.txHash, "0x" + String(repeating: "ab", count: 32))
    XCTAssertEqual(tx.peer, f.recipient)
    XCTAssertEqual(tx.amount.decimalValue, 2)
    XCTAssertEqual(tx.base.fee.decimalValue, Decimal(string: "1000000000000000000"))
  }
  func testSuccessfulTransportBalancesTheLoadingIndicator() async throws {
    let f = try make()
    await finish(f)
    XCTAssertEqual(f.route.shown, 1)
    XCTAssertEqual(f.route.hidden, 1)
  }
  func testPreparedPayloadIsDiscardedAfterSuccessfulTransport() async throws {
    let f = try make()
    await finish(f)
    let p = try XCTUnwrap(f.payload)
    XCTAssertThrowsError(try p.consumeForTransport())
  }
  func testMissingSelectedAccountFailsBeforePreparation() async throws {
    let f = try make()
    SelectedWalletSettings.shared.commitInternalValue(nil)
    await finish(f)
    XCTAssertTrue(f.prepared.isEmpty)
    XCTAssertTrue(f.route.transactions.isEmpty)
    XCTAssertEqual(f.route.hidden, 1)
  }
  func testInvalidRecipientFailsBeforeLiveReads() async throws {
    let f = try make(recipient: "invalid-address")
    await finish(f)
    XCTAssertTrue(f.balanceReads.isEmpty)
    XCTAssertTrue(f.prepared.isEmpty)
  }
  func testLiveInputBalanceShortfallStopsBeforePreparation() async throws {
    let f = try make()
    f.live[f.xor] = 2
    await finish(f)
    XCTAssertTrue(f.prepared.isEmpty)
    XCTAssertTrue(f.route.transactions.isEmpty)
  }
  func testLiveFeeBalanceShortfallStopsBeforePreparation() async throws {
    let f = try make(asset: WalletAssetId.val.rawValue)
    f.live[f.xor] = 0
    await finish(f)
    XCTAssertTrue(f.prepared.isEmpty)
  }
  func testMissingLiveAssetStopsBeforePreparation() async throws {
    let f = try make()
    f.live = [:]
    await finish(f)
    XCTAssertTrue(f.prepared.isEmpty)
  }
  func testDuplicateLiveBalanceRowsAreRejected() async throws {
    let f = try make()
    f.duplicate = true
    await finish(f)
    XCTAssertTrue(f.prepared.isEmpty)
  }
  func testUnavailableLiveBalancesAreRejected() async throws {
    let f = try make()
    f.unavailable = true
    await finish(f)
    XCTAssertTrue(f.prepared.isEmpty)
  }
  func testNilLiveBalanceResultIsRejected() async throws {
    let f = try make()
    f.nilBalances = true
    await finish(f)
    XCTAssertTrue(f.prepared.isEmpty)
  }
  func testLiveBalanceReadFailureLeavesNothingSubmitted() async throws {
    let f = try make()
    f.balanceError = NSError(domain: "fixture", code: 1)
    await finish(f)
    XCTAssertTrue(f.submitted.isEmpty)
    XCTAssertTrue(f.route.transactions.isEmpty)
  }
  func testSignedFeeIncreaseRequiresAnotherReview() async throws {
    let f = try make()
    f.exactFee = 2
    await finish(f)
    XCTAssertEqual(f.prepared.count, 1)
    XCTAssertTrue(f.submitted.isEmpty)
    XCTAssertThrowsError(try XCTUnwrap(f.payload).consumeForTransport())
  }
  func testZeroSignedFeeCannotReachTransport() async throws {
    let f = try make()
    f.exactFee = 0
    await finish(f)
    XCTAssertTrue(f.submitted.isEmpty)
  }
  func testBalanceLossAfterPreparationStopsBeforeTransport() async throws {
    let f = try make()
    f.afterPrepare = { f.live[f.xor] = 0 }
    await finish(f)
    XCTAssertEqual(f.balanceReads.count, 2)
    XCTAssertTrue(f.submitted.isEmpty)
  }
  func testSecondBalanceReadFailureDiscardsThePreparedPayload() async throws {
    let f = try make()
    f.afterPrepare = { f.balanceError = NSError(domain: "fixture", code: 1) }
    await finish(f)
    XCTAssertTrue(f.submitted.isEmpty)
    XCTAssertThrowsError(try XCTUnwrap(f.payload).consumeForTransport())
  }
  func testPreparationFailureStopsTheLoadingIndicator() async throws {
    let f = try make()
    f.prepareError = WalletNetworkOperationFactoryError.invalidFee
    await finish(f)
    XCTAssertEqual(f.route.hidden, 1)
    XCTAssertTrue(f.submitted.isEmpty)
  }
  func testPreparationCancellationDoesNotOpenFailedActivity() async throws {
    let f = try make()
    f.prepareError = CancellationError()
    await finish(f)
    XCTAssertTrue(f.route.transactions.isEmpty)
    XCTAssertTrue(f.submitted.isEmpty)
  }
  func testBeforeTransportFailureDoesNotInventATransaction() async throws {
    let f = try make()
    f.transportError = PreparedExtrinsicTransportError.failedBeforeTransport(
      NSError(domain: "fixture", code: 1))
    await finish(f)
    XCTAssertTrue(f.route.transactions.isEmpty)
  }
  func testAmbiguousTransportOpensOnlyTheExactStagedHash() async throws {
    let f = try make()
    f.transportError = PreparedExtrinsicTransportError.submissionUnknown(
      localHash: "0x" + String(repeating: "ab", count: 32),
      error: NSError(domain: "fixture", code: 1))
    await finish(f)
    XCTAssertEqual(f.route.transactions.first?.base.status, .pending)
    XCTAssertEqual(
      f.route.transactions.first?.base.txHash, "0x" + String(repeating: "ab", count: 32))
  }
  func testUnqualifiedUnknownTransportDoesNotBorrowAnotherHash() async throws {
    let f = try make()
    f.transportError = PreparedExtrinsicTransportError.submissionUnknown(
      NSError(domain: "fixture", code: 1))
    await finish(f)
    XCTAssertEqual(f.route.transactions.first?.base.status, .failed)
    XCTAssertEqual(f.route.transactions.first?.base.txHash, "")
  }
  func testUnexpectedTransportFailureDoesNotOpenActivity() async throws {
    let f = try make()
    f.transportError = NSError(domain: "fixture", code: 1)
    await finish(f)
    XCTAssertTrue(f.route.transactions.isEmpty)
  }
  func testRepeatedTapDuringPreparationStartsOnlyOneSubmission() async throws {
    let f = try make()
    f.hold = true
    f.model.submit()
    await wait { f.pending != nil }
    f.model.submit()
    XCTAssertEqual(f.route.shown, 1)
    XCTAssertEqual(f.prepared.count, 1)
    f.resume()
    await wait { f.route.hidden > 0 }
    XCTAssertEqual(f.submitted.count, 1)
  }
  func testLeavingScreenRevokesQueuedSigning() async throws {
    let f = try make()
    f.hold = true
    f.model.submit()
    await wait { f.pending != nil }
    f.model.viewWillDisappear()
    f.resume()
    await wait { f.route.hidden > 0 }
    XCTAssertTrue(f.submitted.isEmpty)
    XCTAssertTrue(f.route.transactions.isEmpty)
  }
  func testChangingSelectedWalletDuringPreparationStopsTransport() async throws {
    let f = try make()
    f.hold = true
    f.model.submit()
    await wait { f.pending != nil }
    SelectedWalletSettings.shared.commitInternalValue(try SubmissionFlowFixture.account(byte: 5))
    f.resume()
    await wait { f.route.hidden > 0 }
    XCTAssertTrue(f.submitted.isEmpty)
  }
  func testClearingSelectionDuringPreparationStopsTransport() async throws {
    let f = try make()
    f.hold = true
    f.model.submit()
    await wait { f.pending != nil }
    SelectedWalletSettings.shared.commitInternalValue(nil)
    f.resume()
    await wait { f.route.hidden > 0 }
    XCTAssertTrue(f.submitted.isEmpty)
  }
  func testChangingTheAmountDuringPreparationInvalidatesTheReviewedIntent() async throws {
    let f = try make()
    f.hold = true
    f.model.submit()
    await wait { f.pending != nil }
    f.model.firstAssetAmount = 3
    f.resume()
    await wait { f.route.hidden > 0 }
    XCTAssertTrue(f.submitted.isEmpty)
  }
  func testRetryAfterTransientReadFailureCanComplete() async throws {
    let f = try make()
    f.balanceError = NSError(domain: "fixture", code: 1)
    await finish(f)
    f.balanceError = nil
    f.model.submit()
    await wait { f.route.hidden == 2 }
    XCTAssertEqual(f.submitted.count, 1)
  }
  func testExactAffordableBalanceAllowsTheSend() async throws {
    let f = try make()
    f.live[f.xor] = 3
    await finish(f)
    XCTAssertEqual(f.submitted.count, 1)
  }
  func testFeeBalanceMarkedUnavailableNeverEnablesTheSend() async throws {
    let f = try make(asset: WalletAssetId.val.rawValue)
    f.balances.unavailable.insert(f.xor)
    f.model.processBalance(data: [])
    f.model.submit()
    XCTAssertEqual(f.route.shown, 0)
  }
  func testProviderReturningAnotherAssetCannotEnableTheSend() async throws {
    let f = try make()
    f.balances.wrongIdentifier = true
    f.model.processBalance(data: [])
    f.model.submit()
    XCTAssertEqual(f.route.shown, 0)
  }
  func testAuthorizationIsRevocableAndCannotBeReenabled() {
    let a = Sora2TransferSigningAuthorization()
    XCTAssertNoThrow(try a.requireAuthorized())
    a.revoke()
    XCTAssertThrowsError(try a.requireAuthorized())
    a.revoke()
    XCTAssertThrowsError(try a.requireAuthorized())
  }
}
@MainActor private final class SubmissionFlowFixture {
  let xor = WalletAssetId.xor.rawValue, val = WalletAssetId.val.rawValue, account: AccountItem,
    recipient: String, asset: String
  let assets = SubmissionFlowAssets(),
    balances = SubmissionFlowBalances(values: [
      WalletAssetId.xor.rawValue: 10, WalletAssetId.val.rawValue: 20,
    ]), fiat = SubmissionFlowFiat(), route = SubmissionFlowRoute(), view = SubmissionFlowView(),
    factory = WalletNetworkOperationFactoryProtocolMock()
  var live: [String: Decimal] = [WalletAssetId.xor.rawValue: 10, WalletAssetId.val.rawValue: 20],
    balanceReads = [[String]](), prepared = [TransferInfo](), submitted = [TransferInfo](),
    exactFee: Decimal = 1
  var duplicate = false, unavailable = false, nilBalances = false, hold = false
  var balanceError: Error?, prepareError: Error?, transportError: Error?,
    payload: PreparedExtrinsicSubmission?, pending: CheckedContinuation<Void, Never>?,
    afterPrepare: (() -> Void)?
  lazy var model: ConfirmSendingViewModel = {
    let m = ConfirmSendingViewModel(
      wireframe: route, fiatService: fiat, assetManager: assets,
      detailsFactory: DetailViewModelFactory(assetManager: assets), assetId: asset,
      recipientAddress: recipient, firstAssetAmount: 2, transactionType: .outgoing, fee: 1,
      walletService: WalletService(operationFactory: factory), assetsProvider: balances)
    m.view = view
    return m
  }()
  init(asset: String, recipient: String?) throws {
    self.asset = asset
    account = try Self.account(byte: 3)
    self.recipient =
      try recipient
      ?? SS58AddressFactory().addressFromAccountId(
        data: Data(repeating: 4, count: 32), type: SoraPassport.Chain.sora.addressType())
    factory.balanceClosure = { [weak self] ids in
      guard let self else { return .init(targetOperation: ClosureOperation { nil }) }
      self.balanceReads.append(ids)
      let error = self.balanceError
      let missing = self.nilBalances
      var rows = ids.compactMap { id in
        self.live[id].map { BalanceData(identifier: id, balance: .init(value: $0)) }
      }
      if self.duplicate, let first = rows.first { rows.append(first) }
      if self.unavailable { rows = ids.map { BalanceData.unavailable(identifier: $0) } }
      let result = rows
      return .init(
        targetOperation: ClosureOperation {
          if let error { throw error }
          return missing ? nil : result
        })
    }
    factory.prepareTransferClosure = { [weak self] info, authorize in
      guard let self else { throw CancellationError() }
      try authorize()
      self.prepared.append(info)
      if let error = self.prepareError { throw error }
      let bytes = Data([1, 2, 3])
      let payload = PreparedExtrinsicSubmission(
        data: bytes, hash: try bytes.blake2b32().toHex(includePrefix: true))
      self.payload = payload
      let prepared = PreparedSora2TransferSubmission(
        fee: self.exactFee, rawFee: "1000000000000000000", preparedExtrinsic: payload)
      if self.hold { await withCheckedContinuation { self.pending = $0 } }
      self.afterPrepare?()
      return prepared
    }
    factory.submitPreparedTransferClosure = { [weak self] _, info, authorize in
      guard let self else { throw CancellationError() }
      try authorize()
      self.submitted.append(info)
      if let error = self.transportError { throw error }
      return Data(repeating: 0xab, count: 32)
    }
  }
  func resume() {
    let c = pending
    pending = nil
    c?.resume()
  }
  static func account(byte: UInt8) throws -> AccountItem {
    let key = Data(repeating: byte, count: 32)
    return AccountItem(
      address: try SS58AddressFactory().addressFromAccountId(
        data: key, type: SoraPassport.Chain.sora.addressType()), cryptoType: .sr25519,
      networkType: SoraPassport.Chain.sora.addressType(), username: "Public fixture",
      publicKeyData: key, settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []),
      order: 0, isSelected: true)
  }
}
private final class SubmissionFlowRoute: ConfirmWireframeProtocol {
  var shown = 0, hidden = 0, transactions = [Transaction]()
  func showActivityIndicator() { shown += 1 }
  func hideActivityIndicator() { hidden += 1 }
  func showActivityDetails(
    on controller: UIViewController?, model: Transaction, assetManager: AssetManagerProtocol,
    completion: (() -> Void)?
  ) { transactions.append(model) }
}
@MainActor private final class SubmissionFlowView: UIViewController, ConfirmViewProtocol {
  func dismiss(competion: (() -> Void)?) { competion?() }
}
private actor SubmissionFlowFiat: FiatServiceProtocol {
  func getFiat() async -> [PIExactFiatData] { [] }
}
private final class SubmissionFlowBalances: AssetProviderProtocol {
  var values: [String: Decimal]
  var additions = 0
  var unavailable = Set<String>(), wrongIdentifier = false
  init(values: [String: Decimal]) { self.values = values }
  func getBalances(with assetIds: [String]) -> [BalanceData] {
    assetIds.compactMap { id in
      if unavailable.contains(id) { return BalanceData.unavailable(identifier: id) }
      return values[id].map {
        BalanceData(identifier: wrongIdentifier ? "other" : id, balance: AmountDecimal(value: $0))
      }
    }
  }
  func add(observer: AssetProviderObserverProtocol) { additions += 1 }
  func remove(observer: AssetProviderObserverProtocol) { additions -= 1 }
}
private final class SubmissionFlowAssets: AssetManagerProtocol {
  static var networkAssets: [AssetInfo] = []
  private var assets = [
    AssetInfo(
      id: WalletAssetId.xor.rawValue, symbol: "XOR", chainId: "", precision: 18, icon: nil,
      displayName: "SORA", visible: true),
    AssetInfo(
      id: WalletAssetId.val.rawValue, symbol: "VAL", chainId: "", precision: 18, icon: nil,
      displayName: "Validator", visible: true),
  ]
  func assetInfo(for identifier: String) -> AssetInfo? { assets.first { $0.assetId == identifier } }
  func getAssetList() -> [AssetInfo]? { assets }
  func updateAssetList(_ list: [AssetInfo]) { assets = list }
  func saveAssetList(_ list: [AssetInfo]) { assets = list }
  func sortedAssets(_ list: [WalletAsset], onlyVisible: Bool) -> [WalletAsset] { list }
  func visibleCount() -> UInt { UInt(assets.count) }
  func setup(for accountSettings: SelectedWalletSettings) {}
}
