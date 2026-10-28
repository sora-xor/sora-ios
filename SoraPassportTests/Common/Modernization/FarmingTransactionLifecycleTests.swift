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
final class FarmingTransactionLifecycleTests: XCTestCase {
    private var previous: AccountItem?
    private var owner: AccountItem!
    private var subscriptions = Set<AnyCancellable>()
    override func setUpWithError() throws {
        try super.setUpWithError(); previous = SelectedWalletSettings.shared.currentAccount
        let key = Data(repeating: 3, count: 32)
        owner = AccountItem(address: try SS58AddressFactory().address(fromAccountId: key, type: SNAddressType(chain: .sora)), cryptoType: .sr25519, networkType: 69, username: "Farm fixture", publicKeyData: key, settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: 0, isSelected: true)
        SelectedWalletSettings.shared.commitInternalValue(owner)
    }
    override func tearDown() { subscriptions.removeAll(); SelectedWalletSettings.shared.commitInternalValue(previous); super.tearDown() }
    private struct Fixture { let model: EditFarmViewModel; let wallet: FarmTransactionWallet; let route: FarmTransactionRoute; let view: FarmTransactionView; let balances: FarmTransactionBalances }
    private func make(matching: Bool = true) -> Fixture {
        let assets = FarmTransactionAssets(); let wallet = FarmTransactionWallet(); let route = FarmTransactionRoute(); let balances = FarmTransactionBalances(values: [WalletAssetId.xor.rawValue: 100]); let view = FarmTransactionView()
        let farm = Farm(id: "farm", name: "XOR-VAL", baseAsset: assets.assets[0], poolAsset: assets.assets[1], rewardAsset: assets.assets[0], tvl: 100, apr: 10, depositFee: 5)
        let user = UserFarm(id: "user-farm", baseAssetId: WalletAssetId.xor.rawValue, poolAssetId: WalletAssetId.val.rawValue, rewardAssetId: matching ? WalletAssetId.xor.rawValue : WalletAssetId.pswap.rawValue, isFarm: true, pooledTokens: 20, rewards: 777)
        let pool = PoolInfo(baseAssetId: WalletAssetId.xor.rawValue, targetAssetId: WalletAssetId.val.rawValue, poolId: "pool", accountId: owner.address, accountPoolBalance: 100, farms: [user])
        let model = EditFarmViewModel(farm: farm, poolInfo: pool, assetsProvider: balances, feeProvider: FarmTransactionFee(), walletService: wallet, wireframe: route, assetManager: assets)
        model.view = view; model.viewDidLoad()
        return Fixture(model: model, wallet: wallet, route: route, view: view, balances: balances)
    }
    private func row(_ f: Fixture) throws -> EditFarmItem { let entry = try XCTUnwrap(f.model.snapshot.itemIdentifiers.first); guard case .stake(let row) = entry else { throw CancellationError() }; return row }
    private func wait(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async { for _ in 0..<200 { if condition() { return }; try? await Task.sleep(nanoseconds: 10_000_000) }; XCTFail("Farm flow did not finish", file: file, line: line) }
    private func select(_ f: Fixture, percent: Decimal = 50) async throws -> (EditFarmItemService, PassthroughSubject<FarmShareSelection, Never>) {
        let service = try XCTUnwrap(row(f).service); let input = PassthroughSubject<FarmShareSelection, Never>(); service.transform(input: input.eraseToAnyPublisher()).sink { _ in }.store(in: &subscriptions); input.send(FarmShareSelection(percent: percent)!); await wait { service.confirmButtonEnabled }; return (service, input)
    }
    func testFarmEditorMatchesAllThreeAssetsAndShowsCurrentShare() throws { let f = make(); XCTAssertEqual(f.model.sharePercentage, 20); XCTAssertEqual(try row(f).sharePercentage, 20); XCTAssertEqual(try row(f).stakedSelection.basisPoints, 2000) }
    func testDifferentRewardAssetCannotCreateAnEditableFarm() { let f = make(matching: false); XCTAssertNil(f.model.userFarmInfo); XCTAssertTrue(f.model.snapshot.itemIdentifiers.isEmpty); f.model.confirmButtonTapped(); XCTAssertTrue(f.wallet.transfers.isEmpty) }
    func testUnchangedShareCannotSubmitAnEmptyTransaction() { let f = make(); f.model.confirmButtonTapped(); XCTAssertTrue(f.wallet.transfers.isEmpty); XCTAssertEqual(f.route.loading, 0) }
    func testBalanceLossBeforeConfirmationPreventsSubmission() async throws {
        let f = make(); let (_, input) = try await select(f); f.balances.values[WalletAssetId.xor.rawValue] = 0
        f.model.confirmButtonTapped(); XCTAssertTrue(f.wallet.transfers.isEmpty); withExtendedLifetime(input) {}
    }
    func testMissingBalanceBeforeConfirmationPreventsSubmission() async throws {
        let f = make(); let (_, input) = try await select(f); f.balances.values.removeAll()
        f.model.confirmButtonTapped(); XCTAssertTrue(f.wallet.transfers.isEmpty); withExtendedLifetime(input) {}
    }
    func testWalletDeselectionBeforeConfirmationPreventsSubmission() async throws {
        let f = make(); let (_, input) = try await select(f); SelectedWalletSettings.shared.commitInternalValue(nil)
        f.model.confirmButtonTapped(); XCTAssertTrue(f.wallet.transfers.isEmpty); withExtendedLifetime(input) {}
    }
    func testWalletSwitchBeforeConfirmationCannotUseAnOldFarmReview() async throws {
        let f = make(); let (_, input) = try await select(f)
        let key = Data(repeating: 4, count: 32)
        let other = AccountItem(address: try SS58AddressFactory().address(fromAccountId: key, type: SNAddressType(chain: .sora)), cryptoType: .sr25519, networkType: 69, username: "Another fixture", publicKeyData: key, settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: 0, isSelected: true)
        SelectedWalletSettings.shared.commitInternalValue(other); f.model.confirmButtonTapped(); XCTAssertTrue(f.wallet.transfers.isEmpty); withExtendedLifetime(input) {}
    }
    func testDepositCarriesTheExactDeltaAndAllDemeterCallFields() async throws { let f = make(); let (_, input) = try await select(f); f.model.confirmButtonTapped(); let info = try XCTUnwrap(f.wallet.transfers.first); XCTAssertEqual(info.amount.decimalValue, 30); XCTAssertEqual(info.source, WalletAssetId.xor.rawValue); XCTAssertEqual(info.destination, WalletAssetId.val.rawValue); XCTAssertEqual(info.context?[TransactionContextKeys.rewardAsset], WalletAssetId.xor.rawValue); XCTAssertEqual(info.context?[TransactionContextKeys.isFarm], "1"); XCTAssertEqual(info.context?[TransactionContextKeys.transactionType], TransactionType.demeterDeposit.rawValue); withExtendedLifetime(input) {} }
    func testWithdrawalUsesTheExactWithdrawnPoolTokenAmount() async throws { let f = make(); let (_, input) = try await select(f, percent: 10); f.model.confirmButtonTapped(); XCTAssertEqual(f.wallet.transfers.first?.amount.decimalValue, 10); XCTAssertEqual(f.wallet.transfers.first?.context?[TransactionContextKeys.transactionType], TransactionType.demeterWithdraw.rawValue); withExtendedLifetime(input) {} }
    func testRepeatedConfirmCannotCreateConcurrentTransactions() async throws { let f = make(); let (_, input) = try await select(f); f.model.confirmButtonTapped(); f.model.confirmButtonTapped(); XCTAssertEqual(f.wallet.transfers.count, 1); withExtendedLifetime(input) {} }
    func testFailedReceiptShowsTheSubmittedPoolTokensRatherThanAccruedRewards() async throws { let f = make(); let (_, input) = try await select(f); f.model.confirmButtonTapped(); f.wallet.completions[0](.failure(CancellationError())); await wait { !f.route.details.isEmpty }; let tx = try XCTUnwrap(f.route.details.first as? FarmLiquidity); XCTAssertEqual(tx.amount.decimalValue, 30); XCTAssertEqual(tx.base.status, .failed); XCTAssertEqual(tx.sender, owner.address); XCTAssertEqual(f.route.hidden, 1); withExtendedLifetime(input) {} }
    func testPendingReceiptRetainsTheSubmittedAmountWhenTheSliderMoves() async throws { let f = make(); let (_, input) = try await select(f); f.model.confirmButtonTapped(); input.send(FarmShareSelection(percent: 10)!); f.wallet.completions[0](.success(Data([0xab, 0xcd]))); await wait { !f.route.details.isEmpty }; let tx = try XCTUnwrap(f.route.details.first as? FarmLiquidity); XCTAssertEqual(tx.amount.decimalValue, 30); XCTAssertEqual(tx.type, .add); XCTAssertEqual(tx.base.txHash, "0xabcd"); XCTAssertEqual(tx.base.status, .pending) }
    func testReceiptRetainsTheSendingAccountWhenWalletSelectionChanges() async throws { let f = make(); let (_, input) = try await select(f); f.model.confirmButtonTapped(); SelectedWalletSettings.shared.commitInternalValue(nil); f.wallet.completions[0](.failure(CancellationError())); await wait { !f.route.details.isEmpty }; XCTAssertEqual((f.route.details.first as? FarmLiquidity)?.sender, owner.address); withExtendedLifetime(input) {} }
    func testMissingTransferResultRestoresLoadingStateWithoutDetails() async throws { let f = make(); let (_, input) = try await select(f); f.model.confirmButtonTapped(); f.wallet.completions[0](nil); await wait { f.route.hidden == 1 }; XCTAssertEqual(f.route.loading, 1); XCTAssertEqual(f.route.hidden, 1); XCTAssertTrue(f.route.details.isEmpty); withExtendedLifetime(input) {} }
    func testFarmInfoActionsPresentExplanationsWithoutSubmitting() { let f = make(); f.model.feeInfoButtonTapped(); f.model.networkFeeInfoButtonTapped(); XCTAssertEqual(f.view.alerts.count, 2); XCTAssertTrue(f.wallet.transfers.isEmpty) }
    func testFarmScreenLoadsAndDisplaysItsPublishedItem() async throws { let f = make(); let screen = EditFarmViewController(viewModel: f.model); f.model.view = screen; screen.loadViewIfNeeded(); screen.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844); screen.view.layoutIfNeeded(); let table = try XCTUnwrap(descendants(UITableView.self, in: screen.view).first); await wait { table.numberOfSections > 0 && table.numberOfRows(inSection: 0) == 1 }; XCTAssertNotNil(screen.navigationItem.title) }
    private func descendants<T: UIView>(_ type: T.Type, in view: UIView) -> [T] { ((view as? T).map { [$0] } ?? []) + view.subviews.flatMap { descendants(type, in: $0) } }
}
private final class FarmTransactionRoute: ConfirmTransactionWireframeProtocol {
    var loading = 0; var hidden = 0; var details: [Transaction] = []
    func showActivityIndicator() { loading += 1 }; func hideActivityIndicator() { hidden += 1 }
    func showActivityDetails(on controller: UIViewController?, model: Transaction, assetManager: AssetManagerProtocol, completion: (() -> Void)?) { details.append(model) }
}
private final class FarmTransactionView: UIViewController, EditFarmViewProtocol {
    var controller: UIViewController { self }; var alerts: [UIViewController] = []
    func dismiss(competion: (() -> Void)?) { competion?() }
    override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) { alerts.append(viewControllerToPresent); completion?() }
}
private final class FarmTransactionFee: FeeProviderProtocol {
    func getFee(for type: TransactionType, completion: @escaping (Decimal) -> Void) { completion(1) }
    func getFee(for type: InputRewardAmountType, completion: @escaping (Decimal) -> Void) { completion(1) }
    func getFee(for call: any RuntimeCallable) async -> Decimal { 1 }
    func getFee(for type: TransactionType) async -> Decimal { 1 }
}
private final class FarmTransactionCall: CancellableCall { func cancel() {} }
private final class FarmTransactionWallet: WalletServiceProtocol {
    var transfers: [TransferInfo] = []
    var completions: [DataResultCompletionBlock] = []
    var queries: [String] = []; var searchCompletions: [SearchCompletionBlock] = []; var calls: [FarmTransactionCall] = []
    private let unused = WalletService(operationFactory: WalletNetworkOperationFactoryProtocolMock())
    func search(for searchString: String, runCompletionIn queue: DispatchQueue, completionBlock: @escaping SearchCompletionBlock) -> CancellableCall {
        queries.append(searchString); searchCompletions.append(completionBlock); let call = FarmTransactionCall(); calls.append(call); return call
    }
    func fetchBalance(for assets: [String], runCompletionIn queue: DispatchQueue, completionBlock: @escaping BalanceCompletionBlock) -> CancellableCall { unused.fetchBalance(for: assets, runCompletionIn: queue, completionBlock: completionBlock) }
    func fetchTransactionHistory(for filter: WalletHistoryRequest, pagination: Pagination, runCompletionIn queue: DispatchQueue, completionBlock: @escaping TransactionHistoryBlock) -> CancellableCall { unused.fetchTransactionHistory(for: filter, pagination: pagination, runCompletionIn: queue, completionBlock: completionBlock) }
    func fetchTransferMetadata(for info: TransferMetadataInfo, runCompletionIn queue: DispatchQueue, completionBlock: @escaping TransferMetadataCompletionBlock) -> CancellableCall { unused.fetchTransferMetadata(for: info, runCompletionIn: queue, completionBlock: completionBlock) }
    func transfer(info: TransferInfo, runCompletionIn queue: DispatchQueue, completionBlock: @escaping DataResultCompletionBlock) -> CancellableCall { transfers.append(info); completions.append(completionBlock); return FarmTransactionCall() }
    func prepareTransferSubmission(for info: TransferInfo, preSigningValidation: @escaping () throws -> Void) async throws -> PreparedSora2TransferSubmission { XCTFail("Scanner attempted to sign"); throw CancellationError() }
    func submitPreparedTransfer(_ submission: PreparedSora2TransferSubmission, info: TransferInfo, preTransportValidation: @escaping () throws -> Void) async throws -> Data { XCTFail("Scanner attempted a submission"); throw CancellationError() }
    func fetchContacts(runCompletionIn queue: DispatchQueue, completionBlock: @escaping SearchCompletionBlock) -> CancellableCall { unused.fetchContacts(runCompletionIn: queue, completionBlock: completionBlock) }
    func fetchWithdrawalMetadata(for info: WithdrawMetadataInfo, runCompletionIn queue: DispatchQueue, completionBlock: @escaping WithdrawalMetadataCompletionBlock) -> CancellableCall { unused.fetchWithdrawalMetadata(for: info, runCompletionIn: queue, completionBlock: completionBlock) }
    func withdraw(info: WithdrawInfo, runCompletionIn queue: DispatchQueue, completionBlock: @escaping DataResultCompletionBlock) -> CancellableCall { XCTFail("Scanner attempted withdrawal"); return FarmTransactionCall() }
}

private final class FarmTransactionBalances: AssetProviderProtocol {
    var values: [String: Decimal]; var unavailable: Set<String> = []; var observers = 0
    init(values: [String: Decimal]) { self.values = values }
    func getBalances(with assetIds: [String]) -> [BalanceData] { assetIds.compactMap { id in values[id].map { BalanceData(identifier: id, balance: AmountDecimal(value: $0)) } } }
    func unavailableBalanceAssetIds(among assetIds: [String]) -> Set<String> { unavailable.intersection(assetIds) }
    func add(observer: AssetProviderObserverProtocol) { observers += 1 }; func remove(observer: AssetProviderObserverProtocol) { observers -= 1 }
}
private final class FarmTransactionAssets: AssetManagerProtocol {
    static var networkAssets: [AssetInfo] = []
    let assets = [AssetInfo(id: WalletAssetId.xor.rawValue, symbol: "XOR", chainId: "", precision: 18, icon: nil, displayName: "SORA", visible: true), AssetInfo(id: WalletAssetId.val.rawValue, symbol: "VAL", chainId: "", precision: 6, icon: nil, displayName: "Validator", visible: true)]
    func assetInfo(for identifier: String) -> AssetInfo? { assets.first { $0.assetId == identifier } }; func getAssetList() -> [AssetInfo]? { assets }; func updateAssetList(_ list: [AssetInfo]) {}; func saveAssetList(_ list: [AssetInfo]) {}
    func sortedAssets(_ list: [WalletAsset], onlyVisible: Bool) -> [WalletAsset] { list }; func visibleCount() -> UInt { 2 }; func setup(for accountSettings: SelectedWalletSettings) {}
}
