import Foundation
import SoraKeystore
import SoraFoundation
import SSFCloudStorage

final class EnterPasswordWireframe: CustomPresentable {
    private weak var currentController: EnterPasswordViewProtocol?
    private weak var navigationController: UINavigationController?
    private var endAddingBlock: (() -> Void)? = nil
    var activityIndicatorWindow: UIWindow?

    init(currentController: EnterPasswordViewProtocol? = nil,
         endAddingBlock: (() -> Void)? = nil) {
        self.currentController = currentController
        self.navigationController = currentController?.controller.navigationController
        self.endAddingBlock = endAddingBlock
    }
}

extension EnterPasswordWireframe: EnterPasswordWireframeProtocol {
    func openSuccessImport(importedAccountAddress: String, accounts: [OpenBackupAccount]) {
        guard let successView = AccountImportedViewFactory.createView(
            with: importedAccountAddress,
            accounts: accounts,
            endAddingBlock: endAddingBlock
        )?.controller else { return }
        currentController?.controller.navigationController?.setViewControllers([successView], animated: true)
    }
}
