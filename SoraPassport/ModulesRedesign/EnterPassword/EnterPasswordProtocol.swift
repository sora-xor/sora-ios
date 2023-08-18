import Foundation
import RobinHood
import CommonWallet
import SSFCloudStorage

typealias EnterPasswordDataSource = UITableViewDiffableDataSource<EnterPasswordSection, EnterPasswordSectionItem>
typealias EnterPasswordSnapshot = NSDiffableDataSourceSnapshot<EnterPasswordSection, EnterPasswordSectionItem>


protocol EnterPasswordViewProtocol: ControllerBackedProtocol {
    var viewModel: EnterPasswordViewModelProtocol? { get set }
    func showLoading()
    func hideLoading()
}

protocol EnterPasswordViewModelProtocol: AnyObject {
    var titlePublisher: Published<String>.Publisher { get }
    var snapshotPublisher: Published<EnterPasswordSnapshot>.Publisher { get }

    func reload()
}

protocol EnterPasswordWireframeProtocol: Loadable {
    func openSuccessImport(importedAccountAddress: String, accounts: [OpenBackupAccount])
}
