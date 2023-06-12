import Foundation
import IrohaCrypto
import SoraUIKit
import SSFCloudStorage

final class AccountCreateWireframe {
    private var authorizationView: PinSetupViewProtocol?
    lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()
    var endAddingBlock: (() -> Void)?
    var activityIndicatorWindow: UIWindow?
    
    init(endAddingBlock: (() -> Void)? = nil) {
        self.endAddingBlock = endAddingBlock
    }
}

extension AccountCreateWireframe: AccountCreateWireframeProtocol {
    func proceed(on controller: UIViewController?) {
        let view = PinViewFactory.createRedesignPinSetupView()
        
        let containerView = BlurViewController()
        containerView.isClosable = false
        containerView.modalPresentationStyle = .overFullScreen
        containerView.add(view?.controller)
        
        controller?.present(containerView, animated: true)
    }
    
    func confirm(from view: AccountCreateViewProtocol?,
                 request: AccountCreationRequest,
                 metadata: AccountCreationMetadata) {
        guard let confirmationView = AccountConfirmViewFactory.createViewForOnboardingRedesign(request: request,
                                                                                               metadata: metadata) else { return }
        view?.controller.navigationController?.pushViewController(confirmationView.controller, animated: true)
    }
    
    func setupBackupAccountPassword(on controller: AccountCreateViewProtocol?, account: OpenBackupAccount) {
        guard let setupPasswordView = SetupPasswordViewFactory.createView(with: account,
                                                                          completion: endAddingBlock)?.controller else { return }
        controller?.controller.navigationController?.pushViewController(setupPasswordView, animated: true)
    }
}

extension AccountCreateWireframe: Authorizable {
    func authorize() {
        guard let presentingController = UIApplication.shared.keyWindow?.rootViewController?.topModalViewController,
              let authorizationView = PinViewFactory.createRedesignScreenAuthorizationView(with: self, cancellable: false) else { return }

        authorizationView.controller.modalTransitionStyle = .crossDissolve
        authorizationView.controller.modalPresentationStyle = .fullScreen
        self.authorizationView = authorizationView

        presentingController.present(authorizationView.controller, animated: true, completion: nil)
    }
}

extension AccountCreateWireframe: ScreenAuthorizationWireframeProtocol {
    func showAuthorizationCompletion(with result: Bool) {
        guard result else { return }
        self.authorizationView?.controller.dismiss(animated: true)
    }
}
