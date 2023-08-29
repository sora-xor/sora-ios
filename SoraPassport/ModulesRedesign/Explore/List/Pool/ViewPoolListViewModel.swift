import UIKit
import SoraUIKit
import CommonWallet
import BigInt
import Combine
import IrohaCrypto

protocol ViewPoolListViewModelProtocol: Produtable {
    typealias ItemType = AssetListItem
}

final class ViewPoolListViewModel {

    var setupNavigationBar: ((WalletViewMode) -> Void)?
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var dissmiss: ((Bool) -> Void)?
    var updateHandler: (() -> Void)?

    var poolItems: [ExplorePoolListItem] = [] {
        didSet {
            setupTableViewItems(with: poolItems)
        }
    }

    var filteredPoolItems: [ExplorePoolListItem] = [] {
        didSet {
            setupTableViewItems(with: filteredPoolItems)
        }
    }

    var mode: WalletViewMode = .selection

    var isActiveSearch: Bool = false {
        didSet {
            setupTableViewItems(with: isActiveSearch ? filteredPoolItems : poolItems)
        }
    }

    var searchText: String = "" {
        didSet {
            guard !searchText.isEmpty else {
                setupTableViewItems(with: poolItems)
                return
            }
            filterAssetList(with: searchText.lowercased())
        }
    }

    weak var view: UIViewController?
    var viewModelService: ExplorePoolViewModelService?
    var wireframe: ExploreWireframeProtocol
    weak var accountPoolsService: PoolsServiceInputProtocol?
    private var cancellables: Set<AnyCancellable> = []

    init(viewModelService: ExplorePoolViewModelService?,
         wireframe: ExploreWireframeProtocol,
         accountPoolsService: PoolsServiceInputProtocol) {
        self.viewModelService = viewModelService
        self.wireframe = wireframe
        self.accountPoolsService = accountPoolsService
    }
}

extension ViewPoolListViewModel: ViewPoolListViewModelProtocol {
    var navigationTitle: String {
        R.string.localizable.discoveryPolkaswapPools(preferredLanguages: .currentLocale)
    }
    
    var searchBarPlaceholder: String {
        R.string.localizable.assetListSearchPlaceholder(preferredLanguages: .currentLocale)
    }
    
    var items: [ManagebleItem] {
        isActiveSearch ? filteredPoolItems : poolItems
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

private extension ViewPoolListViewModel {
    
    func setupSubscription() {
        viewModelService?.$viewModels
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                let items = value.map { viewModel in
                    
                    let item = ExplorePoolListItem(viewModel: viewModel)
                    item.poolHandler = { [weak self] pool in
                        let poolId = pool?.poolId ?? ""
                        let baseAssetId = pool?.baseAssetId ?? ""
                        let targetAssetId = pool?.targetAssetId ?? ""
                        let account = SelectedWalletSettings.shared.currentAccount
                        let accountId = (try? SS58AddressFactory().accountId(fromAddress: account?.address ?? "",
                                                                            type: account?.networkType ?? 0).toHex(includePrefix: true)) ?? ""
                        
                        guard let poolInfo = self?.accountPoolsService?.getPool(by: poolId) else {
                            
                            let poolInfo = PoolInfo(baseAssetId: baseAssetId, targetAssetId: targetAssetId, poolId: poolId, accountId: accountId)
                            self?.wireframe.showAccountPoolDetails(on: self?.view, poolInfo: poolInfo)
                            return
                        }
                        self?.wireframe.showAccountPoolDetails(on: self?.view, poolInfo: poolInfo)
                    }
                    return item
                }
                
                
                self?.poolItems = items
            }
            .store(in: &cancellables)
    }

    func filterAssetList(with query: String) {
        filteredPoolItems = poolItems.filter { item in
            item.viewModel.title?.lowercased().contains(query) ?? false
        }
    }

    func setupTableViewItems(with items: [ExplorePoolListItem]) {
        if isActiveSearch {
            setupItems?(items)
            return
        }

        setupItems?(items)
    }
}
