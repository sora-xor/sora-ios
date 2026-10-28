// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0
import SoraFoundation
import SoraUIKit
import UIKit
import XCTest
@testable import SoraPassport

@MainActor
final class ActivityRowMappingTests: XCTestCase {
    private var language = "en"
    private let assets = ActivityRowAssets()
    private let xor = WalletAssetId.xor.rawValue
    private let val = WalletAssetId.val.rawValue
    override func setUp() { super.setUp(); language = LocalizationManager.shared.selectedLocalization; LocalizationManager.shared.selectedLocalization = "en" }
    override func tearDown() { LocalizationManager.shared.selectedLocalization = language; super.tearDown() }
    private func factory() -> ActivityViewModelFactory { ActivityViewModelFactory(walletAssets: assets.assets, assetManager: assets) }
    private func base(_ hash: String = "hash", at timestamp: String = "1700000000", status: TransactionBase.Status = .success) -> TransactionBase { TransactionBase(txHash: hash, blockHash: "block", fee: Amount(value: 1), status: status, timestamp: timestamp) }
    private func transfer(_ type: TransferTransaction.TransferType = .outcoming, token: String? = nil, hash: String = "hash", timestamp: String = "1700000000") -> TransferTransaction { TransferTransaction(base: base(hash, at: timestamp), amount: Amount(value: Decimal(string: "1.25")!), peer: "peer-address", transferType: type, tokenId: token ?? val) }
    private func swap(from: String? = nil, to: String? = nil) -> Swap { Swap(base: base(), fromTokenId: from ?? xor, toTokenId: to ?? val, fromAmount: Amount(value: 2), toAmount: Amount(value: 7), market: .xyk) }
    private func liquidity(_ type: Liquidity.TransactionLiquidityType = .add, first: String? = nil, second: String? = nil) -> Liquidity { Liquidity(base: base(), firstTokenId: first ?? xor, secondTokenId: second ?? val, firstAmount: Amount(value: 2), secondAmount: Amount(value: 7), type: type) }
    private func row(_ transaction: Transaction) throws -> ActivityContentViewModel { try XCTUnwrap(factory().createActivityViewModel(with: transaction)) }
    private func text(_ transaction: Transaction) throws -> String { try row(transaction).firstBalanceText.attributedString.string }
    func testOutgoingTransferKeepsItsExactAmountAssetAndPeer() throws { let value = try row(transfer()); XCTAssertEqual(value.firstBalanceText.attributedString.string, "1.25 VAL"); XCTAssertEqual(value.subtitle, "peer-address"); XCTAssertEqual(value.txHash, "hash"); XCTAssertFalse(value.isNeedTwoImage) }
    func testIncomingTransferAddsTheCreditMarker() throws { XCTAssertEqual(try text(transfer(.incoming)), "+ 1.25 VAL") }
    func testRTLTransferPlacesTheSymbolAndCreditMarkerInReadingOrder() throws { LocalizationManager.shared.selectedLocalization = "ar"; XCTAssertEqual(try text(transfer(.incoming)), "VAL 1.25 +"); XCTAssertEqual(try text(transfer()), "VAL 1.25") }
    func testUnknownTransferAssetIsNeverLabeledAsXor() throws { XCTAssertFalse(try text(transfer(token: "unknown-token")).contains("XOR")) }
    func testSwapKeepsEachAmountPairedWithItsAsset() throws { let value = try row(swap()); XCTAssertEqual(value.firstBalanceText.attributedString.string, "2 XOR → 7 VAL"); XCTAssertEqual(value.subtitle, "XOR → VAL"); XCTAssertTrue(value.isNeedTwoImage) }
    func testSwapAcceptsTheLegacyWrappedAssetIdentifiers() throws { XCTAssertEqual(try text(swap(from: "{\"code\":\"\(xor)\"}", to: "{\"code\":\"\(val)\"}")), "2 XOR → 7 VAL") }
    func testUnknownSwapAssetIsNeverReplacedWithTheFeeAsset() throws { let value = try row(swap(from: "unknown-first", to: "unknown-second")); XCTAssertFalse(value.firstBalanceText.attributedString.string.contains("XOR")); XCTAssertFalse(value.subtitle.contains("XOR")) }
    func testRTLSwapPreservesTheDirectionAndAmounts() throws { LocalizationManager.shared.selectedLocalization = "ar"; XCTAssertEqual(try text(swap()), "VAL 7 ← XOR 2") }
    func testLiquidityDepositKeepsFirstAndSecondAmountsWithTheirTokens() throws { XCTAssertEqual(try text(liquidity()), "2 XOR / 7 VAL") }
    func testLiquidityWithdrawalCreditsTheCorrectTokenAmounts() throws { XCTAssertEqual(try text(liquidity(.withdraw)), "+ 2 XOR / + 7 VAL") }
    func testRTLLiquidityKeepsItsTokenAmountPairs() throws { LocalizationManager.shared.selectedLocalization = "ar"; XCTAssertEqual(try text(liquidity()), "VAL 7 / XOR 2"); XCTAssertEqual(try text(liquidity(.withdraw)), "VAL 7 + / XOR 2 +") }
    func testLiquidityAcceptsWrappedIdsWithoutSwappingAmounts() throws { XCTAssertEqual(try text(liquidity(first: "{\"code\":\"\(xor)\"}", second: "{\"code\":\"\(val)\"}")), "2 XOR / 7 VAL") }
    func testUnknownLiquidityAssetsDoNotMasqueradeAsXor() throws { XCTAssertFalse(try text(liquidity(first: "unknown-first", second: "unknown-second")).contains("XOR")) }
    func testReferralBondAndUnbondPreserveAmountsAndCreditDirection() throws { for (type, expected) in [(ReferralBondTransaction.ReferralTransactionType.bond, "3 XOR"), (.unbond, "+ 3 XOR")] { XCTAssertEqual(try text(ReferralBondTransaction(base: base(), amount: Amount(value: 3), tokenId: xor, type: type)), expected) } }
    func testRTLReferralCreditUsesTheCurrentLanguageDirection() throws { LocalizationManager.shared.selectedLocalization = "ar"; XCTAssertEqual(try text(ReferralBondTransaction(base: base(), amount: Amount(value: 3), tokenId: xor, type: .unbond)), "XOR 3 +") }
    func testSetReferrerAndJoinedReferralHaveDifferentDescriptions() throws { let own = try row(SetReferrerTransaction(base: base(), who: "referrer", isMyReferrer: true, tokenId: xor)); let joined = try row(SetReferrerTransaction(base: base(), who: "joined-address", isMyReferrer: false, tokenId: xor)); XCTAssertEqual(own.firstBalanceText.attributedString.string, "--"); XCTAssertEqual(joined.subtitle, "joined-address"); XCTAssertNotEqual(own.title, joined.title); XCTAssertTrue(joined.firstBalanceText.attributedString.string.contains("1")) }
    func testRewardClaimUsesTheRewardAsset() throws { XCTAssertEqual(try text(ClaimReward(base: base(), amount: Amount(value: 4), peer: "", rewardTokenId: val)), "+ 4 VAL") }
    func testUnknownRewardDoesNotDisplayAnInventedXorCredit() throws { XCTAssertFalse(try text(ClaimReward(base: base(), amount: Amount(value: 4), peer: "", rewardTokenId: "unknown-reward")).contains("XOR")) }
    func testFarmDepositAndWithdrawalUseTheLpPairAndAmount() throws { for type in [FarmLiquidity.TransactionLiquidityType.add, .withdraw] { XCTAssertEqual(try text(FarmLiquidity(base: base(), firstTokenId: xor, secondTokenId: val, rewardTokenId: xor, amount: Amount(value: 5), sender: "sender", type: type)), "5 XOR-VAL") } }
    func testUnknownFarmAssetsDoNotBecomeAnXorPair() throws { XCTAssertFalse(try text(FarmLiquidity(base: base(), firstTokenId: "unknown-first", secondTokenId: "unknown-second", rewardTokenId: xor, amount: Amount(value: 5), sender: "sender", type: .add)).contains("XOR")) }
    func testSubmittedTransactionShowsItsOutcomeWithoutInventingAnAmount() throws { for outcome in [SubmittedTransaction.Outcome.pending, .succeeded, .failed, .notIncluded] { let value = try row(SubmittedTransaction(base: base(status: outcome.status), outcome: outcome)); XCTAssertEqual(value.subtitle, outcome.explanation); XCTAssertEqual(value.status, outcome.status); XCTAssertEqual(value.firstBalanceText.attributedString.string, "") } }
    func testUnsupportedTransactionIsNotRendered() { XCTAssertNil(factory().createActivityViewModel(with: ActivityUnknownTransaction(base: base()))) }
    func testHistoryGroupsDaysAndPreservesTapIdentity() {
        let values = [transfer(hash: "first"), transfer(hash: "second"), transfer(hash: "older", timestamp: "1699800000")]; var tapped: [String] = []
        let sections = factory().createActivityViewModels(with: values) { tapped.append($0.base.txHash) }; XCTAssertEqual(sections.count, 2); XCTAssertEqual(sections.map { $0.items.count }, [2, 1]); XCTAssertNotEqual(sections[0].date, sections[1].date)
        for section in sections { for item in section.items { if case .activity(let row) = item { row.handler?() } } }; XCTAssertEqual(tapped, ["first", "second", "older"])
    }
    func testUnsupportedRowsDoNotCreateEmptyDayHeaders() { let values: [Transaction] = [ActivityUnknownTransaction(base: base("unknown", at: "1699800000")), transfer()]; let sections = factory().createActivityViewModels(with: values) { _ in }; XCTAssertEqual(sections.count, 1); XCTAssertTrue(sections.allSatisfy { !$0.items.isEmpty }) }
    func testEmptyHistoryDoesNotInventASection() { XCTAssertTrue(factory().createActivityViewModels(with: []) { _ in }.isEmpty) }
    func testShimmerContainsUniqueRowsAndOneLeadingSpacer() { let sections = factory().createActivityShimmerModels(); XCTAssertEqual(sections.count, 2); XCTAssertEqual(sections[0].items.count, 1); XCTAssertEqual(sections[1].items.count, 20); XCTAssertEqual(Set(sections[1].items).count, 20) }
    func testActivityIdentityChangesWhenTheDisplayedAmountChanges() { let first = ActivityContentViewModel(txHash: "same", firstBalanceText: NSAttributedString(string: "1 XOR")); let next = ActivityContentViewModel(txHash: "same", firstBalanceText: NSAttributedString(string: "2 XOR")); XCTAssertNotEqual(first, next); XCTAssertEqual(Set([first, next]).count, 2) }
    func testActivityIdentityChangesWhenAnIconArrives() { let first = ActivityContentViewModel(txHash: "same"); let next = ActivityContentViewModel(txHash: "same", firstAssetImageViewModel: UIImage(systemName: "circle")); XCTAssertNotEqual(first, next); XCTAssertEqual(Set([first, next]).count, 2) }
    func testEquivalentActivityPresentationRetainsTheSameIdentity() { let first = ActivityContentViewModel(txHash: "same", firstBalanceText: NSAttributedString(string: "1 XOR")); let next = ActivityContentViewModel(txHash: "same", firstBalanceText: NSAttributedString(string: "1 XOR")); XCTAssertEqual(first, next); XCTAssertEqual(Set([first, next]).count, 1) }
}
private struct ActivityUnknownTransaction: Transaction { var base: TransactionBase }
private final class ActivityRowAssets: AssetManagerProtocol {
    static var networkAssets: [AssetInfo] = []
    let assets = [AssetInfo(id: WalletAssetId.xor.rawValue, symbol: "XOR", chainId: "", precision: 18, icon: nil, displayName: "SORA", visible: true), AssetInfo(id: WalletAssetId.val.rawValue, symbol: "VAL", chainId: "", precision: 6, icon: nil, displayName: "Validator", visible: true)]
    func assetInfo(for identifier: String) -> AssetInfo? { assets.first { $0.assetId == identifier } }; func getAssetList() -> [AssetInfo]? { assets }; func updateAssetList(_ list: [AssetInfo]) {}; func saveAssetList(_ list: [AssetInfo]) {}
    func sortedAssets(_ list: [WalletAsset], onlyVisible: Bool) -> [WalletAsset] { list }; func visibleCount() -> UInt { 2 }; func setup(for accountSettings: SelectedWalletSettings) {}
}
