import Foundation
import RobinHood
import CommonWallet
import SSFCloudStorage

typealias BackupedAccountsDataSource = UITableViewDiffableDataSource<BackupedAccountsSection, BackupedAccountSectionItem>
typealias BackupedAccountsSnapshot = NSDiffableDataSourceSnapshot<BackupedAccountsSection, BackupedAccountSectionItem>

protocol BackupedAccountsViewProtocol: ControllerBackedProtocol {
    var viewModel: BackupedAccountsViewModelProtocol? { get set }
}

protocol BackupedAccountsViewModelProtocol: AnyObject {
    var titlePublisher: Published<String>.Publisher { get }
    var snapshotPublisher: Published<BackupedAccountsSnapshot>.Publisher { get }
    func reload()
    func didSelectAccount(with address: String)
}

protocol BackupedAccountsWireframeProtocol {
    func openInputPassword(selectedAddress: String, backedUpAccounts: [OpenBackupAccount])
    func showCreateAccount()
}
