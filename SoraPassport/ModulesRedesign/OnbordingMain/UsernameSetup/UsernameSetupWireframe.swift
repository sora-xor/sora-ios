import Foundation
import SoraFoundation
import SoraUIKit

final class UsernameSetupWireframe: UsernameSetupWireframeProtocol {
    private(set) var localizationManager: LocalizationManagerProtocol
    private var endAddingBlock: (() -> Void)? = nil

    init(localizationManager: LocalizationManagerProtocol,
         endAddingBlock: (() -> Void)? = nil) {
        self.localizationManager = localizationManager
        self.endAddingBlock = endAddingBlock
    }
    
    func proceed(from view: UsernameSetupViewProtocol?, username: String) {
        guard let accountCreation = AccountCreateViewFactory.createViewForCreateAccount(
            username: username,
            endAddingBlock: endAddingBlock
        ) else { return }
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
        let warning = AccountWarningViewController(warningType: .passphrase)
        warning.localizationManager = self.localizationManager
        warning.completion = completion
        view?.controller.navigationController?.pushViewController(warning.controller, animated: true)
    }
}
