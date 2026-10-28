// SPDX-License-Identifier: BSD-4-Clause
import Combine
import SSFCloudStorage
import SoraFoundation
import SoraUIKit
import XCTest

@testable import SoraPassport

@MainActor
final class BackupAccountModelFlowTests: XCTestCase {
  private func account(_ id: String, name: String? = nil) -> OpenBackupAccount {
    OpenBackupAccount(name: name, address: "public-backup-fixture-" + id)
  }
  private func make(_ accounts: [OpenBackupAccount]) -> (
    BackupedAccountsViewModel, BackupModelRoutes
  ) {
    let routes = BackupModelRoutes()
    let model = BackupedAccountsViewModel(backedUpAccounts: accounts, wireframe: routes)
    model.reload()
    return (model, routes)
  }
  private func accounts(_ model: BackupedAccountsViewModel) -> [BackupedAccountItem] {
    model.snapshot.itemIdentifiers.compactMap {
      if case .account(let item) = $0 { return item }
      return nil
    }
  }
  func testEmptyCatalogStillOffersTheCreateAccountAction() {
    let (model, _) = make([])
    XCTAssertEqual(model.snapshot.numberOfSections, 1)
    XCTAssertEqual(model.snapshot.numberOfItems, 2)
    XCTAssertTrue(accounts(model).isEmpty)
    guard case .button = model.snapshot.itemIdentifiers.last else {
      return XCTFail("Missing new-account action")
    }
  }
  func testOneAccountUsesAllRoundedCornersAndOuterPadding() {
    let (model, _) = make([account("one")])
    let row = accounts(model)[0]
    guard case .all = row.config.cornerMask else { return XCTFail("Unexpected corner mask") }
    XCTAssertEqual(row.config.topOffset, 24)
    XCTAssertEqual(row.config.bottomOffset, -24)
  }
  func testFirstAccountInAGroupUsesOnlyTopCorners() {
    let (model, _) = make([account("one"), account("two")])
    let row = accounts(model)[0]
    guard case .top = row.config.cornerMask else { return XCTFail("Unexpected corner mask") }
    XCTAssertEqual(row.config.topOffset, 24)
    XCTAssertEqual(row.config.bottomOffset, -18)
  }
  func testLastAccountInAGroupUsesOnlyBottomCorners() {
    let (model, _) = make([account("one"), account("two")])
    let row = accounts(model)[1]
    guard case .bottom = row.config.cornerMask else { return XCTFail("Unexpected corner mask") }
    XCTAssertEqual(row.config.topOffset, 18)
    XCTAssertEqual(row.config.bottomOffset, -24)
  }
  func testMiddleAccountUsesNoRoundedCorners() {
    let (model, _) = make([account("one"), account("two"), account("three")])
    let row = accounts(model)[1]
    guard case .none = row.config.cornerMask else { return XCTFail("Unexpected corner mask") }
    XCTAssertEqual(row.config.topOffset, 18)
    XCTAssertEqual(row.config.bottomOffset, -18)
  }
  func testCatalogOrderAndExactAddressArePreserved() {
    let values = [account("b", name: "Second"), account("a", name: "First")]
    let (model, _) = make(values)
    XCTAssertEqual(accounts(model).map(\.accountAddress), values.map(\.address))
    XCTAssertEqual(accounts(model).map(\.accountName), ["Second", "First"])
  }
  func testUnnamedBackupDoesNotInventAnotherWalletName() {
    let (model, _) = make([account("unnamed")])
    XCTAssertNil(accounts(model).first?.accountName)
  }
  func testSelectingABackupPassesTheExactAddressAndOriginalBackupMetadata() {
    let values = [account("one", name: "First"), account("two", name: "Second")]
    let (model, routes) = make(values)
    model.didSelectAccount(with: values[1].address)
    XCTAssertEqual(routes.selected, [values[1].address])
    XCTAssertEqual(routes.catalogs.first?.map(\.address), values.map(\.address))
    XCTAssertEqual(routes.catalogs.first?.map(\.name), values.map(\.name))
  }
  func testReloadReplacesObsoleteBackupRows() {
    let (model, _) = make([account("one"), account("two")])
    model.backedUpAccounts = [account("three")]
    model.reload()
    XCTAssertEqual(accounts(model).map(\.accountAddress), [account("three").address])
    XCTAssertEqual(model.snapshot.numberOfItems, 3)
  }
  func testReloadingAnEmptyCatalogRemovesThePreviousRows() {
    let (model, _) = make([account("one")])
    model.backedUpAccounts = []
    model.reload()
    XCTAssertTrue(accounts(model).isEmpty)
    XCTAssertEqual(model.snapshot.numberOfItems, 2)
  }
  func testLocalizationRefreshKeepsTheCurrentCatalog() {
    let (model, _) = make([account("one")])
    model.applyLocalization()
    XCTAssertEqual(accounts(model).map(\.accountAddress), [account("one").address])
    XCTAssertEqual(
      model.title,
      R.string.localizable.selectAccountImport(
        preferredLanguages: LocalizationManager.shared.preferredLocalizations))
  }
  func testSnapshotPublisherReceivesTheReplacementCatalog() {
    let (model, _) = make([])
    var count = 0
    let subscription = model.snapshotPublisher.sink { count = $0.numberOfItems }
    model.backedUpAccounts = [account("one")]
    model.reload()
    XCTAssertEqual(count, 3)
    withExtendedLifetime(subscription) {}
  }
  func testCatalogSeparatesAccountsFromTheCreateButtonWithASpacer() {
    let (model, _) = make([account("one")])
    guard case .space = model.snapshot.itemIdentifiers[1] else {
      return XCTFail("Missing action separation")
    }
    XCTAssertEqual(model.snapshot.itemIdentifiers.count, 3)
  }
}
private final class BackupModelRoutes: BackupedAccountsWireframeProtocol {
  var selected = [String](), catalogs = [[OpenBackupAccount]](), creates = 0
  func openInputPassword(selectedAddress: String, backedUpAccounts: [OpenBackupAccount]) {
    selected.append(selectedAddress)
    catalogs.append(backedUpAccounts)
  }
  func showCreateAccount() { creates += 1 }
}
