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

struct PoolViewModel {

    let identifier: String
    let title: String
    let subtitle: String
    let fiatText: String
    let baseAssetImage: UIImage?
    let targetAssetImage: UIImage?
    let rewardAssetImage: UIImage?
    var mode: WalletViewMode
    var isFavorite: Bool
    var deltaArributedText: SoramitsuTextItem?
    var farmedRewardAssetsImages: [UIImage]

    init(identifier: String,
         title: String,
         subtitle: String,
         fiatText: String,
         baseAssetImage: UIImage? = nil,
         targetAssetImage: UIImage? = nil,
         rewardAssetImage: UIImage? = nil,
         mode: WalletViewMode = .view,
         isFavorite: Bool = false,
         deltaArributedText: SoramitsuTextItem? = nil,
         farmedRewardAssetsImages: [UIImage] = []) {
        self.identifier = identifier
        self.title = title
        self.subtitle = subtitle
        self.fiatText = fiatText
        self.baseAssetImage = baseAssetImage
        self.targetAssetImage = targetAssetImage
        self.rewardAssetImage = rewardAssetImage
        self.mode = mode
        self.isFavorite = isFavorite
        self.deltaArributedText = deltaArributedText
        self.farmedRewardAssetsImages = farmedRewardAssetsImages
    }
}
