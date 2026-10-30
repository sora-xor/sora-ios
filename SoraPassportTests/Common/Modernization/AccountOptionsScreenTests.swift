// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0
import SoraFoundation
import SoraUIKit
import SSFCloudStorage
import UIKit
import XCTest
@testable import SoraPassport

@MainActor
final class AccountOptionsScreenTests: XCTestCase {
    private var language = "en"
    override func setUp() { super.setUp(); language = LocalizationManager.shared.selectedLocalization; LocalizationManager.shared.selectedLocalization = "en" }
    override func tearDown() { LocalizationManager.shared.selectedLocalization = language; super.tearDown() }
    private func descendants<T: UIView>(_ type: T.Type, in view: UIView) -> [T] {
        ((view as? T).map { [$0] } ?? []) + view.subviews.flatMap { descendants(type, in: $0) }
    }
    private func screen() -> (AccountOptionsViewController, OptionsScreenPresenter) {
        let screen = AccountOptionsViewController(); let presenter = OptionsScreenPresenter()
        screen.presenter = presenter; screen.localizationManager = LocalizationManager.shared
        screen.loadViewIfNeeded(); screen.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844); screen.view.layoutIfNeeded()
        return (screen, presenter)
    }
    func testScreenLoadsPresenterAndDisplaysCurrentAccountFields() throws {
        let (screen, presenter) = screen(); XCTAssertEqual(presenter.calls, ["setup"])
        screen.didReceive(username: "Alice"); screen.didReceive(address: "public-address")
        XCTAssertEqual(try XCTUnwrap(descendants(InputField.self, in: screen.view).first).textField.text, "Alice")
        XCTAssertEqual(screen.addressLabel.text, "public-address")
        XCTAssertNotNil(screen.navigationItem.title); XCTAssertNotNil(screen.navigationItem.rightBarButtonItem)
    }
    func testUsernameEditingForwardsTheCurrentText() throws {
        let (screen, presenter) = screen(); let field = try XCTUnwrap(descendants(InputField.self, in: screen.view).first)
        field.textField.text = "New name"; field.textField.sendActions(for: .editingChanged)
        field.textField.text = ""; field.textField.sendActions(for: .editingChanged)
        XCTAssertEqual(presenter.names, ["New name", ""])
    }
    func testExportAndForgetActionsRouteThroughPresenter() {
        let (screen, presenter) = screen(); screen.passphraseTapped(); screen.rawSeedTapped(); screen.jsoneTapped(); screen.logoutTapped()
        XCTAssertEqual(presenter.calls, ["setup", "passphrase", "seed", "json", "logout"])
    }
    func testAddressControlCopiesThroughThePresenter() throws {
        let (screen, presenter) = screen()
        let card = try XCTUnwrap(screen.addressLabel.superview as? UIControl); card.sendActions(for: .touchUpInside)
        XCTAssertEqual(presenter.calls, ["setup", "copy"])
    }
    func testEntropyControlsWhetherPassphraseOptionIsShown() {
        let (screen, _) = screen(); screen.setupOptions(with: .notBackedUp, hasEntropy: true)
        XCTAssertEqual(descendants(AccountOptionItem.self, in: screen.view).count, 4)
        screen.setupOptions(with: .notBackedUp, hasEntropy: false)
        XCTAssertEqual(descendants(AccountOptionItem.self, in: screen.view).count, 3)
        XCTAssertFalse(descendants(AccountOptionItem.self, in: screen.view).contains { $0.titleLabel.text == R.string.localizable.exportAccountDetailsShowPassphrase(preferredLanguages: .currentLocale) })
    }
    func testBackupStateRefreshReplacesTheLastOptionWithoutDuplicatingRows() {
        let (screen, _) = screen(); screen.setupOptions(with: .notBackedUp, hasEntropy: true)
        screen.setupOptions(with: .backedUp, hasEntropy: true)
        let options = descendants(AccountOptionItem.self, in: screen.view)
        XCTAssertEqual(options.count, 4); XCTAssertEqual(options.last?.titleLabel.text, BackupState.backedUp.optionTitle)
        screen.setupOptions(with: .notBackedUp, hasEntropy: true)
        XCTAssertEqual(descendants(AccountOptionItem.self, in: screen.view).last?.titleLabel.text, BackupState.notBackedUp.optionTitle)
    }
    func testLoadingOverlayCanBeShownAndDismissed() async throws {
        let (screen, _) = screen(); let loading = try XCTUnwrap(descendants(SoramitsuLoadingView.self, in: screen.view).first)
        XCTAssertTrue(loading.isHidden); screen.showLoading(); XCTAssertFalse(loading.isHidden)
        screen.hideLoading(); try await Task.sleep(nanoseconds: 20_000_000); XCTAssertTrue(loading.isHidden)
    }
    func testAccountOptionsLocalizesItsChromeOnLanguageChange() {
        let (screen, _) = screen(); screen.applyLocalization(); let english = screen.navigationItem.title
        LocalizationManager.shared.selectedLocalization = "ja"; screen.applyLocalization()
        XCTAssertEqual(screen.navigationItem.title, R.string.localizable.exportAccountOptions(preferredLanguages: ["ja"]))
        XCTAssertNotEqual(screen.navigationItem.title, english)
    }
    func testPresenterSetupUsesAccountAndBackupStateFromItsInteractor() {
        let presenter = AccountOptionsPresenter(backupState: .backedUp); let source = OptionsInteractor(); let view = OptionsViewSpy()
        presenter.interactor = source; presenter.view = view; presenter.setup()
        XCTAssertEqual(view.username, "Fixture"); XCTAssertEqual(view.address, "public-address"); XCTAssertEqual(view.states.count, 1)
        XCTAssertTrue(view.states.first?.0 == .backedUp); XCTAssertTrue(view.states.first?.1 == true)
        presenter.didUpdateUsername("Updated"); XCTAssertEqual(source.names, ["Updated"])
    }
    func testPresenterLogoutWaitsForConfirmationBeforeCallingTheInteractor() async {
        let presenter = AccountOptionsPresenter(backupState: .notBackedUp); let source = OptionsInteractor(); let route = OptionsRoute(); let view = OptionsViewSpy()
        presenter.interactor = source; presenter.wireframe = route; presenter.view = view
        source.lastWithNodes = true; presenter.doLogout(); try? await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertEqual(route.customNodeWarnings, [true]); XCTAssertEqual(source.logouts, 0)
        route.confirmation?(); XCTAssertEqual(source.logouts, 1)
    }
    func testPresenterSuccessfulBackupDeletionUpdatesTheVisibleState() async {
        let presenter = AccountOptionsPresenter(backupState: .backedUp); let source = OptionsInteractor(); let route = OptionsRoute(); let view = OptionsViewSpy()
        presenter.interactor = source; presenter.wireframe = route; presenter.view = view; presenter.deleteBackup()
        try? await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertEqual(route.authorizationRequests, 1); XCTAssertEqual(source.deletions, 1); XCTAssertEqual(view.loading, 1); XCTAssertEqual(view.hidden, 1)
        XCTAssertTrue(view.states.last?.0 == .notBackedUp)
    }
    func testPresenterCloseAndRestartUseDistinctRoutes() {
        let presenter = AccountOptionsPresenter(backupState: .notBackedUp); let route = OptionsRoute()
        presenter.wireframe = route; presenter.close(); presenter.restart()
        XCTAssertEqual(route.routes, ["dismissAfterDeletion", "root"])
    }
}
private final class OptionsScreenPresenter: AccountOptionsPresenterProtocol {
    var calls: [String] = []; var names: [String] = []
    func setup() { calls.append("setup") }
    func showPassphrase() { calls.append("passphrase") }
    func showRawSeed() { calls.append("seed") }
    func showJson() { calls.append("json") }
    func doLogout() { calls.append("logout") }
    func didUpdateUsername(_ new: String) { names.append(new) }
    func copyToClipboard() { calls.append("copy") }
    func deleteBackup() { calls.append("delete") }
    func createBackup() { calls.append("create") }
}
private final class OptionsInteractor: AccountOptionsInteractorInputProtocol {
    let currentAccount = AccountItem(address: "public-address", cryptoType: .sr25519, networkType: 69, username: "Fixture", publicKeyData: Data(repeating: 1, count: 32), settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: 0, isSelected: true)
    var accountHasEntropy = true; var lastWithNodes = false; var names: [String] = []; var logouts = 0; var deletions = 0
    func getMetadata() -> AccountCreationMetadata? { nil }
    func isLastAccountWithCustomNodes(completion: @escaping (Bool) -> Void) { completion(lastWithNodes) }
    func logoutAndClean() { logouts += 1 }
    func updateUsername(_ username: String) { names.append(username) }
    var backedUp = false, deferCloud = false; var deleteError: Error?; var cloudAccount: OpenBackupAccount?; var cloudCompletion: ((AccountOptionsCloudBackupPreparation) -> Void)?
    // `lapses` makes that many operations report a lapsed authorization first.
    var signIns = 0, lapses = 0; var grants: [AccountOptionsCloudBackupAuthorization] = [], authorizations: [AccountOptionsCloudBackupAuthorization] = []
    func makeCloudBackupAuthorization() -> AccountOptionsCloudBackupAuthorization {
        let grant = AccountOptionsCloudBackupAuthorization(accountAddress: currentAccount.address, selectedAddress: { nil }, eventCenter: EventCenter(), notificationCenter: NotificationCenter())
        grants.append(grant); return grant
    }
    func checkCurrentAccountBackedup() async -> Bool { backedUp }
    func deleteBackup(authorization: AccountOptionsCloudBackupAuthorization, completion: @escaping (Error?) -> Void) {
        deletions += 1; authorizations.append(authorization)
        if lapses > 0 { lapses -= 1; completion(AccountOptionsCloudBackupError.authorizationRequired) } else { completion(deleteError) }
    }
    func signInToGoogleIfNeeded(authorization: AccountOptionsCloudBackupAuthorization, completion: ((AccountOptionsCloudBackupPreparation) -> Void)?) {
        signIns += 1; authorizations.append(authorization); cloudCompletion = completion
        if lapses > 0 { lapses -= 1; completion?(.authorizationRequired) } else if !deferCloud { completion?(cloudAccount.map(AccountOptionsCloudBackupPreparation.ready) ?? .unavailable) }
    }
}
private final class OptionsViewSpy: UIViewController, AccountOptionsViewProtocol {
    var alertModels: [AlertPresentableViewModel] = [], alertTitles: [String] = [], alertMessages: [String] = []
    func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?) { alertTitles.append(title ?? ""); alertMessages.append(message ?? "") }
    func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?) { alertModels.append(viewModel) }
    var controller: UIViewController { self }; var username = ""; var address = ""; var states: [(BackupState, Bool)] = []; var loading = 0; var hidden = 0
    func didReceive(username: String) { self.username = username }
    func didReceive(address: String) { self.address = address }
    func setupOptions(with backUpState: BackupState, hasEntropy: Bool) { states.append((backUpState, hasEntropy)) }
    func showLoading() { loading += 1 }
    func hideLoading() { hidden += 1 }
}
private final class OptionsRoute: AccountOptionsWireframeProtocol {
    var activityIndicatorWindow: UIWindow?
    var accounts: [AccountItem] = []; var backupAccounts: [OpenBackupAccount] = []; var backupCompletion: (() -> Void)?
    var routes: [String] = []; var customNodeWarnings: [Bool] = []; var confirmation: (() -> Void)?
    func showPassphrase(from view: AccountOptionsViewProtocol?, account: AccountItem) { routes.append("passphrase"); accounts.append(account) }
    func showRawSeed(from view: AccountOptionsViewProtocol?, account: AccountItem) { routes.append("seed"); accounts.append(account) }
    func showJson(account: AccountItem, from view: AccountOptionsViewProtocol?) { routes.append("json"); accounts.append(account) }
    func showRoot() { routes.append("root") }
    func back(from view: AccountOptionsViewProtocol?) { routes.append("back") }
    func dismissAfterDeletion(from view: AccountOptionsViewProtocol?) { routes.append("dismissAfterDeletion") }
    func showLogout(from view: AccountOptionsViewProtocol?, isNeedCustomNodeText: Bool, completionBlock: (() -> Void)?) { customNodeWarnings.append(isNeedCustomNodeText); confirmation = completionBlock }
    func setupBackupAccountPassword(on controller: AccountOptionsViewProtocol?, account: OpenBackupAccount, completion: @escaping () -> Void) { routes.append("backup"); backupAccounts.append(account); backupCompletion = completion }
    // Answers at once unless `authorizationResult` is nil; then the owner has not answered yet.
    var authorizationResult: Bool? = true; var authorizationRequests = 0; var pendingAuthorization: AuthorizationCompletionBlock?
    func authorizeCloudBackup(from view: AccountOptionsViewProtocol?, completion: @escaping AuthorizationCompletionBlock) {
        authorizationRequests += 1
        if let authorizationResult { completion(authorizationResult) } else { pendingAuthorization = completion }
    }
}

@MainActor
final class AccountOptionsPresenterLifecycleTests: XCTestCase {
    private var savedAddresses: Any?, backupAddresses: Any?
    override func setUp() { super.setUp(); savedAddresses = UserDefaults.standard.object(forKey: "savedAddresses"); backupAddresses = UserDefaults.standard.object(forKey: "backupedAccountAddresses"); UserDefaults.standard.set([], forKey: "savedAddresses"); UserDefaults.standard.set([], forKey: "backupedAccountAddresses") }
    override func tearDown() { UserDefaults.standard.set(savedAddresses, forKey: "savedAddresses"); UserDefaults.standard.set(backupAddresses, forKey: "backupedAccountAddresses"); super.tearDown() }
    private func fixture(_ state: BackupState = .notBackedUp) -> (AccountOptionsPresenter, OptionsInteractor, OptionsViewSpy, OptionsRoute) {
        let p = AccountOptionsPresenter(backupState: state), i = OptionsInteractor(), v = OptionsViewSpy(), r = OptionsRoute()
        p.interactor = i; p.view = v; p.wireframe = r; return (p, i, v, r)
    }
    private func settle() async { for _ in 0..<10 { await Task.yield() }; try? await Task.sleep(nanoseconds: 30_000_000) }
    func testRecoveryRoutesUseTheExactAccountAndMarkItAvailableOnce() {
        let (p, i, _, r) = fixture()
        p.showPassphrase(); p.showRawSeed(); p.showJson()
        XCTAssertEqual(r.routes, ["passphrase", "seed", "json"])
        XCTAssertEqual(r.accounts, [i.currentAccount, i.currentAccount, i.currentAccount])
        XCTAssertEqual(UserDefaults.standard.array(forKey: "savedAddresses") as? [String], [i.currentAccount.address])
    }
    func testCloudBackupStartsLoadingBeforeAuthorizationCompletes() async {
        let (p, i, v, r) = fixture(); i.deferCloud = true
        p.createBackup(); XCTAssertEqual(v.loading, 1); XCTAssertEqual(v.hidden, 0); XCTAssertTrue(r.routes.isEmpty)
        i.cloudCompletion?(.ready(OpenBackupAccount(address: i.currentAccount.address))); await settle()
        XCTAssertEqual(v.hidden, 1); XCTAssertEqual(r.routes, ["backup"]); XCTAssertEqual(r.backupAccounts.map(\.address), [i.currentAccount.address])
    }
    func testCancelledCloudAuthorizationStopsLoadingWithoutAPasswordScreen() async {
        let (p, _, v, r) = fixture(); p.createBackup(); await settle()
        XCTAssertEqual(v.loading, 1); XCTAssertEqual(v.hidden, 1); XCTAssertTrue(r.routes.isEmpty); XCTAssertTrue(v.alertModels.isEmpty)
    }
    func testExistingCloudBackupShowsReviewBeforeOpeningItsPasswordScreen() async throws {
        let (p, i, v, r) = fixture(); i.backedUp = true; i.cloudAccount = OpenBackupAccount(address: i.currentAccount.address)
        p.createBackup(); await settle()
        XCTAssertTrue(v.states.last?.0 == .backedUp); XCTAssertTrue(r.routes.isEmpty)
        XCTAssertTrue(ApplicationConfig.shared.backupedAccountAddresses.contains(i.currentAccount.address))
        let alert = try XCTUnwrap(v.alertModels.first); XCTAssertEqual(alert.actions.count, 1); XCTAssertNotNil(alert.closeAction)
        alert.actions[0].handler?(); XCTAssertEqual(r.routes, ["backup"])
    }
    func testPasswordCompletionReflectsTheActualSavedBackupMarker() async {
        for saved in [false, true] {
            let (p, i, v, r) = fixture(); i.cloudAccount = OpenBackupAccount(address: i.currentAccount.address)
            p.createBackup(); await settle()
            ApplicationConfig.shared.backupedAccountAddresses = saved ? [i.currentAccount.address] : []
            r.backupCompletion?(); await settle()
            XCTAssertTrue(v.states.last?.0 == (saved ? .backedUp : .notBackedUp))
            XCTAssertTrue(v.states.last?.1 == true)
        }
    }
    func testFailedCloudDeletionPreservesTheBackedUpStateAndShowsItsError() async {
        let (p, i, v, _) = fixture(.backedUp); i.deleteError = NSError(domain: "backup-test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Backup unavailable"])
        p.setup(); p.deleteBackup(); await settle()
        XCTAssertTrue(v.states.last?.0 == .backedUp); XCTAssertEqual(v.hidden, 1); XCTAssertEqual(v.alertTitles.last, "Backup unavailable")
    }
    func testCloudBackupReadsNothingUntilTheWalletAuthorizationSucceeds() {
        let (p, i, v, r) = fixture(); r.authorizationResult = nil; i.cloudAccount = OpenBackupAccount(address: i.currentAccount.address)
        p.createBackup()
        XCTAssertEqual(r.authorizationRequests, 1); XCTAssertEqual(i.signIns, 0); XCTAssertTrue(i.grants.isEmpty)
        XCTAssertEqual(v.loading, 0); XCTAssertTrue(r.routes.isEmpty)
        XCTAssertEqual(UserDefaults.standard.array(forKey: "savedAddresses") as? [String], [])
    }
    func testCancelledWalletAuthorizationLeavesTheCloudBackupFlowUntouched() async {
        let (p, i, v, r) = fixture(); r.authorizationResult = nil; i.cloudAccount = OpenBackupAccount(address: i.currentAccount.address)
        p.createBackup(); r.pendingAuthorization?(false); await settle()
        XCTAssertEqual(i.signIns, 0); XCTAssertTrue(i.grants.isEmpty); XCTAssertEqual(v.loading, 0); XCTAssertEqual(v.hidden, 0)
        XCTAssertTrue(r.routes.isEmpty); XCTAssertTrue(v.states.isEmpty); XCTAssertTrue(v.alertModels.isEmpty)
        XCTAssertEqual(UserDefaults.standard.array(forKey: "savedAddresses") as? [String], [])
    }
    func testSuccessfulWalletAuthorizationStartsTheBackupWithItsOwnAuthorization() async {
        let (p, i, v, r) = fixture(); r.authorizationResult = nil; i.cloudAccount = OpenBackupAccount(address: i.currentAccount.address)
        p.createBackup(); r.pendingAuthorization?(true); await settle()
        XCTAssertEqual(i.signIns, 1); XCTAssertEqual(i.grants.count, 1); XCTAssertTrue(i.authorizations.first === i.grants.first)
        XCTAssertEqual(i.grants.first?.accountAddress, i.currentAccount.address)
        XCTAssertEqual(v.loading, 1); XCTAssertEqual(v.hidden, 1); XCTAssertEqual(r.routes, ["backup"])
        XCTAssertEqual(UserDefaults.standard.array(forKey: "savedAddresses") as? [String], [i.currentAccount.address])
    }
    func testBackupDeletionReachesNothingUntilTheWalletAuthorizationSucceeds() {
        let (p, i, v, r) = fixture(.backedUp); r.authorizationResult = nil
        p.deleteBackup()
        XCTAssertEqual(r.authorizationRequests, 1); XCTAssertEqual(i.deletions, 0); XCTAssertTrue(i.grants.isEmpty); XCTAssertEqual(v.loading, 0)
    }
    func testCancelledWalletAuthorizationKeepsTheCloudBackup() async {
        let (p, i, v, r) = fixture(.backedUp); r.authorizationResult = nil
        p.deleteBackup(); r.pendingAuthorization?(false); await settle()
        XCTAssertEqual(i.deletions, 0); XCTAssertTrue(i.grants.isEmpty); XCTAssertEqual(v.loading, 0); XCTAssertEqual(v.hidden, 0)
        XCTAssertTrue(v.states.isEmpty); XCTAssertTrue(v.alertTitles.isEmpty)
    }
    func testSuccessfulWalletAuthorizationDeletesTheBackupWithItsOwnAuthorization() async {
        let (p, i, v, r) = fixture(.backedUp); r.authorizationResult = nil
        p.deleteBackup(); r.pendingAuthorization?(true); await settle()
        XCTAssertEqual(i.deletions, 1); XCTAssertEqual(i.grants.count, 1); XCTAssertTrue(i.authorizations.first === i.grants.first)
        XCTAssertEqual(v.loading, 1); XCTAssertEqual(v.hidden, 1); XCTAssertTrue(v.states.last?.0 == .notBackedUp)
    }
    func testLapsedAuthorizationIsAskedForAgainBeforeTheBackupIsRead() async {
        let (p, i, _, r) = fixture(); i.lapses = 1; i.cloudAccount = OpenBackupAccount(address: i.currentAccount.address)
        p.createBackup(); await settle()
        XCTAssertEqual(r.authorizationRequests, 2); XCTAssertEqual(i.signIns, 2)
        XCTAssertEqual(Set(i.authorizations.map { ObjectIdentifier($0) }).count, 2); XCTAssertEqual(r.routes, ["backup"])
    }
    func testAuthorizationThatLapsesAgainStopsWithoutAPasswordScreen() async {
        let (p, i, v, r) = fixture(); i.lapses = 2; i.cloudAccount = OpenBackupAccount(address: i.currentAccount.address)
        p.createBackup(); await settle()
        XCTAssertEqual(r.authorizationRequests, 2); XCTAssertEqual(i.signIns, 2); XCTAssertTrue(r.routes.isEmpty)
        XCTAssertEqual(v.loading, 2); XCTAssertEqual(v.hidden, 2); XCTAssertTrue(v.alertModels.isEmpty)
    }
    func testLapsedDeletionAuthorizationIsAskedForAgainBeforeDeleting() async {
        let (p, i, v, r) = fixture(.backedUp); i.lapses = 1
        p.deleteBackup(); await settle()
        XCTAssertEqual(r.authorizationRequests, 2); XCTAssertEqual(i.deletions, 2)
        XCTAssertEqual(Set(i.authorizations.map { ObjectIdentifier($0) }).count, 2)
        XCTAssertTrue(v.alertTitles.isEmpty); XCTAssertTrue(v.states.last?.0 == .notBackedUp)
    }
    func testDeletionAuthorizationThatLapsesAgainKeepsTheBackup() async {
        let (p, i, v, r) = fixture(.backedUp); i.lapses = 2
        p.deleteBackup(); await settle()
        XCTAssertEqual(r.authorizationRequests, 2); XCTAssertEqual(i.deletions, 2)
        XCTAssertTrue(v.alertTitles.isEmpty); XCTAssertTrue(v.states.isEmpty); XCTAssertEqual(v.hidden, 2)
    }
    func testBlockedDeletionStopsLoadingAndExplainsTheRecoveryReason() {
        let (p, _, v, _) = fixture(); p.accountDeletionBlocked(message: "Pending transaction")
        XCTAssertEqual(v.hidden, 1); XCTAssertEqual(v.alertTitles, ["Account deletion paused"]); XCTAssertEqual(v.alertMessages, ["Pending transaction"])
    }
    func testBackupAvailabilityIncludesSavedAndCloudAddressesWithoutDuplicates() {
        UserDefaults.standard.set(["one", "shared", "one"], forKey: "savedAddresses")
        ApplicationConfig.shared.backupedAccountAddresses = ["two", "shared"]
        XCTAssertEqual(Set(ApplicationConfig.shared.getAvailableBackupedAccounts()), ["one", "two", "shared"])
    }
}
