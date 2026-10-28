import SoraFoundation
import UIKit
import XCTest
@testable import SoraPassport

@MainActor
final class RecoveryDisclosureFlowTests: XCTestCase {
    private var window: UIWindow!
    private var previousWindow: UIWindow?
    private var previousLanguage = "en"
    private var animations = true
    private var pasteboard = [[String: Any]]()
    override func setUp() {
        super.setUp()
        previousLanguage = LocalizationManager.shared.selectedLocalization
        LocalizationManager.shared.selectedLocalization = "en"
        animations = UIView.areAnimationsEnabled; UIView.setAnimationsEnabled(false)
        pasteboard = UIPasteboard.general.items
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        previousWindow = scene?.windows.first { $0.isKeyWindow }
        window = scene.map(UIWindow.init(windowScene:)) ?? UIWindow(frame: UIScreen.main.bounds)
        window.frame = scene?.coordinateSpace.bounds ?? UIScreen.main.bounds
    }
    override func tearDown() async throws {
        window.rootViewController?.dismiss(animated: false)
        await settle()
        window.isHidden = true; window.rootViewController = nil; window = nil
        previousWindow?.makeKeyAndVisible()
        UIPasteboard.general.items = pasteboard
        LocalizationManager.shared.selectedLocalization = previousLanguage
        UIView.setAnimationsEnabled(animations)
        try await super.tearDown()
    }
    private func all<T: UIView>(_ type: T.Type, in view: UIView) -> [T] {
        ((view as? T).map { [$0] } ?? []) + view.subviews.flatMap { all(type, in: $0) }
    }
    private func button(_ id: String, in controller: UIViewController) throws -> UIButton {
        try XCTUnwrap(all(UIButton.self, in: controller.view).first { $0.accessibilityIdentifier == id })
    }
    private func label(in controller: UIViewController) throws -> UILabel {
        try XCTUnwrap(all(UILabel.self, in: controller.view).first { $0.accessibilityIdentifier == "wallet-recovery-phrase-words" })
    }
    private func open(entries: [WalletRecoveryPhraseReveal.Entry]? = nil) -> WalletRecoveryPhraseViewController {
        let entries = entries ?? [.init(address: "public-fixture-address", name: "Fixture", words: ["abandon", "ability", "able"], derivationPath: "//public-fixture")]
        let controller = WalletRecoveryPhraseViewController(entries: entries)
        window.rootViewController = controller; window.makeKeyAndVisible()
        controller.loadViewIfNeeded(); window.layoutIfNeeded()
        return controller
    }
    private func reveal(_ controller: WalletRecoveryPhraseViewController) throws {
        XCTAssertEqual(UIApplication.shared.applicationState, .active)
        try button("wallet-recovery-phrase-reveal", in: controller).sendActions(for: .touchUpInside)
    }
    private func host() -> UIViewController {
        let controller = UIViewController(); window.rootViewController = controller; window.makeKeyAndVisible(); controller.loadViewIfNeeded()
        return controller
    }
    private func settle() async { try? await Task.sleep(nanoseconds: 40_000_000) }

    func testRecoveryWordsStartHiddenAndHaveNoAccessibilityText() throws {
        let c = open(); XCTAssertTrue(try label(in: c).isHidden); XCTAssertNil(try label(in: c).text)
        XCTAssertEqual(c.view.accessibilityIdentifier, "wallet-recovery-phrase")
    }
    func testExplicitRevealNumbersEveryWordInOrder() throws {
        let c = open(); try reveal(c)
        XCTAssertFalse(try label(in: c).isHidden)
        XCTAssertEqual(try label(in: c).text, "Fixture\n1. abandon\n2. ability\n3. able")
        XCTAssertTrue(all(UILabel.self, in: c.view).contains { $0.text?.contains("//public-fixture") == true })
    }
    func testSecondRevealTapClearsWordsAndDerivationDetails() throws {
        let c = open(); try reveal(c); try reveal(c)
        XCTAssertTrue(try label(in: c).isHidden); XCTAssertNil(try label(in: c).text)
        XCTAssertFalse(all(UILabel.self, in: c.view).contains { $0.text?.contains("//public-fixture") == true })
    }
    func testResigningActiveClearsAlreadyDisplayedWords() throws {
        let c = open(); try reveal(c)
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        XCTAssertTrue(try label(in: c).isHidden); XCTAssertNil(try label(in: c).text)
    }
    func testReturningActiveDoesNotAutomaticallyRevealWords() throws {
        let c = open(); try reveal(c)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        XCTAssertTrue(try label(in: c).isHidden); XCTAssertNil(try label(in: c).text)
    }
    func testCaptureStateNotificationClearsAnExistingDisclosure() throws {
        let c = open(); try reveal(c)
        NotificationCenter.default.post(name: UIScreen.capturedDidChangeNotification, object: nil)
        XCTAssertTrue(try label(in: c).isHidden); XCTAssertNil(try label(in: c).text)
    }
    func testDisappearingClearsWordsBeforeTheViewLeaves() throws {
        let c = open(); try reveal(c); c.beginAppearanceTransition(false, animated: false); c.endAppearanceTransition()
        XCTAssertTrue(try label(in: c).isHidden); XCTAssertNil(try label(in: c).text)
    }
    func testReappearingRequiresASeparateExplicitReveal() throws {
        let c = open(); try reveal(c); c.beginAppearanceTransition(false, animated: false); c.endAppearanceTransition(); c.beginAppearanceTransition(true, animated: false); c.endAppearanceTransition()
        XCTAssertNil(try label(in: c).text)
        try reveal(c); XCTAssertFalse(try label(in: c).isHidden)
    }
    func testScreenshotHidesWordsBeforeShowingWarning() async throws {
        let c = open(); try reveal(c)
        NotificationCenter.default.post(name: UIApplication.userDidTakeScreenshotNotification, object: nil)
        await settle()
        XCTAssertTrue(try label(in: c).isHidden); XCTAssertNil(try label(in: c).text)
        let alert = try XCTUnwrap(c.presentedViewController as? UIAlertController)
        XCTAssertFalse(alert.message?.isEmpty ?? true)
        XCTAssertFalse(alert.message?.contains("abandon") ?? true)
    }
    func testCompletionErasesEntriesSoTheyCannotBeRevealedAgain() throws {
        let c = open(); try reveal(c)
        try button("wallet-recovery-phrase-done", in: c).sendActions(for: .touchUpInside)
        XCTAssertNil(try label(in: c).text)
        try reveal(c)
        XCTAssertTrue(try label(in: c).text?.isEmpty ?? true)
    }
    func testMultipleWalletsRestartWordNumberingAndKeepNames() throws {
        let c = open(entries: [.init(address: "a", name: "First", words: ["abandon", "ability"]), .init(address: "b", name: "Second", words: ["about"])])
        try reveal(c)
        XCTAssertEqual(try label(in: c).text, "First\n1. abandon\n2. ability\n\nSecond\n1. about")
    }
    func testUnnamedWalletUsesOnlyItsShortAddressLabel() throws {
        let c = open(entries: [.init(address: "1234567890abcdef", name: "", words: ["abandon"])])
        try reveal(c); XCTAssertEqual(try label(in: c).text, "12345678…\n1. abandon")
    }
    func testEmptyDerivationPathsDoNotCreateCopyControls() throws {
        let c = open(entries: [.init(address: "a", name: "Fixture", words: ["abandon"], derivationPath: "")])
        try reveal(c)
        XCTAssertFalse(all(UIButton.self, in: c.view).contains { $0.title(for: .normal) == "Copy derivation path" })
    }
    func testCopyingDerivationPathNeverCopiesRecoveryWords() throws {
        let c = open(); try reveal(c)
        let copy = try XCTUnwrap(all(UIButton.self, in: c.view).first { $0.title(for: .normal) == "Copy derivation path" })
        copy.sendActions(for: .touchUpInside)
        XCTAssertEqual(UIPasteboard.general.string, "//public-fixture")
    }
    func testRepeatedRevealDoesNotAccumulateDerivationRows() throws {
        let c = open(); try reveal(c)
        let count = all(UILabel.self, in: c.view).filter { $0.text?.contains("//public-fixture") == true }.count
        try reveal(c); try reveal(c)
        XCTAssertEqual(all(UILabel.self, in: c.view).filter { $0.text?.contains("//public-fixture") == true }.count, count)
        XCTAssertEqual(count, 1)
    }
    func testDisclosureControllerReleasesItsObservers() async throws {
        var c: WalletRecoveryPhraseViewController? = open()
        weak var weakController = c
        window.rootViewController = UIViewController(); c = nil
        await settle()
        XCTAssertNil(weakController)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    func testEmptyPhrasePresentationExplainsMissingMaterial() async throws {
        let c = host(); WalletPinPrompt.presentPhrases([], on: c); await settle()
        let alert = try XCTUnwrap(c.presentedViewController as? UIAlertController)
        XCTAssertEqual(alert.title, "Recovery phrase not shown")
        XCTAssertTrue(alert.message?.contains("No recovery phrase") == true)
        XCTAssertEqual(alert.actions.count, 1)
    }
    func testPhrasePresentationUsesAFullScreenProtectedController() async throws {
        let c = host(); WalletPinPrompt.presentPhrases([.init(address: "fixture", name: "Public fixture", words: ["abandon"])], on: c); await settle()
        let protected = try XCTUnwrap(c.presentedViewController as? WalletRecoveryPhraseViewController)
        XCTAssertEqual(protected.modalPresentationStyle, .fullScreen)
        XCTAssertTrue(try label(in: protected).isHidden)
    }
    func testOwnerPinPromptUsesSecureNumericEntryAndExplicitActions() async throws {
        let c = host(); var submitted = false
        WalletPinPrompt.present(on: c, message: "Public fixture request") { _ in submitted = true }; await settle()
        let alert = try XCTUnwrap(c.presentedViewController as? UIAlertController)
        let field = try XCTUnwrap(alert.textFields?.first)
        XCTAssertTrue(field.isSecureTextEntry); XCTAssertEqual(field.keyboardType, .numberPad)
        XCTAssertEqual(field.accessibilityIdentifier, "wallet-retained-pin")
        XCTAssertEqual(alert.message, "Public fixture request")
        XCTAssertEqual(alert.actions.map(\.title), ["Cancel", "Continue"])
        XCTAssertFalse(submitted)
    }
    func testIncorrectPinMessageIncludesRemainingAttemptBudget() {
        XCTAssertTrue(WalletPinPrompt.message(for: WalletRetainedPinGate.Failure.incorrectPin(attemptsBeforeWait: 2)).contains("2"))
    }
    func testPinLockMessageRoundsUpAndNeverShowsZeroMinutes() {
        XCTAssertTrue(WalletPinPrompt.message(for: WalletRetainedPinGate.Failure.locked(until: Date().addingTimeInterval(61))).contains("2 min"))
        XCTAssertTrue(WalletPinPrompt.message(for: WalletRetainedPinGate.Failure.locked(until: Date().addingTimeInterval(-60))).contains("1 min"))
    }
    func testMissingRetainedPinMessageOffersRecoveryWithoutGuessing() {
        let message = WalletPinPrompt.message(for: WalletRetainedPinGate.Failure.noRetainedPin)
        XCTAssertTrue(message.contains("no saved ownership PIN")); XCTAssertTrue(message.contains("recovery phrase"))
    }
    func testRetainedKeyConflictMessageDoesNotClaimAChange() {
        let message = WalletPinPrompt.message(for: AccountCreateError.retainedKeyConflict)
        XCTAssertTrue(message.contains("Nothing was changed"))
    }
    func testUnknownPinFailureDoesNotExposeTechnicalErrorDetails() {
        let message = WalletPinPrompt.message(for: NSError(domain: "private-fixture-data", code: 42))
        XCTAssertFalse(message.contains("private-fixture-data")); XCTAssertTrue(message.contains("Nothing was changed"))
    }
    func testFreshSetupConfirmationIsExplicitAboutRetainedKeys() async throws {
        let c = host(); var confirmed = false
        WalletSetUpAgainConfirmation.present(on: c, movesWalletData: false) { confirmed = true }; await settle()
        let alert = try XCTUnwrap(c.presentedViewController as? UIAlertController)
        XCTAssertTrue(alert.message?.contains("keys saved on this iPhone are not deleted") == true)
        XCTAssertEqual(alert.actions.map(\.style), [.cancel, .default]); XCTAssertFalse(confirmed)
    }
    func testRecoverySetupConfirmationExplainsThatDataMovesAside() async throws {
        let c = host(); var confirmed = false
        WalletSetUpAgainConfirmation.present(on: c, movesWalletData: true) { confirmed = true }; await settle()
        let alert = try XCTUnwrap(c.presentedViewController as? UIAlertController)
        XCTAssertTrue(alert.message?.contains("moved to a separate folder") == true); XCTAssertFalse(confirmed)
    }
}
