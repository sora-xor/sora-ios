import Foundation
import SoraKeystore
import SoraFoundation
import CommonWallet
import SoraUIKit
import RobinHood
import SSFCloudStorage

final class AccountImportedWireframe {

    private weak var currentController: AccountImportedViewProtocol?
    private var endAddingBlock: (() -> Void)?
    
    init(currentController: AccountImportedViewProtocol? = nil,
         endAddingBlock: (() -> Void)? = nil) {
        self.currentController = currentController
        self.endAddingBlock = endAddingBlock
    }
}

extension AccountImportedWireframe: AccountImportedWireframeProtocol {
    func showSetupPinCode() {
        let view = PinViewFactory.createRedesignPinSetupView()
        
        let containerView = BlurViewController()
        containerView.isClosable = false
        containerView.modalPresentationStyle = .overFullScreen
        containerView.add(view?.controller)
        
        currentController?.controller.present(containerView, animated: true)
    }
    
    func showBackepedAccounts(accounts: [OpenBackupAccount]) {
        guard let viewController = BackupedAccountsViewFactory.createView(
            with: accounts,
            endAddingBlock: endAddingBlock
        )?.controller else { return }
        currentController?.controller.navigationController?.pushViewController(viewController, animated: true)
    }
    
    func dissmiss(completion: (() -> Void)?) {
        currentController?.controller.dismiss(animated: true, completion: completion)
    }
}
