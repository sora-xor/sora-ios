// SPDX-License-Identifier: BSD-4-Clause
import Combine
import SoraUIKit
import UIKit
import XCTest

@testable import SoraPassport

@MainActor
final class BackupAccountScreenFlowTests: XCTestCase {
  private func make(_ m: BackupScreenModel) -> BackupedAccountsViewController {
    let v = BackupedAccountsViewController()
    v.viewModel = m
    v.loadViewIfNeeded()
    return v
  }
  private func settle() async { try? await Task.sleep(nanoseconds: 40_000_000) }
  private func descendants<T: UIView>(_ type: T.Type, _ root: UIView) -> [T] {
    ((root as? T).map { [$0] } ?? []) + root.subviews.flatMap { descendants(type, $0) }
  }
  private func table(_ v: UIViewController) throws -> UITableView {
    try XCTUnwrap(descendants(UITableView.self, v.view).first)
  }
  private func snapshot(_ addresses: [String], space: Bool = false) -> BackupedAccountsSnapshot {
    var items = addresses.map {
      BackupedAccountSectionItem.account(
        BackupedAccountItem(
          accountName: "Name \($0)", accountAddress: $0,
          config: .init(cornerMask: .all, cornerRaduis: .max, topOffset: 24, bottomOffset: -24)))
    }
    if space {
      items.append(.space(SoramitsuTableViewSpacerItem(space: 16, color: .custom(uiColor: .clear))))
    }
    let section = BackupedAccountsSection(items: items)
    var snapshot = BackupedAccountsSnapshot()
    snapshot.appendSections([section])
    snapshot.appendItems(items, toSection: section)
    return snapshot
  }
  func testFirstLoadReloadsTheCurrentModelOnce() {
    let m = BackupScreenModel()
    let v = make(m)
    v.loadViewIfNeeded()
    XCTAssertEqual(m.reloads, 1)
  }
  func testPublishedTitleReachesTheNavigationBar() async {
    let m = BackupScreenModel()
    let v = make(m)
    m.title = "Your saved wallets"
    await settle()
    XCTAssertEqual(v.navigationItem.title, "Your saved wallets")
  }
  func testInitialPublishedSnapshotRendersStoredAccounts() async throws {
    let m = BackupScreenModel()
    m.snapshot = snapshot(["first", "second"])
    let v = make(m)
    await settle()
    XCTAssertEqual(try table(v).numberOfRows(inSection: 0), 2)
  }
  func testAccountRowDisplaysTheExactNameAndAddress() async throws {
    let m = BackupScreenModel()
    m.snapshot = snapshot(["account-address"])
    let v = make(m)
    await settle()
    let t = try table(v)
    let c = try XCTUnwrap(t.dataSource?.tableView(t, cellForRowAt: IndexPath(row: 0, section: 0)))
    let texts = descendants(UILabel.self, c).compactMap(\.text)
    XCTAssertTrue(texts.contains("Name account-address"))
    XCTAssertTrue(texts.contains("account-address"))
  }
  func testSelectingAnAccountPassesItsExactAddress() async throws {
    let m = BackupScreenModel()
    m.snapshot = snapshot(["first", "second"])
    let v = make(m)
    await settle()
    v.tableView(try table(v), didSelectRowAt: IndexPath(row: 1, section: 0))
    XCTAssertEqual(m.selected, ["second"])
  }
  func testSelectingASpacerDoesNotSelectAnAccount() async throws {
    let m = BackupScreenModel()
    m.snapshot = snapshot([], space: true)
    let v = make(m)
    await settle()
    v.tableView(try table(v), didSelectRowAt: IndexPath(row: 0, section: 0))
    XCTAssertTrue(m.selected.isEmpty)
  }
  func testSpacerRetainsTheIntendedRowHeight() async throws {
    let m = BackupScreenModel()
    m.snapshot = snapshot([], space: true)
    let v = make(m)
    await settle()
    XCTAssertEqual(v.tableView(try table(v), heightForRowAt: IndexPath(row: 0, section: 0)), 16)
  }
  func testAccountRowsUseAutomaticHeight() async throws {
    let m = BackupScreenModel()
    m.snapshot = snapshot(["first"])
    let v = make(m)
    await settle()
    XCTAssertEqual(
      v.tableView(try table(v), heightForRowAt: IndexPath(row: 0, section: 0)),
      UITableView.automaticDimension)
  }
  func testMissingRowUsesAutomaticHeightWithoutSelectingAnything() throws {
    let m = BackupScreenModel()
    let v = make(m)
    let t = try table(v)
    XCTAssertEqual(
      v.tableView(t, heightForRowAt: IndexPath(row: 9, section: 0)), UITableView.automaticDimension)
    v.tableView(t, didSelectRowAt: IndexPath(row: 9, section: 0))
    XCTAssertTrue(m.selected.isEmpty)
  }
  func testSnapshotReplacementRemovesObsoleteAccounts() async throws {
    let m = BackupScreenModel()
    let v = make(m)
    m.snapshot = snapshot(["one", "two"])
    await settle()
    m.snapshot = snapshot(["three"])
    await settle()
    let t = try table(v)
    XCTAssertEqual(t.numberOfRows(inSection: 0), 1)
    v.tableView(t, didSelectRowAt: IndexPath(row: 0, section: 0))
    XCTAssertEqual(m.selected, ["three"])
  }
  func testReplacingModelIgnoresThePreviousTitles() async {
    let old = BackupScreenModel()
    let v = make(old)
    let current = BackupScreenModel()
    current.title = "Current"
    v.viewModel = current
    await settle()
    old.title = "Obsolete"
    await settle()
    XCTAssertEqual(v.navigationItem.title, "Current")
  }
  func testReplacingModelIgnoresThePreviousAccountSnapshot() async throws {
    let old = BackupScreenModel()
    let v = make(old)
    let current = BackupScreenModel()
    current.snapshot = snapshot(["current"])
    v.viewModel = current
    await settle()
    old.snapshot = snapshot(["old-one", "old-two"])
    await settle()
    let t = try table(v)
    XCTAssertEqual(t.numberOfRows(inSection: 0), 1)
    v.tableView(t, didSelectRowAt: IndexPath(row: 0, section: 0))
    XCTAssertEqual(current.selected, ["current"])
  }
  func testClearingModelStopsOldTitleUpdates() async {
    let old = BackupScreenModel()
    let v = make(old)
    await settle()
    let title = v.navigationItem.title
    v.viewModel = nil
    old.title = "Obsolete"
    await settle()
    XCTAssertEqual(v.navigationItem.title, title)
  }
  func testReplacingAnAlreadyLoadedModelReloadsItsAccounts() async {
    let old = BackupScreenModel()
    let v = make(old)
    let current = BackupScreenModel()
    v.viewModel = current
    await settle()
    XCTAssertEqual(current.reloads, 1)
  }
  func testModelReplacementDoesNotRetainTheOldModel() async {
    var old: BackupScreenModel? = BackupScreenModel()
    weak var observed = old
    let v = make(old!)
    v.viewModel = BackupScreenModel()
    old = nil
    await settle()
    XCTAssertNil(observed)
  }
  func testScreenDoesNotLeakThroughItsCombineSubscriptions() async {
    let m = BackupScreenModel()
    var v: BackupedAccountsViewController? = make(m)
    weak var observed = v
    v = nil
    await settle()
    XCTAssertNil(observed)
  }
  func testRepeatedBindingDoesNotDuplicateAccountSelection() async throws {
    let m = BackupScreenModel()
    let v = make(m)
    m.snapshot = snapshot(["one"])
    v.viewModel = m
    v.viewModel = m
    await settle()
    v.tableView(try table(v), didSelectRowAt: IndexPath(row: 0, section: 0))
    XCTAssertEqual(m.selected, ["one"])
  }
  func testAccountListUsesCompactNavigationTitle() {
    let v = make(BackupScreenModel())
    XCTAssertEqual(v.navigationItem.largeTitleDisplayMode, .never)
  }
}
private final class BackupScreenModel: BackupedAccountsViewModelProtocol {
  @Published var title = "Saved wallets"
  @Published var snapshot = BackupedAccountsSnapshot()
  var titlePublisher: Published<String>.Publisher { $title }
  var snapshotPublisher: Published<BackupedAccountsSnapshot>.Publisher { $snapshot }
  var reloads = 0, selected = [String]()
  func reload() { reloads += 1 }
  func didSelectAccount(with address: String) { selected.append(address) }
}
