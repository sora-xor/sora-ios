import Foundation
import SoraKeystore
import SoraFoundation
import SSFCloudStorage

final class BackupedAccountsWireframe: CustomPresentable {

    weak var currentController: BackupedAccountsViewController?
    var endAddingBlock: (() -> Void)?
    
    init(currentController: BackupedAccountsViewController? = nil,
         endAddingBlock: (() -> Void)? = nil) {
        self.currentController = currentController
        self.endAddingBlock = endAddingBlock
    }
    
    deinit {
        print("deinited")
    }
}

extension BackupedAccountsWireframe: BackupedAccountsWireframeProtocol {
    func openInputPassword(selectedAddress: String, backedUpAccounts: [OpenBackupAccount]) {
        guard let view = EnterPasswordViewFactory.createView(
            with: selectedAddress,
            backedUpAccounts: backedUpAccounts,
            endAddingBlock: endAddingBlock)?.controller else { return }
        currentController?.controller.navigationController?.pushViewController(view, animated: true)
    }
    
    func showCreateAccount() {
        guard let setupAccountNameView = SetupAccountNameViewFactory.createViewForOnboarding(
            mode: .creating,
            endAddingBlock: endAddingBlock
        ) else { return }
        currentController?.controller.navigationController?.pushViewController(setupAccountNameView.controller, animated: true)
    }
}
