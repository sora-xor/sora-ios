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
import RobinHood
import BigInt
import IrohaCrypto

protocol DiscoverViewModelProtocol {
    var snapshotPublisher: Published<ExploreSnapshot>.Publisher { get }
    func setup()
}

class ExploreSection {
    var id = UUID()
    var items: [ExploreSectionItem]
    
    init(items: [ExploreSectionItem]) {
        self.items = items
    }
}

enum ExploreSectionItem: Hashable {
    case assets(ExploreAssetsItem)
    case pools(ExplorePoolsItem)
}

extension ExploreSection: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ExploreSection, rhs: ExploreSection) -> Bool {
        lhs.id == rhs.id
    }
}


typealias ExploreDataSource = UITableViewDiffableDataSource<ExploreSection, ExploreSectionItem>
typealias ExploreSnapshot = NSDiffableDataSourceSnapshot<ExploreSection, ExploreSectionItem>

final class ExploreViewModel {
    @Published var snapshot: ExploreSnapshot = ExploreSnapshot()
    var snapshotPublisher: Published<ExploreSnapshot>.Publisher { $snapshot }
    
    var wireframe: ExploreWireframeProtocol
    var view: ControllerBackedProtocol?
    
    weak var accountPoolsService: PoolsServiceInputProtocol?
    var assetViewModelsService: ExploreAssetViewModelService
    var poolViewModelsService: ExplorePoolViewModelService

    init(wireframe: ExploreWireframeProtocol,
         accountPoolsService: PoolsServiceInputProtocol,
         assetViewModelsService: ExploreAssetViewModelService,
         poolViewModelsService: ExplorePoolViewModelService) {
        self.wireframe = wireframe
        self.accountPoolsService = accountPoolsService
        self.assetViewModelsService = assetViewModelsService
        self.poolViewModelsService = poolViewModelsService
    }
    
    private func createSnapshot() -> ExploreSnapshot {
        var snapshot = ExploreSnapshot()

        let assetsItem = ExploreAssetsItem(title: R.string.localizable .commonCurrencies(preferredLanguages: .currentLocale),
                                           subTitle: R.string.localizable.exploreSwapTokensOnSora(preferredLanguages: .currentLocale),
                                           viewModelService: assetViewModelsService)
        assetsItem.assetHandler = { [weak self] assetId in
            self?.wireframe.showAssetDetails(on: self?.view?.controller, assetId: assetId)
        }
        
        assetsItem.expandHandler = { [weak self] in
            guard let self = self else { return }
            self.wireframe.showAssetList(on: self.view?.controller, viewModelService: self.assetViewModelsService)
        }
        
        let poolItem = ExplorePoolsItem(title: R.string.localizable.discoveryPolkaswapPools(preferredLanguages: .currentLocale),
                                        subTitle: R.string.localizable.exploreProvideAndEarn(preferredLanguages: .currentLocale),
                                        viewModelService: poolViewModelsService)

        poolItem.poolHandler = { [weak self] pool in
            let poolId = pool.poolId ?? ""
            let baseAssetId = pool.baseAssetId ?? ""
            let targetAssetId = pool.targetAssetId ?? ""
            let account = SelectedWalletSettings.shared.currentAccount
            let accountId = (try? SS58AddressFactory().accountId(fromAddress: account?.address ?? "",
                                                                type: account?.networkType ?? 0).toHex(includePrefix: true)) ?? ""
            
            guard let poolInfo = self?.accountPoolsService?.getPool(by: poolId) else {
                
                let poolInfo = PoolInfo(baseAssetId: baseAssetId, targetAssetId: targetAssetId, poolId: poolId, accountId: accountId)
                self?.wireframe.showAccountPoolDetails(on: self?.view?.controller, poolInfo: poolInfo)
                return
            }
            self?.wireframe.showAccountPoolDetails(on: self?.view?.controller, poolInfo: poolInfo)
        }

        poolItem.expandHandler = { [weak self] in
            guard let self = self else { return }
            self.wireframe.showPoolList(on: self.view?.controller, viewModelService: self.poolViewModelsService)
        }

        let sections = [ ExploreSection(items: [ .assets(assetsItem), .pools(poolItem) ]) ]
        snapshot.appendSections(sections)
        sections.forEach { snapshot.appendItems($0.items, toSection: $0) }
        
        return snapshot
    }
}

extension ExploreViewModel: DiscoverViewModelProtocol {
    func setup() {
        snapshot = createSnapshot()
        assetViewModelsService.setup()
        poolViewModelsService.setup()
    }
}
