import CoreMotion
import SoraUIKit
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

@MainActor
final class MainTabTransitionCoverageTests: RootActionFixtureTests {
    private func install(_ controller: UIViewController, body: () throws -> Void) throws {
        let app = try XCTUnwrap(UIApplication.shared.delegate as? AppDelegate)
        let previous = app.window
        defer { app.window = previous }
        mount(controller); app.window = window
        try body()
    }
    private func tabs() -> (UITabBarController, UINavigationController, UINavigationController) {
        let tabs = UITabBarController()
        let wallet = UINavigationController(rootViewController: UIViewController())
        let explore = UINavigationController(rootViewController: UIViewController())
        tabs.viewControllers = [wallet, explore]
        wallet.pushViewController(UIViewController(), animated: false)
        explore.pushViewController(UIViewController(), animated: false)
        return (tabs, wallet, explore)
    }
    func testReturningToTheSelectedWalletPopsItsNavigationStack() throws {
        let (tabs, wallet, explore) = tabs(); tabs.selectedIndex = 0
        try install(tabs) {
            MainTransitionHelper.transitToMainTabBarController(selectingIndex: 0, closing: wallet.topViewController!, animated: false)
            XCTAssertEqual(tabs.selectedIndex, 0); XCTAssertEqual(wallet.viewControllers.count, 1)
            XCTAssertEqual(explore.viewControllers.count, 2)
        }
    }
    func testChangingTabsFirstPopsThePreviousNavigationStack() throws {
        let (tabs, wallet, explore) = tabs(); tabs.selectedIndex = 1
        try install(tabs) {
            MainTransitionHelper.transitToMainTabBarController(selectingIndex: 0, closing: explore.topViewController!, animated: false)
            XCTAssertEqual(tabs.selectedIndex, 0); XCTAssertEqual(explore.viewControllers.count, 1)
            XCTAssertEqual(wallet.viewControllers.count, 2)
        }
    }
    func testAnimatedTabReturnRevealsTheRequestedTab() throws {
        let (tabs, wallet, explore) = tabs(); tabs.selectedIndex = 1
        try install(tabs) {
            MainTransitionHelper.transitToMainTabBarController(selectingIndex: 0, closing: explore.topViewController!, animated: true)
            XCTAssertTrue(tabs.selectedViewController === wallet)
            XCTAssertEqual(explore.viewControllers.count, 1)
            XCTAssertEqual(tabs.view.alpha, 1)
        }
    }
    func testMissingTabRootLeavesTheExistingNavigationUntouched() throws {
        let navigation = UINavigationController(rootViewController: UIViewController())
        navigation.pushViewController(UIViewController(), animated: false)
        try install(navigation) {
            MainTransitionHelper.transitToMainTabBarController(closing: navigation.topViewController!, animated: false)
            XCTAssertEqual(navigation.viewControllers.count, 2)
            XCTAssertTrue(window.rootViewController === navigation)
        }
    }
    func testPlainSelectedTabCanStillTransitionWithoutANavigationStack() throws {
        let tabs = UITabBarController(), first = UIViewController(), second = UIViewController()
        tabs.viewControllers = [first, second]; tabs.selectedIndex = 1
        try install(tabs) {
            MainTransitionHelper.transitToMainTabBarController(selectingIndex: 0, closing: second, animated: false)
            XCTAssertTrue(tabs.selectedViewController === first)
        }
    }
    func testSelectingTheSamePlainTabKeepsItSelected() throws {
        let tabs = UITabBarController(), first = UIViewController(), second = UIViewController()
        tabs.viewControllers = [first, second]; tabs.selectedIndex = 0
        try install(tabs) {
            MainTransitionHelper.transitToMainTabBarController(selectingIndex: 0, closing: first, animated: true)
            XCTAssertTrue(tabs.selectedViewController === first)
        }
    }
    func testClosingAModalDismissesItBeforeReturningToWallet() async throws {
        let app = try XCTUnwrap(UIApplication.shared.delegate as? AppDelegate), previous = app.window
        defer { app.window = previous }
        let (tabs, _, explore) = tabs(); tabs.selectedIndex = 1; mount(tabs); app.window = window
        let modal = UIViewController(); explore.present(modal, animated: false); await settle()
        XCTAssertTrue(modal.presentingViewController != nil)
        MainTransitionHelper.transitToMainTabBarController(selectingIndex: 0, closing: modal, animated: false)
        await settle()
        XCTAssertNil(modal.presentingViewController); XCTAssertEqual(tabs.selectedIndex, 0)
        XCTAssertEqual(explore.viewControllers.count, 1)
    }
}

@MainActor
final class PortfolioParallaxLifecycleTests: XCTestCase {
    @MainActor private final class Fixture {
        let manager = ParallaxMotionManager()
        let far = UIView(), near = UIView(), text = UILabel()
        var policy: PortfolioParallaxController.MotionPolicy = (true, false, false)
        var renders = [(CGFloat, CGFloat)]()
        lazy var controller: PortfolioParallaxController = {
            let controller = PortfolioParallaxController(layers: [
                .init(view: far, depth: 12, yFactor: 0.5),
                .init(view: near, depth: 24, yFactor: 0.5, rotateDeg: 8)
            ], manager: manager, motionPolicy: { [unowned self] in self.policy })
            controller.onRender = { [weak self] x, y in self?.renders.append((x, y)) }
            return controller
        }()
        func activate() {
            controller.setHeroVisible(true)
            controller.start()
            NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
            manager.send(roll: 10, pitch: 20)
            manager.send(roll: 10, pitch: 20)
        }
        func tilt() { manager.send(roll: 1, pitch: 15.5) }
    }
    private func wait(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0..<300 {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Parallax state did not settle", file: file, line: line)
    }
    func testHiddenSurfaceDoesNotStartTheMotionSensor() {
        let f = Fixture(); f.controller.start(); defer { f.controller.stop() }
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        XCTAssertFalse(f.controller.gate.isOpen)
        XCTAssertEqual(f.manager.starts, 0)
    }
    func testVisibleActiveSurfaceStartsAtSixtySamplesPerSecondOnlyOnce() {
        let f = Fixture(); f.activate(); defer { f.controller.stop() }
        f.controller.start(); f.controller.setHeroVisible(true)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        XCTAssertEqual(f.manager.starts, 1)
        XCTAssertTrue(f.manager.lastQueue === OperationQueue.main)
        XCTAssertEqual(f.manager.deviceMotionUpdateInterval, 1.0 / 60.0, accuracy: 0.00001)
    }
    func testUnavailableMotionHardwareKeepsTheSurfaceAtRest() {
        let f = Fixture(); f.manager.available = false; f.activate(); defer { f.controller.stop() }
        XCTAssertEqual(f.manager.starts, 0)
        XCTAssertEqual(f.controller.deflection.x, 0)
        XCTAssertTrue(f.far.transform.isIdentity)
    }
    func testFirstReferenceAndRestingSamplesDoNotMoveContent() {
        let f = Fixture(); f.activate(); defer { f.controller.stop() }
        XCTAssertEqual(f.controller.deflection.x, 0)
        XCTAssertEqual(f.controller.deflection.y, 0)
        XCTAssertTrue(f.renders.isEmpty)
    }
    func testRelativeMotionMovesOnlyDecorativeLayersWithDepthAndRotation() async {
        let f = Fixture(); f.activate(); defer { f.controller.stop() }
        f.tilt()
        await wait { f.controller.deflection.x > 0.1 }
        XCTAssertLessThanOrEqual(f.controller.deflection.x, 1)
        XCTAssertGreaterThan(f.controller.deflection.y, 0)
        XCTAssertLessThan(f.far.transform.tx, 0)
        XCTAssertLessThan(f.far.transform.ty, 0)
        XCTAssertEqual(f.near.transform.tx, f.far.transform.tx * 2, accuracy: 0.0001)
        XCTAssertEqual(f.near.transform.ty, f.far.transform.ty * 2, accuracy: 0.0001)
        XCTAssertNotEqual(f.near.transform.b, 0)
        XCTAssertTrue(f.text.transform.isIdentity)
        XCTAssertFalse(f.renders.isEmpty)
    }
    func testHidingTheSurfaceStopsSensorsAndGlidesBackToRest() async {
        let f = Fixture(); f.activate(); defer { f.controller.stop() }
        f.tilt(); await wait { f.controller.deflection.x > 0.1 }
        f.controller.setHeroVisible(false)
        XCTAssertFalse(f.manager.active)
        await wait { f.controller.deflection.x == 0 && f.controller.deflection.y == 0 }
        XCTAssertTrue(f.far.transform.isIdentity)
        XCTAssertTrue(f.near.transform.isIdentity)
    }
    func testBackgroundingTheAppStopsSensorsAndResetsTransforms() async {
        let f = Fixture(); f.activate(); defer { f.controller.stop() }
        f.tilt(); await wait { f.controller.deflection.x > 0.1 }
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        XCTAssertTrue(f.controller.gate.hidden)
        XCTAssertFalse(f.manager.active)
        await wait { f.controller.deflection.x == 0 }
        XCTAssertTrue(f.near.transform.isIdentity)
    }
    func testReturningToForegroundRestartsWithAFreshReferencePose() {
        let f = Fixture(); f.activate(); defer { f.controller.stop() }
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        XCTAssertEqual(f.manager.starts, 2)
        f.manager.send(roll: 30, pitch: -40)
        f.manager.send(roll: 30, pitch: -40)
        XCTAssertEqual(f.controller.deflection.x, 0)
        XCTAssertEqual(f.controller.deflection.y, 0)
    }
    func testReducedMotionClosesTheSensorGateOnNotification() {
        let f = Fixture(); f.activate(); defer { f.controller.stop() }
        f.policy.reduceMotion = true
        NotificationCenter.default.post(name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
        XCTAssertFalse(f.controller.gate.isOpen)
        XCTAssertFalse(f.manager.active)
    }
    func testLowPowerClosesTheSensorGateOnNotification() {
        let f = Fixture(); f.activate(); defer { f.controller.stop() }
        f.policy.lowPower = true
        NotificationCenter.default.post(name: .NSProcessInfoPowerStateDidChange, object: nil)
        XCTAssertFalse(f.controller.gate.isOpen)
        XCTAssertFalse(f.manager.active)
    }
    func testReducedEffectsClosesTheSensorGateOnNotification() {
        let f = Fixture(); f.activate(); defer { f.controller.stop() }
        f.policy.enabled = false
        NotificationCenter.default.post(name: .neonFxChanged, object: nil)
        XCTAssertFalse(f.controller.gate.isOpen)
        XCTAssertFalse(f.manager.active)
    }
    func testStopImmediatelyResetsBothTranslationAndRotation() async {
        let f = Fixture(); f.activate(); f.tilt()
        await wait { f.controller.deflection.x > 0.1 }
        f.controller.stop()
        XCTAssertFalse(f.manager.active)
        XCTAssertTrue(f.far.transform.isIdentity)
        XCTAssertTrue(f.near.transform.isIdentity)
        XCTAssertEqual(f.renders.last?.0, 0)
        XCTAssertEqual(f.renders.last?.1, 0)
    }
    func testQueuedMotionAfterStopCannotRestartTheDisplayLink() async {
        let f = Fixture(); f.activate(); f.controller.stop()
        let renders = f.renders.count
        f.tilt()
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(f.controller.deflection.x, 0)
        XCTAssertEqual(f.renders.count, renders)
        XCTAssertTrue(f.near.transform.isIdentity)
    }
    func testQueuedMotionAfterSurfaceHidesCannotCreateANewTilt() async {
        let f = Fixture(); f.activate(); defer { f.controller.stop() }
        f.controller.setHeroVisible(false)
        f.tilt()
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(f.controller.deflection.x, 0)
        XCTAssertTrue(f.renders.isEmpty)
    }
    func testStoppedControllerDoesNotReactToLaterLifecycleNotifications() {
        let f = Fixture(); f.activate(); f.controller.stop()
        let starts = f.manager.starts, stops = f.manager.stops
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.post(name: .NSProcessInfoPowerStateDidChange, object: nil)
        NotificationCenter.default.post(name: .neonFxChanged, object: nil)
        XCTAssertEqual(f.manager.starts, starts)
        XCTAssertEqual(f.manager.stops, stops)
    }
    func testMissingMotionSampleDoesNotStartRendering() {
        let f = Fixture(); f.activate(); defer { f.controller.stop() }
        f.manager.callback?(nil, NSError(domain: "Fixture", code: 1))
        XCTAssertTrue(f.renders.isEmpty)
        XCTAssertEqual(f.controller.deflection.x, 0)
    }
    func testControllerReleaseStopsTheSensorAndLeavesQueuedCallbackHarmless() {
        let manager = ParallaxMotionManager()
        var controller: PortfolioParallaxController? = PortfolioParallaxController(layers: [], manager: manager,
            motionPolicy: { (true, false, false) })
        controller?.setHeroVisible(true); controller?.start()
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        weak var released = controller
        controller = nil
        XCTAssertNil(released)
        XCTAssertFalse(manager.active)
        manager.send(roll: 15, pitch: 5)
    }
}

private final class ParallaxMotionManager: CMMotionManager {
    var available = true, active = false, starts = 0, stops = 0
    var callback: CMDeviceMotionHandler?
    var lastQueue: OperationQueue?
    override var isDeviceMotionAvailable: Bool { available }
    override var isDeviceMotionActive: Bool { active }
    override func startDeviceMotionUpdates(to queue: OperationQueue, withHandler handler: @escaping CMDeviceMotionHandler) {
        starts += 1; active = true; callback = handler; lastQueue = queue
    }
    override func stopDeviceMotionUpdates() { stops += 1; active = false }
    func send(roll: Double, pitch: Double) {
        let motion = ParallaxMotion()
        motion.value.x = roll * .pi / 180; motion.value.y = pitch * .pi / 180
        callback?(motion, nil)
    }
}
private final class ParallaxMotion: CMDeviceMotion {
    let value = ParallaxAttitude()
    override var attitude: CMAttitude { value }
}
private final class ParallaxAttitude: CMAttitude {
    var x: Double = 0, y: Double = 0
    override var roll: Double { x }
    override var pitch: Double { y }
    override func copy(with zone: NSZone? = nil) -> Any {
        let attitude = ParallaxAttitude(); attitude.x = x; attitude.y = y; return attitude
    }
    override func multiply(byInverseOf attitude: CMAttitude) {
        x -= attitude.roll; y -= attitude.pitch
    }
}
