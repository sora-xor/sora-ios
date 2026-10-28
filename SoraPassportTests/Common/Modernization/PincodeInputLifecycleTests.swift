import SoraFoundation
import SoraUIKit
// SPDX-License-Identifier: Apache-2.0
import UIKit
import XCTest

@testable import SoraPassport

@MainActor final class PincodeInputLifecycleTests: XCTestCase {
  private var fixtures = [PinInputFixture]()
  private func make(_ mode: PincodeMode = .create) -> PinInputFixture {
    let f = PinInputFixture(mode: mode)
    fixtures.append(f)
    return f
  }
  override func tearDown() {
    for f in fixtures {
      f.timers.forEach { $0.invalidate() }
      f.view.beginAppearanceTransition(false, animated: false)
      f.view.endAppearanceTransition()
      f.window?.isHidden = true
      f.window?.rootViewController = nil
      f.previousWindow?.makeKeyAndVisible()
    }
    fixtures = []
    super.tearDown()
  }
  private func descendants(_ v: UIView) -> [UIView] { [v] + v.subviews.flatMap { descendants($0) } }
  private func title(_ f: PinInputFixture) -> String? {
    descendants(f.view.view).compactMap { $0 as? SoramitsuLabel }.first?.sora.text
  }
  private func pin(_ f: PinInputFixture) throws -> UIView {
    try XCTUnwrap(
      descendants(f.view.view).first { $0.accessibilityIdentifier == "InputFieldAccessibilityId" })
  }
  func testInitialLoadStartsThePresenterOnce() {
    let f = make()
    f.view.loadViewIfNeeded()
    XCTAssertEqual(f.presenter.starts, 1)
  }
  func testCreateModeUsesTheSetPinPrompt() {
    let f = make()
    XCTAssertEqual(
      title(f),
      R.string.localizable.pincodeSetYourPinCode(preferredLanguages: .currentLocale).capitalized)
  }
  func testSecureInputUsesTheEnterPinPrompt() {
    let f = make(.securedInput)
    XCTAssertEqual(
      title(f),
      R.string.localizable.pincodeEnterPinCode(preferredLanguages: .currentLocale).capitalized)
  }
  func testUnsecuredInputUsesTheEnterPinPrompt() {
    let f = make(.unsecuredInput)
    XCTAssertEqual(
      title(f),
      R.string.localizable.pincodeEnterPinCode(preferredLanguages: .currentLocale).capitalized)
  }
  func testExplicitTitleReplacesTheCurrentPrompt() {
    let f = make()
    f.view.setupTitleLabel(text: "Confirm your PIN")
    XCTAssertEqual(title(f), "Confirm your PIN")
  }
  func testNumericKeyForwardsOnlyItsDigit() {
    let f = make()
    f.view.numpadView(f.view.numpadView, didSelectNumAt: 7)
    XCTAssertEqual(f.presenter.digits, ["7"])
  }
  func testBackspaceForwardsOneDeletion() {
    let f = make()
    f.view.numpadViewDidSelectBackspace(f.view.numpadView)
    XCTAssertEqual(f.presenter.deletes, 1)
  }
  func testAccessoryForwardsBiometryWithoutSigning() {
    let f = make()
    f.view.numpadViewDidSelectAccessoryControl(f.view.numpadView)
    XCTAssertEqual(f.presenter.biometry, 1)
  }
  func testClearingInputDeletesExactlyTheEnteredDigitCount() {
    let f = make()
    f.view.updateInputedCircles(with: 3)
    f.view.numpadViewDidClearInput(f.view.numpadView)
    XCTAssertEqual(f.presenter.deletes, 3)
  }
  func testOverfullInputNeverDeletesBeyondTheConfiguredPinLength() {
    let f = make()
    f.view.updateInputedCircles(with: 99)
    f.view.numpadViewDidClearInput(f.view.numpadView)
    XCTAssertEqual(f.presenter.deletes, 6)
  }
  func testNegativeEnteredCountDoesNotDeleteAnything() {
    let f = make()
    f.view.updateInputedCircles(with: -1)
    f.view.numpadViewDidClearInput(f.view.numpadView)
    XCTAssertEqual(f.presenter.deletes, 0)
  }
  func testReconfiguringPinLengthResetsAccessibilityProgress() throws {
    let f = make()
    f.view.updateInputedCircles(with: 3)
    f.view.updatePinCodeSymbolsCount(with: 4)
    XCTAssertEqual(
      try pin(f).accessibilityValue,
      R.string.localizable.neonPinCount(0, 4, preferredLanguages: .currentLocale))
  }
  func testAccessoryVisibilityTracksItsAvailability() {
    let f = make()
    f.view.didChangeAccessoryState(enabled: true)
    XCTAssertEqual(f.view.numpadView.accessoryButton.alpha, 1)
    f.view.didChangeAccessoryState(enabled: false)
    XCTAssertEqual(f.view.numpadView.accessoryButton.alpha, 0)
  }
  func testDeleteVisibilityTracksThePresenceOfInput() {
    let f = make()
    f.view.setupDeleteButton(isHidden: false)
    XCTAssertEqual(f.view.numpadView.backspaceButton.alpha, 1)
    f.view.setupDeleteButton(isHidden: true)
    XCTAssertEqual(f.view.numpadView.backspaceButton.alpha, 0)
  }
  func testFutureCooldownDisablesTheNumpadImmediately() {
    let f = make()
    f.view.blockUserInputUntil(date: Date().addingTimeInterval(60))
    XCTAssertFalse(f.view.numpadView.isUserInteractionEnabled)
    XCTAssertEqual(f.timers.count, 1)
  }
  func testAlreadyExpiredCooldownDoesNotBlockInputForAnotherSecond() {
    let f = make()
    f.view.blockUserInputUntil(date: Date().addingTimeInterval(-1))
    XCTAssertTrue(f.view.numpadView.isUserInteractionEnabled)
    XCTAssertTrue(f.timers.isEmpty)
  }
  func testReplacingCooldownInvalidatesThePreviousTimer() {
    let f = make()
    f.view.blockUserInputUntil(date: Date().addingTimeInterval(60))
    let prior = f.timers.first
    f.view.blockUserInputUntil(date: Date().addingTimeInterval(120))
    XCTAssertEqual(prior?.isValid, false)
    XCTAssertTrue(f.timers.last?.isValid == true)
  }
  func testCooldownTickDisplaysTheRemainingLockout() {
    let f = make()
    f.view.blockUserInputUntil(date: Date().addingTimeInterval(60))
    f.timers.first?.fire()
    XCTAssertNotEqual(
      title(f),
      R.string.localizable.pincodeSetYourPinCode(preferredLanguages: .currentLocale).capitalized)
    XCTAssertFalse(f.view.numpadView.isUserInteractionEnabled)
  }
  func testScreenDisappearanceInvalidatesTheCooldownTimer() {
    let f = make()
    f.view.blockUserInputUntil(date: Date().addingTimeInterval(60))
    f.view.beginAppearanceTransition(false, animated: false)
    f.view.endAppearanceTransition()
    XCTAssertEqual(f.timers.first?.isValid, false)
  }
  func testNoBiometryNeedsNoPromptOrAuthentication() {
    let f = make()
    var answers = [Bool]()
    f.view.didRequestBiometryUsage(biometryType: .none) { answers.append($0) }
    XCTAssertEqual(answers, [true])
    XCTAssertNil(f.view.presentedViewController)
  }
  func testTouchIdChoiceExplainsThePermissionBeforeAuthentication() async throws {
    let f = make()
    f.show()
    f.view.didRequestBiometryUsage(biometryType: .touchId) { _ in XCTFail("No action was chosen") }
    try? await Task.sleep(nanoseconds: 30_000_000)
    let a = try XCTUnwrap(f.view.presentedViewController as? UIAlertController)
    XCTAssertEqual(
      a.title, R.string.localizable.askTouchidTitle(preferredLanguages: .currentLocale))
    XCTAssertEqual(a.actions.map(\.style), [.default, .cancel])
    XCTAssertEqual(f.presenter.biometry, 0)
  }
  func testFaceIdChoiceUsesTheFaceIdMessage() async throws {
    let f = make()
    f.show()
    f.view.didRequestBiometryUsage(biometryType: .faceId) { _ in XCTFail("No action was chosen") }
    try? await Task.sleep(nanoseconds: 30_000_000)
    let a = try XCTUnwrap(f.view.presentedViewController as? UIAlertController)
    XCTAssertEqual(
      a.message, R.string.localizable.askFaceidMessage(preferredLanguages: .currentLocale))
  }
  func testLastChanceAlertExplainsTheLockout() async throws {
    let f = make()
    f.show()
    f.view.showLastChanceAlert()
    try? await Task.sleep(nanoseconds: 30_000_000)
    let a = try XCTUnwrap(f.view.presentedViewController as? UIAlertController)
    XCTAssertEqual(
      a.title, R.string.localizable.pincodeLastTryTitle(preferredLanguages: .currentLocale))
    XCTAssertEqual(a.actions.count, 1)
  }
  func testPinLengthUpgradeRequiresAnExplicitAction() async throws {
    let f = make()
    f.show()
    f.view.showUpdatePinRequestView()
    try? await Task.sleep(nanoseconds: 30_000_000)
    let a = try XCTUnwrap(f.view.presentedViewController as? UIAlertController)
    XCTAssertEqual(
      a.title, R.string.localizable.pincodeLengthInfoTitle(preferredLanguages: .currentLocale))
    XCTAssertEqual(a.actions.count, 1)
    XCTAssertEqual(f.presenter.upgrades, 0)
  }
}
@MainActor private final class PinInputFixture {
  let view = PincodeViewController(), presenter = PinInputPresenter()
  var timers = [Timer]()
  var window: UIWindow?, previousWindow: UIWindow?
  init(mode: PincodeMode) {
    view.mode = mode
    view.presenter = presenter
    view.cooldownTimerFactory = { [weak self] _, block in
      let timer = Timer(timeInterval: 1_000_000, repeats: true, block: block)
      self?.timers.append(timer)
      return timer
    }
    view.loadViewIfNeeded()
    view.updatePinCodeSymbolsCount(with: 6)
  }
  func show() {
    let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    previousWindow = scene?.windows.first { $0.isKeyWindow }
    window = scene.map(UIWindow.init(windowScene:)) ?? UIWindow(frame: UIScreen.main.bounds)
    window?.rootViewController = view
    window?.makeKeyAndVisible()
  }
}
private final class PinInputPresenter: PinSetupPresenterProtocol {
  var starts = 0, deletes = 0, biometry = 0, upgrades = 0, digits = [String]()
  func start() { starts += 1 }
  func cancel() {}
  func activateBiometricAuth() { biometry += 1 }
  func submit(pin: String) {}
  func deleteButtonTapped() { deletes += 1 }
  func padButtonTapped(with symbol: String) { digits.append(symbol) }
  func updatePinButtonTapped() { upgrades += 1 }
}
