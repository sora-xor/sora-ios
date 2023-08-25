import SoraUIKit

protocol Produtable: AnyObject {
    var searchBarPlaceholder: String { get }
    var searchText: String { get set }
    var mode: WalletViewMode { get set }
    var isActiveSearch: Bool { get set }
    var items: [ManagebleItem] { get }
    var setupNavigationBar: ((WalletViewMode) -> Void)? { get set }
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)? { get set }
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)? { get set }
    var dissmiss: ((Bool) -> Void)? { get set }
    var navigationTitle: String { get }
    func canMoveAsset(from: Int, to: Int) -> Bool
    func didMoveAsset(from: Int, to: Int)
    func viewDidLoad()
    func viewDissmissed()
}

extension Produtable {
    func viewDissmissed() {}
    var navigationTitle: String { "" }
}

protocol ManagebleItem {
    var title: String { get }
}
