// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0
import UIKit
import XCTest

@testable import SoraPassport

@MainActor
final class SheetInteractionTests: XCTestCase {
  private func make(animated: Bool = false, offset: CGFloat = 120) -> (UIViewController, TestSheet)
  {
    let parent = UIViewController()
    parent.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
    let sheet = TestSheet()
    var completion = false
    parent.addPullUpController(sheet, initialOffset: offset, animated: animated) { value in
      completion = value
    }
    XCTAssertTrue(completion)
    return (parent, sheet)
  }
  func testAddingTheSheetEstablishesContainmentAndInitialVisibleHeight() {
    let (p, s) = make()
    XCTAssertTrue(s.parent === p)
    XCTAssertTrue(s.view.superview === p.view)
    XCTAssertEqual(s.pullUpControllerCurrentPointOffset, 120)
    XCTAssertEqual(s.view.frame.minY, 724)
    XCTAssertEqual(s.view.frame.width, 390)
  }
  func testAnimatedAdditionUsesTheAddTransitionBeforeCompletion() {
    let (p, s) = make(animated: true)
    XCTAssertTrue(s.parent === p)
    XCTAssertEqual(s.actions, ["add"])
    XCTAssertEqual(s.durations, [0.3])
  }
  func testMoveReportsWillThenDidAndInvokesCompletionAfterLayout() {
    let (p, s) = make()
    var completed = false
    s.pullUpControllerMoveToVisiblePoint(300, animated: false) {
      completed = true
      XCTAssertEqual(s.view.frame.minY, 544)
    }
    XCTAssertTrue(completed)
    XCTAssertEqual(s.events, ["will:300", "did:300"])
    XCTAssertEqual(s.pullUpControllerCurrentPointOffset, 300)
    XCTAssertTrue(s.parent === p)
  }
  func testAnimatedMoveUsesTheRequestedVisiblePoint() {
    let (p, s) = make()
    s.pullUpControllerMoveToVisiblePoint(500, animated: true, completion: nil)
    XCTAssertEqual(s.actions, ["move"])
    XCTAssertEqual(s.durations, [0.3])
    XCTAssertEqual(s.view.frame.minY, p.view.bounds.height - 500)
  }
  func testRemovingTheSheetReleasesContainmentBeforeCompletion() {
    let (p, s) = make()
    var complete = false
    p.removePullUpController(s, animated: false) { success in
      complete = success
      XCTAssertNil(s.parent)
      XCTAssertNil(s.view.superview)
    }
    XCTAssertTrue(complete)
    XCTAssertTrue(p.children.isEmpty)
  }
  func testAnimatedRemovalUsesTheRemoveTransition() {
    let (p, s) = make()
    p.removePullUpController(s, animated: true)
    XCTAssertEqual(s.actions, ["remove"])
    XCTAssertNil(s.parent)
    XCTAssertNil(s.view.superview)
  }
  func testReaddingASheetDoesNotAccumulateDragRecognizers() {
    let (p, s) = make()
    p.removePullUpController(s, animated: false)
    p.addPullUpController(s, initialOffset: 300)
    XCTAssertEqual(s.view.gestureRecognizers?.filter { $0 is UIPanGestureRecognizer }.count, 1)
    XCTAssertEqual(s.pullUpControllerCurrentPointOffset, 300)
  }
  func testReaddingASheetDoesNotAccumulateSizeConstraints() {
    let (p, s) = make()
    let count = s.view.constraints.filter { $0.isActive }.count
    p.removePullUpController(s, animated: false)
    p.addPullUpController(s, initialOffset: 300)
    XCTAssertEqual(s.view.constraints.filter { $0.isActive }.count, count)
  }
  func testResizingTheSheetUsesItsNewPreferredDimensions() {
    let (p, s) = make()
    s.preferredSize = CGSize(width: 350, height: 600)
    s.updatePreferredFrameIfNeeded(animated: false)
    p.view.layoutIfNeeded()
    XCTAssertEqual(s.view.frame.width, 350)
    XCTAssertEqual(s.pullUpControllerAllStickyPoints, [120, 300, 600])
    XCTAssertEqual(s.pullUpControllerCurrentPointOffset, 120)
  }
  func testStickyPointsAreSortedForGestureNavigation() {
    let s = TestSheet()
    s.middle = [300, 120]
    XCTAssertEqual(s.pullUpControllerAllStickyPoints, [120, 300, 500])
  }
  func testAnUnattachedSheetCanBeResizedSafely() {
    let s = TestSheet()
    s.updatePreferredFrameIfNeeded(animated: false)
    s.pullUpControllerMoveToVisiblePoint(120, animated: false, completion: nil)
    XCTAssertEqual(s.pullUpControllerCurrentPointOffset, 0)
    XCTAssertTrue(s.events.isEmpty)
  }
  func testDraggingTheSheetUpChangesVisibleHeightAndResetsTranslation() {
    let (p, s) = make()
    let pan = SheetPan(state: .changed, translation: -100)
    drag(s, pan)
    XCTAssertEqual(s.pullUpControllerCurrentPointOffset, 220)
    XCTAssertEqual(pan.translation(in: s.view), .zero)
    XCTAssertEqual(s.events, ["drag:220"])
    XCTAssertTrue(s.parent === p)
  }
  func testDraggingBeyondTheTopRespectsTheBounceAllowance() {
    let (p, s) = make()
    drag(s, SheetPan(state: .changed, translation: -1000))
    XCTAssertEqual(s.pullUpControllerCurrentPointOffset, 520)
    XCTAssertTrue(s.parent === p)
  }
  func testDraggingBeyondTheBottomRespectsTheBounceAllowance() {
    let (p, s) = make()
    drag(s, SheetPan(state: .changed, translation: 1000))
    XCTAssertEqual(s.pullUpControllerCurrentPointOffset, 100)
    XCTAssertTrue(s.parent === p)
  }
  func testSlowReleaseSettlesToTheNearestStickyPoint() {
    let (p, s) = make(offset: 270)
    drag(s, SheetPan(state: .ended, velocity: 50))
    XCTAssertEqual(s.pullUpControllerCurrentPointOffset, 300)
    XCTAssertEqual(s.events, ["drag:300", "will:300", "did:300"])
    XCTAssertTrue(s.parent === p)
  }
  func testFastDownwardReleaseSkipsToThePreviousStickyPoint() {
    let (p, s) = make(offset: 300)
    drag(s, SheetPan(state: .ended, velocity: 1000))
    XCTAssertEqual(s.pullUpControllerCurrentPointOffset, 120)
    XCTAssertTrue(s.parent === p)
  }
  func testFastUpwardReleaseSkipsToTheNextStickyPoint() {
    let (p, s) = make(offset: 300)
    drag(s, SheetPan(state: .ended, velocity: -1000))
    XCTAssertEqual(s.pullUpControllerCurrentPointOffset, 500)
    XCTAssertTrue(s.parent === p)
  }
  func testReleaseAtTheBoundaryDoesNotGoPastTheLastStickyPoint() {
    let (p, s) = make(offset: 500)
    drag(s, SheetPan(state: .ended, velocity: -1000))
    XCTAssertEqual(s.pullUpControllerCurrentPointOffset, 500)
    XCTAssertTrue(s.parent === p)
  }
  func testCancelledSheetDragSettlesInsteadOfLeavingAnOverscrollOffset() {
    let (p, s) = make()
    drag(s, SheetPan(state: .changed, translation: 1000))
    drag(s, SheetPan(state: .cancelled))
    XCTAssertEqual(s.pullUpControllerCurrentPointOffset, 120)
    XCTAssertTrue(s.parent === p)
  }
  func testScrollContentAtItsTopCanDragTheSheetDown() {
    let (p, s) = make(offset: 300)
    let scroll = UIScrollView()
    scroll.attach(to: s)
    scrollDrag(s, SheetPan(state: .began, velocity: 50))
    scrollDrag(s, SheetPan(state: .changed, translation: 40, velocity: 50))
    XCTAssertEqual(s.pullUpControllerCurrentPointOffset, 260)
    XCTAssertFalse(scroll.bounces)
    XCTAssertEqual(scroll.contentOffset, .zero)
    scrollDrag(s, SheetPan(state: .ended, velocity: 20))
    XCTAssertTrue(scroll.bounces)
    XCTAssertEqual(s.pullUpControllerCurrentPointOffset, 300)
    XCTAssertTrue(s.parent === p)
  }
  func testScrolledContentDoesNotDragAnExpandedSheet() {
    let (p, s) = make(offset: 500)
    let scroll = UIScrollView()
    scroll.contentOffset.y = 100
    scroll.attach(to: s)
    scrollDrag(s, SheetPan(state: .began, velocity: 10))
    scrollDrag(s, SheetPan(state: .changed, translation: 40, velocity: 10))
    XCTAssertEqual(s.pullUpControllerCurrentPointOffset, 500)
    XCTAssertEqual(scroll.contentOffset.y, 100)
    XCTAssertTrue(s.parent === p)
  }
  func testUpwardScrollExpandsAPartiallyOpenedSheet() {
    let (p, s) = make()
    let scroll = UIScrollView()
    scroll.attach(to: s)
    scrollDrag(s, SheetPan(state: .began, velocity: -50))
    scrollDrag(s, SheetPan(state: .changed, translation: -80, velocity: -50))
    XCTAssertEqual(s.pullUpControllerCurrentPointOffset, 200)
    XCTAssertTrue(s.parent === p)
  }
  func testCancelledScrollRestoresBouncingAndSettlesTheSheet() {
    let (p, s) = make(offset: 300)
    let scroll = UIScrollView()
    scroll.attach(to: s)
    scrollDrag(s, SheetPan(state: .began, velocity: 50))
    scrollDrag(s, SheetPan(state: .changed, translation: 40, velocity: 50))
    scrollDrag(s, SheetPan(state: .cancelled))
    XCTAssertTrue(scroll.bounces)
    XCTAssertEqual(s.pullUpControllerCurrentPointOffset, 300)
    XCTAssertTrue(s.parent === p)
  }
  func testDetachingAnOldScrollViewDoesNotDisconnectItsReplacement() {
    let (p, s) = make(offset: 300)
    let old = UIScrollView()
    let current = UIScrollView()
    old.attach(to: s)
    current.attach(to: s)
    old.detach(from: s)
    scrollDrag(s, SheetPan(state: .began, velocity: 50))
    scrollDrag(s, SheetPan(state: .changed, translation: 40, velocity: 50))
    XCTAssertEqual(s.pullUpControllerCurrentPointOffset, 260)
    XCTAssertFalse(current.bounces)
    XCTAssertTrue(s.parent === p)
  }
  func testDetachingTheActiveScrollViewStopsMovingTheSheet() {
    let (p, s) = make(offset: 300)
    let scroll = UIScrollView()
    scroll.attach(to: s)
    scroll.detach(from: s)
    scrollDrag(s, SheetPan(state: .changed, translation: 40, velocity: 50))
    XCTAssertEqual(s.pullUpControllerCurrentPointOffset, 300)
    XCTAssertTrue(s.parent === p)
  }
  func testLandscapeParentUsesThePreferredLandscapeFrame() {
    let parent = UIViewController()
    parent.view.frame = CGRect(x: 0, y: 0, width: 844, height: 390)
    let sheet = TestSheet()
    parent.addPullUpController(sheet, initialOffset: 120)
    XCTAssertEqual(sheet.view.frame, CGRect(x: 10, y: 20, width: 280, height: 340))
  }
  func testLandscapeSheetDoesNotApplyPortraitProgrammaticMovement() {
    let parent = UIViewController()
    parent.view.frame = CGRect(x: 0, y: 0, width: 844, height: 390)
    let sheet = TestSheet()
    parent.addPullUpController(sheet, initialOffset: 120)
    sheet.pullUpControllerMoveToVisiblePoint(300, animated: false, completion: nil)
    XCTAssertEqual(sheet.view.frame.minY, 20)
    XCTAssertTrue(sheet.events.isEmpty)
  }
  func testLandscapeSheetDoesNotRespondToPortraitDragOffsets() {
    let parent = UIViewController()
    parent.view.frame = CGRect(x: 0, y: 0, width: 844, height: 390)
    let sheet = TestSheet()
    parent.addPullUpController(sheet, initialOffset: 120)
    drag(sheet, SheetPan(state: .changed, translation: 80))
    XCTAssertEqual(sheet.view.frame.minY, 20)
    XCTAssertTrue(sheet.events.isEmpty)
  }
  private func drag(_ sheet: TestSheet, _ pan: SheetPan) {
    sheet.perform(NSSelectorFromString("handlePanGestureRecognizer:"), with: pan)
  }
  private func scrollDrag(_ sheet: TestSheet, _ pan: SheetPan) {
    sheet.perform(NSSelectorFromString("handleScrollViewGestureRecognizer:"), with: pan)
  }
}
private final class TestSheet: PullUpController {
  var preferredSize = CGSize(width: 390, height: 500)
  var middle: [CGFloat] = [120, 300]
  var actions: [String] = [], durations: [TimeInterval] = [], events: [String] = []
  override var pullUpControllerPreferredLandscapeFrame: CGRect {
    CGRect(x: 10, y: 20, width: 280, height: 340)
  }
  override var pullUpControllerPreferredSize: CGSize { preferredSize }
  override var pullUpControllerMiddleStickyPoints: [CGFloat] { middle }
  override var pullUpControllerBounceOffset: CGFloat { 20 }
  override func pullUpControllerAnimate(
    action: PullUpController.Action, withDuration duration: TimeInterval,
    animations: @escaping () -> Void, completion: ((Bool) -> Void)?
  ) {
    switch action {
    case .add: actions.append("add")
    case .move: actions.append("move")
    case .remove: actions.append("remove")
    }
    durations.append(duration)
    animations()
    completion?(true)
  }
  override func pullUpControllerWillMove(to point: CGFloat) { events.append("will:\(Int(point))") }
  override func pullUpControllerDidMove(to point: CGFloat) { events.append("did:\(Int(point))") }
  override func pullUpControllerDidDrag(to point: CGFloat) { events.append("drag:\(Int(point))") }
}
private final class SheetPan: UIPanGestureRecognizer {
  private var simulatedState: UIGestureRecognizer.State
  private var simulatedTranslation: CGPoint
  private var simulatedVelocity: CGPoint
  init(state: UIGestureRecognizer.State, translation: CGFloat = 0, velocity: CGFloat = 0) {
    simulatedState = state
    simulatedTranslation = CGPoint(x: 0, y: translation)
    simulatedVelocity = CGPoint(x: 0, y: velocity)
    super.init(target: nil, action: nil)
  }
  override var state: UIGestureRecognizer.State {
    get { simulatedState }
    set { simulatedState = newValue }
  }
  override func translation(in view: UIView?) -> CGPoint { simulatedTranslation }
  override func velocity(in view: UIView?) -> CGPoint { simulatedVelocity }
  override func setTranslation(_ translation: CGPoint, in view: UIView?) {
    simulatedTranslation = translation
  }
}
