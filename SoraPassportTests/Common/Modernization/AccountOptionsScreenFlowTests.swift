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
