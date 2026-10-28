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

struct ExplorePoolViewModel: Hashable {
    var poolId: String?
    var title: String?
    var tvl: String?
    var serialNumber: String
    var apy: String?
    var baseAssetId: String?
    var targetAssetId: String?
    var baseAssetIcon: UIImage?
    var targetAssetIcon: UIImage?
}

final class ExplorePoolItem: ItemProtocol {

    let serialNumber: String
    let poolViewModel: ExplorePoolViewModel

    init(serialNumber: String,
         poolViewModel: ExplorePoolViewModel) {
        self.serialNumber = serialNumber
        self.poolViewModel = poolViewModel
    }
}

extension ExplorePoolItem: Hashable {
    static func == (lhs: ExplorePoolItem, rhs: ExplorePoolItem) -> Bool {
        lhs.poolViewModel == rhs.poolViewModel
    }
    
    public func hash(into hasher: inout Hasher) {
        return hasher.combine(poolViewModel)
    }
}
