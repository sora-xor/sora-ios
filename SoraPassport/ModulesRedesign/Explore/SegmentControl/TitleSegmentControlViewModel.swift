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

