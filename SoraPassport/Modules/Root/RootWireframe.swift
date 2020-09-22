import UIKit

final class RootWireframe: RootWireframeProtocol {
    func showOnboarding(on view: UIWindow) {
        let onboardingView = OnboardingMainViewFactory.createView()
        let onboardingController = onboardingView?.controller ?? UIViewController()

        let navigationController = SoraNavigationController()
        navigationController.viewControllers = [onboardingController]

        view.rootViewController = navigationController
    }

    func showLocalAuthentication(on view: UIWindow) {
        let pincodeView = PinViewFactory.createSecuredPinView()
        let pincodeController = pincodeView?.controller ?? UIViewController()

        view.rootViewController = pincodeController
    }

    func showAuthVerification(on view: UIWindow) {
        let authVerificationView = StartupViewFactory.createView()
        let authVerificationController = authVerificationView?.controller ?? UIViewController()

        view.rootViewController = authVerificationController
    }

    func showBroken(on view: UIWindow) {
        // normally user must not see this but on malicious devices it is possible
        view.backgroundColor = .red
    }
}
