// SPDX-License-Identifier: Apache-2.0
import Combine
import SoraUIKit
import UIKit
import XCTest

@testable import SoraPassport

@MainActor
final class WalletCardEditingFlowTests: XCTestCase {
  private var selected: AccountItem?
  override func setUp() {
    super.setUp()
    selected = SelectedWalletSettings.shared.currentAccount
    SelectedWalletSettings.shared.commitInternalValue(nil)
  }
  override func tearDown() {
    SelectedWalletSettings.shared.commitInternalValue(selected)
    super.tearDown()
  }
  private func descendants<T: UIView>(_ type: T.Type, _ root: UIView) -> [T] {
    ((root as? T).map { [$0] } ?? []) + root.subviews.flatMap { descendants(type, $0) }
  }
  private func item(_ titles: [String], ids: [Int]? = nil) -> EnabledItem {
    let i = EnabledItem()
    i.enabledViewModels = titles.enumerated().map {
      EnabledViewModel(id: ids?[$0.offset] ?? $0.offset + 1, title: $0.element, state: .selected)
    }
    return i
  }
  private func bind(_ i: EnabledItem) -> EnabledCell {
    let c = EnabledCell(style: .default, reuseIdentifier: nil)
    c.set(item: i, context: nil)
    return c
  }
  private func snapshot(_ titles: [String]) -> EditViewSnapshot {
    let i = item(titles)
    let section = EnabledSection(items: [.enabled(i)])
    var s = EditViewSnapshot()
    s.appendSections([section])
    s.appendItems(section.items, toSection: section)
    return s
  }
  private func make(_ m: EditingScreenModel) -> EditViewController {
    let v = EditViewController(viewModel: m)
    v.loadViewIfNeeded()
    return v
  }
  private func settle() async { try? await Task.sleep(nanoseconds: 40_000_000) }
  private func table(_ v: UIViewController) throws -> UITableView {
    try XCTUnwrap(descendants(UITableView.self, v.view).first)
  }
  private func renderedTitles(_ v: UIViewController) throws -> [String] {
    let t = try table(v)
    guard t.numberOfSections > 0, t.numberOfRows(inSection: 0) > 0 else { return [] }
    let c = try XCTUnwrap(t.dataSource?.tableView(t, cellForRowAt: IndexPath(row: 0, section: 0)))
    return descendants(EnabledView.self, c).compactMap { $0.titleLabel.text }
  }
  func testCellRendersBothEnabledAndDisabledCards() {
    let c = bind(item(["Referral", "Other"], ids: [1, 99]))
    XCTAssertEqual(
      Set(descendants(EnabledView.self, c).compactMap { $0.titleLabel.text }),
      Set(["Referral", "Other"]))
  }
  func testEmptyCardListHidesBothSections() {
    let c = bind(item([]))
    XCTAssertTrue(descendants(EnabledView.self, c).isEmpty)
    let labels = descendants(UILabel.self, c).filter { !($0.text?.isEmpty ?? true) }
    XCTAssertTrue(labels.allSatisfy { $0.superview?.isHidden == true })
  }
  func testRebindingCardsRemovesRowsFromBothOldSections() {
    let c = bind(item(["Referral", "Old"], ids: [1, 99]))
    c.set(item: item(["Current"], ids: [3]), context: nil)
    XCTAssertEqual(descendants(EnabledView.self, c).compactMap { $0.titleLabel.text }, ["Current"])
  }
  func testEnabledCardTapReportsTheExactIdentifier() throws {
    let i = item(["Referral"], ids: [1])
    var tapped = [Int]()
    i.onTap = { tapped.append($0) }
    let c = bind(i)
    try XCTUnwrap(descendants(EnabledView.self, c).first).tappableArea.sendActions(
      for: .touchUpInside)
    XCTAssertEqual(tapped, [1])
  }
  func testDisabledCardTapReportsTheExactIdentifier() throws {
    let i = item(["Other"], ids: [99])
    var tapped = [Int]()
    i.onTap = { tapped.append($0) }
    let c = bind(i)
    try XCTUnwrap(descendants(EnabledView.self, c).first).tappableArea.sendActions(
      for: .touchUpInside)
    XCTAssertEqual(tapped, [99])
  }
  func testRebindingCardsUsesOnlyTheCurrentTapHandler() throws {
    let old = item(["Old"], ids: [1])
    let current = item(["Current"], ids: [3])
    var oldCalls = 0
    var currentCalls = 0
    old.onTap = { _ in oldCalls += 1 }
    current.onTap = { _ in currentCalls += 1 }
    let c = bind(old)
    c.set(item: current, context: nil)
    try XCTUnwrap(descendants(EnabledView.self, c).first).tappableArea.sendActions(
      for: .touchUpInside)
    XCTAssertEqual(oldCalls, 0)
    XCTAssertEqual(currentCalls, 1)
  }
  func testRebindingReleasesThePreviousCardItem() {
    var old: EnabledItem? = item(["Old"], ids: [1])
    weak var observed = old
    let c = bind(old!)
    c.set(item: item(["Current"], ids: [3]), context: nil)
    old = nil
    XCTAssertNil(observed)
  }
  func testCardTapAreaCoversItsReadableContent() {
    let c = bind(item(["Referral"], ids: [1]))
    c.frame = CGRect(x: 0, y: 0, width: 390, height: 250)
    c.layoutIfNeeded()
    let row = descendants(EnabledView.self, c).first
    XCTAssertFalse(row?.tappableArea.isHidden ?? true)
    XCTAssertFalse(row?.stackView.isUserInteractionEnabled ?? true)
  }
  func testCardEditorReloadsItsInitialModelOnce() {
    let m = EditingScreenModel()
    let v = make(m)
    v.loadViewIfNeeded()
    XCTAssertEqual(m.reloads, 1)
  }
  func testPublishedCardsRenderInTheEditor() async throws {
    let m = EditingScreenModel()
    let v = make(m)
    m.snapshot = snapshot(["Current"])
    await settle()
    XCTAssertEqual(try renderedTitles(v), ["Current"])
  }
  func testReplacingEditorModelIgnoresOldPublishedCards() async throws {
    let old = EditingScreenModel()
    let v = make(old)
    let current = EditingScreenModel()
    current.snapshot = snapshot(["Current"])
    v.viewModel = current
    await settle()
    old.snapshot = snapshot(["Obsolete"])
    await settle()
    XCTAssertEqual(try renderedTitles(v), ["Current"])
  }
  func testClearingEditorModelStopsOldPublishedCards() async throws {
    let old = EditingScreenModel()
    let v = make(old)
    old.snapshot = snapshot(["Initial"])
    await settle()
    v.viewModel = nil
    old.snapshot = snapshot(["Obsolete"])
    await settle()
    XCTAssertEqual(try renderedTitles(v), ["Initial"])
  }
  func testReplacingLoadedEditorModelReloadsItsCurrentData() async {
    let old = EditingScreenModel()
    let v = make(old)
    let current = EditingScreenModel()
    v.viewModel = current
    await settle()
    XCTAssertEqual(current.reloads, 1)
  }
  func testEditorCompletionUsesTheCurrentModel() {
    let old = EditingScreenModel()
    let v = make(old)
    let current = EditingScreenModel()
    var oldCalls = 0
    var currentCalls = 0
    old.completion = { oldCalls += 1 }
    current.completion = { currentCalls += 1 }
    v.viewModel = current
    v.viewWillDisappear(false)
    XCTAssertEqual(oldCalls, 0)
    XCTAssertEqual(currentCalls, 1)
  }
  func testEditorCanCloseWithoutACompletion() {
    let v = make(EditingScreenModel())
    v.viewWillDisappear(false)
    XCTAssertNotNil(v.navigationItem.leftBarButtonItem ?? v.navigationItem.rightBarButtonItem)
  }
  func testEditorModelIsReleasedAfterReplacement() async {
    var old: EditingScreenModel? = EditingScreenModel()
    weak var observed = old
    let v = make(old!)
    v.viewModel = EditingScreenModel()
    old = nil
    await settle()
    XCTAssertNil(observed)
  }
  func testEditorControllerIsReleasedWithSubscriptions() async {
    let m = EditingScreenModel()
    var v: EditViewController? = make(m)
    weak var observed = v
    v = nil
    await settle()
    XCTAssertNil(observed)
  }
  func testEditorSnapshotReplacementCanRemoveEveryRow() async throws {
    let m = EditingScreenModel()
    let v = make(m)
    m.snapshot = snapshot(["Current"])
    await settle()
    m.snapshot = EditViewSnapshot()
    await settle()
    XCTAssertEqual(try table(v).numberOfSections, 0)
  }
}
private final class EditingScreenModel: EditViewModelProtocol {
  @Published var snapshot = EditViewSnapshot()
  var snapshotPublisher: Published<EditViewSnapshot>.Publisher { $snapshot }
  var completion: (() -> Void)?, reloads = 0
  func reloadView(with section: EnabledSection?) { reloads += 1 }
}
