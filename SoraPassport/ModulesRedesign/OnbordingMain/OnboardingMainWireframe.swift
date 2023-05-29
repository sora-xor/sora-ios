import Foundation

final class OnboardingMainWireframe: OnboardingMainWireframeProtocol {
    lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()

    var endAddingBlock: (() -> Void)?

    func showSignup(from view: OnboardingMainViewProtocol?) {
        if let endBlock = endAddingBlock {

            let usernameSetup = SetupAccountNameViewFactory.createViewForAdding(endEditingBlock: endBlock)
            guard let usernameSetup = usernameSetup else {
                return
            }
            if let navigationController = view?.controller.navigationController {
                navigationController.pushViewController(usernameSetup.controller, animated: true)
            }
        } else {
            let setupAccountNameView = SetupAccountNameViewFactory.createViewForOnboarding()
            guard let usernameSetup = setupAccountNameView else {
                return
            }
            if let navigationController = view?.controller.navigationController {
                navigationController.pushViewController(usernameSetup.controller, animated: true)
            }
        }
    }
    
    func showAccountRestoreRedesign(from view: OnboardingMainViewProtocol?, sourceType: AccountImportSource) {
        if let endBlock = endAddingBlock {
            let redesignImport = AccountImportViewFactory.createViewForRedesignAdding(sourceType: sourceType, endAddingBlock: endBlock)
            let restorationController = redesignImport
            guard let restorationController = restorationController?.controller else { return }
            if let navigationController = view?.controller.navigationController {
                navigationController.pushViewController(restorationController, animated: true)
            }

        } else {
            guard let restorationController = AccountImportViewFactory.createViewForOnboardingRedesign(sourceType: sourceType)?.controller else {
                return
            }
            if let navigationController = view?.controller.navigationController {
                navigationController.pushViewController(restorationController, animated: true)
            }
        }

    }

    func showAccountRestore(from view: OnboardingMainViewProtocol?) {
        guard
            let endBlock = endAddingBlock,
            let restorationController = AccountImportViewFactory.createViewForAdding(endAddingBlock: endBlock)?.controller else {
                return
            }
        if let navigationController = view?.controller.navigationController {
            navigationController.pushViewController(restorationController, animated: true)
        }
        

    }

    func showKeystoreImport(from view: OnboardingMainViewProtocol?) {
        if
            let navigationController = view?.controller.navigationController,
            navigationController.viewControllers.count == 1,
            navigationController.presentedViewController == nil {
            showAccountRestore(from: view)
        }
    }
}
