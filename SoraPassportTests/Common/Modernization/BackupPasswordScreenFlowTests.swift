// SPDX-License-Identifier: Apache-2.0
import Combine
import SoraUIKit
import UIKit
import XCTest

@testable import SoraPassport

@MainActor
final class BackupPasswordScreenFlowTests: XCTestCase {
  private func make(_ model: PasswordScreenModel) -> SetupPasswordViewController {
    let view = SetupPasswordViewController()
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
    let model = PasswordScreenModel()
    let view = make(model)
    view.loadViewIfNeeded()
    XCTAssertEqual(model.reloads, 1)
  }
  func testPublishedTitleReachesTheNavigationBar() async {
    let model = PasswordScreenModel()
    let view = make(model)
    model.title = "Review backup password"
    await settle()
    XCTAssertEqual(view.navigationItem.title, model.title)
  }
  func testInitialSnapshotCreatesTheRealPasswordCell() async throws {
    let model = PasswordScreenModel()
    model.rows(1)
    let view = make(model)
    await settle()
    let table = try table(view)
    XCTAssertEqual(table.numberOfRows(inSection: 0), 1)
    XCTAssertTrue(
      table.dataSource?.tableView(table, cellForRowAt: IndexPath(row: 0, section: 0))
        is SetupPasswordCell)
  }
  func testSnapshotReplacementRemovesObsoletePasswordRows() async throws {
    let model = PasswordScreenModel()
    model.rows(2)
    let view = make(model)
    await settle()
    model.rows(1)
    await settle()
    XCTAssertEqual(try table(view).numberOfRows(inSection: 0), 1)
  }
  func testReplacingPresenterIgnoresItsPreviousTitle() async {
    let old = PasswordScreenModel()
    let view = make(old)
    let current = PasswordScreenModel()
    current.title = "Current password"
    view.viewModel = current
    await settle()
    old.title = "Obsolete password"
    await settle()
    XCTAssertEqual(view.navigationItem.title, current.title)
  }
  func testReplacingPresenterIgnoresItsPreviousSnapshot() async throws {
    let old = PasswordScreenModel()
    let view = make(old)
    let current = PasswordScreenModel()
    current.rows(1)
    view.viewModel = current
    await settle()
    old.rows(3)
    await settle()
    XCTAssertEqual(try table(view).numberOfRows(inSection: 0), 1)
  }
  func testClearingPresenterStopsItsQueuedTitleUpdates() async {
    let old = PasswordScreenModel()
    let view = make(old)
    await settle()
    let title = view.navigationItem.title
    view.viewModel = nil
    old.title = "Obsolete"
    await settle()
    XCTAssertEqual(view.navigationItem.title, title)
  }
  func testReplacingPresenterOnALoadedScreenReloadsItsData() async {
    let view = make(PasswordScreenModel())
    let current = PasswordScreenModel()
    view.viewModel = current
    await settle()
    XCTAssertEqual(current.reloads, 1)
  }
  func testLoadingIsHiddenBeforeAnyOperation() throws {
    let view = make(PasswordScreenModel())
    XCTAssertTrue(try XCTUnwrap(descendants(SoramitsuLoadingView.self, view.view).first).isHidden)
  }
  func testShowAndHideLoadingReversesTheVisibleProgressState() throws {
    let view = make(PasswordScreenModel())
    let loading = try XCTUnwrap(descendants(SoramitsuLoadingView.self, view.view).first)
    view.showLoading()
    XCTAssertFalse(loading.isHidden)
    view.hideLoading()
    XCTAssertTrue(loading.isHidden)
  }
  func testPasswordListDismissesKeyboardWhenDragging() throws {
    XCTAssertEqual(try table(make(PasswordScreenModel())).keyboardDismissMode, .onDrag)
  }
  func testPresenterReplacementReleasesTheOldPresenter() async {
    var old: PasswordScreenModel? = PasswordScreenModel()
    weak var reference = old
    let view = make(old!)
    view.viewModel = PasswordScreenModel()
    old = nil
    await settle()
    XCTAssertNil(reference)
  }
  func testSubscriptionsDoNotRetainThePasswordScreen() async {
    let model = PasswordScreenModel()
    var view: SetupPasswordViewController? = make(model)
    weak var reference = view
    view = nil
    await settle()
    XCTAssertNil(reference)
  }
}
private final class PasswordScreenModel: SetupPasswordPresenterProtocol {
  @Published var title = "Password"
  @Published var snapshot = SetupPasswordSnapshot()
  var titlePublisher: Published<String>.Publisher { $title }
  var snapshotPublisher: Published<SetupPasswordSnapshot>.Publisher { $snapshot }
  var reloads = 0
  func reload() { reloads += 1 }
  func rows(_ count: Int) {
    let items = (0..<count).map { _ in SetupPasswordSectionItem.setupPassword(SetupPasswordItem()) }
    let section = SetupPasswordSection(items: items)
    var next = SetupPasswordSnapshot()
    next.appendSections([section])
    next.appendItems(items, toSection: section)
    snapshot = next
  }
}
