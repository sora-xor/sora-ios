import UIKit
import SoraFoundation
import SoraUIKit

final class ChangeAccountWireframe: ChangeAccountWireframeProtocol, AuthorizationPresentable {
    
    func showSignUp(from view: UIViewController, completion: @escaping () -> Void) {
        let navigationController = SoraNavigationController()
        let endAddingBlock = { navigationController.dismiss(animated: true, completion: completion) }
        
        guard let usernameSetup = SetupAccountNameViewFactory.createViewForAdding(endEditingBlock: endAddingBlock) else {
            return
        }

        navigationController.viewControllers = [usernameSetup.controller]
        view.present(navigationController, animated: true)
    }
    
    func showAccountRestore(from view: UIViewController, completion: @escaping () -> Void) {
        let navigationController = SoraNavigationController()
        let endAddingBlock = { navigationController.dismiss(animated: true, completion: completion) }
        
        guard let usernameSetup = AccountImportViewFactory.createViewForAdding(endAddingBlock: endAddingBlock) else {
            return
        }

        navigationController.viewControllers = [usernameSetup.controller]
        view.present(navigationController, animated: true)
    }

    func showStart(from view: UIViewController, completion: @escaping () -> Void) {
        let endAddingBlock: (() -> Void)? = {
            guard
                let setupNameView = SetupAccountNameViewFactory.createViewForImport(endAddingBlock: completion)?.controller,
                let navigationController = view.navigationController?.topModalViewController.children.first as? UINavigationController
            else {
                return
            }

            navigationController.setViewControllers([setupNameView], animated: true)
        }
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        
        let onboardingView = OnboardingMainViewFactory.createWelcomeView(endAddingBlock: endAddingBlock)
        
        let nc = UINavigationController(rootViewController: onboardingView?.controller ?? UIViewController())
        nc.navigationBar.backgroundColor = .clear
        nc.navigationBar.setBackgroundImage(UIImage(), for: .default)
        nc.addCustomTransitioning()
        
        containerView.add(nc)
        view.present(containerView, animated: true)
    }

    func showEdit(account: AccountItem, from controller: UIViewController) {
        if let editor = AccountOptionsViewFactory.createView(account: account) as? UIViewController {
            controller.navigationController?.pushViewController(editor, animated: true)
        }
    }

    func showExportAccounts(accounts: [AccountItem], from controller: UIViewController) {

        let warning = AccountWarningViewController(warningType: .json)
        warning.localizationManager = LocalizationManager.shared
        warning.completion = { [weak self] in
            self?.authorize(animated: true, cancellable: true, inView: nil) { isAuthorized in
                if isAuthorized {
                    guard let jsonExportVC = AccountExportViewFactory.createView(accounts: accounts) as? UIViewController else {
                        return
                    }

                    var navigationArray = controller.navigationController?.viewControllers ?? []
                    navigationArray.remove(at: navigationArray.count - 1)
                    controller.navigationController?.viewControllers = navigationArray
                    controller.navigationController?.pushViewController(jsonExportVC, animated: true)
                }
            }
        }
        if let navigationController = controller.navigationController {
            warning.controller.hidesBottomBarWhenPushed = true
            navigationController.pushViewController(warning.controller, animated: true)
        }
    }
}
