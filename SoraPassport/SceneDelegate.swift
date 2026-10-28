// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0

import UIKit
import GoogleSignIn
import SoraUIKit

/// Hosts the wallet UI in the app's single window scene.
///
/// Apps built with the iOS 26+ SDKs must adopt the UIScene life cycle. All
/// process-wide state stays in `AppDelegate`: the root window and the Splash
/// flow (which starts wallet storage migration) are created once per process.
/// When the system disconnects the scene and later connects a new one, the
/// existing windows are moved to the new scene; nothing is created again.
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    private var appDelegate: AppDelegate? {
        UIApplication.shared.delegate as? AppDelegate
    }

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        // Defense in depth: AppDelegate gives this delegate only to the
        // application role. A display scene must never take the wallet UI.
        guard session.role.isSoraWalletScene,
              let windowScene = scene as? UIWindowScene,
              let appDelegate else {
            return
        }

        window = appDelegate.attachRootWindow(to: windowScene)

        // Cold launch through a URL or a universal link. These are delivered
        // only here; UIKit does not call the open-URL callbacks for them.
        handle(urlContexts: connectionOptions.urlContexts)
        connectionOptions.userActivities.forEach { handle(userActivity: $0) }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        guard scene.session.role.isSoraWalletScene else {
            return
        }
        // Never tear down Splash, the migration flow or any window here.
        appDelegate?.sceneDidDisconnect(scene)
        window = nil
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        guard scene.session.role.isSoraWalletScene else {
            return
        }
        appDelegate?.sceneWillEnterForeground()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        guard scene.session.role.isSoraWalletScene else {
            return
        }
        appDelegate?.sceneDidEnterBackground()
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard scene.session.role.isSoraWalletScene else {
            return
        }
        handle(urlContexts: URLContexts)
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard scene.session.role.isSoraWalletScene else {
            return
        }
        handle(userActivity: userActivity)
    }

    // MARK: - Routing

    private func handle(urlContexts: Set<UIOpenURLContext>) {
        guard let appDelegate, appDelegate.acceptsExternalRoutes else {
            return
        }

        for url in urlContexts.map(\.url) {
            if IrohaConnectCoordinator.shared.handle(url, in: appDelegate.window) {
                continue
            }
            // Google Sign-In 7 completes through ASWebAuthenticationSession;
            // the URL callback is kept for its EMM and fallback flows.
            _ = GIDSignIn.sharedInstance.handle(url)
        }
    }

    private func handle(userActivity: NSUserActivity) {
        guard let appDelegate, appDelegate.acceptsExternalRoutes,
              userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else {
            return
        }

        if IrohaConnectCoordinator.shared.handle(url, in: appDelegate.window) {
            return
        }

        if !DeepLinkService.shared.handle(url: url) {
            Logger.shared.warning("Can't continue activity for url \(url)")
        }
    }
}

// MARK: - Window scene helpers

extension UISceneSession.Role {
    /// True only for the device's own interactive application scene, the one
    /// scene that may host wallet windows: the standard application role, or
    /// the Assistive Access application role on iOS 26+ (if the system ever
    /// uses it for this app, the wallet must still appear rather than a blank
    /// screen). External-display roles (AirPlay mirroring, a wired display)
    /// are never used for wallet UI.
    var isSoraWalletScene: Bool {
        if self == .windowApplication {
            return true
        }
        if #available(iOS 26.0, *), self == .windowAssistiveAccessApplication {
            return true
        }
        return false
    }
}

extension UIApplication {
    /// The window scene that hosts the wallet UI: the root window's scene,
    /// otherwise the foreground application scene, otherwise any connected
    /// application scene. External-display scenes are never returned.
    var soraWindowScene: UIWindowScene? {
        if let scene = (delegate as? AppDelegate)?.window?.windowScene,
           scene.session.role.isSoraWalletScene {
            return scene
        }

        let scenes = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.session.role.isSoraWalletScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }

    /// Height of the status bar of the wallet scene. Replaces the deprecated
    /// `UIApplication.statusBarFrame`, which is not reliable with scenes.
    var soraStatusBarHeight: CGFloat {
        if let height = soraWindowScene?.statusBarManager?.statusBarFrame.height, height > 0 {
            return height
        }
        return (delegate as? AppDelegate)?.window?.safeAreaInsets.top ?? 0
    }

    /// The window that shows the network status banner. Uses the key window
    /// when it can show the banner, otherwise the root wallet window (a
    /// loading or PIN window can be key for a moment).
    var soraStatusPresentableWindow: ApplicationStatusPresentable? {
        if let keyWindow = soraWindowScene?.keyWindow as? ApplicationStatusPresentable {
            return keyWindow
        }
        return (delegate as? AppDelegate)?.window as? ApplicationStatusPresentable
    }
}

extension UIWindow {
    /// Creates an overlay window in the wallet's window scene. A window made
    /// with `init(frame:)` is never displayed in a scene-based app, so a
    /// frame-based window is used only when no scene is connected (tests).
    static func makeSoraSceneWindow() -> UIWindow {
        let window: UIWindow
        if let scene = UIApplication.shared.soraWindowScene {
            window = UIWindow(windowScene: scene)
        } else {
            window = UIWindow(frame: UIScreen.main.bounds)
        }
        // Overlays (loading, toasts) follow the in-app theme too.
        SoramitsuUI.shared.applyInterfaceStyle(to: window)
        return window
    }
}
