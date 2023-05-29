import Foundation
import IrohaCrypto
import SoraFoundation
import SoraUI

final class AccountImportWireframe: AccountImportWireframeProtocol {
    lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()
    
    let localizationManager: LocalizationManagerProtocol

    init(localizationManager: LocalizationManagerProtocol) {
        self.localizationManager = localizationManager
    }

    func proceed(from view: AccountImportViewProtocol?) {
        guard let setupNameView = SetupAccountNameViewFactory.createViewForImport()?.controller else { return }
        view?.controller.navigationController?.pushViewController(setupNameView, animated: true)
    }
}
