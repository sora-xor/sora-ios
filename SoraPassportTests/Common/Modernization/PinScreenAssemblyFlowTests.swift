// SPDX-License-Identifier: Apache-2.0
import Foundation
import UIKit
import SoraFoundation
import SoraKeystore
import XCTest

@testable import SoraPassport

/// Constructs the real PIN flow without loading its UIKit lifecycle or reading
/// device authentication. The edit grant is authenticated against an isolated
/// in-memory key store; no production PIN is entered or changed.
@MainActor
final class PinScreenAssemblyFlowTests: XCTestCase {
  private func setup() throws -> (PincodeViewController, SetupPincodePresenter, PinSetupInteractor)
  {
    let view = try XCTUnwrap(PinViewFactory.createRedesignPinSetupView() as? PincodeViewController)
    let presenter = try XCTUnwrap(view.presenter as? SetupPincodePresenter)
    return (view, presenter, try XCTUnwrap(presenter.interactor as? PinSetupInteractor))
  }
  private func authorization() throws -> WalletOwnerPIN.Authorization {
    let keys = InMemoryKeychain()
    let settings = InMemorySettingsManager()
    try keys.saveKey(Data("123456".utf8), with: KeystoreTag.pincode.rawValue)
    let gate = WalletRecoveryCapabilityGate(
      settings: settings, unresolvedMigrationJournal: { false },
      unresolvedWalletCommitJournal: { false }, credentialRepairPending: { false })
    return try WalletOwnerPIN(keystore: keys, settings: settings, recoveryGate: gate)
      .authenticateCurrent("123456", accounts: [])
  }
  func testInitialPinAssemblyStartsInCreateModeWithoutLoadingView() throws {
    let (v, p, i) = try setup()
    XCTAssertEqual(v.mode, .create)
    XCTAssertFalse(v.isViewLoaded)
    XCTAssertFalse(p.isNeedChangePinCode)
    XCTAssertEqual(i.state, .waitingPincode)
  }
  func testInitialPinAssemblyConnectsPresenterViewAndInteractorBothWays() throws {
    let (v, p, i) = try setup()
    XCTAssertTrue(p.view === v)
    XCTAssertTrue(i.presenter === p)
    XCTAssertTrue(p.wireframe is PinSetupWireframe)
  }
  func testInitialPinAssemblyDoesNotRetainItsViewThroughPresenter() throws {
    var v: PincodeViewController? = try setup().0
    weak var observed = v
    let p = try XCTUnwrap(v?.presenter as? SetupPincodePresenter)
    v = nil
    XCTAssertNil(observed)
    XCTAssertNil(p.view)
  }
  func testIndependentSetupAssembliesDoNotSharePartiallyEnteredPins() throws {
    let (_, first, _) = try setup()
    let (_, second, _) = try setup()
    first.inputedPinCode = "12"
    first.savedPinCode = "123456"
    XCTAssertEqual(second.inputedPinCode, "")
    XCTAssertEqual(second.savedPinCode, "")
  }
  func testAuthenticatedPinEditUsesChangeModeAndFreshInteractor() throws {
    let v = try XCTUnwrap(
      PinViewFactory.createRedesignPinEditView(authorization: try authorization())
        as? PincodeViewController)
    let p = try XCTUnwrap(v.presenter as? SetupPincodePresenter)
    let i = try XCTUnwrap(p.interactor as? PinSetupInteractor)
    XCTAssertEqual(v.mode, .create)
    XCTAssertTrue(p.isNeedChangePinCode)
    XCTAssertEqual(i.state, .waitingPincode)
    XCTAssertNil(i.pincode)
    XCTAssertTrue(p.view === v)
    XCTAssertTrue(i.presenter === p)
  }
  func testSecuredPinAssemblyUsesVerificationRatherThanSetupPresenter() throws {
    let v = try XCTUnwrap(PinViewFactory.createRedesignSecuredPinView() as? PincodeViewController)
    let p = try XCTUnwrap(v.presenter as? InputPincodePresenter)
    XCTAssertEqual(v.mode, .securedInput)
    XCTAssertTrue(p.view === v)
    XCTAssertTrue(p.interactor is LocalAuthInteractor)
    XCTAssertTrue(p.wireframe is PinSetupWireframe)
    XCTAssertFalse(v.isViewLoaded)
  }
  func testSecuredPinInteractorReturnsToItsOwnPresenter() throws {
    let v = try XCTUnwrap(PinViewFactory.createRedesignSecuredPinView() as? PincodeViewController)
    let p = try XCTUnwrap(v.presenter as? InputPincodePresenter)
    let i = try XCTUnwrap(p.interactor as? LocalAuthInteractor)
    XCTAssertTrue(i.presenter === p)
  }
  func testCancellableAuthorizationAssemblyPreservesCancellationChoice() throws {
    let route = PinAssemblyRoute()
    let v = try XCTUnwrap(
      PinViewFactory.createRedesignScreenAuthorizationView(with: route, cancellable: true)
        as? PincodeViewController)
    XCTAssertEqual(v.mode, .securedInput)
    XCTAssertTrue(v.cancellable)
    XCTAssertFalse(v.isViewLoaded)
  }
  func testMandatoryAuthorizationAssemblyPreservesNoncancellableChoice() throws {
    let route = PinAssemblyRoute()
    let v = try XCTUnwrap(
      PinViewFactory.createRedesignScreenAuthorizationView(with: route, cancellable: false)
        as? PincodeViewController)
    XCTAssertFalse(v.cancellable)
    XCTAssertTrue(v.presenter is AuthorizationPresenter)
  }
  func testAuthorizationAssemblyBindsOnlyTheRequestedCompletionRoute() throws {
    let route = PinAssemblyRoute()
    let v = try XCTUnwrap(
      PinViewFactory.createRedesignScreenAuthorizationView(with: route, cancellable: true)
        as? PincodeViewController)
    let p = try XCTUnwrap(v.presenter as? AuthorizationPresenter)
    let i = try XCTUnwrap(p.interactor as? LocalAuthInteractor)
    XCTAssertTrue(p.view === v)
    XCTAssertTrue(p.wireframe === route)
    XCTAssertTrue(i.presenter === p)
    p.cancel()
    XCTAssertEqual(route.results, [false])
  }
  func testAuthorizationAssemblyDoesNotApproveBeforeExplicitAuthentication() throws {
    let route = PinAssemblyRoute()
    _ = try XCTUnwrap(
      PinViewFactory.createRedesignScreenAuthorizationView(with: route, cancellable: true))
    XCTAssertTrue(route.results.isEmpty)
  }
  func testReleasedAuthorizationViewIsNotRetainedByTheInteractor() throws {
    let route = PinAssemblyRoute()
    var v: PincodeViewController? = try XCTUnwrap(
      PinViewFactory.createRedesignScreenAuthorizationView(with: route, cancellable: true)
        as? PincodeViewController)
    weak var observed = v
    let p = try XCTUnwrap(v?.presenter as? AuthorizationPresenter)
    v = nil
    XCTAssertNil(observed)
    XCTAssertNil(p.view)
  }
}
private final class PinAssemblyRoute: ScreenAuthorizationWireframeProtocol {
  var results = [Bool]()
  func showAuthorizationCompletion(with result: Bool) { results.append(result) }
}

@MainActor
final class PinSetupPresenterLifecycleTests: XCTestCase {
    private var oldLanguage = "en"
    override func setUp() { super.setUp(); oldLanguage = LocalizationManager.shared.selectedLocalization; LocalizationManager.shared.selectedLocalization = "en" }
    override func tearDown() { LocalizationManager.shared.selectedLocalization = oldLanguage; super.tearDown() }
    private func fixture() -> (SetupPincodePresenter, PinPresenterView, PinPresenterInput, PinPresenterRoute) {
        let p = SetupPincodePresenter(), v = PinPresenterView(), i = PinPresenterInput(), r = PinPresenterRoute()
        p.view = v; p.interactor = i; p.wireframe = r; return (p,v,i,r)
    }
    private func enter(_ text: String, into p: SetupPincodePresenter) { text.forEach { p.padButtonTapped(with: String($0)) } }
    private func settle() async { for _ in 0..<5 { await Task.yield() }; try? await Task.sleep(nanoseconds: 20_000_000) }
    func testStartRequestsSixDigitsAndDisablesTheBiometricAccessory() {
        let (p,v,_,_) = fixture(); p.start()
        XCTAssertEqual(v.symbolCounts, [6]); XCTAssertEqual(v.accessory, [false]); XCTAssertFalse(v.titles.first?.isEmpty ?? true)
    }
    func testFirstEntryRequiresConfirmationBeforeAnyPersistence() {
        let (p,v,i,_) = fixture(); enter("123456", into: p)
        XCTAssertEqual(p.savedPinCode, "123456"); XCTAssertEqual(p.inputedPinCode, "")
        XCTAssertTrue(i.created.isEmpty); XCTAssertTrue(i.changed.isEmpty); XCTAssertEqual(v.circles.last, 0); XCTAssertEqual(v.deleteHidden.last, true)
    }
    func testMatchingConfirmationSubmitsTheExactPinOnce() {
        let (p,_,i,_) = fixture(); enter("123456123456", into: p)
        XCTAssertEqual(i.created, ["123456"]); XCTAssertTrue(i.changed.isEmpty)
        p.padButtonTapped(with: "7"); XCTAssertEqual(i.created, ["123456"])
    }
    func testChangeModeUsesAuthenticatedChangeRatherThanCreation() {
        let (p,_,i,_) = fixture(); p.isNeedChangePinCode = true; enter("654321654321", into: p)
        XCTAssertEqual(i.changed, ["654321"]); XCTAssertTrue(i.created.isEmpty)
    }
    func testMismatchedConfirmationClearsBothEntriesOnlyAfterErrorAnimation() {
        let (p,v,i,_) = fixture(); enter("123456654321", into: p)
        XCTAssertEqual(v.errors, 1); XCTAssertEqual(p.savedPinCode, "123456"); XCTAssertEqual(p.inputedPinCode, "654321")
        XCTAssertTrue(i.created.isEmpty); v.errorCompletion?(true)
        XCTAssertEqual(p.savedPinCode, ""); XCTAssertEqual(p.inputedPinCode, ""); XCTAssertEqual(v.circles.last, 0)
    }
    func testDeletingDigitsUpdatesTheVisibleCountAndStopsAtEmpty() {
        let (p,v,_,_) = fixture(); p.deleteButtonTapped(); XCTAssertTrue(v.circles.isEmpty)
        enter("123", into: p); p.deleteButtonTapped(); XCTAssertEqual(p.inputedPinCode, "12"); XCTAssertEqual(v.circles.last, 2)
        p.deleteButtonTapped(); p.deleteButtonTapped(); p.deleteButtonTapped()
        XCTAssertEqual(p.inputedPinCode, ""); XCTAssertEqual(v.deleteHidden.last, true)
    }
    func testDirectSubmissionUsesTheCurrentMode() {
        let (p,_,i,_) = fixture(); p.submit(pin: "123456"); p.isNeedChangePinCode = true; p.submit(pin: "654321")
        XCTAssertEqual(i.created, ["123456"]); XCTAssertEqual(i.changed, ["654321"])
    }
    func testSuccessfulCreationOpensMainOnlyAfterSaveCompletes() async {
        let (p,_,_,r) = fixture(); XCTAssertTrue(r.routes.isEmpty); p.didSavePin(); await settle(); XCTAssertEqual(r.routes, ["main"])
    }
    func testSuccessfulChangeDismissesItsEditor() async {
        let (p,_,_,r) = fixture(); p.isNeedChangePinCode = true; p.didSavePin(); await settle(); XCTAssertEqual(r.routes, ["dismiss"])
    }
    func testSixDigitUpgradeCallsItsBoundCompletionWithoutRoutingAway() async {
        let (p,_,_,r) = fixture(); p.isUpdateTo6Symbols = true; var completed = 0; p.completion = { completed += 1 }
        p.didSavePin(); await settle(); XCTAssertEqual(completed, 1); XCTAssertTrue(r.routes.isEmpty)
    }
    func testSaveFailureErasesBothPinsAndShowsSafeFallbackContent() async {
        let (p,v,_,r) = fixture(); p.savedPinCode = "123456"; p.inputedPinCode = "123"
        p.didReceiveConfigError(NSError(domain: "fixture", code: 1, userInfo: [NSLocalizedDescriptionKey: "sensitive detail"]))
        await settle(); XCTAssertEqual(p.savedPinCode, ""); XCTAssertEqual(p.inputedPinCode, ""); XCTAssertEqual(v.circles.last, 0)
        XCTAssertEqual(r.errors, 1); XCTAssertTrue(r.messages.last?.contains("wallet keys are unchanged") == true); XCTAssertFalse(r.messages.joined().contains("sensitive detail"))
    }
    func testRecognizedSaveErrorDoesNotPresentASecondAlert() async {
        let (p,_,_,r) = fixture(); r.recognizesError = true; p.didReceiveConfigError(NSError(domain: "fixture", code: 1)); await settle()
        XCTAssertEqual(r.errors, 1); XCTAssertTrue(r.messages.isEmpty)
    }
    func testBiometricDecisionRemainsExplicitAndIsDeliveredOnMain() async {
        let (p,v,_,_) = fixture(); var decision: Bool?
        p.didStartWaitingBiometryDecision(type: .touchId) { decision = $0 }; await settle()
        XCTAssertEqual(v.biometryRequests, 1); XCTAssertNil(decision); v.biometryCompletion?(false); XCTAssertEqual(decision, false)
    }
    func testPresenterDoesNotKeepThePinEntryScreenAlive() {
        let p = SetupPincodePresenter(); var view: PinPresenterView? = PinPresenterView(); weak var prior = view; p.view = view; view = nil
        XCTAssertNil(prior); p.start(); p.deleteButtonTapped()
    }
}
private final class PinPresenterInput: PinSetupInteractorInputProtocol {
    var created: [String] = [], changed: [String] = []
    func process(pin: String) { created.append(pin) }
    func change(pin: String) { changed.append(pin) }
}
private final class PinPresenterView: UIViewController, PinSetupViewProtocol {
    var controller: UIViewController { self }
    var symbolCounts: [Int] = [], circles: [Int] = [], accessory: [Bool] = [], deleteHidden: [Bool] = [], titles: [String] = []
    var errors = 0, biometryRequests = 0; var errorCompletion: ((Bool) -> Void)?, biometryCompletion: ((Bool) -> Void)?
    var asked: UIViewController?
    override func present(_ viewController: UIViewController, animated: Bool, completion: (() -> Void)? = nil) { asked = viewController }
    func didRequestBiometryUsage(biometryType: AvailableBiometryType, completionBlock: @escaping (Bool) -> Void) { XCTAssertTrue(Thread.isMainThread); biometryRequests += 1; biometryCompletion = completionBlock }
    func didChangeAccessoryState(enabled: Bool) { accessory.append(enabled) }
    func didReceiveWrongPincode() { errors += 1 }
    func updatePinCodeSymbolsCount(with count: Int) { symbolCounts.append(count) }
    func showUpdatePinRequestView() {}; func blockUserInputUntil(date: Date) {}; func showLastChanceAlert() {}
    func updateInputedCircles(with count: Int) { circles.append(count) }
    func setupDeleteButton(isHidden: Bool) { deleteHidden.append(isHidden) }
    func setupTitleLabel(text: String) { titles.append(text) }
    func resetTitleColor() {}
    func animateWrongInputError(with completion: @escaping (Bool) -> Void) { errors += 1; errorCompletion = completion }
    func askBiometryPermission() {}
}
private final class PinPresenterRoute: PinSetupWireframeProtocol {
    var routes: [String] = [], messages: [String] = []; var recognizesError = false, errors = 0
    func dismiss(from view: PinSetupViewProtocol?) { routes.append("dismiss") }
    func showMain(from view: PinSetupViewProtocol?) { routes.append("main") }
    func showSignup(from view: PinSetupViewProtocol?) { routes.append("signup") }
    func showPinUpdatedNotify(from view: PinSetupViewProtocol?, completionBlock: @escaping () -> Void) { completionBlock() }
    func present(error: Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool { errors += 1; return recognizesError }
    func present(error: Error, from view: ControllerBackedProtocol?, locale: Locale?, completion: @escaping () -> Void) -> Bool { present(error: error, from: view, locale: locale) }
    func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?) { messages.append(message ?? "") }
    func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?, completion: @escaping () -> Void) { messages.append(message ?? "") }
    func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?) { XCTFail("Unexpected custom alert") }
}

@MainActor
final class LocalAuthLifecycleBoundaryTests: XCTestCase {
    private struct Fixture {
        let subject: LocalAuthInteractor; let store: InMemoryKeychainManager; let settings: InMemorySettingsManager
        let output: AuthBoundaryOutput; let biometry: AuthBoundaryBiometry
    }
    private func fixture(pin: String? = "123456", enabled: Bool? = true, type: AvailableBiometryType = .touchId,
                         failCount: Int = 0, accounts: @escaping () throws -> [AccountItem] = { [] },
                         store: InMemoryKeychainManager = InMemoryKeychainManager(),
                         settings: InMemorySettingsManager = InMemorySettingsManager(),
                         ownerKeys: KeystoreProtocol? = nil, allowsBiometry: Bool = true) throws -> Fixture {
        let output = AuthBoundaryOutput(), biometry = AuthBoundaryBiometry()
        if let pin { try store.keychain.saveKey(Data(pin.utf8), with: KeystoreTag.pincode.rawValue) }
        settings.biometryEnabled = enabled; settings.failInputPinCount = failCount; biometry.availableBiometryType = type
        let subject = LocalAuthInteractor(secretManager: store, settingsManager: settings, biometryAuth: biometry,
            locale: Locale(identifier: "en"), ownerPINKeystore: ownerKeys ?? store.keychain, recoveryGate: gate(settings), accounts: accounts,
            allowsBiometry: allowsBiometry)
        subject.presenter = output
        return Fixture(subject: subject, store: store, settings: settings, output: output, biometry: biometry)
    }
    private func gate(_ settings: InMemorySettingsManager) -> WalletRecoveryCapabilityGate {
        WalletRecoveryCapabilityGate(settings: settings, unresolvedMigrationJournal: { false }, unresolvedWalletCommitJournal: { false }, credentialRepairPending: { false })
    }
    /// A real wallet whose keys are in `store`, so it is proven exactly as on a
    /// device. `bound` adds the owner binding that 3.9.1 and later write.
    private func wallet(in store: InMemoryKeychainManager, settings: InMemorySettingsManager, bound: Bool) throws -> AccountItem {
        try AccountCreationHelper.createAccountFromMnemonic(cryptoType: .sr25519, keychain: store.keychain, settings: settings)
        let account = try XCTUnwrap(settings.currentAccount)
        if bound {
            try store.keychain.saveKey(JSONEncoder().encode(WalletOwnerPIN.Binding(pin: "123456")),
                                       with: account.address + WalletOwnerPIN.bindingSuffix)
        }
        return account
    }
    private func waitUntil(timeout: TimeInterval = 3, _ predicate: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !predicate() && Date() < deadline { try? await Task.sleep(nanoseconds: 5_000_000) }
        XCTAssertTrue(predicate(), file: file, line: line)
    }
    /// A typed PIN that creates owner bindings runs scrypt; allow for it.
    private func authenticate(_ f: Fixture, pin: String = "123456", timeout: TimeInterval = 3) async {
        f.subject.process(pin: pin); await waitUntil(timeout: timeout) { f.subject.state != .checkingPincode }
    }
    func testCooldownScheduleAndLastChanceAreExplicitForEveryAttempt() {
        let minutes = [0, 0, 0, 1, 5, 15, 30, 30, 30, 30, 30]
        for count in 0...10 { let value = FailureAuthCount(value: count)
            XCTAssertEqual(value.cooldownMinutes, minutes[count]); XCTAssertEqual(value.isLastTry, count == 2)
            XCTAssertEqual(value.isBlockedTry, count >= 3)
        }
        XCTAssertEqual(FailureAuthCount(value: -1), .unknown); XCTAssertEqual(FailureAuthCount(value: 900), .unknown)
    }
    func testManualBiometryAndSavedBlockDateComeFromTheInjectedSettings() throws {
        let f = try fixture(enabled: nil); XCTAssertFalse(f.subject.allowManualBiometryAuth); XCTAssertNil(f.subject.getInputBlockDate())
        f.settings.biometryEnabled = true; f.settings.inputBlockTimeInterval = 1234
        XCTAssertTrue(f.subject.allowManualBiometryAuth); XCTAssertEqual(f.subject.getInputBlockDate(), Date(timeIntervalSince1970: 1234))
    }
    func testPinLengthIsReadFromTheIsolatedSecretStore() async throws {
        for pin in ["1234", "123456"] { let f = try fixture(pin: pin); f.subject.getPinCodeCount(); await waitUntil { !f.output.lengths.isEmpty }; XCTAssertEqual(f.output.lengths, [pin.count]) }
    }
    func testPinLengthFailureDoesNotInventAnEntryLength() async throws {
        let f = try fixture(accounts: { throw AuthBoundaryFailure.unavailable }); f.subject.getPinCodeCount()
        await waitUntil { f.output.failures == 1 }; XCTAssertTrue(f.output.lengths.isEmpty)
    }
    func testFourDigitPinRequiresManualEntryEvenWhenBiometryIsEnabled() async throws {
        let f = try fixture(pin: "1234"); f.subject.startAuth(completion: nil)
        await waitUntil { f.subject.state == .waitingPincode }; XCTAssertEqual(f.biometry.requests, 0)
    }
    func testDisabledBiometryReturnsToPinEntryWithoutAuthenticating() async throws {
        for enabled in [nil, false] { let f = try fixture(enabled: enabled); f.subject.startAuth(completion: nil)
            await waitUntil { f.subject.state == .waitingPincode }; XCTAssertEqual(f.biometry.requests, 0); XCTAssertEqual(f.output.completions, 0)
        }
    }
    func testUnavailableBiometryCallsTheFallbackCompletionOnce() async throws {
        let f = try fixture(type: .none); var completions = 0; f.subject.startAuth { completions += 1 }
        await waitUntil { completions == 1 }; XCTAssertEqual(f.subject.state, .waitingPincode); XCTAssertEqual(f.biometry.requests, 0)
    }
    func testBiometrySuccessCompletesAuthAndResetsTheFailureCounter() async throws {
        let f = try fixture(failCount: 2); f.subject.startAuth(completion: nil)
        await waitUntil { f.biometry.requests == 1 }; XCTAssertEqual(f.subject.state, .checkingBiometry)
        f.biometry.complete(true); await waitUntil { f.output.completions == 1 }
        XCTAssertEqual(f.subject.state, .completed); XCTAssertEqual(f.settings.failInputPinCount, 0)
        XCTAssertFalse(f.biometry.reasons[0].isEmpty)
    }
    func testBiometryCancellationReturnsToPinWithoutCountingAWrongPin() async throws {
        let f = try fixture(failCount: 1); f.subject.startAuth(completion: nil); await waitUntil { f.biometry.requests == 1 }
        f.biometry.complete(false); await waitUntil { f.subject.state == .waitingPincode }
        XCTAssertEqual(f.output.wrong, 0); XCTAssertEqual(f.output.completions, 0); XCTAssertEqual(f.settings.failInputPinCount, 1)
    }
    func testRepeatedStartWhileBiometryIsPendingDoesNotIssueAnotherPrompt() async throws {
        let f = try fixture(); f.subject.startAuth(completion: nil); await waitUntil { f.biometry.requests == 1 }
        f.subject.startAuth(completion: nil); XCTAssertEqual(f.biometry.requests, 1)
        f.biometry.complete(false); await waitUntil { f.subject.state == .waitingPincode }
    }
    func testBiometricSuccessCannotGrantPermissionToChangeThePin() async throws {
        let f = try fixture(); f.subject.startAuth(completion: nil); await waitUntil { f.biometry.requests == 1 }
        f.biometry.complete(true); await waitUntil { f.output.completions == 1 }
        f.subject.updatePin(pin: "654321", completion: { XCTFail("Biometry cannot authorize PIN rotation") })
        XCTAssertEqual(f.output.failures, 1); XCTAssertEqual(try f.store.keychain.fetchKey(for: KeystoreTag.pincode.rawValue), Data("123456".utf8))
    }
    func testLateBiometryCallbackCannotCompleteAnAlreadyCompletedPinCheckTwice() async throws {
        let f = try fixture(); f.subject.startAuth(completion: nil); await waitUntil { f.biometry.requests == 1 }
        await authenticate(f); f.biometry.complete(true); await Task.yield()
        XCTAssertEqual(f.output.completions, 1); XCTAssertEqual(f.subject.state, .completed)
    }
    func testPreparationFailurePreventsBiometryAndMarksUnexpectedFailure() async throws {
        let f = try fixture(accounts: { throw AuthBoundaryFailure.unavailable }); f.subject.startAuth(completion: nil)
        await waitUntil { f.output.failures == 1 }; XCTAssertEqual(f.subject.state, .unexpectedFail); XCTAssertEqual(f.biometry.requests, 0)
    }
    func testSecondWrongPinShowsTheLastChanceAndThirdAddsABlockDate() async throws {
        let f = try fixture(failCount: 1); await authenticate(f, pin: "000000")
        XCTAssertEqual(f.output.lastChance, 1); XCTAssertEqual(f.settings.failInputPinCount, 2)
        await authenticate(f, pin: "000000"); XCTAssertEqual(f.output.wrong, 2); XCTAssertEqual(f.settings.failInputPinCount, 3)
        XCTAssertEqual(f.output.blocks.count, 1); XCTAssertGreaterThan(try XCTUnwrap(f.subject.getInputBlockDate()), Date())
    }
    func testDurableThrottleRejectsFurtherAttemptsWithoutCountingAnotherWrongPin() async throws {
        let f = try fixture()
        for _ in 0..<3 { await authenticate(f, pin: "000000") }
        let wrong = f.output.wrong; await authenticate(f)
        XCTAssertEqual(f.output.wrong, wrong); XCTAssertEqual(f.output.completions, 0); XCTAssertFalse(f.output.blocks.isEmpty)
    }
    func testMissingPinIsAnUnexpectedFailureAndCannotAuthorize() async throws {
        let f = try fixture(pin: nil); await authenticate(f)
        XCTAssertEqual(f.output.failures, 1); XCTAssertEqual(f.output.completions, 0); XCTAssertEqual(f.subject.state, .waitingPincode)
    }
    func testCorrectPinGrantsOneSuccessfulRotationAndConsumesTheGrant() async throws {
        let f = try fixture(); await authenticate(f); XCTAssertEqual(f.output.completions, 1)
        var saved = false; f.subject.updatePin(pin: "654321") { saved = true }; await waitUntil { saved }
        XCTAssertEqual(try f.store.keychain.fetchKey(for: KeystoreTag.pincode.rawValue), Data("654321".utf8))
        f.subject.updatePin(pin: "111111", completion: { XCTFail("Rotation requires a new PIN entry") })
        XCTAssertEqual(f.output.failures, 1)
    }
    func testInvalidReplacementPinFailsWithoutChangingTheExistingSecret() async throws {
        let f = try fixture(); await authenticate(f); f.subject.updatePin(pin: "bad", completion: { XCTFail("Invalid PIN saved") })
        await waitUntil { f.output.failures == 1 }; XCTAssertEqual(f.subject.state, .unexpectedFail); XCTAssertNil(f.subject.pincode)
        XCTAssertEqual(try f.store.keychain.fetchKey(for: KeystoreTag.pincode.rawValue), Data("123456".utf8))
    }
    // MARK: Face ID and Touch ID accept only the enrollment set the owner approved with the PIN

    func testNewlyEnrolledFaceOrFingerFallsBackToThePinWithoutPrompting() async throws {
        let f = try fixture(); f.biometry.isEnrollmentApproved = false; XCTAssertFalse(f.subject.allowManualBiometryAuth)
        var completions = 0; f.subject.startAuth { completions += 1 }
        await waitUntil { f.subject.state == .waitingPincode }
        XCTAssertEqual(f.biometry.requests, 0); XCTAssertEqual(f.output.completions, 0); XCTAssertEqual(completions, 0)
    }
    func testTypedPinApprovesOnlyAFirstEnrollmentAndOnlyWhileBiometryIsOn() async throws {
        let on = try fixture(); on.biometry.isEnrollmentApproved = false; await authenticate(on)
        XCTAssertEqual(on.output.completions, 1); XCTAssertEqual(on.biometry.firstApprovals, 1); XCTAssertEqual(on.biometry.approvals, 0)
        let off = try fixture(enabled: false); await authenticate(off)
        XCTAssertEqual(off.output.completions, 1); XCTAssertEqual(off.biometry.firstApprovals, 0); XCTAssertEqual(off.biometry.approvals, 0)
        let wrong = try fixture(); await authenticate(wrong, pin: "000000"); XCTAssertEqual(wrong.biometry.firstApprovals, 0)
    }
    private func typePinOnChangedEnrollment() async throws -> Fixture {
        let f = try fixture(); f.biometry.isEnrollmentApproved = false; f.biometry.hasEnrollmentChanged = true
        f.subject.process(pin: "123456"); await waitUntil(timeout: 30) { f.output.decisions.count == 1 }
        return f
    }
    func testTypedPinOnAChangedEnrollmentWaitsForTheOwnerAndApprovesNothing() async throws {
        let f = try await typePinOnChangedEnrollment()
        XCTAssertEqual(f.output.completions, 0); XCTAssertEqual(f.subject.state, .checkingPincode)
        XCTAssertEqual(f.biometry.approvals, 0); XCTAssertEqual(f.biometry.firstApprovals, 0)
        XCTAssertEqual(f.settings.biometryEnabled, true)
    }
    func testKeepingAChangedEnrollmentApprovesItAndCompletes() async throws {
        let f = try await typePinOnChangedEnrollment()
        f.output.decisions[0](true)
        XCTAssertEqual(f.biometry.approvals, 1); XCTAssertEqual(f.output.completions, 1); XCTAssertEqual(f.subject.state, .completed)
        XCTAssertEqual(f.settings.biometryEnabled, true)
    }
    func testRefusingAChangedEnrollmentTurnsBiometryOffAndCompletesWithoutApproving() async throws {
        let f = try await typePinOnChangedEnrollment()
        f.output.decisions[0](false)
        XCTAssertEqual(f.biometry.approvals, 0); XCTAssertEqual(f.output.completions, 1); XCTAssertEqual(f.subject.state, .completed)
        XCTAssertEqual(f.settings.biometryEnabled, false)
    }
    func testASecondAnswerToTheEnrollmentQuestionChangesNothing() async throws {
        let f = try await typePinOnChangedEnrollment()
        f.output.decisions[0](true); f.output.decisions[0](false)
        XCTAssertEqual(f.settings.biometryEnabled, true); XCTAssertEqual(f.biometry.approvals, 1); XCTAssertEqual(f.output.completions, 1)
    }
    func testBackgroundingDiscardsBothAnswersToThePendingEnrollmentQuestion() async throws {
        for keep in [true, false] {
            let f = try await typePinOnChangedEnrollment()
            NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
            f.output.decisions[0](keep)
            XCTAssertEqual(f.subject.state, .waitingPincode)
            XCTAssertEqual(f.output.completions, 0); XCTAssertEqual(f.biometry.approvals, 0)
            XCTAssertEqual(f.settings.biometryEnabled, true)
            f.subject.updatePin(pin: "654321", completion: { XCTFail("The backgrounded PIN grant must be discarded") })
            XCTAssertEqual(f.output.failures, 1)
        }
    }
    func testAnOldEnrollmentAnswerCannotCompleteAFreshPinAttempt() async throws {
        let f = try await typePinOnChangedEnrollment()
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        f.subject.process(pin: "123456")
        await waitUntil(timeout: 30) { f.output.decisions.count == 2 }
        f.output.decisions[0](true)
        XCTAssertEqual(f.output.completions, 0); XCTAssertEqual(f.biometry.approvals, 0)
        guard f.output.decisions.count == 2 else { return }
        f.output.decisions[1](false)
        XCTAssertEqual(f.output.completions, 1); XCTAssertEqual(f.settings.biometryEnabled, false)
    }
    func testBecomingInactiveDiscardsBothAnswersToTheEnrollmentQuestion() async throws {
        for keep in [true, false] {
            let f = try await typePinOnChangedEnrollment()
            NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
            f.output.decisions[0](keep)
            XCTAssertEqual(f.subject.state, .waitingPincode)
            XCTAssertEqual(f.output.completions, 0); XCTAssertEqual(f.biometry.approvals, 0)
            XCTAssertEqual(f.settings.biometryEnabled, true)
        }
    }
    func testSystemBiometryCanFinishAfterBecomingInactive() async throws {
        let f = try fixture(); f.subject.startAuth(completion: nil)
        await waitUntil { f.biometry.requests == 1 }
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        XCTAssertEqual(f.subject.state, .checkingBiometry)
        f.biometry.complete(true); await waitUntil { f.output.completions == 1 }
        XCTAssertEqual(f.subject.state, .completed); XCTAssertEqual(f.biometry.approvals, 0)
    }
    func testBothPinScreensAcceptFreshEntryAfterBackgroundingTheEnrollmentQuestion() async throws {
        let input = InputPincodePresenter(), authorization = AuthorizationPresenter()
        for presenter in [input as any PinSetupPresenterProtocol, authorization as any PinSetupPresenterProtocol] {
            let f = try fixture(), view = PinPresenterView()
            f.biometry.hasEnrollmentChanged = true; f.biometry.isEnrollmentApproved = false
            if let input = presenter as? InputPincodePresenter {
                input.view = view; input.wireframe = PinPresenterRoute(); input.interactor = f.subject; f.subject.presenter = input
            } else {
                authorization.view = view; authorization.wireframe = PinAssemblyRoute(); authorization.interactor = f.subject; f.subject.presenter = authorization
            }
            f.subject.presenter?.setupPinCodeSymbols(with: 6)
            "123456".forEach { presenter.padButtonTapped(with: String($0)) }
            await waitUntil(timeout: 30) { view.asked != nil }
            NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
            XCTAssertEqual(view.circles.last, 0)
            presenter.padButtonTapped(with: "1")
            XCTAssertEqual(view.circles.last, 1)
            XCTAssertEqual(f.subject.state, .waitingPincode)
        }
    }
    func testAChangedEnrollmentAsksNothingWhileBiometryIsOff() async throws {
        let f = try fixture(enabled: false); f.biometry.hasEnrollmentChanged = true; await authenticate(f, timeout: 30)
        XCTAssertTrue(f.output.decisions.isEmpty); XCTAssertEqual(f.output.completions, 1); XCTAssertEqual(f.biometry.approvals, 0)
    }
    func testAWrongPinOnAChangedEnrollmentAsksNothing() async throws {
        let f = try fixture(); f.biometry.hasEnrollmentChanged = true; await authenticate(f, pin: "000000", timeout: 30)
        XCTAssertTrue(f.output.decisions.isEmpty); XCTAssertEqual(f.output.wrong, 1); XCTAssertEqual(f.biometry.approvals, 0)
    }
    private func answer(_ action: UIAlertAction) throws {
        let block = try XCTUnwrap(action.value(forKey: "handler"))
        unsafeBitCast(block as AnyObject, to: (@convention(block) (UIAlertAction) -> Void).self)(action)
    }
    func testTheChangedBiometryQuestionNamesTheTypeAndItsButtonsAnswerAsTheySay() throws {
        for (type, name) in [(AvailableBiometryType.faceId, "Face ID"), (AvailableBiometryType.touchId, "Touch ID")] {
            let view = PinPresenterView(); var answers: [Bool] = []
            view.askToKeepChangedBiometry(type: type) { answers.append($0) }
            let alert = try XCTUnwrap(view.asked as? UIAlertController)
            XCTAssertEqual(alert.title, WalletUX.format("%@ changed on this iPhone", name))
            XCTAssertEqual(alert.message?.components(separatedBy: name).count, 3, "The message names \(name) twice")
            XCTAssertEqual(alert.actions.map(\.title), [WalletUX.format("Keep %@", name), WalletUX.format("Turn %@ off", name)])
            XCTAssertEqual(alert.actions.map(\.style), [.default, .destructive]); XCTAssertEqual(answers, [])
            try answer(alert.actions[0]); XCTAssertEqual(answers, [true])
            try answer(alert.actions[1]); XCTAssertEqual(answers, [true, false])
        }
    }
    func testBothPinScreensPutTheQuestionOnTheirOwnView() async throws {
        let input = InputPincodePresenter(), inputView = PinPresenterView(); input.view = inputView
        let authorization = AuthorizationPresenter(), authorizationView = PinPresenterView(); authorization.view = authorizationView
        var answers: [Bool] = []
        input.didRequireEnrollmentDecision(type: .faceId) { answers.append($0) }
        authorization.didRequireEnrollmentDecision(type: .touchId) { answers.append($0) }
        await waitUntil { inputView.asked != nil && authorizationView.asked != nil }
        let faceID = try XCTUnwrap(inputView.asked as? UIAlertController), touchID = try XCTUnwrap(authorizationView.asked as? UIAlertController)
        XCTAssertEqual(faceID.title, WalletUX.format("%@ changed on this iPhone", "Face ID"))
        XCTAssertEqual(touchID.title, WalletUX.format("%@ changed on this iPhone", "Touch ID"))
        try answer(faceID.actions[0]); try answer(touchID.actions[1]); XCTAssertEqual(answers, [true, false])
    }
    func testReplacingThePinApprovesNoFacesOrFingers() async throws {
        let f = try fixture()
        let authorization = try WalletOwnerPIN(keystore: f.store.keychain, settings: f.settings, recoveryGate: gate(f.settings))
            .authenticateCurrent("123456", currentAccounts: { [] })
        let output = PinReplacementOutput()
        let setup = PinSetupInteractor(secretManager: f.store, settingsManager: f.settings, biometryAuth: f.biometry,
            config: ApplicationConfig.shared, ownerPINKeystore: f.store.keychain, recoveryGate: gate(f.settings),
            authorization: authorization, accounts: { [] })
        setup.presenter = output
        setup.change(pin: "654321")
        await waitUntil(timeout: 10) { output.saves == 1 }
        XCTAssertEqual(f.biometry.approvals, 0); XCTAssertEqual(f.biometry.firstApprovals, 0)
    }
    func testBiometricUnlockNeverApprovesAnEnrollment() async throws {
        let f = try fixture(); f.subject.startAuth(completion: nil); await waitUntil { f.biometry.requests == 1 }
        f.biometry.complete(true); await waitUntil { f.output.completions == 1 }; XCTAssertEqual(f.biometry.approvals, 0)
        XCTAssertEqual(f.biometry.firstApprovals, 0)
    }
    func testPinOnlyAuthorizationNeverOffersBiometry() async throws {
        let f = try fixture(allowsBiometry: false); XCTAssertFalse(f.subject.allowManualBiometryAuth)
        var completions = 0; f.subject.startAuth { completions += 1 }
        await waitUntil { f.subject.state == .waitingPincode }
        XCTAssertEqual(f.biometry.requests, 0); XCTAssertEqual(completions, 0)
        f.subject.startAuth(completion: nil); await waitUntil { f.subject.state == .waitingPincode }
        XCTAssertEqual(f.biometry.requests, 0, "The accessory button cannot start biometry either")
        await authenticate(f); XCTAssertEqual(f.output.completions, 1); XCTAssertEqual(f.subject.state, .completed)
    }
    func testCompletedAuthIgnoresAdditionalPinSubmissions() async throws {
        let f = try fixture(); await authenticate(f); f.subject.process(pin: "000000")
        XCTAssertEqual(f.subject.state, .completed); XCTAssertEqual(f.output.completions, 1); XCTAssertEqual(f.output.wrong, 0)
    }

    // MARK: Owner bindings from builds that never wrote them (3.8.6, internal 3.9.1/3.9.2)

    func testMissingOwnerBindingAsksForTheTypedPinInsteadOfBiometry() async throws {
        let store = InMemoryKeychainManager(), settings = InMemorySettingsManager()
        let account = try wallet(in: store, settings: settings, bound: false)
        let f = try fixture(accounts: { [account] }, store: store, settings: settings)
        let before = try store.keychain.allKeyIdentifiers()
        f.subject.startAuth(completion: nil); await waitUntil { f.output.ownerPinRequests == 1 }
        XCTAssertEqual(f.subject.state, .waitingPincode); XCTAssertEqual(f.biometry.requests, 0)
        XCTAssertEqual(f.output.completions, 0); XCTAssertEqual(f.output.failures, 0)
        XCTAssertEqual(try store.keychain.allKeyIdentifiers(), before, "Deciding writes nothing")
        f.subject.startAuth(completion: nil); await waitUntil { f.output.ownerPinRequests == 2 }
        XCTAssertEqual(f.biometry.requests, 0, "A manual biometric request is not accepted either")
    }
    func testTypedPinCreatesTheOwnerBindingAndTheNextUnlockUsesBiometryAgain() async throws {
        let store = InMemoryKeychainManager(), settings = InMemorySettingsManager()
        let account = try wallet(in: store, settings: settings, bound: false)
        let f = try fixture(accounts: { [account] }, store: store, settings: settings)
        f.subject.startAuth(completion: nil); await waitUntil { f.output.ownerPinRequests == 1 }
        await authenticate(f, timeout: 60); XCTAssertEqual(f.output.completions, 1)
        let owner = WalletOwnerPIN(keystore: store.keychain, settings: settings, recoveryGate: gate(settings))
        XCTAssertTrue(try owner.hasBindings(accounts: [account]))
        XCTAssertEqual(try owner.verifyRetained("123456", addresses: [account.address]), [account.address],
                       "Welcome back can restore this wallet with its PIN after a reinstall")
        let next = try fixture(accounts: { [account] }, store: store, settings: settings)
        next.subject.startAuth(completion: nil); await waitUntil { next.biometry.requests == 1 }
        next.biometry.complete(true); await waitUntil { next.output.completions == 1 }
        XCTAssertEqual(next.subject.state, .completed); XCTAssertEqual(next.output.ownerPinRequests, 0)
    }
    func testWalletsWithOwnerBindingsKeepTheBiometricUnlock() async throws {
        let store = InMemoryKeychainManager(), settings = InMemorySettingsManager()
        let account = try wallet(in: store, settings: settings, bound: true)
        let f = try fixture(failCount: 2, accounts: { [account] }, store: store, settings: settings)
        f.subject.startAuth(completion: nil); await waitUntil { f.biometry.requests == 1 }
        XCTAssertEqual(f.subject.state, .checkingBiometry)
        f.biometry.complete(true); await waitUntil { f.output.completions == 1 }
        XCTAssertEqual(f.subject.state, .completed); XCTAssertEqual(f.settings.failInputPinCount, 0)
        XCTAssertEqual(f.output.ownerPinRequests, 0)
    }
    func testUnreadableOwnerBindingAsksForTheTypedPin() async throws {
        let store = InMemoryKeychainManager(), settings = InMemorySettingsManager()
        let account = try wallet(in: store, settings: settings, bound: true)
        let keys = AuthBoundaryReadFaultKeychain(base: store.keychain, failing: account.address + WalletOwnerPIN.bindingSuffix)
        let f = try fixture(accounts: { [account] }, store: store, settings: settings, ownerKeys: keys)
        f.subject.startAuth(completion: nil); await waitUntil { f.output.ownerPinRequests == 1 }
        XCTAssertEqual(f.subject.state, .waitingPincode); XCTAssertEqual(f.biometry.requests, 0)
        XCTAssertEqual(f.output.failures, 0)
        keys.failing = nil; await authenticate(f, timeout: 60)
        XCTAssertEqual(f.output.completions, 1); XCTAssertEqual(f.output.wrong, 0)
    }
    func testUnprovenWatchOnlyWalletDoesNotHoldBackBiometry() async throws {
        let store = InMemoryKeychainManager(), settings = InMemorySettingsManager()
        // No signing key on this iPhone: a typed PIN would not bind it either.
        let account = try wallet(in: InMemoryKeychainManager(), settings: settings, bound: false)
        settings.set(value: true, for: "wallet.watchOnly.\(account.address)")
        let f = try fixture(accounts: { [account] }, store: store, settings: settings)
        f.subject.startAuth(completion: nil); await waitUntil { f.biometry.requests == 1 }
        f.biometry.complete(true); await waitUntil { f.output.completions == 1 }
        XCTAssertEqual(f.output.ownerPinRequests, 0)
    }
    func testDisabledBiometryNeedsNoOwnerPinExplanation() async throws {
        let store = InMemoryKeychainManager(), settings = InMemorySettingsManager()
        let account = try wallet(in: store, settings: settings, bound: false)
        let f = try fixture(enabled: false, accounts: { [account] }, store: store, settings: settings)
        f.subject.startAuth(completion: nil); await waitUntil { f.subject.state == .waitingPincode }
        XCTAssertEqual(f.biometry.requests, 0); XCTAssertEqual(f.output.ownerPinRequests, 0)
    }
    func testMalformedOwnerBindingKeepsTheBiometricUnlock() async throws {
        let store = InMemoryKeychainManager(), settings = InMemorySettingsManager()
        let account = try wallet(in: store, settings: settings, bound: false)
        // authenticateCurrent rejects this record, so a typed PIN could not
        // replace it: asking for one would only lock the user out.
        try store.keychain.saveKey(Data("not a binding".utf8), with: account.address + WalletOwnerPIN.bindingSuffix)
        let f = try fixture(accounts: { [account] }, store: store, settings: settings)
        f.subject.startAuth(completion: nil); await waitUntil { f.biometry.requests == 1 }
        f.biometry.complete(true); await waitUntil { f.output.completions == 1 }
        XCTAssertEqual(f.output.ownerPinRequests, 0)
    }
    func testOwnerBindingQueryIsReadOnlyAndCountsAnyBindingRecord() throws {
        let store = InMemoryKeychainManager(), settings = InMemorySettingsManager()
        let account = try wallet(in: store, settings: settings, bound: false)
        let owner = WalletOwnerPIN(keystore: store.keychain, settings: settings, recoveryGate: gate(settings))
        let tag = account.address + WalletOwnerPIN.bindingSuffix
        let snapshot: () throws -> [String: Data] = {
            try Dictionary(uniqueKeysWithValues: store.keychain.allKeyIdentifiers().map { ($0, try store.keychain.fetchKey(for: $0)) })
        }
        let before = try snapshot()
        XCTAssertFalse(try owner.hasBindings(accounts: [account])); XCTAssertTrue(try owner.hasBindings(accounts: []))
        XCTAssertEqual(try snapshot(), before)
        let valid = try JSONEncoder().encode(WalletOwnerPIN.Binding(pin: "654321"))
        for record in [Data(#"{"version":2,"salt":"","verifier":""}"#.utf8), Data("not a binding".utf8), valid] {
            try store.keychain.saveKey(record, with: tag)
            XCTAssertTrue(try owner.hasBindings(accounts: [account]))
        }
        let unreadable = WalletOwnerPIN(keystore: AuthBoundaryReadFaultKeychain(base: store.keychain, failing: tag),
                                        settings: settings, recoveryGate: gate(settings))
        XCTAssertThrowsError(try unreadable.hasBindings(accounts: [account]))
    }
    func testNormalUnlockScreenExplainsTheOneTypedPinAndHidesBiometry() async throws {
        let store = InMemoryKeychainManager(), settings = InMemorySettingsManager()
        let account = try wallet(in: store, settings: settings, bound: false)
        let f = try fixture(accounts: { [account] }, store: store, settings: settings)
        let presenter = InputPincodePresenter(), view = PinPresenterView(), route = PinPresenterRoute()
        presenter.view = view; presenter.wireframe = route; presenter.interactor = f.subject; f.subject.presenter = presenter
        let explanation = LocalAuthInteractor.ownerPinEntryTitle
        presenter.start(); await waitUntil { view.titles.last == explanation && view.accessory.last == false }
        XCTAssertEqual(f.biometry.requests, 0)
        "000000".forEach { presenter.padButtonTapped(with: String($0)) }
        await waitUntil { view.errors == 1 }; view.errorCompletion?(true)
        XCTAssertEqual(view.titles.last, explanation, "The explanation stays after a wrong PIN")
        "123456".forEach { presenter.padButtonTapped(with: String($0)) }
        await waitUntil(timeout: 60) { route.routes == ["main"] }
        XCTAssertTrue(try store.keychain.checkKey(for: account.address + WalletOwnerPIN.bindingSuffix))
    }
    func testLockAndAuthorizationScreenExplainsTheOneTypedPinToo() async throws {
        let store = InMemoryKeychainManager(), settings = InMemorySettingsManager()
        let account = try wallet(in: store, settings: settings, bound: false)
        let f = try fixture(accounts: { [account] }, store: store, settings: settings)
        let presenter = AuthorizationPresenter(), view = PinPresenterView(), route = PinAssemblyRoute()
        presenter.view = view; presenter.wireframe = route; presenter.interactor = f.subject; f.subject.presenter = presenter
        let explanation = LocalAuthInteractor.ownerPinEntryTitle
        presenter.start(); await waitUntil { view.titles.last == explanation && view.accessory.last == false }
        XCTAssertEqual(f.biometry.requests, 0)
        "00".forEach { presenter.padButtonTapped(with: String($0)) }
        XCTAssertEqual(view.titles.last, explanation, "Typing keeps the explanation")
        "0000".forEach { presenter.padButtonTapped(with: String($0)) }
        await waitUntil { view.errors == 1 }; view.errorCompletion?(true)
        XCTAssertEqual(view.titles.last, explanation, "The explanation stays after a wrong PIN")
        "123456".forEach { presenter.padButtonTapped(with: String($0)) }
        await waitUntil(timeout: 60) { route.results == [true] }
        XCTAssertTrue(try store.keychain.checkKey(for: account.address + WalletOwnerPIN.bindingSuffix))
    }
}
private enum AuthBoundaryFailure: Error { case unavailable }
private final class AuthBoundaryBiometry: BiometryAuthProtocol {
    var availableBiometryType: AvailableBiometryType = .touchId
    var isEnrollmentApproved = true, hasEnrollmentChanged = false, approvals = 0, firstApprovals = 0
    func approveCurrentEnrollment() { approvals += 1 }
    func approveFirstEnrollment() { firstApprovals += 1 }
    var requests = 0, reasons: [String] = []; private var callback: (() -> Void)?; private var delivery: ((Bool) -> Void)?
    func authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void) {
        requests += 1; reasons.append(localizedReason); delivery = { value in completionQueue.async { completionBlock(value) } }
    }
    func complete(_ result: Bool) { delivery?(result) }
}
private final class AuthBoundaryOutput: LocalAuthInteractorOutputProtocol {
    var wrong = 0, lastChance = 0, completions = 0, failures = 0, ownerPinRequests = 0
    var lengths: [Int] = [], blocks: [Date] = [], states: [LocalAuthInteractor.LocalAuthState] = []
    func didEnterWrongPincode() { wrong += 1 }; func blockUserInputUntil(date: Date) { blocks.append(date) }
    func reachedLastChancePinInput() { lastChance += 1 }; func didChangeState(from state: LocalAuthInteractor.LocalAuthState) { states.append(state) }
    func didCompleteAuth() { completions += 1 }; func didUnexpectedFail() { failures += 1 }; func setupPinCodeSymbols(with count: Int) { lengths.append(count) }
    func didRequireOwnerPinEntry() { ownerPinRequests += 1 }
    var decisions: [(Bool) -> Void] = []
    func didRequireEnrollmentDecision(type: AvailableBiometryType, completion: @escaping (Bool) -> Void) { decisions.append(completion) }
}
private final class PinReplacementOutput: PinSetupInteractorOutputProtocol {
    var saves = 0
    func didSavePin() { saves += 1 }
    func didStartWaitingBiometryDecision(type: AvailableBiometryType, completionBlock: @escaping (Bool) -> Void) {}
    func didChangeState(from: PinSetupInteractor.PinSetupState) {}
}
/// Fails every read of one tag the way an unavailable Keychain does.
private final class AuthBoundaryReadFaultKeychain: KeystoreProtocol {
    let base: InMemoryKeychain; var failing: String?
    init(base: InMemoryKeychain, failing: String) { self.base = base; self.failing = failing }
    private func admit(_ identifier: String) throws {
        if identifier == failing { throw KeystoreSystemError(status: errSecInteractionNotAllowed) }
    }
    func addKey(_ key: Data, with identifier: String) throws { try base.addKey(key, with: identifier) }
    func updateKey(_ key: Data, with identifier: String) throws { try base.updateKey(key, with: identifier) }
    func fetchKey(for identifier: String) throws -> Data { try admit(identifier); return try base.fetchKey(for: identifier) }
    func checkKey(for identifier: String) throws -> Bool { try admit(identifier); return try base.checkKey(for: identifier) }
    func allKeyIdentifiers() throws -> [String] { try base.allKeyIdentifiers() }
    func deleteKey(for identifier: String) throws { try base.deleteKey(for: identifier) }
}

/// BiometryAuth itself: Face ID or Touch ID unlock works only while the device
/// reports the enrollment set the owner approved with the PIN.
final class BiometryEnrollmentApprovalTests: XCTestCase {
    private final class Evaluator: BiometryPolicyEvaluating {
        var enrollment: BiometryEnrollment? = BiometryEnrollment(type: .faceId, state: Data([1]))
        var prompts = 0, result = true; var matched: Data? = Data([1])
        func currentEnrollment() -> BiometryEnrollment? { enrollment }
        func evaluate(localizedReason: String, completion: @escaping (Bool, Data?) -> Void) {
            prompts += 1; completion(result, result ? matched : nil)
        }
    }
    private final class Approvals: BiometryEnrollmentApprovalStoring {
        var stored: Data?, saves = 0
        func load() -> Data? { stored }; func save(_ state: Data) { stored = state; saves += 1 }
    }
    private func unlock(_ auth: BiometryAuth) -> Bool? {
        let done = expectation(description: "biometry"); var value: Bool?
        auth.authenticate(localizedReason: "Unlock SORA", completionQueue: .main) { value = $0; done.fulfill() }
        wait(for: [done], timeout: 2); return value
    }
    func testNothingApprovedYetMeansNoPromptAndNoUnlock() {
        let evaluator = Evaluator(), auth = BiometryAuth(evaluator: evaluator, approvals: Approvals())
        XCTAssertEqual(auth.availableBiometryType, .faceId); XCTAssertFalse(auth.isEnrollmentApproved)
        XCTAssertEqual(unlock(auth), false); XCTAssertEqual(evaluator.prompts, 0)
    }
    func testTheApprovedEnrollmentUnlocks() {
        let evaluator = Evaluator(), approvals = Approvals(), auth = BiometryAuth(evaluator: evaluator, approvals: approvals)
        auth.approveCurrentEnrollment(); XCTAssertEqual(approvals.stored, Data([1])); XCTAssertTrue(auth.isEnrollmentApproved)
        XCTAssertEqual(unlock(auth), true); XCTAssertEqual(evaluator.prompts, 1)
        evaluator.result = false; XCTAssertEqual(unlock(auth), false, "A failed or cancelled prompt never unlocks")
    }
    func testAnAddedFaceOrFingerStopsBiometricUnlockUntilThePinApprovesIt() {
        let evaluator = Evaluator(), approvals = Approvals(), auth = BiometryAuth(evaluator: evaluator, approvals: approvals)
        auth.approveCurrentEnrollment()
        evaluator.enrollment = BiometryEnrollment(type: .faceId, state: Data([2])); evaluator.matched = Data([2])
        XCTAssertFalse(auth.isEnrollmentApproved); XCTAssertEqual(unlock(auth), false)
        XCTAssertEqual(evaluator.prompts, 0, "The changed set is refused before any prompt")
        auth.approveCurrentEnrollment(); XCTAssertEqual(unlock(auth), true)
    }
    func testAnEnrollmentChangeDuringThePromptIsRefused() {
        let evaluator = Evaluator(), approvals = Approvals(), auth = BiometryAuth(evaluator: evaluator, approvals: approvals)
        auth.approveCurrentEnrollment(); evaluator.matched = Data([3])
        XCTAssertEqual(unlock(auth), false); XCTAssertEqual(evaluator.prompts, 1)
        evaluator.matched = nil; XCTAssertEqual(unlock(auth), false, "A success without an enrollment state is refused")
    }
    /// Approval happens before the app's first Face ID prompt (right after
    /// the PIN is set), so iOS must report the enrollment set without one.
    /// Runs where the simulator or device has biometrics enrolled.
    func testTheSystemReportsTheEnrollmentSetWithoutAPrompt() throws {
        guard let enrollment = LocalAuthenticationPolicyEvaluator().currentEnrollment() else {
            throw XCTSkip("No biometrics are enrolled here")
        }
        XCTAssertNotEqual(enrollment.type, .none)
        XCTAssertNotNil(enrollment.state)
        XCTAssertEqual(LocalAuthenticationPolicyEvaluator().currentEnrollment(), enrollment, "Stable while nothing changes")
    }
    func testApprovalNeedsUsableBiometricsWithAnEnrollmentState() {
        let evaluator = Evaluator(), approvals = Approvals(), auth = BiometryAuth(evaluator: evaluator, approvals: approvals)
        evaluator.enrollment = nil; auth.approveCurrentEnrollment()
        XCTAssertEqual(auth.availableBiometryType, .none); XCTAssertEqual(approvals.saves, 0); XCTAssertEqual(unlock(auth), false)
        evaluator.enrollment = BiometryEnrollment(type: .touchId, state: nil); auth.approveCurrentEnrollment()
        XCTAssertEqual(approvals.saves, 0); XCTAssertFalse(auth.isEnrollmentApproved)
    }
    func testAChangeIsReportedOnlyAgainstAnApprovedSet() {
        let evaluator = Evaluator(), approvals = Approvals(), auth = BiometryAuth(evaluator: evaluator, approvals: approvals)
        XCTAssertFalse(auth.hasEnrollmentChanged, "Nothing approved yet")
        auth.approveCurrentEnrollment(); XCTAssertFalse(auth.hasEnrollmentChanged)
        evaluator.enrollment = BiometryEnrollment(type: .faceId, state: Data([2])); XCTAssertTrue(auth.hasEnrollmentChanged)
        evaluator.enrollment = nil; XCTAssertFalse(auth.hasEnrollmentChanged, "None enrolled now: nothing to decide")
        evaluator.enrollment = BiometryEnrollment(type: .faceId, state: Data([3]))
        XCTAssertTrue(auth.hasEnrollmentChanged, "Emptying the set and enrolling again is still a change")
        evaluator.enrollment = BiometryEnrollment(type: .faceId, state: nil); XCTAssertFalse(auth.hasEnrollmentChanged)
    }
    func testTheFirstApprovalHappensOnceAndNeverCoversAChangedSet() {
        let evaluator = Evaluator(), approvals = Approvals(), auth = BiometryAuth(evaluator: evaluator, approvals: approvals)
        auth.approveFirstEnrollment(); XCTAssertEqual(approvals.stored, Data([1])); XCTAssertEqual(approvals.saves, 1)
        evaluator.enrollment = BiometryEnrollment(type: .faceId, state: Data([2])); evaluator.matched = Data([2])
        auth.approveFirstEnrollment()
        XCTAssertEqual(approvals.stored, Data([1]), "A later typed PIN does not approve a changed set")
        XCTAssertFalse(auth.isEnrollmentApproved); XCTAssertEqual(unlock(auth), false)
        auth.approveCurrentEnrollment(); XCTAssertEqual(unlock(auth), true, "The owner's yes does")
    }
}
