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

final class PoolDetailsViewModel {
    @Published var snapshot: PoolDetailsSnapshot = PoolDetailsSnapshot()
    var snapshotPublisher: Published<PoolDetailsSnapshot>.Publisher { $snapshot }
    
    var detailsItem: PoolDetailsItem?
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var dismiss: (() -> Void)?
    var dismissHandler: (() -> Void)?
    
    var apyService: APYServiceProtocol
    var fiatService: FiatServiceProtocol
    weak var view: PoolDetailsViewProtocol?
    var wireframe: PoolDetailsWireframeProtocol?
    var poolsService: PoolsServiceInputProtocol?
    var poolInfo: PoolInfo {
        didSet {
            Task {
                await updateContent()
                
            }
        }
    }
    let assetManager: AssetManagerProtocol
    let detailsFactory: DetailViewModelFactoryProtocol
    let providerFactory: BalanceProviderFactory
    let operationFactory: WalletNetworkOperationFactoryProtocol
    private var isDeletedPool = false
    private weak var assetsProvider: AssetProviderProtocol?
    private let farmingService: DemeterFarmingServiceProtocol
    private let itemFactory = PoolDetailsItemFactory()
    private let group = DispatchGroup()
    private var marketCapService: MarketCapServiceProtocol
    private var task: Task<Void, Swift.Error>?
    
    private var detailsContent: (apy: Decimal?, fiatData: [FiatData], farms: [Farm])? {
        didSet {
            if detailsContent != nil {
                reload()
            }
        }
    }

    init(
        wireframe: PoolDetailsWireframeProtocol?,
        poolInfo: PoolInfo,
        fiatService: FiatServiceProtocol,
        poolsService: PoolsServiceInputProtocol?,
        assetManager: AssetManagerProtocol,
        detailsFactory: DetailViewModelFactoryProtocol,
        providerFactory: BalanceProviderFactory,
        operationFactory: WalletNetworkOperationFactoryProtocol,
        assetsProvider: AssetProviderProtocol?,
        farmingService: DemeterFarmingServiceProtocol,
        marketCapService: MarketCapServiceProtocol
    ) {
        self.poolInfo = poolInfo
        self.apyService = APYService.shared
        self.fiatService = fiatService
        self.wireframe = wireframe
        self.poolsService = poolsService
        self.assetManager = assetManager
        self.detailsFactory = detailsFactory
        self.providerFactory = providerFactory
        self.operationFactory = operationFactory
        self.assetsProvider = assetsProvider
        self.farmingService = farmingService
        self.marketCapService = marketCapService
        self.poolsService?.appendDelegate(delegate: self)
        self.poolsService?.subscribePoolsReserves([poolInfo])
    }
    
    deinit {
        print("deinited")
    }
    
    func dissmissIfNeeded() {
        if isDeletedPool {
            dismiss?()
        }
    }
    
    func updateContent() async {
        reload()

        task?.cancel()
        task = Task {
            async let apy = apyService.getApy(for: poolInfo.baseAssetId, targetAssetId: poolInfo.targetAssetId)
            
            async let fiatData = fiatService.getFiat()
            
            async let farms = (try? farmingService.getAllFarms().filter {
                $0.baseAsset?.assetId == poolInfo.baseAssetId &&
                $0.poolAsset?.assetId == poolInfo.targetAssetId
            }) ?? []
            
            detailsContent = await (apy, fiatData, farms)
        }
    }
}

extension PoolDetailsViewModel: PoolDetailsViewModelProtocol {
    func viewDidLoad() {
        Task {
            await updateContent()
        }
    }
    
    func reload() {
        snapshot = createSnapshot()
    }
    
    private func createSnapshot() -> PoolDetailsSnapshot {
        var snapshot = PoolDetailsSnapshot()
        
        let sections = [ contentSection() ]
        snapshot.appendSections(sections)
        sections.forEach { snapshot.appendItems($0.items, toSection: $0) }
        
        return snapshot
    }
    
    private func contentSection() -> PoolDetailsSection {
        var items: [PoolDetailsSectionItem] = []
        
        let poolDetailsItem = itemFactory.createPoolDetailsItem(with: assetManager,
                                                                poolInfo: poolInfo,
                                                                apy: detailsContent?.apy ?? .zero,
                                                                detailsFactory: detailsFactory,
                                                                viewModel: self,
                                                                fiatData: detailsContent?.fiatData ?? [], 
                                                                farms: poolInfo.farms)
        
        items.append(contentsOf: [
            .details(poolDetailsItem),
            .space(SoramitsuTableViewSpacerItem(space: 8, color: .custom(uiColor: .clear)))
        ])
        
        if !poolInfo.farms.isEmpty {
            let farmViewModels = itemFactory.farmsItem(
                with: assetManager,
                poolInfo: poolInfo,
                farms: detailsContent?.farms ?? []
            )
            let activeFarmsItem = FarmListItem(
                title: R.string.localizable.poolDetailsActiveFarms(preferredLanguages: .currentLocale),
                farmViewModels: farmViewModels
            ) { [weak self] id in
                guard let self, let farm = self.detailsContent?.farms.first(where: { $0.id == id }) else { return }
                self.wireframe?.showFarmDetails(
                    on: self.view?.controller,
                    poolsService: self.poolsService,
                    fiatService: self.fiatService,
                    assetManager: self.assetManager,
                    providerFactory: self.providerFactory,
                    operationFactory: self.operationFactory,
                    assetsProvider: self.assetsProvider,
                    marketCapService: self.marketCapService,
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
        
        if !(detailsContent?.farms.isEmpty ?? true) {
            let farmViewModels = itemFactory.farmsItem(with: detailsContent?.farms ?? [])
            
            let stakeItem = FarmListItem(
                title: R.string.localizable.polkaswapPoolFarmsTitle(preferredLanguages: .currentLocale),
                farmViewModels: farmViewModels
            ) { [weak self] id in
                guard let self, let farm = self.detailsContent?.farms.first(where: { $0.id == id }) else { return }
                self.wireframe?.showFarmDetails(
                    on: self.view?.controller,
                    poolsService: self.poolsService,
                    fiatService: self.fiatService,
                    assetManager: self.assetManager,
                    providerFactory: self.providerFactory,
                    operationFactory: self.operationFactory,
                    assetsProvider: self.assetsProvider,
                    marketCapService: self.marketCapService,
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
                                 providerFactory: providerFactory,
                                 operationFactory: operationFactory,
                                 assetsProvider: assetsProvider,
                                 marketCapService: marketCapService,
                                 farmingService: farmingService,
                                 completionHandler: dissmissIfNeeded)
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
