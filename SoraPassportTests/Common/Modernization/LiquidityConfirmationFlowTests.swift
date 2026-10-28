// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0
import IrohaCrypto
import RobinHood
import SSFUtils
import SoraFoundation
import SoraUIKit
import UIKit
import XCTest

@testable import SoraPassport

@MainActor
final class LiquidityConfirmationFlowTests: XCTestCase {
  private var previous: AccountItem?
  private var language = "en"
  private var owner: AccountItem!
  override func setUpWithError() throws {
    previous = SelectedWalletSettings.shared.currentAccount
    language = LocalizationManager.shared.selectedLocalization
    LocalizationManager.shared.selectedLocalization = "en"
    let key = Data(repeating: 3, count: 32)
    owner = AccountItem(
      address: try SS58AddressFactory().address(
        fromAccountId: key, type: SNAddressType(chain: .sora)), cryptoType: .sr25519,
      networkType: 69, username: "Liquidity fixture", publicKeyData: key,
      settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: 0,
      isSelected: true)
    SelectedWalletSettings.shared.commitInternalValue(owner)
  }
  override func tearDown() {
    SelectedWalletSettings.shared.commitInternalValue(previous)
    LocalizationManager.shared.selectedLocalization = language
    super.tearDown()
  }
  private func make(
    _ removing: Bool = false, type: TransactionType = .liquidityAdd,
    base: String = WalletAssetId.xor.rawValue, fee: Decimal = 1
  ) -> LiquidityFlowFixture {
    LiquidityFlowFixture(
      removing: removing, type: type, base: base, fee: fee, account: owner.address)
  }
  private func wait(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line)
    async
  {
    for _ in 0..<200 {
      if condition() { return }
      try? await Task.sleep(nanoseconds: 10_000_000)
    }
    XCTFail("Liquidity flow did not reach the expected state", file: file, line: line)
  }
  private func finish(_ f: LiquidityFlowFixture) async {
    f.submit()
    await wait { f.route.hidden > 0 || !f.route.errors.isEmpty }
  }
  private func rejects(
    _ f: LiquidityFlowFixture, file: StaticString = #filePath, line: UInt = #line
  ) async {
    await finish(f)
    XCTAssertTrue(f.submitted.isEmpty, file: file, line: line)
    XCTAssertFalse(f.route.errors.isEmpty, file: file, line: line)
  }
  func testExistingPoolSupplyUsesExactAmountsAndFreshFee() async throws {
    let f = make()
    f.freshFee = 0.5
    await finish(f)
    let info = try XCTUnwrap(f.submitted.first)
    XCTAssertEqual(info.asset, WalletAssetId.xor.rawValue)
    XCTAssertEqual(info.destination, WalletAssetId.val.rawValue)
    XCTAssertEqual(info.amount.decimalValue, 2)
    XCTAssertEqual(info.context?[TransactionContextKeys.secondAssetAmount], "4")
    XCTAssertEqual(info.fees.first?.value.decimalValue, 0.5)
    XCTAssertEqual(f.route.details.count, 1)
    XCTAssertEqual(f.prepared.count, 1)
    XCTAssertEqual(f.pools.pairQueries, [[WalletAssetId.xor.rawValue, WalletAssetId.val.rawValue]])
  }
  func testNewPoolSupplyUsesRegisterInitializeAndDepositType() async throws {
    let f = make(type: .liquidityAddNewPool)
    f.pools.state = .init(isPresented: false, isEnabled: false)
    await finish(f)
    XCTAssertEqual(
      f.submitted.first?.context?[TransactionContextKeys.transactionType],
      TransactionType.liquidityAddNewPool.rawValue)
    XCTAssertEqual(f.pools.poolQueries, 0)
  }
  func testEnabledEmptyPoolSupplyUsesInitializeAndDepositType() async throws {
    let f = make(type: .liquidityAddToExistingPoolFirstTime)
    f.pools.state = .init(isPresented: false, isEnabled: true)
    await finish(f)
    XCTAssertEqual(
      f.submitted.first?.context?[TransactionContextKeys.transactionType],
      TransactionType.liquidityAddToExistingPoolFirstTime.rawValue)
    XCTAssertEqual(f.pools.poolQueries, 0)
  }
  func testNewPoolReviewRejectsAnAlreadyCreatedPool() async {
    let f = make(type: .liquidityAddNewPool)
    await rejects(f)
    XCTAssertTrue(f.prepared.isEmpty)
  }
  func testEmptyPoolReviewRejectsDisabledPair() async {
    let f = make(type: .liquidityAddToExistingPoolFirstTime)
    f.pools.state = .init(isPresented: false, isEnabled: false)
    await rejects(f)
  }
  func testSupplyRejectsDisabledLivePair() async {
    let f = make()
    f.pools.state = .init(isPresented: true, isEnabled: false)
    await rejects(f)
  }
  func testSupplyRejectsMissingLivePool() async {
    let f = make()
    f.pools.pool = nil
    await rejects(f)
  }
  func testSupplyRejectsMismatchedLiveAssets() async {
    let f = make()
    f.pools.pool = LiquidityFlowFixture.pool(base: WalletAssetId.pswap.rawValue)
    await rejects(f)
  }
  func testSupplyRejectsZeroLiveReserve() async {
    let f = make()
    f.pools.pool?.baseAssetReserves = 0
    await rejects(f)
  }
  func testSupplyRejectsUnknownLiveIssuance() async {
    let f = make()
    f.pools.pool?.totalIssuances = nil
    await rejects(f)
  }
  func testSupplyRejectsAChangedRatioWhenTargetMinimumWouldBeLost() async {
    let f = make()
    f.pools.pool?.targetAssetReserves = 150
    await rejects(f)
  }
  func testSupplyRejectsAChangedRatioWhenBaseMinimumWouldBeLost() async {
    let f = make()
    f.pools.pool?.targetAssetReserves = 250
    await rejects(f)
  }
  func testSupplyAcceptsRatioMovementWithinReviewedSlippage() async {
    let f = make()
    f.pools.pool?.targetAssetReserves = 200.2
    await finish(f)
    XCTAssertEqual(f.submitted.count, 1)
  }
  func testSupplyRequiresXORAmountAndFeeTogether() async {
    let f = make()
    f.values[WalletAssetId.xor.rawValue] = 2
    await rejects(f)
  }
  func testSupplyRequiresTheFullTargetAmount() async {
    let f = make()
    f.values[WalletAssetId.val.rawValue] = 3
    await rejects(f)
  }
  func testXSTUSDSupplyUsesItsOwnPairAndSeparateXORFeeBalance() async {
    let f = make(base: WalletAssetId.xstusd.rawValue)
    await finish(f)
    XCTAssertEqual(f.submitted.count, 1)
    XCTAssertEqual(f.pools.pairQueries.first?.first, WalletAssetId.xstusd.rawValue)
    XCTAssertEqual(f.submitted.first?.context?[TransactionContextKeys.dex], "1")
  }
  func testSupplyRejectsMissingXORFeeBalance() async {
    let f = make(base: WalletAssetId.xstusd.rawValue)
    f.values[WalletAssetId.xor.rawValue] = nil
    await rejects(f)
  }
  func testSupplyRejectsDuplicateBalanceRows() async {
    let f = make()
    f.duplicateBalances = true
    await rejects(f)
  }
  func testSupplyRejectsNegativeBalances() async {
    let f = make()
    f.values[WalletAssetId.val.rawValue] = -1
    await rejects(f)
  }
  func testSupplyRejectsMissingBalanceResult() async {
    let f = make()
    f.nilBalances = true
    await rejects(f)
  }
  func testSupplyBalanceFailureDoesNotSign() async {
    let f = make()
    f.balanceFailure = true
    await rejects(f)
    XCTAssertTrue(f.prepared.isEmpty)
  }
  func testPairQueryFailureDoesNotRequestSigning() async {
    let f = make()
    f.pools.error = CancellationError()
    await finish(f)
    XCTAssertTrue(f.prepared.isEmpty)
    XCTAssertTrue(f.route.errors.isEmpty)
  }
  func testSupplyFeeIncreaseRequiresAnotherReviewAndPreventsRetry() async {
    let f = make()
    f.freshFee = 2
    await rejects(f)
    XCTAssertEqual(f.feeChanges, 1)
    f.submit()
    XCTAssertEqual(f.prepared.count, 1)
  }
  func testSupplyZeroFreshFeeNeverReachesTransport() async {
    let f = make()
    f.freshFee = 0
    await rejects(f)
  }
  func testSupplyDuplicateConfirmCreatesOnlyOnePreflight() async {
    let f = make()
    f.pausePrepare = true
    f.submit()
    f.submit()
    await wait { f.prepareResume != nil }
    XCTAssertEqual(f.prepared.count, 1)
    f.resumePrepare()
    await wait { f.route.hidden == 1 }
    XCTAssertEqual(f.submitted.count, 1)
  }
  func testSupplyDisappearanceRevokesSigningBeforeTransport() async {
    let f = make()
    f.pausePrepare = true
    f.submit()
    await wait { f.prepareResume != nil }
    f.disappear()
    f.resumePrepare()
    await wait { f.route.hidden > 0 }
    XCTAssertTrue(f.submitted.isEmpty)
    XCTAssertTrue(f.route.errors.isEmpty)
    XCTAssertThrowsError(try f.preparedPayload?.consumeForTransport())
  }
  func testSupplyDefiniteTransportFailureCanBeRetried() async {
    let f = make()
    f.transportError = .failedBeforeTransport(CancellationError())
    await rejects(f)
    f.transportError = nil
    f.submit()
    await wait { f.route.details.count == 1 }
    XCTAssertEqual(f.submitted.count, 1)
    XCTAssertEqual(f.prepared.count, 2)
  }
  func testSupplyAmbiguousTransportPreventsAutomaticRetry() async {
    let f = make()
    f.transportError = .submissionUnknown(CancellationError())
    await rejects(f)
    f.transportError = nil
    f.submit()
    XCTAssertEqual(f.prepared.count, 1)
  }
  func testSupplyPreparedBytesAreDiscardedAfterSuccessfulSubmission() async {
    let f = make()
    await finish(f)
    XCTAssertThrowsError(try f.preparedPayload?.consumeForTransport())
  }
  func testSupplyReceiptKeepsAmountsPairedWithTheirAssetIds() async throws {
    let f = make()
    await finish(f)
    let tx = try XCTUnwrap(f.route.details.first as? Liquidity)
    XCTAssertEqual(tx.firstTokenId, WalletAssetId.xor.rawValue)
    XCTAssertEqual(tx.secondTokenId, WalletAssetId.val.rawValue)
    XCTAssertEqual(tx.firstAmount.decimalValue, 2)
    XCTAssertEqual(tx.secondAmount.decimalValue, 4)
    XCTAssertEqual(tx.base.fee.decimalValue, Decimal(string: "1000000000000000000"))
    XCTAssertEqual(tx.type, .add)
  }
  func testSupplyContextKeepsPoolShareSeparateFromAPY() async {
    let f = make()
    await finish(f)
    XCTAssertEqual(f.submitted.first?.context?[TransactionContextKeys.shareOfPool], "2%")
    XCTAssertEqual(f.submitted.first?.context?[TransactionContextKeys.sbApy], "12% APY")
  }
  func testSupplyWalletChangeBeforeConfirmationInvalidatesReview() async {
    let f = make()
    SelectedWalletSettings.shared.commitInternalValue(nil)
    await rejects(f)
    XCTAssertTrue(f.prepared.isEmpty)
  }
  func testSupplyCannotChangeReviewedAmountsWhileSigningIsSuspended() async {
    let f = make()
    f.pausePrepare = true
    f.submit()
    await wait { f.prepareResume != nil }
    f.supply?.firstAssetAmount = 8
    f.resumePrepare()
    await wait { f.route.hidden > 0 }
    XCTAssertTrue(f.submitted.isEmpty)
  }
  func testSupplyReceiptRetainsSubmittedAmountsWhileTransportIsSuspended() async throws {
    let f = make()
    f.pauseTransport = true
    f.submit()
    await wait { f.transportResume != nil }
    f.supply?.firstAssetAmount = 99
    f.resumeTransport()
    await wait { !f.route.details.isEmpty }
    XCTAssertEqual((f.route.details.first as? Liquidity)?.firstAmount.decimalValue, 2)
  }
  func testRemovalUsesReviewedPoolShareAndFreshFee() async throws {
    let f = make(true)
    f.freshFee = 0.5
    await finish(f)
    let info = try XCTUnwrap(f.submitted.first)
    XCTAssertEqual(
      info.context?[TransactionContextKeys.transactionType],
      TransactionType.liquidityRemoval.rawValue)
    XCTAssertEqual(info.context?[TransactionContextKeys.firstReserves], "100")
    XCTAssertEqual(info.context?[TransactionContextKeys.totalIssuances], "10")
    XCTAssertEqual(info.fees.first?.value.decimalValue, 0.5)
  }
  func testRemovalRejectsDisabledLivePool() async {
    let f = make(true)
    f.pools.state = .init(isPresented: true, isEnabled: false)
    await rejects(f)
  }
  func testRemovalRejectsMissingLivePool() async {
    let f = make(true)
    f.pools.pool = nil
    await rejects(f)
  }
  func testRemovalRejectsMismatchedLivePool() async {
    let f = make(true)
    f.pools.pool = LiquidityFlowFixture.pool(base: WalletAssetId.kxor)
    await rejects(f)
  }
  func testRemovalRejectsInsufficientPoolTokens() async {
    let f = make(true)
    f.pools.pool?.accountPoolBalance = 0.1
    await rejects(f)
  }
  func testRemovalRejectsUnknownStakedPoolTokens() async {
    let f = make(true)
    f.pools.pool?.farms = [f.farm(nil)]
    await rejects(f)
  }
  func testRemovalRejectsNegativeStakedPoolTokens() async {
    let f = make(true)
    f.pools.pool?.farms = [f.farm(-1)]
    await rejects(f)
  }
  func testRemovalSubtractsMaximumOverlappingFarmStake() async {
    let f = make(true)
    f.pools.pool?.accountPoolBalance = 2
    f.pools.pool?.farms = [f.farm(1), f.farm(1.5)]
    await finish(f)
    XCTAssertEqual(f.submitted.count, 1)
  }
  func testRemovalRejectsAWithdrawalExceedingUnstakedTokens() async {
    let f = make(true)
    f.pools.pool?.accountPoolBalance = 2
    f.pools.pool?.farms = [f.farm(1.9)]
    await rejects(f)
  }
  func testRemovalRejectsLiveOutputsBelowSlippageMinimum() async {
    let f = make(true)
    f.pools.pool?.targetAssetReserves = 150
    await rejects(f)
  }
  func testRemovalRejectsMissingXORBalance() async {
    let f = make(true)
    f.values[WalletAssetId.xor.rawValue] = nil
    await rejects(f)
    XCTAssertTrue(f.prepared.isEmpty)
  }
  func testRemovalRejectsDuplicateXORBalance() async {
    let f = make(true)
    f.duplicateBalances = true
    await rejects(f)
  }
  func testRemovalRejectsInsufficientXORFee() async {
    let f = make(true)
    f.values[WalletAssetId.xor.rawValue] = 0.5
    await rejects(f)
  }
  func testRemovalFeeIncreaseInvalidatesReview() async {
    let f = make(true)
    f.freshFee = 2
    await rejects(f)
    XCTAssertEqual(f.feeChanges, 1)
    f.submit()
    XCTAssertEqual(f.prepared.count, 1)
  }
  func testRemovalDisappearanceRevokesTransport() async {
    let f = make(true)
    f.pausePrepare = true
    f.submit()
    await wait { f.prepareResume != nil }
    f.disappear()
    f.resumePrepare()
    await wait { f.route.hidden > 0 }
    XCTAssertTrue(f.submitted.isEmpty)
    XCTAssertTrue(f.route.errors.isEmpty)
  }
  func testRemovalAmbiguousTransportCannotRetryOldReview() async {
    let f = make(true)
    f.transportError = .submissionUnknown(CancellationError())
    await rejects(f)
    f.transportError = nil
    f.submit()
    XCTAssertEqual(f.prepared.count, 1)
  }
  func testRemovalReceiptKeepsAmountsPairedWithAssetIds() async throws {
    let f = make(true)
    await finish(f)
    let tx = try XCTUnwrap(f.route.details.first as? Liquidity)
    XCTAssertEqual(tx.firstTokenId, WalletAssetId.xor.rawValue)
    XCTAssertEqual(tx.secondTokenId, WalletAssetId.val.rawValue)
    XCTAssertEqual(tx.firstAmount.decimalValue, 2)
    XCTAssertEqual(tx.secondAmount.decimalValue, 4)
    XCTAssertEqual(tx.type, .withdraw)
  }
  func testRemovalContextKeepsPoolShareSeparateFromAPY() async {
    let f = make(true)
    await finish(f)
    XCTAssertEqual(f.submitted.first?.context?[TransactionContextKeys.shareOfPool], "2%")
    XCTAssertEqual(f.submitted.first?.context?[TransactionContextKeys.sbApy], "12% APY")
  }
  func testRemovalWalletChangeBeforeConfirmationInvalidatesReview() async {
    let f = make(true)
    SelectedWalletSettings.shared.commitInternalValue(nil)
    await rejects(f)
    XCTAssertTrue(f.prepared.isEmpty)
  }
  func testRemovalCannotChangeReviewedAmountsWhileSigningIsSuspended() async {
    let f = make(true)
    f.pausePrepare = true
    f.submit()
    await wait { f.prepareResume != nil }
    f.removal?.firstAssetAmount = 8
    f.resumePrepare()
    await wait { f.route.hidden > 0 }
    XCTAssertTrue(f.submitted.isEmpty)
  }
  func testRemovalReceiptRetainsSubmittedAmountsWhileTransportIsSuspended() async {
    let f = make(true)
    f.pauseTransport = true
    f.submit()
    await wait { f.transportResume != nil }
    f.removal?.firstAssetAmount = 99
    f.resumeTransport()
    await wait { !f.route.details.isEmpty }
    XCTAssertEqual((f.route.details.first as? Liquidity)?.firstAmount.decimalValue, 2)
  }
  func testSupplyWalletLossDuringSigningPreventsTransport() async {
    let f = make()
    f.pausePrepare = true
    f.submit()
    await wait { f.prepareResume != nil }
    SelectedWalletSettings.shared.commitInternalValue(nil)
    f.resumePrepare()
    await wait { f.route.hidden > 0 }
    XCTAssertTrue(f.submitted.isEmpty)
  }
  func testRemovalWalletLossDuringSigningPreventsTransport() async {
    let f = make(true)
    f.pausePrepare = true
    f.submit()
    await wait { f.prepareResume != nil }
    SelectedWalletSettings.shared.commitInternalValue(nil)
    f.resumePrepare()
    await wait { f.route.hidden > 0 }
    XCTAssertTrue(f.submitted.isEmpty)
  }
  func testSupplyAcceptedTransactionKeepsTheOriginalAccountOwner() async {
    let f = make()
    let observer = LiquidityFlowEvents()
    EventCenter.shared.add(observer: observer, dispatchIn: .main)
    defer { EventCenter.shared.remove(observer: observer) }
    f.pauseTransport = true
    f.submit()
    await wait { f.transportResume != nil }
    SelectedWalletSettings.shared.commitInternalValue(nil)
    f.resumeTransport()
    await wait { !observer.events.isEmpty }
    XCTAssertEqual(observer.events.first?.accountAddress, owner.address)
  }
  func testRemovalAcceptedTransactionKeepsTheOriginalAccountOwner() async {
    let f = make(true)
    let observer = LiquidityFlowEvents()
    EventCenter.shared.add(observer: observer, dispatchIn: .main)
    defer { EventCenter.shared.remove(observer: observer) }
    f.pauseTransport = true
    f.submit()
    await wait { f.transportResume != nil }
    SelectedWalletSettings.shared.commitInternalValue(nil)
    f.resumeTransport()
    await wait { !observer.events.isEmpty }
    XCTAssertEqual(observer.events.first?.accountAddress, owner.address)
  }
  func testSupplyAcceptedTransactionIsPublishedAfterScreenLeaves() async {
    let f = make()
    let observer = LiquidityFlowEvents()
    EventCenter.shared.add(observer: observer, dispatchIn: .main)
    defer { EventCenter.shared.remove(observer: observer) }
    f.pauseTransport = true
    f.submit()
    await wait { f.transportResume != nil }
    f.navigation.setViewControllers([UIViewController()], animated: false)
    f.disappear()
    f.resumeTransport()
    await wait { f.route.hidden > 0 }
    await wait { !observer.events.isEmpty }
    XCTAssertTrue(f.route.details.isEmpty)
  }
  func testRemovalAcceptedTransactionIsPublishedAfterScreenLeaves() async {
    let f = make(true)
    let observer = LiquidityFlowEvents()
    EventCenter.shared.add(observer: observer, dispatchIn: .main)
    defer { EventCenter.shared.remove(observer: observer) }
    f.pauseTransport = true
    f.submit()
    await wait { f.transportResume != nil }
    f.navigation.setViewControllers([UIViewController()], animated: false)
    f.disappear()
    f.resumeTransport()
    await wait { f.route.hidden > 0 }
    await wait { !observer.events.isEmpty }
    XCTAssertTrue(f.route.details.isEmpty)
  }

}

@MainActor
private final class LiquidityFlowFixture {
  let route = LiquidityFlowRoute()
  let pools = LiquidityFlowPools()
  let assets = LiquidityFlowAssets()
  let factory = WalletNetworkOperationFactoryProtocolMock()
  let view = LiquidityFlowView()
  let navigation: UINavigationController
  var supply: ConfirmSupplyLiquidityViewModel?
  var removal: ConfirmRemoveLiquidityViewModel?
  var values = [
    WalletAssetId.xor.rawValue: Decimal(100), WalletAssetId.val.rawValue: 100,
    WalletAssetId.kxor: 100,
    WalletAssetId.xstusd.rawValue: 100,
  ]
  var duplicateBalances = false, nilBalances = false, balanceFailure = false
  var freshFee: Decimal = 1
  var prepared: [TransferInfo] = [], submitted: [TransferInfo] = []
  var preparedPayload: PreparedExtrinsicSubmission?
  var feeChanges = 0
  var pausePrepare = false, pauseTransport = false
  var prepareResume: CheckedContinuation<Void, Never>?,
    transportResume: CheckedContinuation<Void, Never>?
  var transportError: PreparedExtrinsicTransportError?
  init(removing: Bool, type: TransactionType, base: String, fee: Decimal, account: String) {
    navigation = UINavigationController(rootViewController: view)
    pools.pool = Self.pool(base: base)
    let details = [
      (R.string.localizable.poolShareTitle1(preferredLanguages: .currentLocale), "2%"),
      (SoraPassport.Constants.apyTitle, "12% APY"),
    ].map {
      DetailViewModel(
        title: $0.0,
        assetAmountText: SoramitsuTextItem(
          text: $0.1, fontData: FontType.textS, textColor: .fgPrimary, alignment: .right))
    }
    let wallet = WalletService(operationFactory: factory)
    if removing {
      removal = ConfirmRemoveLiquidityViewModel(
        wireframe: route, poolInfo: pools.pool!, poolsService: pools, assetManager: assets,
        firstAssetAmount: 2, secondAssetAmount: 4, slippageTolerance: .defaultValue,
        details: details, operationFactory: factory,
        feeChangeHandler: { [weak self] in self?.feeChanges += 1 }, walletService: wallet, fee: fee)
      removal?.view = view
      removal?.viewDidLoad()
    } else {
      supply = ConfirmSupplyLiquidityViewModel(
        wireframe: route, baseAssetId: base, targetAssetId: WalletAssetId.val.rawValue,
        poolsService: pools, assetManager: assets, firstAssetAmount: 2, secondAssetAmount: 4,
        slippageTolerance: .defaultValue, details: details, transactionType: type, fee: fee,
        operationFactory: factory, feeChangeHandler: { [weak self] in self?.feeChanges += 1 },
        walletService: wallet)
      supply?.view = view
      supply?.viewDidLoad()
    }
    factory.balanceClosure = { [weak self] ids in
      guard let self else { return .init(targetOperation: ClosureOperation { nil }) }
      let values = self.values
      let failure = self.balanceFailure
      let missing = self.nilBalances
      let duplicate = self.duplicateBalances
      return .init(
        targetOperation: ClosureOperation {
          if failure { throw NSError(domain: "Balance fixture", code: 1) }
          if missing { return nil }
          var rows = ids.compactMap { id in
            values[id].map { BalanceData(identifier: id, balance: AmountDecimal(value: $0)) }
          }
          if duplicate, let xor = rows.first(where: { $0.identifier == WalletAssetId.xor.rawValue })
          {
            rows.append(xor)
          }
          return rows
        })
    }
    factory.prepareLiquidityClosure = { [weak self] info, authorize in
      guard let self else { throw CancellationError() }
      try authorize()
      self.prepared.append(info)
      let bytes = Data([1, 2, 3])
      let payload = PreparedExtrinsicSubmission(
        data: bytes, hash: try bytes.blake2b32().toHex(includePrefix: true))
      self.preparedPayload = payload
      let submission = PreparedLiquiditySubmission(
        fee: self.freshFee, rawFee: "1000000000000000000", preparedExtrinsic: payload)
      if self.pausePrepare { await withCheckedContinuation { self.prepareResume = $0 } }
      return submission
    }
    factory.submitPreparedLiquidityClosure = { [weak self] _, info, authorize in
      guard let self else { throw CancellationError() }
      try authorize()
      if let error = self.transportError { throw error }
      self.submitted.append(info)
      if self.pauseTransport { await withCheckedContinuation { self.transportResume = $0 } }
      return Data([0xab, 0xcd])
    }
  }
  func submit() {
    supply?.submit()
    removal?.submit()
  }
  func disappear() {
    supply?.viewWillDisappear()
    removal?.viewWillDisappear()
  }
  func resumePrepare() {
    let c = prepareResume
    prepareResume = nil
    c?.resume()
  }
  func resumeTransport() {
    let c = transportResume
    transportResume = nil
    c?.resume()
  }
  static func pool(base: String = WalletAssetId.xor.rawValue) -> PoolInfo {
    PoolInfo(
      baseAssetId: base, targetAssetId: WalletAssetId.val.rawValue, poolId: "pool",
      accountId: "fixture", totalIssuances: 10, baseAssetReserves: 100, targetAssetReserves: 200,
      accountPoolBalance: 5)
  }
  func farm(_ staked: Decimal?) -> UserFarm {
    UserFarm(
      id: "farm", baseAssetId: WalletAssetId.xor.rawValue, poolAssetId: WalletAssetId.val.rawValue,
      rewardAssetId: WalletAssetId.pswap.rawValue, isFarm: true, pooledTokens: staked)
  }
}
private final class LiquidityFlowRoute: ConfirmWireframeProtocol {
  var shown = 0, hidden = 0
  var errors: [String] = []
  var details: [Transaction] = []
  var closeActions: [() -> Void] = []
  func showActivityIndicator() { shown += 1 }
  func hideActivityIndicator() { hidden += 1 }
  func showActivityDetails(
    on controller: UIViewController?, model: Transaction, assetManager: AssetManagerProtocol,
    completion: (() -> Void)?
  ) { details.append(model) }
  func present(
    message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?
  ) { errors.append(message ?? "") }
  func present(
    message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?,
    completion: @escaping () -> Void
  ) {
    errors.append(message ?? "")
    closeActions.append(completion)
  }
}
private final class LiquidityFlowView: UIViewController, ConfirmViewProtocol {
  var controller: UIViewController { self }
  func dismiss(competion: (() -> Void)?) { competion?() }
}
private final class LiquidityFlowPools: PoolsServiceInputProtocol {
  var pool: PoolInfo?
  var state = PoolNetworkState(isPresented: true, isEnabled: true)
  var pairQueries: [[String]] = []
  var poolQueries = 0
  var error: Error?
  func loadPairState(baseAssetId: String, targetAssetId: String) async throws -> PoolNetworkState {
    pairQueries.append([baseAssetId, targetAssetId])
    if let error { throw error }
    return state
  }
  func loadPool(by baseAssetId: String, targetAssetId: String) async -> PoolInfo? {
    poolQueries += 1
    return pool
  }
  func getPool(by baseAssetId: String, targetAssetId: String) async -> PoolInfo? { pool }
  func getPool(by id: String) -> PoolInfo? { pool }
  func getAccountPools() -> [PoolInfo] { pool.map { [$0] } ?? [] }
  func loadAccountPools() {}
  func updatePools(_ pools: [PoolInfo]) {}
  func loadPools(currentAsset: AssetInfo) -> [PoolInfo] { getAccountPools() }
  func loadTargetPools(for baseAssetId: String) -> [PoolInfo] { getAccountPools() }
  func appendDelegate(delegate: PoolsServiceOutput) {}
}
private final class LiquidityFlowAssets: AssetManagerProtocol {
  static var networkAssets: [AssetInfo] = []
  let assets = [
    (WalletAssetId.xor.rawValue, "XOR"), (WalletAssetId.val.rawValue, "VAL"),
    (WalletAssetId.kxor, "KXOR"),
    (WalletAssetId.xstusd.rawValue, "XSTUSD"),
  ].map {
    AssetInfo(
      id: $0.0, symbol: $0.1, chainId: "", precision: 18, icon: nil, displayName: $0.1,
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

private final class LiquidityFlowEvents: EventVisitorProtocol {
  var events: [NewTransactionCreatedEvent] = []
  func processNewTransactionCreated(event: NewTransactionCreatedEvent) { events.append(event) }
}
