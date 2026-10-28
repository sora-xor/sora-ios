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

final class ClaimRewardsItem: ItemProtocol {
    
    var rewardText: String
    var amountText: String
    var image: UIImage?
    var claimPossible: Bool
    var detailsViewModel: [DetailViewModel] = []
    var onClaim: (() -> Void)?
    
    init(rewardText: String,
         amountText: String,
         image: UIImage?,
         claimPossible: Bool,
         detailsViewModel: [DetailViewModel]) {
        self.rewardText = rewardText
        self.amountText = amountText
        self.image = image
        self.claimPossible = claimPossible
        self.detailsViewModel = detailsViewModel
    }
}

extension ClaimRewardsItem: Hashable {
    static func == (lhs: ClaimRewardsItem, rhs: ClaimRewardsItem) -> Bool {
        lhs.rewardText == rhs.rewardText && lhs.amountText == rhs.amountText &&
            lhs.image == rhs.image && lhs.claimPossible == rhs.claimPossible &&
            lhs.detailsViewModel == rhs.detailsViewModel
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(amountText)
        hasher.combine(rewardText)
        hasher.combine(image)
        hasher.combine(claimPossible)
        hasher.combine(detailsViewModel)
    }
}
