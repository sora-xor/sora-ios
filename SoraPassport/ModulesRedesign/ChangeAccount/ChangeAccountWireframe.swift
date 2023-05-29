import UIKit
import SoraUIKit

final class ChangeAccountWireframe: ChangeAccountWireframeProtocol {
    
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
        let endAddingBlock = { view.dismiss(animated: true, completion: completion) }
        
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

}
