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

final class PoolDetailsViewModel {
    @Published var snapshot: PoolDetailsSnapshot = PoolDetailsSnapshot()
    var snapshotPublisher: Published<PoolDetailsSnapshot>.Publisher { $snapshot }
    
    private var cancellables: Set<AnyCancellable> = []
    
    var dismiss: (() -> Void)?
    var dismissHandler: (() -> Void)?
    weak var view: PoolDetailsViewProtocol?
    
    private var apyService: APYServiceProtocol
    private var fiatService: FiatServiceProtocol
    private var wireframe: PoolDetailsWireframeProtocol?
    private let farmingService: DemeterFarmingServiceProtocol
    private let itemFactory = PoolDetailsItemFactory()
    private let poolDetailsService: PoolDetailsItemServiceProtocol
    
    private var poolsService: PoolsServiceInputProtocol?
    private var poolInfo: PoolInfo
    
    private let assetManager: AssetManagerProtocol
    private let detailsFactory: DetailViewModelFactoryProtocol
    private var isDeletedPool = false
    
    private var detailsContent: [Farm] = []
    private let userFarmService: UserFarmsServiceProtocol

    init(
        wireframe: PoolDetailsWireframeProtocol?,
        poolInfo: PoolInfo,
        fiatService: FiatServiceProtocol,
        poolsService: PoolsServiceInputProtocol?,
        assetManager: AssetManagerProtocol,
        detailsFactory: DetailViewModelFactoryProtocol,
        farmingService: DemeterFarmingServiceProtocol,
        poolDetailsService: PoolDetailsItemServiceProtocol,
        userFarmService: UserFarmsServiceProtocol
    ) {
        self.poolInfo = poolInfo
        self.apyService = APYService.shared
        self.fiatService = fiatService
        self.wireframe = wireframe
        self.assetManager = assetManager
        self.detailsFactory = detailsFactory
        self.farmingService = farmingService
        self.poolDetailsService = poolDetailsService
        self.userFarmService = userFarmService
        self.poolsService = poolsService
        self.poolsService?.appendDelegate(delegate: self)
    }
    
    deinit {
        print("deinited " + String(describing: type(of: self)))
    }
    
    func dismissIfNeeded() {
        if isDeletedPool {
            dismiss?()
        }
    }
}

extension PoolDetailsViewModel: PoolDetailsViewModelProtocol {
    func viewDidLoad() {
        snapshot = createSnapshot(with: poolInfo, farms: poolInfo.farms)
        
        Task { [weak self, weak poolDetailsService] in
            guard let self, let poolDetailsService else { return }
            self.detailsContent = await (try? self.farmingService.getAllFarms().filter {
                $0.baseAsset?.assetId == self.poolInfo.baseAssetId &&
                $0.poolAsset?.assetId == self.poolInfo.targetAssetId
            }) ?? []

            self.snapshot = self.createSnapshot(with: poolInfo, farms: poolInfo.farms)
            poolDetailsService.setup(with: poolInfo)
        }
        
        Task { [weak self, weak poolDetailsService] in
            guard let self, let poolDetailsService else { return }
            try? await self.userFarmService.subscribeUserFarms(to: poolInfo.baseAssetId, targetAssetId: poolInfo.targetAssetId)
            await self.userFarmService.userFarms
                .dropFirst()
                .sink(
                    receiveValue: { [weak self] values in
                        guard let self else { return }
                        self.poolInfo.farms = values
                        self.snapshot = self.createSnapshot(with: poolInfo, farms: values)
                        poolDetailsService.setup(with: poolInfo)
                    }
                ).store(in: &self.cancellables)
        }
    }
    
    private func createSnapshot(with poolInfo: PoolInfo, farms: [UserFarm]) -> PoolDetailsSnapshot {
        var snapshot = PoolDetailsSnapshot()
        
        let sections = [ contentSection(with: poolInfo, userFarms: farms) ]
        snapshot.appendSections(sections)
        sections.forEach { snapshot.appendItems($0.items, toSection: $0) }
        
        return snapshot
    }
    
    private func contentSection(with poolInfo: PoolInfo, userFarms: [UserFarm]) -> PoolDetailsSection {
        var items: [PoolDetailsSectionItem] = []
        
        let poolDetailsItem = itemFactory.createPoolDetailsItem(with: assetManager,
                                                                poolInfo: poolInfo,
                                                                detailsFactory: detailsFactory,
                                                                viewModel: self,
                                                                farms: userFarms,
                                                                service: poolDetailsService)
        
        items.append(contentsOf: [
            .details(poolDetailsItem),
            .space(SoramitsuTableViewSpacerItem(space: 8, color: .custom(uiColor: .clear)))
        ])
        
        if !userFarms.isEmpty {
            let farmViewModels = itemFactory.farmsItem(
                with: assetManager,
                poolInfo: poolInfo,
                farms: detailsContent
            )
            let activeFarmsItem = FarmListItem(
                title: R.string.localizable.poolDetailsActiveFarms(preferredLanguages: .currentLocale),
                farmViewModels: farmViewModels
            ) { [weak self] id in
                guard let self, let farm = self.detailsContent.first(where: { $0.id == id }) else { return }
                self.wireframe?.showFarmDetails(
                    on: self.view?.controller,
                    poolsService: self.poolsService,
                    fiatService: self.fiatService,
                    assetManager: self.assetManager,
                    farmingService: self.farmingService,
                    poolInfo: self.poolInfo,
                    farm: farm
                )
            }
            
            items.append(contentsOf: [
                .staked(activeFarmsItem),
                .space(SoramitsuTableViewSpacerItem(space: 8, color: .custom(uiColor: .clear)))
            ])
        }
        
        let userFarmIds = userFarms.map { $0.id }
        let offerToStakeFarms = detailsContent.filter { !userFarmIds.contains($0.id) }
        if !offerToStakeFarms.isEmpty {
            let farmViewModels = itemFactory.farmsItem(with: offerToStakeFarms)
            
            let stakeItem = FarmListItem(
                title: R.string.localizable.polkaswapPoolFarmsTitle(preferredLanguages: .currentLocale),
                farmViewModels: farmViewModels
            ) { [weak self] id in
                guard let self, let farm = offerToStakeFarms.first(where: { $0.id == id }) else { return }
                self.wireframe?.showFarmDetails(
                    on: self.view?.controller,
                    poolsService: self.poolsService,
                    fiatService: self.fiatService,
                    assetManager: self.assetManager,
                    farmingService: self.farmingService,
                    poolInfo: self.poolInfo,
                    farm: farm
                )
            }
            
            items.append(.staked(stakeItem))
        }
        
        return PoolDetailsSection(items: items)
    }
    
    func apyInfoButtonTapped() {
        wireframe?.present(
            message: R.string.localizable.polkaswapSbApyInfo(),
            title: Constants.apyTitle,
            closeAction: R.string.localizable.commonOk(),
            from: view
        )
    }
    
    func dismissed() {
        dismissHandler?()
    }
    
    func infoButtonTapped(with type: Liquidity.TransactionLiquidityType) {
        wireframe?.showLiquidity(on: view?.controller,
                                 poolInfo: poolInfo,
                                 farms: poolInfo.farms,
                                 type: type,
                                 assetManager: assetManager,
                                 poolsService: poolsService,
                                 fiatService: fiatService,
                                 farmingService: farmingService,
                                 completionHandler: dismissIfNeeded)
    }
}

extension PoolDetailsViewModel: PoolsServiceOutput {
    func loaded(pools: [PoolInfo]) {
        guard let pool = pools.first(where: { $0.baseAssetId == poolInfo.baseAssetId && $0.targetAssetId == poolInfo.targetAssetId }) else {
            isDeletedPool = true
            dismiss?()
            return
        }

        poolInfo = pool
        snapshot = createSnapshot(with: pool, farms: pool.farms)
        poolDetailsService.setup(with: pool)
    }
}

extension String {
    func components(withMaxLength length: Int) -> [String] {
        return stride(from: 0, to: self.count, by: length).map {
            let start = self.index(self.startIndex, offsetBy: $0)
            let end = self.index(start, offsetBy: length, limitedBy: self.endIndex) ?? self.endIndex
            return String(self[start..<end])
        }
    }
}
