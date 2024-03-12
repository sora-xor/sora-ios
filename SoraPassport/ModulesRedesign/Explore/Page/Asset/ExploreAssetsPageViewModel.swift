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
