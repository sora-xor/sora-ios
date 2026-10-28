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

protocol ExplorePageViewModelProtocol {
    var snapshotPublisher: Published<ExplorePageSnapshot>.Publisher { get }
    var isNeedHeaders: Bool { get }
    func setup()
    func didSelect(with item: ExplorePageSectionItem?)
    func searchTextChanged(with text: String)
}

class ExplorePageSection {
    var id = UUID()
    var items: [ExplorePageSectionItem]
    
    init(items: [ExplorePageSectionItem]) {
        self.items = items
    }
}

enum ExplorePageSectionItem: Hashable {
    case header(HeaderItem)
    case asset(ExploreAssetItem)
    case pool(ExplorePoolItem)
    case farm(ExploreFarmItem)
}

extension ExplorePageSection: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ExplorePageSection, rhs: ExplorePageSection) -> Bool {
        lhs.id == rhs.id
    }
}

typealias ExplorePageDataSource = UITableViewDiffableDataSource<ExplorePageSection, ExplorePageSectionItem>
typealias ExplorePageSnapshot = NSDiffableDataSourceSnapshot<ExplorePageSection, ExplorePageSectionItem>

final class ExploreAssetsPageViewModel {
    @Published var snapshot: ExplorePageSnapshot = ExplorePageSnapshot()
    var snapshotPublisher: Published<ExplorePageSnapshot>.Publisher { $snapshot }
    
    var wireframe: ExploreWireframeProtocol
    var view: ControllerBackedProtocol?
    
    var assetViewModelsService: ExploreAssetViewModelService

    init(wireframe: ExploreWireframeProtocol,
         assetViewModelsService: ExploreAssetViewModelService) {
        self.wireframe = wireframe
        self.assetViewModelsService = assetViewModelsService
    }
    
    private func createSnapshot(assetViewModels: [ExploreAssetViewModel] = []) -> ExplorePageSnapshot {
        var snapshot = ExplorePageSnapshot()

        let title = R.string.localizable .commonCurrencies(preferredLanguages: .currentLocale)
        let subTitleText = R.string.localizable.exploreSwapTokensOnSora(preferredLanguages: .currentLocale)
        let headerItem = HeaderItem(titleText: title, subTitleText: subTitleText)
        
        var sections = [ ExplorePageSection(items: [ .header(headerItem) ]) ]
        
        if assetViewModels.isEmpty {
            let serialNumbers = Array(1...20)
            let shimmersAssetItems = serialNumbers.map {
                ExploreAssetItem(serialNumber: String($0), assetViewModel: ExploreAssetViewModel(serialNumber: String($0)))
            }
            
            let shimmerSection = ExplorePageSection(items: shimmersAssetItems.map { .asset($0) })
            sections.append(shimmerSection)
        } else {
            let assetItems = assetViewModels.map { ExploreAssetItem(serialNumber: $0.serialNumber, assetViewModel: $0) }
            let assetSection = ExplorePageSection(items: assetItems.map { .asset($0) })
            sections.append(assetSection)
        }

        snapshot.appendSections(sections)
        sections.forEach { snapshot.appendItems($0.items, toSection: $0) }
        
        return snapshot
    }
}

extension ExploreAssetsPageViewModel: ExplorePageViewModelProtocol {
    var isNeedHeaders: Bool {
        return false
    }
    
    func setup() {
        snapshot = createSnapshot()

        Task {
            let assetViewModels = await assetViewModelsService.setup()
            snapshot = createSnapshot(assetViewModels: assetViewModels)
        }
    }
    
    func didSelect(with item: ExplorePageSectionItem?) {
        switch item {
        case .asset(let item):
            guard let id = item.assetViewModel.assetId else { return }
            wireframe.showAssetDetails(on: view?.controller, assetId: id)
        default: break
        }
    }
    
    func searchTextChanged(with text: String) {}
}
