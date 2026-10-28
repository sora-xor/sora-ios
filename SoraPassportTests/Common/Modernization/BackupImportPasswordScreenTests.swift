// SPDX-License-Identifier: BSD-4-Clause
import Combine
import SoraUIKit
import UIKit
import XCTest

@testable import SoraPassport

@MainActor
final class BackupImportPasswordScreenTests: XCTestCase {
  private func make(_ model: ImportPasswordScreenModel) -> EnterPasswordViewController {
    let view = EnterPasswordViewController()
    view.viewModel = model
    view.loadViewIfNeeded()
    return view
  }
  private func descendants<T: UIView>(_ type: T.Type, _ root: UIView) -> [T] {
    ((root as? T).map { [$0] } ?? []) + root.subviews.flatMap { descendants(type, $0) }
  }
  private func table(_ view: UIViewController) throws -> UITableView {
    try XCTUnwrap(descendants(UITableView.self, view.view).first)
  }
  private func settle() async { try? await Task.sleep(nanoseconds: 30_000_000) }
  func testFirstLoadReloadsItsPresenterExactlyOnce() {
    let model = ImportPasswordScreenModel()
    let view = make(model)
    view.loadViewIfNeeded()
    XCTAssertEqual(model.reloads, 1)
  }
  func testPublishedTitleReachesTheNavigationBar() async {
    let model = ImportPasswordScreenModel()
    let view = make(model)
    model.title = "Review backup password"
    await settle()
    XCTAssertEqual(view.navigationItem.title, model.title)
  }
  func testInitialSnapshotCreatesTheRealPasswordCell() async throws {
    let model = ImportPasswordScreenModel()
    model.rows(1)
    let view = make(model)
    await settle()
    let table = try table(view)
    XCTAssertEqual(table.numberOfRows(inSection: 0), 1)
    XCTAssertTrue(
      table.dataSource?.tableView(table, cellForRowAt: IndexPath(row: 0, section: 0))
        is EnterPasswordCell)
  }
  func testSnapshotReplacementRemovesObsoletePasswordRows() async throws {
    let model = ImportPasswordScreenModel()
    model.rows(2)
    let view = make(model)
    await settle()
    model.rows(1)
    await settle()
    XCTAssertEqual(try table(view).numberOfRows(inSection: 0), 1)
  }
  func testReplacingPresenterIgnoresItsPreviousTitle() async {
    let old = ImportPasswordScreenModel()
    let view = make(old)
    let current = ImportPasswordScreenModel()
    current.title = "Current password"
    view.viewModel = current
    await settle()
    old.title = "Obsolete password"
    await settle()
    XCTAssertEqual(view.navigationItem.title, current.title)
  }
  func testReplacingPresenterIgnoresItsPreviousSnapshot() async throws {
    let old = ImportPasswordScreenModel()
    let view = make(old)
    let current = ImportPasswordScreenModel()
    current.rows(1)
    view.viewModel = current
    await settle()
    old.rows(3)
    await settle()
    XCTAssertEqual(try table(view).numberOfRows(inSection: 0), 1)
  }
  func testClearingPresenterStopsItsQueuedTitleUpdates() async {
    let old = ImportPasswordScreenModel()
    let view = make(old)
    await settle()
    let title = view.navigationItem.title
    view.viewModel = nil
    old.title = "Obsolete"
    await settle()
    XCTAssertEqual(view.navigationItem.title, title)
  }
  func testReplacingPresenterOnALoadedScreenReloadsItsData() async {
    let view = make(ImportPasswordScreenModel())
    let current = ImportPasswordScreenModel()
    view.viewModel = current
    await settle()
    XCTAssertEqual(current.reloads, 1)
  }
  func testLoadingIsHiddenBeforeAnyOperation() throws {
    let view = make(ImportPasswordScreenModel())
    XCTAssertTrue(try XCTUnwrap(descendants(SoramitsuLoadingView.self, view.view).first).isHidden)
  }
  func testShowAndHideLoadingReversesTheVisibleProgressState() throws {
    let view = make(ImportPasswordScreenModel())
    let loading = try XCTUnwrap(descendants(SoramitsuLoadingView.self, view.view).first)
    view.showLoading()
    XCTAssertFalse(loading.isHidden)
    view.hideLoading()
    XCTAssertTrue(loading.isHidden)
  }
  func testPresenterReplacementReleasesTheOldPresenter() async {
    var old: ImportPasswordScreenModel? = ImportPasswordScreenModel()
    weak var reference = old
    let view = make(old!)
    view.viewModel = ImportPasswordScreenModel()
    old = nil
    await settle()
    XCTAssertNil(reference)
  }
  func testSubscriptionsDoNotRetainThePasswordScreen() async {
    let model = ImportPasswordScreenModel()
    var view: EnterPasswordViewController? = make(model)
    weak var reference = view
    view = nil
    await settle()
    XCTAssertNil(reference)
  }
}
private final class ImportPasswordScreenModel: EnterPasswordViewModelProtocol {
  @Published var title = "Password"
  @Published var snapshot = EnterPasswordSnapshot()
  var titlePublisher: Published<String>.Publisher { $title }
  var snapshotPublisher: Published<EnterPasswordSnapshot>.Publisher { $snapshot }
  var reloads = 0
  func reload() { reloads += 1 }
  func rows(_ count: Int) {
    let items = (0..<count).map { _ in
      EnterPasswordSectionItem.enterPassword(
        EnterPasswordItem(
          accountAddress: "public-fixture", errorText: "", continueButtonHandler: nil))
    }
    let section = EnterPasswordSection(items: items)
    var next = EnterPasswordSnapshot()
    next.appendSections([section])
    next.appendItems(items, toSection: section)
    snapshot = next
  }
}
