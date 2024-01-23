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
import SoraUIKit
import CommonWallet
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
    static func == (lhs: ExploreAssetViewModel, rhs: ExploreAssetViewModel) -> Bool {
        lhs.assetId == rhs.assetId && lhs.serialNumber == rhs.serialNumber
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(assetId)
        hasher.combine(symbol)
        hasher.combine(title)
        hasher.combine(serialNumber)
        hasher.combine(marketCap.value)
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
