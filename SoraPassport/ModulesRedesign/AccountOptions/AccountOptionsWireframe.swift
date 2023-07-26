import Foundation
import IrohaCrypto
import SoraKeystore
import SCard
import SoraFoundation
import SoraUIKit
import SSFCloudStorage

final class AccountOptionsWireframe: AccountOptionsWireframeProtocol, AuthorizationPresentable, Loadable {

    private(set) var localizationManager: LocalizationManagerProtocol
    var activityIndicatorWindow: UIWindow?

    init(localizationManager: LocalizationManagerProtocol) {
        self.localizationManager = localizationManager
    }

    func showPassphrase(from view: AccountOptionsViewProtocol?, account: AccountItem) {
        let warning = AccountWarningViewController(warningType: .passphrase)
        warning.localizationManager = self.localizationManager
        warning.completion = { [weak self] in
            self?.authorize(animated: true, cancellable: true, inView: nil) { isAuthorized in
                guard isAuthorized, let passphraseView = AccountCreateViewFactory.createViewForShowPassthrase(account) else {
                    return
                }
                
                var navigationArray = view?.controller.navigationController?.viewControllers ?? []
                navigationArray.remove(at: navigationArray.count - 1)
                view?.controller.navigationController?.viewControllers = navigationArray
                view?.controller.navigationController?.pushViewController(passphraseView.controller, animated: true)
            }
        }
        if let navigationController = view?.controller.navigationController {
            warning.controller.hidesBottomBarWhenPushed = true
            navigationController.pushViewController(warning.controller, animated: true)
        }
    }
    
    func setupBackupAccountPassword(on controller: AccountOptionsViewProtocol?,
                                    account: OpenBackupAccount,
                                    completion: @escaping () -> Void) {
        guard let setupPasswordView = SetupPasswordViewFactory.createView(
            with: account,
            entryPoint: .profile,
            completion: completion)?.controller else { return }
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        
        let nc = UINavigationController(rootViewController: setupPasswordView)
        nc.navigationBar.backgroundColor = .clear
        nc.navigationBar.setBackgroundImage(UIImage(), for: .default)
        nc.addCustomTransitioning()
        
        containerView.add(nc)
        controller?.controller.present(containerView, animated: true)
    }

    func showRawSeed(from view: AccountOptionsViewProtocol?, account: AccountItem) {
        let warning = AccountWarningViewController(warningType: .rawSeed)
        warning.localizationManager = self.localizationManager
        warning.completion = { [weak self] in
            self?.authorize(animated: true, cancellable: true, inView: nil) { isAuthorized in
                if isAuthorized {
                    guard let jsonExportVC = AccountExportRawSeedViewFactory.createView(account: account) as? UIViewController else {
                        return
                    }

                    var navigationArray = view?.controller.navigationController?.viewControllers ?? []
                    navigationArray.remove(at: navigationArray.count - 1)
                    view?.controller.navigationController?.viewControllers = navigationArray
                    view?.controller.navigationController?.pushViewController(jsonExportVC, animated: true)
                }
            }
        }
        if let navigationController = view?.controller.navigationController {
            warning.controller.hidesBottomBarWhenPushed = true
            navigationController.pushViewController(warning.controller, animated: true)
        }
    }

    func showJson(account: AccountItem, from view: AccountOptionsViewProtocol?) {
        let warning = AccountWarningViewController(warningType: .json)
        warning.localizationManager = self.localizationManager
        warning.completion = { [weak self] in
            self?.authorize(animated: true, cancellable: true, inView: nil) { isAuthorized in
                if isAuthorized {
                    guard let jsonExportVC = AccountExportViewFactory.createView(accounts: [account]) as? UIViewController else {
                        return
                    }

                    var navigationArray = view?.controller.navigationController?.viewControllers ?? []
                    navigationArray.remove(at: navigationArray.count - 1)
                    view?.controller.navigationController?.viewControllers = navigationArray
                    view?.controller.navigationController?.pushViewController(jsonExportVC, animated: true)
                }
            }
        }
        if let navigationController = view?.controller.navigationController {
            warning.controller.hidesBottomBarWhenPushed = true
            navigationController.pushViewController(warning.controller, animated: true)
        }
    }

    func back(from view: AccountOptionsViewProtocol?) {
        DispatchQueue.main.async {
            view?.controller.navigationController?.popViewController(animated: true)
        }
    }

    func showRoot() {
        guard let rootWindow = UIApplication.shared.delegate?.window as? SoraWindow else {
            fatalError()
        }

        _ = SplashPresenterFactory.createSplashPresenter(with: rootWindow)
    }

    func showLogout(from view: AccountOptionsViewProtocol?, isNeedCustomNodeText: Bool, completionBlock: (() -> Void)?) {
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
}
