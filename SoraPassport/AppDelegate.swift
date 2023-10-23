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
            Task {
                let token = await SCard.shared?.accessToken()
                let title = "Reset SORA Card Token"
                let alertController = UIAlertController(title: title, message: token, preferredStyle: .alert)

                let copyAction = UIAlertAction(title: "Copy",  style: .default) { _ in
                    UIPasteboard.general.string = token
                }
                let removeAction = UIAlertAction(title: "Remove",  style: .destructive) { _ in
                    Task { await SCard.shared?.removeToken() }
                }
                let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in }

                alertController.addAction(cancelAction)
                alertController.addAction(copyAction)
                alertController.addAction(removeAction)

                DispatchQueue.main.async {
                    tableViewController.present(alertController, animated: true)
                }
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

            let alertController = UIAlertController(title: title, message: SCard.shared?.iosClientVersion, preferredStyle: .alert)

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
