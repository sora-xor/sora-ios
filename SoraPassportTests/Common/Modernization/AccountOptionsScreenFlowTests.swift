import SSFCloudStorage
// SPDX-License-Identifier: Apache-2.0
import SoraFoundation
import SoraUIKit
import UIKit
import XCTest

@testable import SoraPassport

@MainActor
final class AccountOptionsScreenFlowTests: XCTestCase {
  private func descendants<T: UIView>(_ type: T.Type, _ root: UIView) -> [T] {
    ((root as? T).map { [$0] } ?? []) + root.subviews.flatMap { descendants(type, $0) }
  }
  private func make() -> (AccountOptionsViewController, OptionsScreenPresenter) {
    let p = OptionsScreenPresenter()
    let v = AccountOptionsViewController()
    v.presenter = p
    v.loadViewIfNeeded()
    return (v, p)
  }
  private func settle() async {
    await withCheckedContinuation { continuation in
      DispatchQueue.main.async { continuation.resume() }
    }
  }
  private func account() -> AccountItem {
    AccountItem(
      address: "public-test-wallet", cryptoType: .sr25519, networkType: Chain.sora.addressType(),
      username: "Fixture", publicKeyData: Data(repeating: 3, count: 32),
      settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: 0,
      isSelected: false)
  }
  private func route() -> AccountOptionsWireframe {
    AccountOptionsWireframe(localizationManager: LocalizationManager.shared)
  }
  func testInitialScreenRequestsItsPresenterOnce() {
    let (v, p) = make()
    v.loadViewIfNeeded()
    XCTAssertEqual(p.setupCount, 1)
  }
  func testReceivedAccountNameIsRenderedWithoutSubmittingAnEdit() throws {
    let (v, p) = make()
    v.didReceive(username: "Visible wallet")
    XCTAssertEqual(
      try XCTUnwrap(descendants(UITextField.self, v.view).first).text, "Visible wallet")
    XCTAssertTrue(p.names.isEmpty)
  }
  func testUserNameEditsSendTheCompleteNewValue() throws {
    let (v, p) = make()
    let field = try XCTUnwrap(descendants(UITextField.self, v.view).first)
    field.text = "Personal wallet 2"
    field.sendActions(for: .editingChanged)
    XCTAssertEqual(p.names, ["Personal wallet 2"])
  }
  func testFullPublicAddressIsRenderedWithoutTruncatingData() {
    let (v, _) = make()
    v.didReceive(address: "exact-public-address-with-long-suffix")
    XCTAssertEqual(v.addressLabel.text, "exact-public-address-with-long-suffix")
    XCTAssertEqual(v.addressLabel.numberOfLines, 0)
  }
  func testAddressTapForwardsCopyToThePresenter() throws {
    let (v, p) = make()
    let control = try XCTUnwrap(v.addressLabel.superview as? UIControl)
    control.sendActions(for: .touchUpInside)
    XCTAssertEqual(p.copies, 1)
  }
  func testPassphraseActionRequestsTheGuardedPresenterFlow() {
    let (v, p) = make()
    v.passphraseTapped()
    XCTAssertEqual(p.phrases, 1)
    XCTAssertEqual(p.seeds, 0)
  }
  func testRawSeedActionRequestsTheGuardedPresenterFlow() {
    let (v, p) = make()
    v.rawSeedTapped()
    XCTAssertEqual(p.seeds, 1)
    XCTAssertEqual(p.phrases, 0)
  }
  func testJsonExportActionRequestsTheGuardedPresenterFlow() {
    let (v, p) = make()
    v.jsoneTapped()
    XCTAssertEqual(p.jsons, 1)
  }
  func testForgetWalletActionRequestsTheGuardedPresenterFlow() {
    let (v, p) = make()
    v.logoutTapped()
    XCTAssertEqual(p.logouts, 1)
  }
  func testMnemonicWalletShowsTheAdditionalPhraseOption() {
    let (v, _) = make()
    v.setupOptions(with: .notBackedUp, hasEntropy: true)
    XCTAssertEqual(descendants(AccountOptionItem.self, v.view).count, 4)
  }
  func testSeedOnlyWalletDoesNotOfferAPhrase() {
    let (v, _) = make()
    v.setupOptions(with: .notBackedUp, hasEntropy: false)
    XCTAssertEqual(descendants(AccountOptionItem.self, v.view).count, 3)
    XCTAssertFalse(
      descendants(AccountOptionItem.self, v.view).contains {
        $0.titleLabel.text
          == R.string.localizable.exportAccountDetailsShowPassphrase(
            preferredLanguages: .currentLocale)
      })
  }
  func testUpdatingBackupStateReplacesTheOldActionLabel() {
    let (v, _) = make()
    v.setupOptions(with: .notBackedUp, hasEntropy: true)
    v.setupOptions(with: .backedUp, hasEntropy: true)
    let titles = descendants(AccountOptionItem.self, v.view).compactMap { $0.titleLabel.text }
    XCTAssertEqual(titles.count, 4)
    XCTAssertTrue(titles.contains(BackupState.backedUp.optionTitle))
    XCTAssertFalse(titles.contains(BackupState.notBackedUp.optionTitle))
  }
  func testChangingToASeedOnlyWalletRemovesTheOldPhraseRow() {
    let (v, _) = make()
    v.setupOptions(with: .notBackedUp, hasEntropy: true)
    v.setupOptions(with: .notBackedUp, hasEntropy: false)
    XCTAssertEqual(descendants(AccountOptionItem.self, v.view).count, 3)
  }
  func testLoadingCoversTheInteractiveContent() throws {
    let (v, _) = make()
    v.showLoading()
    let loading = try XCTUnwrap(descendants(SoramitsuLoadingView.self, v.view).first)
    XCTAssertFalse(loading.isHidden)
    XCTAssertTrue(loading.isUserInteractionEnabled)
  }
  func testLoadingCanBeDismissedAfterAnAsyncOperation() async throws {
    let (v, _) = make()
    v.showLoading()
    v.hideLoading()
    await settle()
    XCTAssertTrue(try XCTUnwrap(descendants(SoramitsuLoadingView.self, v.view).first).isHidden)
  }
  func testAccountOptionsKeepsAVisibleCloseAffordance() {
    let (v, _) = make()
    XCTAssertNotNil(v.navigationItem.leftBarButtonItem ?? v.navigationItem.rightBarButtonItem)
    XCTAssertEqual(v.navigationItem.largeTitleDisplayMode, .never)
  }
  func testPhraseRouteStopsAtTheDisclosureScreen() throws {
    let host = OptionsRouteHost()
    let nav = UINavigationController(rootViewController: host)
    route().showPassphrase(from: host, account: account())
    let warning = try XCTUnwrap(nav.topViewController as? AccountWarningViewController)
    XCTAssertNotNil(warning.completion)
    XCTAssertTrue(warning.hidesBottomBarWhenPushed)
    XCTAssertEqual(nav.viewControllers.count, 2)
  }
  func testSeedRouteStopsAtTheDisclosureScreen() throws {
    let host = OptionsRouteHost()
    let nav = UINavigationController(rootViewController: host)
    route().showRawSeed(from: host, account: account())
    XCTAssertTrue(nav.topViewController is AccountWarningViewController)
    XCTAssertEqual(nav.viewControllers.count, 2)
  }
  func testJsonRouteStopsAtTheDisclosureScreen() throws {
    let host = OptionsRouteHost()
    let nav = UINavigationController(rootViewController: host)
    route().showJson(account: account(), from: host)
    XCTAssertTrue(nav.topViewController is AccountWarningViewController)
    XCTAssertEqual(nav.viewControllers.count, 2)
  }
  func testDisclosureRoutesWithoutNavigationCannotPresentSecrets() {
    let host = OptionsRouteHost()
    let r = route()
    r.showPassphrase(from: host, account: account())
    r.showRawSeed(from: host, account: account())
    r.showJson(account: account(), from: host)
    XCTAssertTrue(host.shown.isEmpty)
  }
  func testBackPopsPushedAccountOptions() async {
    let root = UIViewController()
    let host = OptionsRouteHost()
    let nav = UINavigationController(rootViewController: root)
    nav.pushViewController(host, animated: false)
    route().back(from: host)
    await settle()
    XCTAssertTrue(nav.topViewController === root)
  }
  func testBackDismissesUncontainedAccountOptions() async {
    let host = OptionsRouteHost()
    route().back(from: host)
    await settle()
    XCTAssertEqual(host.dismissals, 1)
  }
  func testBackDismissesTheWholePresentedContainerAtItsRoot() async {
    let host = OptionsRouteHost()
    let nav = UINavigationController(rootViewController: host)
    let container = OptionsRouteHost()
    container.addChild(nav)
    route().back(from: host)
    await settle()
    XCTAssertEqual(container.dismissals, 1)
    XCTAssertEqual(host.dismissals, 0)
  }
  func testDeletionDismissesTheContainerInsteadOfReturningToStaleWalletRows() async {
    let root = UIViewController()
    let host = OptionsRouteHost()
    let nav = UINavigationController(rootViewController: root)
    let container = OptionsRouteHost()
    nav.pushViewController(host, animated: false)
    container.addChild(nav)
    route().dismissAfterDeletion(from: host)
    await settle()
    XCTAssertEqual(container.dismissals, 1)
    XCTAssertTrue(nav.topViewController === host)
  }
  func testMissingOptionsViewCanBeDismissedSafely() async {
    let r = route()
    r.back(from: nil)
    r.dismissAfterDeletion(from: nil)
    await settle()
  }
  func testBackupPasswordRoutePresentsAContainedPasswordScreen() throws {
    let host = OptionsRouteHost()
    route().setupBackupAccountPassword(
      on: host, account: OpenBackupAccount(name: "Fixture", address: "public-test-wallet"),
      completion: {})
    let blur = try XCTUnwrap(host.shown.first as? BlurViewController)
    XCTAssertEqual(blur.modalPresentationStyle, .overFullScreen)
    let nav = try XCTUnwrap(blur.children.first as? UINavigationController)
    XCTAssertTrue(nav.topViewController is SetupPasswordViewController)
  }
}
private final class OptionsScreenPresenter: AccountOptionsPresenterProtocol {
  var setupCount = 0, copies = 0, phrases = 0, seeds = 0, jsons = 0, logouts = 0, backups = 0,
    deletions = 0, names = [String]()
  func setup() { setupCount += 1 }
  func showPassphrase() { phrases += 1 }
  func showRawSeed() { seeds += 1 }
  func showJson() { jsons += 1 }
  func doLogout() { logouts += 1 }
  func didUpdateUsername(_ new: String) { names.append(new) }
  func copyToClipboard() { copies += 1 }
  func deleteBackup() { deletions += 1 }
  func createBackup() { backups += 1 }
}
private final class OptionsRouteHost: UIViewController, AccountOptionsViewProtocol {
  var shown = [UIViewController](), dismissals = 0
  override func present(
    _ viewControllerToPresent: UIViewController, animated: Bool, completion: (() -> Void)? = nil
  ) {
    shown.append(viewControllerToPresent)
    completion?()
  }
  override func dismiss(animated: Bool, completion: (() -> Void)? = nil) {
    dismissals += 1
    completion?()
  }
  func didReceive(username: String) {}
  func didReceive(address: String) {}
  func setupOptions(with backUpState: BackupState, hasEntropy: Bool) {}
  func showLoading() {}
  func hideLoading() {}
}

// These route tests exercise real navigation stack semantics without a visible
// window. Complete transitions synchronously before simulating authorization.
private final class OptionsRouteNavigation: UINavigationController {
  override func pushViewController(_ viewController: UIViewController, animated: Bool) {
    super.pushViewController(viewController, animated: false)
  }
  override func setViewControllers(_ viewControllers: [UIViewController], animated: Bool) {
    super.setViewControllers(viewControllers, animated: false)
  }
}

@MainActor
final class AccountOptionsAuthorizationRouteTests: XCTestCase {
  private enum Route: CaseIterable { case phrase, seed, json }
  @MainActor private final class Fixture {
    let host = OptionsRouteHost()
    let destination = UIViewController()
    lazy var navigation = OptionsRouteNavigation(rootViewController: host)
    var requests = [(Route, AccountItem)]()
    var authorization = [AuthorizationCompletionBlock]()
    var factoryAvailable = true
    lazy var route = AccountOptionsWireframe(localizationManager: LocalizationManager.shared,
      environment: AccountOptionsRouteEnvironment(
        authorize: { [unowned self] _, completion in self.authorization.append(completion) },
        passphrase: { [unowned self] in self.make(.phrase, $0) },
        rawSeed: { [unowned self] in self.make(.seed, $0) },
        json: { [unowned self] in self.make(.json, $0) }))
    let account = AccountItem(address: "isolated-route-wallet", cryptoType: .sr25519, networkType: 69,
      username: "Private fixture", publicKeyData: Data(repeating: 1, count: 32),
      settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: 0, isSelected: false)
    func make(_ kind: Route, _ account: AccountItem) -> UIViewController? {
      requests.append((kind, account)); return factoryAvailable ? destination : nil
    }
    func show(_ kind: Route) throws -> AccountWarningViewController {
      _ = navigation
      switch kind {
      case .phrase: route.showPassphrase(from: host, account: account)
      case .seed: route.showRawSeed(from: host, account: account)
      case .json: route.showJson(account: account, from: host)
      }
      let warning = try XCTUnwrap(navigation.topViewController as? AccountWarningViewController)
      XCTAssertTrue(authorization.isEmpty, "Disclosure must precede authorization")
      XCTAssertTrue(requests.isEmpty, "Secrets cannot be assembled before consent")
      warning.completion?()
      XCTAssertEqual(authorization.count, 1)
      return warning
    }
  }
  private func assertAllowed(_ kind: Route) throws {
    let f = Fixture(); let warning = try f.show(kind)
    f.authorization[0](true)
    XCTAssertEqual(f.requests.map(\.0), [kind])
    XCTAssertEqual(f.requests.first?.1.address, f.account.address)
    XCTAssertEqual(f.navigation.viewControllers.count, 2)
    XCTAssertTrue(f.navigation.topViewController === f.destination)
    XCTAssertFalse(f.navigation.viewControllers.contains { $0 === warning })
    XCTAssertTrue(f.navigation.viewControllers.first === f.host)
  }
  private func assertDenied(_ kind: Route) throws {
    let f = Fixture(); let warning = try f.show(kind)
    f.authorization[0](false)
    XCTAssertTrue(f.requests.isEmpty)
    XCTAssertTrue(f.navigation.topViewController === warning)
  }
  private func assertFactoryFailure(_ kind: Route) throws {
    let f = Fixture(); f.factoryAvailable = false; let warning = try f.show(kind)
    f.authorization[0](true)
    XCTAssertEqual(f.requests.map(\.0), [kind])
    XCTAssertTrue(f.navigation.topViewController === warning)
  }
  func testAuthorizedPhraseReplacesOnlyTheDisclosureWithTheExactAccount() throws { try assertAllowed(.phrase) }
  func testAuthorizedSeedReplacesOnlyTheDisclosureWithTheExactAccount() throws { try assertAllowed(.seed) }
  func testAuthorizedJsonReplacesOnlyTheDisclosureWithTheExactAccount() throws { try assertAllowed(.json) }
  func testDeniedPhraseDoesNotBuildASecretScreen() throws { try assertDenied(.phrase) }
  func testDeniedSeedDoesNotBuildASecretScreen() throws { try assertDenied(.seed) }
  func testDeniedJsonDoesNotBuildASecretScreen() throws { try assertDenied(.json) }
  func testUnavailablePhraseFactoryPreservesTheDisclosure() throws { try assertFactoryFailure(.phrase) }
  func testUnavailableSeedFactoryPreservesTheDisclosure() throws { try assertFactoryFailure(.seed) }
  func testUnavailableJsonFactoryPreservesTheDisclosure() throws { try assertFactoryFailure(.json) }
  func testAuthorizationAfterNavigatingAwayCannotRemoveTheNewScreen() throws {
    for kind in Route.allCases {
      let f = Fixture(); _ = try f.show(kind)
      let replacement = UIViewController()
      f.navigation.setViewControllers([f.host, replacement], animated: false)
      f.authorization[0](true)
      XCTAssertTrue(f.navigation.topViewController === replacement)
      XCTAssertTrue(f.requests.isEmpty)
    }
  }
  func testAuthorizationAfterRemovingTheOptionsHostDoesNotOpenSecrets() throws {
    for kind in Route.allCases {
      let f = Fixture(); _ = try f.show(kind)
      let replacement = UIViewController()
      f.navigation.setViewControllers([replacement], animated: false)
      XCTAssertNil(f.host.navigationController)
      f.authorization[0](true)
      XCTAssertTrue(f.navigation.topViewController === replacement)
      XCTAssertTrue(f.requests.isEmpty)
    }
  }
  func testDuplicateAuthorizationCompletionCannotReplaceTheExportScreen() throws {
    let f = Fixture(); _ = try f.show(.json)
    f.authorization[0](true); f.authorization[0](true)
    XCTAssertEqual(f.requests.count, 1)
    XCTAssertTrue(f.navigation.topViewController === f.destination)
  }
  func testDeniedLogoutDoesNotPresentConfirmationOrDeleteTheWallet() {
    let f = Fixture(); var deletions = 0
    f.route.showLogout(from: f.host, isNeedCustomNodeText: false) { deletions += 1 }
    XCTAssertEqual(f.authorization.count, 1)
    f.authorization[0](false)
    XCTAssertTrue(f.host.shown.isEmpty)
    XCTAssertEqual(deletions, 0)
  }
  func testAuthorizedLogoutStillRequiresTheDestructiveConfirmation() throws {
    let f = Fixture(); var deletions = 0
    f.route.showLogout(from: f.host, isNeedCustomNodeText: false) { deletions += 1 }
    f.authorization[0](true)
    let alert = try XCTUnwrap(f.host.shown.last as? UIAlertController)
    XCTAssertEqual(alert.preferredStyle, .alert)
    XCTAssertEqual(alert.actions.map(\.style), [.cancel, .destructive])
    XCTAssertEqual(deletions, 0)
    let action = try XCTUnwrap(alert.actions.last)
    let block = try XCTUnwrap(action.value(forKey: "handler"))
    unsafeBitCast(block as AnyObject, to: (@convention(block) (UIAlertAction) -> Void).self)(action)
    XCTAssertEqual(deletions, 1)
  }
  func testLogoutWithCustomNodesAddsTheRemovalExplanation() throws {
    let normal = Fixture(), custom = Fixture()
    normal.route.showLogout(from: normal.host, isNeedCustomNodeText: false, completionBlock: nil)
    custom.route.showLogout(from: custom.host, isNeedCustomNodeText: true, completionBlock: nil)
    normal.authorization[0](true); custom.authorization[0](true)
    let normalAlert = try XCTUnwrap(normal.host.shown.last as? UIAlertController)
    let customAlert = try XCTUnwrap(custom.host.shown.last as? UIAlertController)
    let normalMessage = try XCTUnwrap(normalAlert.message)
    XCTAssertTrue(customAlert.message?.hasPrefix(normalMessage + "\n\n") == true)
    XCTAssertEqual(normalAlert.title, customAlert.title)
  }
  func testCancellingLogoutHasNoDeletionHandler() throws {
    let f = Fixture(); var deletions = 0
    f.route.showLogout(from: f.host, isNeedCustomNodeText: false) { deletions += 1 }
    f.authorization[0](true)
    let alert = try XCTUnwrap(f.host.shown.last as? UIAlertController)
    let cancel = try XCTUnwrap(alert.actions.first { $0.style == .cancel })
    XCTAssertNil(cancel.value(forKey: "handler"))
    XCTAssertEqual(deletions, 0)
  }
  func testAuthorizedLogoutWithoutAHostCannotDeleteAutomatically() {
    let f = Fixture(); var deletions = 0
    f.route.showLogout(from: nil, isNeedCustomNodeText: false) { deletions += 1 }
    f.authorization[0](true)
    XCTAssertEqual(deletions, 0)
    XCTAssertTrue(f.host.shown.isEmpty)
  }
}
