/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import SoraSwiftUI
import CommonWallet
import RobinHood

enum AssetListMode {
    case edit
    case `default`
}

protocol AssetListViewModelProtocol {
    var searchText: String { get set }
    var mode: AssetViewMode { get set }
    var isActiveSearch: Bool { get set }
    var assetItems: [AssetListItem] { get set }
    var setupNavigationBar: ((AssetViewMode) -> Void)? { get set }
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)? { get set }
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)? { get set }
    func canMoveAsset(from: Int, to: Int) -> Bool
    func didMoveAsset(from: Int, to: Int)
}

final class AssetListViewModel {

    var setupNavigationBar: ((AssetViewMode) -> Void)?
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)?

    var assetItems: [AssetListItem] = [] {
        didSet {
            setupTableViewItems(with: assetItems)
        }
    }

    var filteredAssetItems: [AssetListItem] = [] {
        didSet {
            setupTableViewItems(with: filteredAssetItems)
        }
    }

    var isNeedZeroBalance: Bool = false {
        didSet {
            setupTableViewItems(with: isActiveSearch ? filteredAssetItems : assetItems )
        }
    }

    var mode: AssetViewMode = .view {
        didSet {
            if mode == .view {
                saveUpdates()
            }

            setupNavigationBar?(mode)

            assetItems.forEach { item in
                item.assetViewModel.mode = mode
            }

            setupTableViewItems(with: isActiveSearch ? filteredAssetItems : assetItems )
        }
    }

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

    weak var assetManager: AssetManagerProtocol?
    var assetViewModelFactory: AssetViewModelFactoryProtocol
    var balanceProvider: (SingleValueProvider<[BalanceData]>)?

    init(balanceProvider: (SingleValueProvider<[BalanceData]>)?,
         assetViewModelFactory: AssetViewModelFactoryProtocol,
         assetManager: AssetManagerProtocol?) {
        self.balanceProvider = balanceProvider
        self.assetViewModelFactory = assetViewModelFactory
        self.assetManager = assetManager
        setupBalanceDataProvider()
    }
}

extension AssetListViewModel: AssetListViewModelProtocol {

    func canMoveAsset(from: Int, to: Int) -> Bool {
        let firstNotFavoriteIndex = assetItems.firstIndex { !$0.assetViewModel.isFavorite } ?? assetItems.count
        let isFavorite = assetItems[from].assetViewModel.isFavorite
        let isTryToChangeXorPosition = to == 0
        return (isFavorite ? firstNotFavoriteIndex >= to : firstNotFavoriteIndex <= to) && !isTryToChangeXorPosition
    }

    func didMoveAsset(from: Int, to: Int) {
        let item = assetItems.remove(at: from)
        assetItems.insert(item, at: to)
        setupItems?(assetItems)
    }
}

private extension AssetListViewModel {
    func items(with balanceItems: [BalanceData]) {

        assetItems = balanceItems.compactMap { balance in
            guard let assetInfo = self.assetManager?.assetInfo(for: balance.identifier),
                  let viewModel = self.assetViewModelFactory.createAssetViewModel(with: balance, mode: self.mode) else {
                return nil
            }

            let item = AssetListItem(assetInfo: assetInfo, assetViewModel: viewModel, balance: balance.balance.decimalValue)

            item.favoriteHandle = { item in
                item.assetInfo.visible = !item.assetInfo.visible
            }
            return item
        }.sorted { $0.assetViewModel.isFavorite && !$1.assetViewModel.isFavorite }
    }

    func filterAssetList(with query: String) {
        filteredAssetItems = self.assetItems.filter { item in
            return item.assetInfo.assetId.lowercased().contains(query) ||
            item.assetInfo.symbol.lowercased().contains(query) ||
            item.assetViewModel.title.lowercased().contains(query)
        }
    }

    func saveUpdates() {
        let assetInfos = self.assetItems.map({ $0.assetInfo })
        assetManager?.updateAssetList(assetInfos)
    }

    func setupTableViewItems(with assetItems: [AssetListItem]) {
        let isNeedAllItems = isNeedZeroBalance || mode == .edit || isActiveSearch
        var cellItems: [SoramitsuTableViewItemProtocol] = isNeedAllItems ? assetItems : assetItems.filter { !$0.balance.isZero }

        if mode == .view, !isActiveSearch {
            let zeroIndex = assetItems.map { $0.balance }.firstIndex { $0.isZero } ?? assetItems.count - 1
            let zeroItem = ZeroBalanceItem(isShown: isNeedZeroBalance)

            zeroItem.buttonHandler = { [weak self] in
                guard let self = self else { return }
                self.isNeedZeroBalance = !self.isNeedZeroBalance
                self.reloadItems?([zeroItem])
            }

            cellItems.insert(zeroItem, at: zeroIndex)
        }

        DispatchQueue.main.async {
            self.setupItems?(cellItems)
        }
    }

    func setupBalanceDataProvider() {
        let changesBlock = { [weak self] (changes: [DataProviderChange<[BalanceData]>]) -> Void in
            guard let change = changes.first else { return }
            switch change {
            case .insert(let items), .update(let items):
                self?.items(with: items)
            default:
                break
            }
        }

        let failBlock: (Error) -> Void = { (error: Error) in
            //TODO: Add error handler
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: true)
        balanceProvider?.addObserver(self,
                                    deliverOn: .main,
                                    executing: changesBlock,
                                    failing: failBlock,
                                    options: options)
    }
}
