// SPDX-License-Identifier: Apache-2.0
import Combine
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
    XCTAssertEqual(try row(f).errorText, "Fixture rejected password")
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
  let model: EnterPasswordViewModel
  init(selected: String) {
    model = EnterPasswordViewModel(
      selectedAddress: selected,
      backedUpAccounts: [
        .init(name: "First backup", address: "public-one"),
        .init(name: "Second backup", address: "public-two"),
      ], interactor: importer, wireframe: routes, view: view)
  }
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
  func openSuccessImport(importedAccountAddress: String, accounts: [OpenBackupAccount]) {
    addresses.append(importedAccountAddress)
    self.accounts.append(accounts)
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
