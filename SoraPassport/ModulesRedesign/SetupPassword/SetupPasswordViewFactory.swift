import UIKit
import SoraFoundation
import SoraKeystore
import SSFCloudStorage

final class SetupPasswordViewFactory {
    static func createView(with account: OpenBackupAccount, completion: (() -> Void)? = nil) -> SetupPasswordViewProtocol? {
        let view = SetupPasswordViewController()
        let cloudStorageService = CloudStorageService(uiDelegate: view)
        let viewModel = SetupPasswordPresenter(account: account, cloudStorageService: cloudStorageService, completion: completion)
        let wireframe = SetupPasswordWireframe(currentController: view)
        view.viewModel = viewModel
        viewModel.view = view
        viewModel.wireframe = wireframe
        return view
    }
}
