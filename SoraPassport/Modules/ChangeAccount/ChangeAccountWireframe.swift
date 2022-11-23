import Foundation
import UIKit

final class ChangeAccountWireframe: ChangeAccountWireframeProtocol {
    func showSignUp(from view: UIViewController, completion: @escaping () -> Void) {
        let navigationController = SoraNavigationController()
        let endAddingBlock = { navigationController.dismiss(animated: true, completion: completion) }
        
        guard let usernameSetup = UsernameSetupViewFactory.createViewForAdding(endEditingBlock: endAddingBlock) else {
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
}
