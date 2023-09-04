import Foundation
import SoraFoundation
import SoraUIKit

final class AddUsernameWireframe: UsernameSetupWireframeProtocol {
    private(set) var localizationManager: LocalizationManagerProtocol
    private var isGoogleBackupSelected: Bool
    private var isNeedSetupName: Bool

    init(localizationManager: LocalizationManagerProtocol, isGoogleBackupSelected: Bool = false, isNeedSetupName: Bool) {
        self.localizationManager = localizationManager
        self.isGoogleBackupSelected = isGoogleBackupSelected
        self.isNeedSetupName = isNeedSetupName
    }

    var endAddingBlock: (() -> Void)?

    func proceed(from view: UsernameSetupViewProtocol?, username: String) {
        guard let accountCreation = AccountCreateViewFactory.createViewForImportAccount(
            username: username,
            isGoogleBackupSelected: isGoogleBackupSelected,
            isNeedSetupName: isNeedSetupName,
            endAddingBlock: endAddingBlock
        ) else { return }
        view?.controller.navigationController?.pushViewController(accountCreation.controller,
                                                                  animated: true)
    }
    
    func showPinCode(from view: UsernameSetupViewProtocol?) {
        let view = PinViewFactory.createRedesignPinSetupView()
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        containerView.add(view?.controller)
        
        view?.controller.present(containerView, animated: true)
    }
    
    func showWarning(from view: UsernameSetupViewProtocol?, completion: @escaping () -> Void) {
        let warning = AccountWarningViewController(warningType: .passphrase)
        warning.localizationManager = self.localizationManager
        warning.completion = completion
        view?.controller.navigationController?.pushViewController(warning.controller, animated: true)
    }
}
