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
