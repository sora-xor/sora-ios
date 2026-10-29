// SPDX-License-Identifier: Apache-2.0
import Foundation
import SoraUIKit
import UIKit
import XCTest

@testable import SoraPassport

@MainActor
final class PortfolioCoordinatorFlowTests: XCTestCase {
  private var fixtures = [PortfolioCoordinatorFixture]()
  override func tearDown() {
    fixtures.forEach { $0.close() }
    fixtures = []
    super.tearDown()
  }
  private func make(
    sample: Bool = false, snapshot: PortfolioSnapshot = PortfolioFixtures.snapshot()
  ) -> PortfolioCoordinatorFixture {
    let f = PortfolioCoordinatorFixture(sample: sample, snapshot: snapshot)
    fixtures.append(f)
    return f
  }
  private func shown<T: UIViewController>(_ type: T.Type, _ f: PortfolioCoordinatorFixture) throws
    -> T
  { try XCTUnwrap(f.host.shown.last as? T) }
  func testSelectedWalletPlainSendOpensNetworkAwareSend() {
    let f = make()
    f.coordinator.perform(.send(assetId: nil, recipient: nil, amount: nil), walletId: "A")
    XCTAssertEqual(f.router.routes, [.send(assetId: nil, recipient: nil, amount: nil)])
    XCTAssertTrue(f.switcher.requests.isEmpty)
  }
  func testSelectedWalletPrefillPreservesExactRecipientAndAmount() {
    let f = make()
    let route = PortfolioHandoff.send(
      assetId: "XOR", recipient: "B-sora2", amount: .exact(Decimal(string: "0.000000000000000001")!)
    )
    f.coordinator.perform(route, walletId: "A")
    XCTAssertEqual(f.router.routes, [route])
  }
  func testReceiveUsesTheNetworkAwareRoute() {
    let f = make()
    f.coordinator.perform(.receive, walletId: "A")
    XCTAssertEqual(f.router.routes, [.receive])
  }
  func testReceiveOnSora2BypassesTheNetworkChoice() {
    let f = make()
    f.coordinator.perform(.receiveOnSora2, walletId: "A")
    XCTAssertEqual(f.router.routes, [.receiveOnSora2])
  }
  func testSwapKeepsBothRequestedAssetIds() {
    let f = make()
    f.coordinator.perform(.swap(from: "XOR", to: "VAL"), walletId: "A")
    XCTAssertEqual(f.router.routes, [.swap(from: "XOR", to: "VAL")])
  }
  func testNetworkSendKeepsNetworkAndSendIntent() {
    let f = make()
    f.coordinator.perform(.network(.taira, send: true), walletId: "A")
    XCTAssertEqual(f.router.routes, [.network(.taira, send: true)])
  }
  func testUnavailableNetworkExplainsWhyItDidNotOpen() throws {
    let f = make()
    f.router.networkAvailable = false
    f.coordinator.openNetwork(.minamoto)
    XCTAssertFalse(try shown(UIAlertController.self, f).message?.isEmpty ?? true)
  }
  func testUnconfirmedOtherWalletRequiresAnExplicitSwitchSheet() throws {
    let f = make()
    f.coordinator.perform(.receive, walletId: "B")
    XCTAssertEqual(try shown(PortfolioSwitchSheet.self, f).walletName, "Beta")
    XCTAssertTrue(f.router.routes.isEmpty)
    XCTAssertTrue(f.switcher.requests.isEmpty)
  }
  func testUnknownUnconfirmedWalletCannotBeSwitched() {
    let f = make()
    f.coordinator.perform(.receive, walletId: "missing")
    XCTAssertTrue(f.host.shown.isEmpty)
    XCTAssertTrue(f.switcher.requests.isEmpty)
  }
  func testConfirmedSwitchStoresRouteUntilMatchingWalletAppears() {
    let f = make()
    f.coordinator.perform(.receive, walletId: "B", confirmed: true)
    XCTAssertEqual(f.switcher.requests, ["B"])
    f.coordinator.consumePendingHandoff()
    XCTAssertTrue(f.router.routes.isEmpty)
    f.switcher.selectedWalletId = "B"
    f.coordinator.consumePendingHandoff()
    XCTAssertEqual(f.router.routes, [.receive])
  }
  func testPendingRouteIsConsumedExactlyOnce() {
    let f = make()
    f.inbox.put(.receive, walletId: "A")
    f.coordinator.consumePendingHandoff()
    f.coordinator.consumePendingHandoff()
    XCTAssertEqual(f.router.routes, [.receive])
  }
  func testFailedSwitchClearsItsPendingRoute() throws {
    let f = make()
    f.coordinator.perform(.receive, walletId: "B", confirmed: true)
    f.switcher.callbacks[0](false)
    f.switcher.selectedWalletId = "B"
    f.coordinator.consumePendingHandoff()
    XCTAssertTrue(f.router.routes.isEmpty)
    XCTAssertNotNil(try shown(UIAlertController.self, f).message)
  }
  func testOldFailedSwitchCannotEraseANewerPendingRoute() {
    let f = make()
    f.coordinator.perform(.receive, walletId: "B", confirmed: true)
    f.coordinator.perform(.receiveOnSora2, walletId: "C", confirmed: true)
    f.switcher.callbacks[0](false)
    f.switcher.selectedWalletId = "C"
    f.coordinator.consumePendingHandoff()
    XCTAssertEqual(f.router.routes, [.receiveOnSora2])
  }
  func testMissingHostDoesNotConsumeARouteBeforePresentationIsPossible() {
    let f = make()
    f.inbox.put(.receive, walletId: "A")
    f.coordinator.host = nil
    f.coordinator.consumePendingHandoff()
    f.coordinator.host = f.host
    f.coordinator.consumePendingHandoff()
    XCTAssertEqual(f.router.routes, [.receive])
  }
  func testSampleSendNeverRoutesToSyntheticWalletAddresses() throws {
    let f = make(sample: true)
    f.coordinator.perform(.send(assetId: "XOR", recipient: "sample", amount: .max), walletId: "A")
    XCTAssertTrue(f.router.routes.isEmpty)
    XCTAssertTrue(f.switcher.requests.isEmpty)
    XCTAssertTrue(try shown(UIAlertController.self, f).message?.contains("Sample") == true)
  }
  func testSampleNetworkNeverOpensTheRealNetworkWallet() {
    let f = make(sample: true)
    f.coordinator.openNetwork(.taira)
    XCTAssertTrue(f.router.routes.isEmpty)
  }
  func testSampleSelectedWalletMayOpenReceiveOnTheRealSelectedWallet() {
    let f = make(sample: true)
    f.coordinator.perform(.receive, walletId: "A")
    XCTAssertEqual(f.router.routes, [.receive])
    XCTAssertTrue(f.switcher.requests.isEmpty)
  }
  func testSampleOtherWalletCannotBeSelectedForSwap() {
    let f = make(sample: true)
    f.coordinator.perform(.swap(from: "XOR", to: "VAL"), walletId: "B")
    XCTAssertTrue(f.router.routes.isEmpty)
    XCTAssertTrue(f.switcher.requests.isEmpty)
  }
  func testWalletsSheetListsAllAndIndividualWalletTotals() throws {
    let f = make()
    f.coordinator.showWallets()
    let sheet = try shown(PortfolioWalletsSheet.self, f)
    XCTAssertEqual(sheet.entries.map(\.scope), [.allWallets, .wallet("A"), .wallet("B")])
    XCTAssertEqual(sheet.entries.map(\.title), ["All wallets", "Alpha", "Beta"])
    XCTAssertEqual(sheet.selected, .allWallets)
  }
  func testWalletSelectionUpdatesScope() throws {
    let f = make()
    f.coordinator.showWallets()
    try shown(PortfolioWalletsSheet.self, f).onSelect?(.wallet("B"))
    XCTAssertEqual(f.model.state.scope, .wallet("B"))
  }
  func testWalletsRefreshRequestsAFreshRead() throws {
    let f = make()
    f.coordinator.showWallets()
    try shown(PortfolioWalletsSheet.self, f).onRefresh?()
    XCTAssertEqual(f.source.refreshed, 1)
  }
  func testHowWeCountExplainsEachExcludedCategory() throws {
    let f = make()
    f.coordinator.showHowWeCount()
    let sheet = try shown(PortfolioInfoSheet.self, f)
    XCTAssertEqual(sheet.paragraphs.count, 2)
    XCTAssertEqual(sheet.bullets.count, 3)
    XCTAssertTrue(sheet.bullets.contains { $0.contains("hidden") })
    XCTAssertTrue(sheet.bullets.contains { $0.contains("unpriced") })
    XCTAssertTrue(sheet.bullets.contains { $0.contains("testnet") })
  }
  func testFreshnessWithNoNetworksExplainsRetainedBalances() throws {
    let f = make()
    f.coordinator.showFreshness([])
    let sheet = try shown(PortfolioInfoSheet.self, f)
    XCTAssertTrue(sheet.paragraphs.joined().contains("last ones read"))
    sheet.onButton?()
    XCTAssertEqual(f.source.refreshed, 1)
  }
  func testQuickSendWithManyWalletsShowsWalletPicker() throws {
    let f = make()
    f.coordinator.quickAction(.send)
    let sheet = try shown(PortfolioPickerSheet.self, f)
    XCTAssertEqual(sheet.options.map(\.id), ["A", "B"])
    XCTAssertTrue(f.router.routes.isEmpty)
  }
  func testQuickReceiveWithOneWalletRoutesDirectly() {
    let base = PortfolioFixtures.snapshot()
    let snapshot = PortfolioSnapshot(
      wallets: [base.wallets[0]], holdings: base.holdings.filter { $0.walletId == "A" },
      networks: base.networks, swapsAvailable: true, swapDisclaimerAccepted: true,
      liveNetworks: base.liveNetworks)
    let f = make(snapshot: snapshot)
    f.coordinator.quickAction(.receive)
    XCTAssertEqual(f.router.routes, [.receive])
    XCTAssertTrue(f.host.shown.isEmpty)
  }
  func testQuickMoveWithNoSpendableHoldingsExplainsEmptyState() throws {
    let base = PortfolioFixtures.snapshot()
    let snapshot = PortfolioSnapshot(
      wallets: base.wallets, holdings: [], networks: base.networks, swapsAvailable: true,
      swapDisclaimerAccepted: true, liveNetworks: base.liveNetworks)
    let f = make(snapshot: snapshot)
    f.coordinator.quickAction(.move)
    let sheet = try shown(PortfolioPickerSheet.self, f)
    XCTAssertTrue(sheet.options.isEmpty)
    XCTAssertFalse(sheet.note?.isEmpty ?? true)
  }
  func testMoveShowsOnlyOtherWalletsOnTheSameNetwork() throws {
    let f = make()
    f.coordinator.showMove(holdingId: f.source.snapshot.holdings[0].id)
    let sheet = try shown(PortfolioMoveSheet.self, f)
    XCTAssertEqual(sheet.destinations.map(\.walletId), ["B"])
    XCTAssertEqual(sheet.destinations.map(\.address), ["B-sora2"])
    XCTAssertEqual(sheet.availability, .send)
    XCTAssertTrue(sheet.sourceIsSelected)
  }
  func testMoveWithNoDestinationCannotOpenSend() throws {
    let f = make()
    f.coordinator.showMove(holdingId: f.source.snapshot.holdings[1].id)
    let sheet = try shown(PortfolioMoveSheet.self, f)
    guard case .unavailable = sheet.availability else {
      return XCTFail("No recipient wallet accepted")
    }
    XCTAssertTrue(sheet.destinations.isEmpty)
  }
  func testMoveFromAnotherWalletNamesItsSource() throws {
    let f = make()
    f.coordinator.showMove(holdingId: f.source.snapshot.holdings[4].id)
    let sheet = try shown(PortfolioMoveSheet.self, f)
    XCTAssertEqual(sheet.sourceWalletName, "Beta")
    XCTAssertFalse(sheet.sourceIsSelected)
  }
  func testUnknownHoldingDoesNotOpenMoveOrSwap() {
    let f = make()
    f.coordinator.showMove(holdingId: "missing")
    f.coordinator.showSwap(holdingId: "missing")
    XCTAssertTrue(f.host.shown.isEmpty)
  }
  func testSwapTargetsExcludeTheSourceAndRetainKnownSymbols() throws {
    let f = make()
    f.coordinator.showSwap(holdingId: f.source.snapshot.holdings[0].id)
    let sheet = try shown(PortfolioSwapSheet.self, f)
    XCTAssertEqual(sheet.targets.map(\.symbol), ["VAL", "PSWAP", "XSTUSD"])
    XCTAssertFalse(sheet.targets.contains { $0.id == PortfolioFixtures.xor.id })
    XCTAssertTrue(sheet.isSelectedWallet)
  }
  func testDetailSendUsesTheSelectedHoldingAsset() {
    let f = make()
    f.coordinator.detailAction(.send, holdingId: f.source.snapshot.holdings[0].id)
    XCTAssertEqual(
      f.router.routes, [.send(assetId: PortfolioFixtures.xor.id, recipient: nil, amount: nil)])
  }
  func testDetailSendOnTairaUsesTheTairaSendRoute() {
    let f = make()
    f.coordinator.detailAction(.send, holdingId: f.source.snapshot.holdings[1].id)
    XCTAssertEqual(f.router.routes, [.network(.taira, send: true)])
  }
  func testDetailReceiveOpensSora2Receive() {
    let f = make()
    f.coordinator.detailAction(.receiveOnSora2, holdingId: f.source.snapshot.holdings[0].id)
    XCTAssertEqual(f.router.routes, [.receiveOnSora2])
  }
  func testUnknownDetailHoldingDoesNotRoute() {
    let f = make()
    f.coordinator.detailAction(.send, holdingId: "missing")
    XCTAssertTrue(f.router.routes.isEmpty)
  }
  func testDetailRequiresNavigationContainer() {
    let f = make()
    f.coordinator.showDetail(tokenId: PortfolioFixtures.xor.id, holdingId: nil)
    XCTAssertTrue(f.host.children.isEmpty)
    XCTAssertTrue(f.host.shown.isEmpty)
  }
  func testHomeLifecycleStartsAndStopsSourceAndSky() {
    let f = make()
    let home = PortfolioHome(dataSource: f.source, preferences: f.preferences)
    home.attach(host: f.host, router: f.router, switcher: f.switcher)
    home.viewWillAppear()
    home.viewDidAppear()
    XCTAssertEqual(f.source.started, 1)
    XCTAssertTrue(home.heroItem.isSkyVisible)
    home.viewDidDisappear()
    XCTAssertEqual(f.source.stopped, 1)
    XCTAssertFalse(home.heroItem.isSkyVisible)
  }
  func testHomeHeroScopeActionOpensWalletSheet() throws {
    let f = make()
    let home = PortfolioHome(dataSource: f.source, preferences: f.preferences)
    home.attach(host: f.host, router: f.router, switcher: f.switcher)
    home.heroItem.onScope?()
    XCTAssertTrue(try shown(PortfolioWalletsSheet.self, f).entries.count == 3)
  }
  func testHomeLensSelectionUpdatesTheRenderedList() {
    let f = make()
    let home = PortfolioHome(dataSource: f.source, preferences: f.preferences)
    home.lensItem.onSelect?(.networks)
    XCTAssertEqual(home.viewModel.state.lens, .networks)
    XCTAssertEqual(home.listItem.model?.lens, .networks)
  }
  func testHomeCaptionOpensTheExclusionExplanation() throws {
    let f = make()
    let home = PortfolioHome(dataSource: f.source, preferences: f.preferences)
    home.attach(host: f.host, router: f.router, switcher: f.switcher)
    home.heroItem.onCaption?()
    XCTAssertEqual(try shown(PortfolioInfoSheet.self, f).bullets.count, 3)
  }
}
@MainActor private final class PortfolioCoordinatorFixture {
  let name = "portfolio-coordinator-" + UUID().uuidString
  let host = PortfolioRouteHost(), router = PortfolioRouteSpy(), switcher = PortfolioSwitchSpy(),
    inbox = PortfolioHandoffInbox()
  let source: PortfolioRouteSource, preferences: PortfolioPreferences, model: PortfolioViewModel,
    coordinator: PortfolioCoordinator
  init(sample: Bool, snapshot: PortfolioSnapshot) {
    let defaults = UserDefaults(suiteName: name)!
    preferences = PortfolioPreferences(defaults: defaults)
    source = PortfolioRouteSource(snapshot, sample: sample)
    model = PortfolioViewModel(dataSource: source, preferences: preferences)
    coordinator = PortfolioCoordinator(
      viewModel: model, router: router, switcher: switcher, inbox: inbox,
      asset: { _ in ("XSTUSD", nil) })
    coordinator.host = host
  }
  func close() {
    model.viewDidDisappear()
    host.shown = []
    UserDefaults(suiteName: name)?.removePersistentDomain(forName: name)
  }
}
@MainActor private final class PortfolioRouteSource: PortfolioDataSource {
  var snapshot: PortfolioSnapshot
  var onChange: ((PortfolioSnapshot) -> Void)?
  let isSample: Bool
  var started = 0, stopped = 0, refreshed = 0
  init(_ snapshot: PortfolioSnapshot, sample: Bool) {
    self.snapshot = snapshot
    isSample = sample
  }
  func start() { started += 1 }
  func stop() { stopped += 1 }
  func refreshAll() { refreshed += 1 }
  func asset(_ id: String) -> (symbol: String, icon: String?)? { ("XSTUSD", nil) }
}
@MainActor private final class PortfolioRouteHost: UIViewController {
  var shown = [UIViewController]()
  override func present(
    _ viewControllerToPresent: UIViewController, animated: Bool, completion: (() -> Void)? = nil
  ) {
    shown.append(viewControllerToPresent)
    completion?()
  }
}
@MainActor private final class PortfolioSwitchSpy: PortfolioAccountSwitching {
  var selectedWalletId: String? = "A"
  var requests = [String]()
  var callbacks = [(Bool) -> Void]()
  func switchTo(walletId: String, completion: @escaping (Bool) -> Void) {
    requests.append(walletId)
    callbacks.append(completion)
  }
}
@MainActor private final class PortfolioRouteSpy: PortfolioHandoffRouting {
  var routes = [PortfolioHandoff](), networkAvailable = true
  func showSend(from: UIViewController) {
    routes.append(.send(assetId: nil, recipient: nil, amount: nil))
  }
  func showSora2Send(
    from: UIViewController, assetId: String?, recipient: String?, amount: PortfolioAmountChoice?
  ) { routes.append(.send(assetId: assetId, recipient: recipient, amount: amount)) }
  func showReceive(from: UIViewController) { routes.append(.receive) }
  func showSora2Receive(from: UIViewController) { routes.append(.receiveOnSora2) }
  func showSwap(from: UIViewController, fromAssetId: String, toAssetId: String) {
    routes.append(.swap(from: fromAssetId, to: toAssetId))
  }
  func showNetwork(_ network: PortfolioNetwork, send: Bool, from: UIViewController) -> Bool {
    routes.append(.network(network, send: send))
    return networkAvailable
  }
  func showManageWallets(from: UIViewController) {}
  func showManageAssets(from: UIViewController) {}
}

extension PortfolioCoordinatorFlowTests {
    private func boundHome(_ f: PortfolioCoordinatorFixture) -> PortfolioHome {
        let home = PortfolioHome(dataSource: f.source, preferences: f.preferences)
        home.attach(host: f.host, router: f.router, switcher: f.switcher)
        home.viewModel.update()
        return home
    }
    private func homeRow(_ home: PortfolioHome, lens: PortfolioLens, key: String) throws -> PortfolioRow {
        home.lensItem.onSelect?(lens)
        return try XCTUnwrap(home.listItem.model?.rows.first { $0.key == key })
    }
    func testHomeWalletLinkScopesAllRenderedBalancesToThatWallet() throws {
        let f = make(), home = boundHome(f)
        home.listItem.onLink?(try homeRow(home, lens: .wallets, key: "B"))
        XCTAssertEqual(home.viewModel.state.scope, .wallet("B")); XCTAssertTrue(f.router.routes.isEmpty)
    }
    func testHomeNetworkLinkOpensTheMatchingNetwork() throws {
        let f = make(), home = boundHome(f)
        home.listItem.onLink?(try homeRow(home, lens: .networks, key: PortfolioNetwork.taira.rawValue))
        XCTAssertEqual(f.router.routes, [.network(.taira, send: false)])
    }
    func testHomeTokenLinkDoesNotInventANavigationAction() throws {
        let f = make(), home = boundHome(f)
        home.listItem.onLink?(try homeRow(home, lens: .tokens, key: PortfolioFixtures.xor.id))
        XCTAssertTrue(f.host.shown.isEmpty); XCTAssertTrue(f.router.routes.isEmpty)
    }
    func testHomeMoveActionChoosesASpendableHoldingAndTheOtherWalletOnItsNetwork() throws {
        let f = make(), home = boundHome(f)
        home.listItem.onRowAction?(try homeRow(home, lens: .tokens, key: PortfolioFixtures.xor.id), .move)
        let sheet = try shown(PortfolioMoveSheet.self, f)
        XCTAssertEqual(sheet.destinations.map(\.walletId), ["B"]); XCTAssertEqual(sheet.availability, .send)
    }
    func testHomeSwapActionPrefersTheSora2Holding() throws {
        let f = make(), home = boundHome(f)
        home.listItem.onRowAction?(try homeRow(home, lens: .tokens, key: PortfolioFixtures.xor.id), .swap)
        let sheet = try shown(PortfolioSwapSheet.self, f)
        XCTAssertTrue(sheet.isSelectedWallet); XCTAssertEqual(sheet.targets.map(\.symbol), ["VAL", "PSWAP", "XSTUSD"])
    }
    func testHomeTokenActionWithNoExplicitChoiceOpensItsDetailInTheCurrentNavigation() throws {
        let f = make(), home = boundHome(f), navigation = UINavigationController(rootViewController: f.host)
        home.listItem.onRowAction?(try homeRow(home, lens: .tokens, key: PortfolioFixtures.xor.id), nil)
        XCTAssertTrue(navigation.topViewController is PortfolioDetailViewController)
        XCTAssertEqual(navigation.viewControllers.count, 2)
    }
    func testHomeInlineSendAndReceiveDoNotBypassTheirDedicatedRoutes() throws {
        let f = make(), home = boundHome(f), row = try homeRow(home, lens: .tokens, key: PortfolioFixtures.xor.id)
        home.listItem.onRowAction?(row, .send); home.listItem.onRowAction?(row, .receive)
        XCTAssertTrue(f.router.routes.isEmpty); XCTAssertTrue(f.host.shown.isEmpty)
    }
    func testHomeQuickActionUsesTheBoundCoordinator() {
        let f = make(), home = boundHome(f)
        home.heroItem.onQuickAction?(.send)
        XCTAssertFalse(f.host.shown.isEmpty)
    }
}

@MainActor
final class PortfolioTableBindingCoverageTests: RootActionFixtureTests {
    private var fixtures = [PortfolioCoordinatorFixture]()
    private var formatLocale: Locale!
    override func setUp() { super.setUp(); formatLocale = PortfolioFormat.locale }
    override func tearDown() async throws {
        fixtures.forEach { $0.close() }; fixtures = []; PortfolioFormat.locale = formatLocale
        try await super.tearDown()
    }
    private func make() -> (PortfolioHome, SoramitsuTableView, UIViewController, PortfolioTableBinding) {
        let f = PortfolioCoordinatorFixture(sample: true, snapshot: PortfolioFixtures.snapshot()); fixtures.append(f)
        let home = PortfolioHome(dataSource: f.source, preferences: f.preferences)
        let table = SoramitsuTableView(type: .plain), host = UIViewController()
        host.loadViewIfNeeded(); host.view.addSubview(table); table.frame = host.view.bounds
        let binding = PortfolioTableBinding(home: home, tableView: table, host: host)
        return (home, table, host, binding)
    }
    func testBindingConnectsTheTableScrollDelegateAndNoninteractiveBackdrop() throws {
        let (_, table, host, binding) = make()
        XCTAssertTrue(table.scrollViewDelegate === binding)
        let backdrop = try XCTUnwrap(host.view.subviews.first { $0 is PortfolioStatusBackdrop })
        XCTAssertFalse(backdrop.isUserInteractionEnabled); XCTAssertFalse(backdrop.isAccessibilityElement)
    }
    func testSafeAreaChangeWithoutAWindowDoesNotInventATopInset() {
        let (home, _, _, binding) = make(); home.heroItem.topInset = 17
        binding.safeAreaDidChange(); XCTAssertEqual(home.heroItem.topInset, 17)
    }
    func testSafeAreaChangeUsesTheWindowInsetInsteadOfTheNavigationBar() {
        let (home, _, host, binding) = make(); let navigation = UINavigationController(rootViewController: host)
        mount(navigation); binding.safeAreaDidChange()
        XCTAssertEqual(home.heroItem.topInset, window.safeAreaInsets.top)
        let before = home.heroItem.topInset; binding.safeAreaDidChange(); XCTAssertEqual(home.heroItem.topInset, before)
    }
    func testVisibleSkyIsEnabledOnlyWhileItRemainsInsideTheViewport() {
        let (home, table, host, binding) = make(); mount(host); binding.safeAreaDidChange()
        table.contentOffset = .zero; binding.scrollViewDidScroll(table); XCTAssertTrue(home.heroItem.isSkyVisible)
        table.contentOffset.y = home.heroItem.topInset + PortfolioTheme.Sky.height
        binding.scrollViewDidScroll(table); XCTAssertFalse(home.heroItem.isSkyVisible)
    }
    func testDetachedHostNeverLeavesTheSkyAnimationRunning() {
        let (home, table, _, binding) = make(); home.heroItem.isSkyVisible = true
        binding.scrollViewDidScroll(table); XCTAssertFalse(home.heroItem.isSkyVisible)
    }
    func testBackdropAppearsExactlyWhenTheCardReachesStatusChrome() throws {
        let (_, table, host, binding) = make(); mount(host)
        let backdrop = try XCTUnwrap(host.view.subviews.compactMap { $0 as? PortfolioStatusBackdrop }.first)
        table.contentOffset.y = PortfolioTheme.Sky.height - PortfolioTheme.Sky.cardOverlap
        binding.scrollViewDidScroll(table); XCTAssertFalse(backdrop.isShown)
        table.contentOffset.y += 1; binding.scrollViewDidScroll(table); XCTAssertTrue(backdrop.isShown)
        table.contentOffset.y = 0; binding.scrollViewDidScroll(table); XCTAssertFalse(backdrop.isShown)
    }
    func testHeightChangeCallbackDoesNotKeepAReleasedTableAlive() {
        let f = PortfolioCoordinatorFixture(sample: true, snapshot: PortfolioFixtures.snapshot()); fixtures.append(f)
        let home = PortfolioHome(dataSource: f.source, preferences: f.preferences), host = UIViewController()
        weak var observed: SoramitsuTableView?
        var binding: PortfolioTableBinding?
        autoreleasepool {
            let table = SoramitsuTableView(type: .plain); observed = table
            binding = PortfolioTableBinding(home: home, tableView: table, host: host)
        }
        XCTAssertNil(observed); XCTAssertNotNil(binding)
        home.listItem.onHeightChange?()
    }
    func testBackdropRepeatedVisibilityRequestsRemainIdempotent() {
        let backdrop = PortfolioStatusBackdrop(frame: CGRect(x: 0, y: 0, width: 390, height: 54))
        backdrop.setShown(true, animated: false); let count = backdrop.subviews.count
        backdrop.setShown(true, animated: true); XCTAssertTrue(backdrop.isShown); XCTAssertEqual(backdrop.subviews.count, count)
        backdrop.setShown(false, animated: false); backdrop.setShown(false, animated: true); XCTAssertFalse(backdrop.isShown)
    }
    func testBackdropPaletteRefreshRebuildsTheBackgroundWithoutChangingVisibility() throws {
        let backdrop = PortfolioStatusBackdrop(frame: CGRect(x: 0, y: 0, width: 390, height: 54))
        backdrop.setShown(true, animated: false); let old = try XCTUnwrap(backdrop.subviews.first)
        backdrop.styleDidChange(options: .palette)
        XCTAssertTrue(backdrop.isShown); XCTAssertFalse(backdrop.subviews.contains { $0 === old })
        XCTAssertEqual(backdrop.subviews.count, 2)
    }
    func testBackdropEffectsRefreshPreservesTheHiddenState() throws {
        let backdrop = PortfolioStatusBackdrop(frame: .zero); let old = try XCTUnwrap(backdrop.subviews.first)
        backdrop.styleDidChange(options: .effects)
        XCTAssertFalse(backdrop.isShown); XCTAssertFalse(backdrop.subviews.contains { $0 === old })
    }
}

@MainActor
final class PortfolioDetailActionCoverageTests: XCTestCase {
    @MainActor private final class Fixture {
        var snapshot = PortfolioFixtures.snapshot()
        var available = true
        var requests = [(String, String?)]()
        var actions = [(PortfolioActionPlan.Action, String)]()
        var swaps = [String?]()
        let token: PortfolioToken
        let initial: String
        lazy var controller: PortfolioDetailViewController = {
            let controller = PortfolioDetailViewController(tokenId: token.id, holdingId: initial) { [unowned self] tokenId, holdingId in
                self.requests.append((tokenId, holdingId))
                return self.available ? PortfolioDetailPresenter.model(tokenId: tokenId, selectedHoldingId: holdingId,
                    snapshot: self.snapshot, scope: .allWallets, walletSlots: [:]) : nil
            }
            controller.onAction = { [weak self] action, holding in self?.actions.append((action, holding)) }
            controller.onPolkaswap = { [weak self] in self?.swaps.append($0) }
            controller.loadViewIfNeeded()
            return controller
        }()
        init(token: PortfolioToken = PortfolioFixtures.xor, wallet: String = "A", network: PortfolioNetwork = .sora2) {
            self.token = token; initial = "\(wallet)|\(network.rawValue)|\(token.id)"
        }
        var model: PortfolioDetailModel {
            PortfolioDetailPresenter.model(tokenId: token.id, selectedHoldingId: requests.last?.1 ?? initial,
                snapshot: snapshot, scope: .allWallets, walletSlots: [:])!
        }
    }
    private func views<T: UIView>(_ type: T.Type, _ view: UIView) -> [T] {
        ((view as? T).map { [$0] } ?? []) + view.subviews.flatMap { views(type, $0) }
    }
    func testSelectedHoldingPrimaryActionKeepsItsExactIdentity() throws {
        let f = Fixture(); let button = try XCTUnwrap(views(PortfolioPrimaryButton.self, f.controller.view).first)
        button.sendActions(for: .touchUpInside)
        XCTAssertEqual(f.actions.map(\.0), [.swap])
        XCTAssertEqual(f.actions.map(\.1), [f.initial])
        XCTAssertTrue(f.swaps.isEmpty)
    }
    func testSelectedHoldingSecondaryActionsDispatchTheirOwnKinds() throws {
        let f = Fixture(); let buttons = views(PortfolioSecondaryButton.self, f.controller.view)
        XCTAssertEqual(buttons.count, 2)
        for button in buttons { XCTAssertTrue(button.isEnabled); button.sendActions(for: .touchUpInside) }
        XCTAssertEqual(f.actions.map(\.0), [.send, .move])
        XCTAssertEqual(f.actions.map(\.1), [f.initial, f.initial])
    }
    func testPolkaswapCardUsesItsDedicatedRouteAndSoraHolding() throws {
        let f = Fixture(); let button = try XCTUnwrap(views(PortfolioPrimaryButton.self, f.controller.view).last)
        button.sendActions(for: .touchUpInside)
        XCTAssertEqual(f.swaps.count, 1)
        XCTAssertEqual(f.swaps.first!, f.model.polkaswap.holdingId)
        XCTAssertTrue(f.actions.isEmpty)
    }
    func testNontradableTokenExplainsItsRouteAndOffersSoraReceive() throws {
        let f = Fixture(token: PortfolioFixtures.meme)
        let button = try XCTUnwrap(views(PortfolioPrimaryButton.self, f.controller.view).last)
        let reason = try XCTUnwrap(f.model.polkaswap.action.reason)
        XCTAssertTrue(views(UILabel.self, f.controller.view).contains { $0.text == reason })
        button.sendActions(for: .touchUpInside)
        XCTAssertEqual(f.actions.map(\.0), [.receiveOnSora2])
        XCTAssertEqual(f.actions.map(\.1), [f.initial])
        XCTAssertTrue(f.swaps.isEmpty)
    }
    func testUnavailableSecondaryActionCarriesItsReasonAndDisabledAppearance() throws {
        let f = Fixture(token: PortfolioFixtures.meme)
        let action = try XCTUnwrap(f.model.panel?.secondary.first { !$0.isEnabled })
        let button = try XCTUnwrap(views(PortfolioSecondaryButton.self, f.controller.view).first { $0.accessibilityLabel == action.title })
        XCTAssertFalse(button.isEnabled)
        XCTAssertTrue(button.accessibilityTraits.contains(.notEnabled))
        XCTAssertEqual(button.accessibilityHint, action.reason)
        XCTAssertEqual(button.alpha, 0.45, accuracy: 0.001)
        button.isHighlighted = true; XCTAssertEqual(button.alpha, 0.45, accuracy: 0.001)
        XCTAssertFalse(button.isHighlighted, "Disabled controls do not accept highlighted state")
        button.isHighlighted = false; XCTAssertEqual(button.alpha, 0.45, accuracy: 0.001)
        XCTAssertTrue(f.actions.isEmpty)
    }
    func testHoldingRowSelectionRebuildsActionsForTheNewWallet() throws {
        let f = Fixture(); let rows = views(PortfolioDetailHoldingRow.self, f.controller.view)
        let holding = try XCTUnwrap(f.model.holdings.first { $0.id != f.initial && $0.network == .sora2 })
        let row = try XCTUnwrap(rows.first { $0.accessibilityLabel == holding.accessibilityLabel })
        row.sendActions(for: .touchUpInside)
        XCTAssertEqual(f.requests.last?.1, holding.id)
        let button = try XCTUnwrap(views(PortfolioPrimaryButton.self, f.controller.view).first)
        button.sendActions(for: .touchUpInside)
        XCTAssertEqual(f.actions.map(\.1), [holding.id])
        XCTAssertEqual(views(PortfolioDetailHoldingRow.self, f.controller.view).filter { $0.accessibilityTraits.contains(.selected) }.count, 1)
    }
    func testRetappingTheSelectedHoldingDoesNotRebuildTheScreen() throws {
        let f = Fixture(); let row = try XCTUnwrap(views(PortfolioDetailHoldingRow.self, f.controller.view).first { $0.accessibilityTraits.contains(.selected) })
        let before = f.requests.count
        row.sendActions(for: .touchUpInside)
        XCTAssertEqual(f.requests.count, before)
    }
    func testPaletteUpdateRereadsTheCurrentModel() {
        let f = Fixture(); _ = f.controller
        let before = f.requests.count
        f.controller.styleDidChange(options: .palette)
        XCTAssertEqual(f.requests.count, before + 1)
        XCTAssertEqual(f.requests.last?.1, f.initial)
    }
    func testEffectsOnlyUpdateDoesNotReloadHoldings() {
        let f = Fixture(); _ = f.controller
        let before = f.requests.count
        f.controller.styleDidChange(options: .effects)
        XCTAssertEqual(f.requests.count, before)
    }
    func testMissingTokenReturnsToThePreviousScreen() {
        let f = Fixture(); let root = UIViewController()
        let navigation = UINavigationController(rootViewController: root)
        navigation.pushViewController(f.controller, animated: false)
        f.available = false
        f.controller.reload()
        XCTAssertTrue(navigation.topViewController === root)
    }
    func testHoldingHighlightReturnsToNormalOpacity() throws {
        let f = Fixture(); let row = try XCTUnwrap(views(PortfolioDetailHoldingRow.self, f.controller.view).first)
        row.isHighlighted = true; XCTAssertEqual(row.alpha, 0.7, accuracy: 0.001)
        row.isHighlighted = false; XCTAssertEqual(row.alpha, 1, accuracy: 0.001)
    }
    func testUnavailablePrimaryActionDisplaysWhyItCannotRun() throws {
        let f = Fixture(token: PortfolioFixtures.meme)
        f.snapshot = PortfolioSnapshot(wallets: f.snapshot.wallets,
            holdings: [PortfolioFixtures.holding("A", .sora2, PortfolioFixtures.meme, "10", transferable: "0")],
            networks: f.snapshot.networks, swapsAvailable: true, swapDisclaimerAccepted: true, liveNetworks: [.sora2])
        let button = try XCTUnwrap(views(PortfolioPrimaryButton.self, f.controller.view).first)
        XCTAssertFalse(button.isEnabled)
        let reason = try XCTUnwrap(f.model.panel?.primary.reason)
        XCTAssertTrue(views(UILabel.self, f.controller.view).contains { $0.text == reason })
        XCTAssertTrue(button.accessibilityTraits.contains(.notEnabled))
    }
}
