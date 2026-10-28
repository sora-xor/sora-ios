// SPDX-License-Identifier: BSD-4-Clause
import SoraFoundation
import SoraKeystore
import UIKit
import XCTest

@testable import SoraPassport

@MainActor
final class RecoveryPresentationFlowTests: XCTestCase {
  private var window: UIWindow!, previousWindow: UIWindow?, language = "en", animations = true
  private var clipboard = [[String: Any]]()
  override func setUp() {
    super.setUp()
    language = LocalizationManager.shared.selectedLocalization
    LocalizationManager.shared.selectedLocalization = "en"
    animations = UIView.areAnimationsEnabled
    UIView.setAnimationsEnabled(false)
    clipboard = UIPasteboard.general.items
    let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    previousWindow = scene?.windows.first { $0.isKeyWindow }
    window = scene.map(UIWindow.init(windowScene:)) ?? UIWindow(frame: UIScreen.main.bounds)
    window.frame = scene?.coordinateSpace.bounds ?? UIScreen.main.bounds
  }
  override func tearDown() async throws {
    window.rootViewController?.dismiss(animated: false)
    await settle()
    window.isHidden = true
    window.rootViewController = nil
    window = nil
    previousWindow?.makeKeyAndVisible()
    UIView.setAnimationsEnabled(animations)
    LocalizationManager.shared.selectedLocalization = language
    UIPasteboard.general.items = clipboard
    try await super.tearDown()
  }
  private func all<T: UIView>(_ type: T.Type, in view: UIView) -> [T] {
    ((view as? T).map { [$0] } ?? []) + view.subviews.flatMap { all(type, in: $0) }
  }
  private func title(_ button: UIButton) -> String? {
    button.currentTitle ?? button.configuration?.attributedTitle.map { String($0.characters) }
      ?? button.accessibilityLabel
  }
  private func mount(_ c: UIViewController) {
    window.rootViewController = c
    window.makeKeyAndVisible()
    c.loadViewIfNeeded()
    window.layoutIfNeeded()
  }
  private func settle() async { try? await Task.sleep(nanoseconds: 35_000_000) }
  private func wait(_ condition: () -> Bool) async {
    for _ in 0..<150 {
      if condition() { return }
      try? await Task.sleep(nanoseconds: 10_000_000)
    }
    XCTFail("Recovery action did not finish")
  }
  private func button(_ id: String, in c: UIViewController) throws -> UIButton {
    try XCTUnwrap(
      all(UIButton.self, in: c.view).first { $0.accessibilityIdentifier == id || title($0) == id })
  }
  private func tap(_ id: String, in c: UIViewController) throws {
    try button(id, in: c).sendActions(for: .touchUpInside)
  }
  private func completeOptions() -> WalletRecoveryOptions {
    var o = WalletRecoveryOptions()
    o.canRetry = true
    o.canRestoreFromPhrase = true
    o.canRestoreFromDrive = true
    o.canShowPhraseAfterPin = true
    o.canSetUpDeviceAgain = true
    o.canSetAsideTransactionRecords = true
    o.canExport = true
    return o
  }
  private func open(
    options: WalletRecoveryOptions? = nil, retry: (() -> Void)? = {}, setAside: (() -> Void)? = {},
    restore: ((Bool) -> Void)? = { _ in }, reason: String? = nil
  ) async -> WalletRecoveryViewController {
    let o = options ?? completeOptions()
    let c = WalletRecoveryViewController(
      reason: reason, onRetry: retry, onSetAside: setAside, onRestore: restore, optionsLoader: { o }
    )
    mount(c)
    await settle()
    XCTAssertEqual(c.options, o)
    return c
  }
  func testRecoveryRendersOnlyActionsSupportedByCurrentFacts() async throws {
    let c = await open(options: WalletRecoveryOptions())
    for id in [
      "wallet-recovery-retry", "wallet-recovery-restore-phrase", "wallet-recovery-restore-keys",
      "wallet-recovery-restore-cloud-backup", "wallet-recovery-show-phrase",
      "wallet-recovery-set-up-again", "wallet-recovery-set-aside-transaction-records",
    ] { XCTAssertTrue(try button(id, in: c).isHidden, id) }
  }
  func testRecoveryWithNoRetryCallbackHidesRetryAndRecordChanges() async throws {
    let c = await open(retry: nil)
    XCTAssertTrue(try button("wallet-recovery-retry", in: c).isHidden)
    XCTAssertTrue(try button("wallet-recovery-set-aside-transaction-records", in: c).isHidden)
  }
  func testRestoreCallbackKeepsPhraseAndDriveAvailableWithoutRetry() async throws {
    let c = await open(retry: nil)
    XCTAssertFalse(try button("wallet-recovery-restore-phrase", in: c).isHidden)
    XCTAssertFalse(try button("wallet-recovery-restore-cloud-backup", in: c).isHidden)
  }
  func testNoRestoreOrRetryCallbackHidesExternalRestoreChoices() async throws {
    let c = await open(retry: nil, restore: nil)
    XCTAssertTrue(try button("wallet-recovery-restore-phrase", in: c).isHidden)
    XCTAssertTrue(try button("wallet-recovery-restore-cloud-backup", in: c).isHidden)
  }
  func testNoSetAsideCallbackHidesDeviceSetupChoice() async throws {
    let c = await open(setAside: nil)
    XCTAssertTrue(try button("wallet-recovery-set-up-again", in: c).isHidden)
  }
  func testRetryRunsOnceWhenTheButtonReceivesRepeatedEvents() async throws {
    var n = 0
    let c = await open(retry: { n += 1 })
    try tap("wallet-recovery-retry", in: c)
    try tap("wallet-recovery-retry", in: c)
    XCTAssertEqual(n, 1)
  }
  func testRetryDisablesStateChangingActions() async throws {
    let c = await open()
    try tap("wallet-recovery-retry", in: c)
    for id in [
      "wallet-recovery-retry", "wallet-recovery-restore-phrase", "wallet-recovery-restore-keys",
      "wallet-recovery-restore-cloud-backup", "wallet-recovery-set-aside-transaction-records",
    ] { XCTAssertFalse(try button(id, in: c).isEnabled, id) }
  }
  func testExportCannotStartWhileRetryIsInFlight() async throws {
    let c = await open()
    try tap("wallet-recovery-retry", in: c)
    try tap("Create protected recovery export", in: c)
    await settle()
    XCTAssertNil(c.presentedViewController)
  }
  func testRecoveryPhraseRequiresOwnerPinBeforeShowingAnyWords() async throws {
    let c = await open()
    try tap("wallet-recovery-show-phrase", in: c)
    let alert = try XCTUnwrap(c.presentedViewController as? UIAlertController)
    let field = try XCTUnwrap(alert.textFields?.first)
    XCTAssertTrue(field.isSecureTextEntry)
    XCTAssertEqual(field.keyboardType, .numberPad)
    XCTAssertEqual(alert.actions.map(\.title), ["Cancel", "Continue"])
    XCTAssertFalse(
      all(UILabel.self, in: c.view).contains { $0.text?.contains("1. abandon") == true })
  }
  func testUnavailablePhraseCannotBeOpenedByAQueuedTap() async throws {
    let c = await open(options: WalletRecoveryOptions())
    try tap("wallet-recovery-show-phrase", in: c)
    XCTAssertNil(c.presentedViewController)
  }
  func testRecoveryPhraseCannotOpenDuringRetry() async throws {
    let c = await open()
    try tap("wallet-recovery-retry", in: c)
    try tap("wallet-recovery-show-phrase", in: c)
    XCTAssertNil(c.presentedViewController)
  }
  func testExternalPhraseRestorePresentsConfirmationBeforeChangingFiles() async throws {
    var calls = [Bool]()
    let c = await open(restore: { calls.append($0) })
    try tap("wallet-recovery-restore-phrase", in: c)
    XCTAssertNotNil(c.presentedViewController as? UIAlertController)
    XCTAssertTrue(calls.isEmpty)
  }
  func testExternalDriveRestorePresentsConfirmationBeforeChangingFiles() async throws {
    var calls = [Bool]()
    let c = await open(restore: { calls.append($0) })
    try tap("wallet-recovery-restore-cloud-backup", in: c)
    XCTAssertNotNil(c.presentedViewController as? UIAlertController)
    XCTAssertTrue(calls.isEmpty)
  }
  func testExternalRestoreDoesNothingWithoutAnOnboardingRoute() async throws {
    let c = await open(restore: nil)
    try tap("wallet-recovery-restore-phrase", in: c)
    XCTAssertNil(c.presentedViewController)
  }
  func testDeviceSetupRequiresConfirmationAndDoesNotCallItsCompletion() async throws {
    var n = 0
    let c = await open(setAside: { n += 1 })
    try tap("wallet-recovery-set-up-again", in: c)
    let alert = try XCTUnwrap(c.presentedViewController as? UIAlertController)
    XCTAssertTrue(alert.actions.contains { $0.style == .cancel })
    XCTAssertEqual(n, 0)
  }
  func testRecordSetAsideConfirmationDescribesLostPendingKnowledge() async throws {
    let c = await open()
    try tap("wallet-recovery-set-aside-transaction-records", in: c)
    let alert = try XCTUnwrap(c.presentedViewController as? UIAlertController)
    XCTAssertTrue(alert.message?.contains("no longer be able to tell") == true)
    XCTAssertEqual(alert.actions.map(\.title), ["Cancel", "Set aside"])
  }
  func testRecordSetAsideCannotBeginDuringRetry() async throws {
    var calls = 0
    let c = await open()
    c.transactionRecordsPaths = {
      calls += 1
      throw RecoveryPresentationFailure.unavailable
    }
    try tap("wallet-recovery-retry", in: c)
    c.setAsideTransactionRecords()
    await settle()
    XCTAssertEqual(calls, 0)
  }
  func testFailedRecordPathReadRestoresActionsAndExplainsThatNothingChanged() async throws {
    let c = await open()
    c.transactionRecordsPaths = { throw RecoveryPresentationFailure.unavailable }
    c.setAsideTransactionRecords()
    await wait { c.presentedViewController != nil }
    let alert = try XCTUnwrap(c.presentedViewController as? UIAlertController)
    XCTAssertEqual(alert.title, "Could not set the records aside")
    XCTAssertTrue(alert.message?.contains("Nothing was changed") == true)
    XCTAssertTrue(try button("wallet-recovery-retry", in: c).isEnabled)
  }
  func testFailedRecordSetAsideDoesNotReportSuccessfulRetry() async throws {
    var calls = 0
    let c = await open(retry: { calls += 1 })
    c.transactionRecordsPaths = { throw RecoveryPresentationFailure.unavailable }
    c.setAsideTransactionRecords()
    await wait { c.presentedViewController != nil }
    XCTAssertEqual(calls, 0)
  }
  func testFailedRecordSetAsideCanBeRetriedIndependently() async throws {
    let c = await open()
    let reads = RecoveryReadCount()
    c.transactionRecordsPaths = {
      reads.increment()
      throw RecoveryPresentationFailure.unavailable
    }
    c.setAsideTransactionRecords()
    await wait { c.presentedViewController != nil }
    c.dismiss(animated: false)
    await settle()
    c.setAsideTransactionRecords()
    await wait { c.presentedViewController != nil }
    XCTAssertEqual(reads.count, 2)
  }
  func testProtectedExportExplainsItsPublicMetadataAndSecretExclusions() async throws {
    let c = await open()
    try tap("Create protected recovery export", in: c)
    let alert = try XCTUnwrap(c.presentedViewController as? UIAlertController)
    XCTAssertEqual(alert.title, "Create protected recovery export?")
    XCTAssertTrue(alert.message?.contains("public wallet metadata") == true)
    XCTAssertTrue(alert.message?.contains("does not contain your phrase") == true)
    XCTAssertEqual(alert.actions.map(\.title), ["Cancel", "Create export"])
  }
  func testExportConfirmationDoesNotBeginWorkBeforeApproval() async throws {
    let c = await open()
    try tap("Create protected recovery export", in: c)
    XCTAssertFalse(all(UIActivityIndicatorView.self, in: c.view).contains(where: \.isAnimating))
    XCTAssertTrue(try button("Create protected recovery export", in: c).isEnabled)
  }
  func testBackupHelpOffersInstructionsAndAnExplicitSupportAction() async throws {
    let c = await open()
    try tap("Recovery export help", in: c)
    let alert = try XCTUnwrap(c.presentedViewController as? UIAlertController)
    XCTAssertEqual(
      alert.actions.map(\.title), ["Copy instructions", "Open SORA support", "Cancel"])
    XCTAssertTrue(alert.message?.contains("Never send anyone your phrase") == true)
  }
  func testCopiedReportRedactsArbitraryHistoricalErrorText() async throws {
    let secret = "untrusted-history-credential"
    let c = await open(reason: secret)
    try tap("wallet-recovery-copy-details", in: c)
    let report = try XCTUnwrap(UIPasteboard.general.string)
    XCTAssertFalse(report.contains(secret))
    XCTAssertTrue(report.contains("legacy record (details unavailable)"))
    XCTAssertTrue(report.contains("Recovery report format: 2"))
  }
  func testCopiedReportIncludesCurrentVersionAndProtectedDataState() async throws {
    let c = await open()
    try tap("wallet-recovery-copy-details", in: c)
    let report = try XCTUnwrap(UIPasteboard.general.string)
    XCTAssertTrue(report.hasPrefix("SORA "))
    XCTAssertTrue(report.contains("iOS: "))
    XCTAssertTrue(report.contains("Protected data when copied:"))
  }
  func testReapplyingOptionsRemovesPreviouslyAvailableActions() async throws {
    let c = await open()
    c.apply(WalletRecoveryOptions())
    XCTAssertTrue(try button("wallet-recovery-show-phrase", in: c).isHidden)
    XCTAssertTrue(try button("wallet-recovery-retry", in: c).isHidden)
    XCTAssertFalse(
      all(UILabel.self, in: c.view).compactMap(\.text).contains { $0.contains("Try again to run") })
  }
  func testUpgradeDetailsDescribePreservationWithoutConfirming() throws {
    var n = 0
    let c = LegacyWalletUpgradeViewController { n += 1 }
    mount(c)
    try tap("What happens during the upgrade?", in: c)
    let alert = try XCTUnwrap(c.presentedViewController as? UIAlertController)
    XCTAssertTrue(alert.message?.contains("not deleted or replaced") == true)
    XCTAssertEqual(n, 0)
  }
  func testUpgradeConfirmationRunsOnceAndShowsProgress() throws {
    var n = 0
    let c = LegacyWalletUpgradeViewController { n += 1 }
    mount(c)
    try tap("Upgrade wallet", in: c)
    try tap("Upgrade wallet", in: c)
    XCTAssertEqual(n, 1)
    XCTAssertFalse(try button("Upgrade wallet", in: c).isEnabled)
    XCTAssertTrue(all(UIActivityIndicatorView.self, in: c.view).contains(where: \.isAnimating))
  }
  func testUpgradeAssuranceIsMultilineAndDoesNotAnnounceDecorativeIcon() {
    let row = LegacyWalletUpgradeViewController.assurance("Public assurance")
    XCTAssertEqual(all(UILabel.self, in: row).first?.text, "Public assurance")
    XCTAssertEqual(all(UILabel.self, in: row).first?.numberOfLines, 0)
    XCTAssertFalse(all(UIImageView.self, in: row).first?.isAccessibilityElement ?? true)
  }
  func testReleasedRecoveryScreenIsNotRetainedByItsOptionsRead() async {
    var c: WalletRecoveryViewController? = await open()
    weak var weakController = c
    window.rootViewController = UIViewController()
    c = nil
    await settle()
    XCTAssertNil(weakController)
  }
}
private enum RecoveryPresentationFailure: Error { case unavailable }
private final class RecoveryReadCount: @unchecked Sendable {
  private let lock = NSLock()
  private var value = 0
  func increment() {
    lock.lock()
    value += 1
    lock.unlock()
  }
  var count: Int {
    lock.lock()
    defer { lock.unlock() }
    return value
  }
}
