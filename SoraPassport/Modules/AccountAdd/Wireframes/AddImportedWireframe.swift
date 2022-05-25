import Foundation
import IrohaCrypto

final class AddImportedWireframe: AccountImportWireframeProtocol {
    func proceed(from view: AccountImportViewProtocol?) {
        guard let navigationController = view?.controller.navigationController else {
            return
        }

        MainTransitionHelper.transitToMainTabBarController(closing: navigationController,
                                                           animated: true)
    }
}
