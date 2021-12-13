import UIKit
import Firebase

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

            let rootWindow = SoraWindow()
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
}
