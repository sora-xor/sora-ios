import Foundation

final class PersonalUpdateWireframe: PersonalUpdateWireframeProtocol {
    func close(view: PersonalUpdateViewProtocol?) {
        if let navigationController = view?.controller.navigationController {
            navigationController.popViewController(animated: true)
        }
    }
}
