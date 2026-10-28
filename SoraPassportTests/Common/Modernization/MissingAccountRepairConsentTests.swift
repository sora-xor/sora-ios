// SPDX-License-Identifier: Apache-2.0
import Foundation
import IrohaCrypto
import SoraKeystore
import UIKit
import XCTest

@testable import SoraPassport

/// Checks the actual repair consent UI with public fixture keys in memory.
/// No repair action is approved and no app-global account store is read.
@MainActor
final class MissingAccountRepairConsentTests: XCTestCase {
  private var fixtures = [MissingRepairFixture]()
  private var priorWindow: UIWindow?
  override func setUp() {
    super.setUp()
    priorWindow = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(
      \.windows
    ).first { $0.isKeyWindow }
  }
  override func tearDown() {
    fixtures.forEach { $0.cleanup() }
    fixtures = []
    priorWindow?.makeKeyAndVisible()
    priorWindow = nil
    super.tearDown()
  }
  private func make(attached: Bool = true) throws -> MissingRepairFixture {
    let f = try MissingRepairFixture(attached: attached)
    fixtures.append(f)
    return f
  }
  private func settle(_ condition: @escaping () -> Bool) async throws {
    for _ in 0..<100 {
      if condition() { return }
      try await Task.sleep(nanoseconds: 10_000_000)
    }
    XCTFail("Repair consent did not settle")
  }
  private func present(existing: Bool = false) async throws -> MissingRepairFixture {
    let f = try make()
    if existing { f.loader.accounts = [f.prepared.account] }
    f.begin()
    try await settle { f.host.alert != nil }
    return f
  }
  func testACompatiblePreparedAccountDoesNotRequireCredentialReplacement() throws {
    let f = try make()
    XCTAssertFalse(try f.flow.requiresExplicitRepair(f.prepared))
    XCTAssertTrue(try f.keys.allKeyIdentifiers().isEmpty)
  }
  func testRetainedConflictingCredentialsRequireExplicitRepairWithoutWriting() throws {
    let f = try make()
    let tag = KeystoreTag.secretKeyTagForAddress(f.prepared.account.address)
    try f.keys.saveKey(Data([0xff]), with: tag)
    XCTAssertTrue(try f.flow.requiresExplicitRepair(f.prepared))
    XCTAssertEqual(try f.keys.fetchKey(for: tag), Data([0xff]))
  }
  func testAlreadyDiscardedPreparationIsNotTreatedAsARepairableConflict() throws {
    let f = try make()
    f.prepared.discard()
    XCTAssertThrowsError(try f.flow.requiresExplicitRepair(f.prepared))
  }
  func testDetachedControllerCancelsBeforeReadingAccounts() throws {
    let f = try make(attached: false)
    f.begin()
    XCTAssertEqual(f.results.count, 1)
    XCTAssertEqual(f.loader.reads, 0)
    XCTAssertThrowsError(try f.prepared.validatePersistence(to: f.keys))
  }
  func testControllerWithAnotherModalCancelsBeforeReadingAccounts() throws {
    let f = try make()
    f.host.reportedModal = UIViewController()
    f.begin()
    XCTAssertEqual(f.results.count, 1)
    XCTAssertEqual(f.loader.reads, 0)
  }
  func testEmptyInstallationRequestsTwoNewPinFields() async throws {
    let f = try await present()
    let alert = try XCTUnwrap(f.host.alert)
    XCTAssertEqual(alert.textFields?.count, 2)
    XCTAssertEqual(
      alert.textFields?.map(\.accessibilityIdentifier),
      ["wallet-import-repair-pin-0", "wallet-import-repair-pin-1"])
    XCTAssertTrue(alert.message?.contains(f.prepared.account.address) == true)
  }
  func testExistingWalletRequestsOnlyTheCurrentAppPin() async throws {
    let f = try await present(existing: true)
    let alert = try XCTUnwrap(f.host.alert)
    XCTAssertEqual(alert.textFields?.count, 1)
    XCTAssertEqual(alert.textFields?.first?.textContentType, .password)
  }
  func testNewPinFieldsUseSecureNumberPadAndNewPasswordSemantics() async throws {
    let f = try await present()
    let fields = try XCTUnwrap(f.host.alert?.textFields)
    for field in fields {
      XCTAssertTrue(field.isSecureTextEntry)
      XCTAssertEqual(field.keyboardType, .numberPad)
      XCTAssertEqual(field.textContentType, .newPassword)
    }
  }
  func testShowingConsentDoesNotPersistOrSelectThePreparedWallet() async throws {
    let f = try await present()
    XCTAssertTrue(f.results.isEmpty)
    XCTAssertTrue(try f.keys.allKeyIdentifiers().isEmpty)
    XCTAssertNil(f.selection.currentAccount)
    XCTAssertNoThrow(try f.prepared.validatePersistence(to: f.keys))
  }
  func testConsentContainsBothCancellationAndExplicitRepairActions() async throws {
    let f = try await present()
    let actions = try XCTUnwrap(f.host.alert?.actions)
    XCTAssertEqual(actions.count, 2)
    XCTAssertEqual(actions.filter { $0.style == .cancel }.count, 1)
    XCTAssertEqual(actions.filter { $0.style == .default }.count, 1)
  }
  func testBackgroundingCancelsConsentAndDiscardsPreparation() async throws {
    let f = try await present()
    NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
    try await settle { !f.results.isEmpty }
    XCTAssertTrue(try XCTUnwrap(f.results.first).failure is CancellationError)
    XCTAssertThrowsError(try f.prepared.validatePersistence(to: f.keys))
  }
  func testCaptureChangeCancelsConsentAndClearsEveryPinField() async throws {
    let f = try await present()
    let alert = try XCTUnwrap(f.host.alert)
    alert.textFields?.forEach { $0.text = "123456" }
    NotificationCenter.default.post(name: UIScreen.capturedDidChangeNotification, object: nil)
    try await settle { !f.results.isEmpty }
    XCTAssertTrue(alert.textFields?.allSatisfy { $0.text?.isEmpty != false } == true)
  }
  func testRepeatedPrivacyNotificationsCompleteOnlyOnce() async throws {
    let f = try await present()
    for name in [
      UIApplication.willResignActiveNotification, UIScreen.capturedDidChangeNotification,
      UIApplication.willResignActiveNotification,
    ] {
      NotificationCenter.default.post(name: name, object: nil)
    }
    try await settle { !f.results.isEmpty }
    try await Task.sleep(nanoseconds: 30_000_000)
    XCTAssertEqual(f.results.count, 1)
  }
  func testSecondBeginCannotReplaceAnUnansweredConsent() async throws {
    let f = try await present()
    let second = try f.newPrepared()
    var result: Result<AccountItem, Error>?
    f.flow.begin(second) { result = $0 }
    XCTAssertNotNil(result)
    XCTAssertTrue(f.results.isEmpty)
    XCTAssertThrowsError(try second.validatePersistence(to: f.keys))
    XCTAssertNoThrow(try f.prepared.validatePersistence(to: f.keys))
  }
  func testAReadFailureIsReturnedWithoutDisplayingAnEmptyInstallationPrompt() async throws {
    let f = try make()
    f.loader.failure = true
    f.begin()
    try await settle { !f.results.isEmpty }
    XCTAssertNil(f.host.alert)
    XCTAssertTrue(try XCTUnwrap(f.results.first).failure is MissingRepairFailure)
  }
  func testBackgroundingWhileAccountsLoadPreventsTheLatePrompt() async throws {
    let f = try make()
    f.loader.hold = true
    f.begin()
    try await settle { f.loader.reads == 1 }
    NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
    try await settle { !f.results.isEmpty }
    f.loader.release()
    try await Task.sleep(nanoseconds: 40_000_000)
    XCTAssertNil(f.host.alert)
    XCTAssertEqual(f.results.count, 1)
  }
  func testDetachedWindowDuringAccountReadCancelsTheLatePrompt() async throws {
    let f = try make()
    f.loader.hold = true
    f.begin()
    try await settle { f.loader.reads == 1 }
    f.window.rootViewController = nil
    f.loader.release()
    try await settle { !f.results.isEmpty }
    XCTAssertNil(f.host.alert)
  }
  func testNewModalDuringAccountReadPreventsOverlappingConsent() async throws {
    let f = try make()
    f.loader.hold = true
    f.begin()
    try await settle { f.loader.reads == 1 }
    f.host.reportedModal = UIViewController()
    f.loader.release()
    try await settle { !f.results.isEmpty }
    XCTAssertNil(f.host.alert)
  }
}
extension Result {
  fileprivate var failure: Failure? {
    if case .failure(let error) = self { return error }
    return nil
  }
}
private enum MissingRepairFailure: Error { case unavailable }
@MainActor
private final class MissingRepairFixture {
  let keys = InMemoryKeychain(), selection = MissingRepairSelection(), host = MissingRepairHost(),
    loader = MissingRepairLoader()
  let gate: WalletRecoveryCapabilityGate
  let window: UIWindow
  let prepared: PreparedAccount
  var results = [Result<AccountItem, Error>]()
  var flow: WalletMissingAccountRepairFlow!
  init(attached: Bool) throws {
    let gate = WalletRecoveryCapabilityGate(
      settings: InMemorySettingsManager(), unresolvedMigrationJournal: { false },
      unresolvedWalletCommitJournal: { false }, credentialRepairPending: { false })
    self.gate = gate
    prepared = try Self.prepare(keys: keys, gate: gate)
    let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    window = scene.map(UIWindow.init(windowScene:)) ?? UIWindow(frame: UIScreen.main.bounds)
    if attached {
      window.rootViewController = host
      window.makeKeyAndVisible()
      host.loadViewIfNeeded()
    }
    flow = WalletMissingAccountRepairFlow(
      controller: host, keystore: keys, selection: selection,
      loadAccounts: { [loader] in try loader.load() })
  }
  private static func prepare(keys: InMemoryKeychain, gate: WalletRecoveryCapabilityGate) throws
    -> PreparedAccount
  {
    let mnemonic = try IRMnemonicCreator(language: .english).mnemonic(
      fromList:
        "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    )
    let op = AccountOperationFactory(keystore: keys, recoveryGate: gate).prepareAccountOperation(
      request: AccountCreationRequest(
        username: "Public consent fixture", type: .sora, derivationPath: "//consent",
        cryptoType: .sr25519), mnemonic: mnemonic)
    op.start()
    return try XCTUnwrap(op.result).get()
  }
  func newPrepared() throws -> PreparedAccount { try Self.prepare(keys: keys, gate: gate) }
  func begin() { flow.begin(prepared) { [weak self] in self?.results.append($0) } }
  func cleanup() {
    NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
    loader.release()
    prepared.discard()
    window.isHidden = true
    window.rootViewController = nil
  }
}
private final class MissingRepairHost: UIViewController {
  var alert: UIAlertController?, reportedModal: UIViewController?
  override var presentedViewController: UIViewController? { reportedModal }
  override func present(
    _ controller: UIViewController, animated: Bool, completion: (() -> Void)? = nil
  ) {
    alert = controller as? UIAlertController
    completion?()
  }
}
private final class MissingRepairLoader {
  private let condition = NSCondition()
  private var count = 0
  var hold = false, failure = false
  var accounts = [AccountItem]()
  var reads: Int {
    condition.lock()
    defer { condition.unlock() }
    return count
  }
  func load() throws -> [AccountItem] {
    condition.lock()
    defer { condition.unlock() }
    count += 1
    while hold {
      if !condition.wait(until: Date().addingTimeInterval(4)) {
        throw MissingRepairFailure.unavailable
      }
    }
    if failure { throw MissingRepairFailure.unavailable }
    return accounts
  }
  func release() {
    condition.lock()
    hold = false
    condition.broadcast()
    condition.unlock()
  }
}

private final class MissingRepairSelection: SelectedWalletSettingsProtocol {
  struct Pending {
    let prepared: PreparedAccount
    let persist: () throws -> Void
    let lease: WalletLifecycleLease
    let completion: (Result<AccountItem, Error>) -> Void
  }
  var currentAccount: AccountItem?
  var pending = [Pending]()
  func performInsertAndSelect(
    prepared: PreparedAccount, persistSecrets: @escaping () throws -> Void,
    lifecycleLease: WalletLifecycleLease,
    completionClosure: @escaping (Result<AccountItem, Error>) -> Void
  ) {
    DispatchQueue.main.async {
      self.pending.append(
        Pending(
          prepared: prepared, persist: persistSecrets, lease: lifecycleLease,
          completion: completionClosure))
    }
  }
  func commit() throws {
    let next = pending.removeFirst()
    try next.persist()
    currentAccount = next.prepared.account
    next.completion(.success(next.prepared.account))
  }
  func fail() {
    let next = pending.removeFirst()
    next.prepared.discard()
    next.completion(.failure(MissingRepairFailure.unavailable))
  }
  func cancelPending() { while !pending.isEmpty { fail() } }
  func performSave(
    value: AccountItem, completionClosure: @escaping (Result<AccountItem, Error>) -> Void
  ) { XCTFail("Unexpected metadata save") }
  func performSelectAfterRemoval(
    value: AccountItem, lifecycleLease: WalletLifecycleLease,
    completionClosure: @escaping (Result<AccountItem, Error>) -> Void
  ) { XCTFail("Unexpected removal") }
  func performUpdateName(
    account: AccountItem, displayName: String,
    completionClosure: @escaping (Result<AccountItem, Error>) -> Void
  ) { XCTFail("Unexpected rename") }
  func performUpdateAssetSettings(
    account: AccountItem, settings: AccountSettings,
    completionClosure: @escaping (Result<AccountItem, Error>) -> Void
  ) { XCTFail("Unexpected assets mutation") }
  func performSetup(completionClosure: @escaping (Result<AccountItem?, Error>) -> Void) {
    completionClosure(.success(currentAccount))
  }
  func save(value: AccountItem) { XCTFail("Unexpected save") }
}
