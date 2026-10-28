// SPDX-License-Identifier: BSD-4-Clause
import UIKit
import XCTest

@testable import SoraPassport

@MainActor final class WalletNavigationStyleTests: XCTestCase {
  private func style(_ image: UIImage? = nil) -> WalletNavigationBarStyle {
    .init(
      barColor: .blue, shadowColor: .gray, itemTintColor: .green, titleColor: .red,
      titleFont: .systemFont(ofSize: 21), backButtonImage: image)
  }
  private func make(_ root: UIViewController? = nil) -> WalletNavigationController {
    let n = WalletNavigationController(rootViewController: root ?? UIViewController())
    n.navigationBarStyle = style()
    n.loadViewIfNeeded()
    return n
  }
  func testNavigationDelegatesItsTransitionsToItself() {
    let n = make()
    XCTAssertTrue(n.delegate === n)
  }
  func testStatusBarStyleIsDelegatedToTheTopController() {
    let root = UIViewController()
    let n = WalletNavigationController(rootViewController: UIViewController())
    n.setViewControllers([root], animated: false)
    XCTAssertTrue(n.childForStatusBarStyle === root)
  }
  func testNavigationAppliesItemAndTitleColors() {
    let n = make()
    XCTAssertEqual(n.navigationBar.tintColor, .green)
    XCTAssertEqual(n.navigationBar.titleTextAttributes?[.foregroundColor] as? UIColor, .red)
  }
  func testNavigationAppliesItsTitleFont() {
    let n = make()
    XCTAssertEqual(n.navigationBar.titleTextAttributes?[.font] as? UIFont, .systemFont(ofSize: 21))
  }
  func testChangingStyleUpdatesAnAlreadyLoadedNavigationBar() {
    let n = make()
    var updated = style()
    updated.itemTintColor = .purple
    n.navigationBarStyle = updated
    XCTAssertEqual(n.navigationBar.tintColor, .purple)
  }
  func testCustomBackImageIsAppliedToBothIndicators() {
    let n = make()
    let image = UIImage(systemName: "arrow.left")!
    n.navigationBarStyle = style(image)
    XCTAssertTrue(n.navigationBar.backIndicatorImage === image)
    XCTAssertTrue(n.navigationBar.backIndicatorTransitionMaskImage === image)
  }
  func testRemovingCustomBackImageRestoresTheSystemIndicator() {
    let n = make()
    n.navigationBarStyle = style(UIImage(systemName: "arrow.left"))
    n.navigationBarStyle = style()
    XCTAssertNil(n.navigationBar.backIndicatorImage)
    XCTAssertNil(n.navigationBar.backIndicatorTransitionMaskImage)
  }
  func testConcealableScreensHideTheNavigationBar() {
    let n = make()
    let screen = HiddenWalletNavigationScreen()
    n.navigationController(n, willShow: screen, animated: false)
    XCTAssertTrue(n.isNavigationBarHidden)
  }
  func testOrdinaryScreenRestoresTheNavigationBar() {
    let n = make()
    n.navigationController(n, willShow: HiddenWalletNavigationScreen(), animated: false)
    n.navigationController(n, willShow: UIViewController(), animated: false)
    XCTAssertFalse(n.isNavigationBarHidden)
  }
  func testEmptyShadowScreenRemovesTheSeparator() {
    let n = make()
    let screen = ShadowlessWalletScreen()
    n.navigationController(n, willShow: screen, animated: false)
    XCTAssertEqual(n.navigationBar.shadowImage?.size, .zero)
  }
  func testOrdinaryScreenRestoresASeparatorAfterAShadowlessScreen() {
    let n = make()
    n.navigationController(n, willShow: ShadowlessWalletScreen(), animated: false)
    n.navigationController(n, willShow: UIViewController(), animated: false)
    XCTAssertNotEqual(n.navigationBar.shadowImage?.size, .zero)
  }
  func testBackButtonDoesNotRepeatThePreviousScreenTitle() {
    let n = make()
    let screen = UIViewController()
    screen.navigationItem.title = "Previous wallet"
    n.navigationController(n, willShow: screen, animated: false)
    XCTAssertEqual(screen.navigationItem.backBarButtonItem?.title, " ")
  }
  func testExistingBackButtonIdentityIsPreserved() {
    let n = make()
    let screen = UIViewController()
    let button = UIBarButtonItem(title: "Old", style: .plain, target: nil, action: nil)
    screen.navigationItem.backBarButtonItem = button
    n.navigationController(n, willShow: screen, animated: false)
    XCTAssertTrue(screen.navigationItem.backBarButtonItem === button)
    XCTAssertEqual(button.title, " ")
  }
  func testEmptyNavigationStillHasAStyledShadow() {
    let n = WalletNavigationController()
    n.navigationBarStyle = style()
    n.loadViewIfNeeded()
    XCTAssertNotNil(n.navigationBar.shadowImage)
  }
}
private final class HiddenWalletNavigationScreen: UIViewController, WalletNavigationBarConcealable {
}
private final class ShadowlessWalletScreen: UIViewController, WalletDesignableBar {
  var shadowType: WalletBarShadowType { .empty }
}
