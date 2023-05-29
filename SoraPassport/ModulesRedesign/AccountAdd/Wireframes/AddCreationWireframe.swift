import Foundation
import IrohaCrypto
import SoraUIKit

final class AddCreationWireframe: AccountCreateWireframeProtocol {
    lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()
    var endAddingBlock: (() -> Void)?

    func confirm(from view: AccountCreateViewProtocol?,
                 request: AccountCreationRequest,
                 metadata: AccountCreationMetadata) {
        let confirmView = AccountConfirmViewFactory.createViewForRedesignAdding(request: request, metadata: metadata, endAddingBlock: endAddingBlock)?.controller
        
        guard let accountConfirmation = confirmView else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            navigationController.pushViewController(accountConfirmation, animated: true)
        }
    }
    
    func proceed(on controller: UIViewController?) {
        if endAddingBlock != nil {
            endAddingBlock?()
            return
        }
        let view = PinViewFactory.createRedesignPinSetupView()
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        containerView.add(view?.controller)
        
        controller?.present(containerView, animated: true)
    }
}
