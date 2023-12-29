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

final class EditFarmViewModel {
    @Published var snapshot: EditFarmSnapshot = EditFarmSnapshot()
    var snapshotPublisher: Published<EditFarmSnapshot>.Publisher { $snapshot }
    
    weak var view: EditFarmViewProtocol?
    
    var farm: Farm
    var poolInfo: PoolInfo
    var userFarmInfo: UserFarm?
    private weak var assetsProvider: AssetProviderProtocol?
    private let itemFactory = EditFarmItemFactory()
    private let feeProvider: FeeProviderProtocol
    
    internal var sharePercentage: Decimal = 0
    private var fee: Decimal = 0
    
    private var stakedValue: Float = 0

    init(farm: Farm,
         poolInfo: PoolInfo,
         assetsProvider: AssetProviderProtocol?,
         feeProvider: FeeProviderProtocol) {
        self.farm = farm
        self.poolInfo = poolInfo
        self.assetsProvider = assetsProvider
        self.feeProvider = feeProvider
    }
    
    deinit {
        print("deinited")
    }

}

extension EditFarmViewModel: EditFarmViewModelProtocol, AlertPresentable {
    func viewDidLoad() {
        loadFarmInfo()
        reload()
    }
    
    private func reload() {
        snapshot = createSnapshot()
    }
    
    private func createSnapshot() -> EditFarmSnapshot {
        var snapshot = EditFarmSnapshot()
        let sections = [ contentSection() ]
        snapshot.appendSections(sections)
        sections.forEach { snapshot.appendItems($0.items, toSection: $0) }
        
        return snapshot
    }
    
    private func contentSection() -> EditFarmSection {
        var items: [EditFarmSectionItem] = []
        
        if let userFarmInfo {
            let service = EditFarmItemService(userFarm: userFarmInfo,
                                              feeProvider: feeProvider,
                                              currentPercentage: stakedValue,
                                              feePercentage: farm.depositFee)
            service.setup()
            
            let editFarmItem = itemFactory.createEditFarmItem(stakeFeeAmount: farm.depositFee,
                                                              sharePercentage: sharePercentage,
                                                              stakedValue: stakedValue,
                                                              viewModel: self,
                                                              service: service)
            items.append(.stake(editFarmItem))
        }
        
        return EditFarmSection(items: items)
    }
    
    func loadFarmInfo() {
       userFarmInfo = poolInfo.farms.first {
           $0.baseAssetId == farm.baseAsset?.assetId &&
           $0.poolAssetId == farm.poolAsset?.assetId &&
           $0.rewardAssetId == farm.rewardAsset?.assetId
       }
        
        let pooledTokens = userFarmInfo?.pooledTokens  ?? .zero
        let accountPoolBalance = poolInfo.accountPoolBalance ?? .zero
        let sharePercentage = accountPoolBalance > 0 ? pooledTokens / accountPoolBalance * 100 : 0
        self.sharePercentage = sharePercentage
        self.stakedValue = sharePercentage.floatValue / 100
    }
    
    func feeInfoButtonTapped() {
        present(
            message: R.string.localizable.demeterFarmingDepositFeeHint(preferredLanguages: .currentLocale),
            title: R.string.localizable.commonFee(preferredLanguages: .currentLocale) ,
            closeAction: R.string.localizable.commonOk(preferredLanguages: .currentLocale),
            from: view
        )
    }
    
    func networkFeeInfoButtonTapped() {
        present(
            message: R.string.localizable.polkaswapNetworkFeeInfo(preferredLanguages: .currentLocale),
            title: R.string.localizable.networkFee(preferredLanguages: .currentLocale),
            closeAction: R.string.localizable.commonOk(preferredLanguages: .currentLocale),
            from: view
        )
    }
    
    func confirmButtonTapped() {
        print("Confirm button tapped.")
    }
}

