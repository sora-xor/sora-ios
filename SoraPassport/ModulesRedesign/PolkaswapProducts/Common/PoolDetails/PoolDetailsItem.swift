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
import SoraUIKit

import RobinHood

enum PoollProductType: Hashable {
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
    private let serviceIdentity: ObjectIdentifier?
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
        self.serviceIdentity = service.map(ObjectIdentifier.init)
    }
}

extension PoolDetailsItem: Hashable {
    static func == (lhs: PoolDetailsItem, rhs: PoolDetailsItem) -> Bool {
        lhs.isThereLiquidity == rhs.isThereLiquidity &&
            lhs.isRemoveLiquidityEnabled == rhs.isRemoveLiquidityEnabled &&
            lhs.title == rhs.title && lhs.typeImage == rhs.typeImage &&
            lhs.firstAssetImage == rhs.firstAssetImage && lhs.secondAssetImage == rhs.secondAssetImage &&
            lhs.rewardAssetImage == rhs.rewardAssetImage && lhs.detailsViewModels == rhs.detailsViewModels &&
            lhs.serviceIdentity == rhs.serviceIdentity &&
            (lhs.handler != nil) == (rhs.handler != nil)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(isThereLiquidity)
        hasher.combine(isRemoveLiquidityEnabled)
        hasher.combine(title)
        hasher.combine(typeImage)
        hasher.combine(firstAssetImage)
        hasher.combine(secondAssetImage)
        hasher.combine(rewardAssetImage)
        hasher.combine(detailsViewModels)
        hasher.combine(serviceIdentity)
        hasher.combine(handler != nil)
    }
}
