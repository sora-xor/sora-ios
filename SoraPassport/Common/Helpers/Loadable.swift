import UIKit

protocol Loadable {
    var activityIndicatorWindow: UIWindow? { get set }
    mutating func showActivityIndicator()
    mutating func hideActivityIndicator()
}

extension Loadable {
    mutating func showActivityIndicator() {
        activityIndicatorWindow = UIWindow(frame: UIScreen.main.bounds)
        activityIndicatorWindow?.windowLevel = UIWindow.Level.alert
        activityIndicatorWindow?.rootViewController = ActivityIndicatorViewController()
        activityIndicatorWindow?.isHidden = false
        activityIndicatorWindow?.makeKeyAndVisible()
    }
    
    mutating func hideActivityIndicator() {
        activityIndicatorWindow?.isHidden = true
        activityIndicatorWindow = nil
    }
}
