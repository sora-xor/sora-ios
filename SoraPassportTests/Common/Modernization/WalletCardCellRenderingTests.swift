import SoraUIKit
// SPDX-License-Identifier: BSD-4-Clause
import UIKit
import XCTest

@testable import SoraPassport

@MainActor final class WalletCardCellRenderingTests: XCTestCase {
  private func descendants(_ view: UIView) -> [UIView] {
    [view] + view.subviews.flatMap { descendants($0) }
  }
  private func rows(_ cell: EnabledCell) -> [EnabledView] {
    descendants(cell).compactMap { $0 as? EnabledView }
  }
  private func item(_ values: [(Int, String, State)]) -> EnabledItem {
    let i = EnabledItem()
    i.enabledViewModels = values.map { EnabledViewModel(id: $0.0, title: $0.1, state: $0.2) }
    return i
  }
  private var enabled: Int {
    ApplicationConfig.shared.getAvailableApplicationSections().first ?? Cards.referralProgram.id
  }
  func testEmptyItemHasNoVisibleCardRows() {
    let c = EnabledCell()
    c.set(item: item([]), context: nil)
    XCTAssertTrue(rows(c).isEmpty)
  }
  func testEnabledCardDisplaysItsTitle() {
    let c = EnabledCell()
    c.set(item: item([(enabled, "Referral", .selected)]), context: nil)
    XCTAssertEqual(rows(c).first?.titleLabel.sora.text, "Referral")
  }
  func testDisabledCardDisplaysItsTitle() {
    let c = EnabledCell()
    c.set(item: item([(-1, "Unavailable", .selected)]), context: nil)
    XCTAssertEqual(rows(c).first?.titleLabel.sora.text, "Unavailable")
  }
  func testEnabledSelectedCardShowsAnEnabledCheckmark() {
    let c = EnabledCell()
    c.set(item: item([(enabled, "Card", .selected)]), context: nil)
    XCTAssertEqual(rows(c).first?.checkmarkButton.isEnabled, true)
  }
  func testEnabledDisabledCardShowsADisabledCheckmark() {
    let c = EnabledCell()
    c.set(item: item([(enabled, "Card", .disabled)]), context: nil)
    XCTAssertEqual(rows(c).first?.checkmarkButton.isEnabled, false)
  }
  func testEnabledCardTapReportsItsStableIdentifier() {
    let c = EnabledCell()
    let i = item([(enabled, "Card", .selected)])
    var values = [Int]()
    i.onTap = { values.append($0) }
    c.set(item: i, context: nil)
    rows(c).first?.tappableArea.sendActions(for: .touchUpInside)
    XCTAssertEqual(values, [enabled])
  }
  func testDisabledCardTapReportsItsStableIdentifier() {
    let c = EnabledCell()
    let i = item([(-1, "Card", .disabled)])
    var values = [Int]()
    i.onTap = { values.append($0) }
    c.set(item: i, context: nil)
    rows(c).first?.tappableArea.sendActions(for: .touchUpInside)
    XCTAssertEqual(values, [-1])
  }
  func testRebindingRemovesOldRows() {
    let c = EnabledCell()
    c.set(item: item([(enabled, "Old", .selected), (-1, "Unavailable", .disabled)]), context: nil)
    c.set(item: item([(enabled, "New", .selected)]), context: nil)
    XCTAssertEqual(rows(c).count, 1)
    XCTAssertEqual(rows(c).first?.titleLabel.sora.text, "New")
  }
  func testRebindingToEmptyRemovesBothSectionsRows() {
    let c = EnabledCell()
    c.set(item: item([(enabled, "Old", .selected), (-1, "Unavailable", .disabled)]), context: nil)
    c.set(item: item([]), context: nil)
    XCTAssertTrue(rows(c).isEmpty)
  }
  func testRebindingDoesNotAccumulateTapHandlers() {
    let c = EnabledCell()
    let old = item([(enabled, "Old", .selected)])
    let new = item([(enabled, "New", .selected)])
    var oldCalls = 0
    var newCalls = 0
    old.onTap = { _ in oldCalls += 1 }
    new.onTap = { _ in newCalls += 1 }
    c.set(item: old, context: nil)
    c.set(item: new, context: nil)
    rows(c).first?.tappableArea.sendActions(for: .touchUpInside)
    XCTAssertEqual(oldCalls, 0)
    XCTAssertEqual(newCalls, 1)
  }
  func testDiscardedCardItemIsNotRetainedByRemovedRows() {
    let c = EnabledCell()
    var old: EnabledItem? = item([(enabled, "Old", .selected)])
    weak let weakOld = old
    c.set(item: old!, context: nil)
    let priorRows = rows(c)
    c.set(item: item([]), context: nil)
    old = nil
    XCTAssertNil(weakOld)
    withExtendedLifetime(priorRows) {}
  }
  func testRenderingUnavailableCardDoesNotMutateItsInputModel() {
    let c = EnabledCell()
    let i = item([(-1, "Unavailable", .selected)])
    c.set(item: i, context: nil)
    XCTAssertEqual(i.enabledViewModels.first?.state, .selected)
  }
  func testCardsRemainInTheirInputOrderWithinEachSection() {
    let c = EnabledCell()
    c.set(item: item([(-1, "One", .disabled), (-2, "Two", .disabled)]), context: nil)
    XCTAssertEqual(rows(c).map { $0.titleLabel.sora.text }, ["One", "Two"])
  }
  func testCardTappableAreaCoversTheWholeRow() {
    let v = EnabledView()
    v.frame = CGRect(x: 0, y: 0, width: 280, height: 56)
    v.layoutIfNeeded()
    XCTAssertEqual(v.tappableArea.frame, v.bounds)
    XCTAssertEqual(v.stackView.frame, v.bounds)
  }
  func testNestedCardLabelsDoNotInterceptTouches() {
    let v = EnabledView()
    XCTAssertFalse(v.titleLabel.isUserInteractionEnabled)
    XCTAssertFalse(v.checkmarkButton.isUserInteractionEnabled)
    XCTAssertFalse(v.stackView.isUserInteractionEnabled)
  }
  func testNewCardStartsWithItsTapAreaHidden() {
    XCTAssertTrue(EnabledView().tappableArea.isHidden)
  }
  func testBindingMakesTheCardTapAreaVisible() {
    let c = EnabledCell()
    c.set(item: item([(enabled, "Card", .selected)]), context: nil)
    XCTAssertEqual(rows(c).first?.tappableArea.isHidden, false)
  }
  func testCardItemDeclaresTheMatchingCellAndAllowsOverflow() {
    let i = EnabledItem()
    XCTAssertTrue(i.cellType === EnabledCell.self)
    XCTAssertFalse(i.clipsToBounds)
  }
}
