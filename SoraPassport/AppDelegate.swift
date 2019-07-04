/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit
import Fabric
import Crashlytics

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    var isUnitTesting: Bool {
        return ProcessInfo.processInfo.arguments.contains("-UNITTEST")
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        if !isUnitTesting {
            Fabric.with([Crashlytics.self])

            let rootWindow = UIWindow()
            window = rootWindow

            let presenter = RootPresenterFactory.createPresenter(with: rootWindow)
            presenter.loadOnLaunch()

            rootWindow.makeKeyAndVisible()
        }

        return true
    }
}
