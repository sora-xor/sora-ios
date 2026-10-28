// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit
import Firebase
import SCard
import GoogleSignIn
import SoraUIKit
import SoraFoundation
#if F_DEV
import FLEX
#endif

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    var isUnitTesting: Bool {
        return ProcessInfo.processInfo.arguments.contains("-UNITTEST")
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        if !isUnitTesting {
            FirebaseApp.configure()

            initFlex()
            setupLanguage()
            
            let rootWindow = SoraWindow()
            rootWindow.backgroundColor = SoramitsuUI.shared.theme.palette.color(.bgPage)
            window = rootWindow

            SplashPresenterFactory.createSplashPresenter(with: rootWindow)

            rootWindow.makeKeyAndVisible()
        }

        return true
    }

    func application(_ application: UIApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb, let url = userActivity.webpageURL {

            let isHandled = DeepLinkService.shared.handle(url: url)

            if !isHandled {
                Logger.shared.warning("Can't continue activity for url \(url)")
            }

            return isHandled
        } else {
            return false
        }
    }

    private func initFlex() {
        #if F_DEV

        FLEXManager.shared.registerGlobalEntry(withName: "Reset SORA Card Token") { tableViewController in
            let isUserSignIn = SCard.shared?.isUserSignIn ?? false
            let message = "User is signed in: \(isUserSignIn)"
            let title = "Reset SORA Card Token"
            let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)

            let copyAction = UIAlertAction(title: "Copy",  style: .default) { _ in
                UIPasteboard.general.string = message
            }
            let removeAction = UIAlertAction(title: "Logout",  style: .destructive) { _ in
                SCard.shared?.logout()
            }
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in }

            alertController.addAction(cancelAction)
            alertController.addAction(copyAction)
            alertController.addAction(removeAction)

            DispatchQueue.main.async {
                tableViewController.present(alertController, animated: true)
            }
        }

        guard let url = Bundle.main.url(forResource: "/Podfile", withExtension: "lock") else { return }
        let data = try? String(contentsOf: url, encoding: .utf8)

        let scardInfo = data?.groups(for: "SCard:\n\\s*:[a-z]*:.*\n\\s*:[a-z]*:.*")
        let commit = scardInfo?[safe: 1]?[safe: 0]?.groups(for: ":commit: (.*)")[safe: 0]?[safe: 1]?.prefix(10) ?? "-"
        let scardInfoMessage = scardInfo?.flatMap{ $0 }.joined()

        FLEXManager.shared.registerGlobalEntry(withName: "SCard commit:\(commit)") { tableViewController in

            let title = "SCard pod version"
            let alertController = UIAlertController(title: title, message: scardInfoMessage, preferredStyle: .alert)

            let copyAction = UIAlertAction(title: "Copy",  style: .default) { _ in
                UIPasteboard.general.string = data
            }
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in }

            alertController.addAction(cancelAction)
            alertController.addAction(copyAction)

            DispatchQueue.main.async {
                tableViewController.present(alertController, animated: true)
            }
        }

        FLEXManager.shared.registerGlobalEntry(withName: "SCard Config") { tableViewController in

            let title = "SCard Config"

            let alertController = UIAlertController(title: title, message: SCard.shared?.configuration, preferredStyle: .alert)

            let copyAction = UIAlertAction(title: "Copy",  style: .default) { _ in
                UIPasteboard.general.string = data
            }
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in }

            alertController.addAction(cancelAction)
            alertController.addAction(copyAction)

            DispatchQueue.main.async {
                tableViewController.present(alertController, animated: true)
            }
        }

        FLEXManager.shared.registerGlobalEntry(withName: "SCard update version") { tableViewController in

            let title = "SCard update version"

            let alertController = UIAlertController(title: title, message: SCard.currentSDKVersion, preferredStyle: .alert)

            let copyAction = UIAlertAction(title: "Copy",  style: .default) { _ in
                UIPasteboard.general.string = data
            }
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in }

            alertController.addAction(cancelAction)
            alertController.addAction(copyAction)

            DispatchQueue.main.async {
                tableViewController.present(alertController, animated: true)
            }
        }

        #endif
    }
    
    func setupLanguage() {
        let semanticContentAttribute: UISemanticContentAttribute = LocalizationManager.shared.isRightToLeft ? .forceRightToLeft : .forceLeftToRight
        UIView.appearance().semanticContentAttribute = semanticContentAttribute
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
        } catch let error {
            print("invalid regex: \(error.localizedDescription)")
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


extension SCard.Config: CustomDebugStringConvertible {
    public var debugDescription: String {

        """
        SCard.Config
        backendUrl: \(backendUrl)
        pwAuthDomain: \(pwAuthDomain)
        pwApiKey: \(pwApiKey)
        kycUrl: \(kycUrl)
        kycUsername: \(kycUsername)
        kycPassword: \(kycPassword)
        environmentType: \(environmentType)
        themeMode: \(themeMode)
        """
    }
}
