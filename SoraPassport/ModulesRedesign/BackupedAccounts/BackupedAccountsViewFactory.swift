import UIKit
import SoraFoundation
import SoraKeystore
import SSFCloudStorage
import RobinHood

final class BackupedAccountsViewFactory {
    static func createView(with accounts: [OpenBackupAccount], endAddingBlock: (() -> Void)? = nil) -> BackupedAccountsViewProtocol? {
        let view = BackupedAccountsViewController()
        let wireframe = BackupedAccountsWireframe(currentController: view, endAddingBlock: endAddingBlock)
        let viewModel = BackupedAccountsViewModel(backedUpAccounts: accounts, wireframe: wireframe)
        
        view.viewModel = viewModel

        return view
    }
}
