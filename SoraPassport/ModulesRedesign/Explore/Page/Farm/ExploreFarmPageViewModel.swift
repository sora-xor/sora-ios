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

final class ExploreFarmsPageViewModel {
    @Published var snapshot: ExplorePageSnapshot = ExplorePageSnapshot()
    var snapshotPublisher: Published<ExplorePageSnapshot>.Publisher { $snapshot }
    
    private var cancellables: Set<AnyCancellable> = []
    
    var wireframe: ExploreWireframeProtocol
    weak var view: ControllerBackedProtocol?
    
    var farmsViewModelsService: ExploreFarmsViewModelService
    weak var accountPoolsService: PoolsServiceInputProtocol?

    init(wireframe: ExploreWireframeProtocol,
         farmsViewModelsService: ExploreFarmsViewModelService,
         accountPoolsService: PoolsServiceInputProtocol?) {
        self.wireframe = wireframe
        self.farmsViewModelsService = farmsViewModelsService
        self.accountPoolsService = accountPoolsService
    }
    
    private func createSnapshot(viewModels: [ExploreFarmViewModel] = []) -> ExplorePageSnapshot {
        var snapshot = ExplorePageSnapshot()

        let items = viewModels.map { ExploreFarmItem(serialNumber: $0.serialNumber, farmViewModel: $0) }
        guard !items.isEmpty else { return snapshot }
        let sections = [ExplorePageSection(items: items.map { .farm($0) })]

        snapshot.appendSections(sections)
        sections.forEach { snapshot.appendItems($0.items, toSection: $0) }
        
        return snapshot
    }
    
    private func setupSubscription() {
        farmsViewModelsService.$viewModels
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                guard let self else { return }
                snapshot = self.createSnapshot(viewModels: value)
            }
            .store(in: &cancellables)
    }
}

extension ExploreFarmsPageViewModel: ExplorePageViewModelProtocol {
    var isNeedHeaders: Bool {
        return false
    }
    
    func setup() {
        setupSubscription()
        snapshot = createSnapshot(viewModels: farmsViewModelsService.viewModels)
        farmsViewModelsService.setup()
    }
    
    func didSelect(with item: ExplorePageSectionItem?) {
        switch item {
        case .farm(let item):
            guard let id = item.farmViewModel.farmId, let farm = farmsViewModelsService.getFarm(with: id) else { return }
            wireframe.showFarmDetails(on: view?.controller, farm: farm)
        default: break
        }
    }

    func searchTextChanged(with text: String) {}
}
