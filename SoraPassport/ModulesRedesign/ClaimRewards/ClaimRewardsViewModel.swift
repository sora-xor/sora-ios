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

final class ClaimRewardsViewModel {
    @Published var snapshot: ClaimRewardsSnapshot = ClaimRewardsSnapshot()
    var snapshotPublisher: Published<ClaimRewardsSnapshot>.Publisher { $snapshot }
    private var cancellables: Set<AnyCancellable> = []
    
    weak var view: ClaimRewardsViewProtocol?
    
    var farm: Farm
    var userFarmInfo: UserFarm?
    var poolInfo: PoolInfo
    weak var poolsService: PoolsServiceInputProtocol?
    var fiatService: FiatServiceProtocol?
    let assetManager: AssetManagerProtocol
    let providerFactory: BalanceProviderFactory
    let operationFactory: WalletNetworkOperationFactoryProtocol?
    private weak var assetsProvider: AssetProviderProtocol?
    private var marketCapService: MarketCapServiceProtocol
    private let farmingService: DemeterFarmingServiceProtocol
    private let detailsFactory: DetailViewModelFactoryProtocol
    private let itemFactory = ClaimRewardsItemFactory()
    
    private var fee: Decimal = 0 {
        didSet {
            reload()
        }
    }

    init(farm: Farm,
         poolInfo: PoolInfo,
         poolsService: PoolsServiceInputProtocol?,
         fiatService: FiatServiceProtocol?,
         assetManager: AssetManagerProtocol,
         providerFactory: BalanceProviderFactory,
         operationFactory: WalletNetworkOperationFactoryProtocol?,
         assetsProvider: AssetProviderProtocol?,
         marketCapService: MarketCapServiceProtocol,
         farmingService: DemeterFarmingServiceProtocol,
         detailsFactory: DetailViewModelFactoryProtocol) {
        self.farm = farm
        self.poolInfo = poolInfo
        self.poolsService = poolsService
        self.fiatService = fiatService
        self.assetManager = assetManager
        self.providerFactory = providerFactory
        self.operationFactory = operationFactory
        self.assetsProvider = assetsProvider
        self.marketCapService = marketCapService
        self.farmingService = farmingService
        self.detailsFactory = detailsFactory
        loadFarmInfo()
    }
    
    deinit {
        print("deinited")
    }

}

extension ClaimRewardsViewModel: ClaimRewardsViewModelProtocol, AlertPresentable {
    func viewDidLoad() {
        reload()
    }
    
    private func reload() {
        snapshot = createSnapshot()
    }
    
    private func createSnapshot() -> ClaimRewardsSnapshot {
        var snapshot = ClaimRewardsSnapshot()
        let sections = [ contentSection() ]
        snapshot.appendSections(sections)
        sections.forEach { snapshot.appendItems($0.items, toSection: $0) }
        
        return snapshot
    }
    
    private func contentSection() -> ClaimRewardsSection {
        var items: [ClaimRewardsSectionItem] = []
        
        let rewardsItem = itemFactory.createClaimRewardsItem(farm: farm,
                                                             userFarmInfo: userFarmInfo,
                                                             poolInfo: poolInfo,
                                                             fee: fee,
                                                             detailsFactory: detailsFactory,
                                                             viewModel: self)
        
        items.append(.claim(rewardsItem))
        
        return ClaimRewardsSection(items: items)
    }
    
    func loadFarmInfo() {
       userFarmInfo = poolInfo.farms.first {
           $0.baseAssetId == farm.baseAsset?.assetId &&
           $0.poolAssetId == farm.poolAsset?.assetId &&
           $0.rewardAssetId == farm.rewardAsset?.assetId
       }
    }
    
    func networkFeeInfoButtonTapped() {
        present(
            message: R.string.localizable.polkaswapNetworkFeeInfo(preferredLanguages: .currentLocale),
            title: R.string.localizable.networkFee(preferredLanguages: .currentLocale),
            closeAction: R.string.localizable.commonOk(preferredLanguages: .currentLocale),
            from: view
        )
    }
    
    func claimButtonTapped() {
        print("Claim button tapped.")
    }
}


