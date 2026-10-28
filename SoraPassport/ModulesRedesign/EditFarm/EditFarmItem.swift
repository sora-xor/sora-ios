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

final class EditFarmItem: ItemProtocol {
    
    let sharePercentage: Decimal
    let stakedSelection: FarmShareSelection
    
    let stakeFeeAmount: Decimal
    
    weak var service: EditFarmItemService?
    
    var onConfirm: (() -> Void)?
    var feeInfoHandler: (() -> Void)?
    var networkFeeHandler: (() -> Void)?

    init(
        sharePercentage: Decimal,
        stakedSelection: FarmShareSelection,
        stakeFeeAmount: Decimal,
        service: EditFarmItemService?
    ) {
        self.sharePercentage = sharePercentage
        self.stakedSelection = stakedSelection
        self.stakeFeeAmount = stakeFeeAmount
        self.service = service
    }
}

extension EditFarmItem: Hashable {
    static func == (lhs: EditFarmItem, rhs: EditFarmItem) -> Bool {
        lhs.stakedSelection == rhs.stakedSelection
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(stakedSelection)
    }
}
