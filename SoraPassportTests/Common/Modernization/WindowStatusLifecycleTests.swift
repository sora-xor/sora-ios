import SoraUI
import SoraUIKit
// SPDX-License-Identifier: BSD-4-Clause
import UIKit
import XCTest

@testable import SoraPassport

@MainActor final class WindowStatusLifecycleTests: XCTestCase {
  private func make() -> SoraWindow {
    SoraWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
  }
  private let style = ApplicationStatusStyle(
    backgroundColor: .red, titleColor: .white, titleFont: .systemFont(ofSize: 13))
  private func status(_ w: SoraWindow) throws -> ApplicationStatusView {
    try XCTUnwrap(w.subviews.compactMap { $0 as? ApplicationStatusView }.first)
  }
  func testStatusUsesTheWindowWidthWithoutAStatusBar() throws {
    let w = make()
    w.presentStatus(title: "Connected", style: style, animated: false)
    let s = try status(w)
    XCTAssertEqual(s.frame.width, 320)
    XCTAssertEqual(s.frame.origin, .zero)
    XCTAssertGreaterThan(s.frame.height, 0)
  }
  func testStatusDisplaysTheExactMessage() throws {
    let w = make()
    w.presentStatus(title: "Reading network", style: style, animated: false)
    XCTAssertEqual(try status(w).titleLabel.text, "Reading network")
  }
  func testStatusAppliesTheSuppliedColorsAndFont() throws {
    let w = make()
    w.presentStatus(title: "Ready", style: style, animated: false)
    let s = try status(w)
    XCTAssertEqual(s.backgroundColor, .red)
    XCTAssertEqual(s.titleLabel.textColor, .white)
    XCTAssertEqual(s.titleLabel.font.pointSize, 13)
  }
  func testReplacingStatusReusesTheSingleBanner() throws {
    let w = make()
    w.presentStatus(title: "First", style: style, animated: false)
    let first = try status(w)
    w.presentStatus(title: "Second", style: style, animated: false)
    XCTAssertTrue(try status(w) === first)
    XCTAssertEqual(first.titleLabel.text, "Second")
    XCTAssertEqual(w.subviews.filter { $0 is ApplicationStatusView }.count, 1)
  }
  func testReplacingStatusUpdatesItsStyle() throws {
    let w = make()
    w.presentStatus(title: "First", style: style, animated: false)
    let next = ApplicationStatusStyle(
      backgroundColor: .blue, titleColor: .yellow, titleFont: .systemFont(ofSize: 16))
    w.presentStatus(title: "Second", style: next, animated: false)
    let s = try status(w)
    XCTAssertEqual(s.backgroundColor, .blue)
    XCTAssertEqual(s.titleLabel.textColor, .yellow)
    XCTAssertEqual(s.titleLabel.font.pointSize, 16)
  }
  func testAddingAnotherViewKeepsTheStatusBannerInFront() throws {
    let w = make()
    w.presentStatus(title: "Status", style: style, animated: false)
    w.addSubview(UIView())
    XCTAssertTrue(try w.subviews.last === status(w))
  }
  func testBringingAnotherViewForwardKeepsTheBannerVisible() throws {
    let w = make()
    let content = UIView()
    w.addSubview(content)
    w.presentStatus(title: "Status", style: style, animated: false)
    w.bringSubviewToFront(content)
    XCTAssertTrue(try w.subviews.last === status(w))
  }
  func testDismissWithoutAnimationRemovesTheBanner() {
    let w = make()
    w.presentStatus(title: "Status", style: style, animated: false)
    w.dismissStatus(title: nil, style: nil, animated: false)
    XCTAssertFalse(w.subviews.contains { $0 is ApplicationStatusView })
  }
  func testDismissCanReplaceFinalMessageBeforeRemoval() throws {
    let w = make()
    w.presentStatus(title: "Connecting", style: style, animated: false)
    let s = try status(w)
    w.dismissStatus(title: "Complete", style: nil, animated: false)
    XCTAssertEqual(s.titleLabel.text, "Complete")
    XCTAssertNil(s.superview)
  }
  func testDismissCanReplaceFinalStyleBeforeRemoval() throws {
    let w = make()
    w.presentStatus(title: "Connecting", style: style, animated: false)
    let s = try status(w)
    let done = ApplicationStatusStyle(
      backgroundColor: .green, titleColor: .black, titleFont: .systemFont(ofSize: 14))
    w.dismissStatus(title: nil, style: done, animated: false)
    XCTAssertEqual(s.backgroundColor, .green)
    XCTAssertEqual(s.titleLabel.text, "Connecting")
  }
  func testDismissWhenNoStatusIsPresentKeepsOtherViews() {
    let w = make()
    let content = UIView()
    w.addSubview(content)
    w.dismissStatus(title: nil, style: nil, animated: false)
    XCTAssertEqual(w.subviews, [content])
  }
  func testNewBannerAfterDismissDoesNotReuseDetachedView() throws {
    let w = make()
    w.presentStatus(title: "First", style: style, animated: false)
    let old = try status(w)
    w.dismissStatus(title: nil, style: nil, animated: false)
    w.presentStatus(title: "New", style: style, animated: false)
    XCTAssertFalse(try status(w) === old)
  }
  func testAnimatedPresentationAndUpdateKeepOneBanner() async throws {
    let w = make()
    w.presentStatus(title: "First", style: style, animated: true)
    w.presentStatus(title: "Second", style: style, animated: true)
    try? await Task.sleep(nanoseconds: 250_000_000)
    XCTAssertEqual(try status(w).titleLabel.text, "Second")
    XCTAssertEqual(try status(w).frame.origin, .zero)
    XCTAssertEqual(w.subviews.filter { $0 is ApplicationStatusView }.count, 1)
  }
  func testAnimatedDismissRemovesOnlyItsOwnBanner() async throws {
    let w = make()
    w.presentStatus(title: "Old", style: style, animated: false)
    let old = try status(w)
    w.dismissStatus(title: "Done", style: style, animated: true)
    w.presentStatus(title: "New", style: style, animated: false)
    try? await Task.sleep(nanoseconds: 700_000_000)
    XCTAssertNil(old.superview)
    XCTAssertEqual(try status(w).titleLabel.text, "New")
  }
  func testNoRootMeansNoTopController() { XCTAssertNil(make().topController) }
  func testTopControllerIsTheRootWhenNothingIsPresented() {
    let w = make()
    let root = UIViewController()
    w.rootViewController = root
    XCTAssertTrue(w.topController === root)
  }
  func testPresentingAlertHonorsTheRequestedAnimationFlag() {
    let w = make()
    let root = WindowStatusPresenter()
    w.rootViewController = root
    let alert = UIAlertController(title: "Notice", message: nil, preferredStyle: .alert)
    w.presentAlert(alert: alert, animated: false)
    XCTAssertTrue(root.presented === alert)
    XCTAssertEqual(root.animated, false)
  }
  func testPaletteChangeUpdatesTheWindowBackground() {
    let w = make()
    w.styleDidChange(options: .palette)
    XCTAssertEqual(w.backgroundColor, SoramitsuUI.shared.theme.palette.color(.bgPage))
  }
  func testUnrelatedStyleUpdatePreservesTheBackground() {
    let w = make()
    w.backgroundColor = .magenta
    w.styleDidChange(options: [])
    XCTAssertEqual(w.backgroundColor, .magenta)
  }
  func testReplacingRootModuleReleasesTheOldOwner() {
    let w = make()
    var old: NSObject? = NSObject()
    weak let weakOld = old
    w.rootModule = old
    old = nil
    XCTAssertNotNil(weakOld)
    w.rootModule = NSObject()
    XCTAssertNil(weakOld)
  }
}
@MainActor private final class WindowStatusPresenter: UIViewController {
  var presented: UIViewController?, animated: Bool?
  override func present(
    _ viewControllerToPresent: UIViewController, animated flag: Bool,
    completion: (() -> Void)? = nil
  ) {
    presented = viewControllerToPresent
    animated = flag
    completion?()
  }
}
