// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0
import SoraFoundation
import SoraUIKit
import UIKit
import XCTest
@testable import SoraPassport

@MainActor
final class MoreMenuLifecycleTests: XCTestCase {
    private func pause() async { try? await Task.sleep(nanoseconds: 40_000_000) }
    private func item(_ title: String = "Fixture", subtitle: String = "Current", subtitleStream: AsyncStream<String?>? = nil,
                      color: SoramitsuColor? = nil, colorStream: AsyncStream<SoramitsuColor?>? = nil,
                      onTap: (() -> Void)? = nil) -> MoreMenuItem {
        MoreMenuItem(title: title, subtitle: subtitle, subtitleStream: subtitleStream, picture: nil, circleColor: color, circleColorStream: colorStream, onTap: onTap)
    }
    private func stream<T>() -> (AsyncStream<T>, AsyncStream<T>.Continuation) {
        var continuation: AsyncStream<T>.Continuation!; let stream = AsyncStream<T> { continuation = $0 }; return (stream, continuation)
    }
    private func descendants<T: UIView>(_ type: T.Type, in view: UIView) -> [T] {
        ((view as? T).map { [$0] } ?? []) + view.subviews.flatMap { descendants(type, in: $0) }
    }
    func testMenuCellReplacesTextAndStatusCircleOnReuse() {
        let cell = MoreMenuCell(style: .default, reuseIdentifier: nil); cell.set(item: item("Old", subtitle: "Connected", color: .statusSuccess), context: nil)
        XCTAssertFalse(cell.categoryItem.circle.isHidden)
        cell.set(item: item("New", subtitle: "Disconnected"), context: nil)
        XCTAssertEqual(cell.categoryItem.titleLabel.text, "New"); XCTAssertEqual(cell.categoryItem.subtitleLabel.text, "Disconnected"); XCTAssertTrue(cell.categoryItem.circle.isHidden)
    }
    func testMenuCellPublishesCurrentSubtitleStreamAndNil() async {
        let (updates, continuation): (AsyncStream<String?>, AsyncStream<String?>.Continuation) = stream(); defer { continuation.finish() }
        let cell = MoreMenuCell(style: .default, reuseIdentifier: nil); let row = item(subtitleStream: updates); cell.set(item: row, context: nil)
        continuation.yield("Reconnected"); await pause(); XCTAssertEqual(cell.categoryItem.subtitleLabel.text, "Reconnected")
        continuation.yield(nil); await pause(); XCTAssertTrue((cell.categoryItem.subtitleLabel.text ?? "").isEmpty)
    }
    func testOldSubtitleStreamCannotOverwriteAReusedCell() async {
        let (updates, continuation): (AsyncStream<String?>, AsyncStream<String?>.Continuation) = stream(); defer { continuation.finish() }
        let cell = MoreMenuCell(style: .default, reuseIdentifier: nil); let old = item("Old", subtitleStream: updates)
        cell.set(item: old, context: nil); continuation.yield("Old live value"); await pause()
        cell.set(item: item("Current", subtitle: "Fresh"), context: nil); continuation.yield("Stale value"); await pause()
        XCTAssertEqual(cell.categoryItem.subtitleLabel.text, "Fresh")
    }
    func testOldStatusStreamCannotShowACircleForTheNewRow() async {
        let (updates, continuation): (AsyncStream<SoramitsuColor?>, AsyncStream<SoramitsuColor?>.Continuation) = stream(); defer { continuation.finish() }
        let cell = MoreMenuCell(style: .default, reuseIdentifier: nil); let old = item("Old", colorStream: updates)
        cell.set(item: old, context: nil); continuation.yield(.statusSuccess); await pause(); XCTAssertFalse(cell.categoryItem.circle.isHidden)
        cell.set(item: item("Current"), context: nil); continuation.yield(.statusSuccess); await pause(); XCTAssertTrue(cell.categoryItem.circle.isHidden)
    }
    func testCurrentStatusStreamCanShowThenHideACircle() async {
        let (updates, continuation): (AsyncStream<SoramitsuColor?>, AsyncStream<SoramitsuColor?>.Continuation) = stream(); defer { continuation.finish() }
        let cell = MoreMenuCell(style: .default, reuseIdentifier: nil); let row = item(colorStream: updates); cell.set(item: row, context: nil)
        continuation.yield(.statusSuccess); await pause(); XCTAssertFalse(cell.categoryItem.circle.isHidden)
        continuation.yield(nil); await pause(); XCTAssertTrue(cell.categoryItem.circle.isHidden)
    }
    func testPreparingCellForReuseStopsItsStreams() async {
        let (updates, continuation): (AsyncStream<String?>, AsyncStream<String?>.Continuation) = stream(); defer { continuation.finish() }
        let cell = MoreMenuCell(style: .default, reuseIdentifier: nil); let row = item(subtitleStream: updates); cell.set(item: row, context: nil)
        continuation.yield("Before reuse"); await pause(); cell.prepareForReuse(); continuation.yield("After reuse"); await pause()
        XCTAssertNotEqual(cell.categoryItem.subtitleLabel.text, "After reuse")
    }
    func testLiveSubtitleStreamDoesNotRetainDiscardedCell() async {
        let (updates, continuation): (AsyncStream<String?>, AsyncStream<String?>.Continuation) = stream(); defer { continuation.finish() }
        weak var released: MoreMenuCell?
        do { let cell = MoreMenuCell(style: .default, reuseIdentifier: nil); released = cell; cell.set(item: item(subtitleStream: updates), context: nil); await pause() }
        await pause(); XCTAssertNil(released)
    }
    func testMenuCellUsesCurrentLanguageDirection() {
        let previous = LocalizationManager.shared.selectedLocalization; defer { LocalizationManager.shared.selectedLocalization = previous }
        let cell = MoreMenuCell(style: .default, reuseIdentifier: nil)
        LocalizationManager.shared.selectedLocalization = "ar"; cell.set(item: item(), context: nil)
        XCTAssertEqual(cell.categoryItem.titleLabel.textAlignment, .right); XCTAssertEqual(cell.categoryItem.horizontalStack.semanticContentAttribute, .forceRightToLeft)
        LocalizationManager.shared.selectedLocalization = "en"; cell.updateLayout()
        XCTAssertEqual(cell.categoryItem.titleLabel.textAlignment, .left); XCTAssertEqual(cell.categoryItem.horizontalStack.semanticContentAttribute, .forceLeftToRight)
    }
    func testMenuItemActionUsesItsOwnHandlerAndRowsKeepDistinctIdentity() {
        var calls = 0; let first = item(onTap: { calls += 1 }); let second = item(); first.itemActionTap(with: nil); second.itemActionTap(with: nil)
        XCTAssertEqual(calls, 1); XCTAssertNotEqual(first, second)
        XCTAssertNotEqual(MoreMenuSection(items: [first]), MoreMenuSection(items: [first]))
    }
    func testMenuScreenReloadsOnEachAppearance() {
        let model = MenuLifecyclePresenter(); let screen = MoreMenuViewController(); screen.presenter = model; screen.loadViewIfNeeded()
        screen.viewWillAppear(false); screen.viewWillAppear(false); XCTAssertEqual(model.loads, 2)
        screen.set(title: "More fixture"); XCTAssertEqual(screen.navigationItem.title, "More fixture")
    }
    func testMenuScreenRendersSectionsAndDispatchesOnlySelectedAction() async throws {
        let screen = MoreMenuViewController(); screen.loadViewIfNeeded(); screen.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        var firstCalls = 0; var secondCalls = 0
        let first = item("Accounts", onTap: { firstCalls += 1 }); let second = item("Preferences", onTap: { secondCalls += 1 })
        let sections = [MoreMenuSection(items: [first]), MoreMenuSection(items: [second])]
        var snapshot = MoreMenuSnapshot(); snapshot.appendSections(sections); snapshot.appendItems([first], toSection: sections[0]); snapshot.appendItems([second], toSection: sections[1]); screen.update(snapshot: snapshot)
        screen.view.layoutIfNeeded(); await pause(); let table = try XCTUnwrap(descendants(UITableView.self, in: screen.view).first)
        XCTAssertEqual(table.numberOfSections, 2); XCTAssertEqual(table.numberOfRows(inSection: 1), 1)
        screen.tableView(table, didSelectRowAt: IndexPath(row: 0, section: 1)); XCTAssertEqual(firstCalls, 0); XCTAssertEqual(secondCalls, 1)
        screen.tableView(table, didSelectRowAt: IndexPath(row: 99, section: 0)); XCTAssertEqual(secondCalls, 1)
        XCTAssertNotNil(screen.tableView(table, viewForFooterInSection: 0))
    }
    func testMenuScreenEmptySnapshotRemovesPreviousRows() async throws {
        let screen = MoreMenuViewController(); screen.loadViewIfNeeded(); var snapshot = MoreMenuSnapshot(); let section = MoreMenuSection(items: [])
        snapshot.appendSections([section]); snapshot.appendItems([item()], toSection: section); screen.update(snapshot: snapshot); await pause()
        screen.update(snapshot: MoreMenuSnapshot()); await pause(); XCTAssertEqual(try XCTUnwrap(descendants(UITableView.self, in: screen.view).first).numberOfSections, 0)
    }
    func testMenuPresenterRoutesEveryActionThroughItsWireframe() {
        let model = MoreMenuPresenter(); let routes = MenuLifecycleRoutes(); model.wireframe = routes
        model.showAccounts(); model.showNexusPortfolio(); model.showPolkamarkt(); model.showNodes(); model.showAppSettings(); model.showLoginAndSecurity(); model.showInviteFriends(); model.showInformation()
        XCTAssertEqual(routes.calls, ["accounts", "nexus", "polkamarkt", "nodes", "settings", "security", "friends", "information"])
    }
}
private final class MenuLifecyclePresenter: MoreMenuPresenterProtocol { weak var view: MoreMenuViewProtocol?; var loads = 0; func reload() { loads += 1 } }
private final class MenuLifecycleRoutes: MoreMenuWireframeProtocol {
    var calls: [String] = []
    func showChangeAccountView(from view: MoreMenuViewProtocol?) { calls.append("accounts") }
    func showNexusPortfolio(from view: MoreMenuViewProtocol?) { calls.append("nexus") }
    func showPolkamarkt(from view: MoreMenuViewProtocol?) { calls.append("polkamarkt") }
    func showFriendsView(from view: MoreMenuViewProtocol?) { calls.append("friends") }
    func showNodes(from view: MoreMenuViewProtocol?) { calls.append("nodes") }
    func showInformation(from view: MoreMenuViewProtocol?) { calls.append("information") }
    func showAppSettings(from view: MoreMenuViewProtocol?) { calls.append("settings") }
    func showSecurity(from view: MoreMenuViewProtocol?) { calls.append("security") }
}
