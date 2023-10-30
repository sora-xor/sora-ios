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

protocol PoolDetailsViewModelProtocol: AnyObject {
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)? { get set }
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)? { get set }
    var dismiss: (() -> Void)? { get set }
    func viewDidLoad()
    func apyInfoButtonTapped()
    func infoButtonTapped(with type: Liquidity.TransactionLiquidityType)
    func dismissed()
}

final class PoolDetailsViewModel {
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
            updateContent()
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
    private var apy: Decimal?
    private var pools: [StakedPool] = []
    private var marketCapService: MarketCapServiceProtocol
    
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
    
    func dissmissIfNeeded() {
        if isDeletedPool {
            dismiss?()
        }
    }
}

extension PoolDetailsViewModel: PoolDetailsViewModelProtocol {
    func viewDidLoad() {
        let insets = SoramitsuInsets(horizontal: 16, vertical: 8)
        let shimmers = [SoramitsuLoadingTableViewItem(height: 136,
                                                      type: .shimmer,
                                                      insets: insets,
                                                      cornerRadius: .max)]
        setupItems?(shimmers)
        
        updateContent()
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
                                 stakedPools: pools,
                                 type: type,
                                 assetManager: assetManager,
                                 poolsService: poolsService,
                                 fiatService: fiatService,
                                 providerFactory: providerFactory,
                                 operationFactory: operationFactory,
                                 assetsProvider: assetsProvider,
                                 marketCapService: marketCapService,
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

extension PoolDetailsViewModel {
    func updateContent() {
        group.enter()
        apyService.getApy(for: poolInfo.baseAssetId, targetAssetId: poolInfo.targetAssetId) { [weak self] apy in
            self?.apy = apy
            self?.group.leave()
        }
        
        group.enter()
        farmingService.getFarmedPools(baseAssetId: poolInfo.baseAssetId, targetAssetId: poolInfo.targetAssetId) { [weak self] pools in
            self?.pools = pools
            self?.group.leave()
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            var items: [SoramitsuTableViewItemProtocol] = []
            
            let poolDetailsItem = self.itemFactory.createAccountItem(with: self.assetManager,
                                                                     poolInfo: self.poolInfo,
                                                                     apy: self.apy,
                                                                     detailsFactory: self.detailsFactory,
                                                                     viewModel: self,
                                                                     pools: self.pools)
            items.append(poolDetailsItem)
            items.append(SoramitsuTableViewSpacerItem(space: 8, color: .custom(uiColor: .clear)))
            
            let stakedItems = self.pools.map {
                self.itemFactory.stakedItem(with: self.assetManager, poolInfo: self.poolInfo, stakedPool: $0)
            }
            
            stakedItems.enumerated().forEach { (index, item) in
                items.append(item)
                if index != stakedItems.count - 1 {
                    items.append(SoramitsuTableViewSpacerItem(space: 8, color: .custom(uiColor: .clear)))
                }
            }

            self.setupItems?(items)
        }
    }
}
