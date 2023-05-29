import Foundation
import SoraFoundation
import SoraUIKit
final class UsernameSetupWireframe: UsernameSetupWireframeProtocol {
    private(set) var localizationManager: LocalizationManagerProtocol

    init(localizationManager: LocalizationManagerProtocol) {
        self.localizationManager = localizationManager
    }
    
    func proceed(from view: UsernameSetupViewProtocol?, username: String) {
        guard let accountCreation = AccountCreateViewFactory.createViewForOnboarding(username: username) else { return }
        view?.controller.navigationController?.pushViewController(accountCreation.controller, animated: true)
    }
    
    func showPinCode(from view: UsernameSetupViewProtocol?) {
        let pinCodeView = PinViewFactory.createRedesignPinSetupView()
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        containerView.add(pinCodeView?.controller)
        
        view?.controller.present(containerView, animated: true)
    }
    
    func showWarning(from view: UsernameSetupViewProtocol?, completion: @escaping () -> Void) {
        let warning = AccountWarningViewController()
        warning.localizationManager = self.localizationManager
        warning.completion = completion
        view?.controller.navigationController?.pushViewController(warning.controller, animated: true)
    }
}
