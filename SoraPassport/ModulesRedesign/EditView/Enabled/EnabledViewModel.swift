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

enum Cards: Int, CaseIterable {
    case soraCard = 0
    case referralProgram
    case liquidAssets
    case pooledAssets
    case scExchange

    var id: Int {
        return self.rawValue
    }
    
    var title: String {
        switch self {
        case .soraCard:
            return R.string.localizable.moreMenuSoraCardTitle(preferredLanguages: .currentLocale)
        case .referralProgram:
            return R.string.localizable.referralToolbarTitle(preferredLanguages: .currentLocale)
        case .liquidAssets:
            return R.string.localizable.liquidAssets(preferredLanguages: .currentLocale)
        case .pooledAssets:
            return R.string.localizable.pooledAssets(preferredLanguages: .currentLocale)
        case .scExchange:
            return ""
        }
    }
    
    var defaultState: State {
        switch self {
        case .soraCard, .scExchange, .referralProgram, .pooledAssets:
            return .selected
        case .liquidAssets:
            return .unselected
        }
    }
}

enum State {
    case selected
    case unselected
    case disabled
}

final class EnabledViewModel {
    let id: Int
    let title: String
    var state: State
    
    init(id: Int,
         title: String,
         state: State) {
        self.id = id
        self.title = title
        self.state = state
    }
    
}
