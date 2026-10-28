import Foundation
import IrohaCrypto
import RobinHood
import SSFUtils
import SoraFoundation
import SoraKeystore
import SoraUIKit
// SPDX-License-Identifier: Apache-2.0
import UIKit
import XCTest

@testable import SoraPassport

@MainActor
final class MoreMenuNavigationFlowTests: XCTestCase {
  private func make() throws -> MenuRouteFixture { try MenuRouteFixture() }
  private func screen<T: UIViewController>(_ type: T.Type, _ root: UIViewController?) throws -> T {
    let root = try XCTUnwrap(root)
    if let value = root as? T { return value }
    for child in root.children { if let value = try? screen(type, child) { return value } }
    throw MenuRouteFailure.missingScreen
  }
  func testInformationRouteCreatesTheInformationScreenInsideOneModal() throws {
    let f = try make()
    f.route.showInformation(from: f.host)
    XCTAssertEqual(f.host.shown.count, 1)
    _ = try screen(SettingsInformationViewController.self, f.host.shown.first)
    XCTAssertTrue(f.host.shown[0] is BlurViewController)
    XCTAssertEqual(f.host.shown[0].modalPresentationStyle, .overFullScreen)
  }
  func testAppSettingsRouteCreatesTheRealSettingsScreen() throws {
    let f = try make()
    f.route.showAppSettings(from: f.host)
    _ = try screen(AppSettingsView.self, f.host.shown.first)
    XCTAssertEqual(f.host.shown.count, 1)
  }
  func testSecurityRouteCreatesTheAuthenticationScreenWithoutAuthenticating() throws {
    let f = try make()
    f.route.showSecurity(from: f.host)
    let view = try screen(ProfileLoginView.self, f.host.shown.first)
    XCTAssertNotNil(view.presenter)
    XCTAssertFalse(view.isViewLoaded)
  }
  func testChangeAccountRouteCreatesTheAccountPickerWithoutChangingSelection() throws {
    let f = try make()
    let previous = SelectedWalletSettings.shared.currentAccount?.address
    f.route.showChangeAccountView(from: f.host)
    let view = try screen(ChangeAccountViewController.self, f.host.shown.first)
    XCTAssertNotNil(view.presenter)
    XCTAssertEqual(SelectedWalletSettings.shared.currentAccount?.address, previous)
  }
  func testNexusRoutePushesThePortfolioOnTheCurrentNavigationStack() throws {
    let f = try make()
    let nav = MenuRouteNavigation()
    nav.addChild(f.host)
    f.route.showNexusPortfolio(from: f.host)
    let view = try XCTUnwrap(nav.pushed.last as? NexusPortfolioViewController)
    XCTAssertTrue(view.hidesBottomBarWhenPushed)
    XCTAssertTrue(f.host.shown.isEmpty)
    XCTAssertEqual(nav.flags, [true])
    XCTAssertFalse(view.isViewLoaded)
  }
  func testPolkamarktRoutePushesTheMarketCatalogOnTheCurrentNavigationStack() throws {
    let f = try make()
    let nav = MenuRouteNavigation()
    nav.addChild(f.host)
    f.route.showPolkamarkt(from: f.host)
    let view = try XCTUnwrap(nav.pushed.last as? PolkamarktViewController)
    XCTAssertTrue(view.hidesBottomBarWhenPushed)
    XCTAssertTrue(view.localizationManager === f.language)
    XCTAssertEqual(nav.flags, [true])
    XCTAssertFalse(view.isViewLoaded)
  }
  func testNexusRouteRequiresANavigationStack() throws {
    let f = try make()
    f.route.showNexusPortfolio(from: f.host)
    XCTAssertTrue(f.host.shown.isEmpty)
  }
  func testPolkamarktRouteRequiresANavigationStack() throws {
    let f = try make()
    f.route.showPolkamarkt(from: f.host)
    XCTAssertTrue(f.host.shown.isEmpty)
  }
  func testInformationRouteHandlesAMissingPresenter() throws {
    let f = try make()
    f.route.showInformation(from: nil)
    XCTAssertTrue(f.host.shown.isEmpty)
  }
  func testSettingsRouteHandlesAMissingPresenter() throws {
    let f = try make()
    f.route.showAppSettings(from: nil)
    XCTAssertTrue(f.host.shown.isEmpty)
  }
  func testSecurityRouteHandlesAMissingPresenter() throws {
    let f = try make()
    f.route.showSecurity(from: nil)
    XCTAssertTrue(f.host.shown.isEmpty)
  }
  func testAccountPickerRouteHandlesAMissingPresenter() throws {
    let f = try make()
    f.route.showChangeAccountView(from: nil)
    XCTAssertTrue(f.host.shown.isEmpty)
  }
  func testNodesRouteHandlesAMissingPresenter() throws {
    let f = try make()
    f.route.showNodes(from: nil)
    XCTAssertTrue(f.host.shown.isEmpty)
  }
  func testFriendsRouteHandlesAMissingPresenter() throws {
    let f = try make()
    f.route.showFriendsView(from: nil)
    XCTAssertTrue(f.host.shown.isEmpty)
  }
  func testNexusRouteHandlesAMissingPresenter() throws {
    let f = try make()
    f.route.showNexusPortfolio(from: nil)
    XCTAssertTrue(f.host.shown.isEmpty)
  }
  func testPolkamarktRouteHandlesAMissingPresenter() throws {
    let f = try make()
    f.route.showPolkamarkt(from: nil)
    XCTAssertTrue(f.host.shown.isEmpty)
  }
  func testIndependentModalRoutesDoNotReuseThePreviousScreen() throws {
    let f = try make()
    f.route.showInformation(from: f.host)
    f.route.showInformation(from: f.host)
    XCTAssertEqual(f.host.shown.count, 2)
    XCTAssertFalse(f.host.shown[0] === f.host.shown[1])
    let first = try screen(SettingsInformationViewController.self, f.host.shown[0])
    let second = try screen(SettingsInformationViewController.self, f.host.shown[1])
    XCTAssertFalse(first === second)
  }
  func testRouteConstructionKeepsItsInjectedSettingsAndContext() throws {
    let f = try make()
    XCTAssertTrue(f.route.settingsManager === f.settings)
    XCTAssertTrue(f.route.localizationManager === f.language)
    XCTAssertTrue(f.route.walletContext === f.context)
  }
}
private enum MenuRouteFailure: Error { case missingScreen }
@MainActor
private final class MenuRouteFixture {
  let host = MenuRouteHost(), context = WalletContextMock(), settings = InMemorySettingsManager(),
    language = LocalizationManager(localization: "en")!, assets = MenuRouteAssets(),
    balances = MenuRouteBalances()
  let route: MoreMenuWireframe
  init() throws {
    let key = Data(repeating: 0x42, count: 32)
    let address = try SS58AddressFactory().addressFromAccountId(
      data: key, type: SoraPassport.Chain.sora.addressType())
    let provider = BalanceProviderFactory(
      accountId: key.toHex(), cacheFacade: CoreDataCacheFacade.shared,
      networkOperationFactory: context.networkOperationFactory,
      identifierFactory: SingleProviderIdentifierFactory())
    route = MoreMenuWireframe(
      settingsManager: settings, localizationManager: language, walletContext: context,
      fiatService: MenuRouteFiat(), balanceFactory: provider, address: address,
      assetsProvider: balances, assetManager: assets)
  }
}
private final class MenuRouteHost: UIViewController, MoreMenuViewProtocol {
  var presenter: MoreMenuPresenterProtocol?
  var shown = [UIViewController]()
  func set(title: String) {}
  func update(snapshot: MoreMenuSnapshot) {}
  func refreshNavigationBar() {}
  override func present(
    _ viewControllerToPresent: UIViewController, animated flag: Bool,
    completion: (() -> Void)? = nil
  ) {
    shown.append(viewControllerToPresent)
    completion?()
  }
}
private final class MenuRouteNavigation: UINavigationController {
  var pushed = [UIViewController](), flags = [Bool]()
  override func pushViewController(_ viewController: UIViewController, animated: Bool) {
    pushed.append(viewController)
    flags.append(animated)
  }
}
private final class MenuRouteAssets: AssetManagerProtocol {
  static var networkAssets: [AssetInfo] = []
  let assets = [
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
  func getAssetList() -> [AssetInfo]? { assets }
  func updateAssetList(_ list: [AssetInfo]) {}
  func saveAssetList(_ list: [AssetInfo]) { saved.append(list) }
  func sortedAssets(_ list: [WalletAsset], onlyVisible: Bool) -> [WalletAsset] { list }
  func visibleCount() -> UInt { 2 }
  func setup(for accountSettings: SelectedWalletSettings) {}
}

private final class MenuRouteBalances: AssetProviderProtocol {
  var balances: [BalanceData] = []
  var unavailable: Set<String> = []
  var additions = 0
  func getBalances(with assetIds: [String]) -> [BalanceData] {
    balances.filter { assetIds.contains($0.identifier) }
  }
  func unavailableBalanceAssetIds(among assetIds: [String]) -> Set<String> {
    unavailable.intersection(assetIds)
  }
  func add(observer: AssetProviderObserverProtocol) { additions += 1 }
  func remove(observer: AssetProviderObserverProtocol) {}
}

private actor MenuRouteFiat: FiatServiceProtocol {
  func getFiat() async -> [PIExactFiatData] { [] }
}
