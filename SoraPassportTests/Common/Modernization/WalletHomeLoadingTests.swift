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

    private func service(_ provider: AssetProviderProtocol, prices: PriceInfoServiceProtocol = HomePrices(PriceInfo(fiatData: [], marketCapInfo: [])))
        -> AssetsItemService {
        let manager = HomeAssets(assets: assets())
        return AssetsItemService(
            marketCapService: HomeMarket(),
            fiatService: nil,
            assetViewModelsFactory: AssetViewModelFactory(walletAssets: assets(), assetManager: manager, fiatService: nil),
            assetManager: manager,
            assetProvider: provider,
            priceInfoService: prices
        )
    }

    private func views<T: UIView>(_ type: T.Type, in view: UIView) -> [T] {
        ((view as? T).map { [$0] } ?? []) + view.subviews.flatMap { views(type, in: $0) }
    }

    private func settle() async { try? await Task.sleep(nanoseconds: 80_000_000) }

    private func wait(_ what: String, until condition: () -> Bool) async {
        for _ in 0 ..< 500 where !condition() {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(condition(), what)
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
        let subject = service(provider)
        XCTAssertTrue(subject.assetViewModels.allSatisfy(\.balanceIsLoading))

        provider.receiveReadFailure()
        subject.setup()
        XCTAssertFalse(provider.isAwaitingFirstRead)
        XCTAssertEqual(provider.unavailableBalanceAssetIds(among: ids), Set(ids))
        XCTAssertTrue(provider.getBalances(with: ids).isEmpty)
        XCTAssertEqual(subject.assetViewModels.map(\.subtitle), Array(repeating: WalletUX.balanceUnavailableText, count: 2))
        XCTAssertFalse(subject.assetViewModels.contains(where: \.balanceIsLoading))

        // The repository may finish after the failed network request.
        provider.receiveSaved([balance(homeXor, 5)])
        subject.setup()
        XCTAssertEqual(provider.getBalances(with: ids).map(\.balance.decimalValue), [5])
        XCTAssertEqual(provider.unavailableBalanceAssetIds(among: ids), [homeVal])
        XCTAssertNotEqual(subject.assetViewModels[0].subtitle, WalletUX.balanceUnavailableText)
        XCTAssertEqual(subject.assetViewModels[1].subtitle, WalletUX.balanceUnavailableText)

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

    func testUnavailableBalancesNeverProduceAZeroTotalAndRecoverUsingKnownPrices() async throws {
        let provider = AssetProvider(refresh: {}, schedule: { _, _ in }, readsBalances: true)
        let fiat = [PIExactFiatData(id: homeXor, priceUsd: try PIQuantity("2"))]
        let prices = HomePrices(PriceInfo(fiatData: fiat, marketCapInfo: []))
        let subject = service(provider, prices: prices)
        provider.receiveReadFailure()
        subject.setup()

        // A failed balance read must end the total's spinner even before
        // the independent price read has answered.
        XCTAssertNil(subject.priceInfo)
        XCTAssertEqual(subject.moneyText, WalletUX.balanceUnavailableText)
        XCTAssertTrue(subject.priceIsUnavailable, "Unavailable totals use the quiet notice style")
        XCTAssertTrue(subject.priceNoteText.isEmpty)

        await wait("prices arrive without any balances") { subject.priceInfo != nil }
        XCTAssertEqual(subject.moneyText, WalletUX.balanceUnavailableText,
                       "Known prices cannot turn missing balances into a zero holding")
        XCTAssertTrue(subject.priceIsUnavailable)

        let fresh = [balance(homeXor, 5), balance(homeVal, 0)]
        provider.receive(fresh)
        subject.setup()
        XCTAssertEqual(subject.moneyText, AssetsItemService.fiatTotalText(balances: fresh, fiatData: fiat))
        XCTAssertFalse(subject.priceIsUnavailable)
        XCTAssertFalse(subject.assetViewModels.contains(where: \.balanceIsLoading))
    }

    func testAProviderWithoutAReaderAwaitsNothing() {
        XCTAssertFalse(AssetProvider(refresh: {}, schedule: { _, _ in }).isAwaitingFirstRead)
        XCTAssertFalse(AssetProvider(assetInfos: [], makeBalanceProvider: { _ in nil }).isAwaitingFirstRead)
    }

    // MARK: - Rows

    func testRowsComeFromTheAssetListBeforeAnyBalanceIsRead() {
        let subject = service(HomeBalances(awaiting: true))
        XCTAssertEqual(subject.assetViewModels.map(\.identifier), [homeXor, homeVal])
        XCTAssertTrue(subject.assetViewModels.allSatisfy(\.balanceIsLoading))
        XCTAssertEqual(subject.assetViewModels.map(\.subtitle), ["XOR", "VAL"])
        XCTAssertEqual(subject.assetViewModels.map(\.title), assets().map(\.name))
        XCTAssertEqual(subject.moneyText, "")
    }

    func testSavedBalancesFillTheirRowsAtOnce() {
        let provider = HomeBalances(awaiting: true)
        provider.balances = [balance(homeXor, 3)]
        let subject = service(provider)
        XCTAssertFalse(subject.assetViewModels[0].balanceIsLoading)
        XCTAssertTrue(subject.assetViewModels[0].subtitle.hasSuffix("XOR"))
        XCTAssertNotEqual(subject.assetViewModels[0].subtitle, "XOR")
        XCTAssertTrue(subject.assetViewModels[1].balanceIsLoading)
    }

    func testAfterTheFirstReadAnAssetWithoutABalanceIsNotShownAsLoading() {
        let provider = HomeBalances(awaiting: false)
        provider.balances = [balance(homeXor, 1)]
        let subject = service(provider)
        XCTAssertEqual(subject.assetViewModels.map(\.identifier), [homeXor])
        XCTAssertFalse(subject.assetViewModels.contains(where: \.balanceIsLoading))
    }

    func testTheTotalWaitsForEveryBalanceAndIsNeverZeroForWantOfOne() async throws {
        let provider = HomeBalances(awaiting: true)
        provider.balances = [balance(homeXor, 3)]
        let fiat = [PIExactFiatData(id: homeXor, priceUsd: try PIQuantity("2"))]
        let prices = HomePrices(PriceInfo(fiatData: fiat, marketCapInfo: []))
        let subject = service(provider, prices: prices)

        subject.setup()
        await wait("the price read") { prices.calls >= 1 && subject.assetViewModels.first?.priceLoadFinished == true }
        XCTAssertEqual(subject.moneyText, "", "VAL is still loading")
        XCTAssertFalse(subject.priceIsUnavailable)
        XCTAssertEqual(subject.priceNoteText, "")
        XCTAssertTrue(subject.assetViewModels[1].balanceIsLoading)

        provider.balances = [balance(homeXor, 3), balance(homeVal, 0)]
        provider.awaiting = false
        subject.setup()
        await wait("the total") { !subject.moneyText.isEmpty }
        XCTAssertEqual(subject.moneyText, AssetsItemService.fiatTotalText(balances: provider.balances, fiatData: fiat))
        XCTAssertFalse(subject.assetViewModels.contains(where: \.balanceIsLoading))
        withExtendedLifetime(prices) {}
    }

    // MARK: - Cells

    func testKnownPricesValueNewBalancesWithoutWaitingForThePriceRefresh() async throws {
        let provider = HomeBalances(awaiting: false)
        provider.balances = [balance(homeXor, 3), balance(homeVal, 0)]
        let fiat = [PIExactFiatData(id: homeXor, priceUsd: try PIQuantity("2"))]
        let prices = HomeHeldRefreshPrices(PriceInfo(fiatData: fiat, marketCapInfo: []))
        defer { prices.finishRefresh() }
        let subject = service(provider, prices: prices)
        subject.setup()
        await wait("initial prices") { !subject.moneyText.isEmpty }
        let initialSubtitle = subject.assetViewModels.first?.subtitle
        let initialTotal = subject.moneyText

        provider.balances = [balance(homeXor, 7), balance(homeVal, 0)]
        subject.setup()
        await wait("held price refresh") { prices.isRefreshPending }

        XCTAssertNotEqual(subject.assetViewModels.first?.subtitle, initialSubtitle,
                          "The new token balance must not wait for the price request")
        XCTAssertNotEqual(subject.moneyText, initialTotal)
        XCTAssertEqual(subject.moneyText, AssetsItemService.fiatTotalText(balances: provider.balances, fiatData: fiat),
                       "Known prices should value the new balances while the refresh is pending")
    }

    func testAssetsCardDrawsNoSkeletonAndAQuietSpinnerUntilTheTotalIsKnown() async throws {
        let provider = HomeBalances(awaiting: true)
        let subject = service(provider)
        let item = AssetsItem(title: "Assets", assetProvider: provider, service: subject)
        let cell = AssetsCell(style: .default, reuseIdentifier: nil)
        cell.set(item: item, context: nil)
        await settle()

        let rows = views(MainScreenAssetView.self, in: cell)
        XCTAssertEqual(rows.count, 2)
        for row in rows {
            XCTAssertEqual(row.assetImageView.sora.loadingPlaceholder.type, .none)
            for label in [row.titleLabel, row.subtitleLabel, row.amountUpLabel, row.amountDownLabel] {
                XCTAssertEqual(label.sora.loadingPlaceholder.type, .none)
            }
        }
        XCTAssertEqual(rows.map(\.subtitleLabel.text), ["XOR", "VAL"])
        XCTAssertTrue(views(SoramitsuLabel.self, in: cell).allSatisfy { $0.sora.loadingPlaceholder.type == .none })

        let spinner = try XCTUnwrap(views(UIActivityIndicatorView.self, in: cell)
            .first { $0.accessibilityIdentifier == "wallet.assets.total-loading" })
        XCTAssertTrue(spinner.isAnimating)
        subject.moneyText = "$6"
        await settle()
        XCTAssertFalse(spinner.isAnimating)
        XCTAssertTrue(views(UILabel.self, in: cell).contains { $0.text == "$6" })
    }

    func testABalanceThatArrivesUpdatesTheSameRowAndItsTapOpensOnlyThatAsset() async throws {
        let provider = HomeBalances(awaiting: true)
        let subject = service(provider)
        let item = AssetsItem(title: "Assets", assetProvider: provider, service: subject)
        var opened: [String] = []
        item.assetHandler = { opened.append($0) }
        let cell = AssetsCell(style: .default, reuseIdentifier: nil)
        cell.set(item: item, context: nil)
        await settle()
        let before = views(MainScreenAssetView.self, in: cell)

        provider.balances = [balance(homeXor, 3)]
        subject.setup()
        await settle()
        cell.set(item: item, context: nil)
        await settle()

        let after = views(MainScreenAssetView.self, in: cell)
        XCTAssertEqual(after.count, 2)
        XCTAssertTrue(zip(before, after).allSatisfy { $0 === $1 }, "Rows are updated in place, not rebuilt")
        XCTAssertNotEqual(after[0].subtitleLabel.text, "XOR")
        XCTAssertEqual(after[1].subtitleLabel.text, "VAL")
        after[0].sendActions(for: .touchUpInside)
        XCTAssertEqual(opened, [homeXor], "Updates must not pile up row handlers")
    }

    func testReusingTheCardForAnotherWalletClearsPreviousValuesBeforePricesArrive() async throws {
        let firstProvider = HomeBalances(awaiting: false)
        firstProvider.balances = [balance(homeXor, 3), balance(homeVal, 0)]
        let firstService = service(firstProvider)
        firstService.assetViewModels[0].fiatText = "$6"
        firstService.assetViewModels[0].deltaPriceText = SoramitsuTextItem(
            text: "+2%", fontData: FontType.textM, textColor: .statusSuccess)
        firstService.assetViewModels[0].priceLoadFinished = true
        firstService.moneyText = "$6"
        firstService.priceNoteText = "Previous wallet quote"
        let firstItem = AssetsItem(title: "Assets", assetProvider: firstProvider, service: firstService)
        var firstOpened: [String] = []
        firstItem.assetHandler = { firstOpened.append($0) }
        let cell = AssetsCell(style: .default, reuseIdentifier: nil)
        cell.set(item: firstItem, context: nil)
        await settle()
        XCTAssertEqual(views(MainScreenAssetView.self, in: cell).first?.amountUpLabel.text, "$6")

        let nextProvider = HomeBalances(awaiting: true)
        let nextService = service(nextProvider)
        let nextItem = AssetsItem(title: "Assets", assetProvider: nextProvider, service: nextService)
        var nextOpened: [String] = []
        nextItem.assetHandler = { nextOpened.append($0) }
        cell.set(item: nextItem, context: nil)

        func assertPreviousValuesAreGone() throws {
            let rows = views(MainScreenAssetView.self, in: cell)
            XCTAssertEqual(rows.map(\.subtitleLabel.text), ["XOR", "VAL"])
            for row in rows {
                XCTAssertTrue((row.amountUpLabel.text ?? "").trimmingCharacters(in: .whitespaces).isEmpty)
                XCTAssertTrue((row.amountDownLabel.text ?? "").trimmingCharacters(in: .whitespaces).isEmpty)
            }
            XCTAssertFalse(views(UILabel.self, in: cell).contains {
                $0.text == "$6" || $0.text == "Previous wallet quote"
            })
            let spinner = try XCTUnwrap(views(UIActivityIndicatorView.self, in: cell)
                .first { $0.accessibilityIdentifier == "wallet.assets.total-loading" })
            XCTAssertTrue(spinner.isAnimating)
        }
        // Check before Combine's scheduled initial emissions as well as afterward.
        try assertPreviousValuesAreGone()
        await settle()
        try assertPreviousValuesAreGone()
        views(MainScreenAssetView.self, in: cell).first?.sendActions(for: .touchUpInside)
        XCTAssertTrue(firstOpened.isEmpty)
        XCTAssertEqual(nextOpened, [homeXor])
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

    // MARK: - Account header

    func testTheKeyCheckShowsNothingUnderTheAccountName() throws {
        XCTAssertNil(WalletAccountCapability.State.checking.badge)
        XCTAssertNil(WalletAccountCapability.State.checking.reason)

        let cell = AccountCell(style: .default, reuseIdentifier: nil)
        let item = AccountTableViewItem(accountName: "Public fixture")
        item.capability = .checking
        cell.set(item: item, context: nil)
        let labels = views(UILabel.self, in: cell)
        let badge = try XCTUnwrap(labels.first { $0.accessibilityIdentifier == "wallet-selected-account-capability-badge" })
        let reason = try XCTUnwrap(labels.first { $0.accessibilityIdentifier == "wallet-selected-account-read-only-reason" })
        XCTAssertTrue(badge.isHidden)
        XCTAssertTrue(reason.isHidden)

        item.capability = .missingKeys
        cell.set(item: item, context: nil)
        XCTAssertFalse(badge.isHidden)
        XCTAssertFalse(reason.isHidden)
        XCTAssertEqual(reason.text, WalletAccountCapability.State.missingKeys.reason)
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

private final class HomeBalances: AssetProviderProtocol {
    private let lock = NSLock()
    private var storedBalances: [BalanceData] = []
    private var storedAwaiting: Bool

    init(awaiting: Bool) { storedAwaiting = awaiting }

    var balances: [BalanceData] {
        get { lock.lock(); defer { lock.unlock() }; return storedBalances }
        set { lock.lock(); storedBalances = newValue; lock.unlock() }
    }

    var awaiting: Bool {
        get { lock.lock(); defer { lock.unlock() }; return storedAwaiting }
        set { lock.lock(); storedAwaiting = newValue; lock.unlock() }
    }

    var isAwaitingFirstRead: Bool { awaiting }

    func getBalances(with assetIds: [String]) -> [BalanceData] {
        let current = balances
        return assetIds.compactMap { id in current.first { $0.identifier == id } }
    }

    func add(observer _: AssetProviderObserverProtocol) {}
    func remove(observer _: AssetProviderObserverProtocol) {}
}

private final class HomeMarket: MarketCapServiceProtocol {
    func getMarketCap(for _: [String]) async -> Set<MarketCapInfo> { [] }
}

private final class HomePrices: PriceInfoServiceProtocol {
    private let lock = NSLock()
    private let info: PriceInfo
    private var count = 0

    init(_ info: PriceInfo) { self.info = info }

    var calls: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    func getPriceInfo(for _: [String]) async -> PriceInfo {
        lock.lock()
        count += 1
        lock.unlock()
        return info
    }
}

private final class HomeHeldRefreshPrices: PriceInfoServiceProtocol {
    private let lock = NSLock()
    private let info: PriceInfo
    private var firstRead = true
    private var pending: CheckedContinuation<PriceInfo, Never>?

    init(_ info: PriceInfo) { self.info = info }

    var isRefreshPending: Bool {
        lock.lock()
        defer { lock.unlock() }
        return pending != nil
    }

    func getPriceInfo(for _: [String]) async -> PriceInfo {
        await withCheckedContinuation { continuation in
            lock.lock()
            if firstRead {
                firstRead = false
                lock.unlock()
                continuation.resume(returning: info)
            } else {
                pending = continuation
                lock.unlock()
            }
        }
    }

    func finishRefresh() {
        lock.lock()
        let continuation = pending
        pending = nil
        lock.unlock()
        continuation?.resume(returning: info)
    }
}
