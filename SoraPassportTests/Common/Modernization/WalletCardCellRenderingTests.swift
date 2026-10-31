import SoraUIKit
// SPDX-License-Identifier: Apache-2.0
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

@MainActor final class PortfolioSurfaceInteractionTests: XCTestCase {
    private let segments = [
        PortfolioFanSegment(key: "first", slot: .slot(0), rays: 40, value: 40, share: Decimal(string: "0.4")!, members: []),
        PortfolioFanSegment(key: "second", slot: .slot(1), rays: 60, value: 60, share: Decimal(string: "0.6")!, members: [])
    ]
    private func sky(shows: Bool = true) -> PortfolioSkyView {
        let view = PortfolioSkyView(frame: CGRect(x: 0, y: 0, width: 390, height: 400))
        view.apply(.init(segments: segments, highlightedKey: nil, showsFan: shows), animated: false)
        view.layoutIfNeeded(); return view
    }
    /// The middle of a ray on the ring's band, on screen, as the ring is drawn now.
    private func point(_ ray: Int, in sky: PortfolioSkyView) -> CGPoint { sky.pose.point(sky.rayAngle(ray)) }
    private func descendants<T: UIView>(_ type: T.Type, _ view: UIView) -> [T] {
        ((view as? T).map { [$0] } ?? []) + view.subviews.flatMap { descendants(type, $0) }
    }
    private func hiddenByPlanet(_ ray: Int, in sky: PortfolioSkyView) -> Bool {
        let p = point(ray, in: sky)
        return sin(sky.rayAngle(ray) * .pi / 180) < 0 &&
            hypot(p.x - sky.planetCenter.x, p.y - sky.planetCenter.y) < PortfolioTheme.Sky.planetRadius
    }
    func testRingHitTestingPreservesExactAllocationBoundaryUnlessThePlanetHidesIt() {
        let view = sky()
        for ray in 0..<100 {
            let expected = hiddenByPlanet(ray, in: view) ? nil : (ray < 40 ? "first" : "second")
            XCTAssertEqual(view.segmentKey(at: point(ray, in: view)), expected, "ray \(ray)")
        }
    }
    func testHiddenFanAllowsTouchesToReachControlsBeneathIt() {
        let view = sky(shows: false); let p = point(50, in: view)
        XCTAssertNil(view.segmentKey(at: p)); XCTAssertFalse(view.point(inside: p, with: nil))
    }
    func testPlanetAndSkyAroundTheRingDoNotInterceptTouches() {
        let view = sky(); let pose = view.pose
        for p in [view.planetCenter, pose.point(0, radius: pose.radius * 1.5), pose.point(0, radius: pose.radius * 0.6),
                  CGPoint(x: view.planetCenter.x, y: view.planetCenter.y + 75)] {
            XCTAssertNil(view.segmentKey(at: p)); XCTAssertFalse(view.point(inside: p, with: nil))
        }
    }
    func testTheRingBehindThePlanetTakesNoTouches() {
        let view = sky()
        XCTAssertNil(view.segmentKey(at: view.pose.point(270)))
        XCTAssertEqual(view.segmentKey(at: view.pose.point(90)), "first")
    }
    func testASmallSegmentComesRoundToTheFrontInsteadOfHidingBehindThePlanet() {
        let lopsided = [
            PortfolioFanSegment(key: "main", slot: .slot(0), rays: 94, value: 94, share: Decimal(string: "0.94")!, members: []),
            PortfolioFanSegment(key: "small", slot: .slot(1), rays: 6, value: 6, share: Decimal(string: "0.06")!, members: [])
        ]
        let view = PortfolioSkyView(frame: CGRect(x: 0, y: 0, width: 390, height: 400))
        view.apply(.init(segments: lopsided, highlightedKey: nil, showsFan: true), animated: false)
        view.layoutIfNeeded()
        for (x, y) in [(0, 1), (0, -1), (1, 0)] as [(CGFloat, CGFloat)] {
            view.setTilt(x: x, y: y)
            XCTAssertEqual(view.segmentKey(at: view.pose.point(90)), "small")
            for ray in 94..<100 { XCTAssertEqual(view.segmentKey(at: point(ray, in: view)), "small", "ray \(ray)") }
        }
        XCTAssertEqual(PortfolioRing.start(lopsided) + 47 * PortfolioTheme.Sky.degreesPerRay, 270, accuracy: 1e-6)
    }
    func testOnlyRingSegmentsAcceptTouches() {
        let view = sky()
        XCTAssertTrue(view.point(inside: point(20, in: view), with: nil))
        XCTAssertTrue(view.point(inside: point(90, in: view), with: nil))
        XCTAssertTrue(view.accessibilityElementsHidden); XCTAssertFalse(view.isAccessibilityElement)
    }
    func testRingTapDeliversTheSegmentUnderTheGesture() {
        let view = sky(); var selected = [String](); view.onSegmentTap = { selected.append($0) }
        view.perform(NSSelectorFromString("handleTap:"), with: PortfolioTestTap(point(80, in: view)))
        view.perform(NSSelectorFromString("handleTap:"), with: PortfolioTestTap(view.planetCenter))
        XCTAssertEqual(selected, ["second"])
    }
    func testSafeAreaChangesMoveTheRingAndItsHitRegionsTogether() {
        let view = sky(); let before = view.planetCenter
        view.topInset = 55; view.layoutIfNeeded()
        XCTAssertEqual(view.planetCenter.y, before.y + 55)
        XCTAssertEqual(view.segmentKey(at: point(39, in: view)), "first")
        XCTAssertEqual(view.segmentKey(at: point(40, in: view)), "second")
    }
    func testTiltTurnsTheRingAndItsHitRegionsTogether() {
        let view = sky(); view.setTilt(x: 1, y: -1)
        XCTAssertEqual(view.pose.rollDeg, PortfolioTheme.Sky.rollDeg + PortfolioTheme.Sky.rollTiltDeg, accuracy: 1e-6)
        XCTAssertEqual(view.pose.aspect, PortfolioTheme.Sky.aspect - PortfolioTheme.Sky.aspectTilt, accuracy: 1e-6)
        XCTAssertEqual(view.segmentKey(at: point(39, in: view)), "first")
        XCTAssertEqual(view.segmentKey(at: point(40, in: view)), "second")
    }
    func testHighlightWidensOnlyItsSegmentAndDimsTheOther() throws {
        let view = sky(); let layers = view.segmentLayers
        XCTAssertEqual(layers.map(\.name), ["first", "second"])
        view.apply(.init(segments: segments, highlightedKey: "first", showsFan: true), animated: false)
        XCTAssertEqual(layers[0].opacity, 1); XCTAssertEqual(layers[1].opacity, PortfolioTheme.Sky.dimmedAlpha)
        XCTAssertGreaterThan(layers[0].lineWidth, layers[1].lineWidth)
    }
    func testAnimatedHighlightAnimatesTheBandWidthWhenMotionIsAllowed() throws {
        let view = sky()
        view.apply(.init(segments: segments, highlightedKey: "second", showsFan: true), animated: true)
        let layer = try XCTUnwrap(view.segmentLayers.last)
        if UIAccessibility.isReduceMotionEnabled { XCTAssertNil(layer.animation(forKey: "highlight")) }
        else { XCTAssertNotNil(layer.animation(forKey: "highlight") as? CABasicAnimation) }
        view.apply(.init(segments: segments, highlightedKey: nil, showsFan: true), animated: false)
        XCTAssertEqual(layer.opacity, 1)
    }
    func testLensSelectionDeliversCurrentLensAndRetappingDoesNothing() throws {
        let cell = PortfolioLensCell(style: .default, reuseIdentifier: nil); let item = PortfolioLensItem()
        var selected = [PortfolioLens](); item.onSelect = { selected.append($0) }; cell.set(item: item, context: nil)
        let buttons = descendants(UIButton.self, cell)
        buttons[0].sendActions(for: .touchUpInside); buttons[2].sendActions(for: .touchUpInside)
        XCTAssertEqual(selected, [.wallets])
    }
    func testLensReuseDisconnectsPreviousItemAndRejectsOutOfRangeIndex() throws {
        let cell = PortfolioLensCell(style: .default, reuseIdentifier: nil); let old = PortfolioLensItem(), current = PortfolioLensItem()
        var oldCalls = 0, selected = [PortfolioLens](); old.onSelect = { _ in oldCalls += 1 }
        current.lenses = [.networks, .wallets]; current.selected = .networks; current.onSelect = { selected.append($0) }
        cell.set(item: old, context: nil); cell.set(item: current, context: nil)
        let control = try XCTUnwrap(descendants(PortfolioSegmentedControl.self, cell).first)
        control.onSelect?(9); descendants(UIButton.self, control)[1].sendActions(for: .touchUpInside)
        old.selected = .wallets
        XCTAssertEqual(selected, [.wallets]); XCTAssertEqual(oldCalls, 0)
        XCTAssertEqual(descendants(UIButton.self, control).count, 2)
    }
    private func row(_ kind: PortfolioRow.Kind = .token) -> PortfolioRow {
        PortfolioRow(key: "token", kind: kind, icon: .token(id: "token", symbol: "XOR", icon: nil), title: "XOR", change: nil,
            direction: .flat, subtitle: "SORA", walletDots: [], value: "$10", detail: "2 XOR", tag: nil,
            isExpandable: true, isExpanded: false, children: [], link: nil, accessibilityLabel: "XOR, 2 tokens, $10")
    }
    private func child() -> PortfolioChildRow {
        PortfolioChildRow(key: "holding", icon: .network(.sora2), title: "SORA", subtitle: "Wallet", walletSlot: .slot(0),
            value: "$10", detail: "2 XOR", tag: nil, target: .holding("holding"), accessibilityLabel: "2 XOR on SORA")
    }
    func testTokenAccessibilityActionsKeepTheirDistinctIntent() throws {
        let view = PortfolioRowView(); view.configure(row(), showsSeparator: false)
        var calls = [PortfolioQuickAction?](); view.onCustomAction = { calls.append($0) }
        let actions = try XCTUnwrap(view.accessibilityCustomActions)
        XCTAssertEqual(actions.count, 3)
        for action in actions { XCTAssertEqual(action.actionHandler?(action), true) }
        XCTAssertEqual(calls, [nil, .move, .swap])
    }
    func testNonTokenRowClearsOldTokenAccessibilityActions() {
        let view = PortfolioRowView(); view.configure(row(), showsSeparator: false)
        XCTAssertNotNil(view.accessibilityCustomActions)
        view.configure(row(.network), showsSeparator: true)
        XCTAssertNil(view.accessibilityCustomActions)
    }
    func testPortfolioRowTapAndHighlightDoNotChangeItsAccessibleIdentity() {
        let view = PortfolioRowView(); view.configure(row(), showsSeparator: false); var taps = 0; view.onTap = { taps += 1 }
        view.sendActions(for: .touchUpInside); view.isHighlighted = true
        XCTAssertEqual(view.backgroundColor, PortfolioTheme.tokens.glassFillPressed)
        XCTAssertEqual(view.accessibilityLabel, row().accessibilityLabel)
        view.isHighlighted = false; XCTAssertEqual(view.backgroundColor, .clear); XCTAssertEqual(taps, 1)
    }
    func testExpandedHoldingTapAndHighlightKeepTheExactHolding() throws {
        let view = PortfolioWellView(); let expected = child(); var selected = [PortfolioChildRow]()
        view.configure([expected], link: nil); view.onChild = { selected.append($0) }
        let control = try XCTUnwrap(descendants(PortfolioChildRowView.self, view).first)
        control.isHighlighted = true; XCTAssertEqual(control.backgroundColor, PortfolioTheme.tokens.glassFillPressed)
        control.sendActions(for: .touchUpInside); control.isHighlighted = false
        XCTAssertEqual(selected, [expected]); XCTAssertEqual(control.backgroundColor, .clear)
    }
    func testExpandedWalletLinkIsIndependentFromHoldingSelection() throws {
        let view = PortfolioWellView(); var links = 0, children = 0
        view.configure([child()], link: "Open wallet"); view.onLink = { links += 1 }; view.onChild = { _ in children += 1 }
        try XCTUnwrap(descendants(UIButton.self, view).first).sendActions(for: .touchUpInside)
        XCTAssertEqual(links, 1); XCTAssertEqual(children, 0)
    }
}
private final class PortfolioTestTap: UITapGestureRecognizer {
    let point: CGPoint
    init(_ point: CGPoint) { self.point = point; super.init(target: nil, action: nil) }
    override func location(in view: UIView?) -> CGPoint { point }
}
