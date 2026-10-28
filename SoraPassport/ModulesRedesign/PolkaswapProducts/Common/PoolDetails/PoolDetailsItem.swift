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

enum PoollProductType {
    case activePoolWithFarming
    case inactivePoolWithFarming
    case activeFarming
    case incativeFarming
    
    var image: UIImage? {
        switch self {
        case .activeFarming: R.image.greenLeaf()
        case .incativeFarming: R.image.grayLeaf()
        case .activePoolWithFarming: R.image.greenDrop()
        case .inactivePoolWithFarming: R.image.grayDrop()
        }
    }
}

final class PoolDetailsItem: ItemProtocol {

    var title: String
    let firstAssetImage: String?
    let secondAssetImage: String?
    let rewardAssetImage: String?
    var isRemoveLiquidityEnabled: Bool
    var isThereLiquidity: Bool
    let typeImage: PoollProductType
    weak var service: PoolDetailsItemServiceProtocol?
    let detailsViewModels: [DetailViewModel]
    var handler: ((Liquidity.TransactionLiquidityType) -> Void)?

    init(title: String,
         firstAssetImage: String?,
         secondAssetImage: String?,
         rewardAssetImage: String?,
         isRemoveLiquidityEnabled: Bool,
         typeImage: PoollProductType,
         isThereLiquidity: Bool,
         detailsViewModels: [DetailViewModel],
         poolInfo: PoolInfo,
         service: PoolDetailsItemServiceProtocol?) {
        self.title = title
        self.typeImage = typeImage
        self.firstAssetImage = firstAssetImage
        self.secondAssetImage = secondAssetImage
        self.rewardAssetImage = rewardAssetImage
        self.isRemoveLiquidityEnabled = isRemoveLiquidityEnabled
        self.isThereLiquidity = isThereLiquidity
        self.detailsViewModels = detailsViewModels
        self.service = service
    }
}

extension PoolDetailsItem: Hashable {
    static func == (lhs: PoolDetailsItem, rhs: PoolDetailsItem) -> Bool {
        lhs.isThereLiquidity == rhs.isThereLiquidity
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(isThereLiquidity)
    }
}
