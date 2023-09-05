// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

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
