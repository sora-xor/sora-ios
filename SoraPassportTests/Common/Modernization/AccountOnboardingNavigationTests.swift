// SPDX-License-Identifier: Apache-2.0
import SoraFoundation
import SoraKeystore
import SoraUIKit
import SSFCloudStorage
import UIKit
import XCTest
@testable import SoraPassport

/// Builds the real destinations without starting account persistence or cloud authorization.
@MainActor
final class AccountOnboardingNavigationTests: XCTestCase {
    private var previousServices: [URLHandlingServiceProtocol] = []
    private var previousAccount: AccountItem?
    override func setUp() {
        super.setUp()
        previousServices = URLHandlingService.shared.children
        URLHandlingService.shared.setup(children: [KeystoreImportService(logger: Logger.shared)])
        previousAccount = SelectedWalletSettings.shared.currentAccount
        SelectedWalletSettings.shared.commitInternalValue(nil)
    }
    override func tearDown() {
        SelectedWalletSettings.shared.commitInternalValue(previousAccount)
        URLHandlingService.shared.setup(children: previousServices)
        super.tearDown()
    }
    private func drainMainQueue() async { await withCheckedContinuation { continuation in DispatchQueue.main.async { continuation.resume() } } }
    private func input(_ value: String) -> InputViewModel {
        InputViewModel(inputHandler: InputHandler(value: value, required: false, predicate: NSPredicate.notEmpty, processor: ByteLengthProcessor.username))
    }
    private func make() -> (OnboardingMainWireframe, OnboardingRouteHost, UINavigationController) {
        let route = OnboardingMainWireframe(), host = OnboardingRouteHost()
        route.endAddingBlock = {}
        return (route, host, UINavigationController(rootViewController: host))
    }
    func testSignupPushesTheCreatingNameScreenAndPreservesItsCompletion() async throws {
        let (route, host, nav) = make(); var completions = 0; route.endAddingBlock = { completions += 1 }
        route.showSignup(from: host, isGoogleBackupSelected: true); await drainMainQueue()
        let view = try XCTUnwrap(nav.topViewController as? SetupAccountNameViewController)
        let presenter = try XCTUnwrap(view.presenter as? UsernameSetupPresenter)
        XCTAssertEqual(presenter.mode, .creating); XCTAssertTrue(presenter.view === view)
        let destination = try XCTUnwrap(presenter.wireframe as? AddUsernameWireframe)
        destination.endAddingBlock?(); XCTAssertEqual(completions, 1)
    }
    func testSignupRequiresTheAddingCompletionAndANavigationStack() async {
        let (route, host, nav) = make(); route.endAddingBlock = nil
        route.showSignup(from: host, isGoogleBackupSelected: false); await drainMainQueue(); XCTAssertEqual(nav.viewControllers.count, 1)
        route.endAddingBlock = {}; route.showSignup(from: OnboardingRouteHost(), isGoogleBackupSelected: false); await drainMainQueue()
        XCTAssertEqual(nav.viewControllers.count, 1)
    }
    func testEveryRestoreSourcePushesTheMatchingImportPresenter() throws {
        for source in AccountImportSource.allCases {
            let (route, host, nav) = make(); route.showAccountRestoreRedesign(from: host, sourceType: source)
            let view = try XCTUnwrap(nav.topViewController as? ImportAccountViewController)
            let presenter = try XCTUnwrap(view.presenter as? AccountImportPresenter)
            XCTAssertEqual(presenter.selectedSourceType, source); XCTAssertTrue(presenter.view === view)
            XCTAssertNotNil(presenter.interactor); XCTAssertTrue(presenter.wireframe is AddImportedWireframe)
        }
    }
    func testKeystoreImportOnlyPushesFromTheRootOfTheFlow() throws {
        let (route, host, nav) = make(); route.showKeystoreImport(from: host)
        XCTAssertTrue(nav.topViewController is ImportAccountViewController); XCTAssertEqual(nav.viewControllers.count, 2)
        route.showKeystoreImport(from: host); XCTAssertEqual(nav.viewControllers.count, 2)
    }
    func testMissingImportServiceDoesNotPushAnIncompleteDestination() {
        URLHandlingService.shared.setup(children: [])
        let (route, host, nav) = make(); route.showAccountRestore(from: host); route.showAccountRestoreRedesign(from: host, sourceType: .keystore)
        XCTAssertEqual(nav.viewControllers.count, 1)
        XCTAssertNil(OnboardingMainViewFactory.createWelcomeViewForRoot())
        XCTAssertNil(OnboardingMainViewFactory.createWelcomeViewForChanging(endAddingBlock: {}))
        XCTAssertNil(SetupAccountNameViewFactory.createViewForCreationImport(endAddingBlock: {}))
    }
    func testRestoreWithoutAnAddingCompletionLeavesTheCurrentScreen() {
        let (route, host, nav) = make(); route.endAddingBlock = nil
        route.showAccountRestore(from: host); route.showAccountRestoreRedesign(from: host, sourceType: .mnemonic)
        XCTAssertEqual(nav.viewControllers.count, 1)
    }
    func testBackupSelectionPushesTheAccountChooser() async throws {
        let (route, host, nav) = make()
        route.showBackupedAccounts(from: host, accounts: [OpenBackupAccount(name: "Fixture", address: "public-account")])
        await drainMainQueue()
        let view = try XCTUnwrap(nav.topViewController as? BackupedAccountsViewController)
        XCTAssertNotNil(view.viewModel)
    }
    func testChangingAndRootWelcomeFactoriesUseTheirDistinctRoutes() throws {
        let changing = try XCTUnwrap(OnboardingMainViewFactory.createWelcomeViewForChanging(endAddingBlock: {}) as? WelcomeViewController)
        let root = try XCTUnwrap(OnboardingMainViewFactory.createWelcomeViewForRoot() as? WelcomeViewController)
        let changingPresenter = try XCTUnwrap(changing.presenter as? OnboardingMainPresenter)
        let rootPresenter = try XCTUnwrap(root.presenter as? OnboardingMainPresenter)
        XCTAssertTrue(changingPresenter.wireframe is OnboardingMainWireframe)
        XCTAssertTrue(rootPresenter.wireframe is OnboardingRootWireframe)
        XCTAssertTrue(changingPresenter.view === changing); XCTAssertTrue(rootPresenter.view === root)
        XCTAssertNotNil(changingPresenter.interactor); XCTAssertNotNil(rootPresenter.interactor)
    }
    func testAddingAndRootNameFactoriesChooseTheRequestedMode() throws {
        for mode in [UsernameSetupMode.onboarding, .editing, .creating] {
            let view = try XCTUnwrap(SetupAccountNameViewFactory.createViewForOnboarding(mode: mode) as? SetupAccountNameViewController)
            let presenter = try XCTUnwrap(view.presenter as? UsernameSetupPresenter)
            XCTAssertEqual(presenter.mode, mode); XCTAssertTrue(presenter.wireframe is UsernameSetupWireframe)
            XCTAssertTrue(presenter.view === view)
        }
    }
    func testImportNameFactoriesRetainEveryUserEnteredFieldAndTheCryptoScheme() throws {
        for source in AccountImportSource.allCases {
            let material = input("public fixture"), name = input("Wallet"), password = input("fixture password"), path = input("//fixture")
            let added = try XCTUnwrap(SetupAccountNameViewFactory.createViewForAddImport(sourceType: source, cryptoType: .ed25519, networkType: .sora, sourceViewModel: material, usernameViewModel: name, passwordViewModel: password, derivationPathViewModel: path, expectedAddress: "expected-public-address", endAddingBlock: {}) as? SetupAccountNameViewController)
            let presenter = try XCTUnwrap(added.presenter as? SetupNameImportAccountPresenter)
            XCTAssertEqual(presenter.sourceType, source); XCTAssertEqual(presenter.cryptoType, .ed25519); XCTAssertEqual(presenter.networkType, .sora)
            XCTAssertEqual(presenter.sourceViewModel.inputHandler.value, material.inputHandler.value); XCTAssertEqual(presenter.usernameViewModel.inputHandler.value, name.inputHandler.value)
            XCTAssertEqual(presenter.passwordViewModel?.inputHandler.value, password.inputHandler.value); XCTAssertEqual(presenter.derivationPathViewModel?.inputHandler.value, path.inputHandler.value)
            XCTAssertTrue(presenter.view === added); XCTAssertNotNil(presenter.interactor)
            let root = try XCTUnwrap(SetupAccountNameViewFactory.createViewForAccountImport(sourceType: source, cryptoType: .sr25519, networkType: .sora, sourceViewModel: material, usernameViewModel: name, passwordViewModel: nil, derivationPathViewModel: nil) as? SetupAccountNameViewController)
            let rootPresenter = try XCTUnwrap(root.presenter as? SetupNameImportRootPresenter)
            XCTAssertEqual(rootPresenter.sourceType, source); XCTAssertEqual(rootPresenter.cryptoType, .sr25519)
            XCTAssertEqual(rootPresenter.sourceViewModel.inputHandler.value, material.inputHandler.value); XCTAssertNil(rootPresenter.passwordViewModel); XCTAssertNil(rootPresenter.derivationPathViewModel)
            XCTAssertTrue(rootPresenter.view === root); XCTAssertNotNil(rootPresenter.interactor)
        }
    }
    func testImportNameFactoriesRequireTheImportService() {
        URLHandlingService.shared.setup(children: []); let value = input("fixture")
        XCTAssertNil(SetupAccountNameViewFactory.createViewForAddImport(sourceType: .seed, cryptoType: .sr25519, networkType: .sora, sourceViewModel: value, usernameViewModel: value, passwordViewModel: nil, derivationPathViewModel: nil, endAddingBlock: {}))
        XCTAssertNil(SetupAccountNameViewFactory.createViewForAccountImport(sourceType: .seed, cryptoType: .sr25519, networkType: .sora, sourceViewModel: value, usernameViewModel: value, passwordViewModel: nil, derivationPathViewModel: nil))
    }
    func testCreationImportFactoryPreservesItsCompletionAndWiresTheInteractor() throws {
        var completions = 0
        let view = try XCTUnwrap(SetupAccountNameViewFactory.createViewForCreationImport(endAddingBlock: { completions += 1 }) as? SetupAccountNameViewController)
        let presenter = try XCTUnwrap(view.presenter as? SetupNameCreateAccountPresenter)
        XCTAssertNotNil(presenter.interactor); XCTAssertTrue(presenter.view === view)
        presenter.completion?(); XCTAssertEqual(completions, 1)
    }
    func testChangingAccountsPresentsSignupInsideItsOwnNavigationController() throws {
        let host = OnboardingRouteHost(); ChangeAccountWireframe().showSignUp(from: host, completion: {})
        let nav = try XCTUnwrap(host.shown.last as? UINavigationController)
        XCTAssertEqual(nav.viewControllers.count, 1); XCTAssertTrue(nav.topViewController is SetupAccountNameViewController)
    }
    func testChangingAccountsPresentsImportInsideItsOwnNavigationController() throws {
        let host = OnboardingRouteHost(); ChangeAccountWireframe().showAccountRestore(from: host, completion: {})
        let nav = try XCTUnwrap(host.shown.last as? UINavigationController)
        XCTAssertEqual(nav.viewControllers.count, 1); XCTAssertTrue(nav.topViewController is ImportAccountViewController)
    }
    func testChangingAccountsDoesNotPresentAnImportWithoutItsService() {
        URLHandlingService.shared.setup(children: [])
        let host = OnboardingRouteHost(); ChangeAccountWireframe().showAccountRestore(from: host, completion: {})
        XCTAssertTrue(host.shown.isEmpty)
    }
    func testChangingAccountsStartsAWelcomeFlowInAnOverFullScreenContainer() throws {
        let host = OnboardingRouteHost(); ChangeAccountWireframe().showStart(from: host, completion: {})
        let container = try XCTUnwrap(host.shown.last as? BlurViewController)
        let nav = try XCTUnwrap(container.children.first as? UINavigationController)
        XCTAssertEqual(container.modalPresentationStyle, .overFullScreen); XCTAssertTrue(nav.topViewController is WelcomeViewController)
    }
    func testExportRouteRequiresTheWarningBeforeAuthentication() throws {
        let host = OnboardingRouteHost(), nav = UINavigationController(rootViewController: OnboardingRouteHost())
        nav.pushViewController(host, animated: false)
        ChangeAccountWireframe().showExportAccounts(accounts: [], from: host)
        let warning = try XCTUnwrap(nav.topViewController as? AccountWarningViewController)
        XCTAssertTrue(warning.hidesBottomBarWhenPushed); XCTAssertNotNil(warning.completion)
    }
    func testJsonExportRoutePushesItsWarningWithoutCreatingAnExportFile() throws {
        let host = OnboardingRouteHost(), nav = UINavigationController(rootViewController: OnboardingRouteHost())
        nav.pushViewController(host, animated: false)
        AccountExportWireframe(localizationManager: LocalizationManager.shared).showJson(from: host, accounts: [])
        XCTAssertTrue(nav.topViewController is AccountWarningViewController); XCTAssertEqual(nav.viewControllers.count, 3)
    }
    func testShareCancellationKeepsTheExportScreenAndSuccessReturnsToItsCaller() throws {
        let host = OnboardingRouteHost(), root = OnboardingRouteHost(), nav = UINavigationController(rootViewController: OnboardingRouteHost())
        nav.setViewControllers([root, host], animated: false)
        let route = AccountExportWireframe(localizationManager: LocalizationManager.shared)
        route.showShareFile(url: NSURL(fileURLWithPath: "/tmp/public-test-export.json"), in: host)
        let activity = try XCTUnwrap(host.shown.last as? UIActivityViewController)
        activity.completionWithItemsHandler?(nil, false, nil, nil); XCTAssertTrue(nav.topViewController === host)
        activity.completionWithItemsHandler?(.copyToPasteboard, true, nil, nil); XCTAssertTrue(nav.topViewController === root)
    }
    func testNameSetupStartsEmptyForNewWalletAndDefersProceedUntilWarningCompletes() throws {
        let view = OnboardingRouteHost(), route = UsernameRouteSpy(), presenter = UsernameSetupPresenter()
        presenter.mode = .creating; presenter.view = view; presenter.wireframe = route; presenter.setup()
        XCTAssertEqual(view.model?.inputHandler.value, "")
        presenter.viewModel = input("Fixture wallet"); presenter.proceed()
        XCTAssertTrue(route.names.isEmpty); XCTAssertNotNil(route.warning)
        route.warning?(); XCTAssertEqual(route.names, ["Fixture wallet"])
    }
    func testNameEditingCompletionRunsOnceAndWebLinksUseTheCurrentView() {
        let view = OnboardingRouteHost(), route = UsernameRouteSpy(), presenter = UsernameSetupPresenter()
        presenter.view = view; presenter.wireframe = route; var completions = 0
        presenter.successEditingBlock = { completions += 1 }; presenter.endEditing(); XCTAssertEqual(completions, 1)
        let url = URL(string: "https://sora.org/terms")!; presenter.activateURL(url); XCTAssertEqual(route.urls, [url]); XCTAssertTrue(route.webView === view)
        presenter.view = nil; presenter.activateURL(url); XCTAssertEqual(route.urls.count, 1)
    }
    func testBackupPasswordFactoryBuildsAndRendersTheChosenPublicAccount() throws {
        let account = OpenBackupAccount(name: "Fixture backup", address: "public-account")
        let view = try XCTUnwrap(EnterPasswordViewFactory.createView(with: account.address, backedUpAccounts: [account]) as? EnterPasswordViewController)
        XCTAssertNotNil(view.viewModel)
        view.loadViewIfNeeded()
        XCTAssertFalse(view.view.subviews.isEmpty)
    }
    func testBackupPasswordFactoryRequiresItsImportService() {
        URLHandlingService.shared.setup(children: [])
        XCTAssertNil(EnterPasswordViewFactory.createView(with: "public-account", backedUpAccounts: []))
    }
    func testConfirmationFactoriesBindTheSamePublicFixtureMnemonicToTheirInteractors() throws {
        let words = Array(repeating: "abandon", count: 11) + ["about"]
        let request = AccountCreationRequest(username: "Fixture", type: .sora, derivationPath: "", cryptoType: .sr25519)
        let metadata = AccountCreationMetadata(mnemonic: words, availableNetworks: [.sora], defaultNetwork: .sora, availableCryptoTypes: [.sr25519], defaultCryptoType: .sr25519)
        let first = try XCTUnwrap(AccountConfirmViewFactory.createViewForOnboardingRedesign(request: request, metadata: metadata)?.controller as? ConfirmPassphraseViewController)
        let second = try XCTUnwrap(AccountConfirmViewFactory.createViewForRedesignAdding(request: request, metadata: metadata, isNeedSetupName: false, endAddingBlock: {})?.controller as? ConfirmPassphraseViewController)
        for view in [first, second] {
            let model = try XCTUnwrap(view.viewModel as? ConfirmPassphraseViewModel)
            XCTAssertEqual(model.mnemonic, words); XCTAssertTrue(model.view === view); XCTAssertNotNil(model.interactor)
            view.loadViewIfNeeded(); XCTAssertNotNil(model.numbersItem); XCTAssertNotNil(model.quiz)
        }
    }
    func testConfirmationFactoriesRejectInvalidMnemonicBeforeBuildingAFlow() {
        let request = AccountCreationRequest(username: "Fixture", type: .sora, derivationPath: "", cryptoType: .sr25519)
        let metadata = AccountCreationMetadata(mnemonic: ["invalid"], availableNetworks: [.sora], defaultNetwork: .sora, availableCryptoTypes: [.sr25519], defaultCryptoType: .sr25519)
        XCTAssertNil(AccountConfirmViewFactory.createViewForOnboardingRedesign(request: request, metadata: metadata))
        XCTAssertNil(AccountConfirmViewFactory.createViewForRedesignAdding(request: request, metadata: metadata, endAddingBlock: nil))
    }
    func testCustomNodeFactoryWiresEveryEditingModeWithoutPersistingChanges() throws {
        let node = ChainNodeModel(url: URL(string: "wss://node.example.org")!, name: "Fixture", apikey: nil)
        let chain = ChainModel(chainId: "fixture-chain", name: "Fixture chain", nodes: [node], addressPrefix: 69, types: nil, icon: nil, options: nil, iosMinAppVersion: "1.0")
        for mode in [NodeAction.add, .select(node: node), .copy(node: node), .edit(node: node), .remove(node: node)] {
            let view = try XCTUnwrap(NodesViewFactory.customNodeView(with: chain, mode: mode, completion: nil) as? CustomNodeViewController)
            let presenter = try XCTUnwrap(view.presenter as? CustomNodePresenter)
            XCTAssertTrue(presenter.view === view); XCTAssertNotNil(presenter.interactor)
        }
    }
    func testAddNameWarningPreservesTheContinuationAndRequiresExplicitAction() throws {
        let view = OnboardingRouteHost(), nav = UINavigationController(rootViewController: OnboardingRouteHost())
        nav.pushViewController(view, animated: false); var completions = 0
        AddUsernameWireframe(localizationManager: LocalizationManager.shared, isNeedSetupName: true).showWarning(from: view) { completions += 1 }
        let warning = try XCTUnwrap(nav.topViewController as? AccountWarningViewController)
        XCTAssertEqual(completions, 0); warning.completion?(); XCTAssertEqual(completions, 1)
    }
}
private final class OnboardingRouteHost: UIViewController, OnboardingMainViewProtocol, AccountExportViewProtocol, UsernameSetupViewProtocol {
    var shown = [UIViewController](), model: InputViewModelProtocol?
    func showLoading() {}; func hideLoading() {}; func set(viewModel: InputViewModelProtocol) { model = viewModel }; func resetFocus() {}
    override func present(_ viewControllerToPresent: UIViewController, animated: Bool, completion: (() -> Void)? = nil) { shown.append(viewControllerToPresent); completion?() }
}
private final class UsernameRouteSpy: UsernameSetupWireframeProtocol {
    var names = [String](), urls = [URL](), warning: (() -> Void)?, webView: ControllerBackedProtocol?
    func proceed(from view: UsernameSetupViewProtocol?, username: String) { names.append(username) }
    func showPinCode(from view: UsernameSetupViewProtocol?) {}
    func showWarning(from view: UsernameSetupViewProtocol?, completion: @escaping () -> Void) { warning = completion }
    func showWeb(url: URL, from view: ControllerBackedProtocol, style: WebPresentableStyle) { urls.append(url); webView = view }
    func present(error: Swift.Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool { false }
    func present(error: Swift.Error, from view: ControllerBackedProtocol?, locale: Locale?, completion: @escaping () -> Void) -> Bool { false }
}

@MainActor final class OnboardingActionBoundaryTests: XCTestCase {
    private func make() -> (OnboardingMainPresenter, OnboardingActionHost, OnboardingActionInput, OnboardingActionRoute) {
        let presenter = OnboardingMainPresenter(locale: Locale(identifier: "en")), host = OnboardingActionHost(), input = OnboardingActionInput(), route = OnboardingActionRoute()
        presenter.view = host; presenter.interactor = input; presenter.wireframe = route
        return (presenter, host, input, route)
    }
    private func action(_ route: OnboardingActionRoute, _ index: Int) throws -> AlertPresentableAction {
        try XCTUnwrap(route.sheets.last?.actions[index])
    }
    func testSignupStartsTheLocalCreationFlowFromTheCurrentScreen() {
        let (p, host, input, route) = make(); p.activateSignup()
        XCTAssertEqual(route.signups, [false]); XCTAssertTrue(route.source === host); XCTAssertEqual(input.reads, 0)
    }
    func testKeystoreSuggestionRoutesTheCurrentScreenWithoutReadingCloudBackups() {
        let (p, host, input, route) = make(); p.didSuggestKeystoreImport()
        XCTAssertEqual(route.keystoreCount, 1); XCTAssertTrue(route.source === host); XCTAssertEqual(input.reads, 0)
    }
    func testRestoreSheetOffersCloudMnemonicAndSeedWithoutStartingAnImport() throws {
        let (p, host, input, route) = make(); p.activateAccountRestore()
        let sheet = try XCTUnwrap(route.sheets.last)
        XCTAssertEqual(route.styles, [.actionSheet]); XCTAssertTrue(route.source === host)
        XCTAssertEqual(sheet.title, R.string.localizable.recoveryTitleV2(preferredLanguages: .currentLocale))
        XCTAssertEqual(sheet.message, R.string.localizable.importAccountMessage(preferredLanguages: .currentLocale))
        XCTAssertEqual(sheet.closeAction, R.string.localizable.commonCancel(preferredLanguages: .currentLocale))
        XCTAssertEqual(sheet.actions.map(\.title), ["Google", R.string.localizable.recoveryPassphrase(preferredLanguages: .currentLocale), R.string.localizable.commonRawSeed(preferredLanguages: .currentLocale)])
        XCTAssertEqual(input.reads, 0); XCTAssertTrue(route.restore.isEmpty); XCTAssertTrue(route.signups.isEmpty)
    }
    func testMnemonicChoicePreservesItsSourceAndDoesNotOpenSeedImport() throws {
        let (p, host, _, route) = make(); p.activateAccountRestore(); try action(route, 1).handler?()
        XCTAssertEqual(route.restore, [.mnemonic]); XCTAssertTrue(route.source === host)
    }
    func testRawSeedChoicePreservesItsSourceAndDoesNotOpenMnemonicImport() throws {
        let (p, host, _, route) = make(); p.activateAccountRestore(); try action(route, 2).handler?()
        XCTAssertEqual(route.restore, [.seed]); XCTAssertTrue(route.source === host)
    }
    func testCloudChoiceRunsOneRequestAndUsesCloudSignupForAnEmptyAccountList() async throws {
        let (p, host, input, route) = make(); let finished = expectation(description: "cloud route")
        route.didFinish = { finished.fulfill() }; p.activateAccountRestore(); try action(route, 0).handler?()
        await fulfillment(of: [finished], timeout: 2)
        XCTAssertEqual(input.reads, 1); XCTAssertEqual(host.loading, [true, false]); XCTAssertEqual(route.signups, [true])
    }
    func testRetainedRestoreActionsDoNothingAfterPresenterRelease() throws {
        var p: OnboardingMainPresenter? = OnboardingMainPresenter(locale: Locale(identifier: "en"))
        let host = OnboardingActionHost(), input = OnboardingActionInput(), route = OnboardingActionRoute()
        p?.view = host; p?.interactor = input; p?.wireframe = route; p?.activateAccountRestore()
        let actions = try XCTUnwrap(route.sheets.last).actions; weak var released = p; p = nil
        XCTAssertNil(released); actions.forEach { $0.handler?() }
        XCTAssertTrue(route.restore.isEmpty); XCTAssertTrue(route.signups.isEmpty); XCTAssertEqual(input.reads, 0)
    }
    func testRetainedMnemonicActionUsesTheCurrentViewAfterRebinding() throws {
        let (p, first, _, route) = make(); p.activateAccountRestore(); let action = try action(route, 1)
        let replacement = OnboardingActionHost(); p.view = replacement; action.handler?()
        XCTAssertTrue(route.source === replacement); XCTAssertFalse(route.source === first)
    }
    func testRepeatedRestoreSheetsDoNotStartCloudAuthorization() {
        let (p, _, input, route) = make(); p.activateAccountRestore(); p.activateAccountRestore()
        XCTAssertEqual(route.sheets.count, 2); XCTAssertEqual(input.reads, 0); XCTAssertTrue(route.restore.isEmpty)
    }
    func testSetupInitializesTheInteractorBeforeAnyChoice() {
        let (p, _, input, route) = make(); p.setup(); XCTAssertEqual(input.setups, 1)
        XCTAssertTrue(route.sheets.isEmpty); XCTAssertTrue(route.signups.isEmpty)
    }
    func testReappearingWithoutACloudRequestResetsThePreviousSignInState() {
        let (p, _, input, _) = make(); p.viewWillAppear(); p.viewWillAppear(); XCTAssertEqual(input.resets, 2)
    }
    func testCloudFailureFromTheRestoreSheetStopsLoadingAndCanBeSelectedAgain() async throws {
        let (p, host, input, route) = make(); input.failure = CloudStorageServiceError.notFound
        let first = expectation(description: "first cloud failure"); route.didFinish = { first.fulfill() }
        p.activateAccountRestore(); let cloud = try action(route, 0); cloud.handler?(); await fulfillment(of: [first], timeout: 2)
        XCTAssertEqual(route.messages.count, 1); XCTAssertEqual(host.loading, [true, false]); XCTAssertTrue(route.signups.isEmpty)
        let second = expectation(description: "retry cloud failure"); route.didFinish = { second.fulfill() }
        cloud.handler?(); await fulfillment(of: [second], timeout: 2)
        XCTAssertEqual(input.reads, 2); XCTAssertEqual(route.messages.count, 2)
    }
}
private final class OnboardingActionHost: UIViewController, OnboardingMainViewProtocol {
    var loading = [Bool]()
    func showLoading() { loading.append(true) }
    func hideLoading() { loading.append(false) }
}
private final class OnboardingActionInput: OnboardingMainInteractorInputProtocol {
    var setups = 0, resets = 0, reads = 0; var failure: Error?
    func setup() { setups += 1 }
    func resetGoogleState() { resets += 1 }
    func getBackupedAccounts() async throws -> [OpenBackupAccount] { reads += 1; if let failure { throw failure }; return [] }
}
private final class OnboardingActionRoute: OnboardingMainWireframeProtocol {
    var activityIndicatorWindow: UIWindow?
    var source: ControllerBackedProtocol?, sheets = [AlertPresentableViewModel](), styles = [UIAlertController.Style](), restore = [AccountImportSource](), signups = [Bool](), messages = [String?](), keystoreCount = 0
    var didFinish: (() -> Void)?
    func showSignup(from view: OnboardingMainViewProtocol?, isGoogleBackupSelected: Bool) { source = view; signups.append(isGoogleBackupSelected); didFinish?() }
    func showAccountRestoreRedesign(from view: OnboardingMainViewProtocol?, sourceType: AccountImportSource) { source = view; restore.append(sourceType) }
    func showKeystoreImport(from view: OnboardingMainViewProtocol?) { source = view; keystoreCount += 1 }
    func showBackupedAccounts(from view: OnboardingMainViewProtocol?, accounts: [OpenBackupAccount]) { XCTFail("No cloud account expected") }
    func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?) { source = view; sheets.append(viewModel); styles.append(style) }
    func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?) { source = view; messages.append(message); didFinish?() }
}
