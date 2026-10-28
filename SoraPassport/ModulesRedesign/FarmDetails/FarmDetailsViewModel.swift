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
    private let userFarmService: UserFarmsServiceProtocol

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
         wireframe: FarmDetailsWireframeProtocol?,
         userFarmService: UserFarmsServiceProtocol) {
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
        self.userFarmService = userFarmService
    }
    
    deinit {
        print("deinited " + String(describing: type(of: self)))
    }
    
    private func setupSubscription() {
        Task { [weak self] in
            guard let self, let baseAssetId = poolInfo?.baseAssetId, let targetAssetId = poolInfo?.targetAssetId  else { return }

            try? await self.userFarmService.subscribeUserFarms(to: baseAssetId, targetAssetId: targetAssetId)
            await self.userFarmService.userFarms
                .dropFirst()
                .sink(
                    receiveValue: { [weak self] values in
                        guard let self else { return }
                        let userFarm = values.first { $0.rewardAssetId == self.farm.rewardAsset?.assetId }
                        self.updateContent(with: userFarm)
                    }
                ).store(in: &self.cancellables)
        }

        poolViewModelsService?.$viewModels
            .receive(on: DispatchQueue.main)
            .sink { [weak self] viewModels in
                guard let self else { return }
                self.viewModels = viewModels
            }
            .store(in: &cancellables)
    }
    
    private func updateContent(with userFarm: UserFarm?) {
        Task { [weak self] in
            guard let self, let baseAssetId = self.farm.baseAsset?.assetId, let targetAssetId = self.farm.poolAsset?.assetId else { return }
            let poolInfo = await self.poolsService?.loadPool(by: baseAssetId, targetAssetId: targetAssetId)
            self.poolInfo = poolInfo
            self.snapshot = self.createSnapshot(poolInfo: poolInfo, userFarmInfo: userFarm)
        }
    }
}

extension FarmDetailsViewModel: FarmDetailsViewModelProtocol, AlertPresentable {
    func viewDidLoad() {
        reload()
        poolViewModelsService?.setup()
        
        Task { [weak self] in
            let baseAssetId = self?.farm.baseAsset?.assetId ?? ""
            let targetAssetId =  self?.farm.poolAsset?.assetId ?? ""

            self?.poolInfo = await self?.poolsService?.loadPool(
                by: baseAssetId,
                targetAssetId: targetAssetId
            )
            
            self?.setupSubscription()
        }
    }
    
    private func reload() {
        let userFarmInfo = poolInfo?.farms.first {
            $0.baseAssetId == farm.baseAsset?.assetId &&
            $0.poolAssetId == farm.poolAsset?.assetId &&
            $0.rewardAssetId == farm.rewardAsset?.assetId
        }
        
        if let poolInfo {
            snapshot = createSnapshot(poolInfo: poolInfo, userFarmInfo: userFarmInfo)
        }
        
        Task {
            guard let baseAssetId = farm.baseAsset?.assetId, let targetAssetId = farm.poolAsset?.assetId else { return }
            let poolInfo = await poolsService?.getPool(by: baseAssetId, targetAssetId: targetAssetId)
            let fiatData = await fiatService?.getFiat() ?? []
            self.poolInfo = poolInfo
            snapshot = createSnapshot(poolInfo: poolInfo, userFarmInfo: userFarmInfo, fiatData: fiatData)
        }
    }
    
    private func createSnapshot(poolInfo: PoolInfo? = nil, userFarmInfo: UserFarm? = nil, fiatData: [FiatData] = []) -> FarmDetailsSnapshot {
        var snapshot = FarmDetailsSnapshot()
        let sections = [ contentSection(poolInfo: poolInfo, userFarmInfo: userFarmInfo, fiatData: fiatData) ]
        snapshot.appendSections(sections)
        sections.forEach { snapshot.appendItems($0.items, toSection: $0) }
        
        return snapshot
    }
    
    private func contentSection(poolInfo: PoolInfo? = nil, userFarmInfo: UserFarm? = nil, fiatData: [FiatData] = []) -> FarmDetailsSection {
        var items: [FarmDetailsSectionItem] = []
        
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
                                                     supplyItem: supplyLiquidityItem,
                                                     fiatData: fiatData)
        
        
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
        wireframe?.showClaimRewards(
            on: view?.controller,
            farm: farm,
            poolInfo: poolInfo,
            fiatService: fiatService,
            assetsProvider: assetsProvider,
            detailsFactory: detailsFactory
        )
    }
    
    func editFarmButtonTapped() {
        wireframe?.showStakeDetails(
            on: view?.controller,
            farm: farm,
            poolInfo: poolInfo,
            assetsProvider: assetsProvider,
            detailsFactory: detailsFactory
        )
    }
}
