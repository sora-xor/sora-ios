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
    
    weak var view: FarmDetailsViewProtocol?
    
    var farm: Farm
    var poolInfo: PoolInfo?
    weak var poolsService: PoolsServiceInputProtocol?
    
    private let detailsFactory: DetailViewModelFactoryProtocol
    
    private let itemFactory = PoolDetailsItemFactory()

    init(farm: Farm,
         poolInfo: PoolInfo? = nil,
         poolsService: PoolsServiceInputProtocol?,
         detailsFactory: DetailViewModelFactoryProtocol) {
        self.farm = farm
        self.poolInfo = poolInfo
        self.poolsService = poolsService
        self.detailsFactory = detailsFactory
    }
    
    deinit {
        print("deinited")
    }
}

extension FarmDetailsViewModel: FarmDetailsViewModelProtocol, AlertPresentable {
    func viewDidLoad() {
        if let poolInfo {
            snapshot = createSnapshot(poolInfo: poolInfo)
            return
        }
        
        Task {
            guard let baseAssetId = farm.baseAsset?.assetId, let targetAssetId = farm.poolAsset?.assetId else { return }
            let poolInfo = await poolsService?.getPool(by: baseAssetId, targetAssetId: targetAssetId)
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

        let poolDetailsItem = itemFactory.farmDetail(with: farm,
                                                     poolInfo: poolInfo,
                                                     userFarmInfo: userFarmInfo,
                                                     detailsFactory: detailsFactory, viewModel: self)
        
        items.append(contentsOf: [
            .details(poolDetailsItem),
            .space(SoramitsuTableViewSpacerItem(space: 8, color: .custom(uiColor: .clear)))
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
}
