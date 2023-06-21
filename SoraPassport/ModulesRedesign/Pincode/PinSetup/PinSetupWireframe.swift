import UIKit
import SoraFoundation

class PinSetupWireframe: PinSetupWireframeProtocol, AlertPresentable, ErrorPresentable {
    lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()

    let localizationManager: LocalizationManagerProtocol

    init(localizationManager: LocalizationManagerProtocol) {
        self.localizationManager = localizationManager
    }

    func dismiss(from view: PinSetupViewProtocol?) {
        if let presentingViewController = view?.controller.presentingViewController {
            presentingViewController.dismiss(animated: true, completion: nil)
        }
        if let navigationController = view?.controller.navigationController {
            navigationController.popViewController(animated: true)
        }
    }

    func showMain(from view: PinSetupViewProtocol?) {
        guard let mainViewController = MainTabBarViewFactory.createView()?.controller else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.rootAnimator.animateTransition(to: mainViewController)
        }
    }

    public func showSignup(from view: PinSetupViewProtocol?) {
    }

    func showPinUpdatedNotify(from view: PinSetupViewProtocol?, completionBlock: @escaping () -> Void) {

        let languages = localizationManager.preferredLocalizations

        let success = ModalAlertFactory.createSuccessAlert(R.string.localizable.pincodeChangeSuccess(preferredLanguages: languages))

        view?.controller.present(success, animated: true, completion: {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                completionBlock()
            }
        })
    }
}
