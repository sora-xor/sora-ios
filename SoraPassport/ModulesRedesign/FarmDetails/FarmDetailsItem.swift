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

enum FarmDetailsBottomButtonState {
    case startStacking
    case startStackingWithRewards
    case editFarm
    case stackingUnavailable
    
    var title: String {
        switch self {
        case .editFarm:
            return R.string.localizable.editFarm(preferredLanguages: .currentLocale)
        case .startStacking, .stackingUnavailable, .startStackingWithRewards:
            return R.string.localizable.startStaking(preferredLanguages: .currentLocale)
        }
    }
    
    var buttonTitleColor: SoramitsuColor {
        switch self {
        case .editFarm, .startStackingWithRewards:
            return .additionalPolkaswap
        case .startStacking:
            return .custom(uiColor: .white)
        case .stackingUnavailable:
            return .fgTertiary
        }
    }
    
    var backgroundColor: SoramitsuColor {
        switch self {
        case .editFarm, .startStackingWithRewards:
            return .additionalPolkaswapContainer
        case .startStacking:
            return .additionalPolkaswap
        case .startStacking:
            return .additionalPolkaswap
        case .stackingUnavailable:
            return .bgSurfaceVariant
        }
    }
    
    var isUserInteractionEnabled: Bool {
        return self != .stackingUnavailable
    }
}

final class FarmDetailsItem: NSObject {

    var title: String
    let subtitle: String
    let firstAssetImage: UIImage?
    let secondAssetImage: UIImage?
    let rewardAssetImage: UIImage?
    var detailsViewModel: [DetailViewModel] = []
    let typeImage: PoollProductType
    let areThereRewards: Bool
    let stackingState: FarmDetailsBottomButtonState
    let supplyItem: SupplyPoolItem?
    var onTapTopButton: (() -> Void)?
    var onTapBottomButton: (() -> Void)?

    init(title: String,
         subtitle: String,
         firstAssetImage: UIImage?,
         secondAssetImage: UIImage?,
         rewardAssetImage: UIImage?,
         detailsViewModel: [DetailViewModel],
         typeImage: PoollProductType,
         stackingState: FarmDetailsBottomButtonState,
         areThereRewards: Bool,
         supplyItem: SupplyPoolItem?) {
        self.title = title
        self.subtitle = subtitle
        self.typeImage = typeImage
        self.firstAssetImage = firstAssetImage
        self.secondAssetImage = secondAssetImage
        self.rewardAssetImage = rewardAssetImage
        self.detailsViewModel = detailsViewModel
        self.areThereRewards = areThereRewards
        self.stackingState = stackingState
        self.supplyItem = supplyItem
    }
}

extension FarmDetailsItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { PoolDetailsCell.self }

    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }

    var clipsToBounds: Bool { false }
}
