import UIKit
import SoraUI

protocol UnsupportedVersionPresentable: class {
    func presentUnsupportedVersion(for data: SupportedVersionData, on window: UIWindow?, animated: Bool)
}

extension UnsupportedVersionPresentable {
    func presentUnsupportedVersion(for data: SupportedVersionData, on window: UIWindow?, animated: Bool) {
        guard let presentingWindow = window ?? UIApplication.shared.keyWindow else {
            return
        }

        guard let unsupportedVersionView = UnsupportedVersionViewFactory
            .createView(supportedVersionData: data) else {
            return
        }

        if animated {
            let transitionAnimator = TransitionAnimator(type: .fade)
            transitionAnimator.animate(view: presentingWindow, completionBlock: nil)
        }

        presentingWindow.rootViewController = unsupportedVersionView.controller
    }
}
