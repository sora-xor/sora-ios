import UIKit
import SoraUIKit
import CommonWallet
import RobinHood

protocol SelectAssetViewModelProtocol: Produtable {
    typealias ItemType = AssetListItem
}

final class SelectAssetViewModel {

    var setupNavigationBar: ((WalletViewMode) -> Void)?
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var dissmiss: ((Bool) -> Void)?
    var selectionCompletion: ((String) -> Void)?

    var assetItems: [AssetListItem] = [] {
        didSet {
            setupItems?(assetItems)
        }
    }

    var filteredAssetItems: [AssetListItem] = [] {
        didSet {
            setupItems?(filteredAssetItems)
        }
    }

    var mode: WalletViewMode = .selection

    var isActiveSearch: Bool = false {
        didSet {
            setupItems?(isActiveSearch ? filteredAssetItems : assetItems)
        }
    }

    var searchText: String = "" {
        didSet {
            guard !searchText.isEmpty else {
                setupItems?(assetItems)
                return
            }
            filterAssetList(with: searchText.lowercased())
        }
    }

    weak var assetManager: AssetManagerProtocol?
    var assetViewModelFactory: AssetViewModelFactoryProtocol
    weak var fiatService: FiatServiceProtocol?
    private weak var assetsProvider: AssetProviderProtocol?
    var assetIds: [String] = []

    init(assetViewModelFactory: AssetViewModelFactoryProtocol,
         fiatService: FiatServiceProtocol,
         assetManager: AssetManagerProtocol?,
         assetsProvider: AssetProviderProtocol?,
         assetIds: [String]) {
        self.assetViewModelFactory = assetViewModelFactory
        self.fiatService = fiatService
        self.assetManager = assetManager
        self.assetsProvider = assetsProvider
        self.assetIds = assetIds
    }
}

extension SelectAssetViewModel: SelectAssetViewModelProtocol {
    var navigationTitle: String {
        R.string.localizable.chooseToken(preferredLanguages: .currentLocale)
    }

    var searchBarPlaceholder: String {
        R.string.localizable.assetListSearchPlaceholder(preferredLanguages: .currentLocale)
    }
    
    var items: [ManagebleItem] {
        isActiveSearch ? filteredAssetItems : assetItems
    }

    func canMoveAsset(from: Int, to: Int) -> Bool {
        let firstNotFavoriteIndex = assetItems.firstIndex { !$0.assetViewModel.isFavorite } ?? items.count
        let isFavorite = assetItems[from].assetViewModel.isFavorite
        let isTryToChangeXorPosition = to == 0
        return (isFavorite ? firstNotFavoriteIndex >= to : firstNotFavoriteIndex <= to) && !isTryToChangeXorPosition
    }

    func didMoveAsset(from: Int, to: Int) {
        let item = assetItems.remove(at: from)
        assetItems.insert(item, at: to)
        setupItems?(assetItems)
    }
    
    func viewDidLoad() {
        setupNavigationBar?(mode)
        if let balanceData = assetsProvider?.getBalances(with: assetIds) {
            items(with: balanceData)
        }
    }
}

private extension SelectAssetViewModel {
    func items(with balanceItems: [BalanceData]) {

        fiatService?.getFiat { [weak self] fiatData in
            self?.assetItems = balanceItems.compactMap { balance in
                guard let self = self,
                      let assetInfo = self.assetManager?.assetInfo(for: balance.identifier),
                      let viewModel = self.assetViewModelFactory.createAssetViewModel(with: balance,
                                                                                      fiatData: fiatData,
                                                                                      mode: self.mode) else {
                    return nil
                }

                let item = AssetListItem(assetInfo: assetInfo, assetViewModel: viewModel, balance: balance.balance.decimalValue)

                item.assetHandler = { [weak self] identifier in
                    self?.dissmiss?(true)
                    self?.selectionCompletion?(identifier)
                }
        
                item.favoriteHandle = { item in
                    item.assetInfo.visible = !item.assetInfo.visible
                }
                return item
            }.sorted { $0.assetViewModel.isFavorite && !$1.assetViewModel.isFavorite }
        }
    }

    func filterAssetList(with query: String) {
        filteredAssetItems = query == "" ? assetItems : assetItems.filter { item in
            return item.assetInfo.assetId.lowercased().contains(query) ||
            item.assetInfo.symbol.lowercased().contains(query) ||
            item.assetViewModel.title.lowercased().contains(query)
        }
    }

    func saveUpdates() {
        let assetInfos = assetItems.map({ $0.assetInfo })
        assetManager?.saveAssetList(assetInfos)
    }
}
