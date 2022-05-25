import Foundation
import SoraKeystore
import SoraFoundation

final class ProfileWireframe: ProfileWireframeProtocol, AuthorizationPresentable {

    private(set) var settingsManager: SettingsManagerProtocol
    private(set) var localizationManager: LocalizationManagerProtocol
    private(set) var disclaimerViewFactory: DisclaimerViewFactoryProtocol

    init(settingsManager: SettingsManagerProtocol,
         localizationManager: LocalizationManagerProtocol,
         disclaimerViewFactory: DisclaimerViewFactoryProtocol
    ) {
        self.settingsManager = settingsManager
        self.localizationManager = localizationManager
        self.disclaimerViewFactory = disclaimerViewFactory
    }

    func showPersonalDetailsView(from view: ProfileViewProtocol?) {
        if let personalView = UsernameSetupViewFactory.createViewForEditing(),
           let navigationController = view?.controller.navigationController {
            personalView.controller.hidesBottomBarWhenPushed = true
            navigationController.pushViewController(personalView.controller, animated: true)
        }
    }

    func showFriendsView(from view: ProfileViewProtocol?) {
        guard let friendsView = FriendsViewFactory.createView() else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            friendsView.controller.hidesBottomBarWhenPushed = true
            navigationController.pushViewController(friendsView.controller, animated: true)
        }
    }

    func showPassphraseView(from view: ProfileViewProtocol?) {
        authorize(animated: true, cancellable: true) { (isAuthorized) in
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

    func showChangePin(from view: ProfileViewProtocol?) {
        authorize(animated: true, cancellable: true) { (isAuthorized) in
            if isAuthorized {
                guard let pinView = PinViewFactory.createPinEditView() else {
                    return
                }

                pinView.controller.hidesBottomBarWhenPushed = true
                pinView.controller.modalTransitionStyle = .crossDissolve
                pinView.controller.modalPresentationStyle = .overFullScreen
                view?.controller.present(pinView.controller, animated: true, completion: nil)
            }
        }
    }

    func switchBiometry(
        toValue: Bool,
        from view: ProfileViewProtocol?,
        successBlock: @escaping (Bool) -> Void) {

        authorize(animated: true, cancellable: true) { (isAuthorized) in
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

    func showLogout(from view: ProfileViewProtocol?, completionBlock: (() -> Void)?) {
        let languages = localizationManager.preferredLocalizations

        let alertTitle = R.string.localizable.profileLogoutTitle(preferredLanguages: languages)
        let alertMessage = R.string.localizable.logoutDialogBody(preferredLanguages: languages)
        let cancelActionTitle = R.string.localizable.commonCancel(preferredLanguages: languages)
        let logoutActionTitle = R.string.localizable.profileLogoutTitle(preferredLanguages: languages)

        authorize(animated: true, cancellable: true) { (isAuthorized) in
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
}
