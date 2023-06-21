import UIKit
import SoraFoundation
import SoraKeystore
import SSFCloudStorage
import RobinHood

final class AccountImportedViewFactory {
    static func createView(
        with importedAccountAddress: String,
        accounts: [OpenBackupAccount],
        endAddingBlock: (() -> Void)? = nil
    ) -> AccountImportedViewProtocol? {
        let view = AccountImportedViewController()
        let wireframe = AccountImportedWireframe(currentController: view, endAddingBlock: endAddingBlock)
        let viewModel = AccountImportedViewModel(
            importedAccountAddress: importedAccountAddress,
            backedUpAccounts: accounts,
            wireframe: wireframe,
            endAddingBlock: endAddingBlock
        )
        view.viewModel = viewModel
        return view
    }
}
