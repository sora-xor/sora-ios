// SPDX-License-Identifier: BSD-4-Clause
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
