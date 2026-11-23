// SPDX-License-Identifier: Apache-2.0
import Combine
import GoogleAPIClientForRESTCore
import GoogleAPIClientForREST_Drive
import GoogleSignIn
import SSFCloudStorage
import SoraFoundation
import UIKit
import XCTest

@testable import SoraPassport

@MainActor final class BackupImportPasswordModelTests: XCTestCase {
  private var previous = [String]()
  override func setUp() {
    super.setUp()
    previous = ApplicationConfig.shared.backupedAccountAddresses
  }
  override func tearDown() {
    ApplicationConfig.shared.backupedAccountAddresses = previous
    super.tearDown()
  }
  private func make(selected: String = "public-one") -> BackupPasswordModelFixture {
    BackupPasswordModelFixture(selected: selected)
  }
  private func row(_ f: BackupPasswordModelFixture) throws -> EnterPasswordItem {
    f.model.reload()
    guard case .enterPassword(let item) = f.model.snapshot.itemIdentifiers.first else {
      throw NSError(domain: "fixture", code: 1)
    }
    return item
  }
  func testSnapshotUsesTheSelectedBackupNameAndAddress() throws {
    let f = make()
    let item = try row(f)
    XCTAssertEqual(item.accountName, "First backup")
    XCTAssertEqual(item.accountAddress, "public-one")
    XCTAssertEqual(item.errorText, "")
  }
  func testSnapshotIsOnePasswordEntryInOneSection() throws {
    let f = make()
    _ = try row(f)
    XCTAssertEqual(f.model.snapshot.numberOfSections, 1)
    XCTAssertEqual(f.model.snapshot.numberOfItems, 1)
  }
  func testPasswordIsPassedUnmodifiedToTheSelectedBackup() throws {
    let f = make()
    try row(f).continueButtonHandler?("  Unicode🔑  ")
    XCTAssertEqual(f.importer.requests.first?.password, "  Unicode🔑  ")
    XCTAssertEqual(f.importer.requests.first?.account.address, "public-one")
    XCTAssertEqual(f.view.shows, 1)
  }
  func testAnotherSelectedBackupUsesItsOwnMetadata() throws {
    let f = make(selected: "public-two")
    try row(f).continueButtonHandler?("password")
    XCTAssertEqual(f.importer.requests.first?.account.name, "Second backup")
    XCTAssertEqual(f.importer.requests.first?.account.address, "public-two")
  }
  func testMissingSelectedBackupCannotLeaveProgressRunning() throws {
    let f = make(selected: "missing")
    try row(f).continueButtonHandler?("password")
    XCTAssertTrue(f.importer.requests.isEmpty)
    XCTAssertFalse(f.view.loading)
  }
  func testRepeatedContinueWhileImportingDoesNotStartAnotherImport() throws {
    let f = make()
    let item = try row(f)
    item.continueButtonHandler?("first")
    item.continueButtonHandler?("second")
    XCTAssertEqual(f.importer.requests.count, 1)
  }
  func testImportFailureHidesProgressAndPublishesTheReason() throws {
    let f = make()
    try row(f).continueButtonHandler?("password")
    f.model.didReceiveAccountImport(error: BackupPasswordModelFailure.denied)
    XCTAssertFalse(f.view.loading)
    XCTAssertEqual(try row(f).errorText, WalletUX.text("Could not import this backup. Check your original backup and try again."))
    f.model.didReceiveAccountImport(error: CloudStorageServiceError.incorectPassword)
    XCTAssertEqual(try row(f).errorText, R.string.localizable.enterPasswordIncorectTitle(preferredLanguages: .currentLocale))
  }
  func testCancelledKeyRepairHidesProgressWithoutAnErrorAndAllowsRetry() throws {
    let f = make()
    try row(f).continueButtonHandler?("password")
    XCTAssertTrue(f.view.loading)
    f.model.didCancelAccountImport()
    XCTAssertFalse(f.view.loading)
    XCTAssertEqual(try row(f).errorText, "")
    try row(f).continueButtonHandler?("password")
    XCTAssertEqual(f.importer.requests.count, 2)
  }
  func testFailedImportCanRetryWithANewPassword() throws {
    let f = make()
    try row(f).continueButtonHandler?("first")
    f.model.didReceiveAccountImport(error: BackupPasswordModelFailure.denied)
    try row(f).continueButtonHandler?("second")
    XCTAssertEqual(f.importer.requests.map(\.password), ["first", "second"])
  }
  func testRetryClearsThePreviousPasswordError() throws {
    let f = make()
    f.model.didReceiveAccountImport(error: BackupPasswordModelFailure.denied)
    try row(f).continueButtonHandler?("corrected")
    guard case .enterPassword(let item) = f.model.snapshot.itemIdentifiers.first else {
      return XCTFail("Missing password")
    }
    XCTAssertEqual(item.errorText, "")
  }
  func testSuccessHidesProgressAndRoutesWithTheExactCatalog() throws {
    let f = make()
    try row(f).continueButtonHandler?("password")
    f.model.didCompleteAccountImport()
    XCTAssertFalse(f.view.loading)
    XCTAssertEqual(f.routes.addresses, ["public-one"])
    XCTAssertEqual(f.routes.accounts.first?.map(\.address), ["public-one", "public-two"])
  }
  func testSuccessRetainsOtherBackupsWithoutDuplicatingThisAddress() throws {
    let f = make()
    ApplicationConfig.shared.backupedAccountAddresses = ["keep", "public-one"]
    try row(f).continueButtonHandler?("password")
    f.model.didCompleteAccountImport()
    XCTAssertEqual(ApplicationConfig.shared.backupedAccountAddresses, ["keep", "public-one"])
  }
  func testRepeatedSuccessCannotNavigateTwice() throws {
    let f = make()
    try row(f).continueButtonHandler?("password")
    f.model.didCompleteAccountImport()
    f.model.didCompleteAccountImport()
    XCTAssertEqual(f.routes.addresses, ["public-one"])
  }
  func testShortPhraseRestoreWarnsBeforeRoutingToSuccess() throws {
    let f = make()
    try row(f).continueButtonHandler?("password")
    f.model.didRestoreShortPhraseWallet()
    f.model.didCompleteAccountImport()
    XCTAssertFalse(f.view.loading)
    XCTAssertEqual(f.routes.warnings.count, 1)
    XCTAssertEqual(f.routes.warnedWallets, ["public-one"])
    XCTAssertTrue(f.routes.addresses.isEmpty)
    f.routes.warnings.first?()
    XCTAssertEqual(f.routes.addresses, ["public-one"])
  }
  func testOrdinaryRestoreRoutesWithoutTheShortPhraseWarning() throws {
    let f = make()
    try row(f).continueButtonHandler?("password")
    f.model.didCompleteAccountImport()
    XCTAssertTrue(f.routes.warnings.isEmpty)
    XCTAssertEqual(f.routes.addresses, ["public-one"])
  }
  func testFailedImportForgetsItsShortPhraseNotice() throws {
    let f = make()
    try row(f).continueButtonHandler?("password")
    f.model.didRestoreShortPhraseWallet()
    f.model.didReceiveAccountImport(error: BackupPasswordModelFailure.denied)
    f.model.didRestoreShortPhraseWallet()
    try row(f).continueButtonHandler?("password")
    f.model.didCompleteAccountImport()
    XCTAssertTrue(f.routes.warnings.isEmpty)
    XCTAssertEqual(f.routes.addresses, ["public-one"])
  }
  func testLocalizationReloadKeepsSelectedAccountMetadata() throws {
    let f = make(selected: "public-two")
    f.model.applyLocalization()
    XCTAssertEqual(try row(f).accountAddress, "public-two")
    XCTAssertEqual(
      f.model.title,
      R.string.localizable.enterBackupPasswordTitle(
        preferredLanguages: LocalizationManager.shared.preferredLocalizations))
  }
  // MARK: The Google account the list came from
  func testPasswordRequestNamesTheGoogleAccountThatListedTheBackup() throws {
    let f = make()
    try row(f).continueButtonHandler?("password")
    XCTAssertEqual(
      f.importer.requests.first?.expectedGoogleUserID, BackupPasswordModelFixture.listedBy.userID)
  }
  func testSnapshotNamesTheGoogleAccountTheBackupIsReadFrom() throws {
    let f = make()
    XCTAssertEqual(try row(f).googleAccountText, "owner@example.com")
  }
  func testAnotherGoogleAccountIsExplainedAndCanBeRetried() throws {
    let f = make()
    try row(f).continueButtonHandler?("password")
    f.model.didReceiveAccountImport(error: CloudStorageServiceError.accountChanged)
    XCTAssertFalse(f.view.loading)
    XCTAssertEqual(
      try row(f).errorText,
      WalletUX.text(
        "Google is signed in to another account than the one this backup list came from. Go back and choose Google again."
      ))
    XCTAssertTrue(f.routes.addresses.isEmpty)
    XCTAssertTrue(f.store.accounts(for: "public-one").isEmpty)
    try row(f).continueButtonHandler?("password")
    XCTAssertEqual(f.importer.requests.count, 2)
  }
  func testCompletedRestoreRecordsTheGoogleAccountForThatWalletOnly() throws {
    let f = make()
    try row(f).continueButtonHandler?("password")
    XCTAssertTrue(f.store.accounts(for: "public-one").isEmpty, "Nothing is recorded before the restore completes")
    f.model.didCompleteAccountImport()
    let recorded = f.store.accounts(for: "public-one")
    XCTAssertEqual(recorded.map(\.googleUserID), [BackupPasswordModelFixture.listedBy.userID])
    XCTAssertEqual(recorded.map(\.googleEmail), ["owner@example.com"])
    XCTAssertTrue(f.store.accounts(for: "public-two").isEmpty)
    XCTAssertEqual(f.routes.googleAccounts, [BackupPasswordModelFixture.listedBy])
  }
  func testFailedRestoreRecordsNoGoogleAccount() throws {
    let f = make()
    try row(f).continueButtonHandler?("password")
    f.model.didReceiveAccountImport(error: CloudStorageServiceError.incorectPassword)
    f.model.didCompleteAccountImport()
    XCTAssertTrue(f.store.accounts(for: "public-one").isEmpty)
  }
  func testPublishedSnapshotDoesNotKeepTheModelAlive() throws {
    var f: BackupPasswordModelFixture? = make()
    let item = try row(f!)
    weak var model = f?.model
    f = nil
    XCTAssertNil(model)
    withExtendedLifetime(item) {}
  }
}
private enum BackupPasswordModelFailure: LocalizedError {
  case denied
  var errorDescription: String? { "Fixture rejected password" }
}
private final class BackupPasswordModelFixture {
  let importer = BackupPasswordImporter(), routes = BackupPasswordRoutes(),
    view = BackupPasswordView()
  /// The Google account the fixture's backup list was read from.
  static let listedBy = CloudStorageAccountIdentity(
    userID: "password-list-google-user", email: "owner@example.com")
  let suite = "BackupPasswordModelFixture." + UUID().uuidString
  let store: WalletGoogleBackupAccountStore
  let model: EnterPasswordViewModel
  init(selected: String) {
    store = WalletGoogleBackupAccountStore(userDefaults: UserDefaults(suiteName: suite)!)
    model = EnterPasswordViewModel(
      selectedAddress: selected,
      backedUpAccounts: [
        .init(name: "First backup", address: "public-one"),
        .init(name: "Second backup", address: "public-two"),
      ], googleAccount: Self.listedBy, interactor: importer, wireframe: routes, view: view,
      backupAccountStore: store)
  }
  deinit { UserDefaults.standard.removePersistentDomain(forName: suite) }
}
private final class BackupPasswordView: EnterPasswordViewProtocol {
  let controller = UIViewController()
  var isSetup: Bool { true }
  var viewModel: EnterPasswordViewModelProtocol?
  var loading = false, shows = 0
  func showLoading() {
    loading = true
    shows += 1
  }
  func hideLoading() { loading = false }
}
private final class BackupPasswordRoutes: EnterPasswordWireframeProtocol {
  var activityIndicatorWindow: UIWindow?
  var addresses = [String](), accounts = [[OpenBackupAccount]](), warnings = [() -> Void](), warnedWallets = [String]()
  var googleAccounts = [CloudStorageAccountIdentity]()
  func openSuccessImport(
    importedAccountAddress: String, accounts: [OpenBackupAccount],
    googleAccount: CloudStorageAccountIdentity
  ) {
    addresses.append(importedAccountAddress)
    self.accounts.append(accounts)
    googleAccounts.append(googleAccount)
  }
  func presentShortPhraseWarning(name: String?, address: String, acknowledged: @escaping () -> Void) {
    warnedWallets.append(address)
    warnings.append(acknowledged)
  }
}
private final class BackupPasswordImporter: AccountImportInteractorInputProtocol {
  var requests = [AccountImportBackedupRequest]()
  func setup() {}
  func importBackedupAccount(request: AccountImportBackedupRequest) { requests.append(request) }
  func deriveMetadataFromKeystore(_ keystore: String) {}
  func validateAccountWithMnemonic(
    request: AccountImportMnemonicRequest, completion: ((Result<AccountItem?, Error>?) -> Void)?
  ) { XCTFail("Unexpected validation") }
  func validateAccountWithSeed(
    request: AccountImportSeedRequest, completion: ((Result<AccountItem?, Error>?) -> Void)?
  ) { XCTFail("Unexpected validation") }
  func validateAccountWithKeystore(
    request: AccountImportKeystoreRequest, completion: ((Result<AccountItem?, Error>?) -> Void)?
  ) { XCTFail("Unexpected validation") }
  func importAccountWithMnemonic(
    request: AccountImportMnemonicRequest, completion: ((Result<AccountItem, Error>?) -> Void)?
  ) { XCTFail("Unexpected import") }
  func importAccountWithSeed(
    request: AccountImportSeedRequest, completion: ((Result<AccountItem, Error>?) -> Void)?
  ) { XCTFail("Unexpected import") }
  func importAccountWithKeystore(
    request: AccountImportKeystoreRequest, completion: ((Result<AccountItem, Error>?) -> Void)?
  ) { XCTFail("Unexpected import") }
}

/// The production Drive service over an in-memory Google sign-in and Drive.
/// A backup is saved by one Google account and then read back: bound to the
/// account that listed it, with another account signed in, and through
/// Google's account chooser. No network and no Google SDK state is used.
@MainActor final class DriveBackupAccountBindingTests: XCTestCase {
  private let address = "cnVkoGs3rEMqLqY27c2nfVXJRGdzNJk2ns78DcqtppaSRe8qm"
  private let password = "Drive binding fixture password 1"
  private let phrase = "bottom drive obey lake curtain smoke basket hold race lonely fit walk"
  private let ownerA = DriveBindingUser(id: "google-user-a", email: "a@example.com")
  private let ownerB = DriveBindingUser(id: "google-user-b", email: "b@example.com")

  private func make(current: DriveBindingUser?) -> (CloudStorageService, DriveBindingSignIn, DriveBindingDrive, UIViewController) {
    let signIn = DriveBindingSignIn(), drive = DriveBindingDrive(address: address), host = UIViewController()
    signIn.currentUser = current
    return (CloudStorageService(uiDelegate: host, signInProvider: signIn, googleDriveService: drive), signIn, drive, host)
  }
  /// Saves a real encrypted backup as account A and leaves it in the drive.
  private func saved(current: DriveBindingUser?) async throws -> (CloudStorageService, DriveBindingSignIn, DriveBindingDrive, UIViewController) {
    let fixture = make(current: ownerA)
    try await fixture.0.saveBackup(account: OpenBackupAccount(name: "Bound", address: address, passphrase: phrase), password: password)
    XCTAssertNotNil(fixture.2.stored)
    fixture.1.currentUser = current
    fixture.2.queries.removeAll(); fixture.2.queryAccounts.removeAll()
    return fixture
  }
  private func refused(_ operation: () async throws -> OpenBackupAccount, file: StaticString = #filePath, line: UInt = #line) async {
    do { _ = try await operation(); XCTFail("Read from another Google account", file: file, line: line) }
    catch CloudStorageServiceError.accountChanged {}
    catch { XCTFail("Unexpected \(error)", file: file, line: line) }
  }

  func testSaveIsAttributedToTheGoogleAccountThatServedIt() async throws {
    let (service, _, drive, host) = make(current: ownerA)
    XCTAssertNil(service.currentAccountIdentity, "Being signed in to Google alone names no account")
    try await service.saveBackup(account: OpenBackupAccount(name: "Bound", address: address, passphrase: phrase), password: password)
    XCTAssertEqual(service.currentAccountIdentity, CloudStorageAccountIdentity(userID: "google-user-a", email: "a@example.com"))
    XCTAssertEqual(Set(drive.queryAccounts), ["a@example.com"])
    withExtendedLifetime(host) {}
  }
  func testBackupIsReadFromTheGoogleAccountThatListedIt() async throws {
    let (service, signIn, drive, host) = try await saved(current: ownerA)
    let opened = try await service.importBackup(account: OpenBackupAccount(address: address), password: password, expectedAccountUserID: "google-user-a")
    XCTAssertEqual(opened.address, address); XCTAssertEqual(opened.passphrase, phrase)
    XCTAssertEqual(signIn.signIns, 0); XCTAssertFalse(drive.queries.isEmpty)
    XCTAssertEqual(Set(drive.queryAccounts), ["a@example.com"])
    XCTAssertEqual(service.currentAccountIdentity?.userID, "google-user-a")
    withExtendedLifetime(host) {}
  }
  /// Account B is signed in when the password is entered. B's Drive is never
  /// asked, even though it could hold a file for the same address.
  func testAnotherSignedInGoogleAccountIsRefusedBeforeAnyDriveRequest() async throws {
    let (service, signIn, drive, host) = try await saved(current: ownerB)
    await refused { try await service.importBackup(account: OpenBackupAccount(address: self.address), password: self.password, expectedAccountUserID: "google-user-a") }
    XCTAssertTrue(drive.queries.isEmpty); XCTAssertEqual(signIn.signIns, 0)
    XCTAssertNil(service.currentAccountIdentity); XCTAssertNil(drive.authorizer, "The Drive service keeps no authorizer of another account")
    // The same account can still be read without a binding, as before.
    let unbound = try await service.importBackup(account: OpenBackupAccount(address: address), password: password)
    XCTAssertEqual(unbound.passphrase, phrase); XCTAssertEqual(service.currentAccountIdentity?.userID, "google-user-b")
    withExtendedLifetime(host) {}
  }
  /// An account that cannot be named is refused, and its session is ended so that the retry offers Google's chooser.
  func testAnAccountThatCannotBeNamedIsRefused() async throws {
    let (service, signIn, drive, host) = try await saved(current: DriveBindingUser(id: nil, email: "a@example.com"))
    await refused { try await service.importBackup(account: OpenBackupAccount(address: self.address), password: self.password, expectedAccountUserID: "google-user-a") }
    XCTAssertEqual(signIn.signOuts, 1); XCTAssertNil(signIn.currentUser)
    await refused { try await service.importBackup(account: OpenBackupAccount(address: self.address), password: self.password, expectedAccountUserID: "") }
    XCTAssertTrue(drive.queries.isEmpty)
    withExtendedLifetime(host) {}
  }
  /// An account that cannot be named cannot be held to one account, so it lists, saves and deletes nothing, and it
  /// is signed out so that the next attempt offers Google's chooser.
  func testAnAccountThatCannotBeNamedServesNoOperationAndIsSignedOut() async throws {
    let (service, signIn, drive, host) = try await saved(current: DriveBindingUser(id: " ", email: "a@example.com"))
    for operation in ["list", "save", "delete", "read"] {
      signIn.currentUser = DriveBindingUser(id: nil, email: "a@example.com"); signIn.signOuts = 0
      do {
        switch operation {
        case "list": _ = try await service.getBackupAccountsNamingAccount()
        case "save": _ = try await service.saveBackupNamingAccount(account: OpenBackupAccount(address: address, passphrase: phrase), password: password)
        case "delete": _ = try await service.deleteBackupNamingAccount(account: OpenBackupAccount(address: address))
        default: _ = try await service.importBackup(account: OpenBackupAccount(address: address), password: password)
        }
        XCTFail("An unnamed Google account served a \(operation)")
      } catch CloudStorageServiceError.notAuthorized {
      } catch { XCTFail("Unexpected \(error) for \(operation)") }
      XCTAssertEqual(signIn.signOuts, 1, operation); XCTAssertNil(drive.authorizer, operation)
    }
    XCTAssertTrue(drive.queries.isEmpty); XCTAssertNotNil(drive.stored)
    withExtendedLifetime(host) {}
  }
  /// The chooser answers with an account that cannot be named, but another account has been signed in by then.
  /// The operation is refused and only the unnamed session would be ended: the other account stays signed in.
  func testOnlyTheUnnamedSessionIsSignedOut() async throws {
    let (service, signIn, drive, host) = try await saved(current: nil)
    signIn.chooses = DriveBindingUser(id: nil, email: "a@example.com")
    signIn.afterChoice = { [weak signIn] in signIn?.currentUser = self.ownerB }
    do { _ = try await service.getBackupAccountsNamingAccount(); XCTFail("An unnamed Google account listed backups") }
    catch CloudStorageServiceError.notAuthorized {}
    XCTAssertEqual(signIn.signOuts, 0); XCTAssertTrue(signIn.currentUser === ownerB)
    XCTAssertTrue(drive.queries.isEmpty); XCTAssertNil(drive.authorizer); XCTAssertNil(service.currentAccountIdentity)
    withExtendedLifetime(host) {}
  }
  /// Nobody is signed in, so Google's chooser opens. Choosing the account
  /// that listed the backup reads it; choosing another one reads nothing.
  func testAccountChosenInGooglesChooserMustBeTheOneThatListedTheBackup() async throws {
    let (service, signIn, drive, host) = try await saved(current: nil)
    signIn.chooses = ownerB
    await refused { try await service.importBackup(account: OpenBackupAccount(address: self.address), password: self.password, expectedAccountUserID: "google-user-a") }
    XCTAssertEqual(signIn.signIns, 1); XCTAssertTrue(drive.queries.isEmpty); XCTAssertNil(drive.authorizer)

    signIn.currentUser = nil; signIn.chooses = ownerA
    let opened = try await service.importBackup(account: OpenBackupAccount(address: address), password: password, expectedAccountUserID: "google-user-a")
    XCTAssertEqual(opened.passphrase, phrase); XCTAssertEqual(signIn.signIns, 2)
    XCTAssertEqual(Set(drive.queryAccounts), ["a@example.com"])
    XCTAssertEqual(signIn.scopes, [[kGTLRAuthScopeDriveAppdata], [kGTLRAuthScopeDriveAppdata]])
    withExtendedLifetime(host) {}
  }
  /// Choosing another Google account for an ordinary list still works: the
  /// service follows the chosen account and names it.
  func testListingFollowsTheGoogleAccountChosenAndNamesIt() async throws {
    let (service, signIn, drive, host) = try await saved(current: nil)
    signIn.chooses = ownerB
    let listed = try await service.getBackupAccounts()
    XCTAssertEqual(listed.map(\.address), [address]); XCTAssertEqual(signIn.signIns, 1)
    XCTAssertEqual(service.currentAccountIdentity, CloudStorageAccountIdentity(userID: "google-user-b", email: "b@example.com"))
    XCTAssertEqual(Set(drive.queryAccounts), ["b@example.com"])
    withExtendedLifetime(host) {}
  }
  /// The app's file is missing, so the read falls back to the browser
  /// extension's files. The account changes in between: the fallback makes
  /// no request.
  func testFallbackReadIsBoundToTheSameGoogleAccount() async throws {
    let (service, signIn, drive, host) = make(current: ownerA)
    drive.afterQuery = { count in if count == 1 { signIn.currentUser = self.ownerB } }
    await refused {
      try await service.importBackup(
        account: OpenBackupAccount(address: self.address, ethDerivationPath: "extension-eth-file"),
        password: self.password, expectedAccountUserID: "google-user-a")
    }
    XCTAssertEqual(drive.queries.count, 1); XCTAssertEqual(drive.queryAccounts, ["a@example.com"])
    XCTAssertNil(drive.authorizer)
    withExtendedLifetime(host) {}
  }
  /// The list is read in two parts. If the Google account changes between
  /// them, no list is returned, so a list never mixes two accounts.
  func testListReadFromTwoGoogleAccountsIsNotReturned() async throws {
    let (service, signIn, drive, host) = try await saved(current: ownerA)
    drive.afterQuery = { count in if count == 2 { signIn.currentUser = self.ownerB } }
    do {
      _ = try await service.getBackupAccountsNamingAccount()
      XCTFail("A list from two Google accounts was returned")
    } catch CloudStorageServiceError.accountChanged {
    } catch { XCTFail("Unexpected \(error)") }
    XCTAssertEqual(drive.queries.count, 2); XCTAssertEqual(Set(drive.queryAccounts), ["a@example.com"])
    withExtendedLifetime(host) {}
  }
  /// Two operations on one service: a read bound to A is in flight when B
  /// signs in and a list is asked for. The list waits, so every request of
  /// the read is made as A. Because Google has switched accounts meanwhile,
  /// what the read fetched is not handed on. Then the list is read, and
  /// named, as B.
  func testOperationsOfOneServiceDoNotShareAnAuthorizer() async throws {
    let (service, signIn, drive, host) = try await saved(current: ownerA)
    let reached = expectation(description: "the bound read reached Drive")
    drive.pauseOnDownload = true; drive.onPause = { reached.fulfill() }
    let read = Task {
      try await service.importBackup(
        account: OpenBackupAccount(address: self.address), password: self.password,
        expectedAccountUserID: "google-user-a")
    }
    await fulfillment(of: [reached], timeout: 5)
    signIn.currentUser = ownerB
    let list = Task { try await service.getBackupAccountsNamingAccount() }
    try await Task.sleep(nanoseconds: 300_000_000)
    let whileReading = drive.queries.count
    XCTAssertEqual(drive.authorizer?.userEmail ?? nil, "a@example.com", "B's authorizer must not replace A's during A's read")
    XCTAssertEqual(Set(drive.queryAccounts), ["a@example.com"])
    drive.resume()
    do { _ = try await read.value; XCTFail("A backup was handed on after Google switched accounts") }
    catch CloudStorageServiceError.accountChanged {}
    let listed = try await list.value
    XCTAssertEqual(listed.googleAccount, CloudStorageAccountIdentity(userID: "google-user-b", email: "b@example.com"))
    XCTAssertEqual(listed.accounts.map(\.address), [address])
    XCTAssertEqual(Set(drive.queryAccounts.dropFirst(whileReading)), ["b@example.com"])
    withExtendedLifetime(host) {}
  }
  /// While a bound read downloads, Google's session becomes one that cannot be named. Nothing is handed on, and
  /// that session is ended so that the retry offers Google's chooser.
  func testReadFinishedUnderAnUnnamedSessionIsRefusedAndSignsItOut() async throws {
    let (service, signIn, drive, host) = try await saved(current: ownerA)
    let reached = expectation(description: "the bound read reached Drive")
    drive.pauseOnDownload = true; drive.onPause = { reached.fulfill() }
    let read = Task {
      try await service.importBackup(account: OpenBackupAccount(address: self.address), password: self.password,
                                     expectedAccountUserID: "google-user-a")
    }
    await fulfillment(of: [reached], timeout: 5)
    signIn.currentUser = DriveBindingUser(id: nil, email: "a@example.com")
    drive.resume()
    do { _ = try await read.value; XCTFail("A backup was handed on under an unnamed session") }
    catch CloudStorageServiceError.accountChanged {}
    XCTAssertEqual(signIn.signOuts, 1); XCTAssertNil(signIn.currentUser)
    withExtendedLifetime(host) {}
  }
  /// A read in flight is not interrupted by a sign-in elsewhere: when the same account is signed in at the end,
  /// the backup is returned.
  func testReadInFlightReturnsWhenTheSameGoogleAccountIsStillSignedIn() async throws {
    let (service, _, drive, host) = try await saved(current: ownerA)
    let reached = expectation(description: "the bound read reached Drive")
    drive.pauseOnDownload = true; drive.onPause = { reached.fulfill() }
    let read = Task {
      try await service.importBackup(
        account: OpenBackupAccount(address: self.address), password: self.password,
        expectedAccountUserID: "google-user-a")
    }
    await fulfillment(of: [reached], timeout: 5)
    drive.resume()
    let opened = try await read.value
    XCTAssertEqual(opened.passphrase, phrase); XCTAssertEqual(Set(drive.queryAccounts), ["a@example.com"])
    withExtendedLifetime(host) {}
  }
  /// An operation waiting for another one to finish is cancelled. It leaves the queue at once, before the running
  /// operation ends, and makes no Drive request; the service then serves the next operation as usual.
  func testCancelledWaitingOperationLeavesAtOnceAndStartsNothing() async throws {
    let (service, _, drive, host) = try await saved(current: ownerA)
    let reached = expectation(description: "the read reached Drive")
    drive.pauseOnDownload = true; drive.onPause = { reached.fulfill() }
    let read = Task {
      try await service.importBackup(account: OpenBackupAccount(address: self.address), password: self.password,
                                     expectedAccountUserID: "google-user-a")
    }
    await fulfillment(of: [reached], timeout: 5)
    let requestsBeforeDeletion = drive.queries.count
    let ended = expectation(description: "the cancelled deletion ended while the read was still running")
    let deletion = Task {
      defer { ended.fulfill() }
      return try await service.deleteBackupNamingAccount(account: OpenBackupAccount(address: self.address))
    }
    try await Task.sleep(nanoseconds: 200_000_000)
    deletion.cancel()
    await fulfillment(of: [ended], timeout: 5)
    XCTAssertEqual(drive.queries.count, requestsBeforeDeletion, "The cancelled deletion made a Drive request")
    drive.resume()
    do { _ = try await deletion.value; XCTFail("A cancelled deletion ran") } catch is CancellationError {}
    let opened = try await read.value
    XCTAssertEqual(opened.passphrase, phrase)
    XCTAssertNotNil(drive.stored, "The backup was deleted")
    let listed = try await service.getBackupAccountsNamingAccount()
    XCTAssertEqual(listed.accounts.map(\.address), [address])
    withExtendedLifetime(host) {}
  }
  /// Two saves of one wallet at once, with different passwords: each uploads the backup it encrypted itself, and
  /// no file named after the wallet is written to the temporary directory.
  func testConcurrentSavesOfOneWalletUploadTheirOwnBackups() async throws {
    let (service, _, drive, host) = make(current: ownerA)
    let shared = FileManager.default.temporaryDirectory.appendingPathComponent("\(address).json")
    try? FileManager.default.removeItem(at: shared)
    let backup = OpenBackupAccount(name: "Bound", address: address, passphrase: phrase)
    async let first = service.saveBackupNamingAccount(account: backup, password: "first " + password)
    async let second = service.saveBackupNamingAccount(account: backup, password: "second " + password)
    let servedBy = try await [first, second]
    let ownerAIdentity: CloudStorageAccountIdentity? = CloudStorageAccountIdentity(userID: "google-user-a", email: "a@example.com")
    XCTAssertEqual(servedBy, [ownerAIdentity, ownerAIdentity])
    XCTAssertEqual(drive.uploads.count, 2)
    let openedWith = drive.uploads.compactMap { upload in
      ["first ", "second "].first { (try? CloudStorageService.openBackup(upload, password: $0 + password, expectedAddress: address)) != nil }
    }
    XCTAssertEqual(Set(openedWith), ["first ", "second "])
    XCTAssertFalse(FileManager.default.fileExists(atPath: shared.path))
    withExtendedLifetime(host) {}
  }
  /// A save and a deletion name the Google account that served them.
  func testSaveAndDeletionNameTheGoogleAccountThatServedThem() async throws {
    let (service, signIn, drive, host) = make(current: ownerA)
    let savedBy = try await service.saveBackupNamingAccount(
      account: OpenBackupAccount(name: "Bound", address: address, passphrase: phrase), password: password)
    XCTAssertEqual(savedBy, CloudStorageAccountIdentity(userID: "google-user-a", email: "a@example.com"))
    signIn.currentUser = ownerB
    let deletedBy = try await service.deleteBackupNamingAccount(account: OpenBackupAccount(address: address))
    XCTAssertEqual(deletedBy, CloudStorageAccountIdentity(userID: "google-user-b", email: "b@example.com"))
    XCTAssertNil(drive.stored)
    withExtendedLifetime(host) {}
  }
  func testDisconnectForgetsTheAccountAndItsAuthorizer() async throws {
    let (service, signIn, drive, host) = try await saved(current: ownerA)
    _ = try await service.getBackupAccounts()
    XCTAssertNotNil(service.currentAccountIdentity); XCTAssertNotNil(drive.authorizer)
    service.disconnect()
    XCTAssertNil(service.currentAccountIdentity); XCTAssertNil(drive.authorizer)
    XCTAssertEqual(signIn.signOuts, 1); XCTAssertEqual(signIn.disconnects, 1)
    withExtendedLifetime(host) {}
  }
}

private final class DriveBindingAuthorizer: NSObject, GTMFetcherAuthorizationProtocol {
  let userEmail: String?
  init(userEmail: String?) { self.userEmail = userEmail }
  func authorizeRequest(_ request: NSMutableURLRequest?, delegate: Any, didFinish selector: Selector) {}
  func stopAuthorization() {}
  func stopAuthorization(for request: URLRequest) {}
  func isAuthorizingRequest(_ request: URLRequest) -> Bool { false }
  func isAuthorizedRequest(_ request: URLRequest) -> Bool { false }
}
private final class DriveBindingProfile: GIDProfileData {
  private let mail: String
  init(email: String) { mail = email; super.init() }
  required init?(coder: NSCoder) { fatalError("not coded") }
  override var email: String { mail }
  override var name: String { "Fixture owner" }
}
/// A Google account as the sign-in SDK reports it. The SDK cannot create one
/// outside a sign-in, so the three values the service reads are overridden.
private final class DriveBindingUser: GIDGoogleUser {
  private let id: String?
  private let data: DriveBindingProfile?
  private let authorizer: DriveBindingAuthorizer
  init(id: String?, email: String?) {
    self.id = id; data = email.map(DriveBindingProfile.init(email:)); authorizer = DriveBindingAuthorizer(userEmail: email)
    super.init()
  }
  required init?(coder: NSCoder) { fatalError("not coded") }
  override var userID: String? { id }
  override var profile: GIDProfileData? { data }
  override var fetcherAuthorizer: GTMFetcherAuthorizationProtocol { authorizer }
}
private final class DriveBindingSignIn: CloudStorageSignInProvider {
  var currentUser: GIDGoogleUser?
  /// The account the user picks in Google's chooser.
  var chooses: DriveBindingUser?
  /// Runs after the choice is made, before it is reported.
  var afterChoice: (() -> Void)?
  var signIns = 0, signOuts = 0, disconnects = 0, scopes = [[String]]()
  func signInForDrive(presenting: UIViewController, scopes: [String], completion: @escaping (GIDGoogleUser?, Error?) -> Void) {
    signIns += 1; self.scopes.append(scopes); currentUser = chooses; afterChoice?(); completion(chooses, nil)
  }
  func signOut() { signOuts += 1; currentUser = nil }
  func disconnect(completion: ((Error?) -> Void)?) { disconnects += 1; completion?(nil) }
}
private struct DriveBindingTicket: GoogleServiceTicket {}
/// One backup folder holding at most one backup file, as Drive lists them.
private final class DriveBindingDrive: GoogleService {
  let address: String
  var authorizer: GTMFetcherAuthorizationProtocol?
  var queries: [GTLRQueryProtocol] = []
  /// The account whose authorizer was in place when each request was made.
  var queryAccounts: [String?] = []
  var stored: Data?
  /// Every backup uploaded, in order.
  var uploads: [Data] = []
  /// Called after each request with the number of requests so far.
  var afterQuery: ((Int) -> Void)?
  /// Holds the next download until `resume()`.
  var pauseOnDownload = false
  var onPause: (() -> Void)?
  private var paused: CheckedContinuation<Void, Never>?
  init(address: String) { self.address = address }
  func set(authorizer: GTMFetcherAuthorizationProtocol?) { self.authorizer = authorizer }
  func resume() { paused?.resume(); paused = nil }
  func executeQuery(_ query: GTLRQueryProtocol) async throws -> (ticket: GoogleServiceTicket, file: Any?) {
    queries.append(query); queryAccounts.append(authorizer?.userEmail ?? nil)
    defer { afterQuery?(queries.count) }
    guard authorizer != nil else { throw CloudStorageServiceError.notAuthorized }
    if query is GTLRDriveQuery_FilesDelete {
      stored = nil
      return (DriveBindingTicket(), nil)
    }
    if pauseOnDownload, query is GTLRDriveQuery_FilesGet {
      pauseOnDownload = false
      await withCheckedContinuation { paused = $0; onPause?() }
    }
    if let create = query as? GTLRDriveQuery_FilesCreate {
      stored = create.uploadParameters?.data
      if let upload = create.uploadParameters?.data { uploads.append(upload) }
      let file = GTLRDrive_File(); file.identifier = "binding-backup-file"; return (DriveBindingTicket(), file)
    }
    if let list = query as? GTLRDriveQuery_FilesList {
      let result = GTLRDrive_FileList()
      if list.q == "name = 'backupFolder'" {
        let folder = GTLRDrive_File(); folder.identifier = "binding-backup-folder"; folder.name = "backupFolder"
        result.files = [folder]
      } else if list.q?.contains("mimeType != 'application/vnd.google-apps.folder'") == true {
        result.files = []
      } else {
        let file = GTLRDrive_File(); file.identifier = "binding-backup-file"; file.name = "\(address).json"
        file.descriptionProperty = "Bound"
        result.files = stored == nil ? [] : [file]
      }
      return (DriveBindingTicket(), result)
    }
    if query is GTLRDriveQuery_FilesGet, let stored {
      let media = GTLRDataObject(); media.data = stored; return (DriveBindingTicket(), media)
    }
    throw CloudStorageServiceError.notFound
  }
}

/// The record of which Google accounts hold a wallet's Drive backup.
final class WalletGoogleBackupAccountStoreTests: XCTestCase {
  private let suite = "WalletGoogleBackupAccountStoreTests." + UUID().uuidString
  private lazy var defaults = UserDefaults(suiteName: suite)!
  private lazy var store = WalletGoogleBackupAccountStore(userDefaults: defaults)
  override func tearDown() { UserDefaults.standard.removePersistentDomain(forName: suite); super.tearDown() }

  func testRecordsAreKeptPerWalletAndNewestFirst() {
    XCTAssertTrue(store.record(googleUserID: " user-a ", googleEmail: " a@example.com ", for: "wallet-1", verifiedAt: Date(timeIntervalSince1970: 10)))
    XCTAssertTrue(store.record(googleUserID: "user-b", googleEmail: nil, for: "wallet-1", verifiedAt: Date(timeIntervalSince1970: 20)))
    XCTAssertTrue(store.record(googleUserID: "user-a", googleEmail: "a@example.com", for: "wallet-2", verifiedAt: Date(timeIntervalSince1970: 30)))
    XCTAssertEqual(store.accounts(for: "wallet-1").map(\.googleUserID), ["user-b", "user-a"])
    XCTAssertEqual(store.accounts(for: "wallet-1").map(\.googleEmail), [nil, "a@example.com"])
    XCTAssertEqual(store.accounts(for: "wallet-2").map(\.googleUserID), ["user-a"])
    XCTAssertTrue(store.accounts(for: "wallet-3").isEmpty)
  }
  func testRecordingTheSameAccountAgainReplacesItsEntry() {
    store.record(googleUserID: "user-a", googleEmail: "old@example.com", for: "wallet-1", verifiedAt: Date(timeIntervalSince1970: 10))
    store.record(googleUserID: "user-a", googleEmail: "new@example.com", for: "wallet-1", verifiedAt: Date(timeIntervalSince1970: 20))
    XCTAssertEqual(store.accounts(for: "wallet-1").map(\.googleEmail), ["new@example.com"])
    XCTAssertEqual(store.accounts(for: "wallet-1").first?.verifiedAt, Date(timeIntervalSince1970: 20))
  }
  func testAnAccountOrWalletThatCannotBeNamedIsNotRecorded() {
    XCTAssertFalse(store.record(googleUserID: "  ", googleEmail: "a@example.com", for: "wallet-1"))
    XCTAssertFalse(store.record(googleUserID: "user-a", googleEmail: "a@example.com", for: ""))
    XCTAssertNil(defaults.data(forKey: WalletGoogleBackupAccountStore.defaultStorageKey))
  }
  func testRemovalTakesOneAccountOrTheWholeWallet() {
    store.record(googleUserID: "user-a", googleEmail: nil, for: "wallet-1")
    store.record(googleUserID: "user-b", googleEmail: nil, for: "wallet-1")
    store.record(googleUserID: "user-a", googleEmail: nil, for: "wallet-2")
    store.remove(for: "wallet-1", googleUserID: "user-a")
    XCTAssertEqual(store.accounts(for: "wallet-1").map(\.googleUserID), ["user-b"])
    XCTAssertEqual(store.accounts(for: "wallet-2").map(\.googleUserID), ["user-a"])
    store.remove(for: "wallet-1")
    XCTAssertTrue(store.accounts(for: "wallet-1").isEmpty)
    XCTAssertEqual(store.accounts(for: "wallet-2").count, 1)
  }
  func testRecordsSurviveANewStoreAndOnlyTheNewestPerWalletAreKept() {
    for index in 0..<(WalletGoogleBackupAccountStore.maximumAccountsPerWallet + 3) {
      store.record(googleUserID: "user-\(index)", googleEmail: nil, for: "wallet-1", verifiedAt: Date(timeIntervalSince1970: TimeInterval(index)))
    }
    store.record(googleUserID: "other", googleEmail: nil, for: "wallet-2")
    let reopened = WalletGoogleBackupAccountStore(userDefaults: defaults)
    let kept = reopened.accounts(for: "wallet-1").map(\.googleUserID)
    XCTAssertEqual(kept.count, WalletGoogleBackupAccountStore.maximumAccountsPerWallet)
    XCTAssertEqual(kept.first, "user-\(WalletGoogleBackupAccountStore.maximumAccountsPerWallet + 2)")
    XCTAssertFalse(kept.contains("user-0"))
    XCTAssertEqual(reopened.accounts(for: "wallet-2").count, 1)
  }
  func testAStoredValueOfAnotherShapeReadsAsEmpty() {
    defaults.set(Data("not the record".utf8), forKey: WalletGoogleBackupAccountStore.defaultStorageKey)
    XCTAssertTrue(store.accounts(for: "wallet-1").isEmpty)
    XCTAssertTrue(store.record(googleUserID: "user-a", googleEmail: nil, for: "wallet-1"))
    XCTAssertEqual(store.accounts(for: "wallet-1").count, 1)
  }

  /// Recovery lets the user choose the Google account. The one that held
  /// the wallet's backup file is recorded; a read that found nothing is not.
  func testRecoveryReadRecordsTheChosenGoogleAccountOnlyWhenItHeldTheBackup() async throws {
    let address = "cnVkoGs3rEMqLqY27c2nfVXJRGdzNJk2ns78DcqtppaSRe8qm"
    let payload = Data("synthetic encrypted backup bytes".utf8)
    func list(_ files: [GTLRDrive_File]) -> GTLRDrive_FileList { let result = GTLRDrive_FileList(); result.files = files; return result }
    let file = GTLRDrive_File(); file.identifier = "recovery-backup"; file.name = "\(address).json"
    file.size = NSNumber(value: payload.count); file.mimeType = "application/json"
    let media = GTLRDataObject(); media.data = payload
    let chosen = CloudStorageAccountIdentity(userID: "recovery-google-user", email: "recovery@example.com")

    let empty = WalletCloudBackupRecoveryService(drive: RecoveryRecordDrive([list([])]), authorize: { true },
                                                 authorizedAccount: { chosen }, backupAccountStore: store)
    do { _ = try await empty.readBackup(for: address); XCTFail("No backup exists") } catch {}
    XCTAssertTrue(store.accounts(for: address).isEmpty)

    let unnamed = WalletCloudBackupRecoveryService(drive: RecoveryRecordDrive([list([file]), media]), authorize: { true },
                                                   backupAccountStore: store)
    let unnamedData = try await unnamed.readBackup(for: address)
    XCTAssertEqual(unnamedData, payload)
    XCTAssertTrue(store.accounts(for: address).isEmpty, "A read whose Google account cannot be named records nothing")

    let found = WalletCloudBackupRecoveryService(drive: RecoveryRecordDrive([list([file]), media]), authorize: { true },
                                                 authorizedAccount: { chosen }, backupAccountStore: store)
    let data = try await found.readBackup(for: address)
    XCTAssertEqual(data, payload)
    XCTAssertEqual(store.accounts(for: address).map(\.googleUserID), ["recovery-google-user"])
    XCTAssertEqual(store.accounts(for: address).map(\.googleEmail), ["recovery@example.com"])
  }
}
private struct RecoveryRecordTicket: GoogleServiceTicket {}
private final class RecoveryRecordDrive: GoogleService {
  var responses: [Any]
  init(_ responses: [Any]) { self.responses = responses }
  func set(authorizer: GTMFetcherAuthorizationProtocol?) {}
  func executeQuery(_ query: GTLRQueryProtocol) async throws -> (ticket: GoogleServiceTicket, file: Any?) {
    guard !responses.isEmpty else { throw WalletCloudBackupRecoveryError.unavailable }
    return (RecoveryRecordTicket(), responses.removeFirst())
  }
}
