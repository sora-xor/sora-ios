// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause
import Combine
import IrohaCrypto
import RobinHood
import SSFUtils
import SoraFoundation
import SoraUIKit
import UIKit
import XCTest

@testable import SoraPassport

@MainActor
final class ClaimRewardsLifecycleTests: XCTestCase {
  private var previous: AccountItem?
  private var owner: AccountItem!
  override func setUpWithError() throws {
    previous = SelectedWalletSettings.shared.currentAccount
    let key = Data(repeating: 3, count: 32)
    owner = AccountItem(
      address: try SS58AddressFactory().address(
        fromAccountId: key, type: SNAddressType(chain: .sora)), cryptoType: .sr25519,
      networkType: 69, username: "Claim fixture", publicKeyData: key,
      settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: 0,
      isSelected: true)
    SelectedWalletSettings.shared.commitInternalValue(owner)
  }
  override func tearDown() {
    SelectedWalletSettings.shared.commitInternalValue(previous)
    super.tearDown()
  }
  private struct Fixture {
    let model: ClaimRewardsViewModel
    let fee: ClaimFeeFixture
    let wallet: ClaimTransactionWallet
    let route: ClaimTransactionRoute
    let view: ClaimTransactionView
    let balances: ClaimTransactionBalances
  }
  private func make(
    reward: Decimal? = 5, fee: Decimal = 1, matching: Bool = true, begin: Bool = true
  ) -> Fixture {
    let assets = ClaimTransactionAssets()
    let wallet = ClaimTransactionWallet()
    let route = ClaimTransactionRoute()
    let balances = ClaimTransactionBalances(values: [WalletAssetId.xor.rawValue: 100])
    let view = ClaimTransactionView()
    let service = ClaimFeeFixture()
    service.result = .success(fee)
    let farm = Farm(
      id: "farm", name: "XOR-VAL", baseAsset: assets.assets[0], poolAsset: assets.assets[1],
      rewardAsset: assets.assets[0], tvl: 100, apr: 1, depositFee: 0)
    let user = UserFarm(
      id: "farm", baseAssetId: WalletAssetId.xor.rawValue, poolAssetId: WalletAssetId.val.rawValue,
      rewardAssetId: matching ? WalletAssetId.xor.rawValue : WalletAssetId.pswap.rawValue,
      isFarm: true, pooledTokens: 20, rewards: reward)
    let pool = PoolInfo(
      baseAssetId: WalletAssetId.xor.rawValue, targetAssetId: WalletAssetId.val.rawValue,
      poolId: "pool", accountId: owner.address, accountPoolBalance: 100, farms: [user])
    let model = ClaimRewardsViewModel(
      farm: farm, poolInfo: pool, fiatService: ClaimPrices(), assetsProvider: balances,
      detailsFactory: DetailViewModelFactory(assetManager: assets), service: service,
      walletService: wallet, wireframe: route, assetManager: assets)
    model.view = view
    if begin { model.viewDidLoad() }
    return Fixture(
      model: model, fee: service, wallet: wallet, route: route, view: view, balances: balances)
  }
  private func row(_ f: Fixture) throws -> ClaimRewardsItem {
    guard case .claim(let item)? = f.model.snapshot.itemIdentifiers.first else {
      throw CancellationError()
    }
    return item
  }
  private func wait(_ condition: () -> Bool) async {
    for _ in 0..<100 {
      if condition() { return }
      try? await Task.sleep(nanoseconds: 5_000_000)
    }
    XCTFail("Claim flow did not settle")
  }
  private func ready(_ f: Fixture) async { await wait { (try? row(f).claimPossible) == true } }
  func testClaimScreenShowsExactRewardAndFiatValue() async throws {
    let f = make()
    await ready(f)
    await wait { (try? self.row(f).amountText) == "$10" }
    XCTAssertTrue(try row(f).rewardText.contains("5 XOR"))
    XCTAssertEqual(try row(f).amountText, "$10")
    XCTAssertEqual(f.fee.requests.first?.0, WalletAssetId.xor.rawValue)
    XCTAssertEqual(f.fee.requests.first?.1, WalletAssetId.val.rawValue)
    XCTAssertEqual(f.fee.requests.first?.2, WalletAssetId.xor.rawValue)
    XCTAssertEqual(f.fee.requests.first?.3, true)
  }
  func testNoMatchingFarmNeverRequestsAFeeOrSubmits() {
    let f = make(matching: false)
    f.model.claimButtonTapped()
    XCTAssertTrue(f.fee.requests.isEmpty)
    XCTAssertTrue(f.wallet.transfers.isEmpty)
  }
  func testClaimBeforeTheFeeArrivesCannotSubmit() {
    let f = make(begin: false)
    f.fee.hold = true
    f.model.viewDidLoad()
    f.model.claimButtonTapped()
    XCTAssertTrue(f.wallet.transfers.isEmpty)
    f.fee.releaseAll()
  }
  func testZeroFeeCannotEnableOrSubmitAClaim() async throws {
    let f = make(fee: 0)
    await wait { f.fee.requests.count == 1 }
    XCTAssertFalse(try row(f).claimPossible)
    f.model.claimButtonTapped()
    XCTAssertTrue(f.wallet.transfers.isEmpty)
  }
  func testNegativeFeeCannotEnableOrSubmitAClaim() async throws {
    let f = make(fee: -1)
    await wait { f.fee.requests.count == 1 }
    try? await Task.sleep(nanoseconds: 20_000_000)
    XCTAssertFalse(try row(f).claimPossible)
    f.model.claimButtonTapped()
    XCTAssertTrue(f.wallet.transfers.isEmpty)
  }
  func testZeroRewardsCannotEnableOrSubmitAClaim() async throws {
    let f = make(reward: 0)
    await wait { f.fee.requests.count == 1 }
    try? await Task.sleep(nanoseconds: 20_000_000)
    XCTAssertFalse(try row(f).claimPossible)
    f.model.claimButtonTapped()
    XCTAssertTrue(f.wallet.transfers.isEmpty)
  }
  func testUnknownRewardsCannotEnableOrSubmitAClaim() async throws {
    let f = make(reward: nil)
    await wait { f.fee.requests.count == 1 }
    try? await Task.sleep(nanoseconds: 20_000_000)
    XCTAssertFalse(try row(f).claimPossible)
    f.model.claimButtonTapped()
    XCTAssertTrue(f.wallet.transfers.isEmpty)
  }
  func testFailedFeeReadCannotSubmitAClaim() async {
    let f = make(begin: false)
    f.fee.result = .failure(CancellationError())
    f.model.viewDidLoad()
    await wait { f.fee.requests.count == 1 }
    f.model.claimButtonTapped()
    XCTAssertTrue(f.wallet.transfers.isEmpty)
  }
  func testMissingBalanceAtConfirmationCannotSubmit() async {
    let f = make()
    await ready(f)
    f.balances.values.removeAll()
    f.model.claimButtonTapped()
    XCTAssertTrue(f.wallet.transfers.isEmpty)
  }
  func testInsufficientBalanceAtConfirmationCannotSubmit() async {
    let f = make()
    await ready(f)
    f.balances.values[WalletAssetId.xor.rawValue] = 0
    f.model.claimButtonTapped()
    XCTAssertTrue(f.wallet.transfers.isEmpty)
  }
  func testUnavailableBalanceAtConfirmationCannotSubmit() async {
    let f = make()
    await ready(f)
    f.balances.unavailable = [WalletAssetId.xor.rawValue]
    f.model.claimButtonTapped()
    XCTAssertTrue(f.wallet.transfers.isEmpty)
  }
  func testDeselectedWalletCannotUseAnOldClaimReview() async {
    let f = make()
    await ready(f)
    SelectedWalletSettings.shared.commitInternalValue(nil)
    f.model.claimButtonTapped()
    XCTAssertTrue(f.wallet.transfers.isEmpty)
  }
  func testChangedWalletIdentityCannotUseAnOldClaimReview() async {
    let f = make()
    await ready(f)
    let other = AccountItem(address: owner.address, cryptoType: .ed25519, networkType: 69, username: owner.username, publicKeyData: owner.publicKeyData, settings: owner.settings, order: owner.order, isSelected: true)
    SelectedWalletSettings.shared.commitInternalValue(other)
    f.model.claimButtonTapped()
    XCTAssertTrue(f.wallet.transfers.isEmpty)
  }
  func testAValidClaimUsesExactFarmIdentifiersAndNoTransferAmount() async throws {
    let f = make()
    await ready(f)
    f.model.claimButtonTapped()
    let info = try XCTUnwrap(f.wallet.transfers.first)
    XCTAssertEqual(info.source, WalletAssetId.xor.rawValue)
    XCTAssertEqual(info.destination, WalletAssetId.val.rawValue)
    XCTAssertEqual(info.amount.decimalValue, 0)
    XCTAssertEqual(info.context?[TransactionContextKeys.rewardAsset], WalletAssetId.xor.rawValue)
    XCTAssertEqual(info.context?[TransactionContextKeys.isFarm], "1")
    XCTAssertEqual(
      info.context?[TransactionContextKeys.transactionType],
      TransactionType.demeterClaimReward.rawValue)
  }
  func testRepeatedConfirmationCreatesOnlyOnePendingClaim() async {
    let f = make()
    await ready(f)
    f.model.claimButtonTapped()
    f.model.claimButtonTapped()
    XCTAssertEqual(f.wallet.transfers.count, 1)
    XCTAssertEqual(f.route.loading, 1)
  }
  func testSuccessReceiptUsesTheSubmittedRewardAmountAndHash() async throws {
    let f = make()
    await ready(f)
    f.model.claimButtonTapped()
    f.wallet.completions[0](.success(Data([0xab, 0xcd])))
    await wait { f.route.details.count == 1 }
    let receipt = try XCTUnwrap(f.route.details.first as? ClaimReward)
    XCTAssertEqual(receipt.amount.decimalValue, 5)
    XCTAssertEqual(receipt.base.txHash, "0xabcd")
    XCTAssertEqual(receipt.base.status, .pending)
    XCTAssertEqual(receipt.peer, owner.address)
    XCTAssertEqual(f.route.hidden, 1)
  }
  func testFailureReceiptPreservesTheRewardIdentity() async throws {
    let f = make()
    await ready(f)
    f.model.claimButtonTapped()
    f.wallet.completions[0](.failure(CancellationError()))
    await wait { f.route.details.count == 1 }
    let receipt = try XCTUnwrap(f.route.details.first as? ClaimReward)
    XCTAssertEqual(receipt.base.status, .failed)
    XCTAssertEqual(receipt.rewardTokenId, WalletAssetId.xor.rawValue)
    XCTAssertEqual(receipt.amount.decimalValue, 5)
  }
  func testReceiptRetainsTheSendingWalletWhenSelectionChanges() async throws {
    let f = make()
    await ready(f)
    f.model.claimButtonTapped()
    SelectedWalletSettings.shared.commitInternalValue(nil)
    f.wallet.completions[0](.failure(CancellationError()))
    await wait { f.route.details.count == 1 }
    XCTAssertEqual((f.route.details.first as? ClaimReward)?.peer, owner.address)
  }
  func testReceiptRetainsTheReviewedRewardWhenThePoolRefreshes() async throws {
    let f = make()
    await ready(f)
    f.model.claimButtonTapped()
    f.model.poolInfo.farms[0].rewards = 99
    f.model.viewDidLoad()
    f.wallet.completions[0](.success(Data([1])))
    await wait { f.route.details.count == 1 }
    XCTAssertEqual((f.route.details.first as? ClaimReward)?.amount.decimalValue, 5)
  }
  func testMissingCompletionResultClearsLoadingWithoutAReceipt() async {
    let f = make()
    await ready(f)
    f.model.claimButtonTapped()
    f.wallet.completions[0](nil)
    await wait { f.route.hidden == 1 }
    XCTAssertTrue(f.route.details.isEmpty)
    f.model.claimButtonTapped()
    XCTAssertEqual(f.wallet.transfers.count, 2)
  }
  func testNetworkFeeExplanationDoesNotSubmit() {
    let f = make()
    f.model.networkFeeInfoButtonTapped()
    XCTAssertEqual(f.view.alerts.count, 1)
    XCTAssertTrue(f.wallet.transfers.isEmpty)
  }
  func testRefreshingFeeDisablesThePreviousReviewUntilItsNewAnswer() async throws {
    let f = make()
    await ready(f)
    f.fee.hold = true
    f.model.viewDidLoad()
    await wait { f.fee.requests.count == 2 }
    XCTAssertFalse(try row(f).claimPossible)
    f.fee.releaseAll()
  }
  func testOlderFeeResponseCannotReplaceTheLatestReview() async throws {
    let f = make(begin: false)
    f.fee.hold = true
    f.model.viewDidLoad()
    await wait { f.fee.requests.count == 1 }
    f.model.viewDidLoad()
    await wait { f.fee.requests.count == 2 }
    f.balances.values[WalletAssetId.xor.rawValue] = 5
    f.fee.release(index: 1, result: .success(200))
    try? await Task.sleep(nanoseconds: 20_000_000)
    f.fee.release(index: 0, result: .success(1))
    try? await Task.sleep(nanoseconds: 20_000_000)
    XCTAssertFalse(try row(f).claimPossible)
  }
  func testClaimScreenRendersItsItemAndUpdatesTheButton() async throws {
    let f = make()
    let screen = ClaimRewardsViewController(viewModel: f.model)
    f.model.view = screen
    screen.loadViewIfNeeded()
    screen.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
    await ready(f)
    let table = try XCTUnwrap(descendants(UITableView.self, screen.view).first)
    await wait { table.numberOfSections > 0 && table.numberOfRows(inSection: 0) == 1 }
    let cell = table.dataSource?.tableView(table, cellForRowAt: IndexPath(row: 0, section: 0))
    XCTAssertNotNil(cell as? ClaimRewardsCell)
  }
  private func descendants<T: UIView>(_ type: T.Type, _ view: UIView) -> [T] {
    ((view as? T).map { [$0] } ?? []) + view.subviews.flatMap { descendants(type, $0) }
  }
}
private actor ClaimPrices: FiatServiceProtocol {
  func getFiat() async -> [PIExactFiatData] {
    [PIExactFiatData(id: WalletAssetId.xor.rawValue, priceUsd: try! PIQuantity("2"))]
  }
}
private final class ClaimFeeFixture: ClaimRewardsServiceProtocol {
  var result: Result<Decimal, Error> = .success(1), hold = false
  private let lock = NSLock()
  private var recorded: [(String, String, String, Bool)] = []
  private var pending: [CheckedContinuation<Decimal, Error>?] = []
  var requests: [(String, String, String, Bool)] {
    lock.lock()
    defer { lock.unlock() }
    return recorded
  }
  func getFee(for baseAssetId: String, targetAssetId: String, rewardAssetId: String, isFarm: Bool)
    async throws -> Decimal
  {
    try await withCheckedThrowingContinuation { continuation in
      lock.lock()
      recorded.append((baseAssetId, targetAssetId, rewardAssetId, isFarm))
      if hold {
        pending.append(continuation)
        lock.unlock()
      } else {
        let value = result
        lock.unlock()
        continuation.resume(with: value)
      }
    }
  }
  func release(index: Int, result: Result<Decimal, Error>) {
    lock.lock()
    let continuation = pending[index]
    pending[index] = nil
    lock.unlock()
    continuation?.resume(with: result)
  }
  func releaseAll() {
    lock.lock()
    hold = false
    let continuations = pending
    pending.removeAll()
    let value = result
    lock.unlock()
    continuations.forEach { $0?.resume(with: value) }
  }
}

private final class ClaimTransactionRoute: ConfirmTransactionWireframeProtocol {
  var loading = 0
  var hidden = 0
  var details: [Transaction] = []
  func showActivityIndicator() { loading += 1 }
  func hideActivityIndicator() { hidden += 1 }
  func showActivityDetails(
    on controller: UIViewController?, model: Transaction, assetManager: AssetManagerProtocol,
    completion: (() -> Void)?
  ) { details.append(model) }
}
private final class ClaimTransactionView: UIViewController, ClaimRewardsViewProtocol {
  var controller: UIViewController { self }
  var alerts: [UIViewController] = []
  func dismiss(competion: (() -> Void)?) { competion?() }
  override func present(
    _ viewControllerToPresent: UIViewController, animated flag: Bool,
    completion: (() -> Void)? = nil
  ) {
    alerts.append(viewControllerToPresent)
    completion?()
  }
}
private final class ClaimTransactionFee: FeeProviderProtocol {
  func getFee(for type: TransactionType, completion: @escaping (Decimal) -> Void) { completion(1) }
  func getFee(for type: InputRewardAmountType, completion: @escaping (Decimal) -> Void) {
    completion(1)
  }
  func getFee(for call: any RuntimeCallable) async -> Decimal { 1 }
  func getFee(for type: TransactionType) async -> Decimal { 1 }
}
private final class ClaimTransactionCall: CancellableCall { func cancel() {} }
private final class ClaimTransactionWallet: WalletServiceProtocol {
  var transfers: [TransferInfo] = []
  var completions: [DataResultCompletionBlock] = []
  var queries: [String] = []
  var searchCompletions: [SearchCompletionBlock] = []
  var calls: [ClaimTransactionCall] = []
  private let unused = WalletService(operationFactory: WalletNetworkOperationFactoryProtocolMock())
  func search(
    for searchString: String, runCompletionIn queue: DispatchQueue,
    completionBlock: @escaping SearchCompletionBlock
  ) -> CancellableCall {
    queries.append(searchString)
    searchCompletions.append(completionBlock)
    let call = ClaimTransactionCall()
    calls.append(call)
    return call
  }
  func fetchBalance(
    for assets: [String], runCompletionIn queue: DispatchQueue,
    completionBlock: @escaping BalanceCompletionBlock
  ) -> CancellableCall {
    unused.fetchBalance(for: assets, runCompletionIn: queue, completionBlock: completionBlock)
  }
  func fetchTransactionHistory(
    for filter: WalletHistoryRequest, pagination: Pagination, runCompletionIn queue: DispatchQueue,
    completionBlock: @escaping TransactionHistoryBlock
  ) -> CancellableCall {
    unused.fetchTransactionHistory(
      for: filter, pagination: pagination, runCompletionIn: queue, completionBlock: completionBlock)
  }
  func fetchTransferMetadata(
    for info: TransferMetadataInfo, runCompletionIn queue: DispatchQueue,
    completionBlock: @escaping TransferMetadataCompletionBlock
  ) -> CancellableCall {
    unused.fetchTransferMetadata(
      for: info, runCompletionIn: queue, completionBlock: completionBlock)
  }
  func transfer(
    info: TransferInfo, runCompletionIn queue: DispatchQueue,
    completionBlock: @escaping DataResultCompletionBlock
  ) -> CancellableCall {
    transfers.append(info)
    completions.append(completionBlock)
    return ClaimTransactionCall()
  }
  func prepareTransferSubmission(
    for info: TransferInfo, preSigningValidation: @escaping () throws -> Void
  ) async throws -> PreparedSora2TransferSubmission {
    XCTFail("Scanner attempted to sign")
    throw CancellationError()
  }
  func submitPreparedTransfer(
    _ submission: PreparedSora2TransferSubmission, info: TransferInfo,
    preTransportValidation: @escaping () throws -> Void
  ) async throws -> Data {
    XCTFail("Scanner attempted a submission")
    throw CancellationError()
  }
  func fetchContacts(
    runCompletionIn queue: DispatchQueue, completionBlock: @escaping SearchCompletionBlock
  ) -> CancellableCall {
    unused.fetchContacts(runCompletionIn: queue, completionBlock: completionBlock)
  }
  func fetchWithdrawalMetadata(
    for info: WithdrawMetadataInfo, runCompletionIn queue: DispatchQueue,
    completionBlock: @escaping WithdrawalMetadataCompletionBlock
  ) -> CancellableCall {
    unused.fetchWithdrawalMetadata(
      for: info, runCompletionIn: queue, completionBlock: completionBlock)
  }
  func withdraw(
    info: WithdrawInfo, runCompletionIn queue: DispatchQueue,
    completionBlock: @escaping DataResultCompletionBlock
  ) -> CancellableCall {
    XCTFail("Scanner attempted withdrawal")
    return ClaimTransactionCall()
  }
}

private final class ClaimTransactionBalances: AssetProviderProtocol {
  var values: [String: Decimal]
  var unavailable: Set<String> = []
  var observers = 0
  init(values: [String: Decimal]) { self.values = values }
  func getBalances(with assetIds: [String]) -> [BalanceData] {
    assetIds.compactMap { id in
      values[id].map { BalanceData(identifier: id, balance: AmountDecimal(value: $0)) }
    }
  }
  func unavailableBalanceAssetIds(among assetIds: [String]) -> Set<String> {
    unavailable.intersection(assetIds)
  }
  func add(observer: AssetProviderObserverProtocol) { observers += 1 }
  func remove(observer: AssetProviderObserverProtocol) { observers -= 1 }
}
private final class ClaimTransactionAssets: AssetManagerProtocol {
  static var networkAssets: [AssetInfo] = []
  let assets = [
    AssetInfo(
      id: WalletAssetId.xor.rawValue, symbol: "XOR", chainId: "", precision: 18, icon: nil,
      displayName: "SORA", visible: true),
    AssetInfo(
      id: WalletAssetId.val.rawValue, symbol: "VAL", chainId: "", precision: 6, icon: nil,
      displayName: "Validator", visible: true),
  ]
  func assetInfo(for identifier: String) -> AssetInfo? { assets.first { $0.assetId == identifier } }
  func getAssetList() -> [AssetInfo]? { assets }
  func updateAssetList(_ list: [AssetInfo]) {}
  func saveAssetList(_ list: [AssetInfo]) {}
  func sortedAssets(_ list: [WalletAsset], onlyVisible: Bool) -> [WalletAsset] { list }
  func visibleCount() -> UInt { 2 }
  func setup(for accountSettings: SelectedWalletSettings) {}
}
