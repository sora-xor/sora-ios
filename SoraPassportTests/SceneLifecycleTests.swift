import XCTest
import UIKit
@testable import SoraPassport

@MainActor
final class SceneLifecycleTests: XCTestCase {
    func testManifestDeclaresSingleWalletScene() throws {
        let manifest = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "UIApplicationSceneManifest") as? [String: Any])
        XCTAssertEqual(manifest["UIApplicationSupportsMultipleScenes"] as? Bool, false)
        let configurations = try XCTUnwrap(manifest["UISceneConfigurations"] as? [String: Any])
        let scenes = try XCTUnwrap(configurations["UIWindowSceneSessionRoleApplication"] as? [[String: Any]])
        XCTAssertEqual(scenes.count, 1)
        XCTAssertEqual(scenes.first?["UISceneDelegateClassName"] as? String, NSStringFromClass(SceneDelegate.self))
        XCTAssertNil(scenes.first?["UISceneStoryboardFile"])
    }

    func testHostLaunchConnectsWindowAndPreservesCompatibilityReference() throws {
        let appDelegate = try XCTUnwrap(UIApplication.shared.delegate as? AppDelegate)
        let window = try XCTUnwrap(appDelegate.window)
        let scene = try XCTUnwrap(window.windowScene)
        let sceneDelegate = try XCTUnwrap(scene.delegate as? SceneDelegate)
        XCTAssertTrue(sceneDelegate.window === window)
        XCTAssertTrue(sceneDelegate.appDelegate === appDelegate)
        XCTAssertNotNil(window.rootViewController)
        XCTAssertTrue(appDelegate.isUnitTesting)
        XCTAssertFalse(window is SoraWindow, "Unit test hosts must not start wallet migration or services")
    }

    func testSceneForwardsForegroundAndBackgroundHooksOnce() throws {
        let scene = try connectedScene()
        let app = LifecycleAppDelegateSpy()
        let delegate = SceneDelegate()
        delegate.appDelegate = app
        delegate.sceneWillEnterForeground(scene)
        delegate.sceneDidEnterBackground(scene)
        XCTAssertEqual(app.foregroundCalls, 1)
        XCTAssertEqual(app.backgroundCalls, 1)
    }

    func testSceneForwardsUniversalLink() throws {
        let scene = try connectedScene()
        let app = LifecycleAppDelegateSpy()
        let delegate = SceneDelegate()
        delegate.appDelegate = app
        let activity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
        activity.webpageURL = URL(string: "https://sora.org/")
        delegate.scene(scene, continue: activity)
        XCTAssertTrue(app.continuedActivity === activity)
    }

    func testDisconnectReleasesCompatibilityWindow() throws {
        let scene = try connectedScene()
        let app = LifecycleAppDelegateSpy()
        let delegate = SceneDelegate()
        let window = UIWindow(windowScene: scene)
        app.window = window
        delegate.window = window
        delegate.appDelegate = app
        delegate.sceneDidDisconnect(scene)
        XCTAssertNil(delegate.window)
        XCTAssertNil(app.window)
    }

    func testOldSceneDisconnectDoesNotClearReplacementWindow() throws {
        let scene = try connectedScene()
        let app = LifecycleAppDelegateSpy()
        let delegate = SceneDelegate()
        let replacement = UIWindow(windowScene: scene)
        delegate.window = UIWindow(windowScene: scene)
        delegate.appDelegate = app
        app.window = replacement
        delegate.sceneDidDisconnect(scene)
        XCTAssertNil(delegate.window)
        XCTAssertTrue(app.window === replacement)
    }

    func testToastWindowUsesApplicationScene() throws {
        let scene = try connectedScene()
        let window = SilentWindow(root: LifecycleToastController())
        defer { window.isHidden = true }
        XCTAssertTrue(window.windowScene === scene)
    }

    func testActivityWindowUsesApplicationScene() throws {
        let scene = try connectedScene()
        var loadable = LifecycleLoadable()
        loadable.showActivityIndicator()
        defer {
            loadable.hideActivityIndicator()
            (UIApplication.shared.delegate as? AppDelegate)?.window?.makeKeyAndVisible()
        }
        XCTAssertTrue(loadable.activityIndicatorWindow?.windowScene === scene)
    }

    private func connectedScene() throws -> UIWindowScene {
        try XCTUnwrap((UIApplication.shared.delegate as? AppDelegate)?.window?.windowScene)
    }
}

private final class LifecycleAppDelegateSpy: AppDelegate {
    var foregroundCalls = 0
    var backgroundCalls = 0
    var continuedActivity: NSUserActivity?

    override func applicationWillEnterForeground(_ application: UIApplication) {
        foregroundCalls += 1
    }

    override func applicationDidEnterBackground(_ application: UIApplication) {
        backgroundCalls += 1
    }

    override func application(_ application: UIApplication, continue userActivity: NSUserActivity,
                              restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        continuedActivity = userActivity
        return true
    }
}

private final class LifecycleToastController: UIViewController, SilentViewController {}
private struct LifecycleLoadable: Loadable {
    var activityIndicatorWindow: UIWindow?
}
