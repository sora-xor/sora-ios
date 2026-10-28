// SPDX-License-Identifier: Apache-2.0
import UIKit
import XCTest

@testable import SoraPassport

@MainActor final class NavigationTransitionLifecycleTests: XCTestCase {
  private func run(_ context: TransitionContext, presenting: Bool = true) async {
    let done = expectation(description: "transition completion")
    context.onComplete = { done.fulfill() }
    TransitionManager(presenting: presenting).animateTransition(using: context)
    await fulfillment(of: [done], timeout: 1.5)
  }
  func testPushAnimatorDeclaresItsBoundedDuration() {
    XCTAssertEqual(TransitionManager(presenting: true).transitionDuration(using: nil), 0.5)
  }
  func testPushCompletesAndPresentsTheDestination() async {
    let c = TransitionContext()
    await run(c)
    XCTAssertEqual(c.completed, true)
    XCTAssertTrue(c.containerView.subviews.last === c.to)
    XCTAssertEqual(c.to.frame, c.frame)
    XCTAssertEqual(c.to.alpha, 1)
  }
  func testPopCompletesAndRestoresDestinationPosition() async {
    let c = TransitionContext()
    await run(c, presenting: false)
    XCTAssertEqual(c.completed, true)
    XCTAssertTrue(c.containerView.subviews.last === c.to)
    XCTAssertEqual(c.to.frame, c.frame)
  }
  func testCancelledPushRestoresTheSourceFrame() async {
    let c = TransitionContext()
    c.cancelled = true
    await run(c)
    XCTAssertEqual(c.completed, false)
    XCTAssertEqual(c.from.frame, c.frame)
  }
  func testCancelledPushRestoresSourceVisibility() async {
    let c = TransitionContext()
    c.cancelled = true
    await run(c)
    XCTAssertEqual(c.from.alpha, 1)
  }
  func testCancelledPushRemovesTheAbortedDestination() async {
    let c = TransitionContext()
    c.cancelled = true
    await run(c)
    XCTAssertNil(c.to.superview)
    XCTAssertTrue(c.containerView.subviews.last === c.from)
  }
  func testCancelledPopRestoresTheSourceFrame() async {
    let c = TransitionContext()
    c.cancelled = true
    await run(c, presenting: false)
    XCTAssertEqual(c.from.frame, c.frame)
    XCTAssertEqual(c.completed, false)
  }
  func testCancelledPopRestoresSourceVisibility() async {
    let c = TransitionContext()
    c.cancelled = true
    await run(c, presenting: false)
    XCTAssertEqual(c.from.alpha, 1)
  }
  func testMissingSourceCompletesTheTransitionAsFailed() {
    let c = TransitionContext()
    c.omitSource = true
    TransitionManager(presenting: true).animateTransition(using: c)
    XCTAssertEqual(c.completed, false)
  }
  func testMissingDestinationCompletesTheTransitionAsFailed() {
    let c = TransitionContext()
    c.omitTarget = true
    TransitionManager(presenting: true).animateTransition(using: c)
    XCTAssertEqual(c.completed, false)
  }
  func testCoordinatorSelectsPushAnimator() {
    let c = TransitionCoordinator()
    let a =
      c.navigationController(
        UINavigationController(), animationControllerFor: .push, from: UIViewController(),
        to: UIViewController()) as? TransitionManager
    XCTAssertEqual(a?.presenting, true)
  }
  func testCoordinatorSelectsPopAnimator() {
    let c = TransitionCoordinator()
    let a =
      c.navigationController(
        UINavigationController(), animationControllerFor: .pop, from: UIViewController(),
        to: UIViewController()) as? TransitionManager
    XCTAssertEqual(a?.presenting, false)
  }
  func testCoordinatorHasNoAnimatorForNoOperation() {
    let c = TransitionCoordinator()
    XCTAssertNil(
      c.navigationController(
        UINavigationController(), animationControllerFor: .none, from: UIViewController(),
        to: UIViewController()))
  }
  func testCoordinatorReturnsTheCurrentInteraction() {
    let c = TransitionCoordinator()
    let i = UIPercentDrivenInteractiveTransition()
    c.interactionController = i
    XCTAssertTrue(
      c.navigationController(
        UINavigationController(), interactionControllerFor: TransitionManager(presenting: true))
        === i)
  }
  func testCustomTransitionInstallationIsIdempotent() {
    let n = UINavigationController()
    n.addCustomTransitioning()
    let helper = n.transitionCoordinatorHelper
    let gestures = n.view.gestureRecognizers?.count
    n.addCustomTransitioning()
    XCTAssertTrue(n.transitionCoordinatorHelper === helper)
    XCTAssertEqual(n.view.gestureRecognizers?.count, gestures)
    XCTAssertTrue(n.delegate === helper)
  }
  func testInstalledSwipeBeginsAtTheLeadingEdge() {
    let n = UINavigationController()
    n.addCustomTransitioning()
    let swipe = n.view.gestureRecognizers?.compactMap { $0 as? UIScreenEdgePanGestureRecognizer }
      .first
    XCTAssertEqual(swipe?.edges, .left)
  }
  func testDetachedSwipeClearsTheInteraction() {
    let n = UINavigationController()
    n.addCustomTransitioning()
    n.transitionCoordinatorHelper?.interactionController = UIPercentDrivenInteractiveTransition()
    n.handleSwipe(TransitionSwipe())
    XCTAssertNil(n.transitionCoordinatorHelper?.interactionController)
  }
  func testCancelledSwipeCancelsAndClearsTheInteraction() {
    let n = UINavigationController()
    n.addCustomTransitioning()
    let i = TransitionInteraction()
    n.transitionCoordinatorHelper?.interactionController = i
    let g = TransitionSwipe()
    n.view.addGestureRecognizer(g)
    g.reportedState = .cancelled
    n.handleSwipe(g)
    XCTAssertTrue(i.cancelled)
    XCTAssertNil(n.transitionCoordinatorHelper?.interactionController)
  }
  func testFailedSwipeCancelsAndClearsTheInteraction() {
    let n = UINavigationController()
    n.addCustomTransitioning()
    let i = TransitionInteraction()
    n.transitionCoordinatorHelper?.interactionController = i
    let g = TransitionSwipe()
    n.view.addGestureRecognizer(g)
    g.reportedState = .failed
    n.handleSwipe(g)
    XCTAssertTrue(i.cancelled)
    XCTAssertNil(n.transitionCoordinatorHelper?.interactionController)
  }
  func testShortSwipeCancelsTheInteraction() {
    let n = UINavigationController()
    n.addCustomTransitioning()
    n.view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    let i = TransitionInteraction()
    n.transitionCoordinatorHelper?.interactionController = i
    let g = TransitionSwipe()
    n.view.addGestureRecognizer(g)
    g.reportedState = .ended
    g.distance = 40
    n.handleSwipe(g)
    XCTAssertTrue(i.cancelled)
    XCTAssertFalse(i.finished)
    XCTAssertNil(n.transitionCoordinatorHelper?.interactionController)
  }
  func testLongSwipeFinishesTheInteraction() {
    let n = UINavigationController()
    n.addCustomTransitioning()
    n.view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    let i = TransitionInteraction()
    n.transitionCoordinatorHelper?.interactionController = i
    let g = TransitionSwipe()
    n.view.addGestureRecognizer(g)
    g.reportedState = .ended
    g.distance = 60
    n.handleSwipe(g)
    XCTAssertTrue(i.finished)
    XCTAssertNil(n.transitionCoordinatorHelper?.interactionController)
  }
  func testChangedSwipeClampsProgressToOne() {
    let n = UINavigationController()
    n.addCustomTransitioning()
    n.view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    let i = TransitionInteraction()
    n.transitionCoordinatorHelper?.interactionController = i
    let g = TransitionSwipe()
    n.view.addGestureRecognizer(g)
    g.reportedState = .changed
    g.distance = 300
    n.handleSwipe(g)
    XCTAssertEqual(i.progress, 1)
  }
  func testChangedSwipeClampsNegativeProgressToZero() {
    let n = UINavigationController()
    n.addCustomTransitioning()
    n.view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    let i = TransitionInteraction()
    n.transitionCoordinatorHelper?.interactionController = i
    let g = TransitionSwipe()
    n.view.addGestureRecognizer(g)
    g.reportedState = .changed
    g.distance = -40
    n.handleSwipe(g)
    XCTAssertEqual(i.progress, 0)
  }
  func testZeroWidthSwipeNeverSendsNonfiniteProgress() {
    let n = UINavigationController()
    n.addCustomTransitioning()
    n.view.frame = .zero
    let i = TransitionInteraction()
    n.transitionCoordinatorHelper?.interactionController = i
    let g = TransitionSwipe()
    n.view.addGestureRecognizer(g)
    g.reportedState = .changed
    g.distance = 40
    n.handleSwipe(g)
    XCTAssertTrue(i.progress?.isFinite ?? true)
  }
}
@MainActor private final class TransitionContext: NSObject, UIViewControllerContextTransitioning {
  let frame = CGRect(x: 0, y: 0, width: 320, height: 640)
  let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
  let from = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 640)),
    to = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
  var cancelled = false, omitSource = false, omitTarget = false, completed: Bool?,
    onComplete: (() -> Void)?
  override init() {
    super.init()
    containerView.addSubview(from)
  }
  var isAnimated: Bool { true }
  var isInteractive: Bool { false }
  var transitionWasCancelled: Bool { cancelled }
  var presentationStyle: UIModalPresentationStyle { .fullScreen }
  var targetTransform: CGAffineTransform { .identity }
  func updateInteractiveTransition(_ percentComplete: CGFloat) {}
  func finishInteractiveTransition() {}
  func cancelInteractiveTransition() {}
  func pauseInteractiveTransition() {}
  func completeTransition(_ didComplete: Bool) {
    completed = didComplete
    onComplete?()
  }
  func viewController(forKey key: UITransitionContextViewControllerKey) -> UIViewController? { nil }
  func view(forKey key: UITransitionContextViewKey) -> UIView? {
    key == .from ? (omitSource ? nil : from) : (omitTarget ? nil : to)
  }
  func initialFrame(for vc: UIViewController) -> CGRect { frame }
  func finalFrame(for vc: UIViewController) -> CGRect { frame }
}
@MainActor private final class TransitionSwipe: UIScreenEdgePanGestureRecognizer {
  var reportedState: UIGestureRecognizer.State = .possible
  var distance: CGFloat = 0
  override var state: UIGestureRecognizer.State {
    get { reportedState }
    set { reportedState = newValue }
  }
  override func translation(in view: UIView?) -> CGPoint { CGPoint(x: distance, y: 0) }
}
@MainActor private final class TransitionInteraction: UIPercentDrivenInteractiveTransition {
  var cancelled = false, finished = false, progress: CGFloat?
  override func cancel() { cancelled = true }
  override func finish() { finished = true }
  override func update(_ percentComplete: CGFloat) { progress = percentComplete }
}
