import Foundation
import IrohaCrypto
import RobinHood
import SoraFoundation
import SSFUtils
import SSFCloudStorage
import SoraKeystore
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
    var handlesErrors = true
    var errorCompletions = [() -> Void]()
    func requestKnownAddress(from view: AccountImportViewProtocol?, completion: @escaping (String?) -> Void) { prompts += 1; completion(knownAddress) }
    func proceed(from view: AccountImportViewProtocol?, sourceType: AccountImportSource, cryptoType: CryptoType, networkType: Chain,
                 sourceViewModel: InputViewModelProtocol, usernameViewModel: InputViewModelProtocol, passwordViewModel: InputViewModelProtocol?,
                 derivationPathViewModel: InputViewModelProtocol?, expectedAddress: String?) {
        routes.append(.init(type: sourceType, source: sourceViewModel.inputHandler.value, name: usernameViewModel.inputHandler.value,
                            path: derivationPathViewModel?.inputHandler.value ?? "", expectedAddress: expectedAddress))
    }
    func present(error: Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool { errors.append(error); return true }
    func present(error: Error, from view: ControllerBackedProtocol?, locale: Locale?, completion: @escaping () -> Void) -> Bool { errors.append(error); errorCompletions.append(completion); return handlesErrors }
    func showWeb(url: URL, from view: ControllerBackedProtocol, style: WebPresentableStyle) { urls.append(url) }
    func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?) {}
    func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?, completion: @escaping () -> Void) {}
    func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?) {}
}

final class AccountImportPreparationBoundaryTests: XCTestCase {
    private let phrase = Array(repeating: "abandon", count: 11).joined(separator: " ") + " about"
    private struct Fixture {
        let interactor: PreparationOnlyImport; let output: PreparationImportOutput; let imports: PreparationImportService
        let cloud: PreparationImportCloud; let keys: InMemoryKeychain; let factory: AccountOperationFactory
    }
    private func fixture() -> Fixture {
        let keys = InMemoryKeychain(), settings = InMemorySettingsManager(), cloud = PreparationImportCloud(), imports = PreparationImportService(), output = PreparationImportOutput()
        let gate = WalletRecoveryCapabilityGate(settings: settings, unresolvedMigrationJournal: { false }, unresolvedWalletCommitJournal: { false })
        let factory = AccountOperationFactory(keystore: keys, recoveryGate: gate)
        let subject = PreparationOnlyImport(accountOperationFactory: factory, accountRepository: AnyDataProviderRepository(InMemoryDataProviderRepository<AccountItem>()), operationManager: OperationManager(), keystoreImportService: imports, supportedNetworks: [.sora], defaultNetwork: .sora, cloudStorage: cloud)
        subject.presenter = output
        return Fixture(interactor: subject, output: output, imports: imports, cloud: cloud, keys: keys, factory: factory)
    }
    private func mnemonic(_ text: String? = nil, path: String = "", expected: String? = nil) -> AccountImportMnemonicRequest {
        AccountImportMnemonicRequest(mnemonic: text ?? phrase, username: "Public fixture", networkType: .sora, derivationPath: path, cryptoType: .sr25519, expectedAddress: expected)
    }
    private func expected(_ f: Fixture, path: String = "") throws -> AccountItem {
        let op = try f.interactor.prepareMnemonic(mnemonic(path: path)); op.start(); let prepared = try XCTUnwrap(op.result).get(); defer { prepared.discard() }; return prepared.account
    }
    private func definition(crypto: String = "sr25519") -> KeystoreDefinition {
        KeystoreDefinition(address: nil, encoded: "AA==", encoding: KeystoreEncoding(content: ["pkcs8", crypto], type: ["scrypt", "xsalsa20-poly1305"], version: "3"), meta: nil)
    }
    private func backup(_ f: Fixture, value: OpenBackupAccount, password: String = "fixture password") async {
        let done = expectation(description: "backup preparation completed")
        f.interactor.onPrepared = { done.fulfill() }; f.output.onError = { done.fulfill() }
        f.cloud.account = value; f.interactor.importBackedupAccount(request: AccountImportBackedupRequest(account: OpenBackupAccount(address: value.address), password: password))
        await fulfillment(of: [done], timeout: 3)
    }
    func testSetupPublishesTheSupportedImportChoicesAndRegistersForKeystoreFiles() throws {
        let f = fixture(); f.interactor.setup(); let metadata = try XCTUnwrap(f.output.metadata.first)
        XCTAssertEqual(metadata.availableSources, AccountImportSource.allCases); XCTAssertEqual(metadata.defaultSource, .mnemonic)
        XCTAssertEqual(metadata.availableNetworks, [.sora]); XCTAssertEqual(metadata.defaultNetwork, .sora)
        XCTAssertEqual(metadata.availableCryptoTypes, CryptoType.allCases); XCTAssertEqual(metadata.defaultCryptoType, .sr25519)
        XCTAssertTrue(f.imports.observer === f.interactor)
    }
    func testPendingKeystoreIsConsumedOnceAndSuggestedWithoutImportingSecrets() throws {
        let f = fixture(); f.imports.definition = definition(); f.interactor.setup()
        XCTAssertNil(f.imports.definition); XCTAssertEqual(f.imports.clears, 1); XCTAssertEqual(f.output.suggestions.count, 1)
        let decoded = try JSONDecoder().decode(KeystoreDefinition.self, from: Data(f.output.suggestions[0].utf8))
        XCTAssertEqual(decoded.encoded, "AA=="); XCTAssertEqual(f.output.infos.first??.cryptoType, .sr25519)
        XCTAssertEqual(f.interactor.imports, 0); f.interactor.didUpdateDefinition(from: nil); XCTAssertEqual(f.output.suggestions.count, 1)
    }
    func testInvalidKeystoreMetadataIsReportedWithoutAttemptingAnImport() {
        let f = fixture(); f.imports.definition = definition(crypto: "unknown"); f.interactor.setup()
        XCTAssertEqual(f.output.errors.count, 1); XCTAssertTrue(f.output.suggestions.isEmpty); XCTAssertEqual(f.interactor.imports, 0)
    }
    func testManualKeystoreMetadataRetainsTheRealCryptoScheme() throws {
        let f = fixture(), json = String(data: try JSONEncoder().encode(definition(crypto: "ed25519")), encoding: .utf8)!
        f.interactor.deriveMetadataFromKeystore(json)
        XCTAssertEqual(f.output.suggestions, [json]); XCTAssertEqual(f.output.infos.first??.cryptoType, .ed25519)
        XCTAssertEqual(f.output.infos.first??.networkType, .sora); XCTAssertEqual(f.output.infos.first??.networkTypeConfirmed, false)
    }
    func testEveryKeystoreSchemePreservesItsDeclaredSigningAlgorithm() throws {
        for scheme in CryptoType.allCases {
            let file = definition(crypto: scheme.typeString.lowercased())
            let info = try AccountImportJsonFactory().createInfo(from: file)
            XCTAssertEqual(info.cryptoType, scheme)
            XCTAssertEqual(CryptoType(type: scheme.typeString), scheme)
            XCTAssertEqual(CryptoType(type: scheme.typeString.lowercased()), scheme)
        }
    }
    func testMalformedManualKeystoreDoesNotReplaceTheCurrentSuggestion() {
        let f = fixture(); f.interactor.deriveMetadataFromKeystore("not-json"); XCTAssertTrue(f.output.suggestions.isEmpty); XCTAssertEqual(f.interactor.imports, 0)
    }
    func testMnemonicPreparationReturnsTheDerivedAccountWithoutPersistingItsKeys() throws {
        let f = fixture(), account = try expected(f); var result: AccountItem?
        f.interactor.importAccountWithMnemonic(request: mnemonic()) { result = try? $0?.get() }
        XCTAssertEqual(result?.address, account.address); XCTAssertEqual(f.interactor.imports, 1)
        XCTAssertFalse(try f.keys.checkKey(for: KeystoreTag.entropyTagForAddress(account.address)))
        XCTAssertFalse(try f.keys.checkKey(for: KeystoreTag.secretKeyTagForAddress(account.address)))
    }
    func testInvalidMnemonicReportsFailureToBothPresenterAndCompletion() {
        let f = fixture(); var failed = false
        f.interactor.importAccountWithMnemonic(request: mnemonic("invalid phrase")) { if case .failure? = $0 { failed = true } }
        XCTAssertTrue(failed); XCTAssertEqual(f.output.errors.count, 1); XCTAssertEqual(f.interactor.imports, 0)
    }
    func testInvalidValidationUsesItsCompletionWithoutDuplicatePresenterError() {
        let f = fixture(); var failed = false
        f.interactor.validateAccountWithMnemonic(request: mnemonic("invalid phrase")) { if case .failure? = $0 { failed = true } }
        XCTAssertTrue(failed); XCTAssertTrue(f.output.errors.isEmpty); XCTAssertEqual(f.interactor.validations, 0)
    }
    func testInvalidValidationWithoutCompletionUsesThePresenter() {
        let f = fixture(); f.interactor.validateAccountWithMnemonic(request: mnemonic("invalid phrase"), completion: nil)
        XCTAssertEqual(f.output.errors.count, 1); XCTAssertEqual(f.interactor.validations, 0)
    }
    func testValidMnemonicValidationDoesNotBecomeAnImport() throws {
        let f = fixture(); var account: AccountItem?
        f.interactor.validateAccountWithMnemonic(request: mnemonic()) { account = try? $0?.get() }
        XCTAssertEqual(account?.address, try expected(f).address); XCTAssertEqual(f.interactor.validations, 1); XCTAssertEqual(f.interactor.imports, 0)
    }
    func testSeedPreparationAndValidationUseTheRequestedSchemeWithoutPersistence() throws {
        let f = fixture(), request = AccountImportSeedRequest(seed: "0x" + String(repeating: "07", count: 32), username: "Seed fixture", networkType: .sora, derivationPath: "", cryptoType: .ed25519)
        var imported: AccountItem?, validated: AccountItem?
        f.interactor.importAccountWithSeed(request: request) { imported = try? $0?.get() }
        f.interactor.validateAccountWithSeed(request: request) { validated = try? $0?.get() }
        XCTAssertNotNil(imported); XCTAssertEqual(imported, validated); XCTAssertEqual(imported?.cryptoType, .ed25519)
        XCTAssertEqual(f.interactor.imports, 1); XCTAssertEqual(f.interactor.validations, 1)
        XCTAssertFalse(try f.keys.checkKey(for: KeystoreTag.seedTagForAddress(try XCTUnwrap(imported).address)))
    }
    func testInvalidEncryptedKeystoreCannotProduceAnAccountInEitherMode() {
        let f = fixture(), request = AccountImportKeystoreRequest(keystore: "invalid", password: "fixture", username: "Fixture", networkType: .sora, cryptoType: .sr25519)
        f.interactor.importAccountWithKeystore(request: request, completion: nil); f.interactor.validateAccountWithKeystore(request: request, completion: nil)
        XCTAssertEqual(f.interactor.failures.count, 2); XCTAssertTrue(f.interactor.accounts.isEmpty)
    }
    func testCloudPhraseMustMatchTheSavedAddressBeforeAnyKeysArePersisted() async throws {
        let f = fixture(), account = try expected(f)
        await backup(f, value: OpenBackupAccount(name: "Cloud fixture", address: account.address, passphrase: phrase))
        XCTAssertEqual(f.interactor.accounts.first?.address, account.address); XCTAssertEqual(f.interactor.accounts.first?.username, "Cloud fixture")
        XCTAssertEqual(f.cloud.passwords, ["fixture password"]); XCTAssertTrue(f.interactor.failures.isEmpty)
        XCTAssertFalse(try f.keys.checkKey(for: KeystoreTag.entropyTagForAddress(account.address)))
    }
    func testCloudPhraseKeepsItsOriginalDerivationPath() async throws {
        let f = fixture(), account = try expected(f, path: "//public-fixture")
        await backup(f, value: OpenBackupAccount(address: account.address, passphrase: phrase, substrateDerivationPath: "//public-fixture"))
        XCTAssertEqual(f.interactor.accounts.first?.address, account.address)
    }
    func testCloudBackupForAnotherAddressCannotImportAValidPhrase() async {
        let f = fixture(); await backup(f, value: OpenBackupAccount(address: "another-wallet", passphrase: phrase))
        XCTAssertTrue(f.interactor.accounts.isEmpty); XCTAssertEqual(f.interactor.failures.count, 1)
    }
    func testCloudSeedRestoresOnlyItsMatchingIdentity() async throws {
        let f = fixture(), seed = "0x" + String(repeating: "07", count: 32)
        let op = f.factory.prepareAccountOperation(request: AccountImportSeedRequest(seed: seed, username: "", networkType: .sora, derivationPath: "", cryptoType: .ed25519))
        op.start(); let prepared = try XCTUnwrap(op.result).get(); let expected = prepared.account; prepared.discard()
        await backup(f, value: OpenBackupAccount(address: expected.address, cryptoType: "ED25519", encryptedSeed: .init(substrateSeed: seed)))
        XCTAssertEqual(f.interactor.accounts.first?.address, expected.address); XCTAssertEqual(f.interactor.accounts.first?.cryptoType, .ed25519)
    }
    func testCloudBackupWithNoUsableMaterialFailsInsteadOfCreatingAnAccount() async {
        let f = fixture(); await backup(f, value: OpenBackupAccount(address: "public-fixture", passphrase: "invalid", json: .init(substrateJson: "invalid-json")))
        XCTAssertTrue(f.interactor.accounts.isEmpty); XCTAssertEqual(f.interactor.failures.count, 1)
    }
    func testCloudReadFailureIsReportedWithoutStartingPreparation() async {
        let f = fixture(); f.cloud.failure = NSError(domain: "cloud-fixture", code: 1)
        await backup(f, value: OpenBackupAccount(address: "public-fixture"))
        XCTAssertEqual(f.output.errors.count, 1); XCTAssertEqual(f.interactor.imports, 0)
    }
}
private final class PreparationOnlyImport: BaseAccountImportInteractor {
    var imports = 0, validations = 0; var accounts: [AccountItem] = [], failures: [Error] = []; var onPrepared: (() -> Void)?
    private func prepare(_ operation: BaseOperation<PreparedAccount>) -> Result<AccountItem, Error> {
        operation.start()
        let result = Result { let value = try XCTUnwrap(operation.result).get(); defer { value.discard() }; return value.account }
        switch result { case .success(let account): accounts.append(account); case .failure(let error): failures.append(error) }
        return result
    }
    override func importAccountUsingOperation(_ operation: BaseOperation<PreparedAccount>, completion: ((Result<AccountItem, Error>?) -> Void)?) { imports += 1; let result = prepare(operation); completion?(result); onPrepared?() }
    override func validateAccountUsingOperation(_ operation: BaseOperation<PreparedAccount>, completion: ((Result<AccountItem?, Error>?) -> Void)?) { validations += 1; let result = prepare(operation).map { Optional($0) }; completion?(result) }
}
private final class PreparationImportOutput: AccountImportInteractorOutputProtocol {
    var metadata: [AccountImportMetadata] = [], suggestions: [String] = [], infos: [AccountImportPreferredInfo?] = [], errors: [Error] = []; var onError: (() -> Void)?
    func didReceiveAccountImport(metadata: AccountImportMetadata) { self.metadata.append(metadata) }
    func didCompleteAccountImport() { XCTFail("Preparation must not persist an account") }
    func didReceiveAccountImport(error: Error) { errors.append(error); onError?() }
    func didSuggestKeystore(text: String, preferredInfo: AccountImportPreferredInfo?) { suggestions.append(text); infos.append(preferredInfo) }
}
private final class PreparationImportService: KeystoreImportServiceProtocol {
    var definition: KeystoreDefinition?; weak var observer: KeystoreImportObserver?; var clears = 0
    func add(observer: KeystoreImportObserver) { self.observer = observer }; func remove(observer: KeystoreImportObserver) { self.observer = nil }
    func clear() { clears += 1; definition = nil }; func handle(url: URL) -> Bool { false }
}
private final class PreparationImportCloud: CloudStorageServiceProtocol {
    var isUserAuthorized: Bool { true }; var account = OpenBackupAccount(address: "fixture"), passwords: [String] = []; var failure: Error?
    func signInIfNeeded() async throws -> CloudStorageAccountState { .authorized }
    func getBackupAccounts() async throws -> [OpenBackupAccount] { [] }
    func importBackup(account: OpenBackupAccount, password: String) async throws -> OpenBackupAccount { passwords.append(password); if let failure { throw failure }; return self.account }
    func saveBackup(account: OpenBackupAccount, password: String) async throws { XCTFail("No cloud writes allowed") }
    func deleteBackup(account: OpenBackupAccount) async throws { XCTFail("No cloud deletions allowed") }
    func disconnect() {}
}

extension AccountImportFlowTests {
    private func publicKeystore(_ crypto: CryptoType = .ed25519) throws -> String {
        let definition = KeystoreDefinition(address: nil, encoded: "AA==",
            encoding: KeystoreEncoding(content: ["pkcs8", crypto == .ed25519 ? "ed25519" : "sr25519"], type: ["scrypt", "xsalsa20-poly1305"], version: "3"), meta: nil)
        return try XCTUnwrap(String(data: JSONEncoder().encode(definition), encoding: .utf8))
    }
    func testKeystoreValidationUsesTheSchemeDeclaredInsideTheFile() async throws {
        let (m, _, i, r) = make(), text = try publicKeystore()
        m.didSuggestKeystore(text: text, preferredInfo: .init(username: "Imported fixture", networkType: .sora, cryptoType: .sr25519, networkTypeConfirmed: true))
        m.passwordViewModel?.inputHandler.changeValue(to: "public file password"); m.proceed()
        XCTAssertEqual(i.json.first?.keystore, text); XCTAssertEqual(i.json.first?.password, "public file password")
        XCTAssertEqual(i.json.first?.cryptoType, .ed25519); XCTAssertEqual(i.json.first?.networkType, .sora)
        XCTAssertEqual(i.json.first?.username, "Imported fixture"); XCTAssertEqual(m.selectedCryptoType, .ed25519)
        i.finish(.success(nil)); await settle(); XCTAssertEqual(r.routes.first?.type, .keystore)
    }
    func testRepeatedProceedAfterKeystoreSchemeCorrectionKeepsOneValidation() async throws {
        let (model, _, interactor, routes) = make()
        model.didSuggestKeystore(text: try publicKeystore(), preferredInfo: .init(username: "Imported", networkType: .sora, cryptoType: .sr25519, networkTypeConfirmed: true))
        model.proceed(); model.proceed()
        XCTAssertEqual(interactor.json.count, 1)
        interactor.finish(.success(nil)); await settle()
        XCTAssertEqual(routes.routes.count, 1)
        XCTAssertEqual(routes.routes.first?.type, .keystore)
    }
    func testReplacingKeystoreSchemeWhileValidationRunsRejectsTheOldResult() async throws {
        let (model, _, interactor, routes) = make()
        model.didSuggestKeystore(text: try publicKeystore(), preferredInfo: .init(username: "Imported", networkType: .sora, cryptoType: .sr25519, networkTypeConfirmed: true))
        model.proceed()
        let replacement = try publicKeystore(.sr25519)
        model.didSuggestKeystore(text: replacement, preferredInfo: .init(username: "Imported", networkType: .sora, cryptoType: .sr25519, networkTypeConfirmed: true))
        interactor.finish(.success(nil)); await settle()
        XCTAssertTrue(routes.routes.isEmpty)
        model.proceed()
        XCTAssertEqual(interactor.json.count, 2)
        interactor.finish(.success(nil), index: 1); await settle()
        XCTAssertEqual(routes.routes.count, 1)
        XCTAssertEqual(routes.routes.first?.source, replacement)
    }
    func testKeystoreWithoutNetworkMetadataDefaultsToTheAllowedNetwork() throws {
        let (m, _, i, _) = make(); m.didSuggestKeystore(text: try publicKeystore(), preferredInfo: .init(username: nil, networkType: nil, cryptoType: .ed25519, networkTypeConfirmed: false))
        m.proceed(); XCTAssertEqual(i.json.first?.networkType, .sora)
    }
    func testKeystoreWithAnUnsupportedSuggestedNetworkCannotSwitchAwayFromSora() throws {
        let (m, _, i, _) = make(); m.didSuggestKeystore(text: try publicKeystore(), preferredInfo: .init(username: nil, networkType: .polkadot, cryptoType: .ed25519, networkTypeConfirmed: true))
        m.proceed(); XCTAssertEqual(i.json.first?.networkType, .sora)
    }
    func testChangingKeystorePasswordInvalidatesThePendingValidation() async throws {
        let (m, _, i, r) = make(); m.didSuggestKeystore(text: try publicKeystore(), preferredInfo: .init(username: nil, networkType: .sora, cryptoType: .ed25519, networkTypeConfirmed: true))
        m.passwordViewModel?.inputHandler.changeValue(to: "first"); m.proceed()
        m.passwordViewModel?.inputHandler.changeValue(to: "second"); i.finish(.success(nil)); await settle()
        XCTAssertTrue(r.routes.isEmpty)
    }
    func testSeedWithEd25519AcceptsOnlyHardDerivationPaths() async {
        let (m, _, i, r) = make(source: .seed, crypto: .ed25519)
        m.derivationPathViewModel?.inputHandler.changeValue(to: "/soft"); m.proceed(); XCTAssertTrue(i.seeds.isEmpty)
        XCTAssertEqual(r.errors.first as? AccountCreationError, .invalidDerivationHard)
        m.derivationPathViewModel?.inputHandler.changeValue(to: "//7"); m.proceed(); XCTAssertEqual(i.seeds.first?.derivationPath, "//7")
        i.finish(.success(nil)); await settle(); XCTAssertEqual(r.routes.first?.path, "//7")
    }
    func testMnemonicWithMalformedHardSoftPasswordPathReportsItsSpecificError() {
        let (m, _, i, r) = make(); m.derivationPathViewModel?.inputHandler.changeValue(to: "bare-path"); m.proceed()
        XCTAssertTrue(i.mnemonic.isEmpty); XCTAssertEqual(r.errors.first as? AccountCreationError, .invalidDerivationHardSoftPassword)
    }
    func testRejectedDerivationErrorCanResetFocusThroughItsDismissalCallback() {
        let (m, _, _, r) = make(crypto: .ed25519); m.derivationPathViewModel?.inputHandler.changeValue(to: "/soft"); m.proceed()
        XCTAssertEqual(r.errorCompletions.count, 1); r.errorCompletions.first?()
    }
    func testUnknownImportErrorFallsBackToAReadableGenericError() {
        let (m, _, _, r) = make(); r.handlesErrors = false
        m.didReceiveAccountImport(error: NSError(domain: "fixture", code: 42))
        XCTAssertEqual(r.errors.count, 2); XCTAssertTrue(r.errors.last is CommonError)
        XCTAssertEqual(r.errorCompletions.count, 2); r.errorCompletions.forEach { $0() }
    }
    func testKnownImportErrorUsesOnePresentationAndDismissalCallback() {
        let (m, _, _, r) = make(); m.didReceiveAccountImport(error: AccountCreateError.invalidKeystore)
        XCTAssertEqual(r.errors.count, 1); XCTAssertEqual(r.errorCompletions.count, 1); r.errorCompletions.first?()
    }
    func testSourceSuggestionBeforeMetadataDoesNotStartImportWork() {
        let m = AccountImportPresenter(config: ApplicationConfig.shared), i = ImportFlowInteractor(), r = ImportFlowRoutes()
        m.interactor = i; m.wireframe = r; m.didSuggestKeystore(text: "{}", preferredInfo: nil)
        XCTAssertNil(m.sourceViewModel); XCTAssertTrue(i.json.isEmpty)
    }
}

final class ImportValidationLifecycleTests: XCTestCase {
    private final class Fixture {
        let keys = InMemoryKeychain()
        let storage = InMemorySettingsManager()
        let selection = ValidationOnlySelection()
        let repository = InMemoryDataProviderRepository<AccountItem>()
        let output = PreparationImportOutput()
        let queue = OperationQueue()
        let gate: WalletRecoveryCapabilityGate
        let lifecycle: WalletLifecycleCoordinator
        let factory: AccountOperationFactory
        var interactor: BaseAccountImportInteractor?

        init(additional: Bool) {
            gate = WalletRecoveryCapabilityGate(settings: storage, unresolvedMigrationJournal: { false }, unresolvedWalletCommitJournal: { false })
            lifecycle = WalletLifecycleCoordinator(recoveryGate: gate)
            factory = AccountOperationFactory(keystore: keys, recoveryGate: gate)
            let manager = OperationManager(operationQueue: queue)
            if additional {
                interactor = AddAccountImportInteractor(accountOperationFactory: factory,
                    accountRepository: AnyDataProviderRepository(repository), operationManager: manager,
                    settings: selection, keystoreImportService: PreparationImportService(),
                    eventCenter: EventCenter(), lifecycleCoordinator: lifecycle)
            } else {
                interactor = AccountImportInteractor(accountOperationFactory: factory,
                    accountRepository: AnyDataProviderRepository(repository), operationManager: manager,
                    settings: selection, keystoreImportService: PreparationImportService(),
                    eventCenter: EventCenter(), lifecycleCoordinator: lifecycle)
            }
            interactor?.presenter = output
        }
        func prepare() throws -> PreparedAccount {
            let operation = factory.prepareAccountOperation(request: AccountImportSeedRequest(
                seed: "0x" + String(repeating: "07", count: 32), username: "Public fixture",
                networkType: .sora, derivationPath: "", cryptoType: .ed25519))
            operation.start()
            return try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        }
        func retain(_ account: AccountItem) throws {
            let save = repository.saveOperation({ [account] }, { [] })
            save.start()
            _ = try save.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        }
    }
    private func validate(_ f: Fixture, operation: BaseOperation<PreparedAccount>) async throws -> Result<AccountItem?, Error> {
        let completed = expectation(description: "Validation completed on main")
        var response: Result<AccountItem?, Error>?
        f.interactor!.validateAccountUsingOperation(operation) { result in
            XCTAssertTrue(Thread.isMainThread)
            response = result
            completed.fulfill()
        }
        await fulfillment(of: [completed], timeout: 3)
        return try XCTUnwrap(response)
    }
    private func assertReleased(_ f: Fixture, prepared: PreparedAccount? = nil, file: StaticString = #filePath, line: UInt = #line) throws {
        let lease = try XCTUnwrap(f.lifecycle.tryAcquire(), "The import must release its lifecycle lock", file: file, line: line)
        lease.release()
        if let prepared {
            XCTAssertThrowsError(try prepared.validatePersistence(to: f.keys), file: file, line: line) {
                XCTAssertEqual($0 as? AccountCreateError, .duplicated, file: file, line: line)
            }
            for tag in [KeystoreTag.secretKeyTagForAddress(prepared.account.address), KeystoreTag.seedTagForAddress(prepared.account.address)] {
                XCTAssertFalse(try f.keys.checkKey(for: tag), file: file, line: line)
            }
        }
        XCTAssertNil(f.selection.currentAccount, file: file, line: line)
    }
    func testNewAccountValidationDiscardsSecretsWithoutSelectingOrPersisting() async throws {
        for additional in [false, true] {
            let f = Fixture(additional: additional), prepared = try f.prepare()
            XCTAssertNoThrow(try prepared.validatePersistence(to: f.keys))
            let result = try await validate(f, operation: ClosureOperation { prepared })
            XCTAssertNil(try result.get()); XCTAssertTrue(f.output.errors.isEmpty)
            try assertReleased(f, prepared: prepared)
        }
    }
    func testDuplicateAccountValidationFailsWithoutChangingTheRetainedAccount() async throws {
        for additional in [false, true] {
            let f = Fixture(additional: additional), prepared = try f.prepare()
            try f.retain(prepared.account)
            let result = try await validate(f, operation: ClosureOperation { prepared })
            XCTAssertThrowsError(try result.get()) { XCTAssertEqual($0 as? AccountCreateError, .duplicated) }
            XCTAssertTrue(f.output.errors.isEmpty)
            try assertReleased(f, prepared: prepared)
        }
    }
    func testMissingKeysRestoreIsAcceptedWithoutPersistingDuringValidation() async throws {
        for additional in [false, true] {
            let f = Fixture(additional: additional), prepared = try f.prepare()
            try f.retain(prepared.account); f.selection.canRestore = true
            let result = try await validate(f, operation: ClosureOperation { prepared })
            XCTAssertNil(try result.get()); XCTAssertEqual(f.selection.restoreChecks, 1)
            try assertReleased(f, prepared: prepared)
        }
    }
    func testValidationPreparationFailureReachesPresenterAndCompletionAndReleasesTheLock() async throws {
        for additional in [false, true] {
            let f = Fixture(additional: additional)
            let result = try await validate(f, operation: ClosureOperation { throw AccountCreateError.invalidSeed })
            XCTAssertThrowsError(try result.get()) { XCTAssertEqual($0 as? AccountCreateError, .invalidSeed) }
            XCTAssertEqual(f.output.errors.count, 1)
            XCTAssertEqual(f.output.errors.first as? AccountCreateError, .invalidSeed)
            try assertReleased(f)
        }
    }
    func testValidationWithoutAnOperationResultReportsCancellationAndReleasesTheLock() async throws {
        for additional in [false, true] {
            let f = Fixture(additional: additional)
            let result = try await validate(f, operation: BaseOperation<PreparedAccount>())
            XCTAssertThrowsError(try result.get()) { XCTAssertEqual($0 as? BaseOperationError, .parentOperationCancelled) }
            XCTAssertEqual(f.output.errors.count, 1)
            try assertReleased(f)
        }
    }
    func testLeavingValidationDiscardsPreparedSecretsAndReleasesTheLock() async throws {
        try await abandoningOperation(importing: false)
    }
    func testLeavingImportDiscardsPreparedSecretsAndReleasesTheLock() async throws {
        try await abandoningOperation(importing: true)
    }
    private func abandoningOperation(importing: Bool) async throws {
        for additional in [false, true] {
            let f = Fixture(additional: additional), prepared = try f.prepare()
            f.queue.isSuspended = true
            let operation = ClosureOperation { prepared }
            if importing {
                f.interactor!.importAccountUsingOperation(operation) { _ in XCTFail("The abandoned screen must not receive a completion") }
            } else {
                f.interactor!.validateAccountUsingOperation(operation) { _ in XCTFail("The abandoned screen must not receive a completion") }
            }
            let callback = try XCTUnwrap(operation.completionBlock)
            let completed = expectation(description: "Abandoned operation cleaned up")
            operation.completionBlock = { callback(); completed.fulfill() }
            weak var subject = f.interactor
            f.interactor = nil
            XCTAssertNil(subject)
            f.queue.isSuspended = false
            await fulfillment(of: [completed], timeout: 3)
            try assertReleased(f, prepared: prepared)
            XCTAssertTrue(f.output.errors.isEmpty)
        }
    }
    func testImportPreparationFailureReachesPresenterAndCompletionAndReleasesTheLock() async throws {
        for additional in [false, true] {
            let f = Fixture(additional: additional)
            let completed = expectation(description: "Import failure delivered on main")
            f.interactor!.importAccountUsingOperation(ClosureOperation { throw AccountCreateError.invalidSeed }) { result in
                XCTAssertTrue(Thread.isMainThread)
                guard case .failure(let error)? = result else { XCTFail("Expected import failure"); completed.fulfill(); return }
                XCTAssertEqual(error as? AccountCreateError, .invalidSeed)
                completed.fulfill()
            }
            await fulfillment(of: [completed], timeout: 3)
            XCTAssertEqual(f.output.errors.count, 1)
            try assertReleased(f)
        }
    }
}
private final class ValidationOnlySelection: SelectedWalletSettingsProtocol {
    var currentAccount: AccountItem? { nil }
    var canRestore = false, restoreChecks = 0
    func restoresKeysInPlace(existing: AccountItem, imported: AccountItem) throws -> Bool {
        XCTAssertEqual(existing.address, imported.address)
        restoreChecks += 1
        return canRestore
    }
    func performUpdateName(account: AccountItem, displayName: String, completionClosure: @escaping (Result<AccountItem, Error>) -> Void) { XCTFail("Unexpected rename") }
    func performSave(value: AccountItem, completionClosure: @escaping (Result<AccountItem, Error>) -> Void) { XCTFail("Unexpected wallet mutation") }
    func performInsertAndSelect(prepared: PreparedAccount, persistSecrets: @escaping () throws -> Void, lifecycleLease: WalletLifecycleLease, completionClosure: @escaping (Result<AccountItem, Error>) -> Void) { XCTFail("Validation must not import") }
    func performSelectAfterRemoval(value: AccountItem, lifecycleLease: WalletLifecycleLease, completionClosure: @escaping (Result<AccountItem, Error>) -> Void) { XCTFail("Unexpected removal") }
    func performUpdateAssetSettings(account: AccountItem, settings: AccountSettings, completionClosure: @escaping (Result<AccountItem, Error>) -> Void) { XCTFail("Unexpected wallet mutation") }
    func performSetup(completionClosure: @escaping (Result<AccountItem?, Error>) -> Void) { completionClosure(.success(nil)) }
    func save(value: AccountItem) { XCTFail("Unexpected wallet mutation") }
}
