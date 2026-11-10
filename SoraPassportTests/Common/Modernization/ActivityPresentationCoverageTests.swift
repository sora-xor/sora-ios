// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0
import SoraFoundation
import SoraKeystore
import SoraUIKit
import SSFUtils
import UIKit
import XCTest
@testable import SoraPassport

@MainActor
final class ActivityPresentationCoverageTests: XCTestCase {
    private var language = "en"
    private var previous: AccountItem?
    private let manager = PresentationAssets()
    override func setUp() {
        super.setUp(); language = LocalizationManager.shared.selectedLocalization
        LocalizationManager.shared.selectedLocalization = "en"
        previous = SelectedWalletSettings.shared.currentAccount
        SelectedWalletSettings.shared.commitInternalValue(AccountItem(address: "selected", cryptoType: .sr25519, networkType: 69,
            username: "Fixture", publicKeyData: Data(repeating: 1, count: 32),
            settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: 0, isSelected: true))
    }
    override func tearDown() {
        SelectedWalletSettings.shared.commitInternalValue(previous)
        LocalizationManager.shared.selectedLocalization = language; super.tearDown()
    }
    private func base(status: TransactionBase.Status = .success, fee: Decimal = 1_000_000_000_000_000_000,
                      hash: String = "0x01", block: String = "block") -> TransactionBase {
        TransactionBase(txHash: hash, blockHash: block, fee: Amount(value: fee), status: status, timestamp: "1700000000")
    }
    private func model(_ transaction: Transaction) -> ActivityDetailsViewModel {
        let model = ActivityDetailsViewModel(model: transaction, wireframe: nil, assetManager: manager,
            detailsFactory: ActivityDetailsViewModelFactory(assetManager: manager), historyService: PresentationHistory(),
            lpServiceFee: PresentationLPFee(), journalOutcome: { _ in nil })
        model.updateContent { _ in }; return model
    }
    private func header(_ model: ActivityDetailsViewModel) throws -> HeaderActivityDetailsItem {
        try XCTUnwrap(model.items.compactMap { $0 as? HeaderActivityDetailsItem }.first)
    }
    private func details(_ model: ActivityDetailsViewModel) throws -> ActivityDetailsItem {
        try XCTUnwrap(model.items.compactMap { $0 as? ActivityDetailsItem }.first)
    }
    private func transfer(_ type: TransferTransaction.TransferType, status: TransactionBase.Status = .success,
                          hash: String = "0x01", block: String = "block") -> TransferTransaction {
        TransferTransaction(base: base(status: status, hash: hash, block: block), amount: Amount(value: Decimal(string: "12.25")!),
                            peer: "peer", transferType: type, tokenId: WalletAssetId.xor.rawValue)
    }
    func testOutgoingTransferShowsAmountFeeAndCorrectParticipants() throws {
        let model = model(transfer(.outcoming))
        XCTAssertEqual(try header(model).firstBalanceText.string, "12.25 XOR")
        XCTAssertEqual(try header(model).details.count, 3)
        XCTAssertEqual(try header(model).details.last?.assetAmountText.text, "1 XOR")
        XCTAssertEqual(try details(model).detailViewModels.map(\.value), ["0x01", "block", "peer", "selected"])
        XCTAssertEqual(model.assetId, WalletAssetId.xor.rawValue)
    }
    func testIncomingTransferHidesSenderPaidFeeAndReversesParticipants() throws {
        let model = model(transfer(.incoming))
        XCTAssertEqual(try header(model).firstBalanceText.string, "+ 12.25 XOR")
        XCTAssertEqual(try header(model).details.count, 2)
        XCTAssertEqual(try details(model).detailViewModels.map(\.value), ["0x01", "block", "selected", "peer"])
    }
    func testAbsentHashesAreOmittedFromDetails() throws {
        let model = model(transfer(.outcoming, hash: "", block: ""))
        XCTAssertEqual(try details(model).detailViewModels.map(\.value), ["peer", "selected"])
    }
    func testSwapKeepsTheAmountAndSymbolOfEachSideTogether() throws {
        let transaction = Swap(base: base(), fromTokenId: WalletAssetId.xor.rawValue, toTokenId: WalletAssetId.val.rawValue,
                               fromAmount: Amount(value: 2), toAmount: Amount(value: 7), market: .xyk)
        let model = model(transaction)
        XCTAssertEqual(try header(model).firstBalanceText.string, "2 XOR")
        XCTAssertEqual(try header(model).secondBalanceText?.string, "7 VAL")
        XCTAssertEqual(try details(model).detailViewModels.map(\.value), ["0x01", "block", "selected"])
    }
    func testLiquidityDepositKeepsTheAmountAndSymbolOfEachSideTogether() throws {
        let transaction = Liquidity(base: base(), firstTokenId: WalletAssetId.xor.rawValue, secondTokenId: WalletAssetId.val.rawValue,
                                    firstAmount: Amount(value: 2), secondAmount: Amount(value: 7), type: .add)
        let model = model(transaction)
        XCTAssertEqual(try header(model).firstBalanceText.string, "2 XOR")
        XCTAssertEqual(try header(model).secondBalanceText?.string, "7 VAL")
    }
    func testLiquidityWithdrawalShowsBothReturnedAssetsWithPositiveSigns() throws {
        let transaction = Liquidity(base: base(), firstTokenId: WalletAssetId.xor.rawValue, secondTokenId: WalletAssetId.val.rawValue,
                                    firstAmount: Amount(value: 2), secondAmount: Amount(value: 7), type: .withdraw)
        let model = model(transaction)
        XCTAssertEqual(try header(model).firstBalanceText.string, "+ 2 XOR")
        XCTAssertEqual(try header(model).secondBalanceText?.string, "+ 7 VAL")
    }
    func testReferralBondAndUnbondShowTheirOwnDirections() throws {
        for (type, expected) in [(ReferralBondTransaction.ReferralTransactionType.bond, "3 XOR"), (.unbond, "+ 3 XOR")] {
            let transaction = ReferralBondTransaction(base: base(), amount: Amount(value: 3), tokenId: WalletAssetId.xor.rawValue, type: type)
            let model = model(transaction)
            XCTAssertEqual(try header(model).firstBalanceText.string, expected)
            XCTAssertEqual(try details(model).detailViewModels.last?.value, "selected")
        }
    }
    func testSettingMyReferrerDisplaysFeeInXORInsteadOfAtomicUnits() throws {
        let transaction = SetReferrerTransaction(base: base(), who: "referrer", isMyReferrer: true, tokenId: WalletAssetId.xor.rawValue)
        let model = model(transaction)
        XCTAssertEqual(try header(model).firstBalanceText.string, "1 XOR")
        XCTAssertEqual(try header(model).details.count, 2)
        XCTAssertEqual(try details(model).detailViewModels.map(\.value), ["0x01", "block", "referrer", "selected"])
    }
    func testJoinedReferralDisplaysInvitationCountAndSender() throws {
        let transaction = SetReferrerTransaction(base: base(), who: "referral", isMyReferrer: false, tokenId: WalletAssetId.xor.rawValue)
        let model = model(transaction)
        XCTAssertTrue(try header(model).firstBalanceText.string.contains("1"))
        XCTAssertFalse(try header(model).firstBalanceText.string.contains("XOR"))
        XCTAssertEqual(try details(model).detailViewModels.last?.value, "referral")
    }
    func testClaimRewardShowsItsTokenAndRecipient() throws {
        let transaction = ClaimReward(base: base(), amount: Amount(value: 4), peer: "beneficiary", rewardTokenId: WalletAssetId.val.rawValue)
        let model = model(transaction)
        XCTAssertEqual(try header(model).firstBalanceText.string, "+ 4 VAL")
        XCTAssertEqual(try details(model).detailViewModels.last?.value, "beneficiary")
    }
    func testFarmDepositAndWithdrawalShowThePoolPairAndSender() throws {
        for type in [FarmLiquidity.TransactionLiquidityType.add, .withdraw] {
            let transaction = FarmLiquidity(base: base(), firstTokenId: WalletAssetId.xor.rawValue, secondTokenId: WalletAssetId.val.rawValue,
                rewardTokenId: WalletAssetId.val.rawValue, amount: Amount(value: 5), sender: "farmer", type: type)
            let model = model(transaction)
            XCTAssertEqual(try header(model).firstBalanceText.string, "5 XOR-VAL")
            XCTAssertEqual(try details(model).detailViewModels.last?.value, "farmer")
        }
    }
    func testSubmittedTransactionsShowEveryJournalOutcomeWithoutInventingAmounts() throws {
        for outcome in [SubmittedTransaction.Outcome.pending, .succeeded, .failed, .notIncluded] {
            let model = model(SubmittedTransaction(base: base(status: outcome.status), outcome: outcome))
            XCTAssertEqual(try header(model).firstBalanceText.string, outcome.explanation)
            XCTAssertEqual(try header(model).details.count, 2)
            XCTAssertEqual(try header(model).details.first?.assetAmountText.text, outcome.status.title)
        }
    }
    private func confirmation(_ byte: UInt8, success: Bool = true) -> TransactionSubscriptionResult {
        TransactionSubscriptionResult(processingResult: ExtrinsicProcessingResult(
            extrinsic: Extrinsic(signature: nil, call: .dictionaryValue([:])), callPath: CallCodingPath(moduleName: "Assets", callName: "transfer"),
            fee: nil, peerId: nil, isSuccess: success), extrinsicHash: Data([byte]), blockNumber: 10, txIndex: UInt16(byte))
    }
    func testMatchingConfirmationCanAppearLaterInABatch() throws {
        let model = model(transfer(.outcoming, status: .pending))
        let view = PresentationView(); model.view = view
        model.processNewTransaction(event: .init(items: [confirmation(2), confirmation(1, success: false)]))
        XCTAssertEqual(try header(model).details.first?.assetAmountText.text, TransactionBase.Status.failed.title)
        XCTAssertEqual(view.updates, 1)
    }
    func testConfirmedStatusSurvivesAContentRebuild() throws {
        let model = model(transfer(.outcoming, status: .pending))
        model.processNewTransaction(event: .init(items: [confirmation(1)]))
        model.updateContent { _ in }
        XCTAssertEqual(try header(model).details.first?.assetAmountText.text, TransactionBase.Status.success.title)
    }
    func testUnrelatedConfirmationDoesNotChangePendingPresentation() throws {
        let model = model(transfer(.outcoming, status: .pending))
        let view = PresentationView(); model.view = view
        model.processNewTransaction(event: .init(items: [confirmation(2)]))
        XCTAssertEqual(try header(model).details.first?.assetAmountText.text, TransactionBase.Status.pending.title)
        XCTAssertEqual(view.updates, 0)
    }
    func testActivityDetailsCellRebindsRowsAndCopiesTheCurrentValue() {
        let cell = ActivityDetailsCell(style: .default, reuseIdentifier: nil)
        var copied: [String] = []
        let first = ActivityDetailsItem(detailViewModels: [ActivityDetailViewModel(title: "Old", value: "old")])
        let current = ActivityDetailsItem(detailViewModels: [ActivityDetailViewModel(title: "Hash", value: "current")])
        current.copyToClipboardHander = { copied.append($0) }
        cell.set(item: first, context: nil); cell.set(item: current, context: nil)
        func descendants(_ view: UIView) -> [ActivityDetailView] { ((view as? ActivityDetailView).map { [$0] } ?? []) + view.subviews.flatMap(descendants) }
        let rows = descendants(cell)
        XCTAssertEqual(rows.count, 1); XCTAssertEqual(rows.first?.valueLabel.text, "current")
        rows.first?.sendActions(for: .touchUpInside)
        XCTAssertEqual(copied, ["current"])
    }
}
private final class PresentationView: UIViewController, ActivityDetailsViewProtocol {
    var controller: UIViewController { self }
    var updates = 0
    func update(items: [SoramitsuTableViewItemProtocol]) { updates += 1 }
}
private final class PresentationAssets: AssetManagerProtocol {
    static var networkAssets: [AssetInfo] = []
    let assets = [AssetInfo(id: WalletAssetId.xor.rawValue, symbol: "XOR", chainId: "", precision: 18, icon: nil, displayName: "SORA", visible: true),
                  AssetInfo(id: WalletAssetId.val.rawValue, symbol: "VAL", chainId: "", precision: 18, icon: nil, displayName: "Validator", visible: true)]
    func assetInfo(for identifier: String) -> AssetInfo? { assets.first { $0.assetId == identifier } }
    func getAssetList() -> [AssetInfo]? { assets }
    func updateAssetList(_ list: [AssetInfo]) {}
    func saveAssetList(_ list: [AssetInfo]) {}
    func sortedAssets(_ list: [WalletAsset], onlyVisible: Bool) -> [WalletAsset] { list }
    func visibleCount() -> UInt { UInt(assets.count) }
    func setup(for accountSettings: SelectedWalletSettings) {}
}
private final class PresentationLPFee: LPFeeServiceProtocol { func getLpfee(with dexId: UInt32) -> String { "0.3%" } }
private final class PresentationHistory: HistoryServiceProtocol {
    func getHistory(count: Int, assetId: String?, completion: @escaping (Result<[Transaction], Error>) -> Void) { completion(.success([])) }
    func getPageHistory(count: Int, page: Int, assetId: String?, completion: @escaping (Result<HistoryPage, Error>) -> Void) { XCTFail("Details unexpectedly requested history") }
    func getTransaction(by txHash: String) -> Transaction? { nil }
    func getHistory(count: Int, assetId: String?) async throws -> [Transaction] { [] }
    func getPageHistory(count: Int, page: Int, assetId: String?) async throws -> HistoryPage { throw CancellationError() }
}

@MainActor
final class ActivityDetailsInteractionCoverageTests: RootActionFixtureTests {
    private func base(status: TransactionBase.Status = .success, hash: String = "0x01") -> TransactionBase {
        TransactionBase(txHash: hash, blockHash: "block", fee: Amount(value: 1_000_000_000_000_000_000), status: status, timestamp: "1700000000")
    }
    private func transfer(status: TransactionBase.Status = .success) -> TransferTransaction {
        TransferTransaction(base: base(status: status), amount: Amount(value: 3), peer: "peer", transferType: .outcoming, tokenId: WalletAssetId.xor.rawValue)
    }
    private func model(_ transaction: Transaction, factory: ActivityDetailsViewModelFactoryProtocol? = nil,
                       outcome: @escaping (String) -> SubmittedTransaction.Outcome? = { _ in nil }) -> (ActivityDetailsViewModel, ActivityAlertRecorder, ActivityDismissRecorder) {
        let assets = PresentationAssets(), wireframe = ActivityAlertRecorder(), view = ActivityDismissRecorder()
        let model = ActivityDetailsViewModel(model: transaction, wireframe: wireframe, assetManager: assets,
            detailsFactory: factory ?? ActivityDetailsViewModelFactory(assetManager: assets), historyService: PresentationHistory(), lpServiceFee: PresentationLPFee(), journalOutcome: outcome)
        model.view = view; model.updateContent { _ in }
        return (model, wireframe, view)
    }
    private func networkFee(_ transaction: Transaction) throws {
        let (model, route, view) = model(transaction)
        let header = try XCTUnwrap(model.items.compactMap { $0 as? HeaderActivityDetailsItem }.first)
        try XCTUnwrap(header.details.last?.infoHandler)()
        XCTAssertEqual(route.messages.count, 1)
        XCTAssertEqual(route.messages[0].0, R.string.localizable.polkaswapNetworkFeeInfo(preferredLanguages: ["en"]))
        XCTAssertEqual(route.messages[0].1, R.string.localizable.networkFee(preferredLanguages: ["en"]))
        XCTAssertEqual(route.messages[0].2, R.string.localizable.commonOk(preferredLanguages: ["en"]))
        XCTAssertTrue(route.sender === view)
    }
    func testTransferFeeActionExplainsTheActualNetworkCharge() throws { try networkFee(transfer()) }
    func testSwapFeeActionUsesTheSameNetworkFeeExplanation() throws {
        try networkFee(Swap(base: base(), fromTokenId: WalletAssetId.xor.rawValue, toTokenId: WalletAssetId.val.rawValue, fromAmount: Amount(value: 2), toAmount: Amount(value: 3), market: .xyk))
    }
    func testLiquidityFeeActionRemainsAvailableAfterPoolWithdrawal() throws {
        try networkFee(Liquidity(base: base(), firstTokenId: WalletAssetId.xor.rawValue, secondTokenId: WalletAssetId.val.rawValue, firstAmount: Amount(value: 2), secondAmount: Amount(value: 3), type: .withdraw))
    }
    func testReferralBondFeeActionUsesTheNetworkChargeExplanation() throws {
        try networkFee(ReferralBondTransaction(base: base(), amount: Amount(value: 3), tokenId: WalletAssetId.xor.rawValue, type: .bond))
    }
    func testClaimRewardFeeActionUsesTheNetworkChargeExplanation() throws {
        try networkFee(ClaimReward(base: base(), amount: Amount(value: 3), peer: "beneficiary", rewardTokenId: WalletAssetId.val.rawValue))
    }
    func testFarmLiquidityFeeActionUsesTheNetworkChargeExplanation() throws {
        try networkFee(FarmLiquidity(base: base(), firstTokenId: WalletAssetId.xor.rawValue, secondTokenId: WalletAssetId.val.rawValue, rewardTokenId: WalletAssetId.val.rawValue, amount: Amount(value: 3), sender: "farmer", type: .add))
    }
    func testSwapLiquidityFeeCallbackExplainsTheLiquidityCharge() throws {
        let factory = ActivityFeeCaptureFactory()
        let swap = Swap(base: base(), fromTokenId: WalletAssetId.xor.rawValue, toTokenId: WalletAssetId.val.rawValue, fromAmount: Amount(value: 2), toAmount: Amount(value: 3), market: .xyk)
        let active = model(swap, factory: factory)
        try XCTUnwrap(factory.liquidityFee)()
        XCTAssertEqual(active.1.messages.last?.0, R.string.localizable.polkaswapLiquidityTotalFeeDesc(preferredLanguages: ["en"]))
        XCTAssertEqual(active.1.messages.last?.1, R.string.localizable.polkaswapLiquidityTotalFee(preferredLanguages: ["en"]))
        XCTAssertTrue(active.1.sender === active.2)
    }
    func testClosingTheDetailsRunsTheCallerCompletionExactlyOnce() {
        let (model, _, view) = model(transfer()); var completions = 0
        model.completion = { completions += 1 }; model.dismiss()
        XCTAssertEqual(view.dismissals, 1); XCTAssertEqual(view.animated, true); XCTAssertEqual(completions, 1)
    }
    func testTheFooterCloseActionUsesTheSameDismissalCompletion() throws {
        let (model, _, view) = model(transfer()); var completions = 0
        model.completion = { completions += 1 }
        let footer = try XCTUnwrap(model.items.last as? SoramitsuButtonItem)
        XCTAssertEqual(footer.title.text, R.string.localizable.commonClose(preferredLanguages: ["en"]))
        try XCTUnwrap(footer.handler)()
        XCTAssertEqual(view.dismissals, 1); XCTAssertEqual(completions, 1)
    }
    func testUnknownTransactionStillHasAnAccessibleCloseAction() {
        let (model, _, _) = model(ActivityUnknownTransaction(base: base()))
        XCTAssertEqual(model.items.count, 1); XCTAssertTrue(model.items[0] is SoramitsuButtonItem)
    }
    func testUnavailableViewDoesNotInvokeCompletionPrematurely() {
        let (model, _, _) = model(transfer()); var completions = 0
        model.view = nil; model.completion = { completions += 1 }; model.dismiss()
        XCTAssertEqual(completions, 0)
    }
    func testCopyActionCopiesTheExactUntruncatedIdentifier() async throws {
        var value: ActivityDetailsViewModel? = model(transfer()).0
        let details = try XCTUnwrap(value?.items.compactMap { $0 as? ActivityDetailsItem }.first)
        details.copyToClipboardHander?("0x0123456789abcdef")
        XCTAssertEqual(UIPasteboard.general.string, "0x0123456789abcdef")
        value = nil; await settle()
    }
    func testPendingResolutionWithNoHeaderDoesNotInventDisplayRows() async {
        let (model, _, view) = model(ActivityUnknownTransaction(base: base(status: .pending)), outcome: { _ in .failed })
        model.processPendingSubmissionsResolved(event: Sora2PendingSubmissionsResolved())
        await wait { model.model.base.status == .failed }
        XCTAssertEqual(model.items.count, 1); XCTAssertEqual(view.updates, 0)
    }
    func testAlreadyFinalTransactionDoesNotConsultThePendingJournal() async {
        var reads = 0
        let (model, _, view) = model(transfer(), outcome: { _ in reads += 1; return .failed })
        model.processPendingSubmissionsResolved(event: Sora2PendingSubmissionsResolved()); await settle()
        XCTAssertEqual(reads, 0); XCTAssertEqual(view.updates, 0); XCTAssertEqual(model.model.base.status, .success)
    }
    func testPendingTransactionWithoutHashDoesNotConsultTheJournal() async {
        var reads = 0
        let (model, _, view) = model(ActivityUnknownTransaction(base: base(status: .pending, hash: "")), outcome: { _ in reads += 1; return .failed })
        model.processPendingSubmissionsResolved(event: Sora2PendingSubmissionsResolved()); await settle()
        XCTAssertEqual(reads, 0); XCTAssertEqual(view.updates, 0)
    }
    func testMissingSelectedAccountHasNoJournalOutcome() {
        let prior = SelectedWalletSettings.shared.currentAccount
        defer { SelectedWalletSettings.shared.commitInternalValue(prior) }
        SelectedWalletSettings.shared.commitInternalValue(nil)
        XCTAssertNil(ActivityDetailsViewModel.journalOutcome(transactionHash: "public-no-account-fixture"))
    }
}

@MainActor
final class ActivityDetailsScreenCoverageTests: RootActionFixtureTests {
    private func open(_ items: [SoramitsuTableViewItemProtocol] = []) -> (ActivityDetailsViewController, ActivityScreenModel, UINavigationController) {
        let model = ActivityScreenModel(); model.items = items
        let controller = ActivityDetailsViewController(viewModel: model)
        let navigation = UINavigationController(rootViewController: controller); mount(navigation)
        return (controller, model, navigation)
    }
    private func table(_ controller: UIViewController) throws -> SoramitsuTableView {
        try XCTUnwrap(all(SoramitsuTableView.self, controller.view).first)
    }
    func testLoadingRequestsTheDetailsExactlyOnceAndKeepsLargeNavigationTitles() throws {
        let (controller, model, navigation) = open(); controller.loadViewIfNeeded()
        XCTAssertEqual(model.requests, 1); XCTAssertTrue(navigation.navigationBar.prefersLargeTitles)
        XCTAssertTrue(try table(controller).scrollViewDelegate === controller)
    }
    func testInitialRowsKeepTheViewModelOrderAndIdentity() throws {
        let first = SoramitsuTableViewSpacerItem(space: 10), second = SoramitsuTableViewSpacerItem(space: 20)
        let (controller, _, _) = open([first, second]), table = try table(controller)
        XCTAssertEqual(table.numberOfRows(inSection: 0), 2)
        XCTAssertTrue(table.sora.sections.first?.rows.first === first)
        XCTAssertTrue(table.sora.sections.first?.rows.last === second)
    }
    func testTableFillsTheDetailsViewportAndKeepsBottomBreathingRoom() throws {
        let (controller, _, _) = open(); window.layoutIfNeeded(); controller.view.layoutIfNeeded()
        let table = try table(controller)
        XCTAssertEqual(table.frame, controller.view.bounds); XCTAssertEqual(table.contentInset.bottom, 30)
        XCTAssertGreaterThan(table.bounds.width, 0)
    }
    func testRefreshingAnExistingRowDisplaysItsCurrentValuesOnTheMainQueue() async throws {
        let item = ActivityDetailsItem(detailViewModels: [ActivityDetailViewModel(title: "Hash", value: "old")])
        let (controller, _, _) = open([item]), table = try table(controller)
        item.detailViewModels = [ActivityDetailViewModel(title: "Hash", value: "confirmed")]
        controller.update(items: [item]); await settle(); table.layoutIfNeeded()
        XCTAssertTrue(table.sora.sections.first?.rows.first === item)
        let cell = try XCTUnwrap(table.cellForRow(at: IndexPath(row: 0, section: 0)))
        XCTAssertEqual(all(ActivityDetailView.self, cell).first?.valueLabel.text, "confirmed")
    }
    func testAnEmptyRefreshKeepsTheUnchangedActivityRows() async throws {
        let item = SoramitsuTableViewSpacerItem(space: 10)
        let (controller, _, _) = open([item])
        controller.update(items: []); await settle()
        let table = try table(controller)
        XCTAssertEqual(table.numberOfRows(inSection: 0), 1)
        XCTAssertTrue(table.sora.sections.first?.rows.first === item)
    }
}

private struct ActivityUnknownTransaction: Transaction { var base: TransactionBase }
private final class ActivityAlertRecorder: ActivityDetailsWireframeProtocol {
    var messages = [(String?, String?, String?)]()
    weak var sender: UIViewController?
    func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?) {
        messages.append((message, title, closeAction)); sender = view?.controller
    }
}
private final class ActivityDismissRecorder: UIViewController, ActivityDetailsViewProtocol {
    var controller: UIViewController { self }
    var dismissals = 0, updates = 0
    var animated: Bool?
    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        dismissals += 1; animated = flag; completion?()
    }
    func update(items: [SoramitsuTableViewItemProtocol]) { updates += 1 }
}
private final class ActivityScreenModel: ActivityDetailsViewModelProtocol {
    var requests = 0, dismissals = 0
    var items = [SoramitsuTableViewItemProtocol]()
    func updateContent(completion: ([SoramitsuTableViewItemProtocol]) -> Void) { requests += 1; completion(items) }
    func dismiss() { dismissals += 1 }
}
private final class ActivityFeeCaptureFactory: ActivityDetailsViewModelFactoryProtocol {
    var networkFee: (() -> Void)?, liquidityFee: (() -> Void)?
    func createHeaderActivityDetailsViewModels(transactionBase: TransactionBase, isHideFeeDetails: Bool, tapHandler: (() -> Void)?) -> [DetailViewModel] { networkFee = tapHandler; return [] }
    func createHeaderSwapActivityDetailsViewModels(transaction: Swap, networkFeeTapHandler: (() -> Void)?, lpFeeTapHandler: (() -> Void)?) -> [DetailViewModel] { networkFee = networkFeeTapHandler; liquidityFee = lpFeeTapHandler; return [] }
}

@MainActor
final class ActivityListInteractionCoverageTests: XCTestCase {
    private func transaction(_ index: Int = 1) -> Transaction {
        TransferTransaction(base: TransactionBase(txHash: "hash-\(index)", blockHash: "block", fee: Amount(value: 1),
            status: .success, timestamp: "1700000000"), amount: Amount(value: 2), peer: "recipient",
            transferType: .outcoming, tokenId: WalletAssetId.xor.rawValue)
    }
    private func wait(_ condition: () -> Bool) async {
        for _ in 0..<200 {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTAssertTrue(condition())
    }
    private func fixture(_ pages: [HistoryPage]) -> ActivityListFixture {
        ActivityListFixture(pages: pages)
    }
    func testErrorOnlyFirstPageClearsShimmersAndShowsRetryContent() async {
        let f = fixture([HistoryPage(transactions: [], endReached: true, errorMessage: "offline")])
        f.model.viewDidLoad()
        await wait { f.errors == 1 }
        XCTAssertTrue(f.model.sections.isEmpty)
        XCTAssertEqual(f.model.snapshot.numberOfItems, 0)
        XCTAssertEqual(f.model.pageNumber, 0)
        XCTAssertTrue(f.model.isBehind)
        XCTAssertEqual(f.view.animationStops, 1)
    }
    func testPartialFirstPageKeepsTransactionAlongsideRetryAndSpacer() async {
        let f = fixture([HistoryPage(transactions: [transaction()], endReached: true, errorMessage: "partial")])
        f.model.viewDidLoad(); await wait { f.model.pageNumber == 1 }
        let rows = f.model.sections.flatMap(\.items)
        XCTAssertEqual(rows.filter(\.isActivity).count, 1)
        XCTAssertEqual(rows.count, 3)
        guard case .error = rows.first, case .space = rows.last else { return XCTFail("Partial history must keep retry and bottom spacing") }
        XCTAssertEqual(f.hiddenErrors, 1)
        XCTAssertTrue(f.model.isBehind)
    }
    func testPartialPageRetryResetsTheVisibleListThroughItsView() async {
        let f = fixture([HistoryPage(transactions: [transaction()], endReached: true, errorMessage: "partial")])
        f.model.viewDidLoad(); await wait { f.model.pageNumber == 1 }
        let retry = f.model.sections.flatMap(\.items).first { if case .error = $0 { return true }; return false }
        if let retry { f.model.didSelect(with: retry) } else { XCTFail("Missing retry action") }
        XCTAssertEqual(f.view.resets, 1)
    }
    func testTransactionTapRoutesTheExactModelAndAssetManager() async {
        let tx = transaction(); let f = fixture([HistoryPage(transactions: [tx], endReached: true)])
        f.model.viewDidLoad(); await wait { f.model.pageNumber == 1 }
        let row = f.model.sections.flatMap(\.items).first { $0.isActivity }!
        f.model.didSelect(with: row)
        XCTAssertEqual(f.routes.transactions.map { $0.base.txHash }, [tx.base.txHash])
        XCTAssertTrue(f.routes.controller === f.view)
        XCTAssertTrue(f.routes.manager === f.assets)
    }
    func testTransactionTapAfterViewDetachesDoesNotPresent() async {
        let f = fixture([HistoryPage(transactions: [transaction()], endReached: true)])
        f.model.viewDidLoad(); await wait { f.model.pageNumber == 1 }
        f.model.view = nil
        f.model.didSelect(with: f.model.sections.flatMap(\.items).first { $0.isActivity }!)
        XCTAssertTrue(f.routes.transactions.isEmpty)
    }
    func testInformationalRowsCannotOpenDetailsOrRetry() {
        let f = fixture([])
        f.model.didSelect(with: .notice(ActivityNoticeItem(text: "Informational")))
        f.model.didSelect(with: .space(SoramitsuTableViewSpacerItem(space: 30)))
        XCTAssertTrue(f.routes.transactions.isEmpty); XCTAssertEqual(f.view.resets, 0)
    }
    func testMissingRowHandlersAreSafeToSelect() {
        let f = fixture([])
        f.model.didSelect(with: .activity(ActivityItem(model: ActivityContentViewModel(txHash: "orphan"))))
        f.model.didSelect(with: .error(ActivityErrorItem()))
        XCTAssertTrue(f.routes.transactions.isEmpty); XCTAssertEqual(f.view.resets, 0)
    }
    func testCreatedTransactionEventRestartsPaginationOnMain() async {
        let f = fixture([])
        f.model.processNewTransactionCreated(event: NewTransactionCreatedEvent(item: transaction()))
        await wait { f.view.resets == 1 }
        XCTAssertTrue(f.history.requests.isEmpty)
    }
    func testConfirmedTransactionEventRestartsPaginationOnMain() async {
        let f = fixture([])
        f.model.processNewTransaction(event: WalletNewTransactionInserted(items: []))
        await wait { f.view.resets == 1 }
        XCTAssertTrue(f.history.requests.isEmpty)
    }
    func testErrorOnLaterPageKeepsTheFirstPageAndItsDate() async {
        let f = fixture([HistoryPage(transactions: [transaction()], endReached: false),
            HistoryPage(transactions: [transaction(2)], endReached: true, errorMessage: "partial")])
        f.model.viewDidLoad(); await wait { f.model.pageNumber == 1 }
        f.model.updateContent(); await wait { f.model.pageNumber == 2 }
        XCTAssertEqual(f.model.sections.flatMap(\.items).filter(\.isActivity).count, 2)
        XCTAssertTrue(f.model.sections.contains { $0.date == "1700000000" })
        XCTAssertEqual(f.history.requests, [1, 2])
    }
    func testPartialPageAfterLargeListStillHasBottomSpacing() async {
        let f = fixture([HistoryPage(transactions: (1...40).map(transaction), endReached: false),
            HistoryPage(transactions: [transaction(41)], endReached: true, errorMessage: "partial")])
        f.model.viewDidLoad(); await wait { f.model.pageNumber == 1 }
        f.model.updateContent(); await wait { f.model.pageNumber == 2 }
        XCTAssertEqual(f.model.sections.flatMap(\.items).filter(\.isActivity).count, 41)
        XCTAssertTrue(f.model.sections.flatMap(\.items).contains { if case .space = $0 { return true }; return false })
    }
    private func descendants<T: UIView>(_ type: T.Type, _ view: UIView) -> [T] {
        ((view as? T).map { [$0] } ?? []) + view.subviews.flatMap { descendants(type, $0) }
    }
    func testRetryCellRebindingRestoresDefaultTitleAndCurrentHandler() throws {
        let cell = ActivityErrorCell(style: .default, reuseIdentifier: nil)
        let old = ActivityErrorItem(title: "Saved yesterday"), current = ActivityErrorItem()
        var oldTaps = 0, newTaps = 0
        old.handler = { oldTaps += 1 }; current.handler = { newTaps += 1 }
        cell.set(item: old)
        let errorView = try XCTUnwrap(descendants(ErrorView.self, cell).first)
        XCTAssertEqual(errorView.titleLabel.sora.text, "Saved yesterday")
        cell.set(item: current)
        XCTAssertEqual(errorView.titleLabel.sora.text, R.string.localizable.activityDataNotUpToDateTitle(preferredLanguages: .currentLocale))
        // This control dispatches its public Soramitsu pressed state, rather than UIKit targets.
        errorView.button.sora.update(to: .pressed, animated: false)
        XCTAssertEqual(oldTaps, 0); XCTAssertEqual(newTaps, 1)
    }
    func testNoticeCellRebindingUpdatesVisibleAndAccessibleText() throws {
        let cell = ActivityNoticeCell(style: .default, reuseIdentifier: nil)
        cell.set(item: ActivityNoticeItem(text: "Old notice", roundsTop: false))
        cell.set(item: ActivityNoticeItem(text: "Current notice", roundsTop: true))
        XCTAssertEqual(cell.accessibilityLabel, "Current notice")
        XCTAssertEqual(try XCTUnwrap(descendants(SoramitsuLabel.self, cell).first).sora.text, "Current notice")
    }
}

@MainActor private final class ActivityListFixture {
    let view = ActivityListView(), assets = PresentationAssets(), routes = ActivityListRoutes()
    let history: ActivityListHistory
    let events = ActivityListEvents()
    var errors = 0, hiddenErrors = 0
    lazy var model: ActivityViewModel = {
        let m = ActivityViewModel(historyService: history, viewModelFactory: ActivityListFactory(), wireframe: routes,
            assetManager: assets, eventCenter: events, notificationCenter: NotificationCenter(), refreshDelay: { _ in 3_600 })
        m.view = view
        m.setupErrorContent = { [weak self] in self?.errors += 1 }
        m.hideErrorContent = { [weak self] in self?.hiddenErrors += 1 }
        return m
    }()
    init(pages: [HistoryPage]) { history = ActivityListHistory(pages: pages) }
}
private final class ActivityListHistory: HistoryServiceProtocol {
    let pages: [HistoryPage]; var requests = [Int]()
    init(pages: [HistoryPage]) { self.pages = pages }
    func getHistory(count: Int, assetId: String?, completion: @escaping (Result<[Transaction], Swift.Error>) -> Void) { completion(.success([])) }
    func getPageHistory(count: Int, page: Int, assetId: String?, completion: @escaping (Result<HistoryPage, Swift.Error>) -> Void) { XCTFail("Unexpected callback API") }
    func getTransaction(by txHash: String) -> Transaction? { nil }
    func getHistory(count: Int, assetId: String?) async throws -> [Transaction] { [] }
    func getPageHistory(count: Int, page: Int, assetId: String?) async throws -> HistoryPage {
        requests.append(page)
        guard pages.indices.contains(page - 1) else { throw CancellationError() }
        return pages[page - 1]
    }
}
private final class ActivityListFactory: ActivityViewModelFactoryProtocol {
    var currentDate: Date?
    func createActivityViewModels(with transactions: [Transaction], tapHandler: @escaping (Transaction) -> Void) -> [ActivitySection] {
        transactions.isEmpty ? [] : [ActivitySection(date: "1700000000", items: transactions.map { tx in
            let item = ActivityItem(model: ActivityContentViewModel(txHash: tx.base.txHash))
            item.handler = { tapHandler(tx) }; return .activity(item)
        })]
    }
    func createActivityShimmerModels() -> [ActivitySection] { [ActivitySection(items: [.space(SoramitsuTableViewSpacerItem(space: 50))])] }
    func createActivityViewModel(with transaction: Transaction) -> ActivityContentViewModel? { ActivityContentViewModel(txHash: transaction.base.txHash) }
}
private final class ActivityListEvents: EventCenterProtocol {
    func notify(with event: EventProtocol) {}
    func notify(with event: EventProtocol, completionOnMain: @escaping () -> Void) { completionOnMain() }
    func add(observer: EventVisitorProtocol, dispatchIn: DispatchQueue?) {}
    func remove(observer: EventVisitorProtocol) {}
}
private final class ActivityListView: UIViewController, ActivityViewProtocol {
    var resets = 0, animationStops = 0
    func stopAnimating() { animationStops += 1 }
    func resetPagination() { resets += 1 }
    func startPaginationLoader() {}
    func stopPaginationLoader() {}
}
private final class ActivityListRoutes: ActivityWireframeProtocol {
    var transactions = [Transaction](), controller: UIViewController?, manager: AssetManagerProtocol?
    func showActivityDetails(on controller: UIViewController?, model: Transaction, assetManager: AssetManagerProtocol) {
        transactions.append(model); self.controller = controller; manager = assetManager
    }
}
