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
import BigInt
import IrohaCrypto
import Combine

final class ExplorePoolsPageViewModel {
    @Published var snapshot: ExplorePageSnapshot = ExplorePageSnapshot()
    var snapshotPublisher: Published<ExplorePageSnapshot>.Publisher { $snapshot }

    private var cancellables: Set<AnyCancellable> = []
    
    var wireframe: ExploreWireframeProtocol
    weak var view: ControllerBackedProtocol?
    
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

        let items = poolViewModels.map { ExplorePoolItem(serialNumber: $0.serialNumber, poolViewModel: $0) }
        guard !items.isEmpty else { return snapshot }
        let sections = [ExplorePageSection(items: items.map { .pool($0) })]

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
    var isNeedHeaders: Bool {
        return false
    }
    
    func setup() {
        setupSubscription()
        snapshot = createSnapshot(poolViewModels: poolViewModelsService.viewModels)
        poolViewModelsService.setup()
    }
    
    func didSelect(with item: ExplorePageSectionItem?) {
        switch item {
        case .pool(let item):
            let viewModel = item.poolViewModel
            
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
        default: break
        }
    }
    
    func searchTextChanged(with text: String) {}
}
