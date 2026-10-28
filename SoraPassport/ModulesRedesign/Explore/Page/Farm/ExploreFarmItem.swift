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

struct ExploreFarmViewModel: Hashable {
    var farmId: String?
    var title: String?
    var tvl: String?
    var serialNumber: String
    var apr: String?
    var baseAssetId: String?
    var poolAssetId: String?
    var rewardAssetId: String?
    var baseAssetIcon: UIImage?
    var targetAssetIcon: UIImage?
    var rewardAssetIcon: UIImage?
}

final class ExploreFarmItem: ItemProtocol {

    let serialNumber: String
    let farmViewModel: ExploreFarmViewModel

    init(serialNumber: String, farmViewModel: ExploreFarmViewModel) {
        self.serialNumber = serialNumber
        self.farmViewModel = farmViewModel
    }
}

extension ExploreFarmItem: Hashable {
    static func == (lhs: ExploreFarmItem, rhs: ExploreFarmItem) -> Bool {
        lhs.farmViewModel == rhs.farmViewModel
    }
    
    public func hash(into hasher: inout Hasher) {
        return hasher.combine(farmViewModel)
    }
}
