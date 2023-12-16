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
import CommonWallet
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

final class PoolDetailsItem: NSObject {

    var title: String
    let subtitle: String
    let firstAssetImage: String?
    let secondAssetImage: String?
    let rewardAssetImage: String?
    var detailsViewModel: [DetailViewModel] = []
    var isRemoveLiquidityEnabled: Bool
    var isThereLiquidity: Bool
    let typeImage: PoollProductType
    var handler: ((Liquidity.TransactionLiquidityType) -> Void)?

    init(title: String,
         subtitle: String,
         firstAssetImage: String?,
         secondAssetImage: String?,
         rewardAssetImage: String?,
         detailsViewModel: [DetailViewModel],
         isRemoveLiquidityEnabled: Bool,
         typeImage: PoollProductType,
         isThereLiquidity: Bool) {
        self.title = title
        self.subtitle = subtitle
        self.typeImage = typeImage
        self.firstAssetImage = firstAssetImage
        self.secondAssetImage = secondAssetImage
        self.rewardAssetImage = rewardAssetImage
        self.detailsViewModel = detailsViewModel
        self.isRemoveLiquidityEnabled = isRemoveLiquidityEnabled
        self.isThereLiquidity = isThereLiquidity
    }
}

extension PoolDetailsItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { PoolDetailsCell.self }

    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }

    var clipsToBounds: Bool { false }
}
