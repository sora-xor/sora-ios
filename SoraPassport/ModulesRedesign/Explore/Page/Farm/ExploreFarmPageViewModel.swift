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

import RobinHood
import BigInt
import IrohaCrypto
import Combine

final class ExploreFarmsPageViewModel {
    @Published var snapshot: ExplorePageSnapshot = ExplorePageSnapshot()
    var snapshotPublisher: Published<ExplorePageSnapshot>.Publisher { $snapshot }
    
    private var cancellables: Set<AnyCancellable> = []
    
    var wireframe: ExploreWireframeProtocol
    var view: ControllerBackedProtocol?
    
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

        let title = R.string.localizable.exploreDemeterTitle(preferredLanguages: .currentLocale)
        let subTitleText = R.string.localizable.exploreDemeterSubtitle(preferredLanguages: .currentLocale)
        let headerItem = HeaderItem(titleText: title, subTitleText: subTitleText)
        
        var sections = [ ExplorePageSection(items: [ .header(headerItem) ]) ]
        
        if viewModels.isEmpty {
            let serialNumbers = Array(1...20)
            let shimmersPoolItems = serialNumbers.map {
                ExploreFarmItem(serialNumber: String($0), farmViewModel: ExploreFarmViewModel(serialNumber: String($0)))
            }
            
            let shimmerSection = ExplorePageSection(items: shimmersPoolItems.map { .farm($0) })
            sections.append(shimmerSection)
        } else {
            let farmItems = viewModels.map { ExploreFarmItem(serialNumber: $0.serialNumber, farmViewModel: $0) }
            let farmSection = ExplorePageSection(items: farmItems.map { .farm($0) })
            sections.append(farmSection)
        }

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
        snapshot = createSnapshot()
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
