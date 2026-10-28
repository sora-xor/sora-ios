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

import Foundation
import UIKit

protocol TitleSegmentControlViewModelProtocol {
    func setup()
    func didSelect(number: Int)
}

class TitleSegmentControlSection {
    var id = UUID()
    var items: [TitleSegmentControlSectionItem]
    
    init(items: [TitleSegmentControlSectionItem]) {
        self.items = items
    }
}

enum TitleSegmentControlSectionItem: Hashable {
    case segment(SegmentItem)
}

extension TitleSegmentControlSection: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: TitleSegmentControlSection, rhs: TitleSegmentControlSection) -> Bool {
        lhs.id == rhs.id
    }
}

enum ExploreTabs: Int, CaseIterable {
    case assets = 0
    case pools
    case farms
    
    var title: String {
        switch self {
        case .assets: return R.string.localizable.commonCurrencies(preferredLanguages: .currentLocale)
        case .pools: return R.string.localizable.commonPools(preferredLanguages: .currentLocale)
        case .farms: return R.string.localizable.commonFarming(preferredLanguages: .currentLocale)
        }
    }
}

typealias TitleSegmentControlDataSource = UICollectionViewDiffableDataSource<TitleSegmentControlSection, TitleSegmentControlSectionItem>
typealias TitleSegmentControlSnapshot = NSDiffableDataSourceSnapshot<TitleSegmentControlSection, TitleSegmentControlSectionItem>

protocol TitleSegmentControlViewModelDelegate: AnyObject {
    func changeCurrentPage(to number: Int)
}

final class TitleSegmentControlViewModel {
    @Published var snapshot: TitleSegmentControlSnapshot = TitleSegmentControlSnapshot()
    var snapshotPublisher: Published<TitleSegmentControlSnapshot>.Publisher { $snapshot }
    
    weak var delegate: TitleSegmentControlViewModelDelegate?
    
    private func createSnapshot(selectedItemNumber: Int = 0) -> TitleSegmentControlSnapshot {
        var snapshot = TitleSegmentControlSnapshot()
        
        let items: [TitleSegmentControlSectionItem] = ExploreTabs.allCases.map {
            .segment(SegmentItem(tab: $0, isSelected: $0.rawValue == selectedItemNumber) )
        }
        let sections = [ TitleSegmentControlSection(items: items) ]

        snapshot.appendSections(sections)
        sections.forEach { snapshot.appendItems($0.items, toSection: $0) }
        
        return snapshot
    }
}

extension TitleSegmentControlViewModel: TitleSegmentControlViewModelProtocol {
    func setup() {
        snapshot = createSnapshot()
    }
    
    func didSelect(number: Int) {
        snapshot = createSnapshot(selectedItemNumber: number)
        delegate?.changeCurrentPage(to: number)
    }
}

extension TitleSegmentControlViewModel: ExploreScrollViewDelegateOutput {
    func changeCurrentPage(to number: Int) {
        snapshot = createSnapshot(selectedItemNumber: number)
    }
}

