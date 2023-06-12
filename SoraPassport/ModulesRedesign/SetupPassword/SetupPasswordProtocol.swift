import Foundation
import RobinHood
import CommonWallet

typealias SetupPasswordDataSource = UITableViewDiffableDataSource<SetupPasswordSection, SetupPasswordSectionItem>
typealias SetupPasswordSnapshot = NSDiffableDataSourceSnapshot<SetupPasswordSection, SetupPasswordSectionItem>

protocol SetupPasswordViewProtocol: ControllerBackedProtocol, AlertPresentable {
    var viewModel: SetupPasswordPresenterProtocol? { get set }
}

protocol SetupPasswordPresenterProtocol: AnyObject {
    var titlePublisher: Published<String>.Publisher { get }
    var snapshotPublisher: Published<SetupPasswordSnapshot>.Publisher { get }
    func reload()
}

protocol SetupPasswordWireframeProtocol: Loadable, AlertPresentable {
    func showSetupPinCode()
}
