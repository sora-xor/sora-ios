import Foundation
import RobinHood
import CommonWallet

typealias MoreMenuDataSource = UITableViewDiffableDataSource<MoreMenuSection, MoreMenuItem>
typealias MoreMenuSnapshot = NSDiffableDataSourceSnapshot<MoreMenuSection, MoreMenuItem>


protocol MoreMenuViewProtocol: ControllerBackedProtocol {
    var presenter: MoreMenuPresenterProtocol? { get set }
    
    func set(title: String)
    func update(snapshot: MoreMenuSnapshot)
}

protocol MoreMenuPresenterProtocol: AnyObject {
    var view: MoreMenuViewProtocol? { get set }
    
    func reload()
}

protocol MoreMenuWireframeProtocol: ErrorPresentable, AlertPresentable, HelpPresentable, WebPresentable {
    func showChangeAccountView(from view: MoreMenuViewProtocol?)
    func showSoraCard(from view: MoreMenuViewProtocol?)
    func showFriendsView(from view: MoreMenuViewProtocol?)
    func showNodes(from view: MoreMenuViewProtocol?)
    func showInformation(from view: MoreMenuViewProtocol?)
    func showAppSettings(from view: MoreMenuViewProtocol?)
    func showSecurity(from view: MoreMenuViewProtocol?)
}
