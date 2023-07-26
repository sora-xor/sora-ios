import Foundation
import IrohaCrypto
import SoraUIKit
import SSFCloudStorage

final class AddCreationWireframe: AccountCreateWireframeProtocol {
    
    lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()
    var endAddingBlock: (() -> Void)?
    var activityIndicatorWindow: UIWindow?
    var isNeedSetupName: Bool = true

    func confirm(from view: AccountCreateViewProtocol?,
                 request: AccountCreationRequest,
                 metadata: AccountCreationMetadata) {
        let confirmView = AccountConfirmViewFactory.createViewForRedesignAdding(request: request,
                                                                                metadata: metadata,
                                                                                isNeedSetupName: isNeedSetupName,
                                                                                endAddingBlock: endAddingBlock)?.controller
        
        guard let accountConfirmation = confirmView else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            navigationController.pushViewController(accountConfirmation, animated: true)
        }
    }
    
    func proceed(on controller: UIViewController?) {
        if endAddingBlock != nil {
            guard
                !isNeedSetupName,
                let setupNameView = SetupAccountNameViewFactory.createViewForImport(endAddingBlock: endAddingBlock)?.controller,
                let navigationController = controller?.navigationController?.topModalViewController.children.first as? UINavigationController
            else {
                controller?.navigationController?.dismiss(animated: true, completion: endAddingBlock)
                return
            }

            navigationController.setViewControllers([setupNameView], animated: true)
            return
        }
        let view = PinViewFactory.createRedesignPinSetupView()
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        containerView.add(view?.controller)
        
        controller?.present(containerView, animated: true)
    }
    
    func setupBackupAccountPassword(
        on controller: AccountCreateViewProtocol?,
        account: OpenBackupAccount,
        createAccountRequest: AccountCreationRequest,
        createAccountService: CreateAccountServiceProtocol,
        mnemonic: IRMnemonicProtocol
    ) {
        guard let setupPasswordView = SetupPasswordViewFactory.createView(
            with: account,
            createAccountRequest: createAccountRequest,
            createAccountService: createAccountService,
            mnemonic: mnemonic,
            entryPoint: .onboarding,
            completion: endAddingBlock
        )?.controller else { return }
        controller?.controller.navigationController?.pushViewController(setupPasswordView, animated: true)
    }
}
