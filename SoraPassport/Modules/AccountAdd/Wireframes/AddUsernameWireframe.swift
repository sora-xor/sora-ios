import Foundation

final class AddUsernameWireframe: UsernameSetupWireframeProtocol {
    var endAddingBlock: (() -> Void)?

    func proceed(from view: UsernameSetupViewProtocol?, username: String) {
        guard let accountCreation = AccountCreateViewFactory.createViewForAdding(username: username, endAddingBlock: endAddingBlock) else {
            return
        }
        view?.controller.navigationController?.pushViewController(accountCreation.controller,
                                                                  animated: true)
    }
}
