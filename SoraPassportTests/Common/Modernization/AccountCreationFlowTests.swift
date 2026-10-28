// SPDX-License-Identifier: BSD-4-Clause
import UIKit
import Foundation
import IrohaCrypto
import SoraFoundation
import SSFCloudStorage
import XCTest
@testable import SoraPassport

@MainActor
final class AccountCreationFlowTests: XCTestCase {
    private func fixture(google: Bool = true, signedIn: Bool = false) -> CreationFixture {
        CreationFixture(google: google, signedIn: signedIn)
    }
    func testSetupRequestsMetadataOnce() { let f = fixture(); f.presenter.setup(); XCTAssertEqual(f.input.setups, 1) }
    func testMetadataPublishesExactMnemonicToTheView() { let f = fixture(); f.ready(); XCTAssertEqual(f.view.words, f.words) }
    func testProceedBeforeMetadataDoesNothing() { let f = fixture(); f.presenter.proceed(); XCTAssertEqual(f.routes.confirmations.count, 0); XCTAssertEqual(f.routes.backups.count, 0) }
    func testSkipBeforeMetadataDoesNotCreateAnAccount() { let f = fixture(); f.presenter.skip(); XCTAssertTrue(f.input.creations.isEmpty) }
    func testLocalProceedKeepsTheUsernameAndChosenCrypto() {
        let f = fixture(google: false); f.ready(crypto: .ed25519); f.presenter.proceed()
        XCTAssertEqual(f.routes.confirmations.count, 1)
        XCTAssertEqual(f.routes.confirmations.first?.username, "Public fixture")
        XCTAssertEqual(f.routes.confirmations.first?.cryptoType, .ed25519)
        XCTAssertEqual(f.routes.confirmations.first?.derivationPath, "")
        XCTAssertEqual(f.routes.metadata.first?.mnemonic, f.words)
    }
    func testLocalSkipCreatesUsingTheReviewedMnemonic() {
        let f = fixture(google: false); f.ready(); f.presenter.skip()
        XCTAssertEqual(f.input.creations.count, 1); XCTAssertEqual(f.input.mnemonics.first, f.words)
        XCTAssertTrue(f.routes.backups.isEmpty)
    }
    func testLocalProceedDoesNotSilentlyChooseGoogleFromAnExistingSignIn() {
        let f = fixture(google: false, signedIn: true); f.ready(); f.presenter.proceed()
        XCTAssertEqual(f.routes.confirmations.count, 1); XCTAssertTrue(f.routes.backups.isEmpty)
    }
    func testLocalSkipDoesNotSilentlyChooseGoogleFromAnExistingSignIn() {
        let f = fixture(google: false, signedIn: true); f.ready(); f.presenter.skip()
        XCTAssertEqual(f.input.creations.count, 1); XCTAssertTrue(f.routes.backups.isEmpty)
    }
    func testGoogleProceedPassesExactBackupMaterialToPasswordReview() {
        let f = fixture(google: true, signedIn: true); f.ready(crypto: .ecdsa); f.presenter.proceed()
        XCTAssertEqual(f.routes.backups.count, 1)
        XCTAssertEqual(f.routes.backups.first?.name, "Public fixture")
        XCTAssertEqual(f.routes.backups.first?.passphrase, f.words.joined(separator: " "))
        XCTAssertEqual(f.routes.backups.first?.cryptoType, CryptoType.ecdsa.typeString)
        XCTAssertEqual(f.routes.backups.first?.substrateDerivationPath, "")
        XCTAssertTrue(f.routes.confirmations.isEmpty); XCTAssertTrue(f.input.creations.isEmpty)
    }
    func testGoogleSkipStillRequiresBackupPasswordReview() {
        let f = fixture(google: true, signedIn: true); f.ready(); f.presenter.skip()
        XCTAssertEqual(f.routes.backups.count, 1); XCTAssertTrue(f.input.creations.isEmpty)
    }
    func testInvalidMnemonicCannotProceed() {
        let f = fixture(); f.ready(words: ["not", "a", "valid", "mnemonic"]); f.presenter.proceed()
        XCTAssertTrue(f.routes.confirmations.isEmpty); XCTAssertTrue(f.routes.backups.isEmpty)
    }
    func testInvalidMnemonicCannotSkip() {
        let f = fixture(); f.ready(words: ["invalid"]); f.presenter.skip(); XCTAssertTrue(f.input.creations.isEmpty)
    }
    func testRetainedBackupPathIsPassedUnchangedToTheView() {
        let f = fixture(); f.presenter.didReceive(backupDerivationPath: "//public//fixture")
        XCTAssertEqual(f.view.backupPaths, ["//public//fixture"])
    }
    func testMnemonicGenerationErrorUsesSpecificPresentationWhenSupported() {
        let f = fixture(); f.presenter.didReceiveMnemonicGeneration(error: CreationFailure.generation)
        XCTAssertEqual(f.routes.errors.count, 1)
    }
    func testUnknownMnemonicGenerationErrorFallsBackToGeneralMessage() {
        let f = fixture(); f.routes.handlesError = false
        f.presenter.didReceiveMnemonicGeneration(error: CreationFailure.generation)
        XCTAssertEqual(f.routes.errors.count, 2)
    }
    func testAccountCreationFailureStopsLoadingAndIsVisible() {
        let f = fixture(); f.presenter.didReceive(error: CreationFailure.persistence)
        XCTAssertEqual(f.view.hides, 1); XCTAssertEqual(f.routes.errors.count, 1)
    }
    func testAccountCreationUnknownFailureHasGeneralFallback() {
        let f = fixture(); f.routes.handlesError = false
        f.presenter.didReceive(error: CreationFailure.persistence)
        XCTAssertEqual(f.routes.errors.count, 2)
    }
    func testBackupSignInShowsLoadingUntilCompletion() {
        let f = fixture(); f.ready(); f.presenter.backupToGoogle()
        XCTAssertEqual(f.view.shows, 1); XCTAssertEqual(f.view.hides, 0)
        f.input.finish(.notAuthorized)
        XCTAssertEqual(f.view.hides, 1); XCTAssertTrue(f.routes.backups.isEmpty)
    }
    func testRepeatedBackupTapHasOnlyOneAuthorizationInFlight() {
        let f = fixture(); f.ready(); f.presenter.backupToGoogle(); f.presenter.backupToGoogle()
        XCTAssertEqual(f.input.authorizations.count, 1); XCTAssertEqual(f.view.shows, 1)
    }
    func testDeniedGoogleAuthorizationDoesNotCreateAnAccount() {
        let f = fixture(); f.ready(); f.presenter.backupToGoogle(); f.input.finish(.notAuthorized)
        XCTAssertTrue(f.input.creations.isEmpty); XCTAssertTrue(f.routes.backups.isEmpty)
    }
    func testExplicitGoogleBackupChoiceOverridesPreviousLocalChoice() {
        let f = fixture(google: false); f.ready(); f.presenter.backupToGoogle(); f.input.finish(.authorized)
        XCTAssertEqual(f.routes.backups.count, 1); XCTAssertTrue(f.input.creations.isEmpty)
    }
    func testAuthorizationCanBeRetriedAfterDenial() {
        let f = fixture(); f.ready(); f.presenter.backupToGoogle(); f.input.finish(.notAuthorized)
        f.presenter.backupToGoogle(); f.input.finish(.authorized)
        XCTAssertEqual(f.input.authorizationCount, 2); XCTAssertEqual(f.routes.backups.count, 1)
    }
    func testLateAuthorizationCannotAdvanceChangedMnemonicReview() {
        let f = fixture(); f.ready(); f.presenter.backupToGoogle(); f.ready(crypto: .ed25519)
        f.input.finish(.authorized)
        XCTAssertTrue(f.routes.backups.isEmpty); XCTAssertTrue(f.input.creations.isEmpty)
    }
    func testAuthorizationCompletionUpdatesUIOnMainThread() async throws {
        let f = fixture(); f.ready(); f.presenter.backupToGoogle()
        let completion = try XCTUnwrap(f.input.authorizations.first); f.input.signedIn = true
        await withCheckedContinuation { continuation in DispatchQueue.global().async { completion(.authorized); continuation.resume() } }
        for _ in 0..<20 { if !f.routes.backups.isEmpty { break }; try? await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertEqual(f.routes.backups.count, 1); XCTAssertTrue(f.view.threads.allSatisfy { $0 }); XCTAssertTrue(f.routes.threads.allSatisfy { $0 })
    }
    func testInfoActionPresentsLocalizedRecoveryExplanation() {
        let f = fixture(); f.presenter.activateInfo()
        XCTAssertEqual(f.routes.messages.count, 1); XCTAssertFalse(f.routes.messages.first?.isEmpty ?? true)
    }
}

private enum CreationFailure: Swift.Error { case generation, persistence }
@MainActor
private final class CreationFixture {
    let words = Array(repeating: "abandon", count: 11) + ["about"]
    let view = CreationView(), input = CreationInput(), routes = CreationRoutes()
    let presenter: AccountCreatePresenter
    init(google: Bool, signedIn: Bool) {
        presenter = AccountCreatePresenter(username: "Public fixture", shouldCreatedWithGoogle: google, createAccountService: CreationNoService())
        input.signedIn = signedIn; presenter.view = view; presenter.interactor = input; presenter.wireframe = routes
        presenter.localizationManager = LocalizationManager(localization: "en")
    }
    func ready(crypto: CryptoType = .sr25519, words: [String]? = nil) {
        presenter.didReceive(metadata: AccountCreationMetadata(mnemonic: words ?? self.words, availableNetworks: [.sora], defaultNetwork: .sora, availableCryptoTypes: CryptoType.allCases, defaultCryptoType: crypto))
    }
}
private final class CreationView: UIViewController, AccountCreateViewProtocol {
    var words = [String](), backupPaths = [String](), shows = 0, hides = 0, threads = [Bool]()
    func set(mnemonic: [String]) { words = mnemonic; threads.append(Thread.isMainThread) }
    func set(backupDerivationPath: String) { backupPaths.append(backupDerivationPath) }
    func showLoading() { shows += 1; threads.append(Thread.isMainThread) }
    func hideLoading() { hides += 1; threads.append(Thread.isMainThread) }
}
private final class CreationInput: AccountCreateInteractorInputProtocol {
    var cloudStorageService: CloudStorageServiceProtocol?
    var signedIn = false, setups = 0, authorizationCount = 0
    var isSignedInGoogleAccount: Bool { signedIn }
    var authorizations = [(CloudStorageAccountState) -> Void](), creations = [AccountCreationRequest](), mnemonics = [[String]]()
    func setup() { setups += 1 }
    func skipConfirmation(request: AccountCreationRequest, mnemonic: IRMnemonicProtocol) { creations.append(request); mnemonics.append(mnemonic.allWords()) }
    func signInToGoogleIfNeeded(completion: @escaping (CloudStorageAccountState) -> Void) { authorizationCount += 1; authorizations.append(completion) }
    func finish(_ state: CloudStorageAccountState) { signedIn = state == .authorized; if !authorizations.isEmpty { authorizations.removeFirst()(state) } }
}
private final class CreationNoService: CreateAccountServiceProtocol {
    func createAccount(request: AccountCreationRequest, mnemonic: IRMnemonicProtocol, completion: @escaping (Result<AccountItem, Swift.Error>?) -> Void) { XCTFail("No account persistence in presenter tests") }
}
private final class CreationRoutes: AccountCreateWireframeProtocol {
    var activityIndicatorWindow: UIWindow?
    var confirmations = [AccountCreationRequest](), metadata = [AccountCreationMetadata](), backups = [OpenBackupAccount](), errors = [Swift.Error](), messages = [String](), threads = [Bool]()
    var handlesError = true
    func proceed(on controller: UIViewController?) { threads.append(Thread.isMainThread) }
    func confirm(from view: AccountCreateViewProtocol?, request: AccountCreationRequest, metadata: AccountCreationMetadata) { confirmations.append(request); self.metadata.append(metadata); threads.append(Thread.isMainThread) }
    func setupBackupAccountPassword(on controller: AccountCreateViewProtocol?, account: OpenBackupAccount, createAccountRequest: AccountCreationRequest, createAccountService: CreateAccountServiceProtocol, mnemonic: IRMnemonicProtocol) { backups.append(account); threads.append(Thread.isMainThread) }
    func present(error: Swift.Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool { errors.append(error); return handlesError }
    func present(error: Swift.Error, from view: ControllerBackedProtocol?, locale: Locale?, completion: @escaping () -> Void) -> Bool { errors.append(error); return handlesError }
    func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?) { messages.append(message ?? "") }
    func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?, completion: @escaping () -> Void) { messages.append(message ?? "") }
    func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?) {}
}
