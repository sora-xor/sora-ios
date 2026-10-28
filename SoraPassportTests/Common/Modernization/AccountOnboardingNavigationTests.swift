// SPDX-License-Identifier: BSD-4-Clause
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
