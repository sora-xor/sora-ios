import XCTest
import UIKit
@testable import SoraPassport

/// The wallet has one application scene. `AppDelegate` owns the process-wide
/// root window and creates the Splash flow (which starts wallet storage
/// migration) at most once per process; `SceneDelegate` attaches that window
/// to the connected wallet scene and routes links only to the wallet UI.
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
        // The configuration AppDelegate returns for the application role is
        // the one the manifest declares.
        XCTAssertEqual(
            scenes.first?["UISceneConfigurationName"] as? String,
            AppDelegate.sceneConfiguration(for: .windowApplication).name
        )
    }

    func testUnitTestHostConnectsTheWalletSceneWithoutStartingTheWallet() throws {
        let appDelegate = try XCTUnwrap(UIApplication.shared.delegate as? AppDelegate)
        let scene = try connectedScene()
        let sceneDelegate = try XCTUnwrap(scene.delegate as? SceneDelegate)
        XCTAssertTrue(appDelegate.isUnitTesting)
        // attachRootWindow(to:) builds no root window (and so no Splash) in a
        // unit-test host.
        XCTAssertNil(sceneDelegate.window)
        XCTAssertFalse(appDelegate.window is SoraWindow, "Unit test hosts must not start wallet migration or services")
    }

    func testExternalRoutesNeedTheWalletWindow() throws {
        let scene = try connectedScene()
        let app = AppDelegate()
        XCTAssertFalse(app.acceptsExternalRoutes, "A host without the wallet window must not route links")
        let window = UIWindow(windowScene: scene)
        defer { window.isHidden = true }
        app.window = window
        XCTAssertTrue(app.acceptsExternalRoutes)
    }

    func testDisconnectKeepsTheRootWindowAndReconnectReusesIt() throws {
        let scene = try connectedScene()
        let app = AppDelegate()
        let root = UIWindow(windowScene: scene)
        root.rootViewController = UIViewController()
        defer {
            root.isHidden = true
            (UIApplication.shared.delegate as? AppDelegate)?.window?.makeKeyAndVisible()
        }
        app.window = root
        app.sceneDidDisconnect(scene)
        // A disconnected scene never releases the root window: a new one
        // would start a second Splash and wallet storage migration.
        XCTAssertTrue(app.window === root)
        XCTAssertTrue(app.attachRootWindow(to: scene) === root)
        XCTAssertTrue(root.windowScene === scene)
        XCTAssertTrue(app.window === root)
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
        try XCTUnwrap(UIApplication.shared.soraWindowScene)
    }
}

private final class LifecycleToastController: UIViewController, SilentViewController {}
private struct LifecycleLoadable: Loadable {
    var activityIndicatorWindow: UIWindow?
}
