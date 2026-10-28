import Foundation
import IrohaCrypto
import RobinHood
import SoraFoundation
import UIKit
import XCTest
@testable import SoraPassport

@MainActor
final class AccountImportFlowTests: XCTestCase {
    private var retainedViews = [UIViewController]()
    override func tearDown() { retainedViews.removeAll(); super.tearDown() }
    private let phrase = Array(repeating: "abandon", count: 11).joined(separator: " ") + " about"
    private func make(source: AccountImportSource? = .mnemonic, crypto: CryptoType = .sr25519) -> (AccountImportPresenter, ImportAccountViewController, ImportFlowInteractor, ImportFlowRoutes) {
        let model = AccountImportPresenter(sourceType: source, config: ApplicationConfig.shared)
        let view = ImportAccountViewController(), interactor = ImportFlowInteractor(), routes = ImportFlowRoutes()
        retainedViews.append(view)
        model.view = view; model.interactor = interactor; model.wireframe = routes; view.presenter = model
        view.loadViewIfNeeded()
        model.didReceiveAccountImport(metadata: .init(availableSources: AccountImportSource.allCases, defaultSource: .mnemonic,
            availableNetworks: [.sora], defaultNetwork: .sora, availableCryptoTypes: CryptoType.allCases, defaultCryptoType: crypto))
        model.sourceViewModel?.inputHandler.changeValue(to: source == .seed ? "0x" + String(repeating: "42", count: 32) : phrase)
        return (model, view, interactor, routes)
    }
    private func settle() async { try? await Task.sleep(nanoseconds: 30_000_000) }
    func testDefaultMetadataSelectsTheDefaultImportSource() {
        let (m, _, _, _) = make(source: nil)
        XCTAssertEqual(m.selectedSourceType, .mnemonic); XCTAssertNotNil(m.sourceViewModel)
    }
    func testSetupRequestsMetadataExactlyOnceThroughTheActualScreen() {
        let (_, _, i, _) = make(); XCTAssertEqual(i.setups, 1)
    }
    func testMnemonicValidationCarriesExactNamePathCryptoAndNetwork() async {
        let (m, _, i, r) = make(); m.usernameViewModel?.inputHandler.changeValue(to: "Fixture")
        m.derivationPathViewModel?.inputHandler.changeValue(to: "//7///fixture")
        m.selectCryptoType(.ecdsa); m.proceed()
        XCTAssertEqual(i.mnemonic.first?.mnemonic, phrase); XCTAssertEqual(i.mnemonic.first?.username, "Fixture")
        XCTAssertEqual(i.mnemonic.first?.derivationPath, "//7///fixture"); XCTAssertEqual(i.mnemonic.first?.cryptoType, .ecdsa)
        XCTAssertEqual(i.mnemonic.first?.networkType, .sora)
        i.finish(.success(nil)); await settle(); XCTAssertEqual(r.routes.count, 1)
        XCTAssertEqual(r.routes.first?.source, phrase); XCTAssertEqual(r.routes.first?.path, "//7///fixture")
    }
    func testSeedValidationUsesSeedRequestAndExactMaterial() async {
        let (m, _, i, r) = make(source: .seed); m.proceed()
        XCTAssertEqual(i.seeds.first?.seed, "0x" + String(repeating: "42", count: 32))
        XCTAssertTrue(i.mnemonic.isEmpty); i.finish(.success(nil)); await settle()
        XCTAssertEqual(r.routes.first?.type, .seed)
    }
    func testInvalidSeedNeverStartsValidation() {
        let (m, _, i, r) = make(source: .seed); m.sourceViewModel?.inputHandler.changeValue(to: "0x1234"); m.proceed()
        XCTAssertTrue(i.seeds.isEmpty); XCTAssertEqual(r.errors.count, 1)
    }
    func testTooManyMnemonicWordsNeverStartValidation() {
        let (m, _, i, r) = make(); m.sourceViewModel?.inputHandler.changeValue(to: Array(repeating: "act", count: 25).joined(separator: " ")); m.proceed()
        XCTAssertTrue(i.mnemonic.isEmpty); XCTAssertEqual(r.errors.count, 1)
    }
    func testMalformedKeystoreNeverStartsValidation() {
        let (m, _, i, r) = make(); m.didSuggestKeystore(text: "not-json", preferredInfo: nil); m.proceed()
        XCTAssertTrue(i.json.isEmpty); XCTAssertEqual(r.errors.count, 1)
    }
    func testJSONWithNoKeystoreDefinitionFailsExplicitly() async {
        let (m, _, i, r) = make(); m.didSuggestKeystore(text: "{}", preferredInfo: .init(username: "Fixture", networkType: .sora, cryptoType: .sr25519, networkTypeConfirmed: true)); m.proceed()
        await settle(); XCTAssertTrue(i.json.isEmpty); XCTAssertEqual(r.errors.count, 1)
    }
    func testInvalidMnemonicDerivationNeverStartsValidation() {
        let (m, _, i, r) = make(crypto: .ed25519); m.derivationPathViewModel?.inputHandler.changeValue(to: "/soft"); m.proceed()
        XCTAssertTrue(i.mnemonic.isEmpty); XCTAssertEqual(r.errors.count, 1)
    }
    func testInvalidSeedPasswordDerivationNeverStartsValidation() {
        let (m, _, i, r) = make(source: .seed); m.derivationPathViewModel?.inputHandler.changeValue(to: "///password"); m.proceed()
        XCTAssertTrue(i.seeds.isEmpty); XCTAssertEqual(r.errors.count, 1)
    }
    func testCryptoSelectionPreservesEnteredDerivationPath() {
        let (m, _, _, _) = make(); m.derivationPathViewModel?.inputHandler.changeValue(to: "//42"); m.selectCryptoType(.ed25519)
        XCTAssertEqual(m.selectedCryptoType, .ed25519); XCTAssertEqual(m.derivationPathViewModel?.inputHandler.value, "//42")
    }
    func testUnavailableCryptoChoiceIsIgnored() {
        let (m, _, _, _) = make(); m.didReceiveAccountImport(metadata: .init(availableSources: [.mnemonic], defaultSource: .mnemonic, availableNetworks: [.sora], defaultNetwork: .sora, availableCryptoTypes: [.sr25519], defaultCryptoType: .sr25519))
        m.selectCryptoType(.ecdsa); XCTAssertEqual(m.selectedCryptoType, .sr25519)
    }
    func testKeystoreCryptoChoiceCannotBeManuallyOverridden() {
        let (m, _, _, _) = make(); m.didSuggestKeystore(text: "{}", preferredInfo: .init(username: nil, networkType: .sora, cryptoType: .ed25519, networkTypeConfirmed: true)); m.selectCryptoType(.sr25519)
        XCTAssertEqual(m.selectedCryptoType, .ed25519); XCTAssertNil(m.derivationPathViewModel)
    }
    func testLocalizationPreservesTheEnteredMnemonic() {
        let (m, _, _, _) = make(); m.applyLocalization(); XCTAssertEqual(m.sourceViewModel?.inputHandler.value, phrase)
    }
    func testLocalizationPreservesTheEnteredName() {
        let (m, _, _, _) = make(); m.usernameViewModel?.inputHandler.changeValue(to: "Fixture name"); m.applyLocalization()
        XCTAssertEqual(m.usernameViewModel?.inputHandler.value, "Fixture name")
    }
    func testLocalizationPreservesKeystoreTextAndPassword() {
        let (m, _, _, _) = make(); m.didSuggestKeystore(text: "{\"fixture\":true}", preferredInfo: .init(username: "Fixture", networkType: .sora, cryptoType: .sr25519, networkTypeConfirmed: true))
        m.passwordViewModel?.inputHandler.changeValue(to: "public-fixture-password"); m.applyLocalization()
        XCTAssertEqual(m.sourceViewModel?.inputHandler.value, "{\"fixture\":true}")
        XCTAssertEqual(m.passwordViewModel?.inputHandler.value, "public-fixture-password")
    }
    func testLocalizationPreservesDerivationAndCryptoChoice() {
        let (m, _, _, _) = make(); m.derivationPathViewModel?.inputHandler.changeValue(to: "//42"); m.selectCryptoType(.ecdsa); m.applyLocalization()
        XCTAssertEqual(m.derivationPathViewModel?.inputHandler.value, "//42"); XCTAssertEqual(m.selectedCryptoType, .ecdsa)
    }
    func testChangingPhraseDuringValidationInvalidatesTheResult() async {
        let (m, _, i, r) = make(); m.proceed(); m.sourceViewModel?.inputHandler.changeValue(to: "legal winner thank year wave sausage worth useful legal winner thank yellow")
        i.finish(.success(nil)); await settle(); XCTAssertTrue(r.routes.isEmpty)
    }
    func testChangingDerivationDuringValidationInvalidatesTheResult() async {
        let (m, _, i, r) = make(); m.proceed(); m.derivationPathViewModel?.inputHandler.changeValue(to: "//42")
        i.finish(.success(nil)); await settle(); XCTAssertTrue(r.routes.isEmpty)
    }
    func testChangingCryptoDuringValidationInvalidatesTheResult() async {
        let (m, _, i, r) = make(); m.proceed(); m.selectCryptoType(.ecdsa)
        i.finish(.success(nil)); await settle(); XCTAssertTrue(r.routes.isEmpty)
    }
    func testChangingNameDuringValidationInvalidatesTheResult() async {
        let (m, _, i, r) = make(); m.proceed(); m.usernameViewModel?.inputHandler.changeValue(to: "Changed")
        i.finish(.success(nil)); await settle(); XCTAssertTrue(r.routes.isEmpty)
    }
    func testChangingSourceDuringValidationInvalidatesTheResult() async {
        let (m, _, i, r) = make(); m.proceed(); m.didSuggestKeystore(text: "{}", preferredInfo: nil)
        i.finish(.success(nil)); await settle(); XCTAssertTrue(r.routes.isEmpty)
    }
    func testRepeatedProceedDuringOneValidationDoesNotDuplicateWork() async {
        let (m, _, i, r) = make(); m.proceed(); m.proceed()
        XCTAssertEqual(i.mnemonic.count, 1)
        i.finish(.success(nil)); await settle(); XCTAssertEqual(r.routes.count, 1)
    }
    func testOldValidationCannotNavigateAfterANewerRequest() async {
        let (m, _, i, r) = make(); m.proceed(); m.derivationPathViewModel?.inputHandler.changeValue(to: "//42"); m.proceed()
        XCTAssertEqual(i.callbacks.count, 2)
        i.finish(.success(nil), index: 1); await settle(); i.finish(.success(nil), index: 0); await settle()
        XCTAssertEqual(r.routes.count, 1); XCTAssertEqual(r.routes.first?.path, "//42")
    }
    func testOldValidationFailureDoesNotShowAnErrorForNewInput() async {
        let (m, _, i, r) = make(); m.proceed(); m.derivationPathViewModel?.inputHandler.changeValue(to: "//42")
        i.finish(.failure(AccountCreateError.invalidSeed)); await settle(); XCTAssertTrue(r.errors.isEmpty)
    }
    func testValidationFailureIsReportedAndCanBeRetried() async {
        let (m, _, i, r) = make(); m.proceed(); i.finish(.failure(AccountCreateError.invalidSeed)); await settle()
        XCTAssertEqual(r.errors.count, 1); XCTAssertTrue(r.routes.isEmpty)
        m.proceed(); XCTAssertEqual(i.mnemonic.count, 2)
    }
    func testCancelledValidationIsReportedAsFailure() async {
        let (m, _, i, r) = make(); m.proceed(); i.finish(nil); await settle()
        XCTAssertEqual(r.errors.count, 1); XCTAssertTrue(r.routes.isEmpty)
    }
    func testShortHistoricalPhraseRequiresAnExplicitKnownAddress() {
        let (m, _, i, r) = make(); m.sourceViewModel?.inputHandler.changeValue(to: "abandon ability able"); m.proceed()
        XCTAssertEqual(r.prompts, 1); XCTAssertTrue(i.mnemonic.isEmpty)
    }
    func testShortHistoricalPhraseForwardsTheConfirmedAddress() async {
        let (m, _, i, r) = make(); r.knownAddress = "public-fixture-address"
        m.sourceViewModel?.inputHandler.changeValue(to: "abandon ability able"); m.proceed()
        XCTAssertEqual(i.mnemonic.first?.expectedAddress, "public-fixture-address")
        i.finish(.success(nil)); await settle(); XCTAssertEqual(r.routes.first?.expectedAddress, "public-fixture-address")
    }
    func testNormalPhraseClearsEarlierHistoricalAddressBinding() async {
        let (m, _, i, r) = make(); r.knownAddress = "public-fixture-address"
        m.sourceViewModel?.inputHandler.changeValue(to: "abandon ability able"); m.proceed(); i.finish(.failure(AccountCreateError.invalidSeed)); await settle()
        m.sourceViewModel?.inputHandler.changeValue(to: phrase); m.proceed()
        XCTAssertNil(i.mnemonic.last?.expectedAddress)
    }
    func testValidationBeforeMetadataCompletesWithAnExplicitFailure() {
        let m = AccountImportPresenter(sourceType: .mnemonic, config: ApplicationConfig.shared)
        var completed = false
        m.validateAccount { result in completed = true; guard case .failure? = result else { return XCTFail("Missing inputs must fail") } }
        XCTAssertTrue(completed)
    }
    func testHelpLinkUsesTheRequestedURL() {
        let (m, _, _, r) = make(); let url = URL(string: "https://sora.org/help")!; m.activateURL(url)
        XCTAssertEqual(r.urls, [url])
    }
}
private final class ImportFlowInteractor: AccountImportInteractorInputProtocol {
    var setups = 0
    var mnemonic = [AccountImportMnemonicRequest](), seeds = [AccountImportSeedRequest](), json = [AccountImportKeystoreRequest]()
    var callbacks = [((Result<AccountItem?, Error>?) -> Void)?]()
    func setup() { setups += 1 }
    func validateAccountWithMnemonic(request: AccountImportMnemonicRequest, completion: ((Result<AccountItem?, Error>?) -> Void)?) { mnemonic.append(request); callbacks.append(completion) }
    func validateAccountWithSeed(request: AccountImportSeedRequest, completion: ((Result<AccountItem?, Error>?) -> Void)?) { seeds.append(request); callbacks.append(completion) }
    func validateAccountWithKeystore(request: AccountImportKeystoreRequest, completion: ((Result<AccountItem?, Error>?) -> Void)?) { json.append(request); callbacks.append(completion) }
    func finish(_ result: Result<AccountItem?, Error>?, index: Int = 0) { callbacks[index]?(result) }
    func importAccountWithMnemonic(request: AccountImportMnemonicRequest, completion: ((Result<AccountItem, Error>?) -> Void)?) { XCTFail("Unexpected persistence") }
    func importAccountWithSeed(request: AccountImportSeedRequest, completion: ((Result<AccountItem, Error>?) -> Void)?) { XCTFail("Unexpected persistence") }
    func importAccountWithKeystore(request: AccountImportKeystoreRequest, completion: ((Result<AccountItem, Error>?) -> Void)?) { XCTFail("Unexpected persistence") }
    func deriveMetadataFromKeystore(_ keystore: String) {}
    func importBackedupAccount(request: AccountImportBackedupRequest) { XCTFail("Unexpected persistence") }
}
private final class ImportFlowRoutes: AccountImportWireframeProtocol {
    struct Route { let type: AccountImportSource; let source, name, path: String; let expectedAddress: String? }
    var routes = [Route](), errors = [Error](), urls = [URL](), prompts = 0
    var knownAddress: String?
    func requestKnownAddress(from view: AccountImportViewProtocol?, completion: @escaping (String?) -> Void) { prompts += 1; completion(knownAddress) }
    func proceed(from view: AccountImportViewProtocol?, sourceType: AccountImportSource, cryptoType: CryptoType, networkType: Chain,
                 sourceViewModel: InputViewModelProtocol, usernameViewModel: InputViewModelProtocol, passwordViewModel: InputViewModelProtocol?,
                 derivationPathViewModel: InputViewModelProtocol?, expectedAddress: String?) {
        routes.append(.init(type: sourceType, source: sourceViewModel.inputHandler.value, name: usernameViewModel.inputHandler.value,
                            path: derivationPathViewModel?.inputHandler.value ?? "", expectedAddress: expectedAddress))
    }
    func present(error: Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool { errors.append(error); return true }
    func present(error: Error, from view: ControllerBackedProtocol?, locale: Locale?, completion: @escaping () -> Void) -> Bool { errors.append(error); return true }
    func showWeb(url: URL, from view: ControllerBackedProtocol, style: WebPresentableStyle) { urls.append(url) }
    func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?) {}
    func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?, completion: @escaping () -> Void) {}
    func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?) {}
}
