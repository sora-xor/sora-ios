import UIKit
import SoraUIKit
import CommonWallet
import BigInt
import Combine

protocol ViewAssetListViewModelProtocol: Produtable {
    typealias ItemType = ExploreAssetListItem
}

final class ViewAssetListViewModel {

    var setupNavigationBar: ((WalletViewMode) -> Void)?
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var dissmiss: ((Bool) -> Void)?
    var updateHandler: (() -> Void)?

    var assetItems: [ExploreAssetListItem] = [] {
        didSet {
            setupTableViewItems(with: assetItems)
        }
    }

    var filteredAssetItems: [ExploreAssetListItem] = [] {
        didSet {
            setupTableViewItems(with: filteredAssetItems)
        }
    }

    var mode: WalletViewMode = .selection

    var isActiveSearch: Bool = false {
        didSet {
            setupTableViewItems(with: isActiveSearch ? filteredAssetItems : assetItems)
        }
    }

    var searchText: String = "" {
        didSet {
            guard !searchText.isEmpty else {
                setupTableViewItems(with: assetItems)
                return
            }
            filterAssetList(with: searchText.lowercased())
        }
    }

    weak var view: UIViewController?
    weak var viewModelService: ExploreAssetViewModelService?
    private var wireframe: ExploreWireframeProtocol?
    private var cancellables: Set<AnyCancellable> = []

    init(viewModelService: ExploreAssetViewModelService,
         wireframe: ExploreWireframeProtocol?) {
        self.viewModelService = viewModelService
        self.wireframe = wireframe
    }
}

extension ViewAssetListViewModel: ViewAssetListViewModelProtocol {
    var navigationTitle: String {
        R.string.localizable.commonCurrencies(preferredLanguages: .currentLocale)
    }
    
    var searchBarPlaceholder: String {
        R.string.localizable.assetListSearchPlaceholder(preferredLanguages: .currentLocale)
    }
    
    var items: [ManagebleItem] {
        isActiveSearch ? filteredAssetItems : assetItems
    }

    func canMoveAsset(from: Int, to: Int) -> Bool {
        false
    }

    func didMoveAsset(from: Int, to: Int) {}
    
    func viewDidLoad() {
        setupNavigationBar?(mode)
        setupSubscription()
    }
}

private extension ViewAssetListViewModel {
    
    func setupSubscription() {
        viewModelService?.$viewModels
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                let items = value.map { viewModel in
                    let item = ExploreAssetListItem(viewModel: viewModel)
                    item.assetHandler = { [weak self] assetId in
                        self?.wireframe?.showAssetDetails(on: self?.view, assetId: assetId ?? "")
                    }
                    return item
                }
                self?.assetItems = items
            }
            .store(in: &cancellables)
    }

    func filterAssetList(with query: String) {
        filteredAssetItems = assetItems.filter { item in
            return (item.viewModel.assetId?.lowercased().contains(query) ?? false) ||
            (item.viewModel.symbol?.lowercased().contains(query) ?? false) ||
            (item.viewModel.title?.lowercased().contains(query) ?? false)
        }
    }

    func setupTableViewItems(with items: [ExploreAssetListItem]) {
        if isActiveSearch {
            setupItems?(items)
            return
        }

        setupItems?(items)
    }
}
