import UIKit

final class SecurityLayerWireframe: SecurityLayerWireframProtocol, AuthorizationPresentable, SecuredPresentable {

    var logger: LoggerProtocol?

    private var isPincodeVisible: Bool {
        let rootViewController = UIApplication.shared.keyWindow?.rootViewController
        let presentedController = rootViewController?.presentedViewController

        return rootViewController as? PinSetupViewProtocol != nil || presentedController as? PinSetupViewProtocol != nil
    }

    func showSecuringOverlay() {
        guard !isPincodeVisible else {
            return
        }

        securePresentingView(animated: true)
    }

    func hideSecuringOverlay() {
        unsecurePresentingView()
    }

    func showAuthorization() {
        guard let window = UIApplication.shared.keyWindow else {
            return
        }

        if window.rootViewController as? PinSetupViewProtocol != nil {
            return
        }

        if window.rootViewController as? MainTabBarViewProtocol != nil {
            removeExistingAuthViewIfPresented { [weak self] in
                self?.presentModalAuthorization()
            }
        } else {
            presentRootAuthorization(on: window)
        }
    }

    private func presentModalAuthorization() {
        authorize(animated: false) { isAuthorized in
            if !isAuthorized {
                self.logger?.error("Authorization unexpectedly failed")
            }
        }
    }

    private func presentRootAuthorization(on window: UIWindow) {
        guard let localAuthentication = PinViewFactory.createRedesignSecuredPinView() else {
            return
        }

        window.rootViewController = localAuthentication.controller
    }
}