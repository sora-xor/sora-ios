import Foundation
import IrohaCrypto
import SoraFoundation
import SoraUI

final class AddImportedWireframe: AccountImportWireframeProtocol {
    var endAddingBlock: (() -> Void)?
    
    let localizationManager: LocalizationManagerProtocol

    init(localizationManager: LocalizationManagerProtocol) {
        self.localizationManager = localizationManager
    }

    func proceed(from view: AccountImportViewProtocol?) {
        guard let navigationController = view?.controller.navigationController else {
            return
        }

        guard let endAddingBlock = endAddingBlock else {
            MainTransitionHelper.transitToMainTabBarController(closing: navigationController, animated: true)
            return
        }

        endAddingBlock()
    }
}
