import Foundation
import RobinHood
import CommonWallet
import SSFCloudStorage

typealias AccountImportedDataSource = UITableViewDiffableDataSource<AccountImportedSection, AccountImportedSectionItem>
typealias AccountImportedSnapshot = NSDiffableDataSourceSnapshot<AccountImportedSection, AccountImportedSectionItem>

protocol AccountImportedViewProtocol: ControllerBackedProtocol {
    var viewModel: AccountImportedViewModelProtocol? { get set }
}

protocol AccountImportedViewModelProtocol: AnyObject {
    var titlePublisher: Published<String>.Publisher { get }
    var snapshotPublisher: Published<AccountImportedSnapshot>.Publisher { get }
    func reload()
}

protocol AccountImportedWireframeProtocol {
    func showSetupPinCode()
    func showBackepedAccounts(accounts: [OpenBackupAccount])
    func dissmiss(completion: (() -> Void)?)
}
