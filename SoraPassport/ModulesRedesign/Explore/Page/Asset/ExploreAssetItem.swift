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

import RobinHood
import BigInt

struct ExploreAssetLiquidity {
    let tokenId: String
    let marketCap: Decimal
    let oldPrice: Decimal
}

enum LoadingState<T> {
    case loaded(T)
    case loading
    case error
    
    var value: T? {
        if case .loaded(let value) = self { return value }
        return nil
    }
    
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var shimmerType: SoramitsuLoadingPlaceholderType {
        switch self {
        case .error, .loaded:
            return .none
        case .loading:
            return .shimmer
        }
    }
}

struct ExploreAssetViewModel: Hashable {
    /// Two rows are the same only when they show the same thing, so the
    /// list redraws a row whose price arrived or changed.
    static func == (lhs: ExploreAssetViewModel, rhs: ExploreAssetViewModel) -> Bool {
        lhs.assetId == rhs.assetId &&
            lhs.symbol == rhs.symbol &&
            lhs.title == rhs.title &&
            lhs.price == rhs.price &&
            lhs.serialNumber == rhs.serialNumber &&
            lhs.marketCap.value == rhs.marketCap.value &&
            lhs.marketCap.isLoading == rhs.marketCap.isLoading &&
            lhs.deltaPrice.isLoading == rhs.deltaPrice.isLoading &&
            lhs.icon == rhs.icon &&
            lhs.deltaPrice.value??.attributedString.string ==
                rhs.deltaPrice.value??.attributedString.string
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(assetId)
        hasher.combine(symbol)
        hasher.combine(title)
        hasher.combine(price)
        hasher.combine(serialNumber)
        hasher.combine(marketCap.value)
        hasher.combine(marketCap.isLoading)
        hasher.combine(deltaPrice.isLoading)
        hasher.combine(icon)
        hasher.combine(deltaPrice.value??.attributedString.string)
    }
    
    var assetId: String?
    var symbol: String?
    var title: String?
    var price: String?
    var serialNumber: String = ""
    var marketCap: LoadingState<String> = .loading
    var icon: UIImage?
    var deltaPrice: LoadingState<SoramitsuAttributedText?> = .loading
}

final class ExploreAssetItem: ItemProtocol {

    let serialNumber: String
    let assetViewModel: ExploreAssetViewModel

    init(serialNumber: String,
         assetViewModel: ExploreAssetViewModel) {
        self.serialNumber = serialNumber
        self.assetViewModel = assetViewModel
    }
}

extension ExploreAssetItem: Hashable {
    static func == (lhs: ExploreAssetItem, rhs: ExploreAssetItem) -> Bool {
        lhs.assetViewModel == rhs.assetViewModel
    }
    
    public func hash(into hasher: inout Hasher) {
        return hasher.combine(assetViewModel)
    }
}
