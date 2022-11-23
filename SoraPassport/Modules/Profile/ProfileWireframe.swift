import Foundation
import SoraKeystore
import SoraFoundation
import CommonWallet
import SoraSwiftUI

final class ProfileWireframe: ProfileWireframeProtocol, AuthorizationPresentable {

    private(set) var settingsManager: SettingsManagerProtocol
    private(set) var localizationManager: LocalizationManagerProtocol
    private(set) var disclaimerViewFactory: DisclaimerViewFactoryProtocol
    private(set) var walletContext: CommonWalletContextProtocol

    init(settingsManager: SettingsManagerProtocol,
         localizationManager: LocalizationManagerProtocol,
         disclaimerViewFactory: DisclaimerViewFactoryProtocol,
         walletContext: CommonWalletContextProtocol
    ) {
        self.settingsManager = settingsManager
        self.localizationManager = localizationManager
        self.disclaimerViewFactory = disclaimerViewFactory
        self.walletContext = walletContext
    }

    func showChangeAccountView(from view: ProfileViewProtocol?, completion: @escaping () -> Void) {
        if let changeAccountView = ChangeAccountViewFactory.changeAccountViewController(with: completion),
           let navigationController = view?.controller.navigationController {
            changeAccountView.controller.hidesBottomBarWhenPushed = true
            navigationController.pushViewController(changeAccountView.controller, animated: true)
        }
    }

    func showPersonalDetailsView(from view: ProfileViewProtocol?, completion: @escaping () -> Void) {
        if let personalView = UsernameSetupViewFactory.createViewForEditing(with: completion),
           let navigationController = view?.controller.navigationController {
            personalView.controller.hidesBottomBarWhenPushed = true
            navigationController.pushViewController(personalView.controller, animated: true)
        }
    }

    func showFriendsView(from view: ProfileViewProtocol?) {
        guard let friendsView = FriendsViewFactory.createView(walletContext: walletContext) else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            friendsView.controller.hidesBottomBarWhenPushed = true
            navigationController.pushViewController(friendsView.controller, animated: true)
        }
    }

    func showPassphraseView(from view: ProfileViewProtocol?) {
        authorize(animated: true, cancellable: true, inView: nil) { (isAuthorized) in
            if isAuthorized {
                guard let passphraseView = AccountCreateViewFactory.createViewForBackup() else {
                    return
                }

                if let navigationController = view?.controller.navigationController {
                    passphraseView.controller.hidesBottomBarWhenPushed = true
                    navigationController.pushViewController(passphraseView.controller, animated: true)
                }
            }
        }
    }

    func showChangePin(from view: ProfileViewProtocol) {
        authorize(animated: true, cancellable: true, inView: view.controller.navigationController) { (isAuthorized) in
            if isAuthorized {
                guard let pinView = PinViewFactory.createPinEditView() else {
                    return
                }

                pinView.controller.hidesBottomBarWhenPushed = true
                pinView.controller.modalTransitionStyle = .crossDissolve
                pinView.controller.modalPresentationStyle = .overFullScreen
                view.controller.navigationController?.isNavigationBarHidden = true
                view.controller.navigationController?.pushViewController(pinView.controller, animated: true)

            }
        }
    }

    func switchBiometry(
        toValue: Bool,
        from view: ProfileViewProtocol?,
        successBlock: @escaping (Bool) -> Void) {

            authorize(animated: true, cancellable: true, inView: nil) { (isAuthorized) in
            if isAuthorized {
                self.settingsManager.biometryEnabled = toValue
            }

            successBlock(isAuthorized)
        }
    }

    func showLanguageSelection(from view: ProfileViewProtocol?) {
        guard let languageSelection = LanguageSelectionViewFactory.createView() else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            languageSelection.controller.hidesBottomBarWhenPushed = true
            navigationController.pushViewController(languageSelection.controller, animated: true)
        }
    }

    func showFaq(from view: ProfileViewProtocol?) {
        presentHelp(from: view)
    }

    func showAbout(from view: ProfileViewProtocol?) {
        guard let aboutView = AboutViewFactory.createView() else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            aboutView.controller.hidesBottomBarWhenPushed = true
            navigationController.pushViewController(aboutView.controller, animated: true)
        }
    }

    func showDisclaimer(from view: ProfileViewProtocol?) {
        guard let disclaimerView = disclaimerViewFactory.createView() else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            disclaimerView.controller.hidesBottomBarWhenPushed = true
            navigationController.pushViewController(disclaimerView.controller, animated: true)
        }
    }

    func showNodes(from view: ProfileViewProtocol?) {

        let isNeedRedesign = ApplicationConfig.shared.isNeedRedesign
        guard let nodesView = isNeedRedesign ? NodesViewFactory.createView() : NodesViewFactory.createOldView() else {
            return
        }
        if let navigationController = view?.controller.navigationController {
            nodesView.controller.hidesBottomBarWhenPushed = true
            if !isNeedRedesign {
                navigationController.pushViewController(nodesView.controller, animated: true)
                return
            }
            let containerView = BlurViewController()
            containerView.modalPresentationStyle = .overFullScreen

            let newNav = SoraNavigationController(rootViewController: nodesView.controller)
            newNav.navigationBar.backgroundColor = .clear
            containerView.add(newNav)
            navigationController.present(containerView, animated: true)
        }
    }

    func showLogout(from view: ProfileViewProtocol?, isNeedCustomNodeText: Bool, completionBlock: (() -> Void)?) {
        let languages = localizationManager.preferredLocalizations

        let alertTitle = R.string.localizable.profileLogoutTitle(preferredLanguages: languages)
        var alertMessage = R.string.localizable.logoutDialogBody(preferredLanguages: languages)

        if isNeedCustomNodeText {
            let customNodeMessage = R.string.localizable.logoutRemoveCustomNodes(preferredLanguages: languages)
            alertMessage.append(contentsOf: "\n\n" + customNodeMessage)
        }

        let cancelActionTitle = R.string.localizable.commonCancel(preferredLanguages: languages)
        let logoutActionTitle = R.string.localizable.profileLogoutTitle(preferredLanguages: languages)

        authorize(animated: true, cancellable: true, inView: nil) { (isAuthorized) in
            if isAuthorized {
                let alertView = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)

                let cancelAction = UIAlertAction(title: cancelActionTitle, style: .cancel, handler: nil)
                let logoutAction = UIAlertAction(title: logoutActionTitle, style: .destructive) { (_) in
                    completionBlock?()
                }

                alertView.addAction(cancelAction)
                alertView.addAction(logoutAction)

                view?.controller.present(alertView, animated: true, completion: nil)
            }
        }
    }

    func showRoot() {
        guard let rootWindow = UIApplication.shared.delegate?.window as? SoraWindow else {
            fatalError()
        }

        _ = SplashPresenterFactory.createSplashPresenter(with: rootWindow)
    }

    func showUpdatePinView(from view: UIViewController, with completion: @escaping () -> Void) {
        guard let pincodeViewController = PinViewFactory.createPinUpdateView(completion: completion)?.controller else {
            return
        }
        pincodeViewController.modalPresentationStyle = .overFullScreen
        view.present(pincodeViewController, animated: true)
    }
}

@nonobjc extension UIViewController {
    func add(_ child: UIViewController, frame: CGRect? = nil) {
        addChild(child)

        if let frame = frame {
            child.view.frame = frame
        }

        view.addSubview(child.view)
        child.didMove(toParent: self)
    }

    func remove() {
        willMove(toParent: nil)
        view.removeFromSuperview()
        removeFromParent()
    }
}
