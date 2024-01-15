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
import CommonWallet
import SoraUIKit

enum DetailsType {
    case casual
    case progress(Float)
}

final class DetailViewModel {

    let title: String
    var infoHandler: (() -> Void)?
    let rewardAssetImage: UIImage?
    let statusAssetImage: UIImage?
    let assetAmountText: SoramitsuTextItem
    let fiatAmountText: SoramitsuTextItem?
    let type: DetailsType

    init(title: String,
         rewardAssetImage: UIImage? = nil,
         statusAssetImage: UIImage? = nil,
         assetAmountText: SoramitsuTextItem,
         fiatAmountText: SoramitsuTextItem? = nil,
         type: DetailsType = .casual) {
        self.title = title
        self.rewardAssetImage = rewardAssetImage
        self.statusAssetImage = statusAssetImage
        self.assetAmountText = assetAmountText
        self.fiatAmountText = fiatAmountText
        self.type = type
    }
}

extension DetailViewModel: Hashable {
    static func == (lhs: DetailViewModel, rhs: DetailViewModel) -> Bool {
        lhs.assetAmountText.text == rhs.assetAmountText.text
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(assetAmountText.text)
    }
}
