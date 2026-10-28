// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause
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
