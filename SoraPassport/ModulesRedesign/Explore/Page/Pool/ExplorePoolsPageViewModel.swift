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
import BigInt
import IrohaCrypto
import Combine

final class ExplorePoolsPageViewModel {
    @Published var snapshot: ExplorePageSnapshot = ExplorePageSnapshot()
    var snapshotPublisher: Published<ExplorePageSnapshot>.Publisher { $snapshot }
    private var cancellables: Set<AnyCancellable> = []
    
    var wireframe: ExploreWireframeProtocol
    var view: ControllerBackedProtocol?
    
    var poolViewModelsService: ExplorePoolsViewModelService
    weak var accountPoolsService: PoolsServiceInputProtocol?

    init(wireframe: ExploreWireframeProtocol,
         poolViewModelsService: ExplorePoolsViewModelService,
         accountPoolsService: PoolsServiceInputProtocol?) {
        self.wireframe = wireframe
        self.poolViewModelsService = poolViewModelsService
        self.accountPoolsService = accountPoolsService
    }
    
    private func createSnapshot(poolViewModels: [ExplorePoolViewModel] = []) -> ExplorePageSnapshot {
        var snapshot = ExplorePageSnapshot()

        let title = R.string.localizable.discoveryPolkaswapPools(preferredLanguages: .currentLocale)
        let subTitleText = R.string.localizable.exploreProvideAndEarn(preferredLanguages: .currentLocale)
        let headerItem = HeaderItem(titleText: title, subTitleText: subTitleText)
        
        var sections = [ ExplorePageSection(items: [ .header(headerItem) ]) ]
        
        if poolViewModels.isEmpty {
            let serialNumbers = Array(1...20)
            let shimmersPoolItems = serialNumbers.map {
                ExplorePoolItem(poolViewModel: ExplorePoolViewModel(serialNumber: String($0)))
            }
            
            let shimmerSection = ExplorePageSection(items: shimmersPoolItems.map { .pool($0) })
            sections.append(shimmerSection)
        } else {
            let poolItems = poolViewModels.map { ExplorePoolItem(poolViewModel: $0) }
            let poolSection = ExplorePageSection(items: poolItems.map { .pool($0) })
            sections.append(poolSection)
        }

        snapshot.appendSections(sections)
        sections.forEach { snapshot.appendItems($0.items, toSection: $0) }
        
        return snapshot
    }
    
    private func setupSubscription() {
        poolViewModelsService.$viewModels
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                guard let self else { return }
                snapshot = self.createSnapshot(poolViewModels: value)
            }
            .store(in: &cancellables)
    }
}

extension ExplorePoolsPageViewModel: ExplorePageViewModelProtocol {
    func setup() {
        setupSubscription()
        snapshot = createSnapshot()
        poolViewModelsService.setup()
    }
    
    func didSelect(with id: String?) {}
    
    func didSelect(with viewModel: ExplorePoolViewModel?) {
        guard let viewModel else { return }
        
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
    }
}
