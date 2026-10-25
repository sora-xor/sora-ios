// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

@testable import SoraPassport
import XCTest

final class PortfolioMemorySlots: PortfolioSlotStoring {
    var store: [String: [String: Int]] = [:]

    func slots(scope: PortfolioScope, lens: PortfolioLens) -> [String: Int]? {
        store[scope.storageKey + "|" + lens.rawValue]
    }

    func setSlots(_ slots: [String: Int], scope: PortfolioScope, lens: PortfolioLens) {
        store[scope.storageKey + "|" + lens.rawValue] = slots
    }
}

@MainActor
final class PortfolioFakeSource: PortfolioDataSource {
    var snapshot: PortfolioSnapshot
    var onChange: ((PortfolioSnapshot) -> Void)?
    var isSample: Bool { false }
    private(set) var started = 0
    private(set) var stopped = 0
    private(set) var refreshed = 0

    init(_ snapshot: PortfolioSnapshot) {
        self.snapshot = snapshot
    }

    func start() { started += 1 }
    func stop() { stopped += 1 }
    func refreshAll() { refreshed += 1 }
    func asset(_ id: String) -> (symbol: String, icon: String?)? { nil }

    func publish(_ snapshot: PortfolioSnapshot) {
        self.snapshot = snapshot
        onChange?(snapshot)
    }
}

final class PortfolioPresenterTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_031)

    override func setUp() {
        super.setUp()
        PortfolioFormat.locale = Locale(identifier: "en_US")
    }

    private func render(_ snapshot: PortfolioSnapshot = PortfolioFixtures.snapshot(),
                        scope: PortfolioScope = .allWallets, lens: PortfolioLens = .tokens,
                        expanded: Set<String> = [], highlighted: String? = nil) -> PortfolioRender {
        PortfolioPresenter.render(snapshot, state: PortfolioPresentationState(scope: scope, lens: lens, expanded: expanded,
                                                                              highlighted: highlighted),
                                  store: PortfolioMemorySlots(), now: now)
    }

    func testHeroShowsTotalChangeCaptionAndFreshness() {
        let hero = render().hero
        XCTAssertEqual(hero.scopeTitle, "All wallets")
        XCTAssertEqual(hero.totalWhole + hero.totalFraction, "$1,600.00")
        XCTAssertEqual(hero.totalFraction, ".00")
        XCTAssertEqual(hero.direction, .up)
        XCTAssertTrue(hero.changeAmount?.hasPrefix("+$") ?? false)
        XCTAssertEqual(hero.caption, "1 hidden, 1 unpriced, 1 testnet not included")
        XCTAssertEqual(hero.chipText, "LIVE · 31s")
        XCTAssertEqual(hero.chipTone, .live)
        XCTAssertTrue(hero.canChangeScope)
        XCTAssertTrue(hero.sky.showsFan)
        XCTAssertEqual(hero.sky.segments.map(\.rays).reduce(0, +), 100)
        XCTAssertTrue(hero.accessibilityTotal.contains("$1,600.00"))
    }

    func testLegendChipsCarryFullLabelsAndOpenTokensOnlyInTheTokenLens() {
        let tokens = render().hero.legend
        XCTAssertEqual(tokens.map(\.title), ["ETH", "XOR"])
        XCTAssertEqual(tokens.first?.percent, "63%")
        XCTAssertEqual(tokens.first?.accessibilityLabel, "ETH, 63%, $1,000.00")
        XCTAssertTrue(tokens.allSatisfy(\.opensToken))
        let networks = render(lens: .networks).hero.legend
        XCTAssertEqual(networks.map(\.title), ["SORA2"])
        XCTAssertFalse(networks.contains { $0.opensToken })
    }

    func testWalletsLensOnlyInAllWallets() {
        XCTAssertEqual(render().list.lenses, [.tokens, .networks, .wallets])
        let single = render(scope: .wallet("A"), lens: .wallets)
        XCTAssertEqual(single.list.lenses, [.tokens, .networks])
        XCTAssertEqual(single.list.lens, .tokens)
    }

    func testTokenRowsSubtitleDotsAndExpansion() {
        let xorId = PortfolioFixtures.xor.id
        let rows = render(expanded: [xorId]).list.rows
        let xor = rows.first { $0.key == xorId }
        XCTAssertEqual(xor?.subtitle, "2 networks")
        XCTAssertEqual(xor?.walletDots.count, 2)
        XCTAssertEqual(xor?.isExpandable, true)
        XCTAssertEqual(xor?.children.map(\.title), ["SORA2", "SORA2", "Taira"])
        XCTAssertEqual(xor?.children.last?.tag, .network(.testnet), "The app's Testnet tag")
        XCTAssertEqual(xor?.children.first?.tag, .swapReady)
        XCTAssertEqual(xor?.change, "▲ +3.4%")
        let eth = rows.first { $0.key == PortfolioFixtures.eth.id }
        XCTAssertEqual(eth?.subtitle, "SORA2")
        XCTAssertEqual(eth?.isExpandable, false)
        XCTAssertEqual(eth?.value, "$1,000.00")
        let meme = rows.first { $0.key == PortfolioFixtures.meme.id }
        XCTAssertEqual(meme?.value, "No price")
        XCTAssertNil(meme?.change, "Flat or unknown change is hidden")
        // A single wallet's scope shows no wallet dots.
        XCTAssertTrue(render(scope: .wallet("A")).list.rows.allSatisfy { $0.walletDots.isEmpty })
    }

    func testWalletRowsLinkToTheWalletAlone() {
        let rows = render(lens: .wallets, expanded: ["A"]).list.rows
        XCTAssertEqual(rows.map(\.title), ["Beta", "Alpha"])
        XCTAssertEqual(rows.last?.link, "Open Alpha alone")
        XCTAssertTrue(rows.last?.subtitle.hasPrefix("25% · ") ?? false, "Share and networks under the name")
        XCTAssertTrue(rows.last?.detail.hasPrefix("LIVE") ?? false, "Freshness under the total")
    }

    func testEmptyWalletShowsTheSkyWithoutTheFan() {
        let empty = PortfolioSnapshot(wallets: [PortfolioFixtures.wallet("A", "Alpha", order: 0, selected: true)],
                                      holdings: [], networks: [.sora2], swapsAvailable: true,
                                      swapDisclaimerAccepted: false, liveNetworks: [.sora2])
        let result = render(empty, scope: .wallet("A"))
        XCTAssertTrue(result.hero.isEmpty)
        XCTAssertFalse(result.hero.sky.showsFan)
        XCTAssertTrue(result.hero.legend.isEmpty)
        XCTAssertFalse(result.hero.canChangeScope)
        XCTAssertEqual(result.list.emptyText, "No balance yet")
    }

    func testNetworkRowsTakeTheAppsNamesTagsAndOrder() {
        let base = PortfolioFixtures.snapshot()
        let wallets = [PortfolioFixtures.wallet("A", "Alpha", order: 0, selected: true, networks: [.sora2, .minamoto, .taira]),
                       PortfolioFixtures.wallet("B", "Beta", order: 1)]
        func snapshot(live: Set<PortfolioNetwork>) -> PortfolioSnapshot {
            PortfolioSnapshot(wallets: wallets, holdings: base.holdings, networks: [.taira, .minamoto, .sora2],
                              swapsAvailable: true, swapDisclaimerAccepted: true, liveNetworks: live)
        }
        let rows = render(snapshot(live: [.sora2, .taira]), lens: .networks).list.rows
        XCTAssertEqual(rows.map(\.title), ["SORA2", "SORA Nexus", "Taira"],
                       "WalletNetworkDirectory order: main, mainnets not live yet, testnets")
        XCTAssertEqual(rows.map(\.tag), [.network(.main), .network(.comingSoon), .network(.testnet)])
        XCTAssertEqual(rows[1].subtitle, WalletUX.text("Address ready"), "A network that is not live yet only has an address")
        let live = render(snapshot(live: [.sora2, .minamoto, .taira]), lens: .networks).list.rows
        XCTAssertNil(live.first { $0.key == PortfolioNetwork.minamoto.rawValue }?.tag, "A live mainnet has no tag")
    }

    func testFirstReadShowsNeitherTheEmptyStateNorOffline() {
        var loading = PortfolioSnapshot(wallets: [PortfolioFixtures.wallet("A", "Alpha", order: 0, selected: true)],
                                        holdings: [], networks: [.sora2], swapsAvailable: true,
                                        swapDisclaimerAccepted: false, liveNetworks: [.sora2])
        loading.isLoading = true
        let result = render(loading, scope: .wallet("A"))
        XCTAssertTrue(result.hero.isLoading)
        XCTAssertFalse(result.hero.isEmpty, "No \"Your wallet is ready\" before the first read")
        XCTAssertEqual(result.hero.chipText, "", "No OFFLINE chip for a wallet not read yet")
        XCTAssertEqual(result.hero.totalWhole, "—")
        XCTAssertFalse(result.hero.sky.showsFan)
        XCTAssertEqual(result.list.emptyText, "Reading balances…")
        // Holdings already known (an earlier read) are shown as they are.
        var known = PortfolioFixtures.snapshot()
        known.isLoading = true
        XCTAssertFalse(render(known).hero.isLoading)
    }

    func testDetailModelForWhereItLives() {
        let model = PortfolioDetailPresenter.model(tokenId: PortfolioFixtures.xor.id, selectedHoldingId: nil,
                                                   snapshot: PortfolioFixtures.snapshot(), scope: .allWallets,
                                                   walletSlots: [:])
        XCTAssertEqual(model?.symbol, "XOR")
        XCTAssertEqual(model?.counts, "3 HOLDINGS · 2 NETWORKS")
        XCTAssertEqual(model?.share, "38% of all wallets")
        XCTAssertEqual(model?.satellites.map(\.network), [.sora2, .taira])
        XCTAssertEqual(model?.satellites.first?.isSwapReady, true)
        XCTAssertEqual(model?.satellites.last?.isSwapReady, false)
        XCTAssertEqual(model?.panel?.primary.kind, .swap)
        XCTAssertEqual(model?.panel?.locked, "10,000 XOR")
        XCTAssertNil(model?.panel?.switchNote)
        let beta = PortfolioDetailPresenter.model(tokenId: PortfolioFixtures.xor.id,
                                                  selectedHoldingId: "B|sora2|\(PortfolioFixtures.xor.id)",
                                                  snapshot: PortfolioFixtures.snapshot(), scope: .allWallets,
                                                  walletSlots: [:])
        XCTAssertEqual(beta?.panel?.switchNote, "This is in Beta. We switch to it first.")
        // The Polkaswap card follows the selected SORA2 holding, not the largest one.
        XCTAssertEqual(beta?.polkaswap.holdingId, "B|sora2|\(PortfolioFixtures.xor.id)")
        XCTAssertEqual(beta?.polkaswap.checks.first?.text, "SORA2 account in Beta")
        let taira = PortfolioDetailPresenter.model(tokenId: PortfolioFixtures.xor.id,
                                                   selectedHoldingId: "A|taira|\(PortfolioFixtures.xor.id)",
                                                   snapshot: PortfolioFixtures.snapshot(), scope: .allWallets,
                                                   walletSlots: [:])
        XCTAssertEqual(taira?.panel?.route.style, .test)
        XCTAssertEqual(taira?.panel?.route.text, "Testnet assets have no monetary value.")
    }

    func testNoRouteCopyNeverInventsARoute() {
        var snapshot = PortfolioFixtures.snapshot()
        snapshot = PortfolioSnapshot(wallets: snapshot.wallets,
                                     holdings: snapshot.holdings + [PortfolioFixtures.holding("A", .minamoto,
                                                                                              PortfolioFixtures.xor, "10")],
                                     networks: snapshot.networks, swapsAvailable: true, swapDisclaimerAccepted: true,
                                     liveNetworks: snapshot.liveNetworks)
        let model = PortfolioDetailPresenter.model(tokenId: PortfolioFixtures.xor.id,
                                                   selectedHoldingId: "A|minamoto|\(PortfolioFixtures.xor.id)",
                                                   snapshot: snapshot, scope: .allWallets, walletSlots: [:])
        XCTAssertEqual(model?.panel?.route.style, .noRoute)
        XCTAssertEqual(model?.panel?.route.text,
                       "Polkaswap swaps run on SORA2. There is no route from SORA Nexus in this version.")
        XCTAssertEqual(model?.panel?.primary.kind, .send)
        XCTAssertEqual(model?.panel?.primary.isEnabled, false, "SORA Nexus is not live in this version")
    }
}

@MainActor
final class PortfolioViewModelTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        PortfolioFormat.locale = Locale(identifier: "en_US")
        defaults = UserDefaults(suiteName: "portfolio.tests.\(UUID().uuidString)")
    }

    private func makeViewModel(_ snapshot: PortfolioSnapshot = PortfolioFixtures.snapshot())
        -> (PortfolioViewModel, PortfolioFakeSource) {
        let source = PortfolioFakeSource(snapshot)
        let viewModel = PortfolioViewModel(dataSource: source, preferences: PortfolioPreferences(defaults: defaults),
                                           now: { Date(timeIntervalSince1970: 1_031) })
        return (viewModel, source)
    }

    func testAllWalletsIsTheDefaultForTwoOrMoreWalletsAndTheChoiceSticks() {
        let (viewModel, _) = makeViewModel()
        XCTAssertEqual(viewModel.state.scope, .allWallets)
        viewModel.selectScope(.wallet("B"))
        viewModel.selectLens(.networks)
        let (again, _) = makeViewModel()
        XCTAssertEqual(again.state.scope, .wallet("B"))
        XCTAssertEqual(again.state.lens, .networks)
    }

    func testOneWalletUsesItsOwnScope() {
        let single = PortfolioSnapshot(wallets: [PortfolioFixtures.wallet("A", "Alpha", order: 0, selected: true)],
                                       holdings: [], networks: [.sora2], swapsAvailable: true,
                                       swapDisclaimerAccepted: false, liveNetworks: [.sora2])
        let (viewModel, _) = makeViewModel(single)
        XCTAssertEqual(viewModel.state.scope, .wallet("A"))
        var routes: [PortfolioRoute] = []
        viewModel.onRoute = { routes.append($0) }
        viewModel.tapScope()
        XCTAssertTrue(routes.isEmpty, "The Wallets sheet needs two or more wallets")
    }

    func testFirstTapHighlightsSecondTapOpensWhereItLives() {
        let (viewModel, _) = makeViewModel()
        var routes: [PortfolioRoute] = []
        viewModel.onRoute = { routes.append($0) }
        viewModel.viewWillAppear()
        let eth = PortfolioFixtures.eth.id
        viewModel.tapGroup(eth)
        XCTAssertEqual(viewModel.render?.hero.sky.highlightedKey, eth)
        XCTAssertEqual(viewModel.render?.hero.legend.first?.isSelected, true)
        viewModel.tapGroup(eth)
        XCTAssertEqual(routes, [.tokenDetail(tokenId: eth, holdingId: nil)])
        XCTAssertNil(viewModel.render?.hero.sky.highlightedKey)
        viewModel.viewDidDisappear()
    }

    func testRowsExpandAndSingleHoldingsOpenWhereItLives() {
        let (viewModel, _) = makeViewModel()
        var routes: [PortfolioRoute] = []
        viewModel.onRoute = { routes.append($0) }
        viewModel.update()
        let rows = viewModel.render?.list.rows ?? []
        let xor = rows.first { $0.key == PortfolioFixtures.xor.id }!
        viewModel.openRow(xor)
        XCTAssertEqual(viewModel.render?.list.rows.first { $0.key == xor.key }?.isExpanded, true)
        let eth = rows.first { $0.key == PortfolioFixtures.eth.id }!
        viewModel.openRow(eth)
        XCTAssertEqual(routes, [.tokenDetail(tokenId: eth.key, holdingId: "B|sora2|\(eth.key)")])
    }

    func testDataSourceRunsOnlyWhileVisibleAndUpdatesTheRender() {
        let (viewModel, source) = makeViewModel()
        var renders = 0
        viewModel.onRender = { _ in renders += 1 }
        viewModel.viewWillAppear()
        XCTAssertEqual(source.started, 1)
        let before = renders
        source.publish(PortfolioFixtures.snapshot(freshnessB: .saved(Date(timeIntervalSince1970: 0))))
        XCTAssertEqual(renders, before + 1)
        XCTAssertTrue(viewModel.render?.hero.chipText.hasPrefix("SAVED") ?? false)
        viewModel.viewDidDisappear()
        XCTAssertEqual(source.stopped, 1)
    }

    func testMovableAndSwappableHoldings() {
        let (viewModel, _) = makeViewModel()
        XCTAssertEqual(Set(viewModel.swappableHoldings.map(\.token.symbol)), ["XOR", "ETH"])
        // Only B is on SORA2 besides A, so A's and B's SORA2 holdings can move; Taira has no second wallet.
        XCTAssertFalse(viewModel.movableHoldings.contains { $0.network == .taira })
    }

    func testHandoffInboxOnlyRunsForTheWalletItWasMadeFor() {
        let inbox = PortfolioHandoffInbox()
        let start = Date(timeIntervalSince1970: 100)
        inbox.put(.receive, walletId: "B", now: start)
        XCTAssertNil(inbox.take(selectedWalletId: "A", now: start))
        XCTAssertEqual(inbox.take(selectedWalletId: "B", now: start.addingTimeInterval(5)), .receive)
        XCTAssertNil(inbox.take(selectedWalletId: "B", now: start.addingTimeInterval(6)))
        inbox.put(.receive, walletId: "B", now: start)
        XCTAssertNil(inbox.take(selectedWalletId: "B", now: start.addingTimeInterval(61)), "Expired hand-offs never run")
        // Only a send without a token, recipient or amount leaves the network choice to the Wallet tab.
        XCTAssertTrue(PortfolioHandoff.send(assetId: nil, recipient: nil, amount: nil).isPlainSend)
        XCTAssertFalse(PortfolioHandoff.send(assetId: "XOR", recipient: nil, amount: nil).isPlainSend)
    }
}
