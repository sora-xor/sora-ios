import SoraFoundation
import SoraUI
// SPDX-License-Identifier: Apache-2.0
import UIKit
import XCTest

@testable import SoraPassport

@MainActor final class SharedViewLifecycleTests: XCTestCase {
  private func loading(_ c: UIViewController) -> [UIView] {
    c.view.subviews.filter {
      $0.accessibilityIdentifier == LoadableViewProtocolConstants.activityIndicatorIdentifier
    }
  }
  func testLoadingDisablesInputWhenRequested() {
    let c = LoadingFixture()
    c.didStartLoading()
    XCTAssertFalse(c.view.isUserInteractionEnabled)
  }
  func testNonblockingLoadingKeepsInputEnabled() {
    let c = InteractiveLoadingFixture()
    c.didStartLoading()
    XCTAssertTrue(c.view.isUserInteractionEnabled)
  }
  func testRepeatedLoadingStartKeepsOneIndicator() {
    let c = LoadingFixture()
    c.didStartLoading()
    c.didStartLoading()
    XCTAssertEqual(loading(c).count, 1)
  }
  func testLoadingIndicatorCoversAndResizesWithContent() {
    let c = LoadingFixture()
    c.view.frame = CGRect(x: 0, y: 0, width: 320, height: 640)
    c.didStartLoading()
    let indicator = loading(c).first
    XCTAssertEqual(indicator?.frame, c.view.bounds)
    XCTAssertTrue(indicator?.autoresizingMask.contains([.flexibleWidth, .flexibleHeight]) == true)
  }
  func testStoppingLoadingRestoresInputImmediately() {
    let c = LoadingFixture()
    c.didStartLoading()
    c.didStopLoading()
    XCTAssertTrue(c.view.isUserInteractionEnabled)
    XCTAssertTrue(loading(c).isEmpty)
  }
  func testStoppingLoadingRemovesOnlyTheIndicator() async {
    let c = LoadingFixture()
    let content = UIView()
    c.view.addSubview(content)
    c.didStartLoading()
    c.didStopLoading()
    try? await Task.sleep(nanoseconds: 450_000_000)
    XCTAssertEqual(c.view.subviews, [content])
  }
  func testStoppingBeforeStartingDoesNotChangeExistingInputState() {
    let c = LoadingFixture()
    c.view.isUserInteractionEnabled = false
    c.didStopLoading()
    XCTAssertFalse(c.view.isUserInteractionEnabled)
  }
  func testStartingAgainDuringFadeOutKeepsTheNewIndicator() async {
    let c = LoadingFixture()
    c.didStartLoading()
    c.didStopLoading()
    c.didStartLoading()
    try? await Task.sleep(nanoseconds: 450_000_000)
    XCTAssertEqual(loading(c).count, 1)
    XCTAssertFalse(c.view.isUserInteractionEnabled)
  }
  func testRootTransitionReplacesTheExactWindowRoot() {
    let w = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
    let old = UIViewController()
    let next = UIViewController()
    w.rootViewController = old
    RootControllerAnimationCoordinator().animateTransition(to: next, in: w)
    XCTAssertTrue(w.rootViewController === next)
  }
  func testRootTransitionUsesTheConfiguredAnimation() {
    let w = RootAnimationWindow()
    let c = RootControllerAnimationCoordinator()
    c.duration = 0.7
    c.type = .push
    c.timingFunction = .linear
    c.animationKey = "test-transition"
    c.animateTransition(to: UIViewController(), in: w)
    let a = (w.layer as? RootAnimationLayer)?.recorded["test-transition"] as? CATransition
    XCTAssertEqual(a?.duration, 0.7)
    XCTAssertEqual(a?.type, .push)
  }
}
@MainActor private final class LoadingFixture: UIViewController, LoadableViewProtocol {}
@MainActor private final class InteractiveLoadingFixture: UIViewController, LoadableViewProtocol {
  var shouldDisableInteractionWhenLoading: Bool { false }
}

@MainActor private final class RootAnimationWindow: UIWindow {
  override class var layerClass: AnyClass { RootAnimationLayer.self }
}
private final class RootAnimationLayer: CALayer {
  var recorded = [String: CAAnimation]()
  override func add(_ animation: CAAnimation, forKey key: String?) {
    if let key { recorded[key] = animation.copy() as? CAAnimation }
  }
}
