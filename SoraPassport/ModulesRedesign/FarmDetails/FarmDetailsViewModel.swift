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
    private var subscriptionTask: Task<Void, Never>?
    private var contentTask: Task<Void, Never>?
    private var subscriptionID = UUID()
    private var contentID = UUID()
    private var hasObservedUserFarm = false
    private var observedUserFarm: UserFarm?
    
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
    private var pricesObservation: PIPricesObservation?

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
        subscriptionTask?.cancel()
        contentTask?.cancel()
    }
    
    private func setupSubscription() {
        subscriptionTask?.cancel()
        cancellables.removeAll()
        let requestID = UUID()
        subscriptionID = requestID
        let userFarmService = userFarmService
        subscriptionTask = Task { @MainActor [weak self] in
            let publisher = await userFarmService.userFarms
            guard let self, !Task.isCancelled, subscriptionID == requestID,
                  let base = farm.baseAsset?.assetId, let target = farm.poolAsset?.assetId else { return }
            publisher.receive(on: DispatchQueue.main)
                .sink { [weak self] values in
                    guard let self, subscriptionID == requestID else { return }
                    let matching = values.first {
                        $0.baseAssetId == self.farm.baseAsset?.assetId &&
                        $0.poolAssetId == self.farm.poolAsset?.assetId &&
                        $0.rewardAssetId == self.farm.rewardAsset?.assetId
                    }
                    updateContent(with: matching)
                }.store(in: &cancellables)
            try? await userFarmService.subscribeUserFarms(to: base, targetAssetId: target)
        }
        poolViewModelsService?.$viewModels
            .receive(on: DispatchQueue.main)
            .sink { [weak self] viewModels in self?.viewModels = viewModels }
            .store(in: &cancellables)
    }

    private func matchingUserFarm(in pool: PoolInfo?) -> UserFarm? {
        pool?.farms.first {
            $0.baseAssetId == self.farm.baseAsset?.assetId &&
            $0.poolAssetId == self.farm.poolAsset?.assetId &&
            $0.rewardAssetId == self.farm.rewardAsset?.assetId
        }
    }

    private func poolWithLatestFarm(_ pool: PoolInfo?) -> PoolInfo? {
        guard var pool, hasObservedUserFarm else { return pool }
        pool.farms.removeAll {
            $0.baseAssetId == self.farm.baseAsset?.assetId &&
            $0.poolAssetId == self.farm.poolAsset?.assetId &&
            $0.rewardAssetId == self.farm.rewardAsset?.assetId
        }
        if let observedUserFarm { pool.farms.append(observedUserFarm) }
        return pool
    }

    private func updateContent(with userFarm: UserFarm?) {
        hasObservedUserFarm = true
        observedUserFarm = userFarm
        refreshContent(loadPool: true, drawsWithoutPricesFirst: false)
    }

}

extension FarmDetailsViewModel: FarmDetailsViewModelProtocol, AlertPresentable {
    func viewDidLoad() {
        refreshContent(loadPool: true, drawsWithoutPricesFirst: true)
        poolViewModelsService?.setup()
        pricesObservation = PIPricesObservation { [weak self] in
            Task { @MainActor [weak self] in self?.reload(drawsWithoutPricesFirst: false) }
        }
        setupSubscription()
    }

    private func reload(drawsWithoutPricesFirst: Bool = true) {
        refreshContent(loadPool: false, drawsWithoutPricesFirst: drawsWithoutPricesFirst)
    }

    private func refreshContent(loadPool: Bool, drawsWithoutPricesFirst: Bool) {
        contentTask?.cancel()
        let requestID = UUID()
        contentID = requestID
        if drawsWithoutPricesFirst, let poolInfo {
            let latest = hasObservedUserFarm ? observedUserFarm : matchingUserFarm(in: poolInfo)
            snapshot = createSnapshot(poolInfo: poolInfo, userFarmInfo: latest)
        }
        contentTask = Task { @MainActor [weak self] in
            guard let self, let base = farm.baseAsset?.assetId, let target = farm.poolAsset?.assetId else { return }
            let pool = loadPool ? await poolsService?.loadPool(by: base, targetAssetId: target) :
                await poolsService?.getPool(by: base, targetAssetId: target)
            let fiatData = await fiatService?.getFiat() ?? []
            guard !Task.isCancelled, contentID == requestID else { return }
            poolInfo = poolWithLatestFarm(pool)
            let latest = hasObservedUserFarm ? observedUserFarm : matchingUserFarm(in: poolInfo)
            snapshot = createSnapshot(poolInfo: poolInfo, userFarmInfo: latest, fiatData: fiatData)
        }
    }

    private func createSnapshot(poolInfo: PoolInfo? = nil, userFarmInfo: UserFarm? = nil, fiatData: [PIExactFiatData] = []) -> FarmDetailsSnapshot {
        var snapshot = FarmDetailsSnapshot()
        let sections = [ contentSection(poolInfo: poolInfo, userFarmInfo: userFarmInfo, fiatData: fiatData) ]
        snapshot.appendSections(sections)
        sections.forEach { snapshot.appendItems($0.items, toSection: $0) }
        
        return snapshot
    }
    
    private func contentSection(poolInfo: PoolInfo? = nil, userFarmInfo: UserFarm? = nil, fiatData: [PIExactFiatData] = []) -> FarmDetailsSection {
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
