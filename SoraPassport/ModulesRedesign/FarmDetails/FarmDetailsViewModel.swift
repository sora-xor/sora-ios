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
import SoraFoundation
import sorawallet
import Combine

final class FarmDetailsViewModel {
    @Published var snapshot: FarmDetailsSnapshot = FarmDetailsSnapshot()
    var snapshotPublisher: Published<FarmDetailsSnapshot>.Publisher { $snapshot }
    private var cancellables: Set<AnyCancellable> = []
    
    weak var view: FarmDetailsViewProtocol?
    var wireframe: FarmDetailsWireframeProtocol?
    
    var farm: Farm
    var poolInfo: PoolInfo?
    var poolViewModelsService: ExplorePoolsViewModelService?
    weak var poolsService: PoolsServiceInputProtocol?
    
    private var viewModels: [ExplorePoolViewModel] = [] {
        didSet {
            reload()
        }
    }
    
    var fiatService: FiatServiceProtocol?
    let providerFactory: BalanceProviderFactory
    let operationFactory: WalletNetworkOperationFactoryProtocol?
    private weak var assetsProvider: AssetProviderProtocol?
    private var marketCapService: MarketCapServiceProtocol
    private let farmingService: DemeterFarmingServiceProtocol
    private let detailsFactory: DetailViewModelFactoryProtocol
    private let itemFactory = PoolDetailsItemFactory()

    init(farm: Farm,
         poolInfo: PoolInfo? = nil,
         poolsService: PoolsServiceInputProtocol?,
         poolViewModelsService: ExplorePoolsViewModelService? = nil,
         fiatService: FiatServiceProtocol?,
         providerFactory: BalanceProviderFactory,
         operationFactory: WalletNetworkOperationFactoryProtocol?,
         assetsProvider: AssetProviderProtocol?,
         marketCapService: MarketCapServiceProtocol,
         farmingService: DemeterFarmingServiceProtocol,
         detailsFactory: DetailViewModelFactoryProtocol,
         wireframe: FarmDetailsWireframeProtocol?) {
        self.farm = farm
        self.poolInfo = poolInfo
        self.poolsService = poolsService
        self.poolViewModelsService = poolViewModelsService
        self.fiatService = fiatService
        self.providerFactory = providerFactory
        self.operationFactory = operationFactory
        self.assetsProvider = assetsProvider
        self.marketCapService = marketCapService
        self.farmingService = farmingService
        self.detailsFactory = detailsFactory
        self.wireframe = wireframe
    }
    
    deinit {
        print("deinited")
    }
    
    private func setupSubscription() {
        poolViewModelsService?.$viewModels
            .receive(on: DispatchQueue.main)
            .sink { [weak self] viewModels in
                guard let self else { return }
                self.viewModels = viewModels
            }
            .store(in: &cancellables)
    }
    
    private func updateContent() {
        Task { [weak self] in
            guard let self, let baseAssetId = self.farm.baseAsset?.assetId, let targetAssetId = self.farm.poolAsset?.assetId else { return }
            let poolInfo = await self.poolsService?.loadPool(by: baseAssetId, targetAssetId: targetAssetId)
            self.poolInfo = poolInfo
            self.snapshot = self.createSnapshot(poolInfo: poolInfo)
        }
    }
}

extension FarmDetailsViewModel: FarmDetailsViewModelProtocol, AlertPresentable {
    func viewDidLoad() {
        setupSubscription()
        reload()
        poolViewModelsService?.setup()
    }
    
    private func reload() {
        if let poolInfo {
            snapshot = createSnapshot(poolInfo: poolInfo)
            return
        }
        
        Task {
            guard let baseAssetId = farm.baseAsset?.assetId, let targetAssetId = farm.poolAsset?.assetId else { return }
            let poolInfo = await poolsService?.getPool(by: baseAssetId, targetAssetId: targetAssetId)
            self.poolInfo = poolInfo
            snapshot = createSnapshot(poolInfo: poolInfo)
        }
    }
    
    private func createSnapshot(poolInfo: PoolInfo? = nil) -> FarmDetailsSnapshot {
        var snapshot = FarmDetailsSnapshot()
        let sections = [ contentSection(poolInfo: poolInfo) ]
        snapshot.appendSections(sections)
        sections.forEach { snapshot.appendItems($0.items, toSection: $0) }
        
        return snapshot
    }
    
    private func contentSection(poolInfo: PoolInfo? = nil) -> FarmDetailsSection {
        var items: [FarmDetailsSectionItem] = []
        
        let userFarmInfo = poolInfo?.farms.first {
            $0.baseAssetId == farm.baseAsset?.assetId &&
            $0.poolAssetId == farm.poolAsset?.assetId &&
            $0.rewardAssetId == farm.rewardAsset?.assetId
        }
        
        var supplyLiquidityItem: SupplyPoolItem?
        
        if let poolInfo,
           let poolViewModel = viewModels.first(where: { $0.baseAssetId == poolInfo.baseAssetId && $0.targetAssetId == poolInfo.targetAssetId }),
           poolInfo.accountPoolBalance?.isZero ?? true {
            supplyLiquidityItem = itemFactory.createSupplyLiquidityItem(poolViewModel: poolViewModel, viewModel: self)
        }
        
        let poolDetailsItem = itemFactory.farmDetail(with: farm,
                                                     poolInfo: poolInfo,
                                                     userFarmInfo: userFarmInfo,
                                                     detailsFactory: detailsFactory,
                                                     viewModel: self,
                                                     supplyItem: supplyLiquidityItem)
        
        
        items.append(contentsOf: [
            .details(poolDetailsItem),
        ])
        
        return FarmDetailsSection(items: items)
    }
    
    func aprInfoButtonTapped() {
        present(
            message: R.string.localizable.aprDescription(preferredLanguages: .currentLocale),
            title: Constants.aprTitle,
            closeAction: R.string.localizable.commonOk(),
            from: view
        )
    }
    
    func supplyLiquidityTapped() {        
        wireframe?.showPoolDetails(on: view?.controller,
                                   poolInfo: poolInfo,
                                   fiatService: fiatService,
                                   poolsService: poolsService,
                                   providerFactory: providerFactory,
                                   operationFactory: operationFactory,
                                   assetsProvider: assetsProvider,
                                   marketCapService: marketCapService,
                                   farmingService: farmingService)
    }
    
    func claimRewardButtonTapped() {
        wireframe?.showClaimRewards(on: view?.controller,
                                    farm: farm,
                                    poolInfo: poolInfo,
                                    fiatService: fiatService,
                                    assetsProvider: assetsProvider,
                                    detailsFactory: detailsFactory,
                                    completion: {
            Task { [weak self] in
                guard let self, let baseAssetId = self.farm.baseAsset?.assetId, let targetAssetId = self.farm.poolAsset?.assetId else { return }
                let poolInfo = await self.poolsService?.loadPool(by: baseAssetId, targetAssetId: targetAssetId)
                self.poolInfo = poolInfo
                self.snapshot = self.createSnapshot(poolInfo: poolInfo)
            }
        })
    }
    
    func editFarmButtonTapped() {
        wireframe?.showStakeDetails(on: view?.controller,
                                    farm: farm,
                                    poolInfo: poolInfo,
                                    assetsProvider: assetsProvider,
                                    detailsFactory: detailsFactory,
                                    completion: {
            Task { [weak self] in
                guard let self, let baseAssetId = self.farm.baseAsset?.assetId, let targetAssetId = self.farm.poolAsset?.assetId else { return }
                let poolInfo = await self.poolsService?.loadPool(by: baseAssetId, targetAssetId: targetAssetId)
                self.poolInfo = poolInfo
                self.snapshot = self.createSnapshot(poolInfo: poolInfo)
            }
        })
    }
}
