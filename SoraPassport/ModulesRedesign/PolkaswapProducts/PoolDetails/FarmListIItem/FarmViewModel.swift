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

final class FarmViewModel {

    let identifier: String
    let title: String
    let subtitle: String
    let baseAssetImage: UIImage?
    let targetAssetImage: UIImage?
    let rewardAssetImage: UIImage?
    let aprText: String?
    let percentageText: String?
    let isFarmed: Bool

    init(
        identifier: String,
        title: String,
        subtitle: String,
        baseAssetImage: UIImage? = nil,
        targetAssetImage: UIImage? = nil,
        rewardAssetImage: UIImage? = nil,
        aprText: String?,
        percentageText: String? = nil,
        isFarmed: Bool
    ) {
        self.identifier = identifier
        self.title = title
        self.subtitle = subtitle
        self.baseAssetImage = baseAssetImage
        self.targetAssetImage = targetAssetImage
        self.rewardAssetImage = rewardAssetImage
        self.aprText = aprText
        self.percentageText = percentageText
        self.isFarmed = isFarmed
    }
}

extension FarmViewModel: Hashable {
    static func == (lhs: FarmViewModel, rhs: FarmViewModel) -> Bool {
        lhs.identifier == rhs.identifier && lhs.aprText == rhs.aprText
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
        hasher.combine(aprText)
    }
}
