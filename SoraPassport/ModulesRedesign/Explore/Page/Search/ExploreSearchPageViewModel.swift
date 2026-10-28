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

import RobinHood
import BigInt
import IrohaCrypto
import Combine


final class ExploreSearchPageViewModel {
    @Published var snapshot: ExplorePageSnapshot = ExplorePageSnapshot()
    var snapshotPublisher: Published<ExplorePageSnapshot>.Publisher { $snapshot }
    
    private var cancellables: Set<AnyCancellable> = []
    
    var wireframe: ExploreWireframeProtocol
    var view: ControllerBackedProtocol?
    
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
                self.snapshot = self.createSnapshot(assets: assets, pools: pools, farms: farms)
            }
        ).store(in: &cancellables)
    }
}

extension ExploreSearchPageViewModel: ExplorePageViewModelProtocol {
    var isNeedHeaders: Bool {
        return true
    }
    
    func setup() {
        setupSubscription()
        snapshot = createSnapshot()
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
        let filteredAssets = text.isEmpty ? assetViewModelsService.viewModels : assetViewModelsService.viewModels.filter {
            ($0.symbol ?? "").lowercased().contains(text) ||
            ($0.title ?? "").lowercased().contains(text)
        }
        
        let filteredPools = text.isEmpty ? poolViewModelsService.viewModels : poolViewModelsService.viewModels.filter {
            ($0.poolId ?? "").lowercased().contains(text) ||
            ($0.title ?? "").lowercased().contains(text)
        }
        
        let filteredFarms = text.isEmpty ? farmsViewModelsService.viewModels : farmsViewModelsService.viewModels.filter {
            ($0.title ?? "").lowercased().contains(text) ||
            ($0.farmId ?? "").lowercased().contains(text)
        }
        
        snapshot = createSnapshot(assets: filteredAssets, pools: filteredPools, farms: filteredFarms)
    }
}
