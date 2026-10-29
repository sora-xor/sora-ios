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

@MainActor final class ProfileLoginActionBoundaryTests: XCTestCase {
    private func make(biometry: Bool? = nil) throws -> ProfileLoginActionFixture { try ProfileLoginActionFixture(biometry: biometry) }
    private func invoke(_ title: String, in alert: UIAlertController) throws {
        let action = try XCTUnwrap(alert.actions.first { $0.title == title })
        let block = try XCTUnwrap(action.value(forKey: "handler"))
        unsafeBitCast(block as AnyObject, to: (@convention(block) (UIAlertAction) -> Void).self)(action)
    }
    private func submit(_ f: ProfileLoginActionFixture, pin: String = "123456") throws -> UIAlertController {
        try f.items()[0].onTap?()
        let prompt = try XCTUnwrap(f.host.shown.last as? UIAlertController)
        prompt.textFields?.first?.text = pin
        try invoke(WalletUX.text("Continue"), in: prompt)
        return prompt
    }
    private func wait(_ predicate: () -> Bool) async { let end = Date().addingTimeInterval(10); while !predicate() && Date() < end { try? await Task.sleep(nanoseconds: 10_000_000) }; XCTAssertTrue(predicate()) }
    func testReloadPresentsSeparatePinAndBiometrySettings() throws {
        let f = try make(), items = try f.items()
        XCTAssertEqual(items.count, 2); XCTAssertNotNil(items[0].onTap); XCTAssertNil(items[0].onSwitch)
        XCTAssertNil(items[1].onTap); XCTAssertNotNil(items[1].onSwitch)
        XCTAssertEqual(f.view.navigationItem.title, R.string.localizable.settingsLoginTitle(preferredLanguages: ["en"]))
    }
    func testMissingBiometryPreferenceDisplaysOff() throws {
        let f = try make(); guard case .switcher(.off) = try f.items()[1].rightItem else { return XCTFail("Missing preference must be off") }
        XCTAssertNil(f.settings.biometryEnabled)
    }
    func testEnabledBiometryPreferenceDisplaysOn() throws {
        let f = try make(biometry: true); guard case .switcher(.on) = try f.items()[1].rightItem else { return XCTFail("Enabled preference must be on") }
    }
    func testDisablingBiometryWritesOnlyTheInjectedSettings() throws {
        let f = try make(biometry: true); try f.items()[1].onSwitch?(false)
        XCTAssertEqual(f.settings.biometryEnabled, false); XCTAssertEqual(f.auth.requests, [])
    }
    func testEnablingBiometryDoesNotOpenAPinEditor() throws {
        let f = try make(biometry: false); try f.items()[1].onSwitch?(true)
        XCTAssertEqual(f.settings.biometryEnabled, true); XCTAssertTrue(f.host.shown.isEmpty); XCTAssertTrue(f.state.authorizations.isEmpty)
    }
    func testPinChoiceRequestsCurrentPinWithSecureNumericInput() throws {
        let f = try make(); try f.items()[0].onTap?(); let alert = try XCTUnwrap(f.host.shown.last as? UIAlertController)
        XCTAssertEqual(alert.title, WalletUX.text("Enter your PIN")); XCTAssertEqual(alert.textFields?.count, 1)
        XCTAssertTrue(alert.textFields?.first?.isSecureTextEntry == true); XCTAssertEqual(alert.textFields?.first?.keyboardType, .numberPad)
        XCTAssertTrue(f.auth.requests.isEmpty); XCTAssertTrue(f.state.authorizations.isEmpty)
    }
    func testCancellingPinPromptClearsEnteredTextWithoutAuthenticating() throws {
        let f = try make(); try f.items()[0].onTap?(); let alert = try XCTUnwrap(f.host.shown.last as? UIAlertController)
        alert.textFields?.first?.text = "private-entry"; try invoke(WalletUX.text("Cancel"), in: alert)
        XCTAssertTrue((alert.textFields?.first?.text ?? "").isEmpty); XCTAssertTrue(f.auth.requests.isEmpty)
    }
    func testSuccessfulPinAuthenticationPassesTheExactGrantToTheEditorOnMain() async throws {
        let f = try make(); let prompt = try submit(f); await wait { f.state.authorizations.count == 1 }
        XCTAssertEqual(f.auth.requests, ["123456"]); XCTAssertEqual(f.auth.mainThreads, [false])
        XCTAssertTrue(f.state.authorizations.first === f.auth.authorization); XCTAssertEqual(f.state.mainThreads, [true])
        let container = try XCTUnwrap(f.host.shown.last as? BlurViewController)
        XCTAssertEqual(container.modalPresentationStyle, .overFullScreen); XCTAssertTrue(container.children.first === f.state.editor)
        XCTAssertTrue((prompt.textFields?.first?.text ?? "").isEmpty)
    }
    func testWrongPinShowsSafeFailureAndNeverConstructsTheEditor() async throws {
        let f = try make(); f.auth.failure = WalletRetainedPinGate.Failure.incorrectPin(attemptsBeforeWait: 2)
        _ = try submit(f, pin: "999999"); await wait { f.host.shown.count == 2 }
        let failure = try XCTUnwrap(f.host.shown.last as? UIAlertController)
        XCTAssertEqual(failure.title, WalletUX.text("PIN not changed")); XCTAssertTrue(failure.message?.contains("2") == true)
        XCTAssertFalse(failure.message?.contains("999999") ?? true); XCTAssertTrue(f.state.authorizations.isEmpty)
        XCTAssertTrue(f.host.mainThreads.allSatisfy { $0 })
    }
    func testUnexpectedAuthenticationFailureDoesNotExposePrivateErrorText() async throws {
        let f = try make(); f.auth.failure = NSError(domain: "fixture", code: 1, userInfo: [NSLocalizedDescriptionKey: "SECRET-KEY-MATERIAL"])
        _ = try submit(f); await wait { f.host.shown.count == 2 }
        let failure = try XCTUnwrap(f.host.shown.last as? UIAlertController)
        XCTAssertFalse(failure.message?.contains("SECRET-KEY-MATERIAL") ?? true); XCTAssertTrue(f.state.authorizations.isEmpty)
    }
    func testMissingEditorAfterSuccessfulAuthenticationDoesNotPresentAnEmptyContainer() async throws {
        let f = try make(); f.state.editor = nil; _ = try submit(f); await wait { f.state.authorizations.count == 1 }
        XCTAssertEqual(f.host.shown.count, 1)
    }
    func testMissingPresentingControllerDoesNotAuthenticateOrCreateAHiddenPrompt() throws {
        let f = try make(); f.state.host = nil; try f.items()[0].onTap?()
        XCTAssertTrue(f.host.shown.isEmpty); XCTAssertTrue(f.auth.requests.isEmpty)
    }
    func testRetainedSettingsRowsCannotChangePreferencesAfterPresenterRelease() throws {
        let f = try make(biometry: false); let items = try f.items(); weak var released = f.presenter
        f.view.presenter = nil; f.presenter = nil; XCTAssertNil(released)
        items[0].onTap?(); items[1].onSwitch?(true)
        XCTAssertEqual(f.settings.biometryEnabled, false); XCTAssertTrue(f.host.shown.isEmpty)
    }
    func testRetainedPinPromptCannotAuthenticateAfterPresenterRelease() throws {
        let f = try make(); try f.items()[0].onTap?(); let prompt = try XCTUnwrap(f.host.shown.last as? UIAlertController)
        f.view.presenter = nil; f.presenter = nil; prompt.textFields?.first?.text = "123456"
        try invoke(WalletUX.text("Continue"), in: prompt); XCTAssertTrue(f.auth.requests.isEmpty)
    }
    func testAuthenticationCannotPresentAnEditorAfterThePresenterIsReleased() async throws {
        let f = try make(); let gate = DispatchSemaphore(value: 0); f.auth.gate = gate
        defer { gate.signal() }; _ = try submit(f); await wait { f.auth.requests.count == 1 }
        let unexpectedEditor = expectation(description: "Released presenter cannot create an editor")
        unexpectedEditor.isInverted = true
        f.state.didCreateEditor = { unexpectedEditor.fulfill() }
        weak var released = f.presenter
        f.view.presenter = nil; f.presenter = nil
        XCTAssertNil(released)
        gate.signal(); await wait { f.auth.finished }
        await fulfillment(of: [unexpectedEditor], timeout: 1)
        XCTAssertTrue(f.state.authorizations.isEmpty); XCTAssertEqual(f.host.shown.count, 1)
    }
    func testLocalizationRefreshKeepsTheExistingSettingsSections() throws {
        let f = try make(); f.presenter?.applyLocalization()
        XCTAssertEqual(try f.items().count, 2); XCTAssertTrue(f.auth.requests.isEmpty); XCTAssertTrue(f.host.shown.isEmpty)
    }
}
@MainActor private final class ProfileLoginActionFixture {
    let settings = InMemorySettingsManager(), host = ProfileLoginActionHost(), state = ProfileLoginActionState(), view = ProfileLoginView()
    let auth: ProfileLoginActionAuth
    var presenter: ProfileLoginPresenter?
    init(biometry: Bool?) throws {
        settings.biometryEnabled = biometry; auth = try ProfileLoginActionAuth(); state.host = host
        let state = state, auth = auth
        presenter = ProfileLoginPresenter(environment: ProfileLoginEnvironment(settings: settings,
            presentingController: { state.host }, authenticate: { try auth.authenticate($0) },
            makeEditor: { grant in state.authorizations.append(grant); state.mainThreads.append(Thread.isMainThread); state.didCreateEditor?(); return state.editor }))
        presenter?.localizationManager = LocalizationManager(localization: "en")!
        presenter?.view = view; view.presenter = presenter; view.loadViewIfNeeded()
    }
    private func all<T: UIView>(_ type: T.Type, _ root: UIView) -> [T] { ((root as? T).map { [$0] } ?? []) + root.subviews.flatMap { all(type, $0) } }
    func items() throws -> [AppSettingsItem] {
        let table = try XCTUnwrap(all(SoramitsuTableView.self, view.view).first)
        return try XCTUnwrap(table.sora.sections.first?.rows.first as? AppSettingsCardItem).menuItems
    }
}
private final class ProfileLoginActionHost: UIViewController {
    var shown = [UIViewController](), mainThreads = [Bool]()
    override func present(_ controller: UIViewController, animated: Bool, completion: (() -> Void)? = nil) { shown.append(controller); mainThreads.append(Thread.isMainThread); completion?() }
}
@MainActor private final class ProfileLoginActionState {
    var didCreateEditor: (() -> Void)?
    var host: UIViewController?, editor: UIViewController? = UIViewController(), authorizations = [WalletOwnerPIN.Authorization](), mainThreads = [Bool]()
}
private final class ProfileLoginActionAuth: @unchecked Sendable {
    let authorization: WalletOwnerPIN.Authorization
    private let lock = NSLock(); private var values = [String](), threads = [Bool](), completed = false
    var failure: Error?, gate: DispatchSemaphore?
    var requests: [String] { lock.lock(); defer { lock.unlock() }; return values }
    var mainThreads: [Bool] { lock.lock(); defer { lock.unlock() }; return threads }
    var finished: Bool { lock.lock(); defer { lock.unlock() }; return completed }
    init() throws {
        let keys = InMemoryKeychain(), settings = InMemorySettingsManager()
        try keys.saveKey(Data("123456".utf8), with: KeystoreTag.pincode.rawValue)
        let gate = WalletRecoveryCapabilityGate(settings: settings, unresolvedMigrationJournal: { false }, unresolvedWalletCommitJournal: { false }, credentialRepairPending: { false })
        authorization = try WalletOwnerPIN(keystore: keys, settings: settings, recoveryGate: gate).authenticateCurrent("123456", accounts: [])
    }
    func authenticate(_ pin: String) throws -> WalletOwnerPIN.Authorization {
        lock.lock(); values.append(pin); threads.append(Thread.isMainThread); lock.unlock()
        gate?.wait(); defer { lock.lock(); completed = true; lock.unlock() }
        if let failure { throw failure }; return authorization
    }
}
