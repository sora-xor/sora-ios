// SPDX-License-Identifier: Apache-2.0
import UIKit
import XCTest

@testable import SoraPassport

@MainActor final class AuthorizationNavigationFlowTests: XCTestCase {
  private var fixtures = [AuthorizationFixture]()
  private func make() -> AuthorizationFixture {
    let f = AuthorizationFixture()
    fixtures.append(f)
    return f
  }
  override func tearDown() {
    for f in fixtures { f.showAuthorizationCompletion(with: false) }
    fixtures = []
    super.tearDown()
  }
  func testNavigationAuthorizationPushesTheCreatedScreen() {
    let f = make()
    f.begin()
    XCTAssertTrue(f.navigation.topViewController === f.screen)
    XCTAssertEqual(f.creationFlags, [true])
    XCTAssertTrue(f.screen?.navigationItem.hidesBackButton == true)
    XCTAssertTrue(f.screen?.hidesBottomBarWhenPushed == true)
  }
  func testNavigationAuthorizationHonorsAnimationChoice() {
    let f = make()
    f.begin(animated: false)
    XCTAssertEqual(f.navigation.animation, false)
  }
  func testActiveAuthorizationIsVisibleToOtherFlows() {
    let f = make()
    f.begin()
    XCTAssertTrue((f as AuthorizationAccessible).isAuthorizing)
  }
  func testSuccessfulAuthorizationDeliversSuccessExactlyOnce() {
    let f = make()
    f.begin()
    f.showAuthorizationCompletion(with: true)
    f.showAuthorizationCompletion(with: true)
    XCTAssertEqual(f.results, [true])
  }
  func testCancelledAuthorizationDeliversFailure() {
    let f = make()
    f.begin()
    f.showAuthorizationCompletion(with: false)
    XCTAssertEqual(f.results, [false])
    XCTAssertEqual(f.navigation.viewControllers.count, 1)
  }
  func testCompletionRemovesTheExactScreenFromADeepStack() {
    let f = make()
    let detail = UIViewController()
    f.navigation.pushViewController(detail, animated: false)
    f.begin()
    f.showAuthorizationCompletion(with: true)
    XCTAssertEqual(f.navigation.viewControllers.count, 2)
    XCTAssertTrue(f.navigation.topViewController === detail)
    XCTAssertFalse(f.navigation.viewControllers.contains { $0 === f.screen })
  }
  func testCompletionRunsAfterTheAuthorizationScreenIsRemoved() {
    let f = make()
    var removed = false
    f.begin { _ in removed = !f.navigation.viewControllers.contains { $0 === f.screen } }
    f.showAuthorizationCompletion(with: true)
    XCTAssertTrue(removed)
  }
  func testMissingPresenterReportsFailureInsteadOfHanging() {
    let f = make()
    f.presenter = nil
    f.begin()
    XCTAssertEqual(f.results, [false])
    XCTAssertTrue(f.creationFlags.isEmpty)
  }
  func testMissingAuthorizationScreenReportsFailure() {
    let f = make()
    f.screen = nil
    f.begin()
    XCTAssertEqual(f.results, [false])
    XCTAssertEqual(f.navigation.viewControllers.count, 1)
  }
  func testDuplicateAuthorizationDoesNotPushTwoScreens() {
    let f = make()
    f.begin()
    f.begin()
    XCTAssertEqual(f.navigation.viewControllers.count, 2)
    XCTAssertEqual(f.creationFlags.count, 1)
  }
  func testDuplicateAuthorizationFailsTheNewRequestWithoutReplacingTheFirst() {
    let f = make()
    var first = [Bool]()
    var second = [Bool]()
    f.begin { first.append($0) }
    f.begin { second.append($0) }
    f.showAuthorizationCompletion(with: true)
    XCTAssertEqual(first, [true])
    XCTAssertEqual(second, [false])
  }
  func testNewAuthorizationMayStartFromTheCompletionCallback() {
    let f = make()
    let next = make()
    f.begin { _ in next.begin() }
    f.showAuthorizationCompletion(with: true)
    next.showAuthorizationCompletion(with: true)
    XCTAssertEqual(next.results, [true])
    XCTAssertEqual(next.navigation.viewControllers.count, 1)
  }
  func testCompletionWithoutAnActiveRequestDoesNothing() {
    let f = make()
    f.showAuthorizationCompletion(with: true)
    XCTAssertTrue(f.results.isEmpty)
    XCTAssertEqual(f.navigation.viewControllers.count, 1)
  }
  func testRemovingAnExistingScreenCancelsItsRequest() async {
    let f = make()
    f.begin()
    let done = expectation(description: "removed")
    f.removeExistingAuthViewIfPresented { done.fulfill() }
    await fulfillment(of: [done], timeout: 1)
    XCTAssertEqual(f.results, [false])
    XCTAssertEqual(f.navigation.viewControllers.count, 1)
  }
  func testRemovalCallbackRunsImmediatelyWhenNoRequestIsActive() {
    let f = make()
    var calls = 0
    f.removeExistingAuthViewIfPresented { calls += 1 }
    XCTAssertEqual(calls, 1)
  }
  func testNoncancellableRequestPassesTheChoiceToScreenFactory() {
    let f = make()
    f.authorize(animated: false, cancellable: false, inView: f.navigation) { _ in }
    XCTAssertEqual(f.creationFlags, [false])
  }
}
@MainActor
private final class AuthorizationFixture: AuthorizationPresentable, AuthorizationAccessible {
  var presenter: UIViewController? = UIViewController(),
    screen: UIViewController? = UIViewController()
  let navigation = AuthorizationNavigation(rootViewController: UIViewController())
  var results = [Bool](), creationFlags = [Bool]()
  var authorizationPresentingController: UIViewController? { presenter }
  func createAuthorizationView(cancellable: Bool) -> UIViewController? {
    creationFlags.append(cancellable)
    if creationFlags.count > 1 { screen = UIViewController() }
    return screen
  }
  func begin(animated: Bool = false, callback: ((Bool) -> Void)? = nil) {
    authorize(animated: animated, cancellable: true, inView: navigation) { [weak self] value in
      if let callback { callback(value) } else { self?.results.append(value) }
    }
  }
}
@MainActor private final class AuthorizationNavigation: UINavigationController {
  var animation: Bool?
  override func pushViewController(_ viewController: UIViewController, animated: Bool) {
    animation = animated
    super.pushViewController(viewController, animated: false)
  }
}
