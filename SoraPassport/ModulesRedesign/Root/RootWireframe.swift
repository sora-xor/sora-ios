import UIKit
import SoraUIKit

final class RootWireframe: RootWireframeProtocol {
    func showOnboarding(on view: UIWindow) {
        let containerView = WelcomeBackgroundViewController()
        
        let onboardingView = OnboardingMainViewFactory.createWelcomeView()
        
        let nc = UINavigationController(rootViewController: onboardingView?.controller ?? UIViewController())
        nc.navigationBar.backgroundColor = .clear
        nc.navigationBar.setBackgroundImage(UIImage(), for: .default)
        nc.addCustomTransitioning()
        
        containerView.add(nc)
        
        view.rootViewController = containerView
    }

    func showLocalAuthentication(on view: UIWindow) {
        let pinView = PinViewFactory.createRedesignSecuredPinView()?.controller ?? UIViewController()
        
        let containerView = BlurViewController()
        containerView.backgroundColor = .bgPage
        containerView.isClosable = false
        containerView.modalPresentationStyle = .overFullScreen
        containerView.add(pinView)

        view.rootViewController = containerView
    }

    func showPincodeSetup(on view: UIWindow) {
        guard let controller = PinViewFactory.createRedesignPinSetupView()?.controller else {
            return
        }

        view.rootViewController = controller
    }

    func showBroken(on view: UIWindow) {
        // normally user must not see this but on malicious devices it is possible
        view.backgroundColor = .red
    }
}
