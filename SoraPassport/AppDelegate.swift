// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import UIKit
#if !NO_FIREBASE
import FirebaseCore
#endif
import GoogleSignIn
import SoraUIKit
import SoraFoundation

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    /// The process-wide root window. It is created once by
    /// `attachRootWindow(to:)` and reached by many presenters through
    /// `UIApplication.shared.delegate?.window`.
    var window: UIWindow?

    private var migrationEvidenceDecision: RetainedMigrationEvidenceHarness.BootstrapDecision = .inactive
    private var hasEnteredBackground = false
    private var detachedSceneWindows: [UIWindow] = []
    private weak var detachedKeyWindow: UIWindow?

    var isUnitTesting: Bool {
        return ProcessInfo.processInfo.arguments.contains("-UNITTEST")
    }

    /// External URLs and universal links are routed only to the wallet UI,
    /// never to the migration-evidence screen or to a unit-test host.
    var acceptsExternalRoutes: Bool {
        window != nil && migrationEvidenceDecision != .evidenceOnly
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        migrationEvidenceDecision =
            RetainedMigrationEvidenceHarness.shared.bootstrap()
        if migrationEvidenceDecision == .evidenceOnly {
            return true
        }

        if !isUnitTesting {
            #if !NO_FIREBASE
            FirebaseApp.configure()
            #endif

            setupLanguage()
        }

        return true
    }

    // MARK: - Scene life cycle

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        Self.sceneConfiguration(for: connectingSceneSession.role)
    }

    /// Only the device's own application scene hosts the wallet. Any other
    /// role (AirPlay mirroring, a USB-C/HDMI display) gets no delegate, so the
    /// system mirrors the phone screen and never moves the wallet's windows
    /// there or sends that scene's life-cycle events to the app.
    static func sceneConfiguration(for role: UISceneSession.Role) -> UISceneConfiguration {
        guard role.isSoraWalletScene else {
            return UISceneConfiguration(name: nil, sessionRole: role)
        }

        let configuration = UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: role
        )
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }

    /// Shows the app's UI in `windowScene` and returns the root window, or nil
    /// for a unit-test host.
    ///
    /// The root window and the Splash flow are created at most once per
    /// process: creating Splash starts wallet storage migration, so a scene
    /// that reconnects gets the existing windows moved to it instead.
    func attachRootWindow(to windowScene: UIWindowScene) -> UIWindow? {
        guard windowScene.session.role.isSoraWalletScene else {
            return nil
        }

        if let window {
            reattachWindows(rootWindow: window, to: windowScene)
            return window
        }

        if migrationEvidenceDecision == .evidenceOnly {
            let evidenceWindow = UIWindow(windowScene: windowScene)
            evidenceWindow.backgroundColor = .systemBackground
            evidenceWindow.rootViewController =
                RetainedMigrationEvidenceHarness.shared
                    .makeEvidenceOnlyViewController()
            window = evidenceWindow
            RetainedMigrationEvidenceHarness.shared
                .installStatusSurface(in: evidenceWindow)
            evidenceWindow.makeKeyAndVisible()
            return evidenceWindow
        }

        guard !isUnitTesting else {
            return nil
        }

        // The device appearance is known once the scene is connected. Read it
        // before the first screen is built, then make system UI (alerts,
        // keyboards, sheets, Liquid Glass) follow the in-app theme.
        SoramitsuUI.shared.refreshSystemTheme()
        let rootWindow = SoraWindow(windowScene: windowScene)
        SoramitsuUI.shared.applyInterfaceStyle(to: rootWindow)
        rootWindow.backgroundColor = SoramitsuUI.shared.theme.palette.color(.bgPage)
        window = rootWindow

        SplashPresenterFactory.createSplashPresenter(with: rootWindow)

        if migrationEvidenceDecision == .authorized {
            RetainedMigrationEvidenceHarness.shared
                .installStatusSurface(in: rootWindow)
        }

        rootWindow.makeKeyAndVisible()
        return rootWindow
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        guard let windowScene = scene as? UIWindowScene,
              windowScene.session.role.isSoraWalletScene else {
            return
        }
        // Keep the app's own windows (root, PIN lock, loading and toast
        // overlays) so a later scene shows them unchanged. UIKit's private
        // windows (keyboard, text effects) belong to the old scene.
        detachedKeyWindow = windowScene.keyWindow
        detachedSceneWindows = windowScene.windows.filter { candidate in
            candidate === window ||
                candidate is SoraWindow ||
                candidate is SilentWindow ||
                type(of: candidate) == UIWindow.self
        }
    }

    func sceneWillEnterForeground() {
        // UIKit also calls this when the scene first connects. Match the old
        // applicationWillEnterForeground, which ran only after a background.
        guard !isUnitTesting, hasEnteredBackground else {
            return
        }
        resumePendingNexusTransactions()
    }

    func sceneDidEnterBackground() {
        hasEnteredBackground = true
        IrohaConnectCoordinator.shared.applicationDidEnterBackground()
    }

    private func reattachWindows(rootWindow: UIWindow, to windowScene: UIWindowScene) {
        let detachedWindows = detachedSceneWindows
        let previousKeyWindow = detachedKeyWindow
        detachedSceneWindows = []
        detachedKeyWindow = nil

        if rootWindow.windowScene !== windowScene {
            rootWindow.windowScene = windowScene
        }
        for detached in detachedWindows where detached !== rootWindow && detached.windowScene !== windowScene {
            detached.windowScene = windowScene
        }

        rootWindow.makeKeyAndVisible()

        // A PIN lock or loading window that was key stays key and on top.
        if let previousKeyWindow,
           previousKeyWindow !== rootWindow,
           previousKeyWindow.windowScene === windowScene,
           !previousKeyWindow.isHidden {
            previousKeyWindow.makeKey()
        }
    }

    func setupLanguage() {
        let semanticContentAttribute: UISemanticContentAttribute = LocalizationManager.shared.isRightToLeft ? .forceRightToLeft : .forceLeftToRight
        UIView.appearance().semanticContentAttribute = semanticContentAttribute
    }

    private func resumePendingNexusTransactions() {
        Task { @MainActor in
            // Reconcile every network journal entry regardless of selected
            // wallet or Taira visibility. This path performs status lookups
            // only and never retries, signs, or submits a transaction.
            NexusTransactionRuntime.shared.resumePendingAfterProcessStart()
            // Ordinary SORA2 ambiguity recovery is also status-only. Its
            // runtime independently requires both verified wallet storage and
            // a ready canonical SORA2 chain before doing any RPC work.
            Sora2PendingSubmissionRecoveryRuntime.shared
                .resumePendingAfterProcessStart()
        }
    }
}

fileprivate extension String {
    func groups(for regexPattern: String) -> [[String]] {
        do {
            let text = self
            let regex = try NSRegularExpression(pattern: regexPattern)
            let matches = regex.matches(in: text,
                                        range: NSRange(text.startIndex..., in: text))
            return matches.map { match in
                return (0..<match.numberOfRanges).map {
                    let rangeBounds = match.range(at: $0)
                    guard let range = Range(rangeBounds, in: text) else {
                        return ""
                    }
                    return String(text[range])
                }
            }
        } catch {
            print("Invalid application URL regex")
            return []
        }
    }
}

fileprivate extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < endIndex else {
            return nil
        }
        return self[index]
    }
}
