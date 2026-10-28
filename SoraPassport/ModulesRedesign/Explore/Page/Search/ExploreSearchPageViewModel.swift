// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit
import SoraUIKit

import RobinHood
import BigInt
import IrohaCrypto
import Combine


final class ExploreSearchPageViewModel {
    @Published var snapshot: ExplorePageSnapshot = ExplorePageSnapshot()
    var snapshotPublisher: Published<ExplorePageSnapshot>.Publisher { $snapshot }
    
    private var cancellables: Set<AnyCancellable> = []
    private var searchQuery = ""
    
    var wireframe: ExploreWireframeProtocol
    weak var view: ControllerBackedProtocol?
    
    var assetViewModelsService: ExploreAssetViewModelService
    var poolViewModelsService: ExplorePoolsViewModelService
    var farmsViewModelsService: ExploreFarmsViewModelService
    weak var accountPoolsService: PoolsServiceInputProtocol?

    init(wireframe: ExploreWireframeProtocol,
         assetViewModelsService: ExploreAssetViewModelService,
         poolViewModelsService: ExplorePoolsViewModelService,
         farmsViewModelsService: ExploreFarmsViewModelService) {
        self.wireframe = wireframe
        self.assetViewModelsService = assetViewModelsService
        self.poolViewModelsService = poolViewModelsService
        self.farmsViewModelsService = farmsViewModelsService
    }
    
    private func createAssetsSection(assetViewModels: [ExploreAssetViewModel] = []) -> [ExplorePageSection] {
        let assetItems = assetViewModels.enumerated().map { (index, element) in
            return ExploreAssetItem(serialNumber: String(index + 1), assetViewModel: element)
        }
        return [ ExplorePageSection(items: assetItems.map { .asset($0) }) ]
    }
    
    private func createPoolsSection(poolViewModels: [ExplorePoolViewModel] = []) -> [ExplorePageSection] {
        let poolItems = poolViewModels.enumerated().map { (index, element) in
            return ExplorePoolItem(serialNumber: String(index + 1), poolViewModel: element)
        }
        return [ ExplorePageSection(items: poolItems.map { .pool($0) }) ]
    }
    
    private func createFarmsSection(viewModels: [ExploreFarmViewModel] = []) -> [ExplorePageSection] {
        let farmItems = viewModels.enumerated().map { (index, element) in
            return ExploreFarmItem(
                serialNumber: String(index + 1),
                farmViewModel: element
            )
        }
        return [ ExplorePageSection(items: farmItems.map { .farm($0) }) ]
    }
    
    private func createSnapshot(
        assets: [ExploreAssetViewModel] = [],
        pools: [ExplorePoolViewModel] = [],
        farms: [ExploreFarmViewModel] = []
    ) -> ExplorePageSnapshot {
        var snapshot = ExplorePageSnapshot()
        var sections: [ExplorePageSection] = []
        
        if !assets.isEmpty {
            let assetsSection = createAssetsSection(assetViewModels: assets)
            snapshot.appendSections(assetsSection)
            sections.append(contentsOf: assetsSection)
        }

        if !pools.isEmpty {
            let poolsSection = createPoolsSection(poolViewModels: pools)
            snapshot.appendSections(poolsSection)
            sections.append(contentsOf: poolsSection)
        }

        if !farms.isEmpty {
            let farmsSection = createFarmsSection(viewModels: farms)
            snapshot.appendSections(farmsSection)
            sections.append(contentsOf: farmsSection)
        }

        sections.forEach { snapshot.appendItems($0.items, toSection: $0) }
        return snapshot
    }
    
    private func setupSubscription() {
        Publishers.CombineLatest3(
            assetViewModelsService.$viewModels,
            poolViewModelsService.$viewModels,
            farmsViewModelsService.$viewModels
        )
        .sink(
            receiveValue: { [weak self] assets, pools, farms in
                guard let self else { return }
                self.snapshot = self.filteredSnapshot(assets: assets, pools: pools, farms: farms)
            }
        ).store(in: &cancellables)
    }
}

extension ExploreSearchPageViewModel: ExplorePageViewModelProtocol {
    var isNeedHeaders: Bool {
        return true
    }
    
    func setup() {
        cancellables.removeAll()
        setupSubscription()
    }
    
    func didSelect(with item: ExplorePageSectionItem?) {
        switch item {
        case .asset(let item):
            guard let id = item.assetViewModel.assetId else { return }
            wireframe.showAssetDetails(on: view?.controller, assetId: id)
        case .pool(let item):
            let viewModel = item.poolViewModel
            
            let poolId = viewModel.poolId ?? ""
            let baseAssetId = viewModel.baseAssetId ?? ""
            let targetAssetId = viewModel.targetAssetId ?? ""
            let account = SelectedWalletSettings.shared.currentAccount
            
            let accountId = (try? SS58AddressFactory().accountId(
                fromAddress: account?.address ?? "",
                type: account?.networkType ?? 0
            ).toHex(includePrefix: true)) ?? ""
            
            guard let poolInfo = accountPoolsService?.getPool(by: poolId) else {
                let poolInfo = PoolInfo(baseAssetId: baseAssetId, targetAssetId: targetAssetId, poolId: poolId, accountId: accountId)
                wireframe.showAccountPoolDetails(on: view?.controller, poolInfo: poolInfo)
                return
            }
            wireframe.showAccountPoolDetails(on: view?.controller, poolInfo: poolInfo)
        case .farm(let item):
            guard let id = item.farmViewModel.farmId, let farm = farmsViewModelsService.getFarm(with: id) else { return }
            wireframe.showFarmDetails(on: view?.controller, farm: farm)
        default: break
        }
    }
    
    func searchTextChanged(with text: String) {
        searchQuery = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        snapshot = filteredSnapshot(assets: assetViewModelsService.viewModels,
                                    pools: poolViewModelsService.viewModels,
                                    farms: farmsViewModelsService.viewModels)
    }

    private func filteredSnapshot(assets: [ExploreAssetViewModel], pools: [ExplorePoolViewModel],
                                  farms: [ExploreFarmViewModel]) -> ExplorePageSnapshot {
        let query = searchQuery
        let filteredAssets = query.isEmpty ? assets : assets.filter {
            ($0.symbol ?? "").lowercased().contains(query) || ($0.title ?? "").lowercased().contains(query)
        }
        let filteredPools = query.isEmpty ? pools : pools.filter {
            ($0.poolId ?? "").lowercased().contains(query) || ($0.title ?? "").lowercased().contains(query)
        }
        let filteredFarms = query.isEmpty ? farms : farms.filter {
            ($0.title ?? "").lowercased().contains(query) || ($0.farmId ?? "").lowercased().contains(query)
        }
        return createSnapshot(assets: filteredAssets, pools: filteredPools, farms: filteredFarms)
    }
}
