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

import SoraUIKit

struct ActivityContentViewModel {
    
    let txHash: String
    let title: String
    let subtitle: String
    let typeTransactionImage: UIImage?
    let firstAssetImageViewModel: UIImage?
    let secondAssetImageViewModel: UIImage?
    let firstBalanceText: SoramitsuAttributedText
    let fiatText: String
    let status: TransactionBase.Status
    let isNeedTwoImage: Bool
    
    init(txHash: String = "",
         title: String = "",
         subtitle: String = "",
         typeTransactionImage: UIImage? = nil,
         firstAssetImageViewModel: UIImage? = nil,
         secondAssetImageViewModel: UIImage? = nil,
         firstBalanceText: SoramitsuAttributedText = SoramitsuTextItem(text: "",
                                                                       attributes: SoramitsuTextAttributes(fontData: FontType.textM,
                                                                                                           textColor: .accentPrimary)),
         fiatText: String = "",
         status: TransactionBase.Status = .success,
         isNeedTwoImage: Bool = false) {
        self.txHash = txHash
        self.title = title
        self.subtitle = subtitle
        self.typeTransactionImage = typeTransactionImage
        self.firstAssetImageViewModel = firstAssetImageViewModel
        self.secondAssetImageViewModel = secondAssetImageViewModel
        self.firstBalanceText = firstBalanceText
        self.fiatText = fiatText
        self.status = status
        self.isNeedTwoImage = isNeedTwoImage
    }
}

extension ActivityContentViewModel: Hashable {
    static func == (lhs: ActivityContentViewModel, rhs: ActivityContentViewModel) -> Bool {
        lhs.txHash == rhs.txHash &&
        lhs.title == rhs.title &&
        lhs.subtitle == rhs.subtitle &&
        lhs.fiatText == rhs.fiatText &&
        lhs.status == rhs.status &&
        lhs.isNeedTwoImage == rhs.isNeedTwoImage &&
        lhs.firstBalanceText.attributedString.string == rhs.firstBalanceText.attributedString.string &&
        lhs.firstAssetImageViewModel == rhs.firstAssetImageViewModel &&
        lhs.secondAssetImageViewModel == rhs.secondAssetImageViewModel
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(txHash)
        hasher.combine(title)
        hasher.combine(subtitle)
        hasher.combine(fiatText)
        hasher.combine(status)
        hasher.combine(isNeedTwoImage)
        hasher.combine(firstBalanceText.attributedString.string)
        hasher.combine(firstAssetImageViewModel)
        hasher.combine(secondAssetImageViewModel)
    }
}
