// SPDX-License-Identifier: Apache-2.0
import SoraUIKit
import UIKit
import XCTest
@testable import SoraPassport

private let homeXor = "0x0200000000000000000000000000000000000000000000000000000000000000"
private let homeVal = "0x0200040000000000000000000000000000000000000000000000000000000000"

/// The Wallet home at launch: saved balances at once, real rows before any
/// read, no skeleton bars, no total until every balance is known, and no
/// "checking keys" line under the account name.
@MainActor
final class WalletHomeLoadingTests: XCTestCase {
    private func balance(_ id: String, _ value: Int) -> BalanceData {
        BalanceData(identifier: id, balance: AmountDecimal(value: Decimal(value)))
    }

    private func assets() -> [AssetInfo] {
        [
            AssetInfo(id: homeXor, symbol: "XOR", chainId: "", precision: 18, icon: nil, displayName: "SORA", visible: true),
            AssetInfo(id: homeVal, symbol: "VAL", chainId: "", precision: 18, icon: nil, displayName: "SORA Validator Token", visible: true),
        ]
    }

    private func views<T: UIView>(_ type: T.Type, in view: UIView) -> [T] {
        ((view as? T).map { [$0] } ?? []) + view.subviews.flatMap { views(type, in: $0) }
    }

    // MARK: - Saved balances

    func testSavedBalancesShowAtOnceAndTheFirstReadReplacesThem() {
        let provider = AssetProvider(refresh: {}, schedule: { _, _ in }, readsBalances: true)
        XCTAssertTrue(provider.isAwaitingFirstRead)

        provider.receiveSaved([balance(homeXor, 5)])
        XCTAssertEqual(provider.getBalances(with: [homeXor]).map(\.balance.decimalValue), [5])
        XCTAssertTrue(provider.isAwaitingFirstRead, "Saved balances are not a read of this run")

        provider.receive([balance(homeXor, 7)])
        XCTAssertFalse(provider.isAwaitingFirstRead)
        XCTAssertEqual(provider.getBalances(with: [homeXor]).map(\.balance.decimalValue), [7])

        provider.receiveSaved([balance(homeXor, 5)])
        XCTAssertEqual(provider.getBalances(with: [homeXor]).map(\.balance.decimalValue), [7],
                       "A late saved answer never replaces this run's read")
    }

    func testSavedBalancesAskForNoFurtherRead() {
        var timers: [TimeInterval] = []
        var refreshes = 0
        let provider = AssetProvider(refresh: { refreshes += 1 },
                                     schedule: { delay, _ in timers.append(delay) },
                                     readsBalances: true)
        provider.receiveSaved([balance(homeXor, 5)])
        XCTAssertTrue(timers.isEmpty)
        XCTAssertEqual(refreshes, 0)
    }

    func testAnEmptyFirstAnswerAsksAgainOnlyBeforeAnyRead() {
        var timers: [TimeInterval] = []
        let provider = AssetProvider(refresh: {}, schedule: { delay, _ in timers.append(delay) }, readsBalances: true)
        provider.receiveEmptyFirstAnswer()
        XCTAssertEqual(timers, [AssetProvider.retryDelays[0]])
        XCTAssertFalse(provider.isAwaitingFirstRead, "A failed first read ends the loading state while retries continue")

        provider.receive([balance(homeXor, 1)])
        timers.removeAll()
        provider.receiveEmptyFirstAnswer()
        XCTAssertTrue(timers.isEmpty)
    }

    func testFirstReadFailureEndsLoadingAndLateSavedBalancesThenFreshBalancesRecover() {
        let provider = AssetProvider(refresh: {}, schedule: { _, _ in }, readsBalances: true)
        let ids = [homeXor, homeVal]

        provider.receiveReadFailure()
        XCTAssertFalse(provider.isAwaitingFirstRead)
        XCTAssertEqual(provider.unavailableBalanceAssetIds(among: ids), Set(ids))
        XCTAssertTrue(provider.getBalances(with: ids).isEmpty)

        // The repository may finish after the failed network request.
        provider.receiveSaved([balance(homeXor, 5)])
        XCTAssertEqual(provider.getBalances(with: ids).map(\.balance.decimalValue), [5])
        XCTAssertEqual(provider.unavailableBalanceAssetIds(among: ids), [homeVal])

        provider.receive([balance(homeXor, 7), balance(homeVal, 2)])
        XCTAssertFalse(provider.isAwaitingFirstRead)
        XCTAssertTrue(provider.unavailableBalanceAssetIds(among: ids).isEmpty)
        provider.receiveSaved([balance(homeXor, 5)])
        XCTAssertEqual(provider.getBalances(with: ids).map(\.balance.decimalValue), [7, 2],
                       "Late saved data never replaces the successful fresh read")
    }

    func testFirstReadFailureKeepsBalancesAlreadyLoadedFromTheCache() {
        let provider = AssetProvider(refresh: {}, schedule: { _, _ in }, readsBalances: true)
        let ids = [homeXor, homeVal]
        provider.receiveSaved([balance(homeXor, 5), balance(homeVal, 2)])
        provider.receiveReadFailure()
        XCTAssertFalse(provider.isAwaitingFirstRead)
        XCTAssertEqual(provider.getBalances(with: ids).map(\.balance.decimalValue), [5, 2])
        XCTAssertTrue(provider.unavailableBalanceAssetIds(among: ids).isEmpty)
    }

    func testAProviderWithoutAReaderAwaitsNothing() {
        XCTAssertFalse(AssetProvider(refresh: {}, schedule: { _, _ in }).isAwaitingFirstRead)
        XCTAssertFalse(AssetProvider(assetInfos: [], makeBalanceProvider: { _ in nil }).isAwaitingFirstRead)
    }

    // MARK: - Rows

    /// A live Taira send left this row reading the old amount: its label was set only during layout, and a new amount of
    /// the same width lays nothing out. VoiceOver reads the label whenever it lands on the row.
    func testARowsVoiceOverLabelFollowsANewAmountBeforeAnyLayout() {
        let row = MainScreenAssetView()
        row.frame = CGRect(x: 0, y: 0, width: 390, height: 64)
        row.titleLabel.sora.text = "XOR · Taira"
        row.subtitleLabel.sora.text = "24,996.97 XOR"
        row.amountUpLabel.sora.text = "Testnet"
        row.amountDownLabel.sora.text = ""
        row.layoutIfNeeded()
        XCTAssertEqual(row.accessibilityLabel, "XOR · Taira, 24,996.97 XOR, Testnet")

        row.subtitleLabel.sora.text = "24,995.96 XOR"

        XCTAssertEqual(row.accessibilityLabel, "XOR · Taira, 24,995.96 XOR, Testnet")
    }

    func testPoolsCardStartsClosedWithoutPlaceholderRows() {
        let manager = HomeAssets(assets: assets())
        let pools = PoolsItemService(marketCapService: HomeMarket(), fiatService: nil,
            poolViewModelsFactory: PoolViewModelFactory(walletAssets: assets(), assetManager: manager, fiatService: nil))
        XCTAssertTrue(pools.poolViewModels.isEmpty)
        let cell = PoolsCell(style: .default, reuseIdentifier: nil)
        cell.set(item: PoolsItem(title: "Pools", service: pools), context: nil)
        XCTAssertTrue(views(MainScreenPoolView.self, in: cell).isEmpty)
        XCTAssertTrue(views(SoramitsuLabel.self, in: cell).allSatisfy { $0.sora.loadingPlaceholder.type == .none })
    }

}

private final class HomeAssets: AssetManagerProtocol {
    static var networkAssets: [AssetInfo] = []
    let assets: [AssetInfo]

    init(assets: [AssetInfo]) { self.assets = assets }

    func assetInfo(for identifier: String) -> AssetInfo? { assets.first { $0.assetId == identifier } }
    func getAssetList() -> [AssetInfo]? { assets }
    func updateAssetList(_: [AssetInfo]) {}
    func saveAssetList(_: [AssetInfo]) {}
    func sortedAssets(_ list: [WalletAsset], onlyVisible _: Bool) -> [WalletAsset] { list }
    func visibleCount() -> UInt { UInt(assets.count) }
    func setup(for _: SelectedWalletSettings) {}
}

private final class HomeMarket: MarketCapServiceProtocol {
    func getMarketCap(for _: [String]) async -> Set<MarketCapInfo> { [] }
}
