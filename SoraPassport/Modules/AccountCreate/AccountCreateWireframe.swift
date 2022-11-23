import Foundation
import IrohaCrypto

final class AccountCreateWireframe {
    private var authorizationView: PinSetupViewProtocol?
}

extension AccountCreateWireframe: AccountCreateWireframeProtocol {
    func confirm(from view: AccountCreateViewProtocol?,
                 request: AccountCreationRequest,
                 metadata: AccountCreationMetadata) {
        guard let accountConfirmation = AccountConfirmViewFactory
            .createViewForOnboarding(request: request, metadata: metadata)?.controller else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            navigationController.pushViewController(accountConfirmation, animated: true)
        }
    }
}

extension AccountCreateWireframe: Authorizable {
    func authorize() {
        guard let presentingController = UIApplication.shared.keyWindow?.rootViewController?.topModalViewController,
              let authorizationView = PinViewFactory.createScreenAuthorizationView(with: self, cancellable: false) else { return }

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
