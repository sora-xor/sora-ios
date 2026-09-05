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

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    var isUnitTesting: Bool {
        return ProcessInfo.processInfo.arguments.contains("-UNITTEST")
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let migrationEvidenceDecision =
            RetainedMigrationEvidenceHarness.shared.bootstrap()
        if migrationEvidenceDecision == .evidenceOnly {
            let evidenceWindow = UIWindow(frame: UIScreen.main.bounds)
            evidenceWindow.backgroundColor = .systemBackground
            evidenceWindow.rootViewController =
                RetainedMigrationEvidenceHarness.shared
                    .makeEvidenceOnlyViewController()
            window = evidenceWindow
            RetainedMigrationEvidenceHarness.shared
                .installStatusSurface(in: evidenceWindow)
            evidenceWindow.makeKeyAndVisible()
            return true
        }

        if !isUnitTesting {
            #if !NO_FIREBASE
            FirebaseApp.configure()
            #endif

            setupLanguage()
            
            let rootWindow = SoraWindow()
            rootWindow.backgroundColor = SoramitsuUI.shared.theme.palette.color(.bgPage)
            window = rootWindow

            SplashPresenterFactory.createSplashPresenter(with: rootWindow)

            if migrationEvidenceDecision == .authorized {
                RetainedMigrationEvidenceHarness.shared
                    .installStatusSurface(in: rootWindow)
            }

            rootWindow.makeKeyAndVisible()

            if let connectURL = launchOptions?[.url] as? URL,
               IrohaConnectCoordinator.shared.canHandle(connectURL) {
                IrohaConnectCoordinator.shared.handle(connectURL, in: rootWindow)
            }
        }

        return true
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        guard !isUnitTesting else {
            return
        }
        resumePendingNexusTransactions()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        IrohaConnectCoordinator.shared.applicationDidEnterBackground()
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        if IrohaConnectCoordinator.shared.handle(url, in: window) {
            return true
        }
        return GIDSignIn.sharedInstance.handle(url)
    }

    func application(_ application: UIApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb, let url = userActivity.webpageURL {

            if IrohaConnectCoordinator.shared.handle(url, in: window) {
                return true
            }

            let isHandled = DeepLinkService.shared.handle(url: url)

            if !isHandled {
                Logger.shared.warning("Can't continue activity for url \(url)")
            }

            return isHandled
        } else {
            return false
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
