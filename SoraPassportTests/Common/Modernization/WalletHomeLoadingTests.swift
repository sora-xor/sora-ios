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

    // MARK: - Rows that arrive after the card was laid out

    private func networkRow(_ network: NetworkId, _ title: String, tag: WalletNetworkTag, isMain: Bool = false) -> NetworkAssetRow {
        NetworkAssetRow(
            account: NetworkAccount(walletId: "wallet", networkId: network, derivationVersion: 1,
                                    publicKey: Data(repeating: 3, count: 32), address: "\(network.rawValue)-address"),
            title: title, amount: "", tag: tag, icon: nil, isMain: isMain)
    }

    /// The card in a real table in a window, laid out once, as the home does
    /// before it knows about the other networks.
    private func mountCard(listing assets: [AssetInfo]) async throws -> (table: SoramitsuTableView, item: AssetsItem, service: AssetsItemService, cell: AssetsCell) {
        let provider = HomeBalances(awaiting: true)
        let manager = HomeAssets(assets: assets)
        let service = AssetsItemService(
            marketCapService: HomeMarket(),
            fiatService: nil,
            assetViewModelsFactory: AssetViewModelFactory(walletAssets: assets, assetManager: manager, fiatService: nil),
            assetManager: manager,
            assetProvider: provider,
            priceInfoService: HomePrices(PriceInfo(fiatData: [], marketCapInfo: []))
        )
        let item = AssetsItem(title: "Assets", assetProvider: provider, service: service)
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene.map(UIWindow.init(windowScene:)) ?? UIWindow(frame: UIScreen.main.bounds)
        window.frame = scene?.coordinateSpace.bounds ?? UIScreen.main.bounds
        let root = UIViewController()
        let table = SoramitsuTableView()
        table.sora.estimatedRowHeight = UITableView.automaticDimension
        root.view.addSubview(table)
        window.rootViewController = root
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        table.frame = root.view.bounds
        table.sora.sections = [SoramitsuTableViewSection(rows: [item])]
        table.layoutIfNeeded()
        addTeardownBlock {
            window.isHidden = true
            window.rootViewController = nil
        }
        // Drain the initial Combine deliveries and the sizing pass they enqueue.
        // Otherwise the baseline can still include a temporary stacked amount,
        // and its later shrink is incorrectly charged against the added rows.
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async {
                DispatchQueue.main.async { continuation.resume() }
            }
        }
        RedesignWalletViewController.refresh(items: [item], in: table)
        return (table, item, service, try XCTUnwrap(table.visibleCells.first as? AssetsCell))
    }

    private func heading(in cell: AssetsCell) throws -> UIView {
        try XCTUnwrap(views(WalletHeaderView.self, in: cell).first)
    }

    private func expand(in cell: AssetsCell) throws -> UIView {
        try XCTUnwrap(views(SoramitsuButton.self, in: cell).first)
    }

    private func networkRowView(_ network: NetworkId, in cell: AssetsCell) throws -> UIView {
        try XCTUnwrap(views(MainScreenAssetView.self, in: cell).first { $0.accessibilityIdentifier == "wallet.network-row.\(network.rawValue)" })
    }

    private func assetRowView(_ symbol: String, in cell: AssetsCell) throws -> UIView {
        try XCTUnwrap(views(MainScreenAssetView.self, in: cell).first { $0.subtitleLabel.text == symbol })
    }

    private func frame(_ view: UIView, in cell: AssetsCell) -> CGRect {
        view.convert(view.bounds, to: cell)
    }

    /// Top to bottom in this order, nothing overlapping, each with its height,
    /// and the last one ending inside the card.
    private func readsInOrder(_ order: [UIView], in cell: AssetsCell) -> Bool {
        var bottom = -CGFloat.infinity
        for view in order {
            let rect = frame(view, in: cell)
            guard rect.minY >= bottom - 1, rect.height >= 1 else { return false }
            bottom = rect.maxY
        }
        return bottom <= cell.bounds.height + 1
    }

    private func assertReadsInOrder(_ order: [UIView], in cell: AssetsCell, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0 ..< 500 where !readsInOrder(order, in: cell) {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        let frames = order.map { "\(frame($0, in: cell).minY)...\(frame($0, in: cell).maxY)" }
        XCTAssertTrue(readsInOrder(order, in: cell), "Card height \(cell.bounds.height), top to bottom: \(frames)", file: file, line: line)
    }

    /// A fresh import has no asset list yet, so the title is followed only by
    /// the hidden price note and Expand when XOR on the other networks arrives.
    /// These rows used to hang above Expand, over the title, until the list came.
    func testNetworkRowsThatArriveBeforeTheAssetListGoBelowTheTitle() async throws {
        let (table, item, _, cell) = try await mountCard(listing: [])
        let emptyHeight = cell.bounds.height

        item.networkRows = [networkRow(.minamoto, "XOR · SORA Nexus", tag: .comingSoon), networkRow(.taira, "XOR · Taira", tag: .testnet)]
        RedesignWalletViewController.refresh(items: [item], in: table)

        let title = try heading(in: cell), nexus = try networkRowView(.minamoto, in: cell)
        await assertReadsInOrder([title, nexus, try networkRowView(.taira, in: cell), try expand(in: cell)], in: cell)
        XCTAssertEqual(frame(nexus, in: cell).minY - frame(title, in: cell).maxY, 16, accuracy: 1)
        XCTAssertGreaterThanOrEqual(cell.bounds.height, emptyHeight + 2 * 64, "The card makes room for its rows")
        XCTAssertEqual(table.rectForRow(at: IndexPath(row: 0, section: 0)).height, cell.bounds.height, accuracy: 1)

        // A wallet without those networks, then one with them: the row goes in below the same title again.
        item.networkRows = []
        RedesignWalletViewController.refresh(items: [item], in: table)
        await wait("The card is empty again") { abs(cell.bounds.height - emptyHeight) <= 1 }

        item.networkRows = [networkRow(.taira, "XOR · Taira", tag: .testnet)]
        RedesignWalletViewController.refresh(items: [item], in: table)
        await assertReadsInOrder([title, try networkRowView(.taira, in: cell), try expand(in: cell)], in: cell)
        XCTAssertGreaterThanOrEqual(cell.bounds.height, emptyHeight + 64)
    }

    /// The rows of the main network go right below the title, before the SORA2
    /// rows, however long the list already is.
    func testAMainNetworkRowThatArrivesLaterGoesBetweenTheTitleAndTheAssets() async throws {
        let (table, item, _, cell) = try await mountCard(listing: assets())
        await assertReadsInOrder([
            try heading(in: cell), try assetRowView("XOR", in: cell),
            try assetRowView("VAL", in: cell), try expand(in: cell),
        ], in: cell)
        let heightWithAssets = cell.bounds.height

        item.networkRows = [networkRow(.minamoto, "XOR", tag: .main, isMain: true), networkRow(.taira, "XOR · Taira", tag: .testnet)]
        RedesignWalletViewController.refresh(items: [item], in: table)

        await assertReadsInOrder([
            try heading(in: cell), try networkRowView(.minamoto, in: cell), try assetRowView("XOR", in: cell),
            try assetRowView("VAL", in: cell), try networkRowView(.taira, in: cell), try expand(in: cell),
        ], in: cell)
        XCTAssertGreaterThanOrEqual(cell.bounds.height, heightWithAssets + 2 * 64)
    }

    func testThePriceNoteComesAndGoesBetweenTheTitleAndTheRows() async throws {
        let (table, item, service, cell) = try await mountCard(listing: [])
        item.networkRows = [networkRow(.taira, "XOR · Taira", tag: .testnet)]
        RedesignWalletViewController.refresh(items: [item], in: table)
        let title = try heading(in: cell), row = try networkRowView(.taira, in: cell), button = try expand(in: cell)
        await assertReadsInOrder([title, row, button], in: cell)
        let heightWithoutNote = cell.bounds.height

        service.priceNoteText = "Prices as of 09:02"
        await wait("The note appears") { views(SoramitsuLabel.self, in: cell).contains { $0.text == "Prices as of 09:02" && !$0.isHidden } }
        let note = try XCTUnwrap(views(SoramitsuLabel.self, in: cell).first { $0.text == "Prices as of 09:02" })
        await assertReadsInOrder([title, note, row, button], in: cell)
        XCTAssertEqual(frame(note, in: cell).minY - frame(title, in: cell).maxY, 4, accuracy: 1)
        XCTAssertEqual(frame(row, in: cell).minY - frame(note, in: cell).maxY, 16, accuracy: 1)

        service.priceNoteText = ""
        await wait("The note's space goes with it") { note.isHidden && abs(cell.bounds.height - heightWithoutNote) <= 1 }
        await assertReadsInOrder([title, row, button], in: cell)
        XCTAssertEqual(frame(row, in: cell).minY - frame(title, in: cell).maxY, 16, accuracy: 1)
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
