import UIKit
import SoraUIKit
import CommonWallet
import RobinHood


protocol PoolListViewModelProtocol: Produtable {
    typealias ItemType = PoolListItem
}

final class PoolListViewModel {

    var setupNavigationBar: ((WalletViewMode) -> Void)?
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var dissmiss: ((Bool) -> Void)?
    
    var poolItems: [PoolListItem] = [] {
        didSet {
            setupItems?(poolItems)
        }
    }

    var filteredPoolItems: [PoolListItem] = [] {
        didSet {
            setupItems?(filteredPoolItems)
        }
    }

    var mode: WalletViewMode = .view {
        didSet {
            if mode == .view {
                saveUpdates()
            }

            setupNavigationBar?(mode)

            poolItems.forEach { item in
                item.poolViewModel.mode = mode
            }

            setupItems?(isActiveSearch ? filteredPoolItems : poolItems)
        }
    }

    var isActiveSearch: Bool = false {
        didSet {
            setupItems?(isActiveSearch ? filteredPoolItems : poolItems)
        }
    }

    var searchText: String = "" {
        didSet {
            guard !searchText.isEmpty else {
                setupItems?(poolItems)
                return
            }
            filterAssetList(with: searchText.lowercased())
        }
    }

    weak var assetManager: AssetManagerProtocol?
    var poolViewModelFactory: PoolViewModelFactoryProtocol
    var fiatService: FiatServiceProtocol?
    var poolsService: PoolsServiceInputProtocol?
    var wireframe: PoolListWireframeProtocol = PoolListWireframe()
    var providerFactory: BalanceProviderFactory
    weak var view: UIViewController?
    var operationFactory: WalletNetworkOperationFactoryProtocol
    var assetsProvider: AssetProviderProtocol

    init(poolsService: PoolsServiceInputProtocol,
         assetManager: AssetManagerProtocol,
         fiatService: FiatServiceProtocol,
         poolViewModelFactory: PoolViewModelFactoryProtocol,
         providerFactory: BalanceProviderFactory,
         operationFactory: WalletNetworkOperationFactoryProtocol,
         assetsProvider: AssetProviderProtocol
    ) {
        self.poolViewModelFactory = poolViewModelFactory
        self.fiatService = fiatService
        self.assetManager = assetManager
        self.poolsService = poolsService
        self.providerFactory = providerFactory
        self.operationFactory = operationFactory
        self.assetsProvider = assetsProvider
    }
    func dissmissIfNeeded() {
        if poolItems.isEmpty {
            dissmiss?(false)
        }
    }
}

extension PoolListViewModel: PoolListViewModelProtocol {
    
    var searchBarPlaceholder: String {
        R.string.localizable.commonSearchPools(preferredLanguages: .currentLocale)
    }
    
    var items: [ManagebleItem] {
        isActiveSearch ? filteredPoolItems : poolItems
    }

    func canMoveAsset(from: Int, to: Int) -> Bool {
        let firstNotFavoriteIndex = poolItems.firstIndex { !$0.poolInfo.isFavorite } ?? poolItems.count
        let isFavorite = poolItems[from].poolInfo.isFavorite
        return (isFavorite ? firstNotFavoriteIndex >= to : firstNotFavoriteIndex <= to)
    }

    func didMoveAsset(from: Int, to: Int) {
        let item = poolItems.remove(at: from)
        poolItems.insert(item, at: to)
        setupItems?(poolItems)
    }
    
    func viewDidLoad() {
        setupNavigationBar?(mode)
        poolsService?.loadAccountPools(isNeedForceUpdate: false)
    }
}

extension PoolListViewModel: PoolsServiceOutput {
    func loaded(pools: [PoolInfo]) {
        if pools.isEmpty {
            dissmiss?(false)
        }

        fiatService?.getFiat { [weak self] fiatData in
            self?.poolItems = pools.compactMap { pool in
                guard let self = self,
                        let viewModel = self.poolViewModelFactory.createPoolViewModel(with: pool, fiatData: fiatData, mode: .view) else {
                    return nil
                }
                
                let item = PoolListItem(poolInfo: pool, poolViewModel: viewModel)
                item.tapHandler = { [weak self] in
                    self?.showPoolDetails(poolInfo: pool)
                }
                item.favoriteHandle = { item in
                    item.poolInfo.isFavorite = !item.poolInfo.isFavorite
                }
                return item
            }.sorted { $0.poolViewModel.isFavorite && !$1.poolViewModel.isFavorite }
        }
    }
    
    func showPoolDetails(poolInfo: PoolInfo) {
        guard let assetManager = assetManager, let fiatService = fiatService, let poolsService = poolsService else { return }
        let assets = assetManager.getAssetList() ?? []
        
        let balanceProvider = try? providerFactory.createBalanceDataProvider(for: assets, onlyVisible: false)
        
        wireframe.showPoolDetails(on: view,
                                  poolInfo: poolInfo,
                                  assetManager: assetManager,
                                  fiatService: fiatService,
                                  poolsService: poolsService,
                                  providerFactory: providerFactory,
                                  operationFactory: operationFactory,
                                  assetsProvider: assetsProvider,
                                  dismissHandler: dissmissIfNeeded)
    }
}

private extension PoolListViewModel {
    func filterAssetList(with query: String) {
        filteredPoolItems = self.poolItems.filter { item in
            item.poolViewModel.title.lowercased().contains(query)
        }
    }

    func saveUpdates() {
        let poolInfos = self.poolItems.map({ $0.poolInfo })
        poolsService?.updatePools(poolInfos)
    }
}
