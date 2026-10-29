// SPDX-License-Identifier: Apache-2.0
import SoraFoundation
import CoreData
import IrohaCrypto
import RobinHood
import SoraUI
import MessageUI
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

@MainActor
class RootActionFixtureTests: XCTestCase {
    var window: UIWindow!, previousWindow: UIWindow?, language = "en", animations = true
    var clipboard = [[String: Any]]()
    override func setUp() {
        super.setUp(); language = LocalizationManager.shared.selectedLocalization
        LocalizationManager.shared.selectedLocalization = "en"; animations = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false); clipboard = UIPasteboard.general.items
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        previousWindow = scene?.windows.first { $0.isKeyWindow }
        window = scene.map(UIWindow.init(windowScene:)) ?? UIWindow(frame: UIScreen.main.bounds)
        window.frame = scene?.coordinateSpace.bounds ?? UIScreen.main.bounds
    }
    override func tearDown() async throws {
        if let host = window.rootViewController {
            host.view.endEditing(true)
            await wait { host.presentedViewController?.isBeingPresented != true }
            host.dismiss(animated: false)
            await wait { host.presentedViewController == nil }
        }
        window.isHidden = true; window.rootViewController = nil; window = nil; previousWindow?.makeKeyAndVisible()
        UIView.setAnimationsEnabled(animations); LocalizationManager.shared.selectedLocalization = language
        UIPasteboard.general.items = clipboard; try await super.tearDown()
    }
    func all<T: UIView>(_ type: T.Type, _ view: UIView) -> [T] { ((view as? T).map { [$0] } ?? []) + view.subviews.flatMap { all(type, $0) } }
    func mount(_ c: UIViewController) { window.rootViewController = c; window.makeKeyAndVisible(); c.loadViewIfNeeded(); window.layoutIfNeeded() }
    func settle() async { try? await Task.sleep(nanoseconds: 30_000_000) }
    func wait(_ predicate: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        // Real UIKit keyboard transitions and local crypto work share the simulator
        // with the complete suite; wait for the required state, not a fixed pause.
        for _ in 0..<1000 { if predicate() { return }; try? await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertTrue(predicate(), file: file, line: line)
    }
    func button(_ id: String, _ c: UIViewController) throws -> UIButton {
        try XCTUnwrap(all(UIButton.self, c.view).first {
            $0.accessibilityIdentifier == id || $0.currentTitle == id || $0.accessibilityLabel == id ||
            $0.configuration?.attributedTitle.map { String($0.characters) } == id
        })
    }
    func tap(_ id: String, _ c: UIViewController) throws { try button(id, c).sendActions(for: .touchUpInside) }
    func alert(_ c: UIViewController) throws -> UIAlertController { try XCTUnwrap(c.presentedViewController as? UIAlertController) }
    func choose(_ title: String, _ c: UIViewController) async throws {
        let prompt = try alert(c); let action = try XCTUnwrap(prompt.actions.first { $0.title == title })
        await wait { !prompt.isBeingPresented && prompt.transitionCoordinator == nil }
        prompt.view.endEditing(true)
        // KVC returns an Objective-C block; a Swift closure conditional cast silently fails.
        let block = action.value(forKey: "handler")
        let dismissed = expectation(description: "Alert dismissed before its action")
        prompt.dismiss(animated: false) { dismissed.fulfill() }
        await fulfillment(of: [dismissed], timeout: 10)
        XCTAssertNil(c.presentedViewController)
        guard c.presentedViewController == nil else { return }
        if let block {
            let handler = unsafeBitCast(block as AnyObject, to: (@convention(block) (UIAlertAction) -> Void).self)
            handler(action)
        }
        await settle()
    }
    func texts(_ c: UIViewController) -> [String] { all(UILabel.self, c.view).compactMap(\.text) }
    func account(_ suffix: String = "one") -> AccountItem {
        AccountItem(address: "recovery-fixture-" + suffix, cryptoType: .sr25519, networkType: 69, username: "Fixture " + suffix,
                    publicKeyData: Data(repeating: 4, count: 32), settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: 0, isSelected: false)
    }
    func options() -> WalletRecoveryOptions {
        var value = WalletRecoveryOptions(); value.canRetry = true; value.canRestoreExistingKeys = true
        value.canRestoreFromPhrase = true; value.canRestoreFromDrive = true; value.canShowPhraseAfterPin = true; value.canExport = true
        return value
    }
    func inertRecoveryActions() -> WalletRecoveryScreenActions {
        var a = WalletRecoveryScreenActions()
        a.accounts = { throw RecoveryPresentationFailure.unavailable }; a.inventory = { [] }
        a.prepareKeys = { _ in throw RecoveryPresentationFailure.unavailable }
        a.readBackup = { _, _ in throw RecoveryPresentationFailure.unavailable }
        a.restoreBackup = { _, _, _ in throw RecoveryPresentationFailure.unavailable }
        a.restorePhrase = { _, _, _ in throw RecoveryPresentationFailure.unavailable }
        a.revealPhrases = { _ in throw RecoveryPresentationFailure.unavailable }
        a.exportPackage = { throw RecoveryPresentationFailure.unavailable }; a.protectedDataAvailable = { true }
        a.openSupport = { _ in XCTFail("Unexpected support navigation") }; return a
    }
    func openRecovery(retry: @escaping () -> Void = {}, configure: (inout WalletRecoveryScreenActions) -> Void = { _ in }) async -> WalletRecoveryViewController {
        let values = options(); let c = WalletRecoveryViewController(reason: nil, onRetry: retry, optionsLoader: { values })
        var a = inertRecoveryActions(); configure(&a); c.actions = a; mount(c); await wait { c.options.canRestoreExistingKeys }; return c
    }
    func missing(_ a: inout WalletRecoveryScreenActions, account: AccountItem) {
        a.accounts = { [account] }; a.prepareKeys = { _ in (WalletCredentialRepair(keystore: InMemoryKeychain(), settings: InMemorySettingsManager()), true) }
    }
}

@MainActor
final class RootRecoveryActionCoverageTests: RootActionFixtureTests {
    func testUnreadableAccountInventoryRestoresButtonsAndKeepsDataUntouched() async throws {
        let c = await openRecovery(); try tap("wallet-recovery-restore-keys", c)
        await wait { c.presentedViewController != nil }
        XCTAssertTrue(try alert(c).message?.contains("data has not been changed") == true)
        XCTAssertTrue(try button("wallet-recovery-retry", c).isEnabled)
    }
    func testEmptyAccountInventoryDoesNotStartCredentialRepair() async throws {
        let c = await openRecovery { $0.accounts = { [] }; $0.prepareKeys = { _ in XCTFail("Empty inventory"); throw RecoveryPresentationFailure.unavailable } }
        try tap("wallet-recovery-restore-keys", c); await wait { c.presentedViewController != nil }
        XCTAssertEqual(try alert(c).title, "Wallet keys not restored")
    }
    func testMultipleAccountsShowAnExplicitIdentityChoice() async throws {
        let one = account(), two = account("two")
        let c = await openRecovery { $0.accounts = { [one, two] } }; try tap("wallet-recovery-restore-keys", c)
        await wait { c.presentedViewController != nil }
        XCTAssertEqual(try alert(c).title, "Choose the existing wallet")
        XCTAssertEqual(try alert(c).actions.count, 3); XCTAssertTrue(try alert(c).actions[0].title?.contains(one.username) == true)
        XCTAssertTrue(try alert(c).actions[1].title?.contains(two.username) == true)
    }
    func testChoosingAnAccountPassesItsExactIdentityToPreparation() async throws {
        let one = account(), two = account("two"); let received = RootActionValues<String>()
        let c = await openRecovery { a in a.accounts = { [one, two] }; a.prepareKeys = { received.append($0.address); throw RecoveryPresentationFailure.unavailable } }
        try tap("wallet-recovery-restore-keys", c); await wait { c.presentedViewController != nil }
        let choice = try XCTUnwrap(try alert(c).actions[1].title); try await choose(choice, c)
        await wait { !received.values.isEmpty }; XCTAssertEqual(received.values, [two.address])
    }
    func testSingleAccountPreparationFailureIsShownWithoutAnEditor() async throws {
        let one = account(); let c = await openRecovery { $0.accounts = { [one] } }
        try tap("wallet-recovery-restore-keys", c); await wait { c.presentedViewController != nil }
        XCTAssertEqual(try alert(c).title, "Wallet keys not restored")
    }
    func testMissingCredentialsOpenSecurePhraseAndDerivationFields() async throws {
        let one = account(); let c = await openRecovery { self.missing(&$0, account: one) }
        try tap("wallet-recovery-restore-keys", c); await wait { c.presentedViewController != nil }
        let prompt = try alert(c); XCTAssertEqual(prompt.textFields?.count, 2)
        XCTAssertTrue(prompt.textFields?.allSatisfy(\.isSecureTextEntry) == true)
        XCTAssertEqual(prompt.textFields?.first?.accessibilityIdentifier, "wallet-recovery-phrase")
        XCTAssertEqual(prompt.actions.map(\.title), ["Cancel", "Verify and restore"])
    }
    func testCancellingPhraseEntryClearsBothSensitiveFields() async throws {
        let one = account(); let c = await openRecovery { self.missing(&$0, account: one) }
        try tap("wallet-recovery-restore-keys", c); await wait { c.presentedViewController != nil }
        let prompt = try alert(c); prompt.textFields?[0].text = "fixture phrase"; prompt.textFields?[1].text = "//fixture"
        try await choose("Cancel", c); XCTAssertTrue(prompt.textFields?.allSatisfy { $0.text?.isEmpty != false } == true)
    }
    func testVerifiedPhrasePassesExactValuesThenRechecksTheWallet() async throws {
        let one = account(); let received = RootActionValues<[String]>(); var retries = 0
        let c = await openRecovery(retry: { retries += 1 }) { a in self.missing(&a, account: one); a.restorePhrase = { received.append([$0.address, $1, $2]) } }
        try tap("wallet-recovery-restore-keys", c); await wait { c.presentedViewController != nil }
        let prompt = try alert(c); prompt.textFields?[0].text = "fixture phrase"; prompt.textFields?[1].text = "//fixture"
        try await choose("Verify and restore", c); await wait { retries == 1 }
        XCTAssertEqual(received.values, [[one.address, "fixture phrase", "//fixture"]]); XCTAssertTrue(prompt.textFields?.allSatisfy { $0.text?.isEmpty != false } == true)
    }
    func testRejectedPhraseExplainsPreservationAndDoesNotRetryStartup() async throws {
        let one = account(); var retries = 0
        let c = await openRecovery(retry: { retries += 1 }) { self.missing(&$0, account: one) }
        try tap("wallet-recovery-restore-keys", c); await wait { c.presentedViewController != nil }
        try await choose("Verify and restore", c); await wait { c.presentedViewController != nil }
        XCTAssertTrue(try alert(c).message?.contains("Existing accounts and keys were not replaced") == true); XCTAssertEqual(retries, 0)
    }
    func testCloudRecoveryRequiresProtectedDataBeforeReadingDrive() async throws {
        let one = account(); let c = await openRecovery { a in self.missing(&a, account: one); a.protectedDataAvailable = { false }; a.readBackup = { _, _ in XCTFail("Locked phone"); return Data() } }
        try tap("wallet-recovery-restore-cloud-backup", c); await wait { c.presentedViewController != nil }
        XCTAssertEqual(try alert(c).message, "Unlock this iPhone, then try again.")
    }
    func testCloudReadFailureRestoresControlsAndShowsARecoverableError() async throws {
        let one = account(); let c = await openRecovery { self.missing(&$0, account: one) }
        try tap("wallet-recovery-restore-cloud-backup", c); await wait { c.presentedViewController != nil }
        XCTAssertTrue(try button("wallet-recovery-restore-cloud-backup", c).isEnabled)
        XCTAssertFalse(try XCTUnwrap(try alert(c).message).isEmpty)
    }
    func testCloudReadRequestsOnlyTheSelectedAccountBackup() async throws {
        let one = account(); let requested = RootActionValues<String>()
        let c = await openRecovery { a in self.missing(&a, account: one); a.readBackup = { _, address in requested.append(address); return Data("fixture backup".utf8) } }
        try tap("wallet-recovery-restore-cloud-backup", c); await wait { c.presentedViewController != nil }
        XCTAssertEqual(requested.values, [one.address]); XCTAssertEqual(try alert(c).title, "Unlock your existing backup")
        XCTAssertEqual(try alert(c).textFields?.first?.accessibilityIdentifier, "wallet-recovery-backup-password")
        XCTAssertTrue(try alert(c).textFields?.first?.isSecureTextEntry == true)
    }
    func testCancelledBackupPasswordIsErasedWithoutRestoringKeys() async throws {
        let one = account(); let c = await openRecovery { a in self.missing(&a, account: one); a.readBackup = { _, _ in Data([1]) }; a.restoreBackup = { _, _, _ in XCTFail("Cancelled password") } }
        try tap("wallet-recovery-restore-cloud-backup", c); await wait { c.presentedViewController != nil }
        let prompt = try alert(c); prompt.textFields?.first?.text = "fixture password"; try await choose("Cancel", c)
        XCTAssertTrue(prompt.textFields?.first?.text?.isEmpty != false)
    }
    func testVerifiedCloudBackupRestoresTheExactAccountAndRechecksStartup() async throws {
        let one = account(); let input = Data([1, 2, 3]); let received = RootActionValues<String>(); var retries = 0
        let c = await openRecovery(retry: { retries += 1 }) { a in self.missing(&a, account: one); a.readBackup = { _, _ in input }; a.restoreBackup = { data, password, account in XCTAssertEqual(data, input); received.append(account.address + ":" + password) } }
        try tap("wallet-recovery-restore-cloud-backup", c); await wait { c.presentedViewController != nil }
        let prompt = try alert(c); prompt.textFields?.first?.text = "fixture password"; try await choose("Verify and restore", c)
        await wait { retries == 1 }; XCTAssertEqual(received.values, [one.address + ":fixture password"]); XCTAssertTrue(prompt.textFields?.first?.text?.isEmpty != false)
    }
    func testRejectedCloudBackupDoesNotRecheckStartup() async throws {
        let one = account(); var retries = 0
        let c = await openRecovery(retry: { retries += 1 }) { a in self.missing(&a, account: one); a.readBackup = { _, _ in Data([1]) } }
        try tap("wallet-recovery-restore-cloud-backup", c); await wait { c.presentedViewController != nil }
        try await choose("Verify and restore", c); await wait { c.presentedViewController != nil }
        XCTAssertEqual(retries, 0); XCTAssertTrue(try button("wallet-recovery-retry", c).isEnabled)
    }
    func testPhraseRevealWithNoStoredWordsExplainsTheEmptyResult() async throws {
        let c = await openRecovery { $0.revealPhrases = { _ in [] } }; try tap("wallet-recovery-show-phrase", c)
        try await choose("Continue", c); await wait { c.presentedViewController != nil }
        XCTAssertEqual(try alert(c).title, "Recovery phrase not shown"); XCTAssertTrue(try alert(c).message?.contains("No recovery phrase") == true)
    }
    func testPhraseRevealFailureUsesTheOwnershipGateMessage() async throws {
        let c = await openRecovery { $0.revealPhrases = { _ in throw WalletRetainedPinGate.Failure.incorrectPin(attemptsBeforeWait: 2) } }
        try tap("wallet-recovery-show-phrase", c); let prompt = try alert(c); prompt.textFields?.first?.text = "123456"
        try await choose("Continue", c); await wait { c.presentedViewController != nil }
        XCTAssertTrue(try alert(c).message?.contains("Attempts left before a short wait: 2") == true); XCTAssertTrue(prompt.textFields?.first?.text?.isEmpty != false)
    }
    func testPhraseRevealSuccessOpensTheProtectedScreenWithWordsInitiallyHidden() async throws {
        let c = await openRecovery { $0.revealPhrases = { _ in [.init(address: "fixture", name: "Fixture", words: ["public", "fixture"])] } }
        try tap("wallet-recovery-show-phrase", c); try await choose("Continue", c)
        await wait { c.presentedViewController is WalletRecoveryPhraseViewController }
        let view = try XCTUnwrap(c.presentedViewController as? WalletRecoveryPhraseViewController); view.loadViewIfNeeded()
        XCTAssertEqual(view.modalPresentationStyle, .fullScreen); XCTAssertTrue(all(UILabel.self, view.view).first { $0.accessibilityIdentifier == "wallet-recovery-phrase-words" }?.isHidden == true)
    }
    func testExportFailureRestoresTheExportButtonAndStatesNoPackageWasPublished() async throws {
        let c = await openRecovery(); try tap("Create protected recovery export", c); try await choose("Create export", c)
        await wait { c.presentedViewController != nil }; XCTAssertEqual(try alert(c).title, "Recovery export stopped safely")
        XCTAssertTrue(texts(c).contains("No recovery package was published.")); XCTAssertTrue(try button("Create protected recovery export", c).isEnabled)
    }
    func testExportSuccessPresentsThePackageShareSheetAndStopsProgress() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true); defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("public-fixture.zip"); try Data("public-fixture".utf8).write(to: url)
        let c = await openRecovery { $0.exportPackage = { url } }; try tap("Create protected recovery export", c); try await choose("Create export", c)
        // System share extensions may initialize after the app has finished publishing the export.
        let deadline = Date().addingTimeInterval(10)
        while c.presentedViewController == nil && Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertTrue(c.presentedViewController is UIActivityViewController,
                      "Expected the package share sheet; presented: \(String(describing: c.presentedViewController))")
        XCTAssertTrue(texts(c).contains { $0.contains("Protected export created.") }); XCTAssertFalse(all(UIActivityIndicatorView.self, c.view).contains(where: \.isAnimating))
        XCTAssertTrue(try button("Create protected recovery export", c).isEnabled)
    }
    func testSupportButtonUsesOnlyTheConfiguredSupportUrl() async throws {
        var urls: [URL] = []; let c = await openRecovery { $0.openSupport = { urls.append($0) } }
        try tap("Contact support", c); XCTAssertEqual(urls, [ApplicationConfig.shared.supportURL])
    }
    func testBackupHelpCopiesOnlyItsPublicInstructions() async throws {
        let c = await openRecovery(); try tap("Recovery export help", c); let instructions = try alert(c).message
        try await choose("Copy instructions", c); XCTAssertEqual(UIPasteboard.general.string, instructions)
    }
    func testBackupHelpOpensSupportOnlyAfterItsExplicitAction() async throws {
        var urls: [URL] = []; let c = await openRecovery { $0.openSupport = { urls.append($0) } }
        try tap("Recovery export help", c); XCTAssertTrue(urls.isEmpty); try await choose("Open SORA support", c)
        XCTAssertEqual(urls, [ApplicationConfig.shared.supportURL])
    }
}

private final class RootActionValues<T>: @unchecked Sendable {
    private let lock = NSLock(); private var stored: [T] = []
    func append(_ value: T) { lock.lock(); stored.append(value); lock.unlock() }
    var values: [T] { lock.lock(); defer { lock.unlock() }; return stored }
}

@MainActor
final class RootWelcomeActionCoverageTests: RootActionFixtureTests {
    func openWelcome(options value: WalletRecoveryOptions = WalletRecoveryOptions(), continued: @escaping () -> Void = {}, restored: @escaping () -> Void = {}, restore: ((Bool) -> Void)? = nil,
                     configure: (inout WalletWelcomeScreenActions) -> Void = { _ in }) async -> WalletWelcomeBackViewController {
        let c = WalletWelcomeBackViewController(keystore: InMemoryKeychain(), settings: InMemorySettingsManager(), onContinueToOnboarding: continued, onWalletsRestored: restored, onRestore: restore)
        var a = WalletWelcomeScreenActions(); a.loadOptions = { _, _ in (value, false) }; a.leaveForSetup = { _, _ in }
        a.restoreWallets = { _, _, completion in completion(.nothingRestored(message: "Fixture unavailable")) }
        a.revealPhrases = { _, _, _ in throw RecoveryPresentationFailure.unavailable }
        a.restoreEarlierData = { _, _ in XCTFail("Unexpected earlier data restoration") }; a.openSupport = { _ in XCTFail("Unexpected support navigation") }
        configure(&a); c.actions = a; mount(c); await settle(); return c
    }
    func testPhraseRestoreRoutesToPhraseOnboardingAfterSetupPreparation() async throws {
        var choices: [Bool] = []; let c = await openWelcome(restore: { choices.append($0) })
        try tap("wallet-welcome-back-phrase", c); await wait { choices.count == 1 }; XCTAssertEqual(choices, [false])
    }
    func testDriveRestoreRoutesToCloudOnboardingAfterSetupPreparation() async throws {
        var choices: [Bool] = []; let c = await openWelcome(restore: { choices.append($0) })
        try tap("wallet-welcome-back-drive", c); await wait { choices.count == 1 }; XCTAssertEqual(choices, [true])
    }
    func testRestoreWithoutASpecificRouteFallsBackToOnboarding() async throws {
        var continued = 0; let c = await openWelcome(continued: { continued += 1 }); c.leaveForOnboarding(restoreFromDrive: true)
        await wait { continued == 1 }; XCTAssertTrue(c.view.isUserInteractionEnabled)
    }
    func testRestorableWalletsRequireExplicitChoiceBeforeStartingFresh() async throws {
        var continued = 0; let c = await openWelcome(options: options(), continued: { continued += 1 }); c.leaveForOnboarding()
        XCTAssertEqual(try alert(c).actions.map(\.title), ["Restore them now", "Continue without them", "Cancel"]); XCTAssertEqual(continued, 0)
        try await choose("Cancel", c); XCTAssertEqual(continued, 0)
    }
    func testContinuingWithoutRetainedWalletsPreservesTheChosenRestoreDestination() async throws {
        var choices: [Bool] = []; let c = await openWelcome(options: options(), restore: { choices.append($0) }); c.leaveForOnboarding(restoreFromDrive: true)
        try await choose("Continue without them", c); await wait { choices.count == 1 }; XCTAssertEqual(choices, [true])
    }
    func testSetupPreparationFailureDoesNotLeaveTheWelcomeScreen() async throws {
        var continued = 0; let c = await openWelcome(continued: { continued += 1 }) { $0.leaveForSetup = { _, _ in throw RecoveryPresentationFailure.unavailable } }
        c.leaveForOnboarding(); await wait { c.presentedViewController != nil }
        XCTAssertEqual(try alert(c).title, "Could not prepare wallet setup"); XCTAssertEqual(continued, 0); XCTAssertTrue(c.view.isUserInteractionEnabled)
        XCTAssertEqual(try alert(c).actions.map(\.title), ["Try again", "Contact support", "Cancel"])
    }
    func testRetryAfterSetupFailureKeepsTheOriginalRestoreChoice() async throws {
        var choices: [Bool] = []; let c = await openWelcome(restore: { choices.append($0) }) { $0.leaveForSetup = { _, _ in throw RecoveryPresentationFailure.unavailable } }
        c.leaveForOnboarding(restoreFromDrive: false); await wait { c.presentedViewController != nil }
        c.actions.leaveForSetup = { _, _ in }; try await choose("Try again", c); await wait { choices.count == 1 }; XCTAssertEqual(choices, [false])
    }
    func testSetupFailureSupportActionUsesTheConfiguredSupportUrl() async throws {
        var urls: [URL] = []; let c = await openWelcome { a in a.leaveForSetup = { _, _ in throw RecoveryPresentationFailure.unavailable }; a.openSupport = { urls.append($0) } }
        c.leaveForOnboarding(); await wait { c.presentedViewController != nil }; try await choose("Contact support", c)
        XCTAssertEqual(urls, [ApplicationConfig.shared.supportURL])
    }
    func testWelcomeSupportButtonUsesTheConfiguredSupportUrl() async throws {
        var urls: [URL] = []; let c = await openWelcome { $0.openSupport = { urls.append($0) } }; try tap("Contact support", c)
        XCTAssertEqual(urls, [ApplicationConfig.shared.supportURL])
    }
    func testCompleteRetainedWalletRestoreRestartsVerificationOnce() async throws {
        var restored = 0; let c = await openWelcome(options: options(), restored: { restored += 1 }) { $0.restoreWallets = { _, busy, finish in busy(true); busy(false); finish(.restored(count: 2, failed: 0)) } }
        try tap("wallet-welcome-back-restore-found", c); XCTAssertEqual(restored, 1); XCTAssertTrue(c.view.isUserInteractionEnabled)
    }
    func testPartialRetainedRestoreRequiresAcknowledgementBeforeStartup() async throws {
        var restored = 0; let c = await openWelcome(options: options(), restored: { restored += 1 }) { $0.restoreWallets = { _, _, finish in finish(.restored(count: 2, failed: 1)) } }
        try tap("wallet-welcome-back-restore-found", c); XCTAssertEqual(restored, 0); XCTAssertEqual(try alert(c).title, "Some wallets were restored")
        XCTAssertTrue(try alert(c).message?.contains("Restored: 2. Not restored: 1.") == true)
        try await choose("OK", c); XCTAssertEqual(restored, 1)
    }
    func testSavedWalletsRequiringPinSetupOfferContinueWithoutLosingRows() async throws {
        var restored = 0; let c = await openWelcome(options: options(), restored: { restored += 1 }) { $0.restoreWallets = { _, _, finish in finish(.setupRequired(count: 1, message: "Saved wallet needs PIN setup")) } }
        try tap("wallet-welcome-back-restore-found", c); XCTAssertEqual(try alert(c).title, "Complete PIN setup"); XCTAssertEqual(restored, 0)
        try await choose("Continue", c); XCTAssertEqual(restored, 1)
    }
    func testFailedRetainedRestoreShowsItsReasonAndRefreshesAvailableActions() async throws {
        let reads = RootActionValues<Int>(); let values = options()
        let c = await openWelcome(options: values) { a in a.loadOptions = { _, _ in reads.append(1); return (values, false) }; a.restoreWallets = { _, _, finish in finish(.nothingRestored(message: "Fixture rejected")) } }
        try tap("wallet-welcome-back-restore-found", c); XCTAssertEqual(try alert(c).message, "Fixture rejected"); await wait { reads.values.count >= 2 }
    }
    func testRestorationBusyStateRejectsRepeatedRestoreAndEarlierDataActions() async throws {
        var calls = 0; let c = await openWelcome(options: options()) { a in a.restoreWallets = { _, busy, _ in calls += 1; busy(true) }; a.restoreEarlierData = { _, _ in XCTFail("Busy restoration") } }
        try tap("wallet-welcome-back-restore-found", c); try tap("wallet-welcome-back-restore-found", c); try tap("wallet-welcome-back-earlier-data", c)
        XCTAssertEqual(calls, 1); XCTAssertFalse(c.view.isUserInteractionEnabled)
    }
    func testUnavailableRetainedWalletsIgnoreQueuedRestoreTaps() async throws {
        let c = await openWelcome { $0.restoreWallets = { _, _, _ in XCTFail("No retained wallets") } }
        try tap("wallet-welcome-back-restore-found", c); XCTAssertNil(c.presentedViewController)
    }
    func testEarlierWalletDataActionKeepsItsStartupCompletion() async throws {
        var restored = 0; let c = await openWelcome(restored: { restored += 1 }) { a in a.loadOptions = { _, _ in (WalletRecoveryOptions(), true) }; a.restoreEarlierData = { _, completion in completion() } }
        XCTAssertFalse(try button("wallet-welcome-back-earlier-data", c).isHidden); try tap("wallet-welcome-back-earlier-data", c); XCTAssertEqual(restored, 1)
    }
    func testWelcomePhraseRevealFailureRestoresInteractionAndExplainsTheError() async throws {
        let c = await openWelcome(options: options()); try tap("wallet-welcome-back-show-phrase", c); try await choose("Continue", c)
        await wait { c.presentedViewController != nil }; XCTAssertEqual(try alert(c).title, "Nothing was changed"); XCTAssertTrue(c.view.isUserInteractionEnabled)
    }
    func testWelcomePhraseRevealPassesTheEnteredPinAndErasesTheField() async throws {
        let pins = RootActionValues<String>(); let c = await openWelcome(options: options()) { $0.revealPhrases = { pin, _, _ in pins.append(pin); return [] } }
        try tap("wallet-welcome-back-show-phrase", c); let prompt = try alert(c); prompt.textFields?.first?.text = "123456"; try await choose("Continue", c)
        await wait { !pins.values.isEmpty }; XCTAssertEqual(pins.values, ["123456"]); XCTAssertTrue(prompt.textFields?.first?.text?.isEmpty != false)
        await wait { c.presentedViewController != nil }; XCTAssertEqual(try alert(c).title, "Recovery phrase not shown")
    }
    func testWelcomePhraseRevealSuccessOpensTheProtectedPhraseScreen() async throws {
        let c = await openWelcome(options: options()) { $0.revealPhrases = { _, _, _ in [.init(address: "fixture", name: "Fixture", words: ["public", "fixture"])] } }
        try tap("wallet-welcome-back-show-phrase", c); try await choose("Continue", c); await wait { c.presentedViewController is WalletRecoveryPhraseViewController }
        XCTAssertEqual(c.presentedViewController?.modalPresentationStyle, .fullScreen)
    }
}

@MainActor
final class PresentationUtilityCoverageTests: XCTestCase {
    private var originalKeyboard: KeyboardService!
    private var originalMeasurement = CGRect.zero
    override func setUp() {
        super.setUp(); originalKeyboard = KeyboardService.serviceSingleton
        originalMeasurement = originalKeyboard.measuredSize
    }
    override func tearDown() {
        KeyboardService.serviceSingleton = originalKeyboard; originalKeyboard.measuredSize = originalMeasurement
        originalKeyboard = nil; super.tearDown()
    }
    func testStandardSheetHeaderKeepsItsGrabberInsideTheVisibleHeader() {
        let style = ModalSheetPresentationHeaderStyle.modalHeaderStyle
        XCTAssertEqual(style.preferredHeight, 20); XCTAssertEqual(style.cornerRadius, 10)
        XCTAssertGreaterThan(style.indicatorSize.width, style.indicatorSize.height)
        XCTAssertLessThanOrEqual(style.indicatorVerticalOffset + style.indicatorSize.height, style.preferredHeight)
        XCTAssertEqual(style.backgroundColor, .white)
    }
    func testNeumorphicSheetUsesTheConfiguredPaletteAndRoundedCorners() {
        let style = ModalSheetPresentationHeaderStyle.neu
        XCTAssertEqual(style.backgroundColor, R.color.neumorphism.base())
        XCTAssertEqual(style.indicatorColor, R.color.neumorphism.separator())
        XCTAssertEqual(style.cornerRadius, 40); XCTAssertEqual(style.indicatorSize, CGSize(width: 64, height: 4))
    }
    func testStandardSheetRetainsSafeAreaCoverageAndPredictableGestureThresholds() throws {
        let config = ModalSheetPresentationConfiguration.sora
        XCTAssertTrue(config.extendUnderSafeArea); XCTAssertEqual(config.dismissFinishSpeedFactor, 0.6)
        XCTAssertEqual(config.dismissCancelSpeedFactor, 0.6)
        XCTAssertGreaterThan(config.dismissPercentThreshold, 0); XCTAssertLessThan(config.dismissPercentThreshold, 1)
        XCTAssertGreaterThan(config.dismissMinimumOffset, 0)
        XCTAssertEqual(try XCTUnwrap(config.style.headerStyle).preferredHeight, 20)
    }
    func testStandardSheetHasImmediateQuarterSecondEaseOutAppearanceAndLinearDismissal() throws {
        let config = ModalSheetPresentationConfiguration.sora
        let appear = try XCTUnwrap(config.contentAppearanceAnimator as? BlockViewAnimator)
        let dismiss = try XCTUnwrap(config.contentDissmisalAnimator as? BlockViewAnimator)
        XCTAssertEqual(appear.duration, 0.25); XCTAssertEqual(appear.delay, 0); XCTAssertEqual(appear.options, .curveEaseOut)
        XCTAssertEqual(dismiss.duration, 0.25); XCTAssertEqual(dismiss.delay, 0); XCTAssertEqual(dismiss.options, .curveLinear)
    }
    func testNeumorphicSheetKeepsItsDimmerAndMatchedTransitionDurations() throws {
        let config = ModalSheetPresentationConfiguration.neu
        XCTAssertEqual(config.style.backdropColor, R.color.neumorphism.polkaswapDim())
        XCTAssertEqual(try XCTUnwrap(config.style.headerStyle).cornerRadius, 40)
        XCTAssertTrue(config.extendUnderSafeArea); XCTAssertEqual(config.dismissFinishSpeedFactor, 0.6); XCTAssertEqual(config.dismissCancelSpeedFactor, 0.6)
        XCTAssertEqual(config.contentAppearanceAnimator.duration, 0.25); XCTAssertEqual(config.contentDissmisalAnimator.duration, 0.25)
    }
    func testKeyboardMeasurementUsesTheFirstValidEndFrame() {
        let service = KeyboardService(); service.measuredSize = .zero
        let frame = CGRect(x: 0, y: 500, width: 390, height: 344)
        NotificationCenter.default.post(name: UIResponder.keyboardDidShowNotification, object: nil, userInfo: [UIResponder.keyboardFrameEndUserInfoKey: NSValue(cgRect: frame)])
        XCTAssertEqual(service.measuredSize, frame)
        NotificationCenter.default.post(name: UIResponder.keyboardDidShowNotification, object: nil, userInfo: [UIResponder.keyboardFrameEndUserInfoKey: NSValue(cgRect: CGRect(x: 0, y: 600, width: 390, height: 244))])
        XCTAssertEqual(service.measuredSize, frame)
    }
    func testMalformedKeyboardNotificationsDoNotPublishAMeasurement() {
        let service = KeyboardService(); service.measuredSize = .zero
        NotificationCenter.default.post(name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.post(name: UIResponder.keyboardDidShowNotification, object: nil, userInfo: [UIResponder.keyboardFrameEndUserInfoKey: "invalid"])
        NotificationCenter.default.post(name: UIResponder.keyboardDidShowNotification, object: nil, userInfo: [UIResponder.keyboardFrameBeginUserInfoKey: NSValue(cgRect: CGRect(x: 0, y: 500, width: 390, height: 344))])
        XCTAssertEqual(service.measuredSize, .zero)
    }
    func testKeyboardHeightAndSizeUseTheSharedMeasuredEndFrame() {
        let previous = KeyboardService.serviceSingleton; defer { KeyboardService.serviceSingleton = previous }
        let service = KeyboardService(); service.measuredSize = CGRect(x: 5, y: 500, width: 380, height: 300)
        KeyboardService.serviceSingleton = service
        XCTAssertEqual(KeyboardService.keyboardHeight(), 300); XCTAssertEqual(KeyboardService.keyboardSize(), service.measuredSize)
    }
    func testReleasedKeyboardObserverDoesNotRemainAlive() {
        weak var observed: KeyboardService?
        autoreleasepool { let service = KeyboardService(); observed = service }
        XCTAssertNil(observed)
    }
    func testUnavailableEmailComposerDoesNotPresentOrClaimCompletion() {
        // XCTest runs this suite on an unconfigured iOS simulator.
        XCTAssertFalse(MFMailComposeViewController.canSendMail())
        let host = PresentationMailHost(); var completions = [Bool]()
        let result = PresentationMailRoute().writeEmail(with: SocialMessage(body: "Public support request", subject: "Support", recepients: ["support@example.invalid"]), from: host, completionHandler: { completions.append($0) })
        XCTAssertFalse(result); XCTAssertEqual(host.presentations, 0); XCTAssertTrue(completions.isEmpty)
    }
    func testUnavailableEmailCanBeRequestedAgainWithoutLeavingComposerStateBusy() {
        XCTAssertFalse(MFMailComposeViewController.canSendMail())
        let host = PresentationMailHost(), route = PresentationMailRoute()
        XCTAssertFalse(route.writeEmail(with: SocialMessage(), from: host, completionHandler: nil))
        XCTAssertFalse(route.writeEmail(with: SocialMessage(subject: "Another request"), from: host, completionHandler: nil))
        XCTAssertEqual(host.presentations, 0)
    }
}

private struct PresentationMailRoute: EmailPresentable {}
private final class PresentationMailHost: UIViewController, ControllerBackedProtocol {
    var presentations = 0
    override func present(_ viewControllerToPresent: UIViewController, animated: Bool, completion: (() -> Void)? = nil) { presentations += 1; completion?() }
}

@MainActor
final class PreservedWalletReturnUICoverageTests: RootActionFixtureTests {
    private var fixtures = [PreservedReturnFixture]()
    override func tearDown() async throws {
        try await super.tearDown()
        for fixture in fixtures { try? FileManager.default.removeItem(at: fixture.directory) }
        fixtures = []
    }
    private func make() throws -> PreservedReturnFixture { let f = try PreservedReturnFixture(); fixtures.append(f); return f }
    private func open(_ f: PreservedReturnFixture, done: @escaping () -> Void = {}) -> UIViewController {
        let controller = UIViewController(); mount(controller)
        WalletPreservedDataRestoration.present(on: controller, onRestored: done, environment: f.environment)
        return controller
    }
    private func prompt(_ c: UIViewController, title: String) async throws -> UIAlertController {
        await wait { (c.presentedViewController as? UIAlertController)?.title == title }
        return try alert(c)
    }
    private func choosePIN(_ c: UIViewController, pin: String = "2468", confirmation: String? = nil) async throws {
        let a = try await prompt(c, title: "Protect the returned wallets")
        a.textFields?.first?.text = pin; a.textFields?.last?.text = confirmation ?? pin
        try await choose("Use earlier wallet data", c)
    }
    func testMissingPathsLeaveTheScreenInteractiveAndDoNotRestore() throws {
        let c = UIViewController(); mount(c); let f = try make(); var environment = f.environment
        environment.paths = { throw RecoveryPresentationFailure.unavailable }
        WalletPreservedDataRestoration.present(on: c, onRestored: { XCTFail("No paths") }, environment: environment)
        XCTAssertTrue(c.view.isUserInteractionEnabled); XCTAssertNil(c.presentedViewController)
    }
    func testNoPreservedGenerationRestoresInteractionWithoutPresentingAChoice() async throws {
        let f = try make(), c = open(f); await wait { c.view.isUserInteractionEnabled }
        XCTAssertNil(c.presentedViewController); XCTAssertFalse(FileManager.default.fileExists(atPath: f.paths.storeURL.path))
    }
    func testOneGenerationWithoutDeviceKeysAsksForANewAppPin() async throws {
        let f = try make(); _ = try f.preserve([f.account()]); let c = open(f)
        let a = try await prompt(c, title: "Protect the returned wallets")
        XCTAssertEqual(a.textFields?.count, 2); XCTAssertTrue(a.textFields?.allSatisfy(\.isSecureTextEntry) == true)
        XCTAssertEqual(a.textFields?.map(\.keyboardType), [.numberPad, .numberPad])
    }
    func testReturningAReadOnlyGenerationMovesTheExactDatabaseAndSetsTheChosenPin() async throws {
        let f = try make(); let account = try f.account(); let folder = try f.preserve([account])
        let before = try Data(contentsOf: folder.appendingPathComponent("CoreData/" + f.paths.storeURL.lastPathComponent))
        var restored = 0; let c = open(f) { restored += 1 }; try await choosePIN(c)
        await wait { restored == 1 }; XCTAssertTrue(c.view.isUserInteractionEnabled)
        XCTAssertEqual(try Data(contentsOf: f.paths.storeURL), before)
        XCTAssertEqual(try f.keys.fetchKey(for: KeystoreTag.pincode.rawValue), Data("2468".utf8))
        XCTAssertEqual(try f.rows().map(\.address), [account.address])
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("CoreData/" + f.paths.storeURL.lastPathComponent).path))
    }
    func testMismatchedNewPinsKeepTheGenerationAndExplainTheFailure() async throws {
        let f = try make(); let folder = try f.preserve([f.account()]); var restored = 0
        let c = open(f) { restored += 1 }; try await choosePIN(c, pin: "2468", confirmation: "1357")
        _ = try await prompt(c, title: "Earlier wallet data not opened")
        XCTAssertEqual(restored, 0); XCTAssertFalse(FileManager.default.fileExists(atPath: f.paths.storeURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("CoreData/" + f.paths.storeURL.lastPathComponent).path))
        XCTAssertFalse(try f.keys.checkKey(for: KeystoreTag.pincode.rawValue))
    }
    func testInvalidNewPinDoesNotMoveAnyFiles() async throws {
        let f = try make(); _ = try f.preserve([f.account()]); let c = open(f)
        try await choosePIN(c, pin: "x"); _ = try await prompt(c, title: "Earlier wallet data not opened")
        XCTAssertFalse(FileManager.default.fileExists(atPath: f.paths.storeURL.path)); XCTAssertTrue(c.view.isUserInteractionEnabled)
    }
    func testCancellingNewPinSelectionLeavesTheGenerationAvailable() async throws {
        let f = try make(); let folder = try f.preserve([f.account()]); let c = open(f)
        _ = try await prompt(c, title: "Protect the returned wallets"); try await choose("Cancel", c)
        XCTAssertEqual(WalletPreservedGeneration.available(paths: f.paths, settings: f.settings), [folder])
        XCTAssertFalse(try f.keys.checkKey(for: KeystoreTag.pincode.rawValue))
    }
    func testMultipleGenerationsRequireAnExplicitFolderChoice() async throws {
        let f = try make(); _ = try f.preserve([f.account(1)]); _ = try f.preserve([f.account(2)])
        let c = open(f); let a = try await prompt(c, title: "Use the earlier wallet data again")
        XCTAssertEqual(a.actions.map(\.title), ["Saved wallet data 1", "Saved wallet data 2", "Cancel"])
        XCTAssertEqual(a.preferredStyle, .actionSheet); XCTAssertNotNil(a.popoverPresentationController?.sourceView)
        try await choose("Saved wallet data 2", c); _ = try await prompt(c, title: "Protect the returned wallets")
    }
    func testRetainedKeysWithoutAnOwnerBindingRequireTheOriginalBackup() async throws {
        let f = try make(); let account = try f.account(); _ = try f.preserve([account])
        try f.keys.saveKey(Data(repeating: 3, count: 32), with: KeystoreTag.seedTagForAddress(account.address))
        let c = open(f); let a = try await prompt(c, title: "Earlier wallet data not opened")
        XCTAssertTrue(a.message?.contains("without an ownership PIN") == true)
        XCTAssertFalse(FileManager.default.fileExists(atPath: f.paths.storeURL.path))
    }
    func testRetainedKeysRequireTheirOwnerPinBeforeNewPinSelection() async throws {
        let f = try make(); let account = try f.account(); _ = try f.preserve([account]); try f.bind(account, pin: "1357")
        let c = open(f); let a = try await prompt(c, title: "Enter your PIN")
        XCTAssertTrue(a.message?.contains("protected these wallets") == true)
        a.textFields?.first?.text = "1357"; try await choose("Continue", c)
        _ = try await prompt(c, title: "Protect the returned wallets")
        XCTAssertTrue((a.textFields?.first?.text ?? "").isEmpty)
    }
    func testWrongOwnerPinCannotReachFileReturn() async throws {
        let f = try make(); let account = try f.account(); _ = try f.preserve([account]); try f.bind(account, pin: "1357")
        let c = open(f); let a = try await prompt(c, title: "Enter your PIN")
        a.textFields?.first?.text = "9999"; try await choose("Continue", c)
        let failure = try await prompt(c, title: "Earlier wallet data not opened")
        XCTAssertTrue(failure.message?.contains("PIN is not correct") == true)
        XCTAssertFalse(FileManager.default.fileExists(atPath: f.paths.storeURL.path)); XCTAssertTrue(c.view.isUserInteractionEnabled)
    }
    func testDifferentRetainedOwnersRequireEachPinBeforeReturningTheGeneration() async throws {
        let f = try make(); let a = try f.account(1), b = try f.account(2); _ = try f.preserve([a,b])
        try f.bind(a, pin: "1357"); try f.bind(b, pin: "2468"); let c = open(f)
        var prompt = try await self.prompt(c, title: "Enter your PIN"); prompt.textFields?.first?.text = "1357"; try await choose("Continue", c)
        prompt = try await self.prompt(c, title: "Enter your PIN"); prompt.textFields?.first?.text = "2468"; try await choose("Continue", c)
        _ = try await self.prompt(c, title: "Protect the returned wallets")
    }
    func testVerifiedOwnerReturnsTheWalletAndChangesOnlyPinProtection() async throws {
        let f = try make(); let account = try f.realAccount(); _ = try f.preserve([account])
        try f.keys.saveKey(JSONEncoder().encode(WalletOwnerPIN.Binding(pin: "1357")), with: account.address + WalletOwnerPIN.bindingSuffix)
        let before = try f.keys.fetchKey(for: KeystoreTag.secretKeyTagForAddress(account.address))
        var restored = 0; let c = open(f) { restored += 1 }
        let ownerPrompt = try await prompt(c, title: "Enter your PIN"); ownerPrompt.textFields?.first?.text = "1357"
        try await choose("Continue", c); try await choosePIN(c, pin: "2468")
        await wait { restored == 1 }
        XCTAssertEqual(try f.rows().map(\.address), [account.address])
        XCTAssertEqual(try f.keys.fetchKey(for: KeystoreTag.secretKeyTagForAddress(account.address)), before)
        XCTAssertEqual(try WalletOwnerPIN(keystore: f.keys, settings: f.settings, recoveryGate: f.gate).verifyRetained("2468", addresses: [account.address]), [account.address])
    }
    func testFileChangedAfterPinPromptFailsClosedWithoutMovingTheCorruptGeneration() async throws {
        let f = try make(); let folder = try f.preserve([f.account()]); let c = open(f)
        _ = try await prompt(c, title: "Protect the returned wallets")
        try Data("modified fixture database".utf8).write(to: folder.appendingPathComponent("CoreData/" + f.paths.storeURL.lastPathComponent))
        try await choosePIN(c); let a = try await prompt(c, title: "Earlier wallet data not opened")
        XCTAssertTrue(a.message?.contains("could not be returned safely") == true)
        XCTAssertFalse(FileManager.default.fileExists(atPath: f.paths.storeURL.path)); XCTAssertTrue(c.view.isUserInteractionEnabled)
    }
    func testLiveWalletAppearingAfterPinPromptIsNeverOverwritten() async throws {
        let f = try make(); _ = try f.preserve([f.account()]); let c = open(f)
        _ = try await prompt(c, title: "Protect the returned wallets")
        let live = Data("other wallet appeared".utf8); try live.write(to: f.paths.storeURL)
        try await choosePIN(c); _ = try await prompt(c, title: "Earlier wallet data not opened")
        XCTAssertEqual(try Data(contentsOf: f.paths.storeURL), live)
    }
}

private final class PreservedReturnFixture {
    let directory: URL, paths: WalletLocalStateSetAside.Paths
    let keys = InMemoryKeychain(), settings = InMemorySettingsManager()
    lazy var gate = WalletRecoveryCapabilityGate(settings: settings, unresolvedMigrationJournal: { false }, unresolvedWalletCommitJournal: { false })
    lazy var coordinator = WalletLifecycleCoordinator(recoveryGate: gate)
    var environment: WalletPreservedRestoreEnvironment { .init(paths: { self.paths }, settings: settings, keystore: keys, recoveryGate: gate, lifecycleCoordinator: coordinator) }
    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("preserved-return-ui-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        paths = .init(storeURL: directory.appendingPathComponent("wallet.sqlite"), applicationSupportURL: directory, setAsideRootURL: directory.appendingPathComponent("WalletSetAside"))
    }
    func account(_ byte: UInt8 = 4) throws -> AccountItem {
        let publicKey = Data(repeating: byte, count: 32), network = SoraPassport.Chain.sora.addressType()
        return AccountItem(address: try SS58AddressFactory().addressFromAccountId(data: publicKey, type: network), cryptoType: .sr25519, networkType: network, username: "Public fixture", publicKeyData: publicKey, settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: Int16(byte), isSelected: false)
    }
    func realAccount() throws -> AccountItem {
        let mnemonic = try IRMnemonicCreator(language: .english).mnemonic(fromEntropy: Data(repeating: 8, count: 16))
        let operation = AccountOperationFactory(keystore: keys, recoveryGate: gate).prepareAccountOperation(
            request: AccountCreationRequest(username: "Public fixture", type: .sora, derivationPath: "", cryptoType: .sr25519), mnemonic: mnemonic)
        operation.start()
        let prepared = try XCTUnwrap(operation.result).get(); try prepared.persist(to: keys)
        return prepared.account
    }
    func bind(_ account: AccountItem, pin: String) throws {
        try keys.saveKey(Data(repeating: 3, count: 32), with: KeystoreTag.seedTagForAddress(account.address))
        try keys.saveKey(JSONEncoder().encode(WalletOwnerPIN.Binding(pin: pin)), with: account.address + WalletOwnerPIN.bindingSuffix)
    }
    func model() throws -> NSManagedObjectModel {
        let name = UserStorageVersion.version2.rawValue
        let url = Bundle.main.url(forResource: name, withExtension: "omo", subdirectory: UserStorageParams.modelDirectory) ?? Bundle.main.url(forResource: name, withExtension: "mom", subdirectory: UserStorageParams.modelDirectory)
        return try XCTUnwrap(NSManagedObjectModel(contentsOf: XCTUnwrap(url)))
    }
    func preserve(_ accounts: [AccountItem]) throws -> URL {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: try model())
        let store = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: paths.storeURL, options: nil)
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType); context.persistentStoreCoordinator = coordinator
        try context.performAndWait {
            for a in accounts {
                let row = NSEntityDescription.insertNewObject(forEntityName: "CDAccountItem", into: context)
                row.setValue(a.address, forKey: "identifier"); row.setValue(a.username, forKey: "username"); row.setValue(a.publicKeyData, forKey: "publicKey")
                row.setValue(a.cryptoType.rawValue, forKey: "cryptoType"); row.setValue(a.networkType, forKey: "networkType"); row.setValue(a.order, forKey: "order"); row.setValue(a.isSelected, forKey: "isSelected")
            }
            try context.save()
        }
        try coordinator.remove(store)
        return try WalletLocalStateSetAside.setAside(settings: settings, expectedMarker: nil, paths: paths, lifecycleCoordinator: self.coordinator)
    }
    func rows() throws -> [AccountItem] {
        try UserStorageMigrator(targetVersion: UserStorageParams.modelVersion, storeURL: paths.storeURL, modelDirectory: UserStorageParams.modelDirectory, keystore: keys, settings: settings, fileManager: .default).preservedAccountInventory()
    }
}

@MainActor
final class RetainedWalletRestoreLifecycleTests: RootActionFixtureTests {
    private enum Failure: Error { case injected }
    private final class Fixture {
        let keys = RetainedFlowKeychain(), settings = InMemorySettingsManager()
        let storage = UserDataStorageTestFacade(), queue = OperationQueue()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("retained-ui-" + UUID().uuidString)
        lazy var gate = WalletRecoveryCapabilityGate(settings: settings,
            unresolvedMigrationJournal: { false }, unresolvedWalletCommitJournal: { false })
        lazy var coordinator = WalletLifecycleCoordinator(recoveryGate: gate)
        lazy var selection = SelectedWalletSettings(storageFacade: storage, operationQueue: queue, legacySettings: settings,
            walletAccountCommitJournalStoreFactory: { [unowned self] in try WalletAccountCommitJournalStore(baseURL: self.directory, recoveryGate: self.gate) },
            lifecycleCoordinator: coordinator, recoveryGate: gate, keystore: keys)
        lazy var insert = RetainedFlowSelection(base: selection)
        var reads = 0, failReads = Set<Int>()
        var readOverride: ((Int, [AccountItem]) throws -> [AccountItem])?
        var busy = [Bool](), outcomes = [WalletRetainedWalletRestoreFlow.Outcome]()
        deinit { queue.waitUntilAllOperationsAreFinished(); try? storage.databaseService.close(); try? FileManager.default.removeItem(at: directory) }
        var environment: WalletRetainedRestoreEnvironment {
            WalletRetainedRestoreEnvironment(keystore: keys, settings: settings, accounts: { [unowned self] in
                self.reads += 1
                if self.failReads.contains(self.reads) { throw Failure.injected }
                let rows = try self.rows()
                return try self.readOverride?(self.reads, rows) ?? rows
            }, selectedWalletSettings: insert, recoveryGate: gate, lifecycleCoordinator: coordinator)
        }
        func rows() throws -> [AccountItem] { try WalletAccountAddresses.accounts(storageFacade: storage) }
        func prepared(_ byte: UInt8) throws -> PreparedAccount {
            let phrase = try IRMnemonicCreator(language: .english).mnemonic(fromEntropy: Data(repeating: byte, count: 16))
            let operation = AccountOperationFactory(keystore: keys, recoveryGate: gate).prepareAccountOperation(
                request: AccountCreationRequest(username: "Public retained fixture", type: .sora, derivationPath: "", cryptoType: .sr25519), mnemonic: phrase)
            operation.start(); return try XCTUnwrap(operation.result).get()
        }
        func retained(_ byte: UInt8 = 0x31, pin: String = "111111") throws -> AccountItem {
            let prepared = try prepared(byte); try prepared.persist(to: keys)
            try keys.saveKey(JSONEncoder().encode(WalletOwnerPIN.Binding(pin: pin)), with: prepared.account.address + WalletOwnerPIN.bindingSuffix)
            return prepared.account
        }
        func current(_ byte: UInt8 = 0x41, pin: String = "222222") async throws -> AccountItem {
            let prepared = try prepared(byte), lease = coordinator.acquire()
            defer { lease.release() }
            let account: AccountItem = try await withCheckedThrowingContinuation { continuation in
                selection.performInsertAndSelect(prepared: prepared, persistSecrets: { try prepared.persist(to: self.keys) }, lifecycleLease: lease) {
                    continuation.resume(with: $0)
                }
            }
            try owner.setInitialPIN(pin, accounts: rows())
            return account
        }
        var owner: WalletOwnerPIN { WalletOwnerPIN(keystore: keys, settings: settings, recoveryGate: gate) }
    }
    private func begin(_ f: Fixture, scope: WalletRetainedPinGate.Scope = .welcomeBack) -> UIViewController {
        let host = UIViewController(); mount(host)
        WalletRetainedWalletRestoreFlow.run(on: host, scope: scope, setBusy: { f.busy.append($0) }, completion: { f.outcomes.append($0) }, environment: f.environment)
        return host
    }
    private func enter(_ pin: String, on host: UIViewController) async throws {
        try XCTUnwrap(alert(host).textFields?.first).text = pin
        try await choose("Continue", host)
    }
    private func awaitPINPrompt(_ host: UIViewController) async throws {
        let deadline = Date().addingTimeInterval(10)
        while !(host.presentedViewController is UIAlertController) && Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        _ = try alert(host)
    }
    private func completed(_ f: Fixture) async throws -> WalletRetainedWalletRestoreFlow.Outcome {
        let deadline = Date().addingTimeInterval(10)
        while f.outcomes.isEmpty && Date() < deadline { try? await Task.sleep(nanoseconds: 20_000_000) }
        return try XCTUnwrap(f.outcomes.last)
    }
    private func restored(_ outcome: WalletRetainedWalletRestoreFlow.Outcome, count: Int, failed: Int = 0, file: StaticString = #filePath, line: UInt = #line) {
        guard case let .restored(actual, failures) = outcome else { return XCTFail("Expected restored result: \(outcome)", file: file, line: line) }
        XCTAssertEqual(actual, count, file: file, line: line); XCTAssertEqual(failures, failed, file: file, line: line)
    }
    private func nothing(_ outcome: WalletRetainedWalletRestoreFlow.Outcome, file: StaticString = #filePath, line: UInt = #line) {
        guard case let .nothingRestored(message) = outcome else { return XCTFail("Expected safe failure: \(outcome)", file: file, line: line) }
        XCTAssertFalse(message.isEmpty, file: file, line: line)
    }
    func testWelcomeBackCancellationDoesNotReadOrModifyStoredWallets() async throws {
        let f = Fixture(); let host = begin(f)
        XCTAssertTrue(try alert(host).message?.contains("Only wallets owned by that PIN") == true)
        try await choose("Cancel", host)
        XCTAssertTrue(f.busy.isEmpty); XCTAssertTrue(f.outcomes.isEmpty); XCTAssertEqual(f.reads, 0)
        XCTAssertTrue(try f.keys.allKeyIdentifiers().isEmpty); XCTAssertTrue(try f.rows().isEmpty)
    }
    func testWrongOwnerPINCannotInsertRowsOrChangeTheWalletBinding() async throws {
        let f = Fixture(); let account = try f.retained(); let binding = try f.keys.fetchKey(for: account.address + WalletOwnerPIN.bindingSuffix)
        let host = begin(f); try await enter("999999", on: host)
        nothing(try await completed(f)); XCTAssertEqual(f.busy, [true, false])
        XCTAssertTrue(try f.rows().isEmpty); XCTAssertEqual(try f.keys.fetchKey(for: account.address + WalletOwnerPIN.bindingSuffix), binding)
        XCTAssertFalse(try f.keys.checkKey(for: KeystoreTag.pincode.rawValue))
    }
    func testUnreadableCurrentAccountInventoryStopsBeforeDiscoveryOrInsert() async throws {
        let f = Fixture(); f.failReads = [1]; let host = begin(f); try await enter("111111", on: host)
        nothing(try await completed(f)); XCTAssertEqual(f.reads, 1); XCTAssertTrue(f.insert.attempted.isEmpty)
        XCTAssertEqual(f.busy, [true, false])
    }
    func testEmptyKeyInventoryCannotInventARestoredWallet() async throws {
        let f = Fixture(); let host = begin(f); try await enter("111111", on: host)
        nothing(try await completed(f)); XCTAssertTrue(try f.rows().isEmpty); XCTAssertTrue(f.insert.attempted.isEmpty)
    }
    func testWelcomeBackRestoresAProvenWalletThroughTheJournalAndSetsItsPIN() async throws {
        let f = Fixture(); let account = try f.retained(); let original = try f.keys.fetchSecretKeyForAddress(account.address)
        let host = begin(f); try await enter("111111", on: host)
        restored(try await completed(f), count: 1)
        XCTAssertEqual(try f.rows().map(\.address), [account.address]); XCTAssertEqual(f.selection.currentAccount?.address, account.address)
        XCTAssertEqual(try f.keys.fetchKey(for: KeystoreTag.pincode.rawValue), Data("111111".utf8))
        XCTAssertEqual(try f.keys.fetchSecretKeyForAddress(account.address), original)
        XCTAssertNoThrow(try f.owner.authenticateCurrent("111111", accounts: f.rows()))
        XCTAssertEqual(f.busy, [true, false, true, false])
    }
    func testWelcomeBackRestoresOnlyWalletsOwnedByTheSubmittedPIN() async throws {
        let f = Fixture(); let own = try f.retained(); let other = try f.retained(0x32, pin: "333333")
        let original = try f.keys.fetchKey(for: other.address + WalletOwnerPIN.bindingSuffix)
        let host = begin(f); try await enter("111111", on: host)
        restored(try await completed(f), count: 1)
        XCTAssertEqual(try f.rows().map(\.address), [own.address]); XCTAssertEqual(f.insert.attempted, [own.address])
        XCTAssertEqual(try f.keys.fetchKey(for: other.address + WalletOwnerPIN.bindingSuffix), original)
    }
    func testOneFailedInsertDoesNotUndoAnotherVerifiedWallet() async throws {
        let f = Fixture(); let one = try f.retained(); let two = try f.retained(0x32)
        f.insert.rejected = [two.address]
        let host = begin(f); try await enter("111111", on: host)
        restored(try await completed(f), count: 1, failed: 1)
        XCTAssertEqual(try f.rows().map(\.address), [one.address])
        XCTAssertEqual(Set(f.insert.attempted), [one.address, two.address])
        XCTAssertTrue(try f.keys.checkKey(for: KeystoreTag.secretKeyTagForAddress(two.address)))
    }
    func testEveryFailedInsertReturnsSafeFailureWithoutSettingAnAppPIN() async throws {
        let f = Fixture(); let account = try f.retained(); f.insert.rejected = [account.address]
        let host = begin(f); try await enter("111111", on: host)
        nothing(try await completed(f)); XCTAssertTrue(try f.rows().isEmpty)
        XCTAssertFalse(try f.keys.checkKey(for: KeystoreTag.pincode.rawValue)); XCTAssertEqual(f.busy.last, false)
    }
    func testEstablishedInstallationCannotUseWelcomeBackToReplaceItsPIN() async throws {
        let f = Fixture(); let current = try await f.current(); _ = try f.retained()
        let host = begin(f); try await enter("111111", on: host)
        nothing(try await completed(f)); XCTAssertEqual(try f.rows().map(\.address), [current.address])
        XCTAssertTrue(f.insert.attempted.isEmpty); XCTAssertEqual(try f.keys.fetchKey(for: KeystoreTag.pincode.rawValue), Data("222222".utf8))
    }
    func testAfterSetupRequiresTheCurrentAppPINBeforeImportingTheRetainedWallet() async throws {
        let f = Fixture(); let current = try await f.current(); let retained = try f.retained()
        let host = begin(f, scope: .afterSetup); try await enter("111111", on: host)
        try await awaitPINPrompt(host)
        XCTAssertTrue(try alert(host).message?.contains("this app's PIN") == true)
        XCTAssertTrue(f.insert.attempted.isEmpty); XCTAssertEqual(try f.rows().map(\.address), [current.address])
        try await enter("222222", on: host); restored(try await completed(f), count: 1)
        XCTAssertEqual(Set(try f.rows().map(\.address)), [current.address, retained.address])
        XCTAssertEqual(try f.owner.verifyRetained("222222", addresses: [retained.address]), [retained.address])
        XCTAssertEqual(try f.keys.fetchKey(for: KeystoreTag.pincode.rawValue), Data("222222".utf8))
    }
    func testWrongCurrentAppPINDoesNotRebindTheRetainedWallet() async throws {
        let f = Fixture(); let current = try await f.current(); let retained = try f.retained()
        let binding = try f.keys.fetchKey(for: retained.address + WalletOwnerPIN.bindingSuffix)
        let host = begin(f, scope: .afterSetup); try await enter("111111", on: host)
        try await awaitPINPrompt(host); try await enter("444444", on: host)
        nothing(try await completed(f)); XCTAssertEqual(try f.rows().map(\.address), [current.address])
        XCTAssertEqual(try f.keys.fetchKey(for: retained.address + WalletOwnerPIN.bindingSuffix), binding)
        XCTAssertTrue(f.insert.attempted.isEmpty)
    }
    func testCancellingCurrentPINLeavesOwnershipAndSelectionUnchanged() async throws {
        let f = Fixture(); let current = try await f.current(); let retained = try f.retained()
        let binding = try f.keys.fetchKey(for: retained.address + WalletOwnerPIN.bindingSuffix)
        let host = begin(f, scope: .afterSetup); try await enter("111111", on: host)
        try await awaitPINPrompt(host); try await choose("Cancel", host)
        XCTAssertTrue(f.outcomes.isEmpty); XCTAssertEqual(f.busy, [true, false])
        XCTAssertEqual(try f.rows().map(\.address), [current.address]); XCTAssertEqual(f.selection.currentAccount?.address, current.address)
        XCTAssertEqual(try f.keys.fetchKey(for: retained.address + WalletOwnerPIN.bindingSuffix), binding)
    }
    func testAccountReadFailureAfterOwnerProofCannotStartInsertion() async throws {
        let f = Fixture(); _ = try f.retained(); f.failReads = [2]
        let host = begin(f); try await enter("111111", on: host)
        nothing(try await completed(f)); XCTAssertTrue(f.insert.attempted.isEmpty); XCTAssertTrue(try f.rows().isEmpty)
        XCTAssertEqual(f.busy, [true, false, true, false])
    }
    func testCommittedWalletSurvivesAnInterruptedInitialPINWrite() async throws {
        let f = Fixture(); let account = try f.retained(); f.keys.failWriteTag = KeystoreTag.pincode.rawValue
        let host = begin(f); try await enter("111111", on: host)
        let outcome = try await completed(f)
        guard case let .setupRequired(count, message) = outcome else { return XCTFail("Committed row needs PIN setup: \(outcome)") }
        XCTAssertEqual(count, 1); XCTAssertTrue(message.contains("saved"))
        XCTAssertEqual(try f.rows().map(\.address), [account.address]); XCTAssertTrue(try f.keys.checkKey(for: KeystoreTag.secretKeyTagForAddress(account.address)))
    }
    func testPostCommitInventoryFailureReportsSavedWalletsInsteadOfDiscardingThem() async throws {
        let f = Fixture(); let account = try f.retained(); f.failReads = [3]
        let host = begin(f); try await enter("111111", on: host)
        let outcome = try await completed(f)
        guard case let .setupRequired(count, _) = outcome else { return XCTFail("Verified row was not reconciled: \(outcome)") }
        XCTAssertEqual(count, 1); XCTAssertEqual(try f.rows().map(\.address), [account.address])
    }
    func testAfterSetupPostCommitReadFailureKeepsTheNewRowAndReportsProtectionRetry() async throws {
        let f = Fixture(); let current = try await f.current(); let retained = try f.retained(); f.failReads = [4]
        let host = begin(f, scope: .afterSetup); try await enter("111111", on: host)
        try await awaitPINPrompt(host); try await enter("222222", on: host)
        let outcome = try await completed(f)
        guard case let .nothingRestored(message) = outcome else { return XCTFail("Expected a protection retry: \(outcome)") }
        XCTAssertTrue(message.contains("saved")); XCTAssertEqual(Set(try f.rows().map(\.address)), [current.address, retained.address])
    }
    func testSetUpAgainRequiresBothExplicitConfirmations() async throws {
        let host = UIViewController(); mount(host); var confirms = 0
        WalletSetUpAgainConfirmation.present(on: host, movesWalletData: true) { confirms += 1 }
        XCTAssertTrue(try alert(host).message?.contains("separate folder") == true)
        try await choose("Continue", host); XCTAssertEqual(confirms, 0)
        XCTAssertEqual(try alert(host).title, "Start fresh?"); try await choose("Set up again", host)
        XCTAssertEqual(confirms, 1)
    }
    func testSecondSetUpAgainCancellationDoesNotContinue() async throws {
        let host = UIViewController(); mount(host); var confirms = 0
        WalletSetUpAgainConfirmation.present(on: host, movesWalletData: false) { confirms += 1 }
        XCTAssertFalse(try alert(host).message?.contains("separate folder") == true)
        try await choose("Continue", host); try await choose("Cancel", host); XCTAssertEqual(confirms, 0)
    }
}

private enum RetainedFlowFailure: Error { case rejected }
private final class RetainedFlowKeychain: KeystoreProtocol {
    private let base = InMemoryKeychain(), lock = NSRecursiveLock()
    var failWriteTag: String?
    func addKey(_ key: Data, with identifier: String) throws { lock.lock(); defer { lock.unlock() }; if identifier == failWriteTag { throw RetainedFlowFailure.rejected }; try base.addKey(key, with: identifier) }
    func updateKey(_ key: Data, with identifier: String) throws { try addKey(key, with: identifier) }
    func fetchKey(for identifier: String) throws -> Data { lock.lock(); defer { lock.unlock() }; return try base.fetchKey(for: identifier) }
    func checkKey(for identifier: String) throws -> Bool { lock.lock(); defer { lock.unlock() }; return try base.checkKey(for: identifier) }
    func allKeyIdentifiers() throws -> [String] { lock.lock(); defer { lock.unlock() }; return try base.allKeyIdentifiers() }
    func deleteKey(for identifier: String) throws { lock.lock(); defer { lock.unlock() }; try base.deleteKey(for: identifier) }
}
private final class RetainedFlowSelection: SelectedWalletSettingsProtocol {
    let base: SelectedWalletSettingsProtocol
    var rejected = Set<String>(), attempted = [String]()
    init(base: SelectedWalletSettingsProtocol) { self.base = base }
    var currentAccount: AccountItem? { base.currentAccount }
    func performInsertAndSelect(prepared: PreparedAccount, persistSecrets: @escaping () throws -> Void, lifecycleLease: WalletLifecycleLease, completionClosure: @escaping (Result<AccountItem, Error>) -> Void) {
        attempted.append(prepared.account.address)
        if rejected.contains(prepared.account.address) { completionClosure(.failure(RetainedFlowFailure.rejected)); return }
        base.performInsertAndSelect(prepared: prepared, persistSecrets: persistSecrets, lifecycleLease: lifecycleLease, completionClosure: completionClosure)
    }
    func performSave(value: AccountItem, completionClosure: @escaping (Result<AccountItem, Error>) -> Void) { base.performSave(value: value, completionClosure: completionClosure) }
    func performSelectAfterRemoval(value: AccountItem, lifecycleLease: WalletLifecycleLease, completionClosure: @escaping (Result<AccountItem, Error>) -> Void) { base.performSelectAfterRemoval(value: value, lifecycleLease: lifecycleLease, completionClosure: completionClosure) }
    func performUpdateName(account: AccountItem, displayName: String, completionClosure: @escaping (Result<AccountItem, Error>) -> Void) { base.performUpdateName(account: account, displayName: displayName, completionClosure: completionClosure) }
    func performUpdateAssetSettings(account: AccountItem, settings: AccountSettings, completionClosure: @escaping (Result<AccountItem, Error>) -> Void) { base.performUpdateAssetSettings(account: account, settings: settings, completionClosure: completionClosure) }
    func performSetup(completionClosure: @escaping (Result<AccountItem?, Error>) -> Void) { base.performSetup(completionClosure: completionClosure) }
    func save(value: AccountItem) { base.save(value: value) }
}

extension RootRecoveryActionCoverageTests {
    func testExistingUnverifiedCredentialsOpenTheRepairScreenForTheExactAccount() async throws {
        let retained = account("existing")
        let c = await openRecovery { actions in
            actions.accounts = { [retained] }
            actions.prepareKeys = { _ in
                (WalletCredentialRepair(keystore: InMemoryKeychain(), settings: InMemorySettingsManager()), false)
            }
            actions.inventory = { [retained] }
        }
        try tap("wallet-recovery-restore-keys", c)
        await wait { c.presentedViewController is UINavigationController }
        let navigation = try XCTUnwrap(c.presentedViewController as? UINavigationController)
        let repair = try XCTUnwrap(navigation.viewControllers.first as? WalletCredentialRepairViewController)
        repair.loadViewIfNeeded()
        XCTAssertEqual(all(UILabel.self, repair.view).first { $0.accessibilityIdentifier == "wallet-repair-address" }?.text, retained.address)
        XCTAssertTrue(try button("wallet-repair-source-0", repair).accessibilityTraits.contains(.selected))
        XCTAssertTrue(try button("wallet-recovery-retry", c).isEnabled)
    }
    func testExistingUnverifiedCloudCredentialsOpenRepairWithDriveSelected() async throws {
        let retained = account("cloud")
        let c = await openRecovery { actions in
            actions.accounts = { [retained] }
            actions.prepareKeys = { _ in
                (WalletCredentialRepair(keystore: InMemoryKeychain(), settings: InMemorySettingsManager()), false)
            }
            actions.inventory = { [retained] }
            actions.readBackup = { _, _ in XCTFail("Conflict repair must wait for explicit Drive authorization"); return Data() }
        }
        try tap("wallet-recovery-restore-cloud-backup", c)
        await wait { c.presentedViewController is UINavigationController }
        let navigation = try XCTUnwrap(c.presentedViewController as? UINavigationController)
        let repair = try XCTUnwrap(navigation.viewControllers.first as? WalletCredentialRepairViewController)
        repair.loadViewIfNeeded()
        XCTAssertTrue(try button("wallet-repair-source-3", repair).accessibilityTraits.contains(.selected))
        XCTAssertTrue(all(UITextView.self, repair.view).first { $0.accessibilityIdentifier == "wallet-repair-material" }?.isHidden == true)
    }
}
