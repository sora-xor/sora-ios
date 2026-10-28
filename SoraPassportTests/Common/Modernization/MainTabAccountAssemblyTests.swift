// SPDX-License-Identifier: Apache-2.0
import BigInt
import Foundation
import IrohaCrypto
import RobinHood
import SSFUtils
import SoraFoundation
import SoraKeystore
import SoraUI
import SoraUIKit
import UIKit
import XCTest

@testable import SoraPassport

@MainActor
final class MainTabAccountAssemblyTests: XCTestCase {
  private var previousURLServices = [URLHandlingServiceProtocol]()
  override func setUp() {
    super.setUp()
    previousURLServices = URLHandlingService.shared.children
    URLHandlingService.shared.setup(children: [KeystoreImportService(logger: Logger.shared)])
  }
  override func tearDown() {
    URLHandlingService.shared.setup(children: previousURLServices)
    previousURLServices = []
    super.tearDown()
  }
  private func make() throws -> RebuildFixture { try RebuildFixture() }
  private func openingFailure(_ expected: WalletOpeningError, _ change: (RebuildFixture) -> Void)
    throws
  {
    let f = try make()
    change(f)
    XCTAssertThrowsError(try MainTabBarViewFactory.createViewOrThrow(environment: f.environment()))
    {
      XCTAssertEqual($0 as? WalletOpeningError, expected)
    }
  }
  func testRecoveryMarkerPreventsOpeningBeforeAccountAssembly() throws {
    try openingFailure(.recoveryRequired) { $0.recovery = true }
  }
  func testMissingImportServiceProducesAnExplicitOpeningFailure() throws {
    try openingFailure(.servicesNotReady) { $0.hasImport = false }
  }
  func testMissingConnectionProducesAnExplicitOpeningFailure() throws {
    try openingFailure(.connectionNotReady) { $0.hasConnection = false }
  }
  func testMissingRuntimeProducesAnExplicitOpeningFailure() throws {
    try openingFailure(.connectionNotReady) { $0.hasRuntime = false }
  }
  func testMissingSelectedAccountProducesAnExplicitOpeningFailure() throws {
    try openingFailure(.accountNotReady) { $0.selected = nil }
  }
  func testMissingAssetCatalogProducesAnExplicitOpeningFailure() throws {
    try openingFailure(.assetsNotReady) { $0.assets.available = false }
  }
  func testInvalidSelectedAddressProducesAnExplicitOpeningFailure() throws {
    try openingFailure(.accountNotReady) { $0.selected = $0.invalidAccount() }
  }
  func testFailedContextConstructionProducesAnExplicitOpeningFailure() throws {
    try openingFailure(.contextNotReady) { $0.contextFactory.failure = true }
  }
  func testSuccessfulOpeningBuildsAllFiveTabsInTheirPublicOrder() throws {
    let f = try make()
    let view = try f.open()
    let tabs = try XCTUnwrap(view.viewControllers)
    XCTAssertEqual(tabs.count, 5)
    XCTAssertTrue(
      (tabs[0] as? UINavigationController)?.viewControllers.first is RedesignWalletViewController)
    XCTAssertTrue(
      (tabs[1] as? UINavigationController)?.viewControllers.first is ExploreViewController)
    XCTAssertFalse(tabs[2].tabBarItem.isEnabled)
    XCTAssertTrue(
      (tabs[3] as? UINavigationController)?.viewControllers.first is ActivityViewController)
    XCTAssertTrue(
      (tabs[4] as? UINavigationController)?.viewControllers.first is MoreMenuViewController)
    view.middleButtonHadler = nil
  }
  func testSuccessfulOpeningConnectsTheRealPresenterInteractorAndRoute() throws {
    let f = try make()
    let view = try f.open()
    defer { view.middleButtonHadler = nil }
    let p = try XCTUnwrap(view.presenter as? MainTabBarPresenter)
    XCTAssertTrue(p.view === view)
    XCTAssertTrue(p.interactor is MainTabBarInteractor)
    XCTAssertTrue(p.wireframe is MainTabBarWireframe)
    XCTAssertEqual(f.assetPreparations, 1)
    XCTAssertEqual(f.contextFactory.calls, 1)
    XCTAssertEqual(f.apy.count, 1)
  }
  func testOpeningWithAnEmptyCatalogKeepsTheLaterAssetRebuildArmed() throws {
    let f = try make()
    f.assets.assets = []
    let v = try f.open()
    defer { v.middleButtonHadler = nil }
    let p = try XCTUnwrap(v.presenter as? MainTabBarPresenter)
    XCTAssertTrue(
      try XCTUnwrap(p.wireframe as? MainTabBarWireframe).assetListRebuild.isBuiltWithoutAssets)
  }
  func testInitialOpeningCannotPublishAnAccountThatChangedDuringAssembly() throws {
    let f = try make()
    let replacement = try f.account(byte: 0x33)
    f.contextFactory.onCreate = { [weak f] in f?.selected = replacement }
    XCTAssertThrowsError(try f.open())
  }
  func testInitialOpeningCannotMixTabsIfSelectionChangesDuringAPYBinding() throws {
    let f = try make()
    let replacement = try f.account(byte: 0x33)
    f.onAPY = { [weak f] in f?.selected = replacement }
    XCTAssertThrowsError(try f.open())
  }
  func testRecoveryBeginningDuringAssemblyPreventsPublishingWalletTabs() throws {
    let f = try make()
    f.contextFactory.onCreate = { [weak f] in f?.recovery = true }
    XCTAssertThrowsError(try f.open()) {
      XCTAssertEqual($0 as? WalletOpeningError, .recoveryRequired)
    }
  }
  private func checkExploreBackReference(_ index: Int) throws {
    let f = try make()
    let graph = try f.open()
    defer { graph.middleButtonHadler = nil }
    let navigation = try XCTUnwrap(graph.viewControllers?[1] as? UINavigationController)
    let explore = try XCTUnwrap(navigation.viewControllers.first as? ExploreViewController)
    let assets = try XCTUnwrap(explore.viewModels[0] as? ExploreAssetsPageViewModel)
    let pools = try XCTUnwrap(explore.viewModels[1] as? ExplorePoolsPageViewModel)
    let farms = try XCTUnwrap(explore.viewModels[2] as? ExploreFarmsPageViewModel)
    let search = try XCTUnwrap(explore.searchViewModel as? ExploreSearchPageViewModel)
    let bindings: [(ControllerBackedProtocol?) -> Void] = [
      { assets.view = $0 }, { pools.view = $0 }, { farms.view = $0 }, { search.view = $0 }
    ]
    bindings.forEach { $0(nil) }
    defer { bindings.forEach { $0(nil) } }
    weak var observed: RebuildBackedController?
    autoreleasepool {
      let owner = RebuildBackedController()
      observed = owner
      bindings[index](owner)
    }
    XCTAssertNil(observed, "A page model must not own the controller that owns its model")
  }
  func testAssetPageDoesNotRetainItsOwner() throws { try checkExploreBackReference(0) }
  func testPoolPageDoesNotRetainItsOwner() throws { try checkExploreBackReference(1) }
  func testFarmPageDoesNotRetainItsOwner() throws { try checkExploreBackReference(2) }
  func testSearchPageDoesNotRetainItsOwner() throws { try checkExploreBackReference(3) }
  func testInitialSwapCallbackDoesNotKeepItsTabControllerAlive() async throws {
    let f = try make()
    weak var observed: MainTabBarViewController?
    try autoreleasepool {
      let view = try f.open()
      observed = view
    }
    // UIKit may retain a newly assembled hierarchy until the next run-loop
    // update. Give that bounded cleanup a chance without hiding a retain cycle.
    for _ in 0..<50 where observed != nil {
      try await Task.sleep(nanoseconds: 5_000_000)
    }
    XCTAssertNil(observed)
    observed?.middleButtonHadler = nil
  }
  func testRebuildAtomicallyReplacesAllOldAccountTabs() throws {
    let f = try make()
    let old = f.host.viewControllers!
    f.route.recreateWalletViewController(on: f.host)
    XCTAssertEqual(f.host.viewControllers?.count, 5)
    for controller in f.host.viewControllers ?? [] {
      XCTAssertFalse(old.contains { $0 === controller })
    }
    XCTAssertFalse(f.route.accountSwitchRecoveryActive)
    XCTAssertFalse(f.host.tabBar.isHidden)
    XCTAssertTrue(f.route.walletContext === f.contextFactory.context)
  }
  func testRebuildFailureForTheSameAccountPreservesItsCurrentTabs() throws {
    let f = try make()
    let old = f.host.viewControllers!
    f.hasConnection = false
    f.route.recreateWalletViewController(on: f.host)
    XCTAssertEqual(f.host.viewControllers?.count, old.count)
    XCTAssertTrue(f.host.viewControllers?.first === old.first)
    XCTAssertFalse(f.route.accountSwitchRecoveryActive)
  }
  func testMissingAccountRebuildRemovesEveryPreviouslyBoundTab() throws {
    let f = try make()
    f.selected = nil
    f.route.recreateWalletViewController(on: f.host)
    XCTAssertTrue(f.route.accountSwitchRecoveryActive)
    XCTAssertEqual(f.host.viewControllers?.count, 1)
    XCTAssertTrue(f.host.viewControllers?.first is WalletRecoveryViewController)
    XCTAssertTrue(f.host.tabBar.isHidden)
    XCTAssertNil(f.host.middleButtonHadler)
  }
  func testChangedAccountWithMissingConnectionFallsBackToRecovery() throws {
    let f = try make()
    f.selected = try f.account(byte: 0x33)
    f.hasConnection = false
    f.route.recreateWalletViewController(on: f.host)
    XCTAssertTrue(f.route.accountSwitchRecoveryActive)
    XCTAssertTrue(f.host.viewControllers?.first is WalletRecoveryViewController)
  }
  func testChangedAccountWithMissingCatalogFallsBackToRecovery() throws {
    let f = try make()
    f.selected = try f.account(byte: 0x33)
    f.assets.available = false
    f.route.recreateWalletViewController(on: f.host)
    XCTAssertTrue(f.route.accountSwitchRecoveryActive)
  }
  func testChangedAccountWithFailedContextFallsBackToRecovery() throws {
    let f = try make()
    f.selected = try f.account(byte: 0x33)
    f.contextFactory.failure = true
    f.route.recreateWalletViewController(on: f.host)
    XCTAssertTrue(f.route.accountSwitchRecoveryActive)
  }
  func testChangedAccountWithMissingScreenRuntimeFallsBackToRecovery() throws {
    let f = try make()
    f.selected = try f.account(byte: 0x33)
    f.hasRuntime = false
    f.route.recreateWalletViewController(on: f.host)
    XCTAssertTrue(f.route.accountSwitchRecoveryActive)
  }
  func testAccountChangingDuringConstructionCannotPublishAMixedGraph() throws {
    let f = try make()
    let replacement = try f.account(byte: 0x33)
    f.contextFactory.onCreate = { [weak f] in f?.selected = replacement }
    f.route.recreateWalletViewController(on: f.host)
    XCTAssertTrue(f.route.accountSwitchRecoveryActive)
    XCTAssertTrue(f.host.viewControllers?.first is WalletRecoveryViewController)
  }
  func testSuccessfulRebuildAfterRecoveryRestoresTheWholeTabGraph() throws {
    let f = try make()
    let original = f.selected
    f.selected = nil
    f.route.recreateWalletViewController(on: f.host)
    f.selected = original
    f.route.recreateWalletViewController(on: f.host)
    XCTAssertFalse(f.route.accountSwitchRecoveryActive)
    XCTAssertEqual(f.host.viewControllers?.count, 5)
    XCTAssertFalse(f.host.tabBar.isHidden)
  }
  func testRebuiltSwapActionPresentsDisclaimerBeforeConsent() throws {
    let f = try make()
    f.route.recreateWalletViewController(on: f.host)
    f.host.middleButtonHadler?()
    let presented = try XCTUnwrap(f.host.presentations.last)
    XCTAssertTrue(presented.children.first is SwapDisclaimerViewController)
    XCTAssertEqual(f.disclaimerMarks, 0)
  }
  func testRebuiltSwapActionUsesTheExistingConsentPreference() throws {
    let f = try make()
    f.hasDisclaimer = true
    f.route.recreateWalletViewController(on: f.host)
    f.host.middleButtonHadler?()
    let presented = try XCTUnwrap(f.host.presentations.last)
    XCTAssertTrue(presented.children.first is UINavigationController)
    XCTAssertEqual(f.disclaimerMarks, 0)
  }
  func testAcceptedDisclaimerPresentsThePreparedSwapOnce() throws {
    let f = try make()
    f.route.recreateWalletViewController(on: f.host)
    f.host.middleButtonHadler?()
    let child = try XCTUnwrap(
      f.host.presentations.last?.children.first as? SwapDisclaimerViewController)
    let model = try XCTUnwrap(child.viewModel as? SwapDisclaimerViewModel)
    model.completion?()
    XCTAssertEqual(f.disclaimerMarks, 1)
    XCTAssertEqual(f.host.presentations.count, 2)
  }
  func testStaleSwapCallbackCannotPresentForAnotherSelectedAccount() throws {
    let f = try make()
    f.route.recreateWalletViewController(on: f.host)
    let callback = f.host.middleButtonHadler
    f.selected = try f.account(byte: 0x33)
    callback?()
    XCTAssertTrue(f.host.presentations.isEmpty)
  }
  func testPreviousRebuildCallbackCannotPresentAfterNewRebuild() throws {
    let f = try make()
    f.route.recreateWalletViewController(on: f.host)
    let callback = f.host.middleButtonHadler
    f.route.recreateWalletViewController(on: f.host)
    callback?()
    XCTAssertTrue(f.host.presentations.isEmpty)
  }
  func testLateDisclaimerConsentCannotPresentAfterAccountChanges() throws {
    let f = try make()
    f.route.recreateWalletViewController(on: f.host)
    f.host.middleButtonHadler?()
    let child = try XCTUnwrap(
      f.host.presentations.last?.children.first as? SwapDisclaimerViewController)
    let model = try XCTUnwrap(child.viewModel as? SwapDisclaimerViewModel)
    f.selected = try f.account(byte: 0x33)
    model.completion?()
    XCTAssertEqual(f.disclaimerMarks, 0)
    XCTAssertEqual(f.host.presentations.count, 1)
  }
  func testRecoveryInvalidatesPreviouslyRetainedSwapActions() throws {
    let f = try make()
    f.route.recreateWalletViewController(on: f.host)
    let callback = f.host.middleButtonHadler
    f.selected = nil
    f.route.recreateWalletViewController(on: f.host)
    callback?()
    XCTAssertTrue(f.host.presentations.isEmpty)
  }
  func testAccountImportRoutePresentsTheRealImportScreenInsideNavigation() throws {
    let f = try make()
    f.route.presentAccountImport(on: f.host)
    let nav = try XCTUnwrap(f.host.presentations.last as? UINavigationController)
    XCTAssertTrue(nav.viewControllers.first is ImportAccountViewController)
  }
  func testImportRouteDoesNotStackOverAnExistingImportTab() throws {
    let f = try make()
    f.route.presentAccountImport(on: f.host)
    let nav = try XCTUnwrap(f.host.presentations.last as? UINavigationController)
    f.host.presentations = []
    f.host.viewControllers = [nav]
    f.route.presentAccountImport(on: f.host)
    XCTAssertTrue(f.host.presentations.isEmpty)
  }
  func testTransactionSuccessRoutePresentsAUserFacingAcknowledgement() throws {
    let f = try make()
    f.route.showTransactionSuccess(on: f.host)
    XCTAssertEqual(f.host.presentations.count, 1)
    let alert = try XCTUnwrap(f.host.presentations.first)
    XCTAssertEqual(alert.modalPresentationStyle, .custom)
    XCTAssertEqual(
      (alert.view as? ImageWithTitleView)?.title,
      R.string.localizable.walletTransactionSubmitted(
        preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages))
  }
  func testMigrationRoutePresentsAnUnclosableMigrationContainerWithoutStartingIt() throws {
    let f = try make()
    let service = RebuildMigrationService()
    f.route.presentClaim(on: f.host, with: service)
    let root = try XCTUnwrap(f.host.presentations.last as? BlurViewController)
    XCTAssertFalse(root.isClosable)
    XCTAssertTrue(root.children.first is MigrationRedesignViewController)
    XCTAssertEqual(service.requests, 0)
  }
  func testBoundContentReloadExecutesItsCurrentContextCommandOnce() throws {
    let f = try make()
    let command = WalletCommandMock()
    f.route.walletContext = f.contextFactory.context
    f.contextFactory.context.closurePrepareAccountUpdateCommand = { command }
    f.route.reloadWalletContent()
    XCTAssertEqual(command.executionCount, 1)
  }
  func testChangedSelectionCannotReloadAnOldWalletContext() throws {
    let f = try make()
    let command = WalletCommandMock()
    f.route.walletContext = f.contextFactory.context
    f.contextFactory.context.closurePrepareAccountUpdateCommand = { command }
    f.selected = try f.account(byte: 0x31)
    f.route.reloadWalletContent()
    XCTAssertEqual(command.executionCount, 0)
  }

}

@MainActor
private final class RebuildFixture {
  let keys = InMemoryKeychain(), assets = RebuildAssets(), engine = RebuildEngine(),
    runtime = RebuildRuntime()
  let contextFactory = RebuildContextFactory(), host = RebuildHost()
  let language = LocalizationManager(localization: "en")!
  let imports = KeystoreImportService(logger: Logger.shared)
  var recovery = false, hasImport = true, hasConnection = true, hasRuntime = true,
    hasDisclaimer = false
  var selected: AccountItem?, assetPreparations = 0, disclaimerMarks = 0
  var apy = [PolkaswapNetworkOperationFactory]()
  var onAPY: (() -> Void)?
  var route: MainTabBarWireframe!
  init() throws {
    selected = try account(byte: 0x42)
    host.viewControllers = (0..<5).map { _ in UIViewController() }
    route = MainTabBarWireframe(
      walletContext: WalletContextMock(),
      assetListEnvironment: .init(
        selectedWalletId: { [weak self] in self?.selected?.address },
        assets: { [weak self] in self?.assets.assets },
        schedule: { _, _ in {} }, rebuildTabs: { $0.recreateWalletViewController(on: $1) }),
      assemblyEnvironment: environment())
  }
  func account(byte: UInt8) throws -> AccountItem {
    let key = Data(repeating: byte, count: 32)
    return AccountItem(
      address: try SS58AddressFactory().addressFromAccountId(
        data: key, type: SoraPassport.Chain.sora.addressType()),
      cryptoType: .sr25519, networkType: SoraPassport.Chain.sora.addressType(),
      username: "Public fixture", publicKeyData: key,
      settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: 0,
      isSelected: true)
  }
  func invalidAccount() -> AccountItem {
    AccountItem(
      address: "invalid", cryptoType: .sr25519, networkType: SoraPassport.Chain.sora.addressType(),
      username: "Invalid fixture",
      publicKeyData: Data(repeating: 0, count: 32),
      settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: 0,
      isSelected: true)
  }
  func environment() -> WalletTabAssemblyEnvironment {
    .init(
      requiresRecovery: { [weak self] in self?.recovery ?? true },
      importService: { [weak self] in self?.hasImport == true ? self?.imports : nil },
      selectedAccount: { [weak self] in self?.selected },
      connection: { [weak self] in self?.hasConnection == true ? self?.engine : nil },
      runtime: { [weak self] in self?.hasRuntime == true ? self?.runtime : nil },
      assetManager: { [assets] in assets },
      prepareAssets: { [weak self] _ in self?.assetPreparations += 1 },
      contextFactory: { [contextFactory] in contextFactory },
      keystore: { [keys] in keys }, fiatService: RebuildFiat(), marketCapService: RebuildMarket(),
      localizationManager: language,
      configureAPY: { [weak self] in
        self?.apy.append($0)
        self?.onAPY?()
      }, hasShownDisclaimer: { [weak self] in self?.hasDisclaimer ?? false },
      markDisclaimerShown: { [weak self] in self?.disclaimerMarks += 1 },
      eventCenter: { RebuildEvents() }, serviceCoordinator: { RebuildServices() })
  }
  func open() throws -> MainTabBarViewController {
    let created = try MainTabBarViewFactory.createViewOrThrow(environment: environment())
    return try XCTUnwrap(created as? MainTabBarViewController)
  }
}
private final class RebuildContextFactory: WalletContextFactoryProtocol {
  let context = WalletContextMock()
  var failure = false, calls = 0
  var onCreate: (() -> Void)?
  func createContext(
    connection: JSONRPCEngine, assetManager: AssetManagerProtocol,
    accountSettings: WalletAccountSettingsProtocol,
    demeterFarmingService: DemeterFarmingServiceProtocol
  ) throws -> CommonWalletContextProtocol {
    calls += 1
    onCreate?()
    if failure { throw CancellationError() }
    return context
  }
}
private final class RebuildHost: UITabBarController, MainTabBarViewProtocol {
  var middleButtonHadler: (() -> Void)?
  var presentations = [UIViewController]()
  func didReplaceView(for newView: UIViewController, for index: Int) {
    viewControllers?[index] = newView
  }
  override func present(
    _ viewControllerToPresent: UIViewController, animated: Bool, completion: (() -> Void)? = nil
  ) {
    presentations.append(viewControllerToPresent)
    completion?()
  }
}

private final class RebuildAssets: AssetManagerProtocol {
  static var networkAssets: [AssetInfo] = []
  var available = true
  var assets = [
    AssetInfo(
      id: WalletAssetId.xor.rawValue, symbol: "XOR", chainId: "", precision: 18, icon: nil,
      displayName: "SORA", visible: true),
    AssetInfo(
      id: WalletAssetId.val.rawValue, symbol: "VAL", chainId: "", precision: 18, icon: nil,
      displayName: "Validator", visible: true),
    AssetInfo(
      id: "custom-zero", symbol: "ZERO", chainId: "", precision: 18, icon: nil,
      displayName: "Zero asset", visible: false),
    AssetInfo(
      id: "custom-unknown", symbol: "UNKNOWN", chainId: "", precision: 18, icon: nil,
      displayName: "Unread asset", visible: false),
  ]
  var saved: [[AssetInfo]] = []
  func assetInfo(for identifier: String) -> AssetInfo? {
    assets.first { $0.identifier == identifier }
  }
  func getAssetList() -> [AssetInfo]? { available ? assets : nil }
  func updateAssetList(_ list: [AssetInfo]) {}
  func saveAssetList(_ list: [AssetInfo]) { saved.append(list) }
  func sortedAssets(_ list: [WalletAsset], onlyVisible: Bool) -> [WalletAsset] { list }
  func visibleCount() -> UInt { 2 }
  func setup(for accountSettings: SelectedWalletSettings) {}
}

private final class RebuildEngine: JSONRPCEngine {
  var url: URL?
  var pendingEngineRequests: [JSONRPCRequest] { [] }
  func callMethod<P: Codable, T: Decodable>(
    _ method: String, params: P?, options: JSONRPCOptions,
    completion closure: ((Result<T, Error>) -> Void)?
  ) throws -> UInt16 {
    if method.contains("submit") { XCTFail("No transport is permitted during tab construction") }
    throw URLError(.notConnectedToInternet)
  }
  func subscribe<P: Codable, T: Decodable>(
    _ method: String, params: P?, updateClosure: @escaping (T) -> Void,
    failureClosure: @escaping (Error, Bool) -> Void
  ) throws -> UInt16 { throw URLError(.notConnectedToInternet) }
  func cancelForIdentifier(_ identifier: UInt16) {}
  func generateRequestId() -> UInt16 { 1 }
  func addSubscription(_ subscription: JSONRPCSubscribing) {}
  func connectIfNeeded() {}
  func disconnectIfNeeded() {}
  func unsubsribe(_ identifier: UInt16) throws {}
}

private final class RebuildRuntime: RuntimeProviderProtocol {
  let chainId = PIIndexerClient.soraMainnetGenesis
  var snapshot: RuntimeSnapshot? { nil }
  func setup() {}
  func setupHot() {}
  func replaceTypesUsage(_ usage: SoraPassport.ChainModel.TypesUsage) {}
  func cleanup() {}
  func fetchCoderFactoryOperation(
    with timeout: TimeInterval, closure: SoraPassport.RuntimeMetadataClosure?
  ) -> BaseOperation<RuntimeCoderFactoryProtocol> { ClosureOperation { throw CancellationError() } }
}

private actor RebuildFiat: FiatServiceProtocol { func getFiat() async -> [PIExactFiatData] { [] } }

private final class RebuildMarket: MarketCapServiceProtocol {
  func getMarketCap(for assets: [String]) async -> Set<MarketCapInfo> { [] }
}

private final class RebuildMigrationService: MigrationServiceProtocol {
  var requests = 0
  func checkMigration() { XCTFail("Unexpected migration check") }
  func requestMigration(completion: @escaping MigrationResultClosure) {
    requests += 1
    XCTFail("No migration is permitted")
  }
}

private final class RebuildEvents: EventCenterProtocol {
  func notify(with event: EventProtocol) {}
  func notify(with event: EventProtocol, completionOnMain: @escaping () -> Void) {
    completionOnMain()
  }
  func add(observer: EventVisitorProtocol, dispatchIn queue: DispatchQueue?) {}
  func remove(observer: EventVisitorProtocol) {}
}
private final class RebuildServices: ServiceCoordinatorProtocol {
  func setup() {}
  func throttle() {}
  func updateOnAccountChange() {}
  func updateOnNetworkChange() {}
  func checkMigration() {}
}

private final class RebuildBackedController: UIViewController, ControllerBackedProtocol {}

@MainActor
final class MainTabEventLifecycleTests: XCTestCase {
    private func definition() -> KeystoreDefinition {
        KeystoreDefinition(address: "public-fixture", encoded: "AA==", encoding: KeystoreEncoding(content: ["pkcs8", "sr25519"], type: ["scrypt", "xsalsa20-poly1305"], version: "3"), meta: nil)
    }
    private func fixture(pendingImport: Bool = false) -> (MainTabBarInteractor, TabEventOutput, TabEventServices, TabEventImport, EventCenter) {
        let output = TabEventOutput(), services = TabEventServices(), imports = TabEventImport(), events = EventCenter()
        imports.definition = pendingImport ? definition() : nil
        let interactor = MainTabBarInteractor(eventCenter: events, serviceCoordinator: services, keystoreImportService: imports)
        interactor.presenter = output; return (interactor, output, services, imports, events)
    }
    private func send(_ event: EventProtocol, through center: EventCenter) async {
        let done = expectation(description: "event delivered"); center.notify(with: event) { done.fulfill() }; await fulfillment(of: [done], timeout: 3)
    }
    func testInitializationStartsServicesBeforeTheTabsSubscribe() {
        let (interactor, output, services, imports, _) = fixture()
        XCTAssertEqual(services.starts, 1); XCTAssertEqual(imports.additions, 0); XCTAssertTrue(output.calls.isEmpty)
        interactor.setup(); XCTAssertEqual(imports.additions, 1); XCTAssertEqual(services.migrationChecks, 1); XCTAssertEqual(output.calls, ["assets"])
    }
    func testPendingKeystoreImportIsAnnouncedBeforeInitialAssetCheck() {
        let (interactor, output, _, _, _) = fixture(pendingImport: true); interactor.setup()
        XCTAssertEqual(output.calls, ["import", "assets"])
    }
    func testKeystoreDefinitionChangesOnlyRequestImportWhenDataExists() {
        let (interactor, output, _, imports, _) = fixture(); interactor.setup(); output.calls = []
        imports.definition = definition(); imports.observer?.didUpdateDefinition(from: nil)
        imports.definition = nil; imports.observer?.didUpdateDefinition(from: definition())
        XCTAssertEqual(output.calls, ["import"])
    }
    func testWalletEventsRefreshOnlyTheirRelevantPresentationState() async {
        let (interactor, output, _, _, events) = fixture(); interactor.setup(); output.calls = []
        await send(WalletBalanceChanged(), through: events)
        await send(WalletStakingInfoChanged(), through: events)
        await send(WalletNewTransactionInserted(items: []), through: events)
        await send(LanguageChanged(), through: events)
        await send(SelectedAccountChanged(), through: events)
        await send(ChainsUpdatedEvent(updatedChains: []), through: events)
        await send(WalletAssetListArrived(), through: events)
        XCTAssertEqual(output.calls, ["wallet", "wallet", "wallet", "transaction-ended", "language", "account", "network", "assets"])
    }
    func testMigrationEventsCarryTheExactServiceAndCompletion() async {
        let (interactor, output, _, _, events) = fixture(), migration = RebuildMigrationService(); interactor.setup(); output.calls = []
        await send(MigrationEvent(service: migration), through: events)
        await send(MigrationSuccsessEvent(service: migration), through: events)
        XCTAssertEqual(output.calls, ["migration", "migration-ended"]); XCTAssertTrue((output.migration as? RebuildMigrationService) === migration); XCTAssertEqual(migration.requests, 0)
    }
    func testForegroundRefreshesVisibleWalletInformation() {
        let (interactor, output, _, _, _) = fixture()
        interactor.didReceiveWillEnterForeground(notification: Notification(name: UIApplication.willEnterForegroundNotification))
        XCTAssertEqual(output.calls, ["wallet"])
    }
}
private final class TabEventServices: ServiceCoordinatorProtocol {
    var starts = 0, migrationChecks = 0
    func setup() { starts += 1 }; func throttle() {}; func updateOnAccountChange() {}; func updateOnNetworkChange() {}; func checkMigration() { migrationChecks += 1 }
}
private final class TabEventImport: KeystoreImportServiceProtocol {
    var definition: KeystoreDefinition?; weak var observer: KeystoreImportObserver?; var additions = 0
    func add(observer: KeystoreImportObserver) { additions += 1; self.observer = observer }
    func remove(observer: KeystoreImportObserver) { self.observer = nil }
    func clear() { definition = nil }; func handle(url: URL) -> Bool { false }
}
private final class TabEventOutput: MainTabBarInteractorOutputProtocol {
    var calls: [String] = []; var migration: MigrationServiceProtocol?
    func didUserChange() { calls.append("account") }; func didReloadSelectedNetwork() { calls.append("network") }; func didReloadSelectedAccount() { calls.append("selected") }
    func didUpdateWalletInfo() { calls.append("wallet") }; func didRequestImportAccount() { calls.append("import") }; func didRequestMigration(with service: MigrationServiceProtocol) { migration = service; calls.append("migration") }
    func didEndMigration() { calls.append("migration-ended") }; func didEndTransaction() { calls.append("transaction-ended") }; func didLanguageChange() { calls.append("language") }; func didReceiveWalletAssetList() { calls.append("assets") }
}
