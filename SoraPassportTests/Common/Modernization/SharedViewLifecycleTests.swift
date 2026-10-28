import SoraFoundation
import SoraUI
// SPDX-License-Identifier: BSD-4-Clause
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
  func testKeyboardHandlerInstallationIsIdempotent() {
    let c = KeyboardFixture()
    c.setupKeyboardHandler()
    let h = c.keyboardHandler
    c.setupKeyboardHandler()
    XCTAssertTrue(c.keyboardHandler === h)
  }
  func testClearingKeyboardHandlerReleasesIt() {
    let c = KeyboardFixture()
    c.setupKeyboardHandler()
    weak let h = c.keyboardHandler
    c.clearKeyboardHandler()
    XCTAssertNil(c.keyboardHandler)
    XCTAssertNil(h)
  }
  func testKeyboardAnimationStoresTheLatestFrame() {
    let c = KeyboardFixture()
    c.setupKeyboardHandler()
    let frame = CGRect(x: 0, y: 400, width: 320, height: 240)
    c.keyboardHandler?.animateOnFrameChange?(frame)
    XCTAssertEqual(c.currentKeyboardFrame, frame)
  }
  func testKeyboardWithoutBottomConstraintUsesTheCustomCallback() {
    let c = KeyboardFixture()
    c.currentKeyboardFrame = CGRect(x: 0, y: 400, width: 320, height: 240)
    c.applyCurrentKeyboardFrame()
    XCTAssertEqual(c.frames, [c.currentKeyboardFrame!])
  }
  func testMissingKeyboardFrameDoesNotTouchLayout() {
    let c = KeyboardFixture()
    c.constraint = NSLayoutConstraint()
    c.constraint?.constant = -12
    c.applyCurrentKeyboardFrame()
    XCTAssertEqual(c.constraint?.constant, -12)
    XCTAssertTrue(c.frames.isEmpty)
  }
  func testDockedKeyboardOffsetsTheBottomByItsOverlap() {
    let c = KeyboardFixture()
    c.constraint = NSLayoutConstraint()
    c.currentKeyboardFrame = CGRect(x: 0, y: 400, width: 320, height: 240)
    c.applyCurrentKeyboardFrame()
    XCTAssertEqual(c.constraint?.constant, -240)
  }
  func testKeyboardGapIsAddedToTheVisibleOverlap() {
    let c = KeyboardFixture()
    c.constraint = NSLayoutConstraint()
    c.gap = 8
    c.currentKeyboardFrame = CGRect(x: 0, y: 400, width: 320, height: 240)
    c.applyCurrentKeyboardFrame()
    XCTAssertEqual(c.constraint?.constant, -248)
    XCTAssertEqual(c.insets, [240])
  }
  func testDisabledKeyboardAdaptationPreservesTheConstraint() {
    let c = KeyboardFixture()
    c.constraint = NSLayoutConstraint()
    c.constraint?.constant = -10
    c.applies = false
    c.currentKeyboardFrame = CGRect(x: 0, y: 400, width: 320, height: 240)
    c.applyCurrentKeyboardFrame()
    XCTAssertEqual(c.constraint?.constant, -10)
  }
  func testKeyboardBelowTheScreenNeverPushesContentDown() {
    let c = KeyboardFixture()
    c.constraint = NSLayoutConstraint()
    c.currentKeyboardFrame = CGRect(x: 0, y: 900, width: 320, height: 240)
    c.applyCurrentKeyboardFrame()
    XCTAssertEqual(c.constraint?.constant, 0)
  }
  func testKeyboardOnAnotherDisplayDoesNotMoveThisContent() {
    let c = KeyboardFixture()
    c.constraint = NSLayoutConstraint()
    c.currentKeyboardFrame = CGRect(x: 500, y: 400, width: 320, height: 240)
    c.applyCurrentKeyboardFrame()
    XCTAssertEqual(c.constraint?.constant, 0)
  }
  func testZeroSizeKeyboardDoesNotMoveContent() {
    let c = KeyboardFixture()
    c.constraint = NSLayoutConstraint()
    c.currentKeyboardFrame = .zero
    c.applyCurrentKeyboardFrame()
    XCTAssertEqual(c.constraint?.constant, 0)
  }
  func testKeyboardInsetCannotExceedTheVisibleView() {
    let c = KeyboardFixture()
    c.constraint = NSLayoutConstraint()
    c.currentKeyboardFrame = CGRect(x: 0, y: -100, width: 320, height: 900)
    c.applyCurrentKeyboardFrame()
    XCTAssertEqual(c.constraint?.constant, -640)
  }
  func testPlainKeyboardAdoptableReceivesFrameChanges() {
    let f = PlainKeyboardFixture()
    f.setupKeyboardHandler()
    f.keyboardHandler?.animateOnFrameChange?(CGRect(x: 0, y: 2, width: 3, height: 4))
    XCTAssertEqual(f.frames, [CGRect(x: 0, y: 2, width: 3, height: 4)])
    f.clearKeyboardHandler()
    XCTAssertNil(f.keyboardHandler)
  }
  func testKeyboardHandlerDoesNotRetainItsOwner() {
    var f: PlainKeyboardFixture? = PlainKeyboardFixture()
    f?.setupKeyboardHandler()
    let handler = f?.keyboardHandler
    weak let weakOwner = f
    f = nil
    XCTAssertNil(weakOwner)
    handler?.animateOnFrameChange?(.zero)
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
@MainActor private final class KeyboardFixture: UIViewController, KeyboardViewAdoptable {
  var constraint: NSLayoutConstraint?, applies = true, gap: CGFloat = 0, frames = [CGRect](),
    insets = [CGFloat]()
  var targetBottomConstraint: NSLayoutConstraint? { constraint }
  var shouldApplyKeyboardFrame: Bool { applies }
  override func loadView() { view = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 640)) }
  func offsetFromKeyboardWithInset(_ inset: CGFloat) -> CGFloat {
    insets.append(inset)
    return gap
  }
  func updateWhileKeyboardFrameChanging(_ frame: CGRect) { frames.append(frame) }
}
private final class PlainKeyboardFixture: KeyboardAdoptable {
  var keyboardHandler: KeyboardHandler?, frames = [CGRect]()
  func updateWhileKeyboardFrameChanging(_ frame: CGRect) { frames.append(frame) }
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
