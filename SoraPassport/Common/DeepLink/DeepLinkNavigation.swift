import UIKit

protocol DeepLinkNavigatorProtocol {
    func navigate(to invitation: InvitationDeepLink) -> Bool
}

protocol DeepLinkProtocol {
    func accept(navigator: DeepLinkNavigatorProtocol) -> Bool
}

extension DeepLinkNavigatorProtocol {
    func navigate(to invitation: InvitationDeepLink) -> Bool {
        guard
            let rootViewController = UIApplication.shared.delegate?.window??.rootViewController,
            rootViewController.presentedViewController == nil else {
            return false
        }

        let title = R.string.localizable.deepLinkInvitationAlreadyRegisteredTitle()
        let message = R.string.localizable.deepLinkInvitationAlreadyRegisteredMessage()

        let alertViewController = UIAlertController(title: title,
                                                    message: message,
                                                    preferredStyle: .alert)

        alertViewController.addAction(UIAlertAction(title: R.string.localizable.close(),
                                                    style: .cancel,
                                                    handler: nil))

        rootViewController.present(alertViewController, animated: true, completion: nil)

        return true
    }
}
