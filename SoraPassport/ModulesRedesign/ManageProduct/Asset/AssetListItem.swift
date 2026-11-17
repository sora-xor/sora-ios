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
import SoraUIKit

final class AssetListItem: NSObject {

    var assetInfo: AssetInfo
    var assetViewModel: AssetViewModel
    var assetHandler: ((String) -> Void)?
    var favoriteHandle: ((AssetListItem) -> Void)?
    var balance: Decimal
    /// The balance could not be read: the row says "Balance unavailable",
    /// `balance` is a placeholder and no value is worked out from it.
    var balanceUnavailable = false
    /// The asset is on the Polkaswap token blacklist and the wallet holds some: the row is
    /// listed only so the funds stay in view. It says so and cannot be starred back onto the
    /// home screen.
    private(set) var isHiddenByBlacklist = false
    
    var canFavorite: Bool {
        assetInfo.symbol != .xor && !isHiddenByBlacklist
    }

    /// The star as the row shows it. A blacklisted asset is not on the home screen, whatever
    /// its saved visibility (which is left as it is).
    var showsAsFavorite: Bool {
        assetInfo.visible && !isHiddenByBlacklist
    }

    /// Marks the row of a blacklisted asset the wallet holds: the amount stays, followed by
    /// the note that the blacklist hides the token.
    func markHiddenByBlacklist() {
        guard !isHiddenByBlacklist else { return }
        isHiddenByBlacklist = true
        let old = assetViewModel
        var marked = AssetViewModel(identifier: old.identifier,
                                    title: old.title,
                                    subtitle: [old.subtitle, AssetBlacklist.hiddenNote]
                                        .filter { !$0.isEmpty }
                                        .joined(separator: " · "),
                                    fiatText: old.fiatText,
                                    icon: old.icon,
                                    mode: old.mode,
                                    isFavorite: false,
                                    deltaPriceText: old.deltaPriceText)
        marked.priceLoadFinished = old.priceLoadFinished
        marked.balanceIsLoading = old.balanceIsLoading
        assetViewModel = marked
    }

    init(assetInfo: AssetInfo, assetViewModel: AssetViewModel, balance: Decimal) {
        self.assetInfo = assetInfo
        self.assetViewModel = assetViewModel
        self.balance = balance
    }
}

extension AssetListItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { AssetListCell.self }

    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }

    var clipsToBounds: Bool { false }

    var canMove: Bool {
        assetInfo.symbol != .xor
    }
    
    func itemActionTap(with context: SoramitsuTableViewContext?) {
        assetHandler?(assetInfo.identifier)
    }
}
