// SPDX-License-Identifier: Apache-2.0
import Foundation
import RobinHood
import SoraFoundation
import UIKit
import XCTest
@testable import SoraPassport

@MainActor
final class AccountNamingFlowTests: XCTestCase {
    private func make(_ root: Bool, source: AccountImportSource = .mnemonic) -> NamingFixture { NamingFixture(root: root, source: source) }
    private func checkMnemonic(_ root: Bool) {
        let f = make(root); f.importDirect(); let r = f.input.mnemonic.first
        XCTAssertEqual(r?.mnemonic, "public fixture words"); XCTAssertEqual(r?.derivationPath, "//fixture"); XCTAssertEqual(r?.expectedAddress, "historical-address"); XCTAssertEqual(r?.cryptoType, .sr25519); XCTAssertEqual(r?.networkType, .sora)
    }
    func testRootMnemonicHandoffPreservesDerivationAndHistoricalAddress() { checkMnemonic(true) }
    func testAdditionalMnemonicHandoffPreservesDerivationAndHistoricalAddress() { checkMnemonic(false) }
    private func checkSeed(_ root: Bool) { let f = make(root, source: .seed); f.importDirect(); XCTAssertEqual(f.input.seeds.first?.seed, "public fixture words"); XCTAssertEqual(f.input.seeds.first?.derivationPath, "//fixture"); XCTAssertEqual(f.input.seeds.first?.cryptoType, .sr25519) }
    func testRootSeedHandoffPreservesDerivation() { checkSeed(true) }
    func testAdditionalSeedHandoffPreservesDerivation() { checkSeed(false) }
    private func checkJSON(_ root: Bool) { let f = make(root, source: .keystore); f.importDirect(); XCTAssertEqual(f.input.json.first?.keystore, "public fixture words"); XCTAssertEqual(f.input.json.first?.password, "fixture password"); XCTAssertEqual(f.input.json.first?.networkType, .sora) }
    func testRootKeystoreHandoffPreservesPassword() { checkJSON(true) }
    func testAdditionalKeystoreHandoffPreservesPassword() { checkJSON(false) }
    private func checkEditedName(_ root: Bool, source: AccountImportSource) { let f = make(root, source: source); f.presenter.userName = "New wallet name"; f.presenter.proceed(); XCTAssertEqual(f.input.names, ["New wallet name"]) }
    func testRootMnemonicImportsWithTheNameEnteredOnThisScreen() { checkEditedName(true, source: .mnemonic) }
    func testAdditionalMnemonicImportsWithTheNameEnteredOnThisScreen() { checkEditedName(false, source: .mnemonic) }
    func testRootSeedImportsWithTheNameEnteredOnThisScreen() { checkEditedName(true, source: .seed) }
    func testAdditionalSeedImportsWithTheNameEnteredOnThisScreen() { checkEditedName(false, source: .seed) }
    func testRootKeystoreImportsWithTheNameEnteredOnThisScreen() { checkEditedName(true, source: .keystore) }
    func testAdditionalKeystoreImportsWithTheNameEnteredOnThisScreen() { checkEditedName(false, source: .keystore) }
    private func checkDuplicate(_ root: Bool) { let f = make(root); f.presenter.proceed(); f.presenter.proceed(); XCTAssertEqual(f.input.callbacks.count, 1) }
    func testRootRepeatedContinueDoesNotStartASecondImport() { checkDuplicate(true) }
    func testAdditionalRepeatedContinueDoesNotStartASecondImport() { checkDuplicate(false) }
    private func checkFailureRetry(_ root: Bool) { let f = make(root); f.presenter.proceed(); f.input.finish(.failure(NamingFailure.unavailable)); f.presenter.proceed(); XCTAssertEqual(f.input.callbacks.count, 2); XCTAssertEqual(f.routes.messages.count, 1) }
    func testRootFailedImportCanBeRetried() { checkFailureRetry(true) }
    func testAdditionalFailedImportCanBeRetried() { checkFailureRetry(false) }
    private func checkCancel(_ root: Bool) { let f = make(root); f.presenter.proceed(); f.input.finish(.failure(CancellationError())); XCTAssertTrue(f.routes.messages.isEmpty); f.presenter.proceed(); XCTAssertEqual(f.input.callbacks.count, 2) }
    func testRootCancelledImportIsSilentAndCanBeRetried() { checkCancel(true) }
    func testAdditionalCancelledImportIsSilentAndCanBeRetried() { checkCancel(false) }
    private func checkNoResult(_ root: Bool) { let f = make(root); f.presenter.proceed(); f.input.finish(nil); XCTAssertTrue(f.routes.messages.isEmpty); f.presenter.proceed(); XCTAssertEqual(f.input.callbacks.count, 2) }
    func testRootMissingImportResultDoesNotNavigateAndCanBeRetried() { checkNoResult(true) }
    func testAdditionalMissingImportResultDoesNotNavigateAndCanBeRetried() { checkNoResult(false) }
    private func checkSetup(_ root: Bool) { let f = make(root); f.presenter.userName = "Existing name"; f.presenter.setup(); XCTAssertEqual(f.view.model?.inputHandler.value, "Existing name") }
    func testRootSetupProvidesTheExistingDisplayName() { checkSetup(true) }
    func testAdditionalSetupProvidesTheExistingDisplayName() { checkSetup(false) }
    private func checkURL(_ root: Bool) { let f = make(root); let url = URL(string: "https://sora.org/privacy")!; f.presenter.activateURL(url); XCTAssertEqual(f.routes.urls, [url]) }
    func testRootHelpRoutesTheRequestedURL() { checkURL(true) }
    func testAdditionalHelpRoutesTheRequestedURL() { checkURL(false) }
    func testRootBackgroundFailureIsPresentedOnTheMainThread() async {
        let f = make(true); let done = expectation(description: "error delivered"); f.routes.onMessage = { done.fulfill() }; f.presenter.proceed()
        let input = f.input
        DispatchQueue.global().async { input.finish(.failure(NamingFailure.unavailable)) }
        await fulfillment(of: [done], timeout: 2); XCTAssertEqual(f.routes.mainThreads, [true])
    }
    func testAdditionalBackgroundFailureIsPresentedOnTheMainThread() async {
        let f = make(false); let done = expectation(description: "error delivered"); f.routes.onMessage = { done.fulfill() }; f.presenter.proceed()
        let input = f.input
        DispatchQueue.global().async { input.finish(.failure(NamingFailure.unavailable)) }
        await fulfillment(of: [done], timeout: 2); XCTAssertEqual(f.routes.mainThreads, [true])
    }
    func testNameViewDisplaysTheSuppliedInitialValue() throws {
        let p = NamingPresenter(); p.userName = "Saved wallet"; let view = SetupAccountNameViewController(); p.view = view; view.presenter = p; view.loadViewIfNeeded()
        let field = try XCTUnwrap(descendants(UITextField.self, view.view).first); XCTAssertEqual(field.text, "Saved wallet")
    }
    func testNameViewContinuePassesTheVisibleEditedValue() throws {
        let p = NamingPresenter(); let view = SetupAccountNameViewController(); p.view = view; view.presenter = p; view.loadViewIfNeeded()
        let field = try XCTUnwrap(descendants(UITextField.self, view.view).first); field.text = "My edited wallet"
        let button = try XCTUnwrap(descendants(UIButton.self, view.view).first { ($0.configuration?.title ?? $0.currentTitle) == R.string.localizable.transactionContinue(preferredLanguages: .currentLocale) }); button.sendActions(for: .touchUpInside)
        XCTAssertEqual(p.submitted, ["My edited wallet"])
    }
    func testNameViewUsesNicknameKeyboardWithoutAutocorrection() throws {
        let p = NamingPresenter(); let view = SetupAccountNameViewController(); p.view = view; view.presenter = p; view.loadViewIfNeeded()
        let field = try XCTUnwrap(descendants(UITextField.self, view.view).first); XCTAssertEqual(field.textContentType, .nickname); XCTAssertEqual(field.autocorrectionType, .no); XCTAssertEqual(field.autocapitalizationType, .none); XCTAssertEqual(field.returnKeyType, .done)
    }
    private func checkSuccessRenamesReturnedAccount(_ root: Bool) {
        let f = make(root); f.presenter.userName = "New wallet name"; f.presenter.proceed()
        f.settings.currentAccount = NamingFixture.account("different-selected-wallet")
        f.input.finish(.success(NamingFixture.account("imported-wallet")))
        XCTAssertEqual(f.settings.renames.map { $0.0.address }, ["imported-wallet"])
        XCTAssertEqual(f.settings.renames.map { $0.1 }, ["New wallet name"])
    }
    func testRootImportRenamesItsReturnedWalletAfterSelectionChanges() { checkSuccessRenamesReturnedAccount(true) }
    func testAdditionalImportRenamesItsReturnedWalletAfterSelectionChanges() { checkSuccessRenamesReturnedAccount(false) }
    private func checkSuccessfulImportWithoutSelectedAccount(_ root: Bool) {
        let f = make(root); f.presenter.proceed(); f.input.finish(.success(NamingFixture.account("imported-wallet")))
        XCTAssertEqual(f.settings.renames.count, 1)
    }
    func testRootSuccessfulImportStillFinishesIfCurrentSelectionIsMissing() { checkSuccessfulImportWithoutSelectedAccount(true) }
    func testAdditionalSuccessfulImportStillFinishesIfCurrentSelectionIsMissing() { checkSuccessfulImportWithoutSelectedAccount(false) }
    private func checkDuplicateCompletion(_ root: Bool) {
        let f = make(root); f.presenter.proceed(); f.input.finish(.failure(NamingFailure.unavailable)); f.presenter.proceed()
        f.input.finish(.success(NamingFixture.account("obsolete-wallet")), index: 0)
        XCTAssertTrue(f.settings.renames.isEmpty); XCTAssertEqual(f.routes.pinCount, 0)
        f.input.finish(.failure(CancellationError()), index: 1)
    }
    func testRootIgnoresACompletedRequestsLateSuccess() { checkDuplicateCompletion(true) }
    func testAdditionalIgnoresACompletedRequestsLateSuccess() { checkDuplicateCompletion(false) }
    func testRootDoesNotNavigateUntilTheNameIsSaved() {
        let f = make(true); f.settings.currentAccount = NamingFixture.account("imported-wallet"); f.presenter.proceed(); f.input.finish(.success(NamingFixture.account("imported-wallet")))
        XCTAssertEqual(f.routes.pinCount, 0); f.settings.finishName(.success(NamingFixture.account("imported-wallet")))
    }
    func testAdditionalDoesNotDismissUntilTheNameIsSaved() {
        let f = make(false); f.settings.currentAccount = NamingFixture.account("imported-wallet"); f.presenter.proceed(); f.input.finish(.success(NamingFixture.account("imported-wallet")))
        XCTAssertEqual(f.view.recording.dismissCount, 0); f.settings.finishName(.success(NamingFixture.account("imported-wallet")))
    }
    private func checkNameFailureRetriesOnlyMetadata(_ root: Bool) {
        let f = make(root); f.settings.currentAccount = NamingFixture.account("imported-wallet"); f.presenter.proceed(); f.input.finish(.success(NamingFixture.account("imported-wallet"))); f.settings.finishName(.failure(NamingFailure.unavailable)); f.presenter.proceed()
        XCTAssertEqual(f.input.callbacks.count, 1); XCTAssertEqual(f.settings.renames.count, 2)
    }
    func testRootNameSaveRetryDoesNotImportKeysAgain() { checkNameFailureRetriesOnlyMetadata(true) }
    func testAdditionalNameSaveRetryDoesNotImportKeysAgain() { checkNameFailureRetriesOnlyMetadata(false) }
    func testRootContinueWhileSavingNameDoesNotStartAnotherImport() {
        let f = make(true); f.settings.currentAccount = NamingFixture.account("imported-wallet"); f.presenter.proceed(); f.input.finish(.success(NamingFixture.account("imported-wallet"))); f.presenter.proceed(); XCTAssertEqual(f.input.callbacks.count, 1)
    }
    func testAdditionalContinueWhileSavingNameDoesNotStartAnotherImport() {
        let f = make(false); f.settings.currentAccount = NamingFixture.account("imported-wallet"); f.presenter.proceed(); f.input.finish(.success(NamingFixture.account("imported-wallet"))); f.presenter.proceed(); XCTAssertEqual(f.input.callbacks.count, 1)
    }
    func testRootNameSaveSuccessNavigatesExactlyOnce() {
        let f = make(true); f.presenter.proceed(); f.input.finish(.success(NamingFixture.account("imported-wallet"))); f.settings.finishName(.success(NamingFixture.account("imported-wallet"))); f.settings.finishName(.success(NamingFixture.account("imported-wallet"))); f.presenter.proceed(); XCTAssertEqual(f.routes.pinCount, 1); XCTAssertEqual(f.input.callbacks.count, 1)
    }
    func testAdditionalNameSaveSuccessDismissesExactlyOnce() {
        let f = make(false); f.presenter.proceed(); f.input.finish(.success(NamingFixture.account("imported-wallet"))); f.settings.finishName(.success(NamingFixture.account("imported-wallet"))); f.settings.finishName(.success(NamingFixture.account("imported-wallet"))); f.presenter.proceed(); XCTAssertEqual(f.view.recording.dismissCount, 1); XCTAssertEqual(f.input.callbacks.count, 1)
    }
    private func descendants<T: UIView>(_ type: T.Type, _ root: UIView) -> [T] { ((root as? T).map { [$0] } ?? []) + root.subviews.flatMap { descendants(type, $0) } }
}
private enum NamingFailure: Error { case unavailable }
@MainActor
private final class NamingFixture {
    let input = NamingInput(), view = NamingView(), routes = NamingRoutes(), settings = NamingSettings(); let presenter: UsernameSetupPresenterProtocol; let importDirect: () -> Void
    init(root: Bool, source: AccountImportSource) {
        let repository = AnyDataProviderRepository(InMemoryDataProviderRepository<AccountItem>()), event = NamingEvents(), operations = OperationManager()
        let material = Self.value("public fixture words"), name = Self.value("Earlier name"), password = Self.value("fixture password"), path = Self.value("//fixture")
        if root {
            let p = SetupNameImportRootPresenter(accountRepository: repository, eventCenter: event, operationManager: operations, sourceType: source, cryptoType: .sr25519, networkType: .sora, sourceViewModel: material, usernameViewModel: name, passwordViewModel: password, derivationPathViewModel: path, expectedAddress: "historical-address", selectedSettings: settings)
            p.interactor = input; p.view = view; p.wireframe = routes; presenter = p; importDirect = { p.importAccount(completion: nil) }
        } else {
            let p = SetupNameImportAccountPresenter(accountRepository: repository, eventCenter: event, operationManager: operations, sourceType: source, cryptoType: .sr25519, networkType: .sora, sourceViewModel: material, usernameViewModel: name, passwordViewModel: password, derivationPathViewModel: path, expectedAddress: "historical-address", selectedSettings: settings)
            p.interactor = input; p.view = view; p.wireframe = routes; presenter = p; importDirect = { p.importAccount(completion: nil) }
        }
    }
    nonisolated static func account(_ address: String) -> AccountItem { AccountItem(address: address, cryptoType: .sr25519, networkType: Chain.sora.addressType(), username: "Old", publicKeyData: Data(repeating: 3, count: 32), settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: 0, isSelected: false) }
    nonisolated static func value(_ text: String) -> InputViewModel { InputViewModel(inputHandler: InputHandler(value: text, required: false, predicate: NSPredicate(value: true))) }
}
private final class NamingInput: AccountImportInteractorInputProtocol {
    var mnemonic = [AccountImportMnemonicRequest](), seeds = [AccountImportSeedRequest](), json = [AccountImportKeystoreRequest](), callbacks = [((Result<AccountItem, Error>?) -> Void)?]()
    var names: [String] { mnemonic.map(\.username) + seeds.map(\.username) + json.map(\.username) }
    func setup() {}
    func importAccountWithMnemonic(request: AccountImportMnemonicRequest, completion: ((Result<AccountItem, Error>?) -> Void)?) { mnemonic.append(request); callbacks.append(completion) }
    func importAccountWithSeed(request: AccountImportSeedRequest, completion: ((Result<AccountItem, Error>?) -> Void)?) { seeds.append(request); callbacks.append(completion) }
    func importAccountWithKeystore(request: AccountImportKeystoreRequest, completion: ((Result<AccountItem, Error>?) -> Void)?) { json.append(request); callbacks.append(completion) }
    func finish(_ result: Result<AccountItem, Error>?, index: Int = 0) { callbacks[index]?(result) }
    func validateAccountWithMnemonic(request: AccountImportMnemonicRequest, completion: ((Result<AccountItem?, Error>?) -> Void)?) { XCTFail("No second validation expected") }
    func validateAccountWithSeed(request: AccountImportSeedRequest, completion: ((Result<AccountItem?, Error>?) -> Void)?) { XCTFail("No second validation expected") }
    func validateAccountWithKeystore(request: AccountImportKeystoreRequest, completion: ((Result<AccountItem?, Error>?) -> Void)?) { XCTFail("No second validation expected") }
    func deriveMetadataFromKeystore(_ keystore: String) {}
    func importBackedupAccount(request: AccountImportBackedupRequest) { XCTFail("No cloud persistence expected") }
}
private final class NamingView: UsernameSetupViewProtocol {
    var isSetup: Bool { true }
    let recording = NamingController(); var controller: UIViewController { recording }; var model: InputViewModelProtocol?
    func set(viewModel: InputViewModelProtocol) { model = viewModel }
    func resetFocus() {}
}
private final class NamingRoutes: UsernameSetupWireframeProtocol {
    var pinCount = 0
    var urls = [URL](), messages = [String?](), mainThreads = [Bool](); var onMessage: (() -> Void)?
    func proceed(from view: UsernameSetupViewProtocol?, username: String) { XCTFail("Unexpected create route") }
    func showPinCode(from view: UsernameSetupViewProtocol?) { pinCount += 1 }
    func showWarning(from view: UsernameSetupViewProtocol?, completion: @escaping () -> Void) {}
    func showWeb(url: URL, from view: ControllerBackedProtocol, style: WebPresentableStyle) { urls.append(url) }
    func present(error: Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool { true }
    func present(error: Error, from view: ControllerBackedProtocol?, locale: Locale?, completion: @escaping () -> Void) -> Bool { true }
    func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?) { messages.append(message); mainThreads.append(Thread.isMainThread); onMessage?() }
    func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?, completion: @escaping () -> Void) { completion() }
    func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?) {}
}
private final class NamingEvents: EventCenterProtocol {
    func notify(with event: EventProtocol) {}; func notify(with event: EventProtocol, completionOnMain: @escaping () -> Void) { DispatchQueue.main.async(execute: completionOnMain) }
    func add(observer: EventVisitorProtocol, dispatchIn: DispatchQueue?) {}; func remove(observer: EventVisitorProtocol) {}
}
private final class NamingPresenter: UsernameSetupPresenterProtocol {
    weak var view: UsernameSetupViewProtocol?; var userName: String?; var submitted = [String?]()
    func setup() { view?.set(viewModel: NamingFixture.value(userName ?? "")) }; func proceed() { submitted.append(userName) }; func endEditing() {}; func activateURL(_ url: URL) {}
}

private final class NamingController: UIViewController {
    var dismissCount = 0
    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) { dismissCount += 1; completion?() }
}
private final class NamingSettings: SelectedWalletSettingsProtocol {
    var currentAccount: AccountItem?
    var renames = [(AccountItem,String)](), completions = [(Result<AccountItem,Error>) -> Void]()
    func performUpdateName(account: AccountItem, displayName: String, completionClosure: @escaping (Result<AccountItem,Error>) -> Void) { renames.append((account,displayName)); completions.append(completionClosure) }
    func finishName(_ result: Result<AccountItem,Error>) { completions.last?(result) }
    func performSave(value: AccountItem, completionClosure: @escaping (Result<AccountItem,Error>) -> Void) { XCTFail("Unexpected wallet mutation") }
    func performInsertAndSelect(prepared: PreparedAccount, persistSecrets: @escaping () throws -> Void, lifecycleLease: WalletLifecycleLease, completionClosure: @escaping (Result<AccountItem,Error>) -> Void) { XCTFail("No actual key import") }
    func performSelectAfterRemoval(value: AccountItem, lifecycleLease: WalletLifecycleLease, completionClosure: @escaping (Result<AccountItem,Error>) -> Void) { XCTFail("No removal") }
    func performUpdateAssetSettings(account: AccountItem, settings: AccountSettings, completionClosure: @escaping (Result<AccountItem,Error>) -> Void) { XCTFail("Unexpected wallet mutation") }
    func performSetup(completionClosure: @escaping (Result<AccountItem?,Error>) -> Void) { completionClosure(.success(currentAccount)) }
    func save(value: AccountItem) { XCTFail("Unexpected wallet mutation") }
}
